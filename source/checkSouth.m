function checkSouth(north, south)
    % validation function to confirm that the southern coordinate is indeed south of the northern coordinate
    if south > north
        erid  = 'Extract:checkSouth';
        ermsg = 'Southern latitudinal coordinate must be less than or equal to the northern coordinate.';
        error(erid, ermsg)
    end
end