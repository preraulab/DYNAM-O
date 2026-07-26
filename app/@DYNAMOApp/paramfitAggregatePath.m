function p = paramfitAggregatePath(app, channelName, axisKind)
    % paramfitAggregatePath  Resolve the on-disk path for the
    %   paramfit aggregate of one (channel, axis) pair.
    %   Probes .h5 → .mat → .csv (mirrors the binary-then-text
    %   precedence used by runGroupStatsSOPH for the SOPHs aggregate).
    %   Returns "" when none exists. Centralizes the
    %   <root>/aggregates/<chan>/param_basis_<axis>/
    %   <chan>_aggregate_SO<axis>_paramfit.{h5,mat,csv} convention so
    %   hasModeParamData and the loader can't drift apart.
    p = "";
    root = strtrim(char(app.ResultsBrowserOutputDirField.Value));
    if isempty(root) || ~isfolder(root), return, end
    base = fullfile(root, 'aggregates', channelName, ...
        ['param_basis_' axisKind], ...
        [channelName '_aggregate_SO' axisKind '_paramfit']);
    for ext = {'.h5', '.mat', '.csv'}
        cand = [base ext{1}];
        if isfile(cand), p = string(cand); return, end
    end
end
