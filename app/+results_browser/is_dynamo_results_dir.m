function tf = is_dynamo_results_dir(root)
%IS_DYNAMO_RESULTS_DIR  True iff `root` looks like a directory produced
%by the DYNAMOApp batch run. Each save category in the batch dialog
%is independently optional, so accept the directory if any of the
%following signals is present:
%  - <root>/settings/run_settings_*.json          (always emitted)
%  - one of root's immediate subdirs contains any of:
%      param_basis/  SOPHs/  TFpeaks/  spline_basis/
%      figures/      auxiliary_data/
%  - <root>/aggregates/<channel>/{param_basis_*, SOPHs_*, TFpeaks,
%                                 spline_basis_*}/  is present.
tf = false;
if ~isfolder(root), return, end

if ~isempty(dir(fullfile(root,'settings','run_settings_*.json')))
    tf = true; return
end

channelSubs = {'param_basis','SOPHs','TFpeaks','spline_basis', ...
               'figures','auxiliary_data'};
aggSubs     = {'param_basis_power','param_basis_phase', ...
               'SOPHs_power','SOPHs_phase', ...
               'TFpeaks','spline_basis_power','spline_basis_phase', ...
               'figures','auxiliary_data'};

ch = dir(root);
ch = ch([ch.isdir] & ~startsWith({ch.name},'.'));
for ii = 1:numel(ch)
    p = fullfile(root, ch(ii).name);
    for sub = channelSubs
        if isfolder(fullfile(p, sub{1}))
            tf = true; return
        end
    end
end

agg = fullfile(root,'aggregates');
if isfolder(agg)
    ach = dir(agg);
    ach = ach([ach.isdir] & ~startsWith({ach.name},'.'));
    for ii = 1:numel(ach)
        p = fullfile(agg, ach(ii).name);
        for sub = aggSubs
            if isfolder(fullfile(p, sub{1}))
                tf = true; return
            end
        end
    end
end
end

% ---------------------------------------------------------------------
% .mat preview helpers
% ---------------------------------------------------------------------

