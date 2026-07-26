function [merged, unknown] = mergeOptionStructs(app, current, fromJson) %#ok<INUSL>
    % mergeOptionStructs  Tolerant field-by-field merge of an option struct.
    %
    %   [merged, unknown] = mergeOptionStructs(app, current, fromJson)
    %
    %   For each field present in `fromJson` that also exists in `current`,
    %   the value from `fromJson` is copied into `merged`. Fields present in
    %   `current` but absent from `fromJson` are kept at their current value
    %   (this is how schema additions stay backwards-compatible). Fields
    %   present only in `fromJson` are skipped and their names are returned
    %   in `unknown` so the caller can warn the user.
    %
    %   `app` is accepted only so this can be a class method (called as
    %   `app.mergeOptionStructs(...)`); it is otherwise unused.
    %
    %   See also: loadBatchSettingsFromFile.
    %
    % =====================================================================
    %                   DYNAM-O Toolbox  |  Prerau Laboratory
    % =====================================================================

    merged  = current;
    unknown = {};

    if ~isstruct(fromJson)
        return
    end
    if ~isstruct(current)
        % Nothing to merge into — accept whatever the JSON has.
        merged = fromJson;
        return
    end

    fns = fieldnames(fromJson);
    for k = 1:numel(fns)
        f = fns{k};
        if isfield(current, f)
            merged.(f) = fromJson.(f);
        else
            unknown{end+1} = f; %#ok<AGROW>
        end
    end
end
