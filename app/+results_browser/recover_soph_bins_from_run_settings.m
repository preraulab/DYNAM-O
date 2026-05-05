function [freq_bins, so_bins] = recover_soph_bins_from_run_settings(filePath, axis_kind)
%RECOVER_SOPH_BINS_FROM_RUN_SETTINGS  Recover SOPH histogram bin centers
%from the FileManager batch's saved settings JSON.
%
%   Walks up to 6 parent directories from filePath looking for
%   settings/run_settings_*.json (the most recent file wins). Reconstructs
%   freq_bins and, when axis_kind == 'phase', SOphase_bins from the
%   recorded SOPH_options.{freq_range, freq_binsizestep,
%   SOphase_range, SOphase_binsizestep}. SOpower bins remain
%   unrecoverable through this path: the SOpower_range / SOpower_binsizestep
%   fields are blank in adaptive normalization mode (the bins are derived
%   from data at run time).
%
%   Used by peekSOPHTiffBins / plotAggregateSOHist / binsForParamfit
%   in the Results Browser preview path to label image axes correctly
%   when the file itself doesn't carry bin metadata.
freq_bins = []; so_bins = [];
d = fileparts(filePath);
for hop = 1:6
    settingsDir = fullfile(d, 'settings');
    if isfolder(settingsDir)
        files = dir(fullfile(settingsDir, 'run_settings_*.json'));
        if ~isempty(files)
            [~, idx] = max([files.datenum]);
            try
                S = load_run_log(fullfile(files(idx).folder, files(idx).name));
            catch
                return
            end
            if ~isfield(S.options, 'SOPH_options'); return; end
            opts = S.options.SOPH_options;
            freq_bins = bin_centers(opts, 'freq_range', 'freq_binsizestep');
            if strcmp(axis_kind, 'phase')
                so_bins = bin_centers(opts, 'SOphase_range', 'SOphase_binsizestep');
            end
            return
        end
    end
    parent = fileparts(d);
    if isempty(parent) || strcmp(parent, d), return, end
    d = parent;
end
end

function b = bin_centers(opts, rangeField, stepField)
b = [];
if ~isfield(opts, rangeField) || ~isfield(opts, stepField); return; end
rng  = opts.(rangeField); rng = rng(:).';
step = opts.(stepField);  step = step(:).';
if numel(rng) ~= 2 || numel(step) ~= 2; return; end
n = round((rng(2) - rng(1)) / step(2)) + 1;
b = linspace(rng(1), rng(2), n).';
end

