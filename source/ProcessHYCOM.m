function [currentData] = ProcessHYCOM(OutputFolder)
    %% ProcessERA5
    %   This function is designed as a basic method for processing current data attained from the ExtractHYCOM function.
    %   It takes input of a valid folder and returns a structure of processed data, while simulataneously saving that
    %   data to a .mat file in the ./data/ sub directory.
    %
    %       INPUTS (OPTIONAL):
    %           OutputFolder: The location of the .nc files from the HYCOM download.
    %
    %       OUTPUTS:
    %           currentData: A structure of current data contained in the .nc files, also includes the latitude and
    %           longitude data, plus time as a matlab datatime data type.
    %
    %       Created: Feb 23 2023
    %       Edited:  Oct 20 2023


    %% Validation
    arguments
        OutputFolder (1,:) char {mustBeFolder,mustBeTextScalar} = '../rawData/HYCOM/'
    end


    %% Make output directory
    % always make this check, we don't know what order the processors have been called in.
    if ~isfolder('../data')
        mkdir('../data')
    end


    %% Constants
    t0 = datetime(2000, 1, 1, 0, 0, 0, 0);


    %% Inputs
    filenames = dir([OutputFolder '/*.mat']);
    filenames = natsortfiles(filenames, [], 'rmdot');


    %% Pull the data from the NC files
    for f = 1:length(filenames)
        % extract the current file name
        filename = fullfile(filenames(f).folder, filenames(f).name);

        % Pull out the data from each file, initialize the structure on the first iteration of the loop
        if f == 1
            load(filename, 'u', 'v', 'lat', 'lon', 'time')
            % time
            t = t0 + hours(time);
            currentData.time = t;
            % Longitude
            currentData.longitude = lon;
            % Latitude
            currentData.latitude = lat;
            % water_u
            currentData.water_u = squeeze(u);
            % water_v
            currentData.water_v = squeeze(v);

        else
            load(filename, 'u', 'v', 'time')
            % time
            t = t0 + hours(time);
            currentData.time = [currentData.time; t];
            % water_u
            currentData.water_u = [currentData.water_u; squeeze(u)];
            % water_v
            currentData.water_v = [currentData.water_v; squeeze(v)];
        end
    end

    % Save the data to the .mat file and return the outputs
    save('../data/HYCOMData.mat', 'currentData')
    %% end of function %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end










