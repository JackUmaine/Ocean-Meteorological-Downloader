function ExtractHYCOM(North, East, South, West, DepthProfile, StartTime, EndTime)
%% ExtractHYCOM
%   This function is written with the purpose of downloading current data from the HYbrid Coordinate Ocean Model or
%   HYCOM global reanalysis. Data is on a grid at latitudes with 0.08° resolution between 40°S and 40°N, 0.04°
%   poleward of these latitudes and longitudes with 0.08° resolution. The data is 3-hourly and exists for 1994-2015.
%   for more information see: https://www.hycom.org/dataserver/gofs-3pt1/reanalysis
%
%   HYCOM requests that any subset of data be downloaded at 1 day at a time, so this is a rather slow process. Each
%   request has a timeout, but internet issues will cause a break in any active request and will cause errors in
%   that and potentially subsequent downloads. Currently, errors are kept track of but are not re-run.
%
%       REQUIRED INPUTS:
%           North: The northern latitudinal coordiante (decimal degrees north from the equator).
%           East:  The eastern longitudinal coordinate (decimal degrees east from the prime meridian).
%
%       OPTIONAL INPUTS:
%           South: The southern latitudinal coordiante (omit/set equal to North for a single point).
%           West:  The western longitudinal coordinate (omit/set equal to East for a single point).
%           StartTime: The beginning date for data extraction, defined as a datetime object.
%           EndTime: The end date for data extraction, degined as a datetime object.
%
%       OUTPUTS:
%           A series of .nc output files in the rawData/HYCOM subdirectory. Use ProcessHYCOM for a basic method of
%           processing the data into a matlab .mat file.
%
%
%       Created: Jan 26, 2023
%       Edited:  Oct 19, 2023
%


%% Validataion
arguments
    North (1,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(North,-90,90)}
    East (1,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(East,-180,180)}
    South (1,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(South,-90,90),checkSouth(North,South)} = North
    West (1,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(West,-180,180),checkWest(East,West)} = East
    DepthProfile (1,1) logical {mustBeNumericOrLogical} = 0
    StartTime (1,1) datetime {mustBeAfter('19940101',StartTime),mustBeBefore('20151231',StartTime)} = datetime(1994, 1, 1, 0, 0, 0)
    EndTime (1,1) datetime {mustBeBefore('20151231',EndTime),compareTimes(StartTime,EndTime)} = datetime(2015, 12, 31, 0, 0, 0)

end


%% Make output directory
% always make this check, we don't know what order the extractors have been called in.
if ~isfolder('../rawData')
    mkdir('../rawData')
end

% output directory for the the raw data during download.
if ~isfolder('../rawData/HYCOM')
    mkdir('../rawData/HYCOM')
end


%% Setup and load inputs
url = 'https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_53.X/data/';
load('../bin/HYCOMInputs.mat', 'hycomInputs')


%% Procecss location data
[ilat, ~] = find(hycomInputs.lat <= North & hycomInputs.lat >= South);
[ilon, ~] = find(hycomInputs.lon <= East & hycomInputs.lon >= West);

% make directory for current lat/long combination
latLongFname = sprintf('%0.2fN_%0.2fE_%0.2fS_%0.2fW', North, East, South, West);
latLongFname = replace(replace(latLongFname, '-', 'n'), '.', 'p');


