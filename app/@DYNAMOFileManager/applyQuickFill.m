function applyQuickFill(app, opts)
    % applyQuickFill  Populate file lists / staging fields from
    % constructor Name-Value pairs so a launch like
    %   DYNAMOFileManager('EDFPath','/x','StagingPath','/x', ...
    %                     'OutputPath','/x','Delimiter','Tab', ...
    %                     'StagesColumn',2,'TimesColumn',3, ...
    %                     'HeaderRows',14)
    % skips the manual click-through every test cycle.

    % EDF folder → glob *.edf, *.edf.gz, *.edf.zst → data list
    if ~isempty(opts.EDFPath)
        folder = char(opts.EDFPath);
        if isfolder(folder)
            files = [dir(fullfile(folder, '*.edf')); ...
                     dir(fullfile(folder, '*.edf.gz')); ...
                     dir(fullfile(folder, '*.edf.zst'))];
            if ~isempty(files)
                paths = arrayfun(@(f) fullfile(f.folder, f.name), ...
                    files, 'UniformOutput', false);
                app.addDataFiles(paths(:)');
            else
                warning('DYNAMOFileManager:noEDFs', ...
                    'No .edf, .edf.gz, or .edf.zst files found in %s.', folder);
            end
        else
            warning('DYNAMOFileManager:badEDFPath', ...
                'EDFPath does not exist: %s', folder);
        end
    end

    % Staging folder → glob *.csv, add to staging list
    if ~isempty(opts.StagingPath)
        folder = char(opts.StagingPath);
        if isfolder(folder)
            files = dir(fullfile(folder, '*.csv'));
            if ~isempty(files)
                paths = arrayfun(@(f) fullfile(f.folder, f.name), ...
                    files, 'UniformOutput', false);
                app.addStagingFiles(paths(:)');
            else
                warning('DYNAMOFileManager:noCSVs', ...
                    'No .csv files found in %s.', folder);
            end
        else
            warning('DYNAMOFileManager:badStagingPath', ...
                'StagingPath does not exist: %s', folder);
        end
    end

    if ~isempty(opts.OutputPath)
        app.OutputDirEditField.Value = char(opts.OutputPath);
        app.onOutputDirChanged();
    end

    % Channel labels → comma-separated string in the Channel(s) field.
    % Accepts char, string scalar/array, or cellstr; multi-entry inputs
    % are joined with ', ' to match the format the field expects.
    % The field is created disabled (composer is the primary writer);
    % CSSuiEditField drops setValue while disabled, so we must enable
    % first, then write, then drop back into the populated read-only
    % display state. We also assign ChannelList directly so the
    % parsed list is correct even if the JS-side Value write races.
    if ~isempty(opts.Channels)
        if ischar(opts.Channels)
            chanStr = strtrim(opts.Channels);
        elseif isstring(opts.Channels)
            parts   = strtrim(string(opts.Channels(:)));
            parts   = parts(strlength(parts) > 0);
            chanStr = char(strjoin(parts, ', '));
        else  % cellstr
            parts   = strtrim(opts.Channels(:));
            parts   = parts(~cellfun('isempty', parts));
            chanStr = strjoin(parts, ', ');
        end
        if ~isempty(chanStr)
            app.ChannelEditField.Enabled  = true;
            app.ChannelEditField.Editable = false;
            app.ChannelEditField.Value    = chanStr;
            app.ChannelList = app.splitTopLevelCommas(chanStr);
        end
    end

    if ~isempty(opts.Delimiter)
        d = char(opts.Delimiter);
        switch d
            case {'Comma', ','},                 label = 'Comma';
            case {'Tab', '\t', sprintf('\t')},   label = 'Tab';
            case {'Space', ' '},                 label = 'Space';
            case {'Semicolon', ';'},             label = 'Semicolon';
            otherwise
                warning('DYNAMOFileManager:badDelimiter', ...
                    'Unknown delimiter "%s"; leaving dropdown unchanged.', d);
                label = '';
        end
        if ~isempty(label)
            app.DelimeterOptionField.Value = label;
        end
    end

    if ~isempty(opts.StagesColumn)
        app.StagesColumnEditField.Value = opts.StagesColumn;
    end
    if ~isempty(opts.TimesColumn)
        app.TimesColumnEditField.Value = opts.TimesColumn;
    end
    if ~isempty(opts.HeaderRows)
        app.HeaderRowsEditField.Value = opts.HeaderRows;
    end
end
