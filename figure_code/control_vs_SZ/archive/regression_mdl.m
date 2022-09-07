%% Load MST data
mst_path=fullfile('/data/preraugp/archive/Lunesta Study/');
[~,~,memory_test_results]=xlsread([mst_path,'MST.xlsx']);
mem_table = cell2table(memory_test_results(2:end,:), 'VariableNames', memory_test_results(1,:));
[~, idx] = sort(mem_table.original_id);
mem_table = mem_table(idx,:);
mem_table = mem_table(mem_table.numerical_id~=39,:); % remove subj not present in ROI data
bl_change = mem_table.baseline_percentchange_MST;


%% Get ROIs
[pow_params, use_inds, use_issz] = meanSZcontrol_ROIs_plot(powmean_cntrl, powmean_sz, SOpow_cbins_final, ...
                        freq_cbins_final, SOpowcount_plot{elect_ind_meanplot}, TIBpow_plot{elect_ind_meanplot},...
                        SOpow_cbins, freqcbins_new, issz);  
                    
bl_change = bl_change(use_inds);

%% Construct Regression Model
mdl_tbl = table(pow_params(:,1), pow_params(:,2), pow_params(:,3), pow_params(:,4), bl_change, use_issz,...
                'VariableNames', {'sigmafast', 'sigmaslow', 'alphalow', 'theta', 'MST_change', 'issz'});
mdl = fitlm(mdl_tbl, 'MST_change ~ 1 + sigmafast + sigmaslow + alphalow + theta')


%% Scatter Plots
ROIs = {'sigma_f_a_s_t', '\sigma_s_l_o_w', '\alpha_l_o_w', '\theta'};

for r = 1:length(ROIs)
    figure;
    gscatter(pow_params(:,r), bl_change, use_issz);
    [corr_all, p_all] = corr(pow_params(:,r), bl_change);
    xlabel([ROIs{r}, ' (peak/min)']);
    ylabel('MST % Change');
    title([ROIs{r}, ', \rho=', num2str(round(corr_all,3)), ', pval=',num2str(round(p_all,3))]);
    legend('HC', 'SZ');

    %
    figure;
    ax = figdesign(1,2, 'orient','landscape', 'margins',[.1 .08 .08 .05 .08 .08]);

    axes(ax(1))
    scatter(pow_params(~use_issz,r), bl_change(~use_issz), 'filled');
    lsline;
    [corr_cntrl, p_cntrl] = corr(pow_params(~use_issz,r), bl_change(~use_issz));
    xlabel([ROIs{r}, ' (peak/min)']);
    ylabel('MST % Change');
    title(['HC ', ROIs{r}, ', \rho=',num2str(round(corr_cntrl,3)), ', pval=', num2str(round(p_cntrl,3))]);

    axes(ax(2))
    scatter(pow_params(use_issz,r), bl_change(use_issz), 'filled');
    lsline;
    xlabel([ROIs{r}, ' (peak/min)']);
    ylabel('MST % Change');
    [corr_sz, p_sz] = corr(pow_params(use_issz,r), bl_change(use_issz));
    title(['SZ ', ROIs{r}, ', \rho=',num2str(round(corr_sz,3)), ', pval=', num2str(round(p_sz,3))]);
end
