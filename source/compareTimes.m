function compareTimes(time1, time2)
    % validation function to confirm that the end time is indeed after the start time
    if time1 >= time2
        erid  = 'Extract:compareTimes';
        ermsg = 'The end time must correspond to a date after the given start time.';
        error(erid, ermsg)
    end
end
