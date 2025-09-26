function checkWest(east, west)
    % validation function to confirm that the wesstern coordinate is indeed west of the eastern coordinate
    if west > east
        erid  = 'Extract:checkWest';
        ermsg = 'Western longitudinal coordinate must be less than or equal to the eastern coordinate.';
        error(erid, ermsg)
    end
end