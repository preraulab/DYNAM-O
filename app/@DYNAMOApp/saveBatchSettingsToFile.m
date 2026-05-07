function saveBatchSettingsToFile(app)
    % saveBatchSettingsToFile  Save the current batch run settings to a JSON
    % file the user picks. The file captures both the 7 DYNAM-O option
    % structs and the GUI batch-level state (file lists, output dir, save
    % toggles, channel/reference, stage labels, etc.) so the run can be
    % reloaded into the GUI in a future session.
    %
    %   File format: schema_version 2, written by generate_run_log.
    %
    %   See also: loadBatchSettingsFromFile, collectBatchSettings,
    %             generate_run_log.
    %
    % =====================================================================
    %                   DYNAM-O Toolbox  |  Prerau Laboratory
    % =====================================================================

    default_name = sprintf('batch_settings_%s.json', char(datetime('now','Format','yyyyMMdd_HHmmss')));
    [filename, filepath] = uiputfile( ...
        {'*.json', 'JSON Files (*.json)'; '*.*', 'All Files (*.*)'}, ...
        'Save Batch Settings As', default_name);

    if isequal(filename, 0)
        return
    end
    full_path = fullfile(filepath, filename);

    % Refresh the option struct snapshot before serialising.
    app.buildOptionsStruct();

    batch_settings = app.collectBatchSettings();
    run_start = char(datetime('now','Format','yyyyMMdd_HHmmss'));

    try
        generate_run_log( ...
            app.options_structs, app.struct_names, ...
            'run_start',      run_start, ...
            'batch_settings', batch_settings, ...
            'out_path',       full_path);
    catch ME
        uialert(app.UIFigure, sprintf('Could not save settings:\n%s', ME.message), ...
            'Save Batch Settings', 'Icon', 'error');
        return
    end

    uialert(app.UIFigure, sprintf('Batch settings saved to:\n%s', full_path), ...
        'Save Batch Settings', 'Icon', 'success');
end
