function files = dynamo_files_for_components(subject, channel, components)
%DYNAMO_FILES_FOR_COMPONENTS  Synthesize the per-(subject, channel) output
%   file paths produced by a DYNAM-O batch run, from a list of component tags.
%
%   files = dynamo_files_for_components(subject, channel, components) returns
%   a cell array of filesystem-relative paths under the results root. Each
%   path uses forward slashes regardless of platform (JSONL is consumed
%   cross-platform; we normalize at write time so readers don't have to).
%
%   Component → file path mapping (the inverse of what
%   dynamo_seed_index_from_cache classifies):
%
%       'aux'      → <chan>/auxiliary_data/<subj>_auxiliary_data_<chan>.mat
%       'SOPHs'    → <chan>/SOPHs/<subj>_SOPHs_<chan>.mat
%       'TFpeaks'  → <chan>/TFpeaks/<subj>_stats_table_<chan>.mat
%       'paramfit' → <chan>/param_basis/<subj>_SOpower_paramfit_<chan>.mat
%                  → <chan>/param_basis/<subj>_SOphase_paramfit_<chan>.mat
%       'spline'   → <chan>/spline_basis/<subj>_SOpower_splinefit_<chan>.mat
%                  → <chan>/spline_basis/<subj>_SOphase_splinefit_<chan>.mat
%
%   Unknown components are silently ignored. This is the single source of
%   truth for the naming convention; DYNAMORunLogger consults it at write
%   time to populate the `files` field of each JSONL entry, and the GUI's
%   tree builder consults it as a fallback when reading legacy entries
%   that predate the field.
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

    arguments
        subject    (1,:) char
        channel    (1,:) char
        components (1,:) cell
    end

    files = {};
    for ii = 1:numel(components)
        c = components{ii};
        if ~ischar(c) && ~isstring(c), continue, end
        c = char(c);
        switch c
            case 'aux'
                files{end+1} = sprintf('%s/auxiliary_data/%s_auxiliary_data_%s.mat', ...
                    channel, subject, channel); %#ok<AGROW>
            case 'SOPHs'
                files{end+1} = sprintf('%s/SOPHs/%s_SOPHs_%s.mat', ...
                    channel, subject, channel); %#ok<AGROW>
            case 'TFpeaks'
                files{end+1} = sprintf('%s/TFpeaks/%s_stats_table_%s.mat', ...
                    channel, subject, channel); %#ok<AGROW>
            case 'paramfit'
                files{end+1} = sprintf('%s/param_basis/%s_SOpower_paramfit_%s.mat', ...
                    channel, subject, channel); %#ok<AGROW>
                files{end+1} = sprintf('%s/param_basis/%s_SOphase_paramfit_%s.mat', ...
                    channel, subject, channel); %#ok<AGROW>
            case 'spline'
                files{end+1} = sprintf('%s/spline_basis/%s_SOpower_splinefit_%s.mat', ...
                    channel, subject, channel); %#ok<AGROW>
                files{end+1} = sprintf('%s/spline_basis/%s_SOphase_splinefit_%s.mat', ...
                    channel, subject, channel); %#ok<AGROW>
        end
    end
end
