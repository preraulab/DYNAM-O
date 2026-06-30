function hdr = parseParamfitCsvHeader(~, filename)
    % parseParamfitCsvHeader  Parse the `#`-prefixed metadata block
    %   at the top of a paramfit CSV.
    %
    %   Mirrors the recipe documented in README.md (parametric-fit CSV
    %   section). Returns a struct keyed by makeValidName-cleaned
    %   header tokens, with JSON arrays decoded and numeric scalars
    %   coerced to double.
    %
    %   Common fields produced (when present in the file):
    %     background_{PowSlope,FreqSlope,Offset} (power) /
    %     background_{SinAmp,SinPhase,Offset} (phase)
    %     (legacy: background_xxx, background_yyy, background_zzz)
    %     unit_row, n_modes, fit_type
    %     gof_sse, gof_rsquare, gof_dfe, gof_adjrsquare, gof_rmse
    %     freq_bins, SOpower_bins / SOphase_bins
    %     fitobj_coefnames, fitobj_coefvalues
    %
    %   Use in tandem with `readtable(filename, 'CommentStyle', '#')`
    %   to load the params block; this helper is the header companion.
    %
    %   See also: writeParamfitCsv, loadParamfit.

    hdr = struct();
    fid = fopen(filename, 'r');
    if fid < 0
        return
    end
    cleaner = onCleanup(@() local_safe_fclose(fid)); %#ok<NASGU>

    while true
        L = fgetl(fid);
        if ~ischar(L), break, end
        Ls = strtrim(L);
        if isempty(Ls)
            % skip — blank lines inside the preamble are tolerated
            continue
        end
        if ~startsWith(Ls, '#')
            % first non-comment line is the table header — stop
            break
        end
        tok = regexp(L, '^#\s*([^:]+):\s*(.*)$', 'tokens', 'once');
        if numel(tok) ~= 2, continue, end
        key = matlab.lang.makeValidName(tok{1});
        val = strtrim(tok{2});
        if isempty(val)
            hdr.(key) = '';
            continue
        end
        % JSON arrays + JSON strings come through verbatim.
        if startsWith(val, '[') || startsWith(val, '"')
            try
                hdr.(key) = jsondecode(val);
            catch
                hdr.(key) = val;
            end
            continue
        end
        % Numeric scalar (incl. NaN/Inf).
        n = str2double(val);
        if ~isnan(n) || strcmpi(val, 'nan')
            hdr.(key) = n;
        else
            hdr.(key) = val;
        end
    end
end


function local_safe_fclose(f)
    try
        if f >= 0
            fclose(f);
        end
    catch
    end
end
