function createRunLogConsole(app)
    % createRunLogConsole  Initialise the per-run file log and write the header.
    %
    %   Creates <OutputDir>/logs/file_log_<timestamp>.txt and
    %   <OutputDir>/settings/run_settings_<timestamp>.json via
    %   generate_run_log (JSON-only since the legacy `.txt` MATLAB-code
    %   format was a code-injection vector when loaded back via run()).
    %   Stores the file handle for subsequent writes. Resets LogBuffer
    %   so the Run Log Console shows only this run.

    generate_run_log(app.options_structs, app.struct_names, ...
        'run_start', app.curr_datetime, ...
        'file_path', strcat(app.OutputDirEditField.Value, '/settings/'));

    app.runlog_fname = matlab.lang.makeValidName(strcat('file_log_', app.curr_datetime, '.txt'));
    app.runlog_fpath = strcat(app.OutputDirEditField.Value, '/logs/');
    app.runlog_fid   = fopen(fullfile(app.runlog_fpath, app.runlog_fname), 'w');

    app.appendRunLog(sprintf('Date and time of run start: %s\n', app.curr_datetime));
    app.appendRunLog(sprintf('Run with settings file: %s\n\n', ...
        strcat('run_settings_', app.curr_datetime, '.json')));
    app.appendRunLog(sprintf('Files run: \n\n'));
end
