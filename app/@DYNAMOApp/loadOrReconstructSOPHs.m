function SOPHs = loadOrReconstructSOPHs(app, channel, fbase)
    % loadOrReconstructSOPHs  Resolve a SOPHs struct from whatever
    %   on-disk artifacts exist for a (channel, fbase) pair.
    %
    %   Resolution order:
    %     1. app.SOPHs already loaded in memory (current batch step) →
    %        return as-is.
    %     2. <chan>/SOPHs/<fbase>_SOPHs_<chan>.h5  → load and return.
    %     3. <chan>/SOPHs/<fbase>_SOPHs_<chan>.mat → load (legacy).
    %     4. Reconstruct from the slim outputs:
    %          - <chan>/SOPHs/<fbase>_SOPHs_power_<chan>.tiff
    %            → SOpower_mat, SOpower_bins, freq_bins (page-1 JSON)
    %          - <chan>/SOPHs/<fbase>_SOPHs_phase_<chan>.tiff
    %            → SOphase_mat, SOphase_bins, freq_bins (page-1 JSON)
    %          - <chan>/auxiliary_data/<fbase>_auxiliary_data_<chan>.{h5,mat}
    %            → SOpower_norm, SOpower_norm_method, SOpower_retain_Fs,
    %              SOpower_window_params, Fs (used to synthesise
    %              SOpower_times via synthesizeSOpowerTimes).
    %     5. Empty struct on total miss; the caller decides what to do
    %        (typically: rerun the batch step from scratch).
    %
    %   Reconstructed SOPHs is NOT a 1:1 replica of the .mat — it lacks
    %   SOphase / SOphase_times (phase timeseries) and SOfiltered. Those
    %   aren't needed by displaySummaryPlot, runParamBasis, or
    %   runSplineBasis, so the slim shape is sufficient for the
    %   post-batch reconstitution paths.
    SOPHs = struct();

    if ~isempty(app.SOPHs)
        SOPHs = app.SOPHs;
        return
    end

    chanDir  = fullfile(app.OutputDirEditField.Value, channel);
    sophsDir = fullfile(chanDir, 'SOPHs');
    sophBase = fullfile(sophsDir, [fbase '_SOPHs_' channel]);
    for binPath = {[sophBase '.h5'], [sophBase '.mat']}
        p = binPath{1};
        if ~isfile(p), continue, end
        try
            S = load(p);
            % Two layouts on disk:
            %   - new flat: top-level vars (SOpower_mat, freq_bins, ...).
            %   - legacy nested: a single 'SOPHs' struct variable.
            if isfield(S, 'SOPHs') && isstruct(S.SOPHs)
                SOPHs = S.SOPHs;
            elseif isstruct(S) && (isfield(S,'SOpower_mat') || isfield(S,'freq_bins'))
                SOPHs = S;
            end
            if ~isempty(fieldnames(SOPHs)), return, end
        catch
            % fall through to next candidate / TIFF reconstruction
        end
    end

    % --- TIFF + aux reconstruction ---
    powTiff  = fullfile(sophsDir, [fbase '_SOPHs_power_' channel '.tiff']);
    phaTiff  = fullfile(sophsDir, [fbase '_SOPHs_phase_' channel '.tiff']);

    SOPHs = readSOPHTiffPair_(powTiff, phaTiff);
    if ~isempty(fieldnames(SOPHs))
        try
            % Route through loadAuxData so both the new .h5 (h5read) and
            % legacy .mat (load) layouts resolve via a single entry point.
            AD = app.loadAuxData(channel, fbase);
            if ~isempty(AD) && isfield(AD, 'SOpower_norm')
                SOPHs.SOpower_norm = AD.SOpower_norm;
                N         = numel(AD.SOpower_norm);
                retainFs  = true;
                winParams = [5, 0.5];
                if isfield(AD,'SOpower_retain_Fs')
                    retainFs  = logical(AD.SOpower_retain_Fs);
                end
                if isfield(AD,'SOpower_window_params')
                    winParams = double(AD.SOpower_window_params);
                end
                Fs_ = NaN;
                if isfield(AD,'Fs'), Fs_ = double(AD.Fs); end
                if isfinite(Fs_) && Fs_ > 0
                    SOPHs.SOpower_times = app.synthesizeSOpowerTimes( ...
                        N, Fs_, retainFs, winParams);
                end
            end
        catch
            % aux read fail — leave timeseries fields off the struct.
        end
    end
end


function SOPHs = readSOPHTiffPair_(powTiff, phaTiff)
    % Build the SOPHs.{SO*_mat, SO*_bins, freq_bins} fields from the
    % two per-subject single-page TIFFs. Either side can be absent —
    % we still return a struct with whichever fields we could fill.
    SOPHs = struct();
    if isfile(powTiff)
        try
            M = double(imread(powTiff));
            SOPHs.SOpower_mat = M;
            info = imfinfo(powTiff);
            if isfield(info, 'ImageDescription') && ...
                    ~isempty(info(1).ImageDescription)
                meta = jsondecode(info(1).ImageDescription);
                if isfield(meta,'freq_bins'),     SOPHs.freq_bins    = meta.freq_bins(:); end
                if isfield(meta,'SOpower_bins'),  SOPHs.SOpower_bins = meta.SOpower_bins(:); end
            end
        catch
        end
    end
    if isfile(phaTiff)
        try
            M = double(imread(phaTiff));
            SOPHs.SOphase_mat = M;
            info = imfinfo(phaTiff);
            if isfield(info, 'ImageDescription') && ...
                    ~isempty(info(1).ImageDescription)
                meta = jsondecode(info(1).ImageDescription);
                if ~isfield(SOPHs,'freq_bins') && isfield(meta,'freq_bins')
                    SOPHs.freq_bins = meta.freq_bins(:);
                end
                if isfield(meta,'SOphase_bins'), SOPHs.SOphase_bins = meta.SOphase_bins(:); end
            end
        catch
        end
    end
end
