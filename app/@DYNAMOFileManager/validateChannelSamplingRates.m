function validateChannelSamplingRates(app, selectedChannels, tableData)
    % validateChannelSamplingRates  Warn if any selected channel's Fs is
    %   above the multitaper NFFT-jump threshold or below Nyquist
    %   for the configured analysis range.
    %
    %   High threshold: 102.4 Hz. The multitaper spectrogram NFFT
    %   is computed as 2^nextpow2(Fs/mtm_dsfreqs); with the
    %   default mtm_dsfreqs=0.1, NFFT=1024 for Fs <= 102.4 and
    %   doubles to 2048 for Fs > 102.4 (and again at 204.8, etc).
    %   That single jump roughly doubles spectrogram cost AND
    %   pushes the working set past CPU L3 cache on most modern
    %   hardware, so every downstream stage (extract, baseline,
    %   mask, watershed) takes a 2-3x memory-bandwidth hit on top
    %   of the FFT cost. Resampling to <=100 Hz avoids both.
    %
    %   Low threshold: 2x the max analysis upper bound (Nyquist).
    %   Below this, the pipeline literally can't resolve the
    %   target frequency band — must upsample.
    %
    %   The high warning is suppressed if Resample is already on
    %   at a target <=102.4 Hz, since the user has already
    %   resolved the issue.

    soph_upper  = app.SOPH_options.freq_range(2);
    mtm_upper   = app.detection_options.mtm_freq_range(2);
    max_upper   = max(soph_upper, mtm_upper);
    high_thresh = 102.4;     % NFFT-jump boundary at default dsfreqs=0.1
    low_thresh  = 2 * max_upper;

    % If user has already enabled Resample at <=102.4, the high-Fs
    % warning is just noise — they've already got the fix wired up.
    resample_already_fixed = ~isempty(app.ResampleSwitch) && ...
        logical(app.ResampleSwitch.Value) && ...
        app.ResampleFsEditField.Value <= high_thresh;

    tooHigh = {};
    tooLow  = {};
    for ii = 1:numel(selectedChannels)
        lbl = selectedChannels{ii};
        idx = find(strcmp(tableData(:,1), lbl), 1);
        if isempty(idx)
            continue
        end
        fs_vals = sscanf(tableData{idx,2}, '%g');
        if isempty(fs_vals)
            continue
        end
        entry = sprintf('  %s (%s)', lbl, tableData{idx,2});
        if max(fs_vals) > high_thresh
            tooHigh{end+1} = entry; %#ok<AGROW>
        end
        if min(fs_vals) < low_thresh
            tooLow{end+1}  = entry; %#ok<AGROW>
        end
    end

    if ~isempty(tooHigh) && ~resample_already_fixed
        msg = sprintf(['The following channel(s) have Fs > %.1f Hz, which doubles ' ...
            'the multitaper FFT size (NFFT 1024 -> 2048+) and typically pushes the ' ...
            'spectrogram beyond CPU L3 cache, slowing the whole pipeline 2-3x:\n\n' ...
            '%s\n\n' ...
            'Recommendation: enable "Resample Data" with target Fs = 100 Hz. ' ...
            'DYNAMO analyzes 0-30 Hz (Nyquist 50 Hz) so 100 Hz is well above ' ...
            'anything the pipeline cares about — lossless for sleep oscillations.'], ...
            high_thresh, strjoin(tooHigh, newline));
        uialert(app.UIFigure, msg, 'High Sampling Rate', 'Icon', 'warning');
    end

    if ~isempty(tooLow)
        msg = sprintf(['The following selected channel(s) have a sampling frequency ' ...
            'below the minimum required by DYNAMO (< %g Hz, i.e. 2x the upper analysis ' ...
            'bound of %g Hz by Nyquist):\n\n%s\n\n' ...
            'You must enable the "Resample Data" option to upsample these channels ' ...
            'before processing, otherwise the run will fail.'], ...
            low_thresh, max_upper, strjoin(tooLow, newline));
        uialert(app.UIFigure, msg, 'Low Sampling Rate', 'Icon', 'warning');
    end
end
