function renderResultsBrowserPreviewCsv(app, p)
    % renderResultsBrowserPreviewCsv  Render a CSV in the preview
    %   pane. If the file starts with a `# DYNAM-O parametric fit`
    %   comment header (written by writeParamfitCsv), shows a
    %   tabbed layout that mirrors the .mat paramfit preview:
    %     - "params"   : the params table (sortable)
    %     - "fit info" : gof + fitobj coefs + background plane +
    %                    unit_row + bins, formatted as a text
    %                    dump (matches the .mat fit info tab)
    %   Plain CSVs render as a single sortable table.
    delete(app.ResultsBrowserPreviewBody.Children);

    headerLines = local_peekCommentHeader(p);
    isParamfit  = ~isempty(headerLines) && ...
                  contains(headerLines{1}, 'DYNAM-O parametric fit');

    if isParamfit
        hdr     = local_parseHeaderToStruct(headerLines);
        paramsT = readtable(p, 'CommentStyle','#');

        tg = uitabgroup(app.ResultsBrowserPreviewBody, ...
            'Units','normalized','Position',[0 0 1 1]);

        % --- params table tab ---
        tP = uitab(tg, 'Title', sprintf('params (%d×%d)', ...
            height(paramsT), width(paramsT)));
        utp = uitable(tP);
        utp.Units    = 'normalized'; utp.Position = [0 0 1 1];
        utp.Data     = paramsT;
        utp.ColumnSortable = true;

        % --- fit info tab (text dump, matches the .mat preview) ---
        tG = uitab(tg, 'Title', 'fit info');
        ta = app.makeFillTextArea(tG);
        ta.Value = local_buildFitInfoLines(hdr);
    else
        T = readtable(p);
        ut = uitable(app.ResultsBrowserPreviewBody);
        ut.Units    = 'normalized';
        ut.Position = [0 0 1 1];
        ut.Data     = T;
        ut.ColumnSortable = true;
    end

    % --- nested helpers ---
    function L = local_peekCommentHeader(filename)
        L = {};
        fid = fopen(filename, 'r');
        if fid < 0, return, end
        cu = onCleanup(@() fclose(fid)); %#ok<NASGU>
        for k = 1:50
            ln = fgetl(fid);
            if ~ischar(ln), break, end
            s = strtrim(ln);
            if startsWith(s, '#')
                L{end+1} = s; %#ok<AGROW>
            elseif isempty(s)
                % Tolerate blank lines inside a header block
                continue
            else
                break
            end
        end
    end
    function H = local_parseHeaderToStruct(lines)
        % Parse '# key: value' lines into a struct. JSON arrays
        % decode to numeric / cellstr; scalars to double; the
        % rest stay char.
        H = struct();
        for k = 1:numel(lines)
            s = regexprep(lines{k}, '^#\s*', '');
            if isempty(s), continue, end
            idx = strfind(s, ':');
            if isempty(idx), continue, end
            key = strtrim(s(1:idx(1)-1));
            val = strtrim(s(idx(1)+1:end));
            fld = matlab.lang.makeValidName(key);
            if startsWith(val, '[') || startsWith(val, '"')
                try, H.(fld) = jsondecode(val); continue, catch, end
            end
            n = str2double(val);
            if ~isnan(n) || strcmpi(val, 'nan')
                H.(fld) = n;
            else
                H.(fld) = val;
            end
        end
    end
    function L = local_buildFitInfoLines(H)
        % Mirror of the .mat preview's "fit info" tab: a flat
        % text dump grouped by section. Sections are skipped
        % silently when the corresponding header field is
        % missing — older paramfit CSVs without fitobj coefs
        % still get a useful gof/background block.
        L = {};
        if isfield(H,'fit_type') || isfield(H,'n_modes') || isfield(H,'version')
            L = [L; {'--- summary ---'}];
            if isfield(H,'fit_type'), L = [L; {sprintf('  fit_type: %s', char(string(H.fit_type)))}]; end
            if isfield(H,'n_modes'),  L = [L; {sprintf('  n_modes : %g', H.n_modes)}]; end
            if isfield(H,'version'),  L = [L; {sprintf('  version : %g', H.version)}]; end
            L = [L; {''}];
        end
        gofKeys  = {'sse','rsquare','dfe','adjrsquare','rmse'};
        gofPres  = false;
        for kk = 1:numel(gofKeys)
            if isfield(H, ['gof_' gofKeys{kk}]), gofPres = true; break, end
        end
        if gofPres
            L = [L; {'--- gof ---'}];
            for kk = 1:numel(gofKeys)
                f = ['gof_' gofKeys{kk}];
                if isfield(H, f)
                    L = [L; {sprintf('  %-10s: %.6g', gofKeys{kk}, H.(f))}];
                end
            end
            L = [L; {''}];
        end
        if isfield(H,'fitobj_coefnames') && isfield(H,'fitobj_coefvalues')
            cn = H.fitobj_coefnames;
            cv = H.fitobj_coefvalues;
            if iscell(cn) || (isstring(cn) && numel(cn) > 1)
                cn = cellstr(cn);
            end
            if isnumeric(cv), cv = double(cv); end
            if numel(cn) == numel(cv)
                L = [L; {'--- fitobj coefficients ---'}];
                for kk = 1:numel(cn)
                    L = [L; {sprintf('  %-12s: %.6g', cn{kk}, cv(kk))}];
                end
                L = [L; {''}];
            end
        end
        bgKeys = {'background_xxx','background_yyy','background_zzz','unit_row'};
        bgPres = any(cellfun(@(k) isfield(H,k), bgKeys));
        if bgPres
            L = [L; {'--- background plane ---'}];
            for kk = 1:numel(bgKeys)
                if isfield(H, bgKeys{kk})
                    L = [L; {sprintf('  %-12s: %.6g', bgKeys{kk}, H.(bgKeys{kk}))}];
                end
            end
            L = [L; {''}];
        end
        if isfield(H,'freq_bins') || isfield(H,'SOpower_bins') || isfield(H,'SOphase_bins')
            L = [L; {'--- bins ---'}];
            if isfield(H,'freq_bins')
                fb = H.freq_bins(:).';
                L = [L; {sprintf('  freq_bins (n=%d, range=[%.3g, %.3g])', ...
                    numel(fb), min(fb), max(fb))}];
                L = [L; splitlines(string(evalc('disp(fb)')))];
            end
            if isfield(H,'SOpower_bins')
                sb = H.SOpower_bins(:).';
                L = [L; {sprintf('  SOpower_bins (n=%d, range=[%.3g, %.3g])', ...
                    numel(sb), min(sb), max(sb))}];
                L = [L; splitlines(string(evalc('disp(sb)')))];
            end
            if isfield(H,'SOphase_bins')
                sb = H.SOphase_bins(:).';
                L = [L; {sprintf('  SOphase_bins (n=%d, range=[%.3g, %.3g])', ...
                    numel(sb), min(sb), max(sb))}];
                L = [L; splitlines(string(evalc('disp(sb)')))];
            end
        end
        L = cellstr(L);
    end
end
