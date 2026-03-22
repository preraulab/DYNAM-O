function table2csv(T, filename)
%TABLE2CSV  Save table to CSV with full numeric precision and eval-safe encoding
%
% Usage:
%   table2csv(T, filename)
%
% Notes:
%   - Doubles are stored with full precision (17 digits)
%   - Singles are stored with full precision and cast back upon load
%   - Vectors/matrices are preserved as strings
%   - Works with scalars, strings, logicals, cells, and tables

    enc = value2str(T,false);  % Encode table values to strings

    % Add headers
    C = [T.Properties.VariableNames; table2cell(enc)];

    % Write CSV safely, preserving all digits
    writecell(C, filename);
end
