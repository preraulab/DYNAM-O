function [freq_bins, so_bins] = binsForParamfit(~, S, p, axis_kind)
    %BINS_FOR_PARAMFIT  Recover (freq_bins, SO<axis>_bins) for a
    %   paramfit / splinefit struct preview. Order:
    %     1. Direct fields on the struct (freq_bins, SO<axis>_bins).
    %     2. Embedded SOPH metadata (some saves stash a copy under
    %        a sub-struct called 'SOPH_options' or 'SOPHs').
    %     3. peek_bins_from_settings_walk on the file path —
    %        same fallback the SOPH TIFF preview uses, walks up
    %        to find run_settings_*.txt and reconstructs the bin
    %        centers from the recorded ranges.
    %   Returns [] for whichever can't be recovered; the caller
    %   (styleSOPHAxes) treats [] as "use bin indices" so the
    %   image still renders, just with integer ticks.
    import results_browser.*
    freq_bins = [];
    so_bins   = [];
    binsField = ['SO' axis_kind '_bins'];
    % Splinefit structs carry the FIT-DOMAIN bins (after the
    % validity-mask filter in spline_basis), not the source SOPH
    % bins — the splinefit/coefs matrices are sized to those
    % filtered bins, so previewing must use them or the axes
    % won't match the image dimensions. Check these first.
    if isfield(S, 'fit_freq_bins') && ~isempty(S.fit_freq_bins)
        freq_bins = S.fit_freq_bins(:);
    end
    if isfield(S, 'fit_SOfeature_bins') && ~isempty(S.fit_SOfeature_bins)
        so_bins = S.fit_SOfeature_bins(:);
    end
    if isempty(freq_bins) && isfield(S, 'freq_bins') && ~isempty(S.freq_bins)
        freq_bins = S.freq_bins(:);
    end
    if isempty(so_bins) && isfield(S, binsField) && ~isempty(S.(binsField))
        so_bins = S.(binsField)(:);
    end
    if isfield(S, 'SOPHs') && isstruct(S.SOPHs)
        if isempty(freq_bins) && isfield(S.SOPHs, 'freq_bins')
            freq_bins = S.SOPHs.freq_bins(:);
        end
        if isempty(so_bins) && isfield(S.SOPHs, binsField)
            so_bins = S.SOPHs.(binsField)(:);
        end
    end
    if isempty(freq_bins) || isempty(so_bins)
        [fb, sb] = peek_bins_from_settings_walk(p, axis_kind);
        if isempty(freq_bins), freq_bins = fb; end
        if isempty(so_bins),   so_bins   = sb; end
    end
end
