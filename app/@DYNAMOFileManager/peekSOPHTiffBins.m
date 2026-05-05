function [freq_bins, bins] = peekSOPHTiffBins(~, filePath, info, axis_kind)
    % Recover (freq_bins, SO{power,phase}_bins) from a SOPH TIFF.
    % Order: ImageDescription JSON tag → sidecar *_bins.csv →
    % run_settings_*.json walk. Returns [] for whichever can't
    % be recovered; caller falls back to pixel indices.
    import results_browser.*
    freq_bins = []; bins = [];
    if isfield(info,'ImageDescription') && ~isempty(info(1).ImageDescription)
        try
            meta = jsondecode(info(1).ImageDescription);
            if isfield(meta,'freq_bins'), freq_bins = meta.freq_bins(:); end
            bf = ['SO' axis_kind '_bins'];
            if isfield(meta, bf), bins = meta.(bf)(:); end
        catch
        end
    end
    if isempty(freq_bins) || isempty(bins)
        [d, n, ~] = fileparts(filePath);
        binsCsv = fullfile(d, [n '_bins.csv']);
        if isfile(binsCsv)
            try
                B = readtable(binsCsv);
                if isempty(freq_bins) && any(strcmp(B.Properties.VariableNames,'freq'))
                    fb = B.freq(~isnan(B.freq)); freq_bins = fb(:);
                end
                axisCol = ['SO' axis_kind];
                if isempty(bins) && any(strcmp(B.Properties.VariableNames, axisCol))
                    sb = B.(axisCol)(~isnan(B.(axisCol))); bins = sb(:);
                end
            catch
            end
        end
    end
    if isempty(freq_bins) || (isempty(bins) && strcmp(axis_kind,'phase'))
        [fb2, sb2] = recover_soph_bins_from_run_settings(filePath, axis_kind);
        if isempty(freq_bins) && ~isempty(fb2), freq_bins = fb2; end
        if isempty(bins)      && ~isempty(sb2), bins      = sb2; end
    end
end
