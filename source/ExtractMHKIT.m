function ExtractMHKIT(Latitudes, Longitudes, opts, StartTime, EndTime)
    %% ExtractMHKIT
    %   This function is a wrapper written for extracting data from the NREL MHKit toolbox, specifically the WPTO wave
    %   hindcast data. There are two datasets that spans 1979-2020. Thje first dataset is an unstructured grid of data
    %   with a spatial resolution as fine as 100 to 200 meters in shallow water and a 3-hour time step. The second
    %   dataset is a much smaller dataset with fewer points (219) and a higher (1-hour) temporal resolution that also
    %   contains the directional wave spectrum. These points were selected to co-locate with NOAA buoys. for more
    %   information see: https://www.nrel.gov/water/wave-hindcast-dataset.html
    %
    %   The MHKit toolbox will need to be installed from the resources folder in order to run this function. Further, an
    %   api key should be registered with the admin for this toolbox in order to increase download speeds. For each API
    %   key, a new request can be made and thus more simuilanteous requests can be made at the same time. If the
    %   download limit is reached, an automatic 2 minute wait is implemented or the limit will not reset. More API keys
    %   help to alleviate this issue.
    %
    %       REQUIRED INPUTS:
    %           Latitudes: The latitudinal coordiantes as an array (decimal degrees north from the equator).
    %           Longitudes:  The longitudinal coordinates as an array (decimal degrees east from the prime meridian).
    %
    %       OPTIONAL INPUTS:
    %           opts: This is a workaround for calling the function within the MATLAB app and will default to an empty
    %                 struct when not needed. Do not include the variable when calling from the command line or from
    %                 another script.
    %           StartTime: The beginning date for data extraction, defined as a datetime object.
    %           EndTime: The end date for data extraction, degined as a datetime object.
    %
    %       OUTPUTS:
    %           A series of .nc output files in the rawData/NREL subdirectory, further sorted into sub directories by
    %           latitude and longitude. These are already processed .mat files from the NREL API
    %
    %       Created: Jan 26, 2023
    %       Edited:  Oct 19, 2023
    %


    %% Validataion
    arguments
        Latitudes (:,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(Latitudes,-90,90)}
        Longitudes (:,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(Longitudes,-180,180),confirmLengths(Latitudes,Longitudes)}
        opts struct = struct()
        StartTime (1,1) datetime {mustBeAfter('19790101',StartTime),mustBeBefore('20201231',StartTime)} = datetime(1979, 1, 1, 0, 0, 0)
        EndTime (1,1) datetime {mustBeBefore('20201231',EndTime),compareTimes(StartTime,EndTime)} = datetime(2020, 12, 31, 0, 0, 0)
    end


    %% Make output directory
    % always make this check, we don't know what order the extractors have been called in.
    if ~isfolder('../rawData')
        mkdir('../rawData')
    end

    % output directory for the the raw data during download.
    if ~isfolder('../rawData/NREL')
        mkdir('../rawData/NREL')
    end


    %% Get variables from json in bin
    fidJson = fopen('../bin/MHKITInputs.json');
    rawJson = char(fread(fidJson, inf)');
    json    = jsondecode(rawJson);


    %% Ask what variables to request
    % variables aviailable depend on timestep...
    if isempty(fieldnames(opts))
        dataType = questdlg({'Choose timestep', '(data available varies by timestep)'}, ...
            'Timestep', ...
            '1 hour', '3 hour', 'Cancel', '3 hour');
    else
        dataType = opts.nrel{1};
    end

    switch dataType
        case '1 hour'
            dataType = '1-hour';
            theList = json.hr1;

        case '3 hour'
            dataType = '3-hour';
            theList = json.hr3;

        case 'Cancel'
            error('User canceled.');
    end

    if isempty(fieldnames(opts))
        % collect, separate, and format the variables
        params = listdlg('PromptString', 'Select variables for request.', ...
            'SelectionMode', 'multiple', 'OKString', 'Select', 'CancelString', 'No Selection', ...
            'Name', 'MHKit Variable Selection', 'ListSize', [375 300], 'InitialValue', [6 7], ...
            'ListString', theList);
        if isempty(params)
            disp('No variables selected for MHKIT.')
            return
        end
        parameter = strings(1, length(params));
        for p = 1:length(params)
            parameter(p) = string(theList(params(p)));
        end
    else
        parameter = string(opts.nrel(2:end));
    end


    %% Get the years from input data
    yrs = [1979:2020]';
    indy1 = find(yrs == year(StartTime));
    indy2 = find(yrs == year(EndTime));
    yrs = yrs(indy1:indy2);


    %% Send the requests
    % These are seperated by location and by year because sometimes there are issues when attempting to extract an
    % array of locations/times at the same time as some locations may only have some years with some data, and the error
    % handling from NREL is not very clear about what the actual issue is. This method assures that the most amount of
    % data in the area of interest is extracted with the parameters requested.
    for l = 1:length(Latitudes)
        foldName = replace(replace(sprintf('%0.4f%0.4f/', Latitudes(l), Longitudes(l)), '.', 'p'), '-', '(n)');
        if ~isfolder(['../rawData/NREL/' foldName])
            mkdir(['../rawData/NREL/' foldName])
        end
        for y = 1:length(yrs)
            SendRequest(dataType, parameter, [Latitudes(l) Longitudes(l)], yrs(y), json.apiKey{1}, foldName)
        end
    end
    %% end of function %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end








%% HELPER FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SendRequest
% this was separated into a function in order to facilitate the wait-call aspect when all API keys have been maxed out.
% as well as keep track of what years have and have not worked.
function SendRequest(dt, p, ll, y, k, fname)
    if nargin == 5
        fname = '';
    end
    outName = sprintf('../rawData/NREL/%sdata%d.mat', fname, y);
    if ~isfile(outName)
        try
            nrelData = request_wpto(dt, p, ll, y, k);
        catch err
            if contains(err.message, 'Service Unavailable') || contains(err.message, 'Too Many Requests')
                disp('NREL server request limit reached. Attempting retry in 120 seconds...')
                pause(120);
                SendRequest(dt, p, ll, y, k, fname)
                return;
            elseif contains(err.message, 'Not Found')
                warning('Data might not exist for the chosen parameter(s) at <%0.2f, %0.2f> for %d.', ll(1), ll(2), y);
                return;
            elseif contains(err.message, '400')
                warning('Unkown error with NREL function at <%0.2f, %0.2f> for %d.', ll(1), ll(2), y);
                save(outName)
                return;
            else
                disp(err);
                disp(err.stack);
                return;
            end
        end
        fprintf('NREL extraction for %d successful.\n', y);
        save(outName, 'nrelData')
    else
        fprintf('%s already downloaded.\n', outName);
    end
end





