%STRUCT2CODESTR Generate MATLAB code string from a structure
%
%   Usage:
%       code_str = struct2codestr(mystruct, struct_name)
%
%   Input:
%       mystruct: struct - input structure to be converted to code string -- required
%       struct_name: char - name of the structure -- required
%
%   Output:
%       code_str: char - MATLAB code string representing the structure
%
%   Example:
%       % Generate code string for a structure
%       mystruct.field1 = 10;
%       mystruct.field2 = 'hello';
%       struct_name = 'mystruct';
%       code_str = struct2codestr(mystruct, struct_name);
%
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
%   GITHUB     https://github.com
%
%   ATTRIBUTION
%   If you use this toolbox, please cite:
%
%   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
function code_str = struct2codestr(mystruct, struct_name)
code_str = [];
fnames = fieldnames(mystruct);
struct_vals = struct2cell(mystruct);

for ii = 1:length(fnames)
    code_str = [code_str struct_name '.' fnames{ii} ' = ' value2str(struct_vals{ii}) ';' newline];
end