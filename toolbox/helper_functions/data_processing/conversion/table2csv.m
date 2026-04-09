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
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://harvard.edu
%   GITHUB     https://github.com
%
%   CITATION
%   If you use this toolbox, please cite:
%
%   He, M., Prerau, M. J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%    in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%    for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================

    enc = value2str(T,false);  % Encode table values to strings

    % Add headers
    C = [T.Properties.VariableNames; table2cell(enc)];

    % Write CSV safely, preserving all digits
    writecell(C, filename);
end
