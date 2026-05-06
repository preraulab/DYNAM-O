function files = pickFilesViaDialog(app, title, type)
    % pickFilesViaDialog  Open a multi-select file dialog and optionally validate results.
    %
    %   files = pickFilesViaDialog(app, title, type)
    %
    %   Inputs:
    %     title – dialog window title (char)
    %     type  – 'data' | 'staging' | anything else (controls filter list)
    %
    %   Output:
    %     files – cell array of fully-qualified file paths, empty if cancelled.
    %             Passes each path through FileValidationCallback if one is set.

    switch type
        case 'data',    filter = {'*.edf;*.edf.gz;*.edf.zst;*.gz;*.zst', ...
                                  'EDF Files (*.edf, *.edf.gz, *.edf.zst)'; ...
                                  '*.*','All Files'};
        case 'staging', filter = {'*.csv','CSV (*.csv)'; '*.txt','Text (*.txt)'; '*.*','All Files'};
        otherwise,      filter = {'*.*','All Files'};
    end

    [f, p] = uigetfile(filter, title, 'MultiSelect', 'on');
    if isequal(f, 0), files = {}; return; end  % User cancelled

    if ~iscell(f), f = {f}; end  % Wrap single-file selection in a cell
    files = strcat(p, f);

    % Run optional validation callback; keep only files that pass
    if ~isempty(app.FileValidationCallback)
        keep = false(1, numel(files));
        for i = 1:numel(files)
            keep(i) = app.FileValidationCallback(files{i});
        end
        files = files(keep);
    end
end
