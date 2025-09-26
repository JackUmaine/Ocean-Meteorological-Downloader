% makes sure the the user set times are within the times that are accetable for the sources
function [timeS, timeE] = checkTimes(timeS, timeE, name)
    % set the comp times based on source
    switch name
        case 'ERA5'
            tscomp = datetime(1940, 1, 1, 0, 0, 0);
            tecomp = datetime('today') - calmonths(1);
        case 'HYCOM'
            tscomp = datetime(1994, 1, 1, 0, 0, 0);
            tecomp = datetime(2015, 12, 31, 0, 0, 0);
        case 'NDBC'
            tscomp = datetime(1979, 1, 1, 0, 0, 0);
            tecomp = datetime(2020, 12, 31, 0, 0, 0);
        case 'MHKIT'
            tscomp = datetime(1979, 1, 1, 0, 0, 0);
            tecomp = datetime(2020, 12, 31, 0, 0, 0);
    end

    % compare the times and return bands if outsides ranges
    if timeS < tscomp
        timeS = tscomp;
    end
    if timeE > tecomp
        timeE = tecomp;
    end
end