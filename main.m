%% Main for MetOcean data extraction
%
%   This script assumes the user has the "./source" subdirectory, which should contain the following funcitons:
%
%       extractors:
%           [ExtractERA5, ExtractHYCOM, ExtractMHKIT, ExtractNDBC]
%
%       processors:
%           [ProcessERA5, ProcessHYCOM, ProcessMHKIT, ProcessNDBC, ProcessOSCAR]
%
%       validation:
%           [checkSouth, checkWest, compareTimes, confirmLengths, mustBeAfter, mustBeBefore, mustBeBeforeToday]


%% Setup
clear;
close all;
clc;

% make the temp dir for the .mat files for each extractor
if ~isfolder('./temp/')
    mkdir('./temp/')
end

% The extractors, we will as what data they want to extract
extractorNames = {'ERA5', 'HYCOM', 'MHKIT', 'NDBC', 'OSCAR', 'WW3'};
descriptions   = {' (Oceanic & Atmospheric)', ' (Current)', ' (NREL Hindcast)', ' (NOAA buoys)', ' (NASA Surface Currents)', '(WaveWatchIII)'};

% initialize some values
varEnd = '';
startTime = [];
endTime = [];


%% Ask about what extractors they want
[indx, ~] = listdlg( ...
    'PromptString', {'Select data sources.','WARNING: ERA5 has a 60k points limit and takes a long time.'}, ...
    'SelectionMode', 'multiple', ...
    'OKString', 'Select', ...
    'CancelString', 'No Selection', ...
    'Name', 'Extractor Selection', ...
    'ListSize', [300 150], ...
    'InitialValue', [1:length(extractorNames)], ...
    'ListString', strcat(extractorNames, descriptions) ...
    );
extractorNames = extractorNames(indx);


%% Ask the user about the location they are interested in
% Get the latitude and lonitude for a box around the area from the user and spacing for MHKIT
[latLongArea] = inputdlg( ...
    {'\fontsize{11}North (degrees north from equator)', ...
    '\fontsize{11}South (blank for single point)', ...
    '\fontsize{11}East (degrees east from greenwich)', ...
    '\fontsize{11}West (blank for single point)', ...
    '\fontsize{11}MHKIT Spacing (decimal degrees)'}, ...
    'Location Information', ...
    [1 55], ...
    {'41', '', '-124', '', '0.25'}, ...
    struct('Resize', 'on', 'WindowStyle', 'modal', 'Interpreter', 'tex') ...
    );

% get the easy ones
North = str2double(latLongArea{1});
East  = str2double(latLongArea{3});
Space = str2double(latLongArea{5});

% check for single point
if isempty(latLongArea{2})
    South = North;
else
    South = str2double(latLongArea{2});
end
if isempty(latLongArea{4})
    West = East;
else
    West  = str2double(latLongArea{4});
end


%% Ask user for time frame
answer = questdlg('Would you like to input a time range?', ...
    'Time Range', ...
    'Yes', 'No', 'No');
if strcmp(answer, 'No')
    timeRange{1} = [];
    timeRange{2} = [];
else
    [timeRange] = inputdlg( ...
        {'\fontsize{11}Start time (Format: dd-mm-yyyy)', ...
        '\fontsize{11}End time (Format: dd-mm-yyyy)'}, ...
        'Time Range Information', ...
        [1 55], ...
        {'', ''}, ...
        struct('Resize', 'on', 'WindowStyle', 'modal', 'Interpreter', 'tex') ...
        );
end

if (isempty(timeRange{1}) && ~isempty(timeRange{2})) || (~isempty(timeRange{1}) && isempty(timeRange{2}))
    error('main:timeRange', 'Must provide start time with end time and vice versa.')
end
if ~isempty(timeRange{1})
    startTime = datetime(timeRange{1}, 'ConvertFrom', 'datenum', 'Format','dd-MM-yyyy');
end
if ~isempty(timeRange{2})
    endTime = datetime(timeRange{2}, 'ConvertFrom', 'datenum', 'Format','dd-MM-yyyy');
end


%% Run the individual Extractors and processors
% These will be run in separate matlab instances. The data for each instance will be processed and then saved to a .mat
% file which will then be opened in the new instance for running each extractor. This is due to the fact that the
% extractors take vastly different periods of time to extract data for the same location.
save('./temp/NESW.mat', 'North', 'South', 'East', 'West');

% add latitude and longitude grid if MHKIT is selected
if any(contains(extractorNames, 'MHKIT'))
    Latitudes  = South:Space/2:North;
    Longitudes = West:Space:East;
    combos     = combvec(Latitudes, Longitudes);
    latitudes  = combos(1,:)';
    longitudes = combos(2,:)';

    save('./temp/NESW.mat', '-append', 'latitudes', 'longitudes')
end

% add the times to the mat file if they have been set
if ~isempty(endTime)
    varEnd = ',startTime,endTime';
end

% call all the extractors
for i = 1:length(extractorNames)
    % initiate the for calling a new instance of MATLAB
    cmdstr = ['matlab -nosplash ' sprintf(' -sd %s/source', pwd) ' -r load(''../temp/NESW.mat'');'];

    % save the time range if it is set, but check it's within bounds first.
    if ~isempty(endTime)
        [startTime, endTime] = checkTimes(startTime, endTime, 'ERA5');
        save('./temp/NESW.mat', '-append', 'startTime', 'endTime')
    end

    % add each extractor to the string with their various input arguements
    switch extractorNames{i}
        case 'ERA5'
            extPro = sprintf('ExtractERA5(North,East,South,West%s);', varEnd);
        case 'HYCOM'
            extPro = sprintf('ExtractHYCOM(North,East,South,West%s);', varEnd);
        case 'NDBC'
            extPro = sprintf('ExtractNDBC(North,East%s);', varEnd);
        case 'MHKIT'
            extPro = sprintf('ExtractMHKIT(latitudes,longitudes%s);', varEnd);
        case 'OSCAR'
            extPro = sprintf('ProcessOSCAR(North,East%s);', varEnd);
        case 'WW3'
            extPro = sprintf('ExtractWW3(North,East,South,West%s);', varEnd);
    end

    % add the extractor and processor to the string
    cmdstr = strcat(cmdstr, extPro);

    % run the system command. This will open the current extractor in a new matlab window and continue on to the next
    % extractor. This will cause some questions to pop up on the screen
    system([cmdstr ' &']);
    if ~contains(extractorNames{i}, 'HYCOM')
        fprintf('Calling extractor for %s dataset.\n    Once all selections have been made\n    press any key to continue.\n', extractorNames{i});
        pause()
    else
        fprintf('Calling extractor for %s dataset.\n...', extractorNames{i});
        pause(10)
    end
end













