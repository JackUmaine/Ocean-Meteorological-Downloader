function confirmLengths(lats, lons)
    % validation function to confirm that the length of the latitude and longitude are the same lengths
    if length(lats) ~= length(lons)
        erid  = 'Extract:confirmLengths';
        ermsg = 'Vectors of latitudes and longitudes must be of the same length.';
        error(erid, ermsg)
    end
end