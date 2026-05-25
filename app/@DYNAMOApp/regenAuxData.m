function aux = regenAuxData(app)
    % regenAuxData  Build an auxiliary_data struct from in-memory state.
    %
    %   aux = regenAuxData(app)
    %
    %   Tries (in order):
    %     1. Pull SOpower_norm from app.SOPHs if it carries the timeseries
    %        ON ITS NATIVE GRID (just-computed batch step, or loaded from a
    %        SOPHs .h5/.mat). The default SOPHs series is EEG-rate upsampled,
    %        so this shortcut only fires when the grid step matches the
    %        multitaper window step.
    %     2. Call computeSOpower(app.data, app.Fs, ..., 'retain_Fs', false)
    %        to produce the native-grid SOpower_norm directly. Cheaper than
    %        runDYNAMO since it skips TF-peak detection, watershed, merge,
    %        and SOPH binning.
    %
    %   The compact aux schema stores SOpower_norm on the native multitaper
    %   grid (with SOpower_t_start), the artifact mask as [start_s,end_s]
    %   spans, and stage_vals as uint8. SOpower_retain_Fs is dropped — the
    %   stored series is always native; consumers reconstruct the timeline
    %   from t_start + i*window_step.
    %
    %   Returns [] when neither path can run (no SOpower_norm, no data
    %   loaded). Caller is expected to fall through to a heavier path
    %   (typically runStatsTable, which loads the EDF) in that case.
    %
    %   See also: saveAuxData, loadAuxData, writeAuxFormats, computeSOpower,
    %             mask_to_spans.

    aux = [];

    % --- Path 1: peel timeseries off in-memory SOPHs (only if native grid) ---
    if ~isempty(app.SOPHs) && isfield(app.SOPHs,'SOpower_norm') && ...
            ~isempty(app.SOPHs.SOpower_norm) && isfield(app.SOPHs,'SOpower_times') && ...
            ~isempty(app.SOPHs.SOpower_times)
        step = double(app.SOPH_options.SOpower_window_params(2));
        t    = app.SOPHs.SOpower_times(:).';
        if is_native_grid_(t, step)
            aux = build_struct_(app, app.SOPHs.SOpower_norm, t(1));
            return
        end
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
            % Force retain_Fs=false so the stored series is the compact
            % native grid regardless of the user's display preference.
            [SOpower_norm, SOpower_times, ~, norm_method] = computeSOpower( ...
                app.data, app.Fs, ...
                'EEG_times',        [], ...
                'isexcluded',       isexcl, ...
                'stage_times',      app.stage_times, ...
                'stage_vals',       app.stage_vals, ...
                'norm_method',      opts.SOpower_norm_method, ...
                'retain_Fs',        false, ...
                'window_params',    double(opts.SOpower_window_params));
            t_start = [];
            if ~isempty(SOpower_times), t_start = SOpower_times(1); end
            aux = build_struct_(app, SOpower_norm, t_start, norm_method);
        catch ME
            app.TextArea.addnl(sprintf('   regenAuxData: computeSOpower failed (%s).', ME.identifier));
            aux = [];
        end
    end
end


function aux = build_struct_(app, SOpower_norm, SOpower_t_start, norm_method)
    if nargin < 4, norm_method = ''; end
    if isempty(norm_method) && isfield(app.SOPH_options,'SOpower_norm_method')
        norm_method = app.SOPH_options.SOpower_norm_method;
    end

    Fs = app.Fs;
    aux = struct();
    aux.Fs                    = Fs;
    aux.SOpower_norm          = SOpower_norm(:);                 % (Nn,1) native grid
    if ~isempty(SOpower_t_start)
        aux.SOpower_t_start   = double(SOpower_t_start);         % time (s) of native sample 0
    end
    aux.SOpower_norm_method   = norm_method;
    aux.SOpower_window_params = double(app.SOPH_options.SOpower_window_params(:)); % (2,1)
    if isfield(app.SOPH_options,'SO_freqrange')
        aux.SOpower_freqrange = double(app.SOPH_options.SO_freqrange(:));         % (2,1)
    end
    % Per-sample artifact mask -> [start_s, end_s] spans. mask_to_spans
    % returns zeros(0,2) when there are no artifacts; the writer skips
    % empty datasets, so "no artifacts" is encoded as an absent dataset.
    aux.artifact_spans        = mask_to_spans(logical(app.artifacts), Fs);        % (K,2)
    aux.stage_times           = double(app.stage_times(:).');                     % (1,M)
    aux.stage_vals            = uint8(round(app.stage_vals(:).'));                % (1,M) codes 0-6
end


function tf = is_native_grid_(times, step)
    % True when the inter-sample spacing matches the multitaper window step
    % (native grid) rather than the EEG sample period (upsampled series).
    tf = false;
    if numel(times) < 2 || ~(step > 0), return, end
    tf = abs(median(diff(times)) - step) <= 0.25 * step;
end
