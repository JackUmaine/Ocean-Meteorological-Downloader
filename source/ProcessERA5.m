function [atmoData, oceanData] = ProcessERA5(OutputFolder)
    %% ProcessERA5
    %   This function is designed as a basic method for processing ERA5 data attained from the ExtractERA5 function. It
    %   takes input of a valid folder and returns two structures of processed data, while simulataneously saving that
    %   data to a .mat file in the ./data/ sub directory.
    %
    %       INPUTS (OPTIONAL):
    %           OutputFolder: The location of the .nc files from the ERA5 download.
    %
    %       OUTPUTS:
    %           atmoData: A structure of atmospheric data contained in the .nc files, also includes the latitude and
    %           longitude data, plus time as a matlab datatime data type.
    %           oceanData: A structure of oceanic data from the .nc ERA5 request, including the location and time
    %           information for each location.
    %
    %       Created: Feb 10 2023
    %       Edited:  Oct 20 2023


    %% Validation
    arguments
        OutputFolder (1,:) char {mustBeFolder,mustBeTextScalar} = '../rawData/ERA5/'
    end


    %% Make output directory
    % always make this check, we don't know what order the processors have been called in.
    if ~isfolder('../data')
        mkdir('../data')
    end


    %% Constants
    t0 = datetime(1900, 1, 1, 0, 0, 0, 0);


    %% Flags
    firstFile      = true;


    %% Preallocation
    atmoData  = struct();
    oceanData = struct();


    %% Get request info from JSON in bin
    % The outputs are seperated in the bin in order to facilitate ease of modification
    fidJson   = fopen('../bin/ERAoutputs.json');
    rawJson   = char(fread(fidJson, inf)');
    json      = jsondecode(rawJson);
    atmoVars  = json.AtmosphericVariables;
    oceanVars = json.OceanicVariables;
    key       = json.Key;


    %% NC filenames and variable names
    filenames = dir([OutputFolder '/*.nc']);
    filenames = natsortfiles(filenames, [], 'rmdot');
    inform    = ncinfo(fullfile(filenames(1).folder, filenames(1).name));
    varnames  = inform.Variables;


    %% Pull the data from the NC files
    for f = 1:length(filenames)
        % Make sure the temp variable is cleared each loop iteration
        clear fileData

        % extract the current file name
        filename = fullfile(filenames(f).folder, filenames(f).name);

        % This needs to be updated as the database increases in size, but is to avoid accidentally trying to open a
        % data file that contains nothing.
%         if contains(filename, '2025')
%             continue;
%         end

        % Extract the data from the current file using squeeze and store it in the fileData structure
        for i = 1:length(varnames)
            if contains(filename, num2str(year(datetime('today'))))
                fileData.(varnames(i).Name) = squeeze(ncread(filename, varnames(i).Name));
                if ~strcmp(varnames(i).Name, 'time')
                    fileData.(varnames(i).Name) = fileData.(varnames(i).Name)(1, :)';
                end
            else
                fileData.(varnames(i).Name) = squeeze(ncread(filename, varnames(i).Name));
            end
        end

        % Some decision making for when we have jumped between lat/lon pairs.We cannot compare on the first iteration of
        % the loop. The length of the data structures is NOT the same as f (the loop iterator) and thus we must keep
        % track of them separately via ind.
        if f ~= 1
            ind = length(atmoData);
            if atmoData(ind).longitude ~= fileData.longitude
                ind = ind + 1;
                firstFile = true;
            end
        else
            ind = 1;
        end

        % Sort the data into the two structures. For the first file of each new lat/lon pair we must save the data as a
        % new row in the structures, as well as save the lat/long information. The latitude and longitude are on
        % different grids for ocean versus atmospheric data, and thus we take every other point for ocean lat/lon.
        fnames = fields(fileData);
        if firstFile
            firstFile = false;
            % time
            time = t0 + hours(fileData.time);
            atmoData(ind).time = time;
            oceanData(ind).time = time;
            % longitude
            atmoData(ind).longitude = fileData.longitude;
            oceanData(ind).longitude = fileData.longitude(1:2:end);
            % latitude
            atmoData(ind).latitude  = fileData.latitude;
            oceanData(ind).latitude  = fileData.latitude(1:2:end);
            % separate all the other variables between the two structures and report names we don't recognize to improve
            % the input structure in the future
            for i = 1:length(fnames)
                switch fnames{i}
                    case atmoVars
                        atmoData(ind).(fnames{i}) = fileData.(fnames{i});
                    case oceanVars
                        oceanData(ind).(fnames{i}) = fileData.(fnames{i});
                    case {'latitude', 'longitude', 'time'}
                        continue;
                    otherwise
                        disp(['UNRECOGNIZED:: ' fnames{i}]);
                end
            end
        else
            % time
            time = t0 + hours(fileData.time);
            atmoData(ind).time  = [atmoData(ind).time; time];
            oceanData(ind).time = [oceanData(ind).time; time];
            % separate all the other variables between the two structures and report names we don't recognize to improve
            % the input structure in the future
            for i = 1:length(fnames)
                switch fnames{i}
                    case atmoVars
                        atmoData(ind).(fnames{i}) = [atmoData(ind).(fnames{i}); fileData.(fnames{i})];
                    case oceanVars
                        oceanData(ind).(fnames{i}) = [oceanData(ind).(fnames{i}); fileData.(fnames{i})];
                    case {'latitude', 'longitude', 'time'}
                        continue;
                    otherwise
                        disp(['UNRECOGNIZED:: ' fnames{i}]);
                end
            end
        end
    end


    % Save the data to the .mat file and return the outputs
    save('../data/ERA5Data.mat', 'atmoData', 'oceanData', 'key')
    %% end of function %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end












