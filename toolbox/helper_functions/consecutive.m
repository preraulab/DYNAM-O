%Returns the consecutive runs
%[cons, inds]=consecutive(data, minsize, val)
%
%Michael J. Prerau, Ph.D. 2013
function [cons, inds]=consecutive(data, minsize, maxsize, val)

cons=[];
inds=[];

if nargin < 4
    val=1;
end

if nargin <2
    minsize=-inf;
end

if nargin <3
    maxsize=inf;
end

if minsize>=maxsize
    error('Min size must be less than max size');
end


[con,ind]=getchunks(data,'-full');

c=1;
for i=1:length(con)
    if (con(i)>=minsize && data(ind(i))==val && con(i)<=maxsize)
        cons(c)=con(i);
        inds{c}=ind(i):ind(i)+con(i)-1;
        c=c+1;
    end
end


function [d, id] = getchunks(a, opt)

%GETCHUNKS Get the number of repetitions that occur in consecutive chunks.
%   C = GETCHUNKS(A) returns an array of n elements, where n is the number
%   of consecutive chunks (2 or more repetitions) in A, and each element is
%   the number of repetitions in each chunk. A can be LOGICAL, any
%   numeric vector, or CELL array of strings. It can also be a character
%   array (see below, for its special treatment).
%
%   Example:
%     A = [1 2 2 3 4 4 4 5 6 7 8 8 8 8 9];
%     getchunks(A)
%       ans =
%           2   3   4
%
%   [C, I] = GETCHUNKS(A) also returns the indices of the beginnings of the
%   chunks.
%
%   GETCHUNKS(A, OPT) when OPT is '-full', includes single-element chunks
%   as well. Default OPT is '-reps' (meaning REPEATING chunks).
%
%   If A is a character array, then it finds words (consecutive
%   non-spaces), returning number of chararcters in each word and the
%   indeces to the beginnings of the words. In this case, OPT has no
%   effect.
%
%   Example:
%     A = 'This is a generic (simple) sentence';
%     [C, I] = getchunks(A)
%       C =
%            4     2     1     7     8     8
%
%       I =
%            1     6     9    11    19    28
%
%   See also HIST, HISTC.

%   Jiro Doke
%   Feb 16, 2006
%

%--------------------------------------------------------------------------
% Error checking
narginchk(1, 2);
if ndims(a) > 2 || min(size(a)) > 1
  error('Input must be a 2-D vector');
end

if nargin < 2
  opt = '-reps';
end

%--------------------------------------------------------------------------
% Process options
switch lower(opt)

  % Include single-element chunks
  case '-full'
    fullList = true;
    if ischar(a);
      fprintf('''-full'' option not applicable with CHAR arrays.\n');
    end
    
  % Only find 2 or more repeating blocks
  case '-reps'
    fullList = false;
    
  otherwise
    error('Unknown option. Allowed option: ''-full'' or ''-reps''');
end

%--------------------------------------------------------------------------
% Convert to row vector for STRFIND
a = a(:)';

%--------------------------------------------------------------------------
% Deal with differet classes
switch class(a)
  
  case 'double'
    % Leave as is
    
  case {'logical', 'uint8', 'int8', 'uint16', 'int16', 'uint32', 'int32', 'single'}
    % Convert to DOUBLE
    a = double(a);
    
  case 'char'
    % Get non-space locations
    a = ~isspace(a);  
  
  case 'cell'
    % Convert cell array of strings into unique numbers
    if all(cellfun('isclass', a, 'char'))
      [a, a, a] = unique(a);
    else
      error('Cell arrays must be array of strings.');
    end
    
  otherwise
    error('Invalid type. Allowed type: CHAR, LOGICAL, NUMERIC, and CELL arrays of strings.');
end

%--------------------------------------------------------------------------
% Character arrays (now LOGICAL) are dealt differently
if islogical(a)
  % Pad the array
  a  = [false, a, false];

  % Here's a very convoluted engine
  b  = diff(a);
  id = strfind(b, 1);
  d  = strfind(b, -1) - id;

%--------------------------------------------------------------------------
% Everything else (numeric arrays) are processed here
else
  % Pad the array
  a                 = [NaN, a, NaN];

  % Here's more convoluted code
  b                 = diff(a);
  b1                = b;  % to be used in fullList (below)
  ii                = true(size(b));
  ii(strfind(b, 0)) = false;
  b(ii)             = 1;
  c                 = diff(b);
  id                = strfind(c, -1);
  
  % Get single-element chunks also
  if fullList
  
    % And more convoluted code
    b1(id)          = 0;
    ii2             = find(b1(1:end-1));
    d               = [strfind(c, 1) - id + 1, ones(1, length(ii2))];
    id              = [id,ii2];
    [id,tmp]        = sort(id);
    d               = d(tmp);
    
  else
    d               = strfind(c, 1) - id + 1;
  end
end