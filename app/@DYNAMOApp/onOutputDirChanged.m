function onOutputDirChanged(app)
    % onOutputDirChanged  Validate the output directory and ensure it
    % terminates in a DYNAM-O_results folder.
    %
    %   Called whenever the output directory path is modified (Browse,
    %   direct text entry, or constructor quick-fill). The chosen path
    %   is treated as the parent in which a DYNAM-O_results folder
    %   lives — if the user already pointed at a DYNAM-O_results
    %   folder we leave the path alone (no .../DYNAM-O_results/DYNAM-O_results
    %   nesting). The parent must exist (prompt-to-create if not);
    %   the DYNAM-O_results subfolder is created silently.

    pathStr = char(app.OutputDirEditField.Value);
    if isempty(pathStr)
        return;
    end

    % Strip trailing path separators so fileparts sees the leaf.
    while ~isempty(pathStr) && ...
            (pathStr(end) == '/' || pathStr(end) == filesep)
        pathStr(end) = [];
    end

    [~, leaf] = fileparts(pathStr);
    if strcmp(leaf, 'DYNAM-O_results')
        targetDir = pathStr;
        parentDir = fileparts(pathStr);
    else
        parentDir = pathStr;
        targetDir = fullfile(pathStr, 'DYNAM-O_results');
    end

    % Parent must exist — keep the existing prompt behaviour.
    if ~isfolder(parentDir)
        selection = uiconfirm(app.UIFigure, ...
            sprintf('Directory does not exist:\n%s\nCreate it?', parentDir), ...
            'Create Directory?', 'Options', {'Yes','No'}, 'DefaultOption', 2);
        if strcmp(selection, 'Yes')
            mkdir(parentDir);
        else
            app.OutputDirEditField.Value = '';
            return;
        end
    end

    % DYNAM-O_results itself is always created silently.
    if ~isfolder(targetDir)
        mkdir(targetDir);
    end

    app.OutputDirEditField.Value = targetDir;
end
