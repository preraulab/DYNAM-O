function createRunMontageWindow(app)
% createRunMontageWindow  Build the Channels & Derived Channels Composer
%   ("run montage" picker). Scans every loaded EDF file's header for
%   available channel labels and per-file sampling rates, then opens a
%   non-modal three-column dialog where the user assembles the output
%   channel set the upcoming batch run will use. Derived channels (mean,
%   difference, custom) are created via popup dialogs and live in the
%   same Available Channels table as the EDF labels, marked Derived.
%
%   LEFT  : button row (+ Mean / + Difference / + Custom / ✕ Remove) on
%           top of the unified Available Channels table (rows are EDF or
%           Derived; the Type column distinguishes them).
%   MID   : button stack (→ Add / ✕ Remove / − Rereference / ƒ(x) Custom)
%           operating on the Output Channels table.
%   RIGHT : editable Output Channels table (one DYNAM-O run per row).
%
%   Triggered by the "View Channels" button on the Setup tab via the
%   thin viewChannelsButtonPushed shim. OK validates and commits both
%   app.ChannelList (output channels) and app.ReferenceList (every
%   derived channel, regardless of whether the user used it in an
%   output row — read_EDF needs the named-derivation prefix).

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

    % Build sorted base rows for the Available Channels table:
    %   {Channel, Fs string, Info}.
    % The Info column does double duty: for EDF rows it shows file
    % coverage ('5 / 10 files' — how many of the loaded EDFs contain
    % this label), and for Derived rows it shows the expression. The
    % shape of that string is what distinguishes the two visually —
    % no separate Type column.
    %
    % fsByLabel: label -> Fs (scalar) or NaN if mixed across files.
    % When resampling is enabled, every label maps to the target rate
    % (the resampler runs before any composer math does, so downstream
    % operations see a single uniform rate).
    all_edf_labels = sort(keys(chan_map));
    nChans = numel(all_edf_labels);
    edfBaseRows = cell(nChans, 3);
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
        nFound = numel(entry{1});
        if nFound == nFiles
            fileStr = sprintf('%d / %d files', nFound, nFiles);
        else
            % Highlight partial coverage with the same arrow glyph
            % the dialog uses elsewhere — easy to spot at a glance
            % when one file is missing the label.
            fileStr = sprintf('%d / %d files ⚠', nFound, nFiles);
        end
        edfBaseRows{ii,1} = lbl;
        edfBaseRows{ii,2} = freqStr;
        edfBaseRows{ii,3} = fileStr;
    end
    % `tableData` is the live rendered version (EDF rows + any Derived
    % rows built in this dialog). It's rebuilt by rebuildAvailable()
    % on every refresh so newly created derived channels show up in
    % the Available Channels table without re-creating the widget.
    tableData = edfBaseRows;

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
    chanSelectedRows  = [];

    ss = get(0, 'ScreenSize');
    dW = 1200; dH = 760;
    % Non-modal so the user can adjust other parts of the batch
    % (file list, output dir, staging columns) while the
    % composer is open. The closure over `app` keeps the
    % dialog wired to the live app instance regardless of
    % focus changes.
    d = uifigure('Name', 'Configure Channels & Derived Channels', ...
        'Position', [(ss(3)-dW)/2, (ss(4)-dH)/2, dW, dH]);
    app.trackChildWindow(d);

    outer = uigridlayout(d);
    outer.RowHeight    = {62, '1x', 44};
    outer.ColumnWidth  = {'1.2x', 150, '1x'};
    outer.Padding      = [10 10 10 10];
    outer.RowSpacing   = 8;
    outer.ColumnSpacing= 10;

    % --- Material-style SVG <path> fragments shared across this dialog ---
    %     CSSuiButton renders them when passed as 'Icon'.
    helpIcon = ['<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z' ...
        'M13 19h-2v-2h2v2z' ...
        'M15.07 11.25l-.9.92C13.45 12.9 13 13.5 13 15h-2v-.5c0-1.1.45-2.1 1.17-2.83' ...
        'l1.24-1.26c.37-.36.59-.86.59-1.41 0-1.1-.9-2-2-2s-2 .9-2 2H8' ...
        'c0-2.21 1.79-4 4-4s4 1.79 4 4c0 .88-.36 1.68-.93 2.25z"/>'];
    plusIcon  = '<path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>';
    trashIcon = ['<path d="M3 6h18v2H3V6zm2 2h14l-1.5 14h-11L5 8z' ...
        'm5 2v8h2v-8h-2zm4 0v8h2v-8h-2zM8 4h8v2H8V4z"/>'];
    % Chevron-double-right (Material): used on the mid-column "Add"
    % button to signal "push from Available → Output Channels".
    doubleRightIcon = ['<path d="M5.59 7.41L7 6l6 6-6 6-1.41-1.41L10.17 12 5.59 7.41z' ...
        'm6 0L13 6l6 6-6 6-1.41-1.41L16.17 12 11.59 7.41z"/>'];

    % ---- ROW 1: numbered-steps header strip (spans all 3 columns) ----
    % Self-explanatory onboarding for first-time users — replaces the
    % "must hover every button to learn what it does" pattern. The
    % chips align with the column they describe so the eye flows
    % left-to-right with the workflow.
    headerHtml = uihtml(outer, 'HTMLSource', buildHeaderStripHtml(app));
    headerHtml.Layout.Row    = 1;
    headerHtml.Layout.Column = [1 3];

    % ---- ROW 2 / COL 1: Available Channels (full height) ----
    % Single panel — the old splitter + separate "References" panel
    % were collapsed into this one column. Derived channels (mean,
    % difference, custom) live in the same Available Channels table
    % alongside the EDF labels, distinguished by the Type column.
    % Anything in this list — EDF or derived — is a valid source for
    % the middle-column "Build Output" buttons.
    leftCol = uigridlayout(outer);
    leftCol.Layout.Row    = 2;
    leftCol.Layout.Column = 1;
    leftCol.RowHeight     = {30, '1x', 30, 44};
    leftCol.ColumnWidth   = {'1x'};
    leftCol.Padding       = [0 0 0 0];
    leftCol.RowSpacing    = 6;

    CSSuiLabel(leftCol, 'Style', app.AppStyle, ...
        'Text', 'AVAILABLE CHANNELS', ...
        'FontWeight', '700', ...
        'FontSize', app.FontSizeTitle, ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top');

    availTable = CSSuiTable(leftCol, ...
        'Data', tableData, ...
        'ColumnName', {'Channel', 'Fs (Hz)', 'Info'}, ...
        'ColumnWidth', [150, 170, 230], ...
        'Style', app.AppStyle, ...
        'SelectionType', 'row', ...
        'RowClickMode', 'toggle', ...
        'ColumnResizable', true, ...
        'SelectionChangedFcn', @(s,e) onAvailSelect(e), ...
        'DoubleClickFcn', @(s,e) onAvailDoubleClick(e));
    availTable.Layout.Row    = 2;
    availTable.Layout.Column = 1;
    availTable.HTMLComponent.Tooltip = ['Every channel available to the batch — both EDF ' ...
        'labels and any derived channels you''ve built. Double-click a row to add it ' ...
        'as a passthrough output, or select one or more rows (Ctrl/Shift-click) to use as ' ...
        'sources for the middle-column buttons.'];

    CSSuiLabel(leftCol, 'Style', app.AppStyle, ...
        'Text', 'DERIVE CHANNEL', ...
        'FontWeight', '700', ...
        'FontSize', app.FontSizeTitle, ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top');

    % Button row: derived-channel creators + a single Remove that
    % only deletes Derived rows (EDF rows are immutable).
    derivedBtnRow = uigridlayout(leftCol);
    derivedBtnRow.Layout.Row    = 4;
    derivedBtnRow.RowHeight     = {44};
    derivedBtnRow.ColumnWidth   = {'1x', '1x', '1x', '1x'};
    derivedBtnRow.Padding       = [0 0 0 0];
    derivedBtnRow.ColumnSpacing = 6;
    refMeanBtn = CSSuiButton(derivedBtnRow, 'Style', app.AppStyle, ...
        'Text', 'Mean', ...
        'ButtonPushedFcn', @(s,e) addRefMean());
    refMeanBtn.HTMLComponent.Tooltip = ['Create a derived channel: the mean of two or more ' ...
        'available channels. Opens a popup pre-selected with whatever you have selected ' ...
        'in the Available Channels table.'];
    refABMinusBtn = CSSuiButton(derivedBtnRow, 'Style', app.AppStyle, ...
        'Text', 'Difference', ...
        'ButtonPushedFcn', @(s,e) addRefABMinus());
    refABMinusBtn.HTMLComponent.Tooltip = ['Create a derived channel as the difference A − B. ' ...
        'Opens a popup with two channel pickers and a name field.'];
    refCustomBtn = CSSuiButton(derivedBtnRow, 'Style', app.AppStyle, ...
        'Text', 'ƒ(x) Custom', ...
        'ButtonPushedFcn', @(s,e) addRefCustom());
    refCustomBtn.HTMLComponent.Tooltip = ['Create a derived channel from a free-form ' ...
        'expression (e.g., (A1 + A2) / 2 or C3 - mean(A1, A2)). A name is required.'];
    refRemoveBtn = CSSuiButton(derivedBtnRow, 'Style', app.AppStyle, ...
        'Text', 'Remove', ...
        'Icon', trashIcon, 'IconPosition', 'right', 'IconSize', '1.4em', ...
        'ButtonPushedFcn', @(s,e) removeRef());
    refRemoveBtn.HTMLComponent.Tooltip = ['Remove the selected derived channel(s). EDF ' ...
        'channels can''t be removed. If any output channels use the derived channel ' ...
        'being removed, you''ll be warned before they''re removed too.'];

    % ---- COL 2: middle button stack (Output Channel ops) ----
    % Vertical stack of the four operations that produce output
    % rows. Centered in the available height with 1x stretch
    % spacers above and below so the cluster sits next to the
    % Output Channels table on the right.
    midCol = uigridlayout(outer);
    midCol.Layout.Row    = 2;
    midCol.Layout.Column = 2;
    midCol.RowHeight     = {30, '1x', 48, 48, 48, 48, '1x'};
    midCol.ColumnWidth   = {'1x'};
    midCol.Padding       = [0 0 0 0];
    midCol.RowSpacing    = 8;
    CSSuiLabel(midCol, 'Style', app.AppStyle, ...
        'Text', 'BUILD OUTPUT', ...
        'FontWeight', '700', ...
        'FontSize', app.FontSizeTitle, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top');
    uipanel(midCol, 'BorderType', 'none');   % top stretch spacer
    chanAddBtn = CSSuiButton(midCol, 'Style', app.AppStyle, ...
        'Text', 'Add', ...
        'Icon', doubleRightIcon, 'IconPosition', 'right', 'IconSize', '1.4em', ...
        'ButtonPushedFcn', @(s,e) addPassthrough());
    chanAddBtn.HTMLComponent.Tooltip = ['Add a passthrough output for each channel ' ...
        'currently selected in Available Channels (no referencing applied).'];
    chanRemoveBtn = CSSuiButton(midCol, 'Style', app.AppStyle, ...
        'Text', 'Remove', ...
        'Icon', trashIcon, 'IconPosition', 'right', 'IconSize', '1.4em', ...
        'ButtonPushedFcn', @(s,e) removeChan());
    chanRemoveBtn.HTMLComponent.Tooltip = 'Remove the selected output channel.';
    refSubtractBtn = CSSuiButton(midCol, 'Style', app.AppStyle, ...
        'Text', 'Rereference', ...
        'ButtonPushedFcn', @(s,e) addReferenceSubtraction());
    refSubtractBtn.HTMLComponent.Tooltip = ['Subtract a chosen reference from each ' ...
        'selected available channel and add one output row per channel ' ...
        '(e.g., C3, C4 with reference M → C3-M, C4-M).'];
    chanCustomBtn = CSSuiButton(midCol, 'Style', app.AppStyle, ...
        'Text', 'ƒ(x) Custom', ...
        'ButtonPushedFcn', @(s,e) addCustomChannel());
    chanCustomBtn.HTMLComponent.Tooltip = ['Add an output channel from a free-form ' ...
        'expression (e.g., C3 - (A1 + A2)/2). Output name is optional.'];
    uipanel(midCol, 'BorderType', 'none');   % bottom stretch spacer

    % ---- ROW 2 / COL 3: Output Channels (full height) ----
    outPanel = uigridlayout(outer);
    outPanel.Layout.Row    = 2;
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
    % Stack the placeholder textarea and the table in the same grid
    % cell — refresh() flips Visible based on chansState. Mirrors the
    % References panel pattern and gives first-time users a clear
    % "where to start" cue when the table is empty.
    chanEmptyHelp = CSSuiTextArea(outPanel, ...
        'Style', app.AppStyle, ...
        'Editable', false, ...
        'WordWrap', true, ...
        'Value', sprintf(['No output channels yet.\n\n' ...
            '↑  Pick a row on the left and click  →  Add  in the middle column,\n' ...
            'or  double-click a row on the left  to add it as a passthrough.\n\n' ...
            'For referenced channels: build a reference below first, then\n' ...
            'click  −  Rereference  on selected available channels.']));
    chanEmptyHelp.Layout.Row    = 2;
    chanEmptyHelp.Layout.Column = 1;
    chanTable = CSSuiTable(outPanel, ...
        'Data', chanRowsToTable(chansState), ...
        'ColumnName', {'✎ Output Name', 'Expression'}, ...
        'ColumnWidth', [160, 420], ...
        'ColumnEditable', [true false], ...
        'ColumnResizable', true, ...
        'CellEditCallback', @(s,e) onChanCellEdit(e), ...
        'Style', app.AppStyle, ...
        'SelectionType', 'row', ...
        'SelectionChangedFcn', @(s,e) onChanSelect(e));
    chanTable.Layout.Row    = 2;
    chanTable.Layout.Column = 1;
    chanTable.HTMLComponent.Tooltip = ['Output channels — one DYNAM-O run per row. Click ' ...
        'an Output Name cell (✎) to rename it (optional alias); leave it blank to use the ' ...
        'expression as the output name. Expression is read-only — to change it, remove ' ...
        'the row and re-add it with a middle-column button.'];

    % ---- Bottom row: status (left) + Help / Save / Cancel (right) ----

    bottomRow = uigridlayout(outer);
    bottomRow.Layout.Row    = 3;
    bottomRow.Layout.Column = [1 3];
    bottomRow.RowHeight     = {'1x'};
    bottomRow.ColumnWidth   = {'1x', 110, 150, 110};
    bottomRow.Padding       = [0 0 0 0];
    bottomRow.ColumnSpacing = 8;
    % Status panel inside the bottom row's first cell. setStatus()
    % paints its BackgroundColor to colour-stripe by severity
    % (info / warn / error). The colour stops at the buttons so the
    % stripe doesn't bleed under Help / Save / Cancel.
    statusBar = uigridlayout(bottomRow);
    statusBar.Layout.Row    = 1;
    statusBar.Layout.Column = 1;
    statusBar.RowHeight     = {'1x'};
    statusBar.ColumnWidth   = {'1x'};
    statusBar.Padding       = [10 4 10 4];
    statusBar.BackgroundColor = [0.96 0.97 0.99];
    statusLabel = CSSuiLabel(statusBar, ...
        'Style', app.AppStyle, 'Text', '');
    statusLabel.Layout.Row    = 1;
    statusLabel.Layout.Column = 1;
    helpBtn = CSSuiButton(bottomRow, 'Style', app.AppStyle, ...
        'Text', 'Help', ...
        'Icon', helpIcon, 'IconPosition', 'right', 'IconSize', '1.5em', ...
        'ButtonPushedFcn', @(s,e) showHelp());
    helpBtn.HTMLComponent.Tooltip = 'Show help for this dialog.';
    okBtn = CSSuiButton(bottomRow, 'Style', app.AppStyle, ...
        'Text', 'Save and Close', 'ButtonPushedFcn', @(s,e) doOk());
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
        rebuildAvailable();
        availTable.Data = tableData;
        chanTable.Data  = chanRowsToTable(chansState);
        % Empty-state swap for output channels: show a
        % "where to start" placeholder when the table is empty.
        if isempty(chansState)
            chanEmptyHelp.HTMLComponent.Visible = 'on';
            chanTable.HTMLComponent.Visible     = 'off';
        else
            chanEmptyHelp.HTMLComponent.Visible = 'off';
            chanTable.HTMLComponent.Visible     = 'on';
        end
        [okFlag, msg] = validateAll();
        if okFlag
            setStatus('ok', sprintf('Ready: %d derived channel(s), %d output channel(s). Click Save and Close to apply.', ...
                numel(refsState), numel(chansState)));
        else
            setStatus('error', msg);
        end
        % OK button stays clickable; doOk() runs validateAll
        % again on click and alerts if invalid. Gating the
        % button visually was unreliable across uihtml refreshes
        % and confused users into thinking the dialog was stuck.
    end

    function rebuildAvailable()
        % EDF rows (immutable) + Derived rows from refsState.
        % Derived appear after the EDF block so the EDF labels stay
        % in their familiar alphabetical order. Newest derived row
        % lands at the bottom — easy to spot right after creation.
        nDerived = numel(refsState);
        if nDerived == 0
            tableData = edfBaseRows;
            return
        end
        m = fullFsMap();
        derivedRows = cell(nDerived, 3);
        for k = 1:nDerived
            [nm, ex] = splitNameExpr(refsState{k});
            if isempty(nm), nm = '(unnamed)'; end
            if isKey(m, nm) && ~isnan(m(nm))
                fsStr = sprintf('%g Hz', m(nm));
            else
                fsStr = '— (mixed)';
            end
            derivedRows{k,1} = nm;
            derivedRows{k,2} = fsStr;
            derivedRows{k,3} = ex;
        end
        tableData = [edfBaseRows; derivedRows];
    end

    function setStatus(level, msg)
        % Colour-stripe the status bar by severity so warnings and
        % errors aren't lost in the bottom-strip text. Levels:
        %   'ok'    - light grey   (resting state, ready to save)
        %   'info'  - light blue   (in-flight info, e.g. action hint)
        %   'warn'  - amber        (Fs mismatch, resample suggestion)
        %   'error' - red          (parse error, name collision, etc.)
        switch lower(level)
            case 'ok'
                statusBar.BackgroundColor = [0.96 0.97 0.99];
                prefix = '';
            case 'info'
                statusBar.BackgroundColor = [0.92 0.96 1.00];
                prefix = 'ⓘ  ';
            case 'warn'
                statusBar.BackgroundColor = [1.00 0.95 0.82];
                prefix = '⚠  Warning: ';
            case 'error'
                statusBar.BackgroundColor = [1.00 0.90 0.90];
                prefix = '✕  Problem: ';
            otherwise
                statusBar.BackgroundColor = [0.96 0.97 0.99];
                prefix = '';
        end
        statusLabel.Text = [prefix, msg];
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
        pushChan(tableData{r,1});
        refresh();
    end

    function n = pushChan(s)
        % Append `s` to chansState only if it isn't already there.
        % De-duplication is literal: trim + collapse whitespace +
        % case-fold, no semantic equivalence ('C3' vs 'C3 = C3' are
        % treated as distinct). Returns 1 if appended, 0 if skipped.
        n = 0;
        s = strtrim(s);
        if isempty(s), return, end
        cand = lower(regexprep(s, '\s+', ' '));
        for k = 1:numel(chansState)
            if strcmp(lower(regexprep(chansState{k}, '\s+', ' ')), cand) %#ok<STCI>
                return
            end
        end
        chansState{end+1} = s;
        n = 1;
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

    % ---- Derived channels: popup-driven creators + cascade-aware remove ----
    %
    % All three creators (+ Mean / + Difference / + Custom) open a
    % focused modal popup that captures the inputs in one shot, then
    % validate Fs uniformity and name-uniqueness before appending to
    % refsState. `refsState` maps 1:1 to app.ReferenceList at OK
    % time, so every derived channel is passed downstream as a
    % named-derivation prefix to read_EDF — exactly as before, just
    % surfaced through a unified UI.

    function addRefABMinus()
        % Difference — pick A and B (any available channel,
        % EDF or already-derived) and name the result.
        aug = augmentedLabels();
        if numel(aug) < 2
            uialert(d, 'Need at least two channels to form a difference.', ...
                'Difference', 'Icon', 'info');
            return
        end
        [chA, chB, alias] = promptDifference(aug, suggestName('D'));
        if isempty(chA), return, end
        if ~validateNewDerivedName(alias, 'Difference'), return, end
        m = fullFsMap();
        [okFs, msgFs] = uniformFs({chA, chB}, m);
        if ~okFs
            uialert(d, msgFs, 'Mixed sampling rates', 'Icon', 'error');
            return
        end
        refsState{end+1} = sprintf('%s = %s-%s', alias, chA, chB);
        refresh();
    end

    function addRefMean()
        % Mean — popup-driven: a multi-select listbox of every
        % available channel (EDF + already-derived) and a name
        % field. Need at least 2 picks; all picks must share Fs.
        % Whatever the user has selected in the Available Channels
        % table is pre-selected in the popup so a workflow of
        % "shift-click 4 mastoids → click + Mean → tweak name → OK"
        % takes only one extra interaction.
        items = augmentedLabels();
        if numel(items) < 2
            uialert(d, 'Need at least two channels to form a mean.', ...
                'Mean', 'Icon', 'info');
            return
        end
        if ~isempty(availSelectedRows)
            picksInit = tableData(availSelectedRows, 1);
            picksInit = picksInit(:)';
        else
            picksInit = {};
        end
        [picks, alias] = promptMean(items, suggestName('M'), picksInit);
        if isempty(picks), return, end
        if numel(picks) < 2
            uialert(d, 'Pick at least two channels for a mean.', ...
                'Mean', 'Icon', 'error');
            return
        end
        if ~validateNewDerivedName(alias, 'Mean'), return, end
        m = fullFsMap();
        [okFs, msgFs] = uniformFs(picks(:)', m);
        if ~okFs
            uialert(d, msgFs, 'Mixed sampling rates', 'Icon', 'error');
            return
        end
        refsState{end+1} = sprintf('%s = mean(%s)', alias, strjoin(picks, ', '));
        refresh();
    end

    function addRefCustom()
        % Custom — free-text expression validated against the
        % full augmented label set (EDF + already-derived). Name
        % is required so the result can be reused / removed.
        [nm, ex] = promptCustom('Create Custom Derived Channel', true, augmentedLabels(), suggestName('C'));
        if isempty(ex), return, end
        if ~validateNewDerivedName(nm, 'Custom'), return, end
        [~, ~, leaves] = checkLeaves(ex, augmentedLabels());
        m = fullFsMap();
        [okFs, msgFs] = uniformFs(leaves, m);
        if ~okFs
            uialert(d, msgFs, 'Mixed sampling rates', 'Icon', 'error');
            return
        end
        refsState{end+1} = sprintf('%s = %s', nm, ex);
        refresh();
    end

    function removeRef()
        % Operates on the unified Available Channels selection,
        % but only Derived rows are removable — EDF rows are
        % immutable. Cascade rule unchanged: any output channel
        % whose expression cites a removed derived name is
        % flagged for cascade removal.
        if isempty(availSelectedRows), return, end
        % Derived rows live after the EDF block in tableData;
        % map selected row indices back to refsState indices.
        nEdf = size(edfBaseRows, 1);
        derivedSel = availSelectedRows(availSelectedRows > nEdf) - nEdf;
        derivedSel = derivedSel(derivedSel >= 1 & derivedSel <= numel(refsState));
        if isempty(derivedSel)
            uialert(d, 'EDF channels can''t be removed. Select one or more Derived rows.', ...
                'Remove', 'Icon', 'info');
            return
        end
        removedNames = {};
        for kk = 1:numel(derivedSel)
            n2 = firstName(refsState{derivedSel(kk)});
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
                ['Removing derived channel(s) %s will also remove %d output channel(s) that use them:\n\n%s\n\n' ...
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
        refsState(derivedSel) = [];
        availSelectedRows = [];
        refresh();
    end

    function nm = suggestName(prefix)
        % Suggest <prefix><N> picking the lowest N not already in use
        % across EDF labels and existing derived names. Used to
        % pre-fill the Name field in each popup.
        used = [all_edf_labels, ...
            cellfun(@firstName, refsState, 'UniformOutput', false)];
        used = used(~cellfun(@isempty, used));
        for k = 1:999
            cand = sprintf('%s%d', prefix, k);
            if ~any(strcmpi(cand, used))
                nm = cand; return
            end
        end
        nm = prefix;  % fallback (shouldn't happen)
    end

    function ok = validateNewDerivedName(nm, label)
        % Inline-fail with a clear alert before the row is
        % committed. Catches collisions with EDF labels and with
        % existing derived names.
        ok = false;
        if isempty(nm)
            uialert(d, 'Name is required.', label, 'Icon', 'error');
            return
        end
        if any(strcmpi(nm, all_edf_labels))
            uialert(d, sprintf('"%s" collides with an EDF channel label.', nm), ...
                label, 'Icon', 'error');
            return
        end
        existing = cellfun(@firstName, refsState, 'UniformOutput', false);
        if any(strcmpi(nm, existing))
            uialert(d, sprintf('"%s" is already a derived channel name.', nm), ...
                label, 'Icon', 'error');
            return
        end
        ok = true;
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
            pushChan(lbls{kk});
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
            uialert(d, 'No channels available to subtract.', ...
                'Rereference', 'Icon', 'info');
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
            pushChan(sprintf('%s-%s', lbls{kk}, pick));
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
            pushChan(ex);
        else
            pushChan(sprintf('%s = %s', alias, ex));
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
'<h1>Channels &amp; Derived Channels Composer</h1>' ...
'<div class="subtitle">Build the list of <i>output channels</i> DYNAM-O will analyze. Each output channel is one row in the right-hand table — one DYNAM-O run per subject per row.</div>' ...
'<h2>Typical workflow</h2>' ...
'<ol>' ...
'  <li><i>(Optional)</i> Build mastoid / linked-ear or any other derived channels with the <span class="btn">+ Mean</span>, <span class="btn">+ Difference</span>, or <span class="btn">+ Custom</span> buttons above the Available Channels table. They appear in the same table marked <code>Derived</code>.</li>' ...
'  <li>Select one or more rows in <b>Available Channels</b> (EDF or Derived).</li>' ...
'  <li>Click <span class="btn">→ Add</span> for a passthrough output, or <span class="btn">− Rereference</span> to subtract a chosen channel from each selected row.</li>' ...
'  <li>Use <span class="btn">ƒ(x) Custom</span> for anything more complex.</li>' ...
'  <li>Rename outputs in place (Output Name column).</li>' ...
'  <li>Click <span class="btn">Save and Close</span> to commit.</li>' ...
'</ol>' ...
'<h2>Panels</h2>' ...
'<div class="panel"><div class="panel-title">Available Channels (left)</div>' ...
'<div class="panel-meta">read-only · double-click adds as passthrough</div>' ...
'Every channel available to the batch — EDF labels sourced from the loaded files plus any derived channels built with the buttons above. The <i>Fs</i> column shows the resampled rate when <b>Resample data</b> is on in the main panel; otherwise the native rate(s) per file. The <i>Info</i> column shows file coverage (e.g. <code>5 / 10 files</code>) for EDF rows and the formula for derived rows.' ...
'</div>' ...
'<div class="panel"><div class="panel-title">Output Channels (right)</div>' ...
'<div class="panel-meta">edit Output Name in place</div>' ...
'The final list. One DYNAM-O run per row. The Output Name becomes the output directory name. Leave blank to use the expression as the name.' ...
'</div>' ...
'<h2>Buttons</h2>' ...
'<b>Above Available Channels (create derived):</b>' ...
'<ul>' ...
'  <li><span class="btn">+ Mean</span> &nbsp; Popup with multi-select listbox; pick 2+ channels and a name → <code>NAME = mean(...)</code>.</li>' ...
'  <li><span class="btn">+ Difference</span> &nbsp; Popup with two dropdowns and a name → <code>NAME = A-B</code>.</li>' ...
'  <li><span class="btn">+ Custom</span> &nbsp; Popup with a free-text expression and a name → <code>NAME = expression</code>.</li>' ...
'  <li><span class="btn">✕ Remove</span> &nbsp; Delete the selected Derived row(s). EDF rows are immutable. Output channels that depend on a removed derived channel are flagged for cascade removal first.</li>' ...
'</ul>' ...
'<b>Middle column (build output):</b>' ...
'<ul>' ...
'  <li><span class="btn">→ Add</span> &nbsp; Add each selected Available row as a passthrough output (no math).</li>' ...
'  <li><span class="btn">✕ Remove</span> &nbsp; Remove the selected output row(s).</li>' ...
'  <li><span class="btn">− Rereference</span> &nbsp; Subtract a chosen channel (EDF or derived) from each selected Available row. Produces one output row per selection.</li>' ...
'  <li><span class="btn">ƒ(x) Custom</span> &nbsp; Free-text output expression with optional alias.</li>' ...
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
'<div class="callout"><b>Editing.</b> Only the <i>Output Name</i> column on the right is editable in place. To change a derived channel''s expression, Remove it and re-add it via the appropriate button. This guarantees every expression was constructed by the GUI and is well-formed.</div>' ...
'</body></html>'];

        hpW = 760; hpH = 720;
        hp = uifigure('Name', 'Channel Composer Help', ...
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

    function [nm, ex] = promptCustom(title, nameRequired, augLabels, suggestedName)
        % Custom name + expression dialog. Validates the
        % expression (via checkLeaves) against augLabels before
        % closing; if the user supplies an unknown label, the
        % dialog stays open with a uialert. The name is either
        % marked '(required)' or '(optional)' in the label and
        % enforced at the OK handler. suggestedName pre-fills the
        % name field (the caller usually computes it via
        % suggestName(prefix)); pass '' to leave blank.
        if nargin < 4, suggestedName = ''; end
        pdW = 520; pdH = 220; pdPad = 12;
        pd = uifigure('Name', title, ...
            'Position', [(ss(3)-pdW)/2, (ss(4)-pdH)/2, pdW, pdH], ...
            'WindowStyle', 'modal');
        if nameRequired
            nameLabelText = 'Name (required):';
        else
            nameLabelText = 'Name (optional):';
        end
        CSSuiLabel(pd, 'Style', app.AppStyle, 'Text', nameLabelText, ...
            'Position', [pdPad, pdH-pdPad-22, pdW-2*pdPad, 22]);
        efN = CSSuiEditField(pd, 'Style', app.AppStyle, 'Value', suggestedName, ...
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

    function [chA, chB, alias] = promptDifference(labels, suggestedName)
        % "A − B" picker: two dropdowns + name field. Validates
        % A != B; the resulting 'CHA-CHB' string is lexically
        % valid by construction (both leaves are members of the
        % augmented label set). Name is required so the result
        % is referenceable from later expressions / output rows.
        if nargin < 2, suggestedName = ''; end
        pdW = 540; pdH = 220; pdPad = 12;
        pd = uifigure('Name', 'Create Derived Channel — Difference (A − B)', ...
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
        CSSuiLabel(pd, 'Style', app.AppStyle, 'Text', 'Name (required):', ...
            'Position', [pdPad, pdH-pdPad-32-32-6-22, pdW-2*pdPad, 22]);
        efAlias = CSSuiEditField(pd, 'Style', app.AppStyle, 'Value', suggestedName, ...
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
            candAlias = strtrim(efAlias.Value);
            if isempty(candAlias)
                uialert(pd, 'Name is required.', 'Missing name', 'Icon', 'error');
                return
            end
            chA = candA; chB = candB; alias = candAlias;
            if isvalid(pd), delete(pd); end
        end
        function doCan()
            chA = ''; chB = ''; alias = '';
            if isvalid(pd), delete(pd); end
        end
    end

    function [picks, alias] = promptMean(items, suggestedName, preselected)
        % Mean popup — multi-select listbox of every available
        % channel + name field. Need at least 2 picks. The
        % returned `picks` is a cell of selected label strings;
        % `alias` is the user-supplied name. Caller validates
        % Fs uniformity and name uniqueness.
        % `preselected` (cell of label strings) is set as the
        % initial listbox value so the popup opens with whatever
        % the caller had highlighted in the parent table.
        if nargin < 2, suggestedName = ''; end
        if nargin < 3, preselected = {}; end
        pdW = 520; pdH = 380; pdPad = 12;
        pd = uifigure('Name', 'Create Derived Channel — Mean', ...
            'Position', [(ss(3)-pdW)/2, (ss(4)-pdH)/2, pdW, pdH], ...
            'WindowStyle', 'modal');
        CSSuiLabel(pd, 'Style', app.AppStyle, ...
            'Text', 'Pick two or more channels to average:', ...
            'Position', [pdPad, pdH-pdPad-22, pdW-2*pdPad, 22]);
        lbBox = CSSuiListBox(pd, 'Style', app.AppStyle, ...
            'Items', items, ...
            'Multiselect', true, ...
            'Position', [pdPad, pdH-pdPad-22-200-6, pdW-2*pdPad, 200]);
        if ~isempty(preselected)
            % Filter to labels that actually appear in `items` so
            % we don't error on a stale label.
            keep = preselected(ismember(preselected, items));
            if ~isempty(keep)
                lbBox.Value = keep;
            end
        end
        CSSuiLabel(pd, 'Style', app.AppStyle, 'Text', 'Name (required):', ...
            'Position', [pdPad, pdH-pdPad-22-200-6-22-6, pdW-2*pdPad, 22]);
        efAlias = CSSuiEditField(pd, 'Style', app.AppStyle, ...
            'Value', suggestedName, ...
            'Position', [pdPad, pdH-pdPad-22-200-6-22-6-32, pdW-2*pdPad, 32]);
        picks = {}; alias = '';
        CSSuiButton(pd, 'Style', app.AppStyle, 'Text', 'OK', ...
            'Position', [pdW-2*90-pdPad-8, pdPad, 90, 36], ...
            'ButtonPushedFcn', @(s,e) doOk());
        CSSuiButton(pd, 'Style', app.AppStyle, 'Text', 'Cancel', ...
            'Position', [pdW-90-pdPad, pdPad, 90, 36], ...
            'ButtonPushedFcn', @(s,e) doCan());
        uiwait(pd);
        function doOk()
            sel = lbBox.Value;
            if ischar(sel), sel = {sel}; end
            if isstring(sel), sel = cellstr(sel); end
            if numel(sel) < 2
                uialert(pd, 'Pick at least two channels.', 'Need 2+', 'Icon', 'error');
                return
            end
            candAlias = strtrim(efAlias.Value);
            if isempty(candAlias)
                uialert(pd, 'Name is required.', 'Missing name', 'Icon', 'error');
                return
            end
            picks = sel(:)'; alias = candAlias;
            if isvalid(pd), delete(pd); end
        end
        function doCan()
            picks = {}; alias = '';
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
        % Helper consumes a 2-column slice {label, fs_string}; the
        % first two cols of tableData match that shape.
        validateChannelSamplingRates(app, chansState, tableData(:, [1 2]));
        app.refreshChannelTooltips();
        if isvalid(d), delete(d); end
    end

    function doCancel()
        if isvalid(d), delete(d); end
    end

end
