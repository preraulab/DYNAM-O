%VALUE2STR Convert a value to its string representation
%
%   Usage:
%       value_str = value2str(value)
%
%   Input:
%       value: any - input value to be converted to a string -- required
%       simplify: logical - simplify fractions and pi fractions (default:
%       true)
%
%   Output:
%       value_str: char - string representation of the input value
%
%   Example:
%       % Convert numeric array to string
%       value_str = value2str([1, 2, 3]);
%
%       % Convert cell array to string
%       value_str = value2str({'a', 'b', 'c'});
%
% Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

function value_str = value2str(value, simplify)
if nargin<2
    simplify = true;
end

if isempty(value)
    if isnumeric(value) 
        value_str = '[]'; % Empty numeric array
    elseif iscell(value)
        value_str = '{}'; % Empty cell array
    elseif ischar(value)
        value_str = ''''''; % Empty character array
    else % Handle examples like logical([])
        value_str = [class(value) '([])'];
    end
elseif isnumeric(value) && numel(value) > 1
    value_str = mat2strsimplify(value); % Numeric array
elseif isnumeric(value)
    if simplify && length(num2str(value))>4
        %Try for simple fractions
        value_str = double2fracstr(value);

        %Try for pi values
        if isempty(value_str)
            value_str = double2pifracstr(value);
        end

        %Try for e values
        if isempty(value_str)
            value_str = double2estr(value);
        end

        %Return the number
        if isempty(value_str)
            value_str = num2str(value);
        end
    else
        value_str = num2str(value);
    end
elseif islogical(value)
    if value
        value_str = 'true';
    else
        value_str = 'false';
    end
elseif iscell(value)
    % Recurse for all cell elements
    value_str = ['{' strjoin(cellfun(@value2str, value, 'UniformOutput', false), ', ') '}'];