%% Process start and end time
% ask the user what years they wish to download
% we will conver them to datetime so we can manipulate all the information better for writing the links and the
% filenames later.
yrs = cellstr(num2str([1994:2015]'));
indy1 = find(strcmp(yrs, num2str(year(StartTime))));
indy2 = find(strcmp(yrs, num2str(year(EndTime))));
indxYear = indy1:indy2;
startDate = datetime(sprintf('%s-01-01T00:00', yrs{indxYear(1)}), 'InputFormat', 'yyyy-MM-dd''T''HH:mm');
endDate   = datetime(sprintf('%s-12-31T23:00', yrs{indxYear(end)}), 'InputFormat', 'yyyy-MM-dd''T''HH:mm');


%% Request for each year
% all of this is for keeping track of the requests as they are going and reporting back to the user about how long
% things are taking and keeping track of errors.
numberOfYears = floor(years(endDate - startDate));
times         = zeros(numberOfYears, 1);
timedOut      = strings(numberOfYears, 1);
errored       = strings(numberOfYears, 1);
perDone       = round([0.05:0.05:(1-0.05)] * numberOfYears);
waitTime      = 0;

for i = 0:numberOfYears
    % time tracking
    tic

    % get the current date and construct the url
    y = year(startDate) + i;
    hycomLink = [url num2str(y) '?'];

    % check the time info for this year
    tinfo = ncinfo(hycomLink, 'time');

    % mat file name
    saveName = ['../rawData/HYCOM/' latLongFname '_' num2str(y) '.mat'];

    % download the time and currents
    if ~isfile(saveName)
        % call the opendap database for each variable
        if ~DepthProfile
            % no depth profile
            try
                u = ncread(hycomLink, 'water_u', [ilon(1), ilat(1), 1, 1], [length(ilon), length(ilat), 1, tinfo.Size], [1, 1, 1, 1]);
                v = ncread(hycomLink, 'water_v', [ilon(1), ilat(1), 1, 1], [length(ilon), length(ilat), 1, tinfo.Size], [1, 1, 1, 1]);
            catch  errMess
                if contains(errMess.message, {'timed out after'})
                    timedOut(i + 1) = saveName(12:21);
                elseif contains(errMess.message, '400')
                    errored(i + 1) = saveName(12:21);
                else
                    disp(errMess);
                end
            end
        else
            % if there is a depth profile request reduce the matrix to a single point in the center of the selected area
            if length(ilat) > 1 || length(ilon) > 1
                ilat = ilat(ceil(end/2));
                ilon = ilon(ceil(end/2));
            end

            % Query the water_u to get the number of none NaN readings to determine what depths the readings go to
            % at this specific lat/lon
            loop = true;
            while loop
                try
                    depthQuery = squeeze(ncread(hycomLink, 'water_u', [ilon(1), ilat(1), 1, 1], [length(ilon), length(ilat), 40, 1], [1, 1, 1, 1]));
                    loop = false;
                catch
                    disp('Depth query failed, waiting 5 minutes....')
                    pause(60*5);
                    waitTime = waitTime + 60*5;
                end
            end
            ndepths = sum(~isnan(depthQuery));

            % Preallocate
            u = zeros(tinfo.Size, ndepths);
            v = u;

            % Query for each depth, add a waiting period for when the server starts to have issues
            itermax = 100 * ndepths;
            d = 1;
            iter = 0;
            while d <= ndepths && iter < itermax
                iter = iter + 1;
                % for d = 1:ndepths
                % Query the server, if it fails for a known reason then wait and restart from this point
                try
                    u(:,d) = squeeze(ncread(hycomLink, 'water_u', [ilon(1), ilat(1), d, 1], [length(ilon), length(ilat), 1, tinfo.Size], [1, 1, 1, 1]));
                    v(:,d) = squeeze(ncread(hycomLink, 'water_v', [ilon(1), ilat(1), d, 1], [length(ilon), length(ilat), 1, tinfo.Size], [1, 1, 1, 1]));
                catch errMess
                    if contains(errMess.message, {'getVarsShort'})
                        disp('Server issue encountered, waiting 5 minutes....')
                        pause(60*5);
                        waitTime = waitTime + 60*5;
                        continue;
                    else
                        disp(errMess);
                    end
                end

                d = d + 1;
            end
            if iter > itermax
                disp('Maximum iterations occured, problem....')
            end
        end

        % get the time array
        time = ncread(hycomLink, 'time', 1, tinfo.Size, 1);

        % extract the lat and lon from the inputs
        lat  = hycomInputs.lat(ilat);
        lon  = hycomInputs.lon(ilon);

        % save this years data
        save(saveName, 'u', 'v', 'lat', 'lon', 'time')
        if DepthProfile
            depth = hycomInputs.depth(1:ndepths);
            save(saveName, 'depth', '-append')
        end

    end

    % report time to user
    times(i + 1) = toc - waitTime;
    secs = mean(times(1:(i + 1)));
    if any(i == perDone)
        fprintf('%2.0f%% done. Estimated time left: %0.4fs.\n', round(perDone(i == perDone) / numberOfYears, 2) * 100, secs * (numberOfYears - i))
    end
end


%% Clean up and report data that didn't download
% TODO: modify function to work with a random selection of dates instead of a range of dates in order to call the
% function recursively in an attempt to re-download failed data.

timedOut(timedOut == "") = [];
errored(errored == "") = [];

if ~isempty(timedOut) || ~isempty(errored)
    finalMessage = sprintf('HYCOM:: %d downloads timed out and %d threw errors. ', numel(timedOut), numel(errored));
    fmtTO = ['Dates that timed out: ' repmat('%s, ', 1, numel(timedOut)) ];
    strTO = sprintf(fmtTO, timedOut);
    fmtER = ['. Dates that threw errors: ' repmat('%s, ', 1, numel(errored))];
    strER = sprintf(fmtER, errored);
else
    finalMessage = sprintf('HYCOM:: All data downloaded correctly.');
    strTO = '';
    strER = '';
end

sendText = [finalMessage strTO strER];
charLim = 135;
for i = 1:ceil(length(sendText) / charLim)
    if i == ceil(length(sendText) / charLim)
        %             send_text_message('207-329-9008', 'verizon', sendText(((i - 1)*charLim + 1):end))
        disp(sendText(((i - 1)*charLim + 1):end))
    else
        %             send_text_message('207-329-9008', 'verizon', sendText(((i - 1)*charLim + 1):(i * charLim)))
        %             pause(0.1)
        disp(sendText(((i - 1)*charLim + 1):(i * charLim)))
    end
end
end

%% END OF FUNCTION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
