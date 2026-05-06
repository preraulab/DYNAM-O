function p = paramfitAggregatePath(app, channelName, axisKind)
    % paramfitAggregatePath  Resolve the on-disk path for the
    %   paramfit aggregate of one (channel, axis) pair.
    %   Prefers .mat, falls back to .csv, returns "" when
    %   neither exists. Centralizes the
    %   <root>/aggregates/<chan>/param_basis_<axis>/
    %   <chan>_aggregate_SO<axis>_paramfit.{mat,csv} convention
    %   so hasModeParamData and the loader can't drift apart.
    p = "";
    root = strtrim(char(app.ResultsBrowserOutputDirField.Value));
    if isempty(root) || ~isfolder(root), return, end
    base = fullfile(root, 'aggregates', channelName, ...
        ['param_basis_' axisKind], ...
        [channelName '_aggregate_SO' axisKind '_paramfit']);
    if isfile([base '.mat'])
        p = string([base '.mat']); return
    end
    if isfile([base '.csv'])
        p = string([base '.csv']); return
    end
end
