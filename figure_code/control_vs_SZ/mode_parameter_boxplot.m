function [pvals_issz, pvals_night] = mode_parameter_boxplot(params, ROI_inds, param_inds, issz, night, ROI_names, param_names,...
    min_thresh, min_thresh_param, fsave_path, print_png, print_eps)
% IN PROGRESS
%
% Inputs:
%       params: 3d double - [num_ROIs, num_params, num_subjs]
%       ROI_inds: 1d double - which peaks to use
%       param_inds: 1d double - which params to use
%       issz: 1d logical - indicates SZ status
%       night: 1d numerical - indicates night status
%       min_thresh:
%       min_thresh_param:
%
% Outputs:
%
%

if length(unique(night)) == 2
    use_ttest = false;
else
    use_ttest = true;
end

num_ROIs = length(ROI_inds);
num_params = length(param_inds);

%% Take out data with below min_amp
for s = 1:size(params,3)
    no_peak = squeeze(params(:,min_thresh_param,s) < min_thresh) | isnan(squeeze(params(:,min_thresh_param,s)));
    if any(no_peak) % if any peak density is below cutoff
        params(no_peak,1:10,s) = nan; % turn all params for that peak to nan
        if mod(s,2)==0 % turn same peak params to nan for the other night of the same subj
            params(no_peak,1:10,s-1) = nan;
        else
            params(no_peak,1:10,s+1) = nan;
        end
    end
end

%% Repeated measures ANOVA
pvals_issz = nan(num_ROIs,num_params);
pvals_night = nan(num_ROIs,num_params);

if ~use_ttest
    for r = 1:num_ROIs
        for p = 1:num_params
            curr_params = squeeze(params(ROI_inds(r), param_inds(p),:));

            n1 = curr_params(night==1);
            n2 = curr_params(night==2);

            % form the tables for anova analysis
            between_tbl = table(issz(night==1), n1, n2, 'VariableNames',{'issz','n1','n2'});

            within_tbl = table(categorical([1;2]), 'VariableNames', {'night'});

            % do mixed effect ANOVA analysis
            rm = fitrm(between_tbl, 'n1-n2 ~ issz', 'WithinDesign', within_tbl);
            ranovatbl = ranova(rm, 'WithinModel', 'night');

            % Get pvals for issz and night
            pvals_issz(r,p) = ranovatbl{'issz','pValue'};
            pvals_night(r,p) = ranovatbl{'(Intercept):night', 'pValue'};

        end
    end
else
    pvals_issz = [];
    pvals_night = [];
end

%% Plot freq and SO% boxplots
fh1 = figure;
ax = figdesign(num_params,1);

for p = 1:num_params
    %boxplot single param for all ROIs with significance stars
    axes(ax(p));
    if use_ttest
        h_box1 = group_boxchart(squeeze(params(ROI_inds,param_inds(p),:))', issz, ROI_names, {'HC','SZ'}, 1, 0.5, 'o^o^o^o^','brbrbrbrbrb', [], 'markerstyle','none');
    else
        h_box1 = group_boxchart(squeeze(params(ROI_inds,param_inds(p),:))', issz, ROI_names, {'HC','SZ'}, 1, 0.5, 'o^o^o^o^','brbrbrbrbrb', pvals_issz(:,p), 'markerstyle','none');

        %warn if nights is significant
        if any(pvals_night(:,p) < 0.05)
            warning(['Effect of night is significant in param number ', num2str(p), ' for ROI ', ROI_names{pvals_night(:,p)<0.05}]);
        end
    end
    ylabel(param_names{p});
end

if ~use_ttest
    fh2 = figure;
    ax2 = figdesign(num_params,1);
    for p = 1:num_params
        %boxplot single param for all ROIs with significance stars
        axes(ax2(p));
        h_box1 = group_boxchart(squeeze(params(ROI_inds,param_inds(p),:))', night==1, ROI_names, {'n1','n2'}, 1, 0.5, 'o^o^o^o^','brbrbrbrbrb', pvals_night(:,p), 'markerstyle','none');
        ylabel(param_names{p});
    end
end

%% Save
if print_png
    print(fh1,'-dpng', '-r300',fullfile( fsave_path, 'PNG','SZ_HC_ROI_PARAM_BOXPLOT.png'));
end

if print_eps
    print(fh1,'-depsc', fullfile(fsave_path, 'EPS', 'SZ_HC_ROI_PARAM_BOXPLOT.eps'));
end

end

