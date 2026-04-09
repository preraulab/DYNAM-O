function T = csv2table(filename)
%CSV2TABLE  Load CSV saved by table2csv and decode values with type/precision preservation
%
% Usage:
%   T = csv2table(filename)
%
% Features:
%   - Double and single precision restored
%   - Numeric vectors/matrices auto-collapsed
%   - Mixed-type columns remain as cells
%   - Parallel decoding for large tables
%   - Single precision detected per column heuristically
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

%% ------------------- Read CSV as raw text -------------------
opts = detectImportOptions(filename);
opts = setvartype(opts, repmat({'char'}, 1, numel(opts.VariableNames)));
Raw = readtable(filename, opts);

varNames = Raw.Properties.VariableNames;
Nvars = width(Raw);
Nrows = height(Raw);

% Extract each column as cell array of chars
cols = cell(1, Nvars);
for v = 1:Nvars
    cols{v} = Raw.(varNames{v});  % Nx1 cell
end

%% ------------------- Decode each column in parallel -------------------
outCols = cell(1, Nvars);
parfor v = 1:Nvars
    col = cols{v};
    decoded = cell(Nrows,1);
    for r = 1:Nrows
        decoded{r} = decodeValueStr(col{r});
    end
    outCols{v} = decoded;
end

%% ------------------- Auto-collapse numeric columns -------------------
T = table();
for v = 1:Nvars
    col = outCols{v};

    % Case 1: all numeric scalars
    if all(cellfun(@(x) isnumeric(x) && isscalar(x), col))
        % Detect single precision once per column
        strs = cellfun(@(x) sprintf('%.17g', x), col, 'UniformOutput', false);
        if all(cellfun(@(s) length(regexprep(s,'[^0-9]','')) <= 7, strs))
            nums = cellfun(@(x) single(x), col);
        else
            nums = cellfun(@(x) x, col);
        end
        T.(varNames{v}) = nums;

    % Case 2: numeric row vectors of same length → matrix
    elseif all(cellfun(@(x) isnumeric(x) && isrow(x), col)) && ...
           isscalar(unique(cellfun(@numel,col)))
        mat = vertcat(col{:});
        % Detect single precision once per column
        strs = cellfun(@(x) sprintf('%.17g', x), col, 'UniformOutput', false);
        if all(cellfun(@(s) length(regexprep(s,'[^0T-9]','')) <= 7, strs))
            mat = single(mat);
        end
        T.(varNames{v}) = mat;

    % Case 3: heterogeneous or mixed-type → keep as cell array
    else
        T.(varNames{v}) = col;
    end
end

end


%% ------------------- Decode individual string -------------------
function val = decodeValueStr(s)
% Convert string from value2str back to MATLAB value
    s = strtrim(s);

    if strcmp(s,'') || strcmp(s,'[]')
        val = [];
        return;
    end
    if strcmp(s,'{}')
        val = {};
        return;
    end
    if strcmp(s, '''''')
        val = '';
        return;
    end

    try
        val = eval(s);
    catch
        val = s;
    end
end
