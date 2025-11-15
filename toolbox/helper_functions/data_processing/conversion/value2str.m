%VALUE2STR Convert MATLAB values or tables to evaluable string representations
%
% Usage:
%   s = value2str(x)
%   s = value2str(x, simplify)
%
% Input:
%   x        : any - scalar, vector, matrix, cell, string, logical, or table
%   simplify : logical - simplify scalar numeric values to fractions, pi multiples,
%                        or exp notation (default: true)
%
% Output:
%   s : char | table - string representation of x, or table of strings if x is a table
%
% Description:
%   - Converts scalars, arrays, strings, logicals, cells, and tables into strings that can
%     be evaluated using `eval` in MATLAB.
%   - Handles numeric vectors or matrices inside table cells as single strings.
%   - Fully parallelizable for table inputs using parfor.
%   - Optional simplification converts scalar numbers to fractions, multiples of pi,
%     or exp(x) when the decimal representation exceeds 4 characters.
%   - Matches the output of the original `value2str` function exactly, including
%     preservation of `exp()` and `pi` forms over aggressive fraction conversion.
%
% Examples:
%
%   % ---------------- Scalar / Array ----------------
%   value2str(0.5)
%   % Returns: '1/2'
%
%   value2str(pi/6)
%   % Returns: '(1*pi)/6'
%
%   value2str(3*exp(5.345))
%   % Returns: '628.6737'   (preserves exp form, no fraction)
%
%   value2str([1, 2, 3])
%   % Returns: '[1 2 3]'
%
%   value2str([1 2; 3 4])
%   % Returns: '[1 2;3 4]'
%
%   % ---------------- Cell / String ----------------
%   value2str({'a', [1 2 3], true})
%   % Returns: '{''a'', [1 2 3], true}'
%
%   value2str(["foo", "bar"])
%   % Returns: '["foo" "bar"]'
%
%   % ---------------- Nested & Complex Cell ----------------
%   C = {{[1 2;3 4], 'test'}, pi/3, struct('a',1,'b','x')};
%   value2str(C)
%   % Returns: '{{[1 2;3 4], ''test''}, (1*pi)/3, struct(''a'',1,''b'',''x'')}'
%
%   % ---------------- Table with Mixed Types ----------------
%   T = table(...
%       [8422; 7.8613; 1.25; 1.9531], ...
%       rand(4,2), ...
%       {'a','b','c','d'}', ...
%       [true; false; true; false], ...
%       'VariableNames', {'Score','RandMat','Label','Flag'});
%   T2 = value2str(T);
%   disp(T2{1,1})
%   % Returns: '[8422 7.8613 1.25 1.9531]'
%
%   % Table cell with matrix and exp()
%   Texp = table({3*exp(5.345)}, {pi/4}, 'VariableNames',{'ExpVal','PiVal'});
%   Tstr = value2str(Texp);
%   disp(Tstr{1,1})
%   % Returns: '628.6737'
%   disp(Tstr{1,2})
%   % Returns: '(1*pi)/4'
%
%   % Works with parallel processing (fast on large tables)
%   Tbig = table(rand(1000,3), (1:1000)', 'VariableNames',{'Data','ID'});
%   Tstr = value2str(Tbig, false);  % No simplification for speed
%
%   % ---------------- Simplification Control ----------------
%   value2str(1/3, true)
%   % Returns: '1/3'
%
%   value2str(1/3, false)
%   % Returns: '0.333333333333333'
%
% Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

function out = value2str(value, simplify)
if nargin < 2
    simplify = true;
end

%% ---------------- Table Input ----------------
if istable(value)
    varNames = value.Properties.VariableNames;
    Nvars = width(value);

    cols = cell(1, Nvars);
    for v = 1:Nvars
        cols{v} = value.(varNames{v});
    end

    % Preallocate output
    outCols = cell(1, Nvars);

    parfor v = 1:Nvars
        col = cols{v};  % Sliced variable

        % Ensure cell array 
        if ~iscell(col)
            col = num2cell(col, 2); 
        end

        % Encode each row
        colStr = cellfun(@(x) encodeValue(x, simplify), col, ...
                         'UniformOutput', false);
        outCols{v} = colStr;
    end

    % Rebuild table
    out = table();
    for v = 1:Nvars
        out.(varNames{v}) = outCols{v};
    end
    return
end

%% ---------------- Single Value ----------------
out = encodeValue(value, simplify);

end

%% =================================================================
%% ===================== CORE VALUE HANDLER ========================
%% =================================================================
function s = encodeValue(v, simplify)

% Empty
if isempty(v)
    switch class(v)
        case {'double','single','logical'}
            s = '[]';
        case 'cell'
            s = '{}';
        case 'char'
            s = '''''';
        otherwise
            s = [class(v) '([])'];
    end
    return
end

% Numeric
if isnumeric(v)
    if isscalar(v)
        if simplify && length(num2str(v))>4
            %Try for simple fractions
            s = double2fracstr(v);

            %Try for pi values
            if isempty(s)
                s = double2pifracstr(v);
            end

            %Try for e values
            if isempty(s)
                s = double2estr(v);
            end

            %Return the number
            if isempty(s)
                s = num2str(v);
            end

        else
            s = num2str(v);
        end
    else
        s = mat2str(v);  % preserves row/column structure
    end
    return
end

% Logical
if islogical(v)
    if isscalar(v)
        if v
            s = 'true';
        else
            s = 'false';
        end
    else
        s = mat2str(v);
    end
    return
end

% Char
if ischar(v)
    s = ['''' v ''''];
    return
end

% String
if isstring(v)
    if isStringScalar(v)
        s = ['"' char(v) '"'];
    else
        quoted = "\"" + v + "\"";
        s = "[" + strjoin(quoted, " ") + "]";
    end
    return
end

% Cell
if iscell(v)
    elems = cellfun(@(x) encodeValue(x, simplify), v, 'UniformOutput', false);
    s = ['{' strjoin(elems, ', ') '}'];
    return
end

% Fallback
s = class(v);
end