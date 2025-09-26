function ExtractWW3(North, East, South, West, StartTime, EndTime)
    %% ExtractWW3
    %   A 30-year wave climatology has been generated with the NOAA WAVEWATCH III® using the Ardhuin et al (2010)
    %   physics package, 15 regular lat-lon grids, and the NCEP Climate Forecast System Reanalysis and Reforecast
    %   (CFSRR) homogeneous dataset of hourly high-resolution winds. The time period covers from 1979 through 2009.
    %
    %       This function extracts data from individual .grib2 files hosted on the polar.ncep.noaa.gov website. The data
    %       will be extracted from points the closest to the inputs values for both the temporal and spatial grids of
    %       the WatchWatch III data. For more info visit:
    %       https://polar.ncep.noaa.gov/waves/hindcasts/nopp-phase2.php
    %
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
    %           A series of .mat output file in the rawData/WW3 subdirectory.
    %
    %
    %       Created: Jun 11, 2024
    %       Edited:  Jun 14, 2024
    %


    %% Validataion
    arguments
        North (1,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(North,-90,90)}
        East (1,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(East,-180,180)}
        South (1,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(South,-90,90),checkSouth(North,South)} = North
        West (1,1) double {mustBeNonempty,mustBeFinite,mustBeNonNan,mustBeReal,mustBeInRange(West,-180,180),checkWest(East,West)} = East
        StartTime (1,1) datetime {mustBeAfter('19790101',StartTime),mustBeBefore('20091231',StartTime)} = datetime(1979, 1, 1, 0, 0, 0)
        EndTime (1,1) datetime {mustBeBefore('20091231',EndTime),compareTimes(StartTime,EndTime)} = datetime(2009, 12, 31, 0, 0, 0)
    end


    %% Set timeout for websave
    opts = weboptions('Timeout', 60);


    %% Make output directory
    % always make this check, we don't know what order the extractors have been called in.
    if ~isfolder('../rawData')
        mkdir('../rawData')
    end

    % output directory for the the raw data during download.
    if ~isfolder('../rawData/WW3')
        mkdir('../rawData/WW3')
    end


    %% Process start and end time
    % ask the user what years they wish to download
    % we will conver them to datetime so we can manipulate all the information better for writing the links and the
    % filenames later.
    yrs = [1979:2009]';
    indy1 = find(yrs == year(StartTime));
    indy2 = find(yrs == year(EndTime));
    yrs = yrs(indy1:indy2);


    %% Setup the data stream names
    dnames = ["hs", "dp", "tp", "wind"];


    %% Download and process the data
    % ww3Data = struct('time', times, 'hs', [], 'tp', [], 'dp', [], 'windu', [], 'windv', [], 'Lats', [], 'Lons', []);
    % for each year
    for y = 1:length(yrs)
        yr = yrs(y);
        % for each month
        for mon = 1:12
            % avoid data we already downloaded
            if ~isempty(dir(sprintf('../rawData/WW3/%i%02i*', yr, mon)))
                continue;
            end

            % parallel download all the files
            parfor n = 1:length(dnames)
                vname = dnames(n);
                % save the file
                url   = sprintf('https://polar.ncep.noaa.gov/waves/hindcasts/nopp-phase2/%i%02i/gribs/multi_reanal.ecg_10m.%s.%i%02i.grb2', yr, mon, vname, yr, mon);
                fname = sprintf('../temp/%s.grib2', vname);
                try
                    websave(fname, url, opts);
                catch
                    % print something if a download fails
                    % TODO: Gather data that fails and attempt to redownload the files...
                    fprintf('%s failed for: %i, %i', vname, yr, mon);
                end
                savename = sprintf('../rawData/WW3/%i%02i_%s.mat', yr, mon, vname);

                % Get metadata and open the file
                info = georasterinfo(fname);
                metadata = info.Metadata;
                time = metadata.ValidTime;
                [ww3Data, r] = readgeoraster(fname, Bands='all');

                % process the spatial grid from the file
                lats = flip([r.LatitudeLimits(1):r.SampleSpacingInLatitude:r.LatitudeLimits(2)]);
                lons = [r.LongitudeLimits(1):r.SampleSpacingInLongitude:r.LongitudeLimits(2)];

                % get the row and columns indexes for the data
                indla = (South-r.SampleSpacingInLatitude <= lats) & (lats <= North+r.SampleSpacingInLatitude);
                indlo = (West-r.SampleSpacingInLongitude <= lons) & (lons <= East+r.SampleSpacingInLongitude);

                % make missing data NaN
                m = info.MissingDataIndicator;
                ww3Data = standardizeMissing(ww3Data, m);

                % parse and store the data
                ww3Data = ww3Data(indla, indlo, :);
                lat = lats(indla);
                lon = lons(indlo);
                sv = struct('data', ww3Data, 'lat', lat, 'lon', lon, 'time', time);

                % save the data
                save(savename, '-fromstruct', sv)
            end
        end
    end
    %% end of function %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end



















%% LEGACY CODE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     % worldmap(ww3Data, r)
%     % mlabel off
%     % plabel off
%     % geoshow(a,r,DisplayType="surface")
%     % drawnow()