elseif ischar(value)
    value_str = ['''' value '''']; % Char
elseif isstring(value)
    if isStringScalar(value)
     value_str = ['"' char(value) '"'];
    else
        str_str = sprintf('"%s" ',value);
        value_str = ['[' str_str(1:end-1) ']'];
    end
else %Display the type of any unknown class
    value_str = class(value);
end
end


function str = mat2strsimplify(matrix, varargin)
%

%   Copyright 1984-2023 The MathWorks, Inc.

if nargin > 1
    [varargin{:}] = convertStringsToChars(varargin{:});
end

narginchk(1,3);

precision = 15;
precisionSpecified = false;
useclass  = false;

for i = 1:numel(varargin)
    
    if ischar(varargin{i})
        switch lower(varargin{i})
        case 'class'
            useclass = true; 
        otherwise
            error(message('MATLAB:mat2str:InvalidOptionString', varargin{ i }));
        end
    elseif isnumeric(varargin{i})

        precision = varargin{i};
        
        if ~isscalar(precision) || ~isreal(precision) || ~isfinite(precision) || floor(precision) ~= precision || precision < 1
            error(message('MATLAB:mat2str:InvalidPrecision'));   
        end
        
        precisionSpecified = true;
    else
        error(message('MATLAB:mat2str:InvalidOptionType'));    
    end
end

if ~ismatrix(matrix)
    error(message('MATLAB:mat2str:TwoDInput'));
end

enumerationFlag = isenumeration(matrix);

if ~(isnumeric(matrix) || ischar(matrix) || islogical(matrix) || enumerationFlag || isstring(matrix))
    error(message('MATLAB:mat2str:NumericInput'));
end

if enumerationFlag || isstring(matrix) || ischar(matrix)
    useclass = false;
end

[rows, cols] = size(matrix);

if issparse(matrix)
    [i,j,s] = find(matrix);
    str = ['sparse(' mat2strsimplify(i) ', ' mat2strsimplify(j), ', '];
    if useclass
        str = [str mat2strsimplify(s, precision, 'class')];
    else
        str = [str mat2strsimplify(s, precision)];
    end
    str = [str ', ' mat2strsimplify(rows) ', ' mat2strsimplify(cols) ')'];
    return;
end

if ischar(matrix) && ~isempty(matrix)
    values = cell(rows,1); 
    for row=1:rows
        values{row} = matrix(row,:);
    end
    needsConcatenation = rows > 1;

    dangerousPattern  =  '[\0\n-\r]';
    hasDangerousChars = regexp(values, dangerousPattern, 'once');

    needsConcatenation = needsConcatenation | ~isempty([hasDangerousChars{:}]);

    values = replace(values, "'", "''");
    if ~isempty([hasDangerousChars{:}])
        values = regexprep(values, dangerousPattern, "' ${sprintf('char(%d)',$0)} '");
    end

    if needsConcatenation
        str = '[';
    else
        str = '';
    end

    str = [str '''' values{1} ''''];

    for row = 2:rows
        str = [str ';''' values{row} '''']; %#ok 
    end

    if needsConcatenation
        str = [str ']'];
    end

    return;
elseif isstring(matrix)
    
    specialValues  = ["\0"; "\n"; "\v"; "\f"; "\r"];
    
    needsEscape = contains(matrix, compose(specialValues));
    needsEscape = any(needsEscape,'all');
    
    if needsEscape
        specialValues = [specialValues; "\\"];
    else
        specialValues = [];
    end
    
    finalValues = [specialValues; '""'];
    composedValues = compose([specialValues; '"']);
    
    matrix = replace(matrix, composedValues, finalValues);
    matrix = '"' + matrix + '"';
    
    matrix(ismissing(matrix)) = "string(missing)";
    
    if isempty(matrix)
        matrix = "strings(" + join(string(size(matrix)),',') + ")"; 
    elseif ~isscalar(matrix)
        matrix = join(matrix,' ',2);
        matrix = join(matrix,';',1);
        matrix = "[" + matrix + "]"; 
    end
    
    if needsEscape
       matrix = "compose(" + matrix + ")"; 
    end
    
    str = char(matrix);
    return; 
end

if isempty(matrix)
    if enumerationFlag
        str = [class(matrix) '.empty(' int2str(rows) ',' int2str(cols) ')'];
    elseif (rows==0) && (cols==0)
        if ischar(matrix)
            str = '''''';
        else
            str = '[]';
        end
    else
        str = ['zeros(' int2str(rows) ',' int2str(cols) ')'];
    end
    if useclass
        str =  [class(matrix), '(', str, ')'];
    end
    return;
end

if isfloat(matrix) && ~enumerationFlag
    matrix = 0+matrix;  % Remove negative zero
end

numericFormat = "%." + precision + "g";
if class(matrix) == "uint64" && formatNotPreciseEnough(matrix, precision, precisionSpecified)
    numericFormat = "%u";
elseif class(matrix) == "int64" && formatNotPreciseEnough(matrix, precision, precisionSpecified)
    numericFormat = "%d";
end

hasConversion = false;

if enumerationFlag
    values = class(matrix) + "." + string(matrix);
elseif islogical(matrix)
    values = string(matrix);
elseif isreal(matrix)
    % [values, hasConversion] = composeNumber(numericFormat, matrix, useclass);
    values = strings(size(matrix)); 
    for ii = 1:numel(matrix)
        values(ii) = value2str(matrix(ii)); 
    end
else
    realVal = real(matrix);
    imagVal = imag(matrix);

    isFinite = isfinite(imagVal);
    isImagNegative = imagVal < 0;
    isImagNegativeInf = ~isFinite & isImagNegative;

    anyImagNegativeInf = any(isImagNegativeInf,'all');

    if anyImagNegativeInf
        imagVal(isImagNegativeInf) = inf; 
    end

    [realPartStr, realHasConversion] = composeNumber(numericFormat, realVal, useclass);
    [imagPartStr, imagHasConversion] = composeNumber(numericFormat, imagVal, useclass);

    hasConversion = realHasConversion | imagHasConversion;

    imagStr = imagPartStr;

    imagStr( isFinite) = imagStr(isFinite) + "i";
    imagStr(~isFinite) = "1i*" + imagStr(~isFinite);

    imagStr(~isImagNegative)   = "+" + imagStr(~isImagNegative);

    if anyImagNegativeInf
        imagStr(isImagNegativeInf) = "-" + imagStr(isImagNegativeInf);
    end

    imagStr(imagVal == 0) = "";
    
    values = realPartStr + imagStr;

    if any(hasConversion,'all')
        values(hasConversion) = "complex(" + realPartStr(hasConversion) + "," + imagPartStr(hasConversion) + ")";
    end
end

values = join(values,' ',2);
str    = join(values,';',1);

% clean up the end of the string
if ~isscalar(matrix)
    str = "[" + str + "]";
end

if useclass

    isScalarWithConversion = isscalar(matrix) && hasConversion;
    
    if ~isScalarWithConversion
        str =  class(matrix) + "(" + str + ")";
    end
end

str = char(str);

end

function b = isenumeration(m)
    b = ~isempty(enumeration(class(m)));
end

function n = getNumOfDigits(x)
    % Workaround because log10 doesn't support integers
    pows = uint64(10).^uint64(1:20);
    n = find(x <= pows, 1);
end

function tf = formatNotPreciseEnough(matrix, precision, precisionSpecified)
    tf = ~precisionSpecified || precision >= getNumOfDigits(max(abs([real(matrix);imag(matrix)]),[],'all'));
end

function [result, requiresConversion] = composeNumber(fmt, matrix, useclass)

    requiresConversion = (matrix >= flintmax | matrix <= -flintmax) & isinteger(matrix);

    result = compose(fmt,matrix);

    if useclass && any(requiresConversion,'all') && (isa(matrix,'uint64') || isa(matrix,'int64'))
        result(requiresConversion) = class(matrix) + "(" + result(requiresConversion) + ")";
    end
end
