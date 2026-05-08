function pickMetadataFileViaDialog(app)
    % pickMetadataFileViaDialog  Open a file picker for the subject
    %   metadata sheet and route the choice through setMetadataFile.
    %   Defaults the dialog to the directory of the current path
    %   when one is set; otherwise to the configured output dir;
    %   otherwise to the current working directory.
    filters = { ...
        '*.csv;*.tsv;*.txt;*.xlsx;*.xls', 'Metadata files (CSV / TSV / TXT / XLSX)'; ...
        '*.csv',  'CSV (comma-separated)'; ...
        '*.tsv;*.txt', 'TSV / TXT (tab-separated)'; ...
        '*.xlsx;*.xls', 'Excel workbook'; ...
        '*.*', 'All files'};

    startDir = '';
    if ~isempty(app.MetadataFile_) && isfolder(fileparts(app.MetadataFile_))
        startDir = fileparts(app.MetadataFile_);
    else
        try
            od = char(app.OutputDirEditField.Value);
            if ~isempty(od) && isfolder(od), startDir = od; end
        catch
        end
    end
    if isempty(startDir), startDir = pwd; end

    [fname, fpath] = uigetfile(filters, 'Select subject metadata file', startDir);
    if isequal(fname, 0) || isequal(fpath, 0)
        return
    end
    app.setMetadataFile(fullfile(fpath, fname));
end
