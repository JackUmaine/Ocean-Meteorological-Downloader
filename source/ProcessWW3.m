function [ww3Data] = ProcessWW3(OutputFolder)
    %% ProcessERA5
    %   This function is designed as a basic method for processing the wind and wave data from the WW3 dataset.
    %
    %       INPUTS (OPTIONAL):
    %           OutputFolder: The location of the .mat files from the WW3 download.
    %
    %       OUTPUTS:
    %           ww3Data: A structure of wind and wave data contained in the .mat files, also includes the latitude and
    %           longitude data, plus time as a matlab datatime data type.
    %
    %       Created: Jun 14 2024
    %       Edited:  Jun 14 2024


    %% Validation
    arguments
        OutputFolder (1,:) char {mustBeFolder,mustBeTextScalar} = '../data'
    end


    %% Make output directory
    % always make this check, we don't know what order the processors have been called in.
    if ~isfolder('../data')
        mkdir('../data')
    end


    %% Setup the loop data
    % dnames = ["hs", "dp", "tp", "wind"];
    yrs = [1979:2009]';
    times = [datetime(1979, 1, 1, 0, 0, 0):hours(3):datetime(2010, 01, 01, 0, 0, 0)]';


    %% Extract the data
    ww3Data = struct('time', NaT(size(times)), 'hs', [], 'tp', [], 'dp', [], 'windu', [], 'windv', [], 'Lats', [], 'Lons', []);

    % loop through all the years to check for data
    for y = 1:length(yrs)
        yr = yrs(y);
        % for each month
        for mon = 1:12
            % get the files for the current year and month
            fnames = dir(sprintf('../rawData/WW3/%i%02i*', yr, mon));

            % avoid missing years
            if isempty(fnames)
                continue;
            end

            % each .mat file
            for f = 1:length(fnames)
                % get data about current file
                fname = fullfile(fnames(f).folder, fnames(f).name);
                fdata = strsplit(fnames(f).name, '_');

                % load and parse the data
                load(fname, 'data', 'lat', 'lon', 'time')
                indt = (time(1) <= times) & (times <= time(end));
                if ~contains(fdata{2}, 'wind')
                    ww3Data.(replace(fdata{2}, '.mat', ''))(:, :, indt) = data;
                else
                    ww3Data.windu(:, :, indt) = data(:, :, 1:(length(data)/2));
                    ww3Data.windv(:, :, indt) = data(:, :, (1+length(data)/2):end);
                end

                % Store some data one time
                if f == 1
                    ww3Data.time(indt) = time;
                    if (y == 1) && (mon == 1)
                        ww3Data.Lats = lat;
                        ww3Data.Lons = lon;
                    end
                end
            end
        end
    end

    % Save the data to the .mat file and return the outputs
    save([OutputFolder '/WW3Data.mat'], 'ww3Data')
    %% end of function %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end










