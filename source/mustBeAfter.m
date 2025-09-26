function mustBeAfter(timeStr, time)
    % validation function to confirm that the given time is within the bounds
    yr = str2double(timeStr(1:4));
    mo = str2double(timeStr(5:6));
    da = str2double(timeStr(7:8));
    if time < datetime(yr, mo, da, 0, 0, 0)
        erid  = 'Extract:mustBeAfter';
        ermsg = 'Time must correspond to a date after %s.';
        error(erid, ermsg, datetime(yr, mo, da, 0, 0, 0))
    end
end