function ExtractERA5(North, East, South, West, opts, StartTime, EndTime)
    %% ExtractERA5
    %   This function is written with the purpose of downloading data from the ERA5 dataset, and constructing the
    %   request based on user input. For more information about the dataset, or to sign up for your API key for the
    %   function visit:  https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-era5-single-levels?tab=overview
    %
    %   There are data limits on each request from the API. the total number of datapoints that can be downloaded at a
    %   time from their API is 120,000. This translates to roughly 13 channels of hourly data over the course of a year.
    %   Due to the design of their API, only a single request can be processed at a time. This means that any request
    %   with more than 13 channels will automatically multiply the wait time by N, where N = Channels/13. Even a request
    %   with 14 channels will double the request time as a second request for only one variable will have to be made in
    %   order to not go over the ERA5 data limits. For this reason, currently datasets are restricted to only 13
    %   variables. This will also require PYTHON and the CDSAPI package. This is explained on the ERA5 website above.
    %
    %       REQUIRED INPUTS:
    %           North: The northern latitudinal coordiante (decimal degrees north from the equator).
    %           East:  The eastern longitudinal coordinate (decimal degrees east from the prime meridian).
    %
    %       OPTIONAL INPUTS:
    %           South: The southern latitudinal coordiante (omit/set equal to North for a single point).
    %           West:  The western longitudinal coordinate (omit/set equal to East for a single point).
    %           opts: This is a workaround for calling the function within the MATLAB app and will default to an empty
    %                 struct when not needed. Do not include the variable when calling from the command line or from
    %                 another script.
    %           StartTime: The beginning date for data extraction, defined as a datetime object.
    %           EndTime: The end date for data extraction, degined as a datetime object.
    %
    %       OUTPUTS:
    %           A series of .nc output files in the rawData/ERA5 subdirectory. Use ProcessERA5 for a basic method of
    %           processing the data into a matlab .mat file.
    %
    % TODO: Figure out a way to manage the fact that we can now only get 60k items at a time
    %
    %
    %       Created: Jan 26, 2023
    %       Edited:  Jul 02, 2024
    %


    %% Validataion
    arguments
        North (1,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(North,-90,90)}
        East (1,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(East,-180,180)}
        South (1,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(South,-90,90),checkSouth(North,South)} = North
        West (1,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(West,-180,180),checkWest(East,West)} = East
        opts struct = struct()
        StartTime (1,1) datetime {mustBeAfter('19400101',StartTime),mustBeBeforeToday(StartTime,1)} = datetime(1940, 1, 1, 0, 0, 0)
        EndTime (1,1) datetime {mustBeBeforeToday(EndTime,31),compareTimes(StartTime,EndTime)} = datetime('today') - calmonths(1) - caldays(1)
    end


    %% Make output directories
    % always make this check, we don't know what order the extractors have been called in.
    if ~isfolder('../rawData')
        mkdir('../rawData')
    end

    % the output directory for the raw data duuring download
    if ~isfolder('../rawData/ERA5')
        mkdir('../rawData/ERA5')
    end

    % make the temp directory, necessary for this function and could be relevant to others.
    if ~isfolder('../temp')
        mkdir('../temp')
    end


    %% get request info from JSON in bin
    % All the information for this request is in a formatted JSON file and loaded in here. Changes that are made to the
    % API should be made to those files and not inside this script.
    fidJson = fopen('../bin/ERAInputs.json');
    rawJson = char(fread(fidJson, inf)');
    json    = jsondecode(rawJson);


    %% get the request variables
    if isempty(fieldnames(opts))
        % list dlg allows for multiple selections but there is a limit to the amount of data that can come from a request,
        % so to avoid rejection we will need to make multiple calls for data sets that contain more than 13 variables. We
        % must warn the user about this, maybe allow them to make another selection if they select more than 13 by accident.
        % Prompt the user to select variables from the request
        [indxVar, ~] = listdlg('PromptString', {'Select variables for request.', 'WARNING: ERA5 has a data limit.', ...
            'More than 13 variables', 'will be truncated.'}, ...
            'SelectionMode', 'multiple', 'OKString', 'Select', 'CancelString', 'No Selection', ...
            'Name', 'ERA5 Variable Selection', 'ListSize', [375 300], 'InitialValue', [1:12], ...
            'ListString', json.variable);
        if length(indxVar) > 6
            indxVar = indxVar(1:6);
        end
    else
        [~, indxVar] = intersect(json.variable, opts.era5);
        if length(indxVar) > 6
            indxVar = indxVar(1:6);
        end
    end


    %% Process the start and end time
    indy1 = find(strcmp(json.year, num2str(year(StartTime))));
    indy2 = find(strcmp(json.year, num2str(year(EndTime))));
    indxYear = indy1:indy2;


    %% Process the location information
    north = RoundToQuarter(North);
    south = RoundToQuarter(South);
    east  = RoundToQuarter(East);
    west  = RoundToQuarter(West);

    % Check if we have a grid or a single point
    if north ~= south  && west ~= east
        [x, y] = meshgrid(south:0.25:north, west:0.25:east);
    end


    %% print and send requests
    % if x does not exist, the request is for a single latitude and longiude
    if ~exist('x', 'var')
        for yr = 1:length(indxYear)
            downloadName = ['..' replace(replace(sprintf('/rawData/ERA5/data_%02.4fN_%03.4fE_%d', North, East, str2double(json.year(indxYear(yr)))), '.', 'p'), '-', '(n)')];
            if isfile([downloadName '.nc'])
                continue;
            end
            eraRequest = string(PrintRequest(sort(json.variable(indxVar)), json.year(indxYear(yr)), [North, West, South, East], downloadName, json.month, json.day, json.time));
            fprintf('Sending  Request...\n');
            system(sprintf('python %s', eraRequest));
        end
    else
        for i = 1:length(west:0.25:east)
            for j = 1:length(south:0.25:north)
                n = x(i, j);
                e = y(i, j);
                for yr = 1:length(indxYear)
                    downloadName = ['..' replace(replace(sprintf('/rawData/ERA5/data_%02.4fN_%03.4fE_%d', n, e, str2double(json.year(indxYear(yr)))), '.', 'p'), '-', '(n)')];
                    if isfile([downloadName '.nc'])
                        continue;
                    end
                    eraRequest = string(PrintRequest(sort(json.variable(indxVar)), json.year(indxYear(yr)), [n, e, n, e], downloadName, json.month, json.day, json.time));
                    fprintf('Sending  Request...\n');
                    system(sprintf('python %s', eraRequest));
                end
            end
        end
    end

    %% end of function %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end









%% Helper functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% PrintRequest
% This was separated into a function in order to facilitate ease of writing, how much code was in the main function, and
% looping the writing of the requests and sending of the requests in a more readable manner.
% requests at the same time
function eraRequest = PrintRequest(vars, year, coords, name, mon, day, tim)
    fprintf('Printing Request... \n');
    eraRequest  = sprintf('../temp/ERA5Request_%d.py', str2double(year));
    fidPy       = fopen(eraRequest, 'w+');
    fprintf(fidPy, 'import cdsapi\n\r');
    fprintf(fidPy, 'c = cdsapi.Client()\n\r');
    fprintf(fidPy, 'c.retrieve(\n');
    fprintf(fidPy, '    ''reanalysis-era5-single-levels'',\n');
    fprintf(fidPy, '    {\n');
    fprintf(fidPy, '        ''product_type'': [''reanalysis''],\n');
    fprintf(fidPy, '        ''format'': ''netcdf'',\n');

    % variables
    PrintVar('variable', fidPy, vars);

    % years
    PrintVar('year', fidPy, year);

    % month
    PrintVar('month', fidPy, mon);%(indxMon));

    % day
    PrintVar('day', fidPy, day);%(indxDay));

    % time
    PrintVar('time', fidPy, tim);%(indxTime));

    % area [north, west, south, east]
    PrintVar('area', fidPy, [coords(1) coords(2) coords(3) coords(4)])

    % close up the file so the request can go out
    fprintf(fidPy, '    },\n    ''%s.nc'')', name);
    fclose(fidPy);
    fprintf('Readying Request... \n');
