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
% Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

function code_str = struct2codestr(mystruct, struct_name)
code_str = [];
fnames = fieldnames(mystruct);
struct_vals = struct2cell(mystruct);

for ii = 1:length(fnames)
    code_str = [code_str struct_name '.' fnames{ii} ' = ' value2str(struct_vals{ii}) ';' newline];
end