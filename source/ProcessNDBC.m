function buoyData = ProcessNDBC(OutputFolder)
    %% ProcessNDBC
    %   This function takes the .csv files from the NDBC and saves them as a matlab .mat folder for each buoy, wiht a
    %   structure that corresponds to each buoy.
    %
    %       INPUTS (OPTIONAL):
    %           OutputFolder: The location of the folders of .csv files from the NDBC download.
    %
    %       OUTPUTS:
    %           OceanData: A structure of oceanic, atmospheric, and meta data contained in the .csv files.
    %
    %       Created: Feb 21 2023
    %       Edited:  Oct 20 2023


    %% Validation
    arguments
        OutputFolder (1,:) char {mustBeFolder,mustBeTextScalar} = '../rawData/NDBC/'
    end


    %% Make output directory
    % always make this check, we don't know what order the processors have been called in.
    if ~isfolder('../data')
        mkdir('../data')
    end


    %% Preallocate
    buoyData = struct();


    %% Folders of lat/lon pairs
    folderNames = dir(OutputFolder);
    folderNames = natsortfiles(folderNames, [], 'rmdot');


    %% Pull the data from the csv files and concat them
    for i = 1:length(folderNames)
        % The current buoy
        buoyFolder = folderNames(i).name;

        % All the csv files for the current buoy
        filenames = dir(sprintf('../rawData/NDBC/%s/*.csv', buoyFolder));

        % Get the data from each set of csvs and save them to fileData
        fileData = struct();
        for f = 1:length(filenames)
            filename = fullfile(filenames(f).folder, filenames(f).name);
            data = readtable(filename, 'Delimiter', 'space', 'MultipleDelimsAsOne', true, 'ReadVariableNames', true, 'VariableNamesLine', 1);
            time = datetime([data{:, 1:5}, zeros(height(data), 1)]);

            fileData(f).year = year(time(1));
            fileData(f).time = time;
            fileData(f).data = data(:, 5:end);
        end

        % Store the file data in buoyData based on the buoy name
        buoyData.(['ID_' buoyFolder]) = fileData;
    end

    % Save the data to the .mat file and return the outputs
    save('../data/NDBCData.mat', 'buoyData')
    %% end of function %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end














