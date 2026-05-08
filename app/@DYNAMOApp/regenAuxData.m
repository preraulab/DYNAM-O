function aux = regenAuxData(app)
    % regenAuxData  Build an auxiliary_data struct from in-memory state.
    %
    %   aux = regenAuxData(app)
    %
    %   Tries (in order):
    %     1. Pull SOpower_norm from app.SOPHs if it carries the timeseries
    %        (just-computed batch step, or loaded from a SOPHs .h5/.mat).
    %     2. Call computeSOpower(app.data, app.Fs, ...) to produce
    %        SOpower_norm directly. Cheaper than runDYNAMO since it skips
    %        TF-peak detection, watershed, merge, and SOPH binning.
    %
    %   Returns [] when neither path can run (no SOpower_norm, no data
    %   loaded). Caller is expected to fall through to a heavier path
    %   (typically runStatsTable, which loads the EDF) in that case.
    %
    %   See also: saveAuxData, loadAuxData, writeAuxFormats, computeSOpower.

    aux = [];

    % --- Path 1: peel timeseries off in-memory SOPHs ---
    if ~isempty(app.SOPHs) && isfield(app.SOPHs,'SOpower_norm') && ...
            ~isempty(app.SOPHs.SOpower_norm)
        aux = build_struct_(app, app.SOPHs.SOpower_norm);
        return
    end

    % --- Path 2: compute from raw data ---
    if ~isempty(app.data) && ~isempty(app.Fs)
        try
            opts = app.SOPH_options;
            % computeSOpower's `isexcluded` validator requires logical;
            % runBatch's per-channel reset leaves app.artifacts as []
            % (double) when no runDYNAMO has populated it yet. Coerce
            % defensively so the validator doesn't throw on an empty
            % default.
            isexcl = app.artifacts;
            if isempty(isexcl)
                isexcl = false(numel(app.data), 1);
            elseif ~islogical(isexcl)
                isexcl = logical(isexcl);
            end
            [SOpower_norm, ~, ~, norm_method] = computeSOpower( ...
                app.data, app.Fs, ...
                'EEG_times',        [], ...
                'isexcluded',       isexcl, ...
                'stage_times',      app.stage_times, ...
                'stage_vals',       app.stage_vals, ...
                'norm_method',      opts.SOpower_norm_method, ...
                'retain_Fs',        logical(opts.SOpower_retain_Fs), ...
                'window_params',    double(opts.SOpower_window_params));
            aux = build_struct_(app, SOpower_norm, norm_method);
        catch ME
            app.TextArea.addnl(sprintf('   regenAuxData: computeSOpower failed (%s).', ME.identifier));
            aux = [];
        end
    end
end


function aux = build_struct_(app, SOpower_norm, norm_method)
    if nargin < 3, norm_method = ''; end
    if isempty(norm_method) && isfield(app.SOPH_options,'SOpower_norm_method')
        norm_method = app.SOPH_options.SOpower_norm_method;
    end

    aux = struct();
    aux.artifacts             = app.artifacts;
    aux.Fs                    = app.Fs;
    aux.SOpower_norm_method   = norm_method;
    aux.SOpower_norm          = SOpower_norm;
    aux.stage_times           = app.stage_times;
    aux.stage_vals            = app.stage_vals;
    aux.SOpower_retain_Fs     = logical(app.SOPH_options.SOpower_retain_Fs);
    aux.SOpower_window_params = double(app.SOPH_options.SOpower_window_params(:).');
end
