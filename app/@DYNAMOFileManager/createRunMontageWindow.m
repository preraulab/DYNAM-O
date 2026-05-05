function createRunMontageWindow(app)
% createRunMontageWindow  Build the Channel & Reference Composer
%   ("run montage" picker). Scans every loaded EDF file's header for
%   available channel labels and per-file sampling rates, then opens a
%   non-modal three-column dialog where the user assembles the output
%   channel set + named references that the upcoming batch run will use.
%
%   LEFT  : Available Channels table (read-only, sourced from EDF scan).
%   MID   : button stack (Add / Remove / Rereference / Custom) operating
%           on the Output Channels table.
%   RIGHT : editable Output Channels table on top, draggable splitter,
%           editable References table below.
%
%   Triggered by the "View Channels" button on the Setup tab via the
%   thin viewChannelsButtonPushed shim. OK validates and commits to
%   app properties; Cancel discards.

    if isempty(app.DataList)
        uialert(app.UIFigure, ...
            'No EDF files loaded. Load at least one file first.', ...
            'Error', 'Icon', 'error');
        return
    end

    nFiles = length(app.DataList);

    % chan_map: label -> {file_index_array, fs_array}
    % Tracks which files contain each channel and at what sample rate.
    % EDF header reads are fast — no progress dialog. The composer
    % is built inline; users were finding the popup waitbar
    % distracting for what amounts to a sub-second scan in the
    % typical case.
    chan_map = containers.Map('KeyType','char','ValueType','any');

    for ii = 1:nFiles
        try
            [~, signalHeader] = read_EDF(app.DataList{ii});
            for jj = 1:length(signalHeader)
                lbl = strtrim(signalHeader(jj).signal_labels);
                fs  = signalHeader(jj).sampling_frequency;
                if isKey(chan_map, lbl)
                    entry = chan_map(lbl);
                    entry{1}(end+1) = ii;
                    entry{2}(end+1) = fs;
                    chan_map(lbl) = entry;
                else
                    chan_map(lbl) = {ii, fs};
                end
            end
        catch ME
            warning('Failed to read file: %s\n%s', app.DataList{ii}, ME.message);
        end
    end

    if isempty(chan_map)
        uialert(app.UIFigure, ...
            'No channel labels found in loaded EDF files.', ...
            'Warning', 'Icon', 'warning');
        return
    end

    % Build sorted table data: {channel, fs_string, file_count_string}
    % Also build fsByLabel: label -> Fs (scalar) or NaN if mixed
    % across files. When resampling is enabled, every label maps to
    % the target rate (the resampler runs before any composer math
    % does, so downstream operations see a single uniform rate).
    all_edf_labels = sort(keys(chan_map));
    nChans = numel(all_edf_labels);
    tableData = cell(nChans, 3);
    resample_on = ~isempty(app.ResampleSwitch) && ...
        logical(app.ResampleSwitch.Value);
    if resample_on
        target_fs = app.ResampleFsEditField.Value;
    end
    fsByLabel = containers.Map('KeyType','char','ValueType','double');
    for ii = 1:nChans
        lbl   = all_edf_labels{ii};
        entry = chan_map(lbl);
        ufreqs  = unique(entry{2});
        if resample_on
            fsByLabel(lbl) = target_fs;
            freqStr = sprintf('%g Hz (resampled)', target_fs);
        else
            if numel(ufreqs) == 1
                fsByLabel(lbl) = ufreqs;
            else
                fsByLabel(lbl) = NaN;
            end
            freqStr = [strjoin(arrayfun(@(f) sprintf('%g', f), ufreqs, 'UniformOutput', false), ' / ') ' Hz'];
        end
        fileStr = sprintf('%d / %d', numel(entry{1}), nFiles);
        tableData{ii,1} = lbl;
        tableData{ii,2} = freqStr;
        tableData{ii,3} = fileStr;
    end

    % ============================================================
    % CHANNEL & REFERENCE COMPOSER (three-column layout)
    % ============================================================
    % LEFT  : Available Channels (full height). Double-click a
    %         row to add it as a passthrough output channel.
    % MID   : vertical button stack — Add, Remove, Rereference,
    %         Custom — operating on Output Channels.
    % RIGHT : Output Channels on top, draggable row splitter,
    %         References below with their own button row.
    %         References are smaller by default (most users
    %         have 0–2 of them) and can be expanded by dragging
    %         the splitter.
    %
    % Both editable tables use CSSuiTable's ColumnEditable +
    % CellEditCallback. References and Output Channels are
    % rebuilt from the table cell values on every edit so the
    % underlying cell-of-strings (refsState / chansState) stays
    % canonical and validation runs on every keystroke commit.

    % Seed dialog state from current app properties so reopening
    % preserves prior work.
    refsState  = app.ReferenceList(:)';
    if isempty(refsState), refsState = {}; end
    chansState = app.ChannelList(:)';
    if isempty(chansState), chansState = {}; end

    % Track selections in each table for the action buttons.
    availSelectedRows = [];
    refSelectedRows   = [];
    chanSelectedRows  = [];

    ss = get(0, 'ScreenSize');
    dW = 1180; dH = 720;
    % Non-modal so the user can adjust other parts of the batch
    % (file list, output dir, staging columns) while the
    % composer is open. The closure over `app` keeps the
    % dialog wired to the live app instance regardless of
    % focus changes.
    d = uifigure('Name', 'Configure Channels & References', ...
        'Position', [(ss(3)-dW)/2, (ss(4)-dH)/2, dW, dH]);
    app.trackChildWindow(d);

    outer = uigridlayout(d);
    outer.RowHeight    = {'1x', 26, 44};
    outer.ColumnWidth  = {'1x', 150, '1.4x'};
    outer.Padding      = [10 10 10 10];
    outer.RowSpacing   = 8;
    outer.ColumnSpacing= 10;

    % ---- COL 1: Available Channels (top), splitter,
    %             Create Reference (bottom) ----
    leftCol = uigridlayout(outer);
    leftCol.Layout.Row    = 1;
    leftCol.Layout.Column = 1;
    leftCol.RowHeight     = {'2x', 8, '1x'};
    leftCol.ColumnWidth   = {'1x'};
    leftCol.Padding       = [0 0 0 0];
    leftCol.RowSpacing    = 6;

    availPanel = uigridlayout(leftCol);
    availPanel.Layout.Row    = 1;
    availPanel.Layout.Column = 1;
    availPanel.RowHeight  = {30, '1x'};
    availPanel.ColumnWidth= {'1x'};
    availPanel.Padding    = [0 0 0 0];
    availPanel.RowSpacing = 4;
    CSSuiLabel(availPanel, 'Style', app.AppStyle, ...
        'Text', 'AVAILABLE CHANNELS', ...
        'FontWeight', '700', ...
        'FontSize', app.FontSizeTitle, ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top');
    availTable = CSSuiTable(availPanel, ...
        'Data', tableData, ...
        'ColumnName', {'Channel', 'Fs (Hz)', 'Files'}, ...
        'ColumnWidth', [180, 150, 80], ...
        'Style', app.AppStyle, ...
        'SelectionType', 'row', ...
        'SelectionChangedFcn', @(s,e) onAvailSelect(e), ...
        'DoubleClickFcn', @(s,e) onAvailDoubleClick(e));
    availTable.HTMLComponent.Tooltip = ['Channels found in the loaded EDF files. ' ...
        'Double-click a row to add it as a passthrough output, or select one or more ' ...
        'rows (Ctrl/Shift-click) to use as sources for the middle-column buttons.'];

    % --- Splitter between Available Channels and Create Reference ---
    % uipanel with a ButtonDownFcn that captures the figure's
    % mouse-motion / mouse-up callbacks for live drag. Heights
    % are computed in pixels (not flex units) during drag so
    % the user feels a 1:1 response.
    splitterDrag = struct('active', false, 'startY', 0, ...
        'startH1', 0, 'totalH', 0, ...
        'origMotion', [], 'origUp', [], 'origPointer', '');
    splitterPanel = uipanel(leftCol, ...
        'BackgroundColor', [0.82 0.84 0.88], ...
        'BorderType', 'none');
    splitterPanel.Layout.Row    = 2;
    splitterPanel.Layout.Column = 1;
    splitterPanel.ButtonDownFcn = @(~,~) beginSplitDrag();

    refPanel = uigridlayout(leftCol);
    refPanel.Layout.Row    = 3;
    refPanel.Layout.Column = 1;
    refPanel.RowHeight  = {30, '1x', 44};
    refPanel.ColumnWidth= {'1x'};
    refPanel.Padding    = [0 0 0 0];
    refPanel.RowSpacing = 4;
    CSSuiLabel(refPanel, 'Style', app.AppStyle, ...
        'Text', 'CREATE REFERENCE', ...
        'FontWeight', '700', ...
        'FontSize', app.FontSizeTitle, ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top');
    % Empty-state hint and the references table share the same
    % grid cell. refresh() toggles their HTMLComponent.Visible
    % so only one is shown at a time: textarea while
    % refsState is empty, table once the user adds a reference.
    refEmptyHelp = CSSuiTextArea(refPanel, ...
        'Style', app.AppStyle, ...
        'Editable', false, ...
        'WordWrap', true, ...
        'Value', sprintf(['Use the buttons below to create and name a new reference.\n\n' ...
                          'Then select channels above and click Rereference to ' ...
                          'subtract this reference from each selected channel.']));
    refEmptyHelp.Layout.Row    = 2;
    refEmptyHelp.Layout.Column = 1;
    refTable = CSSuiTable(refPanel, ...
        'Data', refRowsToTable(refsState), ...
        'ColumnName', {'Name', 'Expression'}, ...
        'ColumnWidth', [80, 280], ...
        'ColumnEditable', [true false], ...
        'CellEditCallback', @(s,e) onRefCellEdit(e), ...
        'Style', app.AppStyle, ...
        'SelectionType', 'row', ...
        'SelectionChangedFcn', @(s,e) onRefSelect(e));
    refTable.Layout.Row    = 2;
    refTable.Layout.Column = 1;
    refTable.HTMLComponent.Tooltip = ['Defined references. Click a Name cell to rename ' ...
        'the reference; the Expression is read-only — to change it, remove the row and ' ...
        're-add it with one of the buttons below. Drag the divider above to give ' ...
        'this section more room.'];
    refBtnRow = uigridlayout(refPanel);
    refBtnRow.Layout.Row    = 3;
    refBtnRow.RowHeight     = {44};
    refBtnRow.ColumnWidth   = {'1x', '1x', '1x', '1x'};
    refBtnRow.Padding       = [0 0 0 0];
    refBtnRow.ColumnSpacing = 6;
    refABMinusBtn = CSSuiButton(refBtnRow, 'Style', app.AppStyle, ...
        'Text', 'A − B', ...
        'ButtonPushedFcn', @(s,e) addRefABMinus());
    refABMinusBtn.HTMLComponent.Tooltip = ['Add a difference reference (e.g., M1 − M2). ' ...
        'Opens a small dialog to pick the two channels.'];
    refMeanBtn = CSSuiButton(refBtnRow, 'Style', app.AppStyle, ...
        'Text', 'Mean', ...
        'ButtonPushedFcn', @(s,e) addRefMean());
    refMeanBtn.HTMLComponent.Tooltip = ['Add a mean reference from the channels currently ' ...
        'selected in Available Channels (e.g., (A1 + A2) / 2).'];
    refCustomBtn = CSSuiButton(refBtnRow, 'Style', app.AppStyle, ...
        'Text', 'Custom', ...
        'ButtonPushedFcn', @(s,e) addRefCustom());
    refCustomBtn.HTMLComponent.Tooltip = ['Add a reference from a free-form expression ' ...
        '(e.g., (A1 + A2) / 2). A reference name is required.'];
    refRemoveBtn = CSSuiButton(refBtnRow, 'Style', app.AppStyle, ...
        'Text', 'Remove', ...
        'ButtonPushedFcn', @(s,e) removeRef());
    refRemoveBtn.HTMLComponent.Tooltip = ['Remove the selected reference. If any output ' ...
        'channels use it, you will be warned before they are removed too.'];

    % ---- COL 2: middle button stack (Output Channel ops) ----
    % Vertical stack of the four operations that produce output
    % rows. Centered in the available height with 1x stretch
    % spacers above and below so the cluster sits next to the
    % Output Channels table on the right.
    midCol = uigridlayout(outer);
    midCol.Layout.Row    = 1;
    midCol.Layout.Column = 2;
    midCol.RowHeight     = {'1x', 44, 44, 44, 44, '1x'};
    midCol.ColumnWidth   = {'1x'};
    midCol.Padding       = [0 0 0 0];
    midCol.RowSpacing    = 8;
    uipanel(midCol, 'BorderType', 'none');   % top stretch spacer
    chanAddBtn = CSSuiButton(midCol, 'Style', app.AppStyle, ...
        'Text', 'Add', ...
        'ButtonPushedFcn', @(s,e) addPassthrough());
    chanAddBtn.HTMLComponent.Tooltip = ['Add a passthrough output for each channel ' ...
        'currently selected in Available Channels (no referencing applied).'];
    chanRemoveBtn = CSSuiButton(midCol, 'Style', app.AppStyle, ...
        'Text', 'Remove', ...
        'ButtonPushedFcn', @(s,e) removeChan());
    chanRemoveBtn.HTMLComponent.Tooltip = 'Remove the selected output channel.';
    refSubtractBtn = CSSuiButton(midCol, 'Style', app.AppStyle, ...
        'Text', 'Rereference', ...
        'ButtonPushedFcn', @(s,e) addReferenceSubtraction());
    refSubtractBtn.HTMLComponent.Tooltip = ['Subtract a chosen reference from each ' ...
        'selected available channel and add one output row per channel ' ...
        '(e.g., C3, C4 with reference M → C3-M, C4-M).'];
    chanCustomBtn = CSSuiButton(midCol, 'Style', app.AppStyle, ...
        'Text', 'Custom', ...
        'ButtonPushedFcn', @(s,e) addCustomChannel());
    chanCustomBtn.HTMLComponent.Tooltip = ['Add an output channel from a free-form ' ...
        'expression (e.g., C3 - (A1 + A2)/2). Output name is optional.'];
    uipanel(midCol, 'BorderType', 'none');   % bottom stretch spacer

    % ---- COL 3: Output Channels (full height) ----
    outPanel = uigridlayout(outer);
    outPanel.Layout.Row    = 1;
    outPanel.Layout.Column = 3;
    outPanel.RowHeight     = {30, '1x'};
    outPanel.ColumnWidth   = {'1x'};
    outPanel.Padding       = [0 0 0 0];
    outPanel.RowSpacing    = 4;
    CSSuiLabel(outPanel, 'Style', app.AppStyle, ...
        'Text', 'OUTPUT CHANNELS', ...
        'FontWeight', '700', ...
        'FontSize', app.FontSizeTitle, ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top');
    chanTable = CSSuiTable(outPanel, ...
        'Data', chanRowsToTable(chansState), ...
        'ColumnName', {'Output Name', 'Expression'}, ...
        'ColumnWidth', [160, 420], ...
        'ColumnEditable', [true false], ...
        'CellEditCallback', @(s,e) onChanCellEdit(e), ...
        'Style', app.AppStyle, ...
        'SelectionType', 'row', ...
        'SelectionChangedFcn', @(s,e) onChanSelect(e));
    chanTable.HTMLComponent.Tooltip = ['Output channels — one DYNAM-O run per row. Click ' ...
        'an Output Name cell to rename it (optional alias); leave it blank to use the ' ...
        'expression as the output name. Expression is read-only.'];

    % ---- Status line + Help / OK / Cancel ----
    statusLabel = CSSuiLabel(outer, ...
        'Style', app.AppStyle, 'Text', '');
    statusLabel.Layout.Row    = 2;
    statusLabel.Layout.Column = [1 3];

    % Help icon — same SVG path as the main-page HelpButton
    % (createBottomBar.m). Keeps the visual language consistent
    % so a user lands here recognising it.
    helpIcon = ['<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z' ...
        'M13 19h-2v-2h2v2z' ...
        'M15.07 11.25l-.9.92C13.45 12.9 13 13.5 13 15h-2v-.5c0-1.1.45-2.1 1.17-2.83' ...
        'l1.24-1.26c.37-.36.59-.86.59-1.41 0-1.1-.9-2-2-2s-2 .9-2 2H8' ...
        'c0-2.21 1.79-4 4-4s4 1.79 4 4c0 .88-.36 1.68-.93 2.25z"/>'];

    bottomRow = uigridlayout(outer);
    bottomRow.Layout.Row    = 3;
    bottomRow.Layout.Column = [1 3];
    bottomRow.RowHeight     = {'1x'};
    bottomRow.ColumnWidth   = {'1x', 110, 110, 110};
    bottomRow.Padding       = [0 0 0 0];
    bottomRow.ColumnSpacing = 8;
    uipanel(bottomRow, 'BorderType', 'none');  % spacer
    helpBtn = CSSuiButton(bottomRow, 'Style', app.AppStyle, ...
        'Text', 'Help', ...
        'Icon', helpIcon, 'IconPosition', 'left', 'IconSize', '1.5em', ...
        'ButtonPushedFcn', @(s,e) showHelp());
    helpBtn.HTMLComponent.Tooltip = 'Show help for this dialog.';
    okBtn = CSSuiButton(bottomRow, 'Style', app.AppStyle, ...
        'Text', 'OK', 'ButtonPushedFcn', @(s,e) doOk());
    okBtn.HTMLComponent.Tooltip = ['Validate and apply: writes the output channels and ' ...
        'references back to the main page and closes the dialog.'];
    cancelBtn = CSSuiButton(bottomRow, 'Style', app.AppStyle, ...
        'Text', 'Cancel', 'ButtonPushedFcn', @(s,e) doCancel());
    cancelBtn.HTMLComponent.Tooltip = 'Close without applying changes.';

    refresh();

    % Pin the parent function's workspace so the button
    % callbacks (anonymous handles wrapping nested functions)
    % stay valid after this method returns. MATLAB will GC the
    % nested workspace once the figure dies; UserData holds a
    % live reference until then. Without this, non-modal
    % composers fail intermittently with "Unable to find
    % function @(s,e)foo()" when CSSuiButton tries to fire its
    % ButtonPushedFcn — the closure detached.
    d.UserData = struct('keepAlive', @doCancel);

    return  % composer is non-modal; OK/Cancel callbacks finish the work

    % ============================================================
    % Nested helpers — table data, validation, callbacks
    % ============================================================

    function tbl = refRowsToTable(rows)
        if isempty(rows), tbl = cell(0,2); return; end
        tbl = cell(numel(rows), 2);
        for r = 1:numel(rows)
            [n, e] = splitNameExpr(rows{r});
            tbl{r,1} = n;
            tbl{r,2} = e;
        end
    end
    function tbl = chanRowsToTable(rows)
        if isempty(rows), tbl = cell(0,2); return; end
        tbl = cell(numel(rows), 2);
        for r = 1:numel(rows)
            [n, e] = splitNameExpr(rows{r});
            if isempty(n)
                tbl{r,1} = e;   % unaliased passthrough: name == expression
            else
                tbl{r,1} = n;
            end
            tbl{r,2} = e;
        end
    end

    function nm = nextRefName()
        % Auto-name new references R1, R2, ... skipping any
        % already in refsState. Lets the user click a button
        % and get a working ref without typing a name first.
        used = false(1, 999);
        for kk = 1:numel(refsState)
            n2 = firstName(refsState{kk});
            tok = regexp(n2, '^R(\d+)$', 'tokens', 'once');
            if ~isempty(tok)
                idx = str2double(tok{1});
                if idx >= 1 && idx <= 999
                    used(idx) = true;
                end
            end
        end
        k = find(~used, 1, 'first');
        nm = sprintf('R%d', k);
    end
    function [nm, ex] = splitNameExpr(s)
        eq = strfind(s, '=');
        if isempty(eq)
            nm = '';
            ex = strtrim(s);
        else
            nm = strtrim(s(1:eq(1)-1));
            ex = strtrim(s(eq(1)+1:end));
        end
    end

    function refresh()
        refTable.Data  = refRowsToTable(refsState);
        chanTable.Data = chanRowsToTable(chansState);
        % Empty-state swap: textarea explains the workflow
        % until the user adds the first reference, then the
        % table takes over the same grid cell.
        if isempty(refsState)
            refEmptyHelp.HTMLComponent.Visible = 'on';
            refTable.HTMLComponent.Visible     = 'off';
        else
            refEmptyHelp.HTMLComponent.Visible = 'off';
            refTable.HTMLComponent.Visible     = 'on';
        end
        [okFlag, msg] = validateAll();
        if okFlag
            statusLabel.Text = sprintf('OK: %d reference(s), %d output channel(s).', ...
                numel(refsState), numel(chansState));
        else
            statusLabel.Text = ['Problem: ' msg];
        end
        % OK button stays clickable; doOk() runs validateAll
        % again on click and alerts if invalid. Gating the
        % button visually was unreliable across uihtml refreshes
        % and confused users into thinking the dialog was stuck.
    end

    function [ok, msg] = validateAll()
        ok = true; msg = '';
        if isempty(chansState)
            ok = false; msg = 'add at least one output channel.';
            return
        end
        refNames = cell(1, numel(refsState));
        for k = 1:numel(refsState)
            [n, e] = splitNameExpr(refsState{k});
            if isempty(n)
                ok = false; msg = sprintf('reference %d missing name (NAME = expr).', k); return
            end
            if isempty(e)
                ok = false; msg = sprintf('reference "%s" has empty expression.', n); return
            end
            if any(strcmpi(n, all_edf_labels))
                ok = false; msg = sprintf('reference name "%s" collides with an EDF label.', n); return
            end
            refNames{k} = n;
            augSoFar = [all_edf_labels, refNames(1:k-1)];
            [okk, mm] = checkLeaves(e, augSoFar);
            if ~okk
                ok = false; msg = sprintf('reference "%s": %s', n, mm); return
            end
        end
        aug = [all_edf_labels, refNames];
        for k = 1:numel(chansState)
            [~, e] = splitNameExpr(chansState{k});
            if isempty(e)
                ok = false; msg = sprintf('output channel %d has empty expression.', k); return
            end
            [okk, mm] = checkLeaves(e, aug);
            if ~okk
                ok = false; msg = sprintf('channel "%s": %s', chansState{k}, mm); return
            end
        end
    end

    function [ok, msg, leaves] = checkLeaves(expr, labels)
        % Greedy longest-match against `labels` (case-insensitive).
        % Skips operators and 'mean(' tokens. '$LABEL$' regions
        % are extracted as explicit labels first; outside them
        % the parser does prefix matching like read_EDF's
        % preprocessor. Third return is the cell of canonical
        % label names found (used by Fs uniformity checks).
        ok = true; msg = ''; leaves = {};
        rest = expr;
        dollarTokens = regexp(rest, '\$([^$]*)\$', 'tokens');
        for kk = 1:numel(dollarTokens)
            tok = dollarTokens{kk}{1};
            idx = find(strcmpi(tok, labels), 1);
            if isempty(idx)
                ok = false;
                msg = sprintf('unknown label "$%s$".', tok);
                return
            end
            leaves{end+1} = labels{idx}; %#ok<AGROW>
        end
        rest = regexprep(rest, '\$[^$]*\$', '');
        i = 1; n = numel(rest);
        while i <= n
            c = rest(i);
            if isspace(c) || any(c == '+-,()=')
                i = i + 1; continue
            end
            if i+4 <= n && strcmpi(rest(i:i+4), 'mean(')
                i = i + 5; continue
            end
            bestLen = 0; bestIdx = 0;
            for kk = 1:numel(labels)
                L = labels{kk};
                nl = numel(L);
                if i+nl-1 <= n && strcmpi(rest(i:i+nl-1), L) && nl > bestLen
                    bestLen = nl;
                    bestIdx = kk;
                end
            end
            if bestLen == 0
                j = i;
                while j <= n && ~isspace(rest(j)) && ~any(rest(j) == '+-,()=')
                    j = j + 1;
                end
                ok = false;
                msg = sprintf('unknown label "%s".', strtrim(rest(i:j-1)));
                return
            end
            leaves{end+1} = labels{bestIdx}; %#ok<AGROW>
            i = i + bestLen;
        end
    end

    % ---- Selection trackers ----
    function onAvailSelect(evt)
        availSelectedRows = extractSelectedRows(evt);
    end
    function onRefSelect(evt)
        refSelectedRows = extractSelectedRows(evt);
    end
    function onChanSelect(evt)
        chanSelectedRows = extractSelectedRows(evt);
    end
    function rows = extractSelectedRows(evt)
        rows = [];
        try
            if isfield(evt, 'Selection') && ~isempty(evt.Selection)
                rows = unique(evt.Selection(:));
            elseif isfield(evt, 'Indices') && ~isempty(evt.Indices)
                rows = unique(evt.Indices(:,1));
            end
        catch
        end
    end

    function onAvailDoubleClick(evt)
        % Double-clicking an Available row adds it as a
        % passthrough output. Mirrors clicking "Add" with that
        % row selected. The fastest path for the typical
        % "I just want this raw channel" case.
        r = [];
        try
            if isfield(evt,'Row') && ~isempty(evt.Row)
                r = double(evt.Row);
            elseif isfield(evt,'Indices') && ~isempty(evt.Indices)
                r = double(evt.Indices(1));
            end
        catch
        end
        if isempty(r) || r < 1 || r > size(tableData,1), return, end
        chansState{end+1} = tableData{r,1};
        refresh();
    end

    % ---- Splitter drag (left column: Available ↔ Create Reference) ----
    function beginSplitDrag()
        % Capture mouse-motion / mouse-up on the dialog so the
        % user can drag the divider between Available Channels
        % and Create Reference. Heights are computed in pixels
        % and written back to leftCol.RowHeight {h1, 8, h2}.
        avP = getpixelposition(availPanel, true);
        rfP = getpixelposition(refPanel, true);
        splitterDrag.active      = true;
        splitterDrag.startY      = d.CurrentPoint(2);
        splitterDrag.startH1     = avP(4);
        splitterDrag.totalH      = avP(4) + rfP(4);
        splitterDrag.origMotion  = d.WindowButtonMotionFcn;
        splitterDrag.origUp      = d.WindowButtonUpFcn;
        splitterDrag.origPointer = d.Pointer;
        d.Pointer               = 'top';
        d.WindowButtonMotionFcn = @(~,~) dragSplit();
        d.WindowButtonUpFcn     = @(~,~) endSplitDrag();
    end
    function dragSplit()
        if ~splitterDrag.active, return, end
        dy     = d.CurrentPoint(2) - splitterDrag.startY;
        startH = splitterDrag.startH1;
        total  = splitterDrag.totalH;
        minH   = 80;
        newH1  = min(max(startH - dy, minH), total - minH);
        newH2  = max(total - newH1, minH);
        leftCol.RowHeight = {newH1, 8, newH2};
    end
    function endSplitDrag()
        d.WindowButtonMotionFcn = splitterDrag.origMotion;
        d.WindowButtonUpFcn     = splitterDrag.origUp;
        d.Pointer               = splitterDrag.origPointer;
        splitterDrag.active     = false;
    end

    function nm = firstName(s)
        eq = strfind(s, '=');
        if isempty(eq), nm = ''; else, nm = strtrim(s(1:eq(1)-1)); end
    end

    function aug = augmentedLabels()
        aug = all_edf_labels;
        for kk = 1:numel(refsState)
            nm = firstName(refsState{kk});
            if ~isempty(nm), aug{end+1} = nm; end %#ok<AGROW>
        end
    end

    function m = fullFsMap()
        % EDF-label Fs (already in fsByLabel) plus Fs of every
        % currently-defined reference, computed in declaration
        % order so a ref can use earlier refs. Mixed-rate or
        % unresolvable refs map to NaN.
        m = containers.Map('KeyType','char','ValueType','double');
        kk2 = keys(fsByLabel);
        for kk = 1:numel(kk2)
            m(kk2{kk}) = fsByLabel(kk2{kk});
        end
        refNamesSoFar = {};
        for kk = 1:numel(refsState)
            [n2, e2] = splitNameExpr(refsState{kk});
            if isempty(n2), continue, end
            augSoFar = [all_edf_labels, refNamesSoFar];
            [okk, ~, leaves] = checkLeaves(e2, augSoFar);
            if ~okk
                m(n2) = NaN;
            else
                m(n2) = uniformFsFromMap(leaves, m);
            end
            refNamesSoFar{end+1} = n2; %#ok<AGROW>
        end
    end

    function fs = uniformFsFromMap(leaves, m)
        fs = NaN;
        if isempty(leaves), return, end
        fs0 = [];
        for kk = 1:numel(leaves)
            if ~isKey(m, leaves{kk}), return, end
            f = m(leaves{kk});
            if isnan(f), return, end
            if isempty(fs0)
                fs0 = f;
            elseif abs(f - fs0) > 1e-9
                return
            end
        end
        fs = fs0;
    end

    function [ok, msg] = uniformFs(leaves, m)
        % Uniform-rate check with a user-readable message. Used
        % at every "add a row" path so the user sees why a
        % combination was rejected.
        ok = true; msg = '';
        if isempty(leaves), return, end
        fs0 = [];
        firstLbl = '';
        for kk = 1:numel(leaves)
            if ~isKey(m, leaves{kk})
                ok = false;
                msg = sprintf('cannot resolve sampling rate for "%s".', leaves{kk});
                return
            end
            f = m(leaves{kk});
            if isnan(f)
                ok = false;
                msg = sprintf('"%s" has inconsistent sampling rates across files; resolve before combining.', leaves{kk});
                return
            end
            if isempty(fs0)
                fs0 = f; firstLbl = leaves{kk};
            elseif abs(f - fs0) > 1e-9
                ok = false;
                msg = sprintf('mixed sampling rates: "%s" is %g Hz but "%s" is %g Hz.', ...
                    firstLbl, fs0, leaves{kk}, f);
                return
            end
        end
    end

    % ---- References table: inline Name edit + add/remove rows ----
    % Only the Name column is editable; Expression is fixed by
    % the originating button (Add Channel / Create Mean / Custom).
    function onRefCellEdit(evt)
        r = evt.Indices(1);
        if r < 1 || r > numel(refsState), return, end
        [~, e] = splitNameExpr(refsState{r});
        n = strtrim(char(evt.NewData));
        if isempty(n) && isempty(e)
            refsState(r) = [];
        else
            refsState{r} = sprintf('%s = %s', n, e);
        end
        refresh();
    end

    function addRefABMinus()
        % "A − B" — pick two channels (or earlier refs) and
        % create a new reference of the form NAME = A-B. Name
        % is optional in the prompt; if blank, auto-named R<N>.
        aug = [all_edf_labels, ...
            cellfun(@firstName, refsState, 'UniformOutput', false)];
        aug = aug(~cellfun(@isempty, aug));
        if numel(aug) < 2
            uialert(d, 'Need at least two labels (channels or references).', ...
                'A − B', 'Icon', 'info');
            return
        end
        [chA, chB, alias] = promptDifference(aug);
        if isempty(chA), return, end
        m = fullFsMap();
        [okFs, msgFs] = uniformFs({chA, chB}, m);
        if ~okFs
            uialert(d, msgFs, 'Mixed sampling rates', 'Icon', 'error');
            return
        end
        if isempty(alias), alias = nextRefName(); end
        refsState{end+1} = sprintf('%s = %s-%s', alias, chA, chB);
        refresh();
    end

    function addRefMean()
        % "Create Mean" — needs 2+ available rows selected.
        % Appends '<R<N>> = mean(L1, L2, ...)'. All selected
        % channels must share Fs.
        if numel(availSelectedRows) < 2
            uialert(d, 'Select at least 2 rows in Available Channels first.', ...
                'Create Mean', 'Icon', 'info');
            return
        end
        lbls = tableData(availSelectedRows, 1);
        m = fullFsMap();
        [okFs, msgFs] = uniformFs(lbls(:)', m);
        if ~okFs
            uialert(d, msgFs, 'Mixed sampling rates', 'Icon', 'error');
            return
        end
        refsState{end+1} = sprintf('%s = mean(%s)', nextRefName(), strjoin(lbls, ', '));
        refresh();
    end

    function addRefCustom()
        % "Custom" — free-text reference. Name is optional;
        % blank -> auto R<N>. Refs validate against EDF labels
        % only (a ref can't reference a later ref).
        [nm, ex] = promptCustom('Add Custom Reference', false, all_edf_labels);
        if isempty(ex), return, end
        [~, ~, leaves] = checkLeaves(ex, all_edf_labels);
        m = fullFsMap();
        [okFs, msgFs] = uniformFs(leaves, m);
        if ~okFs
            uialert(d, msgFs, 'Mixed sampling rates', 'Icon', 'error');
            return
        end
        if isempty(nm), nm = nextRefName(); end
        refsState{end+1} = sprintf('%s = %s', nm, ex);
        refresh();
    end

    function removeRef()
        % Removing a reference cascades: any output channel whose
        % expression cites that ref name becomes invalid. Find
        % those rows up front and confirm with the user before
        % deleting both. Cancel aborts the whole operation; no
        % half-state where refs are gone but dependent channels
        % linger and fail validation.
        if isempty(refSelectedRows), return, end
        rows = refSelectedRows(refSelectedRows >= 1 & refSelectedRows <= numel(refsState));
        if isempty(rows), return, end
        removedNames = {};
        for kk = 1:numel(rows)
            n2 = firstName(refsState{rows(kk)});
            if ~isempty(n2), removedNames{end+1} = n2; end %#ok<AGROW>
        end
        aug = augmentedLabels();
        affectedRows = [];
        for kk = 1:numel(chansState)
            [~, e2] = splitNameExpr(chansState{kk});
            [~, ~, leaves] = checkLeaves(e2, aug);
            for jj = 1:numel(leaves)
                if any(strcmpi(leaves{jj}, removedNames))
                    affectedRows(end+1) = kk; %#ok<AGROW>
                    break
                end
            end
        end
        if ~isempty(affectedRows)
            msgWarn = sprintf( ...
                ['Removing reference(s) %s will also remove %d output channel(s) that use them:\n\n%s\n\n' ...
                 'Proceed?'], ...
                strjoin(removedNames, ', '), ...
                numel(affectedRows), ...
                strjoin(chansState(affectedRows), '\n'));
            sel = uiconfirm(d, msgWarn, 'Cascade removal', ...
                'Options', {'Remove all', 'Cancel'}, ...
                'DefaultOption', 'Cancel', ...
                'CancelOption', 'Cancel', ...
                'Icon', 'warning');
            if ~strcmp(sel, 'Remove all'), return, end
            chansState(affectedRows) = [];
            chanSelectedRows = [];
        end
        refsState(rows) = [];
        refSelectedRows = [];
        refresh();
    end

    % ---- Output Channels: inline Output-Name edit + middle-column ops ----
    % Only the Output Name column is editable; Expression is set
    % by the originating button (+ / A−B / Reference / Custom).
    function onChanCellEdit(evt)
        r = evt.Indices(1);
        if r < 1 || r > numel(chansState), return, end
        [~, e] = splitNameExpr(chansState{r});
        n = strtrim(char(evt.NewData));
        % Blank name OR name == expression -> no alias (the
        % display will fall back to showing the expression).
        if isempty(n) || strcmp(n, e)
            chansState{r} = e;
        else
            chansState{r} = sprintf('%s = %s', n, e);
        end
        refresh();
    end

    function addPassthrough()
        if isempty(availSelectedRows)
            uialert(d, 'Select rows in Available Channels first.', ...
                'Add Passthrough', 'Icon', 'info');
            return
        end
        lbls = tableData(availSelectedRows, 1);
        for kk = 1:numel(lbls)
            chansState{end+1} = lbls{kk};
        end
        refresh();
    end

    function removeChan()
        if isempty(chanSelectedRows), return, end
        chansState(chanSelectedRows) = [];
        chanSelectedRows = [];
        refresh();
    end

    function addReferenceSubtraction()
        if isempty(availSelectedRows)
            uialert(d, 'Select one or more rows in Available Channels first.', ...
                'Reference', 'Icon', 'info');
            return
        end
        refNames = cellfun(@firstName, refsState, 'UniformOutput', false);
        refNames = refNames(~cellfun(@isempty, refNames));
        pickList = [refNames(:)' all_edf_labels(:)'];
        if isempty(pickList)
            uialert(d, 'No references or labels available to subtract.', ...
                'Reference', 'Icon', 'info');
            return
        end
        pick = promptPickFromList( ...
            'Subtract from each selected channel:', pickList);
        if isempty(pick), return, end
        lbls = tableData(availSelectedRows, 1);
        m = fullFsMap();
        for kk = 1:numel(lbls)
            [okFs, msgFs] = uniformFs({lbls{kk}, pick}, m);
            if ~okFs
                uialert(d, msgFs, 'Mixed sampling rates', 'Icon', 'error');
                return
            end
        end
        for kk = 1:numel(lbls)
            chansState{end+1} = sprintf('%s-%s', lbls{kk}, pick);
        end
        refresh();
    end

    function addCustomChannel()
        % Output channel: name optional. Expression validated
        % against EDF labels + already-defined references.
        [alias, ex] = promptCustom('Add Custom Output Channel', false, augmentedLabels());
        if isempty(alias) && isempty(ex), return, end
        [~, ~, leaves] = checkLeaves(ex, augmentedLabels());
        m = fullFsMap();
        [okFs, msgFs] = uniformFs(leaves, m);
        if ~okFs
            uialert(d, msgFs, 'Mixed sampling rates', 'Icon', 'error');
            return
        end
        if isempty(alias)
            chansState{end+1} = ex;
        else
            chansState{end+1} = sprintf('%s = %s', alias, ex);
        end
        refresh();
    end

    function showHelp()
        % Render the help as proper HTML in a uihtml block. uialert
        % collapses whitespace and the previous CSSuiTextArea +
        % monospace approach buried structure in ASCII art. Inline
        % CSS (no external sheet — uihtml's HTMLSource is a single
        % string) so the help is self-contained and theme-independent.
        html = [ ...
'<!DOCTYPE html><html><head><meta charset="utf-8"><style>' ...
'  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;' ...
'         font-size: 13px; line-height: 1.5; color: #1f2330;' ...
'         background: #f7f8fb; margin: 0; padding: 18px 22px; }' ...
'  h1 { font-size: 16px; margin: 0 0 4px 0; color: #1f2330; }' ...
'  .subtitle { color: #5b6478; font-size: 12px; margin-bottom: 16px; }' ...
'  h2 { font-size: 13.5px; margin: 18px 0 6px 0; color: #2a3a6b;' ...
'       border-bottom: 1px solid #d4d8e2; padding-bottom: 3px; }' ...
'  ol, ul { padding-left: 22px; margin: 4px 0 8px 0; }' ...
'  li { margin: 2px 0; }' ...
'  code, kbd { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;' ...
'              font-size: 12px; background: #eceff5; padding: 1px 5px; border-radius: 3px; }' ...
'  table.syntax { border-collapse: collapse; margin: 6px 0; font-size: 12px; }' ...
'  table.syntax td { padding: 3px 12px 3px 0; vertical-align: top; }' ...
'  table.syntax td:first-child { color: #5b6478; white-space: nowrap; }' ...
'  table.syntax td:last-child  { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;' ...
'                                 background: #eceff5; padding: 2px 7px; border-radius: 3px; }' ...
'  .panel { border: 1px solid #d4d8e2; border-radius: 6px; padding: 8px 12px;' ...
'           background: #fff; margin: 5px 0; }' ...
'  .panel-title { font-weight: 600; color: #2a3a6b; font-size: 12.5px; }' ...
'  .panel-meta  { color: #5b6478; font-size: 11.5px; margin-bottom: 4px; }' ...
'  .callout { border-left: 3px solid #4f7be8; background: #eef3ff;' ...
'             padding: 8px 12px; border-radius: 0 4px 4px 0; margin: 8px 0; }' ...
'  .btn { display: inline-block; font-weight: 600; color: #2a3a6b;' ...
'         font-size: 12px; padding: 1px 6px; border: 1px solid #c4cbdb;' ...
'         border-radius: 4px; background: #fff; }' ...
'</style></head><body>' ...
'<h1>Channel &amp; Reference Composer</h1>' ...
'<div class="subtitle">Build the list of <i>output channels</i> DYNAM-O will analyze. Each output channel is one row in the right-hand table — one DYNAM-O run per subject per row.</div>' ...
'<h2>Typical workflow</h2>' ...
'<ol>' ...
'  <li><i>(Optional)</i> Build mastoid / linked-ear references in the <b>Create Reference</b> panel. Example: <code>R1 = mean(A1, A2)</code>.</li>' ...
'  <li>Select one or more rows in <b>Available Channels</b>.</li>' ...
'  <li>Click <span class="btn">Add</span> for a passthrough output, or <span class="btn">Rereference</span> to subtract a chosen reference from each selected channel.</li>' ...
'  <li>Use <span class="btn">Custom</span> for anything more complex.</li>' ...
'  <li>Rename outputs in place (Output Name column).</li>' ...
'  <li>Click <span class="btn">OK</span> to commit.</li>' ...
'</ol>' ...
'<h2>Panels</h2>' ...
'<div class="panel"><div class="panel-title">Available Channels (left)</div>' ...
'<div class="panel-meta">read-only · double-click adds as passthrough</div>' ...
'Every label found across the loaded EDF files. The <i>Fs</i> column shows the resampled rate when <b>Resample data</b> is on in the main panel; otherwise the native rate(s) per file.' ...
'</div>' ...
'<div class="panel"><div class="panel-title">Create Reference (left, lower)</div>' ...
'<div class="panel-meta">edit Name in place · drag the divider above to resize</div>' ...
'Helper definitions of the form <code>NAME = expression</code>. Defined references can be reused by name in later references or output channels. New references auto-name <code>R1</code>, <code>R2</code>, …' ...
'</div>' ...
'<div class="panel"><div class="panel-title">Output Channels (right)</div>' ...
'<div class="panel-meta">edit Output Name in place</div>' ...
'The final list. One DYNAM-O run per row. The Output Name becomes the output directory name. Leave blank to use the expression as the name.' ...
'</div>' ...
'<h2>Buttons</h2>' ...
'<b>Under Create Reference:</b>' ...
'<ul>' ...
'  <li><span class="btn">A − B</span> &nbsp; Pick two channels (or earlier references) → <code>NAME = A-B</code>.</li>' ...
'  <li><span class="btn">Mean</span> &nbsp; Average the 2+ selected Available rows → <code>NAME = mean(...)</code>.</li>' ...
'  <li><span class="btn">Custom</span> &nbsp; Free-text reference, <code>NAME = expression</code>.</li>' ...
'  <li><span class="btn">Remove</span> &nbsp; Delete the selected reference(s). Output channels that depend on a removed reference are flagged for cascade removal first.</li>' ...
'</ul>' ...
'<b>Middle column:</b>' ...
'<ul>' ...
'  <li><span class="btn">Add</span> &nbsp; Add each selected Available row as a passthrough output (no math).</li>' ...
'  <li><span class="btn">Remove</span> &nbsp; Remove the selected output row(s).</li>' ...
'  <li><span class="btn">Rereference</span> &nbsp; Subtract a chosen reference (or another label) from each selected Available row. Produces one output row per selection.</li>' ...
'  <li><span class="btn">Custom</span> &nbsp; Free-text output expression with optional alias.</li>' ...
'</ul>' ...
'<h2>Expression syntax</h2>' ...
'<table class="syntax">' ...
'<tr><td>Plain label</td><td>C3</td></tr>' ...
'<tr><td>A − B reref</td><td>C3-A2</td></tr>' ...
'<tr><td>Mean of N (N ≥ 2)</td><td>mean(A1, A2)</td></tr>' ...
'<tr><td>Linear combination</td><td>C3 - mean(A1, A2)</td></tr>' ...
'<tr><td>Aliased output</td><td>OUT = mean(C3, C4)</td></tr>' ...
'<tr><td>Reference subtract</td><td>C3-LM &nbsp;<i>(LM defined above)</i></td></tr>' ...
'<tr><td>Escape weird labels</td><td>$EEG A+B$ - $A1$</td></tr>' ...
'</table>' ...
'<div class="callout"><b>Sampling-rate rule.</b> Any combination operation (<i>A − B</i>, <i>Mean</i>, <i>Rereference</i>, <i>Custom</i>) is rejected if its leaves do not share a single <i>Fs</i>. Enable <b>Resample data</b> in the main panel to force every channel to a common rate before any reference math runs.</div>' ...
'<div class="callout"><b>Editing.</b> Only the <i>Name</i> / <i>Output Name</i> column is editable in place. To change an expression, remove the row and re-add it via the appropriate button. This guarantees every expression was constructed by the GUI and is well-formed.</div>' ...
'</body></html>'];

        hpW = 760; hpH = 720;
        hp = uifigure('Name', 'Channel Composer — Help', ...
            'Position', [(ss(3)-hpW)/2, (ss(4)-hpH)/2, hpW, hpH]);
        hpGrid = uigridlayout(hp);
        hpGrid.RowHeight    = {'1x', 44};
        hpGrid.ColumnWidth  = {'1x', 100, '1x'};
        hpGrid.Padding      = [10 10 10 10];
        hpGrid.RowSpacing   = 8;
        hpHtml = uihtml(hpGrid, 'HTMLSource', html);
        hpHtml.Layout.Row    = 1;
        hpHtml.Layout.Column = [1 3];
        closeBtn = CSSuiButton(hpGrid, 'Style', app.AppStyle, ...
            'Text', 'Close', ...
            'ButtonPushedFcn', @(s,e) delete(hp));
        closeBtn.Layout.Row    = 2;
        closeBtn.Layout.Column = 2;
    end

    % ---- Sub-prompts ----
    function pick = promptPickFromList(label, items)
        pdW = 460; pdH = 200; pdPad = 12;
        pd = uifigure('Name', 'Choose', ...
            'Position', [(ss(3)-pdW)/2, (ss(4)-pdH)/2, pdW, pdH], ...
            'WindowStyle', 'modal');
        CSSuiLabel(pd, 'Style', app.AppStyle, 'Text', label, ...
            'Position', [pdPad, pdH-pdPad-22, pdW-2*pdPad, 22]);
        dd = CSSuiDropdown(pd, 'Style', app.AppStyle, ...
            'Items', items, ...
            'Position', [pdPad, pdH-pdPad-22-36-6, pdW-2*pdPad, 36]);
        pick = '';
        CSSuiButton(pd, 'Style', app.AppStyle, 'Text', 'OK', ...
            'Position', [pdW-2*90-pdPad-8, pdPad, 90, 36], ...
            'ButtonPushedFcn', @(s,e) doOk());
        CSSuiButton(pd, 'Style', app.AppStyle, 'Text', 'Cancel', ...
            'Position', [pdW-90-pdPad, pdPad, 90, 36], ...
            'ButtonPushedFcn', @(s,e) doCan());
        uiwait(pd);
        function doOk()
            pick = char(dd.Value);
            if isvalid(pd), delete(pd); end
        end
        function doCan()
            pick = '';
            if isvalid(pd), delete(pd); end
        end
    end

    function [nm, ex] = promptCustom(title, nameRequired, augLabels)
        % Custom name + expression dialog. Validates the
        % expression (via checkLeaves) against augLabels before
        % closing; if the user supplies an unknown label, the
        % dialog stays open with a uialert. The name is either
        % marked '(required)' or '(optional)' in the label and
        % enforced at the OK handler.
        pdW = 520; pdH = 220; pdPad = 12;
        pd = uifigure('Name', title, ...
            'Position', [(ss(3)-pdW)/2, (ss(4)-pdH)/2, pdW, pdH], ...
            'WindowStyle', 'modal');
        if nameRequired
            nameLabelText = 'Reference name (required):';
        else
            nameLabelText = 'Output name (optional):';
        end
        CSSuiLabel(pd, 'Style', app.AppStyle, 'Text', nameLabelText, ...
            'Position', [pdPad, pdH-pdPad-22, pdW-2*pdPad, 22]);
        efN = CSSuiEditField(pd, 'Style', app.AppStyle, 'Value', '', ...
            'Position', [pdPad, pdH-pdPad-22-32, pdW-2*pdPad, 32]);
        CSSuiLabel(pd, 'Style', app.AppStyle, ...
            'Text', 'Expression (e.g. mean(A1, A2) or C3 - LM):', ...
            'Position', [pdPad, pdH-pdPad-22-32-6-22, pdW-2*pdPad, 22]);
        efE = CSSuiEditField(pd, 'Style', app.AppStyle, 'Value', '', ...
            'Position', [pdPad, pdH-pdPad-22-32-6-22-32, pdW-2*pdPad, 32]);
        nm = ''; ex = '';
        CSSuiButton(pd, 'Style', app.AppStyle, 'Text', 'OK', ...
            'Position', [pdW-2*90-pdPad-8, pdPad, 90, 36], ...
            'ButtonPushedFcn', @(s,e) doOk());
        CSSuiButton(pd, 'Style', app.AppStyle, 'Text', 'Cancel', ...
            'Position', [pdW-90-pdPad, pdPad, 90, 36], ...
            'ButtonPushedFcn', @(s,e) doCan());
        uiwait(pd);
        function doOk()
            candNm = strtrim(efN.Value);
            candEx = strtrim(efE.Value);
            if nameRequired && isempty(candNm)
                uialert(pd, 'Name is required.', 'Missing name', 'Icon', 'error');
                return
            end
            if isempty(candEx)
                uialert(pd, 'Expression is required.', 'Missing expression', 'Icon', 'error');
                return
            end
            [okk, mm] = checkLeaves(candEx, augLabels);
            if ~okk
                uialert(pd, mm, 'Invalid expression', 'Icon', 'error');
                return
            end
            nm = candNm; ex = candEx;
            if isvalid(pd), delete(pd); end
        end
        function doCan()
            nm = ''; ex = '';
            if isvalid(pd), delete(pd); end
        end
    end

    function [chA, chB, alias] = promptDifference(labels)
        % "A − B" picker: two dropdowns + optional alias.
        % Validates A != B; the resulting 'CHA-CHB' string is
        % already lexically valid by construction (both leaves
        % are members of the augmented label set).
        pdW = 540; pdH = 220; pdPad = 12;
        pd = uifigure('Name', 'A − B Channel', ...
            'Position', [(ss(3)-pdW)/2, (ss(4)-pdH)/2, pdW, pdH], ...
            'WindowStyle', 'modal');
        CSSuiLabel(pd, 'Style', app.AppStyle, 'Text', 'A:', ...
            'Position', [pdPad, pdH-pdPad-22, 30, 22]);
        ddA = CSSuiDropdown(pd, 'Style', app.AppStyle, ...
            'Items', labels, ...
            'Position', [pdPad+30, pdH-pdPad-32, (pdW-2*pdPad-60)/2, 32]);
        CSSuiLabel(pd, 'Style', app.AppStyle, 'Text', 'B:', ...
            'Position', [pdPad+30+(pdW-2*pdPad-60)/2+10, pdH-pdPad-22, 30, 22]);
        ddB = CSSuiDropdown(pd, 'Style', app.AppStyle, ...
            'Items', labels, ...
            'Position', [pdPad+60+(pdW-2*pdPad-60)/2+10, pdH-pdPad-32, (pdW-2*pdPad-60)/2-10, 32]);
        CSSuiLabel(pd, 'Style', app.AppStyle, 'Text', 'Optional alias (output name):', ...
            'Position', [pdPad, pdH-pdPad-32-32-6-22, pdW-2*pdPad, 22]);
        efAlias = CSSuiEditField(pd, 'Style', app.AppStyle, 'Value', '', ...
            'Position', [pdPad, pdH-pdPad-32-32-6-22-32, pdW-2*pdPad, 32]);
        chA = ''; chB = ''; alias = '';
        CSSuiButton(pd, 'Style', app.AppStyle, 'Text', 'OK', ...
            'Position', [pdW-2*90-pdPad-8, pdPad, 90, 36], ...
            'ButtonPushedFcn', @(s,e) doOk());
        CSSuiButton(pd, 'Style', app.AppStyle, 'Text', 'Cancel', ...
            'Position', [pdW-90-pdPad, pdPad, 90, 36], ...
            'ButtonPushedFcn', @(s,e) doCan());
        uiwait(pd);
        function doOk()
            candA = char(ddA.Value);
            candB = char(ddB.Value);
            if strcmpi(candA, candB)
                uialert(pd, 'A and B must be different.', 'Invalid', 'Icon', 'error');
                return
            end
            chA = candA; chB = candB; alias = strtrim(efAlias.Value);
            if isvalid(pd), delete(pd); end
        end
        function doCan()
            chA = ''; chB = ''; alias = '';
            if isvalid(pd), delete(pd); end
        end
    end

    % ---- OK / Cancel ----
    function doOk()
        [okFlag, msg] = validateAll();
        if ~okFlag
            uialert(d, msg, 'Cannot accept', 'Icon', 'error');
            return
        end
        app.ReferenceList = refsState;
        app.ChannelList   = chansState;
        if isempty(chansState)
            chanText = '';
        else
            chanText = strjoin(chansState, ', ');
        end
        app.ViewChannelsButton.IsError = false;
        % Enable BEFORE setting Value. The disabled CSSuiEditField
        % drops setValue commands at the JS layer (the underlying
        % <input disabled> doesn't accept programmatic value
        % changes through the bridge in some browsers), so a
        % set-then-enable sequence leaves the field visibly empty
        % even though the MATLAB-side Value_ is correct.
        % Editable=false keeps the fields visually active but
        % not typeable -- the composer is still the single
        % writer; the field is purely a display of state.
        app.ChannelEditField.Enabled    = true;
        app.ReferenceEditField.Enabled  = true;
        app.ChannelEditField.Editable   = false;
        app.ReferenceEditField.Editable = false;
        app.ChannelEditField.Value      = chanText;
        if isempty(refsState)
            app.ReferenceEditField.Value = '';
        else
            app.ReferenceEditField.Value = strjoin(refsState, ', ');
        end
        validateChannelSamplingRates(app, chansState, tableData);
        app.refreshChannelTooltips();
        if isvalid(d), delete(d); end
    end

    function doCancel()
        if isvalid(d), delete(d); end
    end

end
