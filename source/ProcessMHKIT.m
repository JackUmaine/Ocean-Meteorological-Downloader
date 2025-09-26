function NRELData = ProcessMHKIT(OutputFolder)
    %% ProcessMHKIT
    %   This function takes the already processed NREL data from an MHKIT extraction and puts it all in the same
    %   structure, then saves it to a .mat file. This will include meta data as well as time.
    %
    %       INPUTS (OPTIONAL):
    %           OutputFolder: The location of the .mat folders of NREL data.
    %
    %       OUTPUTS:
    %           OceanData: A structure of oceanic and meta data contained in the .mat files.
    %
    %       Created: Feb 21 2023
    %       Edited:  Oct 20 2023


    %% Validation
    arguments
        OutputFolder (1,:) char {mustBeFolder,mustBeTextScalar} = '../rawData/NREL/'
    end


    %% Make output directory
    % always make this check, we don't know what order the processors have been called in.
    if ~isfolder('../data')
        mkdir('../data')
    end


    %% Folders of lat/lon pairs
    folderNames = dir(OutputFolder);
    folderNames = natsortfiles(folderNames, [], 'rmdot');
    NRELData    = struct();


    %% Pull the data from the mat files and concat
    % There is a folder for each location, and we want to pool them all together
    for f = 1:length(folderNames)
        % Extract the current folder name
        foldername = fullfile(folderNames(f).folder, folderNames(f).name);

        % Extract the files for the current lat/lon pair
        dataFiles = dir([foldername '\*.mat']);

        % loop through all the
        for j = 1:length(dataFiles)

            % load the NREL .mat data file. This is already processed in the way we like so we are just going to save it in
            % a new structure with all the data in one place instead of a file for each year.
            datafile = fullfile(dataFiles(j).folder, dataFiles(j).name);
            matInfo = who('-file', datafile);
            if ismember('nrelData', matInfo)
                load(datafile, 'nrelData');
            else
                continue;
            end

            % Extract the field names
            fnames = fields(nrelData);
            nrelData.metadata.longitude = nrelData.metadata.latitude;
            nrelData.metadata.latitude = nrelData.metadata.water_depth;

            % loop trough the field names and store them, only store the meta data on the first loop of each file
            for i = 1:length(fnames)
                if j == 1
                    NRELData(f).(fnames{i}) = nrelData.(fnames{i});
                elseif j ~= 1 && strcmp(fnames{i}, 'metadata')
                    continue;
                else
                    NRELData(f).(fnames{i}) = [NRELData(f).(fnames{i}); nrelData.(fnames{i})];
                end
            end
        end
    end

    NRELData = NRELData(~cellfun(@isempty, {NRELData.time}'));

    % Save the data to the .mat file and return the outputs
    save('../data/NRELData.mat', 'NRELData')
    %% end of function %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end














