function loadBatchSettingsFromFile(app)
    % loadBatchSettingsFromFile  Restore batch run settings from a JSON file.
    %
    %   Reads a file previously written by saveBatchSettingsToFile (or by
    %   the auto-emitted run_settings_<timestamp>.json that runBatch
    %   produces), then:
    %     - Tolerantly merges each of the 7 DYNAM-O option structs into the
    %       app's current options (unknown fields are warned, missing fields
    %       are left at the current default).
    %     - If batch_settings (schema v2) is present, applies the GUI-level
    %       state via applyBatchSettings.
    %     - For legacy v1 files (options-only), shows an info dialog so the
    %       user knows the file lists and output dir were left untouched.
    %
    %   See also: saveBatchSettingsToFile, applyBatchSettings,
    %             mergeOptionStructs, load_run_log.
    %
    % =====================================================================
    %                   DYNAM-O Toolbox  |  Prerau Laboratory
    % =====================================================================

    [filename, filepath] = uigetfile( ...
        {'*.json', 'JSON Files (*.json)'; '*.*', 'All Files (*.*)'}, ...
        'Select Batch Settings File');

    if isequal(filename, 0)
        return
    end
    full_path = fullfile(filepath, filename);

    try
        S = load_run_log(full_path);
    catch ME
        uialert(app.UIFigure, sprintf('Could not load %s:\n%s', full_path, ME.message), ...
            'Load Batch Settings', 'Icon', 'error');
        return
    end

    % --- Merge the 7 DYNAM-O option structs ----------------------------
    all_unknown = struct();
    if isfield(S, 'options') && isstruct(S.options)
        names = app.struct_names;
        for ii = 1:numel(names)
            n = names{ii};
            if ~isfield(S.options, n), continue; end
            current = app.(n);
            [merged, unknown] = app.mergeOptionStructs(current, S.options.(n));
            app.(n) = merged;
            if ~isempty(unknown)
                all_unknown.(n) = unknown;
            end
        end
        % Refresh the cached snapshot so a subsequent run picks up the new values.
        app.buildOptionsStruct();
    end

    % --- Apply GUI-level state (schema v2+) ----------------------------
    has_batch_settings = isfield(S, 'batch_settings') && isstruct(S.batch_settings);
    if has_batch_settings
        app.applyBatchSettings(S.batch_settings);
    end

    % --- Warn about unknown fields -------------------------------------
    warn_lines = {};
    fns = fieldnames(all_unknown);
    for ii = 1:numel(fns)
        warn_lines{end+1} = sprintf('  %s: %s', fns{ii}, strjoin(all_unknown.(fns{ii}), ', ')); %#ok<AGROW>
    end
    if ~isempty(warn_lines)
        msg = sprintf('Loaded settings contained unknown option fields (skipped):\n%s\n', ...
            strjoin(warn_lines, newline));
        try, app.appendRunLog(msg); catch, end
        try, app.TextArea.addnl(strtrim(msg)); catch, end
    end

    % --- Inform the user about the result ------------------------------
    schema_version = 1;
    if isfield(S, 'schema_version'), schema_version = S.schema_version; end
    if has_batch_settings
        uialert(app.UIFigure, sprintf('Batch settings loaded from:\n%s', full_path), ...
            'Load Batch Settings', 'Icon', 'success');
    else
        uialert(app.UIFigure, ...
            sprintf(['Loaded a legacy options-only settings file (schema v%d):\n%s\n\n', ...
                     'DYNAM-O option structs were applied. File lists, output ', ...
                     'directory, and other GUI-level fields were left unchanged.'], ...
                schema_version, full_path), ...
            'Load Batch Settings', 'Icon', 'info');
    end
end
