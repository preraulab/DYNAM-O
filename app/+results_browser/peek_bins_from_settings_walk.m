function [freq_bins, so_bins] = peek_bins_from_settings_walk(filePath, axis_kind)
%PEEK_BINS_FROM_SETTINGS_WALK  Walk up parent directories from filePath
%searching for a `settings/run_settings_*.txt` produced by the FileManager
%batch run. Reconstructs freq_bins and (for phase) SOphase_bins from the
%recorded SOPH_options.* values. SOpower bins remain unrecoverable
%(SOpower_range/binsizestep are blank in adaptive mode).
    import results_browser.*
freq_bins = []; so_bins = [];
d = fileparts(filePath);
for hop = 1:6
    settingsDir = fullfile(d, 'settings');
    if isfolder(settingsDir)
        files = dir(fullfile(settingsDir, 'run_settings_*.txt'));
        if ~isempty(files)
            [~, idx] = max([files.datenum]);
            try
                txt = fileread(fullfile(files(idx).folder, files(idx).name));
            catch
                return
            end
            freq_bins = bin_centers_from_settings(txt, ...
                'SOPH_options.freq_range', 'SOPH_options.freq_binsizestep');
            if strcmp(axis_kind, 'phase')
                so_bins = bin_centers_from_settings(txt, ...
                    'SOPH_options.SOphase_range', 'SOPH_options.SOphase_binsizestep');
            end
            return
        end
    end
    parent = fileparts(d);
    if isempty(parent) || strcmp(parent, d), return, end
    d = parent;
end
end

