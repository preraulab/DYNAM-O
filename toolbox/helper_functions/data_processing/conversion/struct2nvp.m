function vargout = struct2nvp(myStruct)
%STRUCT2NVP Converts a structure to name-value pairs string.
%
%   STR = STRUCT2NVP(MYSTRUCT) converts the fields and values of the input
%   structure MYSTRUCT into a name-value pairs string and returns it as STR.
%   The fields are separated by commas and each name-value pair is of the
%   form 'fieldname, value'. The values are converted to strings according
%   to their data type.
%
%   Inputs:
%     myStruct: Input structure to convert to name-value pairs string.
%
%   Output:
%     str: Name-value pairs string representing the input structure.
%
%   Example:
%         myStruct.field1 = 23;
%         myStruct.field2 = 1:5;
%         myStruct.field3 = 'Testing123';
%         myStruct.field4 = {'apple', 42, [], {'a','b','c'}};
%         myStruct.field5 = [];
%         myStruct.field6 = {};
% 
%         struct_str = struct2nvp(myStruct);
%         disp(struct_str)
%
%   See also NAMEDARGS2CELL
% 
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
fields = fieldnames(myStruct);
vargout = '';
for ii = 1:numel(fields)
    field = fields{ii};
    valueStr = value2str(myStruct.(field));
    if ii < numel(fields)
        vargout = [vargout '''' field ''', ' valueStr ', ']; %#ok<*AGROW>
    else
        vargout = [ vargout '''' field ''', ' valueStr];
    end
end

% Convert element value to string
    function value_str = value2str(value)
        if isempty(value)
            if isnumeric(value)
                value_str = '[]'; % Empty numeric array
            elseif iscell(value)
                value_str = '{}'; % Empty cell array
            elseif ischar(value)
                value_str = ''''''; % Empty character array
            end
        elseif isnumeric(value) && numel(value) > 1
            value_str = mat2str(value); % Numeric array
        elseif isnumeric(value) || islogical(value)
            value_str = num2str(value); % Numeric or logical scalar
        elseif iscell(value)
            % Recurse for all cell elements
            value_str = ['{' strjoin(cellfun(@value2str, value, 'UniformOutput', false), ', ') '}'];
        else
            value_str = ['''' value '''']; % String scalar or other types
        end
    end
end
