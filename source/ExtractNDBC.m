function ExtractNDBC(Latitude, Longitude, opts, StartTime, EndTime)
    %% ExtractNDBC
    %   This function is written with the purpose of downloading data from the NDBC. Data is sparse in the NDBC, and you
    %   have to know more or less the station ID that you are interested in for downloading the information. The buoys
    %   are both virtual and phsyical, and not all stations have the same data. for more information visit the NDBC
    %   website: https://www.ndbc.noaa.gov/
    %
    %   The function will ask the user for latitude and longitude, then request which of the closest buoys the user
    %   would like to query. The function will also keep track of which years did not have data for the station queried.
    %
    %       REQUIRED INPUTS:
    %           Latitude: The latitudinal coordiante (decimal degrees north from the equator).
    %           Longitude:  The longitudinal coordinate (decimal degrees east from the prime meridian).
    %
    %       OPTIONAL INPUTS:
    %           opts: This is a workaround for calling the function within the MATLAB app and will default to an empty
    %                 struct when not needed. Do not include the variable when calling from the command line or from
    %                 another script.
    %           StartTime: The beginning date for data extraction, defined as a datetime object.
    %           EndTime: The end date for data extraction, degined as a datetime object.
    %
    %       OUTPUTS:
    %           A series of .csv output files in the rawData/NDBC subdirectory, further sorted into sub directories by
    %           buoy ID. These can be further processed with ProcessNDBC to create a .mat data file.
    %
    %
    %       Created: Jan 26, 2023
    %       Edited:  Oct 19, 2023
    %


    %% Validataion
    arguments
        Latitude (:,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(Latitude,-90,90)}
        Longitude (:,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(Longitude,-180,180),confirmLengths(Latitude,Longitude)}
        opts struct = struct()
        StartTime (1,1) datetime {mustBeAfter('19790101',StartTime),mustBeBefore('20201231',StartTime)} = datetime(1979, 1, 1, 0, 0, 0)
        EndTime (1,1) datetime {mustBeBeforeToday(EndTime,1),compareTimes(StartTime,EndTime)} = datetime('today') - caldays(1)
    end


    %% Setup
    % always make this check, we don't know what order the extractors have been called in.
    if ~isfolder('../rawData')
        mkdir('../rawData')
    end

    % output directory for the the raw data during download.
    if ~isfolder('../rawData/NDBC')
        mkdir('../rawData/NDBC')
    end

    % for plotting the buoys later
    linec = lines(6);
    linec = linec(2:end, :);


    if isempty(fieldnames(opts))
        %% lat and long -> buoyID
        % load in the buoy information
        buoyList = readtable('../bin/NDBCBuoys.csv');
        buoyLat  = buoyList{:, 10};
        buoyLon  = buoyList{:, 11};
        diff = sqrt((Latitude - buoyLat).^2 + (Longitude - buoyLon).^2);
        [~, bi] = sort(diff);
        bi = bi(1:5);
        buoyIDs = buoyList{bi, 4};


        %% read in avilable lat/lon from bin
        % Plot the buoys on the countour plot so that the user can confirm which buoy(s) they would like to use.
        fnameLatLon = '../bin/SSLatLon.nc';
        latitude    = ncread(fnameLatLon, 'latitude');
        longitude   = ncread(fnameLatLon, 'longitude');
        [Lat, Lon]  = meshgrid(latitude, longitude);
        seaSurfTemp = ncread(fnameLatLon, 'sst');
        figure('Units', 'Normalized', 'Position', [0 0 1 1])
        contourf(Lon, Lat, seaSurfTemp, 'HandleVisibility', 'off')
        hold on;
        scatter(Longitude + 360, Latitude, 100, 'k', 'filled', 'DisplayName', 'Given Location')
        for i = 1:length(buoyIDs)
            scatter(buoyList{bi(i), 11} + 360, buoyList{bi(i), 10}, 100, linec(i, :), 'filled', 'DisplayName', buoyIDs{i})
        end
        ylim([Latitude - 2 Latitude + 2])
        xlim([Longitude - 4 + 360 Longitude + 4 + 360])
        legend


        %% get the ID(s) for the call.
        [buoyi, ~] = listdlg('PromptString', 'Select buoy(s) for request.', ...
            'SelectionMode', 'multiple', 'OKString', 'Select', 'CancelString', 'No Selection', ...
            'Name', 'Buoy Selection', 'ListSize', [375 300], 'InitialValue', [1], ...
            'ListString', buoyIDs);
        buoyIDs = buoyIDs(buoyi);
    else
        buoyIDs = opts.ndbc;
    end


    %% years
    % What years are of interest? Irregular spacing is okay
    yrs = [1950:1:year(datetime('today'))]';
    indy1 = find(yrs == year(StartTime));
    indy2 = find(yrs == year(EndTime));
    yrs = yrs(indy1:indy2);


    %% Download all available csv files for each buoy:
    for ID = 1:length(buoyIDs)
        %% Local directory managment
        dirName = ['../rawData/NDBC/' buoyIDs{ID} '/'];
        if ~isfolder(dirName)       % Make the folder if it doesn't exist
            mkdir(dirName);
        end


        %% Preallocate some error stuff for keeping track
        errorData = [zeros(size(yrs))]';
        errorFlag = true;


        %% Loop through all the years of interest
        for y = 1:length(yrs)
            yr    = yrs(y);        % Get the current working year
            fname   = [dirName num2str(yr) '.csv'];
            if exist(fname, 'file')     % Skip years we've already processed
                continue
            end
            % https://www.ndbc.noaa.gov/view_text_file.php?filename=44008h1982.txt.gz&dir=data/historical/stdmet/
            noaaURL = ['https://www.ndbc.noaa.gov/view_text_file.php?filename=',...
                buoyIDs{ID}, 'h', num2str(yr),...
                '.txt.gz&dir=data/historical/stdmet/'];

            % Try to get the data from the server, log the year if there is an issue
            try
                websave(fname, noaaURL);
            catch
                errorData(y) = yr;
                if errorFlag
                    warning(['Missing data for buoy ', buoyIDs{ID}]);
                    errorFlag = false;
                end
                delete(fname);
            end
        end


        %% Error catching and logging to the console
        errorData = errorData(errorData ~= 0);
        if ~isempty(errorData)
            warning(['Data for buoy ', buoyIDs{ID}, ' does not exist for the following year(s): ', num2str(errorData)]);
        end
    end
    %% end of function %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end















%% LEGACY CODE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%
%     ylim([Latitude - 15 Latitude + 15])
%     xlim([Longitude - 30 + 360 Longitude + 30 + 360])
%     % quickly confirm location
%     locAns = questdlg('Is this the correct location?', ...
%         'Confirm Location', ...
%         'Yes', 'No', 'Cancel', 'Yes');
%     switch locAns
%         case 'Yes'
%             disp('Location confirmed.');
%         case 'No'
%             error('Wrong Location.');
%         case 'Cancel'
%             error('User canceled.');
%     end