end


%% PrintVar
% written to remove complications and lines of code from PrintRequest. Properly formatted variables from the above
% selections will be printed in the form that the API requires.
function PrintVar(name, fid, var)
    % if we only have one value in a variable we have to handle it slightly differently
    if isscalar(var)
        fprintf(fid, '        ''%s'': ''%s'',\n', name, var{1});
        return;
    end

    % print the variable name
    fprintf(fid, '        ''%s'': [\n            ', name);

    % print the values
    for v = 1:length(var)
        if iscell(var(v))
            fprintf(fid, '''%s'', ', var{v});
        else
            fprintf(fid, '%0.2f, ', var(v));
        end

        % add a new line every third value
        if rem(v, 3) == 0 && v ~= length(var)
            fprintf(fid, '\n            ');
        end
    end
    fprintf(fid, '\n        ],\n');
end


%% RoundToQuarter
function val = RoundToQuarter(val)
    val = round(val * 4) / 4;
end





%% LEGACY CODE



%         % prompt the user for the years
%         [indxYear, ~] = listdlg('PromptString', 'Select years to fetch.', ...
%             'SelectionMode', 'multiple', 'OKString', 'Select', 'CancelString', 'No Selection', ...
%             'Name', 'ERA5 Year Selection', 'ListSize', [375 300], 'InitialValue', [74], ...
%             'ListString', json.year);

% promt the user for fine details like month, day, and even hours of the day (i.e. only june 6 at 10pm)
%         [indxMon, ~] = listdlg('PromptString', 'Select months to fetch.', ...
%             'SelectionMode', 'multiple', 'OKString', 'Select', 'CancelString', 'No Selection', ...
%             'Name', 'ERA5 Month Selection', 'ListSize', [375 300], 'ListString', json.month);
%
%     [indxDay, ~] = listdlg('PromptString', 'Select days to fetch.', ...
%         'SelectionMode', 'multiple', 'OKString', 'Select', 'CancelString', 'No Selection', ...
%         'Name', 'ERA5 Day Selection', 'ListSize', [375 300], 'ListString', json.day);
%
%     [indxTime, ~] = listdlg('PromptString', 'Select times of days to fetch.', ...
%         'SelectionMode', 'multiple', 'OKString', 'Select', 'CancelString', 'No Selection', ...
%         'Name', 'ERA5 Hour Selection', 'ListSize', [375 300], 'ListString', json.time);

% Get the latitude and lonitude for a box around the area, this is limited to a single latitude and longitude to
% maintain limits on the size of the request. ERA5 has 0.25deg spacing for atmospheric data and 0.5deg spacing for
% ocean wave data. The north, south, east, and west inputs will be re-grided to the nearest 0.25deg if the input is
% for more than a single lat/long (ERA5 handles this on their end for a single point)
%     [latLongArea] = inputdlg({'North (degrees north from equator)', 'South', 'East (degrees east from greenwich)', 'West'}, ...
%         'Lat/Long', [1 40], {'40.9523', '40.9523', '-124.6677', '-124.6677'});
%     North = str2double(latLongArea{1});
%     South = str2double(latLongArea{2});
%     East  = str2double(latLongArea{3});
%     West  = str2double(latLongArea{4});











%     %% read in avilable lat/lon from bin
%     % this is purely to make a plot with colors and a map on it to show the user more or less where they put their
%     % request. It will zoom in slightly on the spot selected.
%     fnameLatLon = 'bin/ERA5LatLon.nc';
%     latitude    = ncread(fnameLatLon, 'latitude');
%     longitude   = ncread(fnameLatLon, 'longitude');
%     [lat, lon]  = meshgrid(latitude, longitude);
%     seaSurfTemp = ncread(fnameLatLon, 'sst');
%     figure('Units', 'Normalized', 'Position', [0 0 1 1])
%     contourf(lon, lat, seaSurfTemp)
%     hold on;
%     scatter([East; East; West; West] + 360, [North; South; South; North], 100, 'r', 'filled')
%     ylim([North - 15 South + 15])
%     xlim([West - 30 + 360 East + 30 + 360])
%     pause(0.00001);
%

