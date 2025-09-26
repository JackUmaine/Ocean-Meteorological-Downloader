function mustBeBeforeToday(time, dt)
    if time > datetime('today') - caldays(dt)
        erid  = 'Extract:mustBeBefore';
        ermsg = 'Time must correspond to a date one month before todays date.';
        error(erid, ermsg)
    end
end