%%%%% Generate all figures associated with the watershed TFpeaks analysis %%%%%

%% Generate all data necessary for analyses and figures
% ccc;
% 
% % Initialize Parameters
% %Add necessary dirs to path
% base_path = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/';
% toolbox_path = fullfile(base_path,'/watershed_TFpeaks/toolbox_paper/');
% addpath(genpath(toolbox_path));
% figurecode_path = fullfile(base_path, 'watershed_TFpeaks/figure_code/');
% addpath(genpath(figurecode_path))
% 
% use_old_data = false;
% 
% %Histogram Rebinning Params
% freq_binsizestep = [1, 0.2]; % orig: [0.5, 0.1] standard: [1, 0.2] 6x6: [2.35, 2.35]
% SOpow_binsizestep = [0.2, 0.01]; % orig: [0.05, 0.01]  standard: [0.2, 0.01] 6x6: [0.165, 0.165]
% SOphase_binsizestep = [(2*pi)/(400/67), (2*pi)/(400/3)]; % orig: [(2*pi)/(400/67), (2*pi)/(400/3)] standard: [(2*pi)/5, (2*pi)/100] 6x6: [(2*pi)/(400/67), (2*pi)/(400/67)]
% 
% freq_range = [4,25];
% 
% % Load SOpow/phase histogram data
% if ~use_old_data
%     load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOphase_data_smallbins.mat', 'freq_cbins', 'issz', 'SOphase_cbins', 'subjects_full', ...
%          'SOphase_data', 'SOphase_prop_data', 'SOphase_time_data', 'subjects', 'SOphase_smallbinsizestep', 'freq_smallbinsizestep');
%     load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpow_data_smallbins.mat', 'SOpow_cbins', 'SOpow_data', 'SOpow_prop_data', 'SOpow_time_data',...
%           'SOpow_smallbinsizestep');
%     
%     %Turn bad subject/electrode data into nans
%     elect_inds = [1,2,3,4,5,6,7, 1, 2, 3, 4, 5, 6, 7,  4, 5, 6,  5,  4];
%     subj_inds =  [8,8,8,8,8,8,8, 24,24,24,24,24,24,24, 27,27,27, 28, 29];
%     
%     [SOpow_data, SOpow_prop_data, SOpow_time_data, SOphase_data, SOphase_prop_data, SOphase_time_data] = remove_subj(SOpow_data, ...
%             SOpow_prop_data, SOpow_time_data, SOphase_data, SOphase_prop_data, SOphase_time_data, elect_inds, subj_inds);
%     
% else
%     base =  '/data/preraugp/projects/transient_oscillations/transient_oscillations_original/code/Lunesta histograms over time/';
%     load([base 'electrode_hists_SW_power_dB_percentLightsOutNoArtifact_compNights_20190102_nights1and2.mat'], 'electrode_hists', 'electrode_time_in_bin', 'electrode_stage_prop',...
%                                                                                                               'subjects', 'freqs', 'issz', 'SWF_bins', 'electrodes');
%     freq_inds = freqs >= freq_range(1) & freqs<= freq_range(2);
%     TIBpow_sumstages = electrode_time_in_bin(1:7);
%     PIBpow_all = cellfun(@(x) permute(x, [3,2,1]), electrode_stage_prop(1:7),'UniformOutput', false);
%     powhists = cellfun(@(x) permute(x(:,freq_inds,:), [2,1,3]), electrode_hists, 'UniformOutput', false);
%     powhists = powhists(1:7);
%     SOpow_cbins_final = SWF_bins;
%     freq_cbins_final = freqs(freq_inds);
%     subjects_full = subjects;
%     subjects_full_2nights = repelem(subjects_full,2);
%     elect_names = cellstr(electrodes(1:7));
%     load([base 'electrode_hists_SW_phase_perSubj_compNights_20190117_nights1and2_all.mat'], 'electrode_hists', 'electrode_time_in_bin', 'electrode_stage_prop',...
%                                                                                                               'SWF_bins', 'electrode_total_time');
%     phasehists = cellfun(@(x) permute(x(:,freq_inds,:), [2,1,3]), electrode_hists, 'UniformOutput', false);
%     phasehists = phasehists(1:7);
%     SOphase_cbins_final = SWF_bins;
%     total_time_phase_old = electrode_total_time(1:7);
% 
%     night_out = [ones(length(subjects_full),1); ones(length(subjects_full),1)*2];
%     issz = logical(issz);
%     issz_out = [issz'; issz'];
% end
% 
% % Sum Stages and Rebin SO Power and Phase Histograms
% if ~use_old_data
%     stage_select = [1,2,3,4]; % [1,2,3,4,5]
%     issz_select = []; % leave empty to get both SZ and controls
%     TIB_req_power = 0;
%     count_flag = true;
%     elect_names = {'C3', 'C4', 'F3', 'F4', 'O1', 'O2', 'Pz'};
%     electrode_inds = 1:7; %(1:7 = 'C3', 'C4','F3', 'F4', 'O1', 'O2', 'Pz');
%     num_elects = length(electrode_inds);
%     num_subjs = length(subjects_full);
%     night = [1,2];
%     num_nights = length(night);
%     SOpow_col_norm = false;
% 
%     powhists = cell(num_elects,1);
%     powhists_counts = cell(num_elects,1);
%     phasehists = cell(num_elects,1);
%     phasehists_counts = cell(num_elects,1);
%     phasehists_bigbin_counts = cell(num_elects,1);
% 
%     TIBpow_all = cell(num_elects,1);
%     TIBphase_all = cell(num_elects,1);
%     TIBpowsmall = cell(num_elects,1);
%     TIBphasesmall = cell(num_elects,1);
% 
%     PIBpow_all = cell(num_elects,1);
% 
%     for ee = 1:num_elects
%         %Sum stages of raw small-bin histograms 
%         [SOpow, freqcbins_new, TIBpow_small, ~, issz_out, night_out] = sumstages_SOpowphase(SOpow_data{ee}, ...
%                                                                SOpow_time_data{ee}, SOpow_prop_data{ee},...
%                                                                freq_cbins, 'pow', night, issz_select, ...
%                                                                stage_select, TIB_req_power, freq_range, [], ...
%                                                                count_flag);
% 
%         [SOphase,~, TIBphase_small,~,~,~] = sumstages_SOpowphase(SOphase_data{ee}, SOphase_time_data{ee}, ...
%                                        SOphase_prop_data{ee}, freq_cbins, 'phase', night, issz_select, ...
%                                        stage_select, [], freq_range, [], count_flag);
% 
% 
%         %Store smallbin data
%         powhists_counts{ee} = permute(SOpow, [3,2,1]);
%         phasehists_counts{ee} = permute(SOphase, [3,2,1]);
%         TIBpowsmall{ee} = TIBpow_small;
%         TIBphasesmall{ee} = TIBphase_small;
% 
%         %Reorder dims
%         SOpow = permute(SOpow, [3,2,1]);
%         SOphase = permute(SOphase, [3,2,1]);
% 
%         %Rebin histograms
%         [SOpow_resize, SOpow_resize_counts, freq_cbins_final, SOpow_cbins_final, TIBpow] = ...
%                                    rebin_histogram(SOpow, TIBpow_small, freqcbins_new, SOpow_cbins, ...
%                                    freq_binsizestep, SOpow_binsizestep, 'pow', freq_smallbinsizestep, ...
%                                    SOpow_smallbinsizestep, SOpow_col_norm);
%         [SOphase_resize, SOphase_resize_counts, ~, SOphase_cbins_final, TIBphase] = ...
%                                    rebin_histogram(SOphase, TIBphase_small, freqcbins_new, SOphase_cbins, ...
%                                    freq_binsizestep, SOphase_binsizestep, 'phase', freq_smallbinsizestep, ...
%                                    SOphase_smallbinsizestep, SOpow_col_norm);
% 
%         %Reorder dims and add to cell array
%         powhists{ee} = permute(SOpow_resize, [2,3,1]);
%         phasehists{ee} = permute(SOphase_resize, [2,3,1]);
%         phasehists_bigbin_counts{ee} = permute(SOphase_resize_counts, [2,3,1]);
% 
%         %Store TIBs
%         TIBphase_all{ee} = TIBphase;
%         TIBpow_all{ee} = TIBpow;
%         PIBpow_all{ee} = TIBpow./sum(TIBpow,2);
% 
%     end
% end
% 
% 
% %Get cntrl vs SZ mean diffs and TIBs from old data
% if use_old_data
%     num_elects = length(elect_names);
%     diff_pow_n2 = cell(num_elects, 1);
%     diff_phase_n2 = cell(num_elects, 1);
% 
%     for ee = 1:num_elects
%         mask_issz = issz_out&night_out==2;
%         mask_cntrl = ~issz_out&night_out==2;
%         diff_pow_n2{ee} = mean(powhists{ee}(:,:,mask_cntrl),3,'omitnan')- mean(powhists{ee}(:,:,mask_issz),3,'omitnan');
%         diff_phase_n2{ee} = mean(phasehists{ee}(:,:,mask_cntrl),3,'omitnan')- mean(phasehists{ee}(:,:,mask_issz),3,'omitnan');
% 
%         TIBpow_all{ee} = permute(permute(PIBpow_all{ee}, [1,3,2]) .* TIBpow_sumstages{ee}', [1,3,2]);
%     end
% 
% end
% 
%% Load all data and functions necessary for analyses and figures
ccc;

% Set path to all necessary functions
addpath(genpath('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/watershed_TFpeaks/figure_code/'));
addpath(genpath('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/watershed_TFpeaks/toolbox_paper/'));

% Load variables necessary for analysis and figures
load('figure_data_init_nowake.mat', 'elect_names', 'freq_binsizestep', 'freq_cbins_final', 'freq_range', 'freqcbins_new', 'issz', 'issz_out',...
                                    'night_out', 'phasehists', 'PIBpow_all', 'powhists', 'powhists_counts', 'SOphase_cbins', ...
                                    'SOphase_cbins_final', 'SOpow_cbins','SOpow_cbins_final', 'SOpow_col_norm', 'subjects_full', 'subjects_full_2nights',...
                                    'TIBpow_all', 'TIBpowsmall', 'use_old_data', 'SOpow_binsizestep', 'SOphase_binsizestep',...
                                    'phasehists_bigbin_counts');

%% Set variables necessary for analyses

% Set path to save eps and pngs
fsave_path = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/watershed_TFpeaks/figure_code/figures';
print_eps = false; % save figures to eps
print_png = false; % save figures to png

% Which array of electrodes to use for multi elecctrode analyses
elect_array_use = {'F3', 'C3', 'Pz', 'O1'};
[mask, loc] = ismember(elect_names, elect_array_use);
[~, p] = sort(loc(mask)); % fancy indexing to preserve order of electrodes
idx = find(mask);
elect_array_inds = idx(p);

% Which electrode to use for single electrode analyses
single_elect_use = 'C3';
single_elect_ind = find(ismember(elect_names, single_elect_use));

% Which analyses/figures to run
plot_all_subj_hists = true;
plot_heterogeneity = true;
plot_hist_schematic = true;
plot_mean_hists = true;
plot_mean_hists_bystage = true;
plot_merge_method = true;
plot_merge_summary = true;
plot_methods_summary = true;
plot_phase_cube = true;
plot_phase_peak_dynamics = true;
plot_power_peak_dynamics = true;
plot_pownorms = true;
plot_spatial = true;
plot_szcontrol_power = true;
plot_szcontrol_phase = true;
plot_TFpeak_props = true;
plot_reconstructions = true;
plot_GCRC_compare = true;
plot_PIB_per_stage = true;
SOpow_mean_table = true;
    
%% Plot all subjects histograms

if plot_all_subj_hists
    
    % Index to get correct SOpow and SOphase hists based on electrodes and control/SZ grouping
    SOpow_plot_c = cellfun(@(x) x(:,:,~issz_out), powhists(elect_array_inds), 'UniformOutput', false);
    SOpow_plot_s = cellfun(@(x) x(:,:,issz_out), powhists(elect_array_inds), 'UniformOutput', false);
    
    SOphase_plot_c = cellfun(@(x) x(:,:,~issz_out), phasehists(elect_array_inds), 'UniformOutput', false);
    SOphase_plot_s = cellfun(@(x) x(:,:,issz_out), phasehists(elect_array_inds), 'UniformOutput', false);
    
    % Set subject ID name strings
    subj_c = subjects_full_2nights(~issz_out);
    subj_c = cellfun(@(x) ['HC',x], subj_c, 'UniformOutput', false);
    subj_s = subjects_full_2nights(issz_out);
    subj_s = cellfun(@(x) ['SZ',x(2:end)], subj_s, 'UniformOutput', false);
    
    % Set night
    night_c = night_out(~issz_out);
    night_s = night_out(issz_out);
    
    % Plot histogram
    close all
    all_subjs_powphase_2nights(SOpow_plot_c, SOphase_plot_c, SOpow_cbins_final, SOphase_cbins_final, ...
        freq_cbins_final, elect_array_use, subj_c, night_c, 'Healthy Controls', fsave_path, print_png, print_eps);
    
    close all
    all_subjs_powphase_2nights(SOpow_plot_s, SOphase_plot_s, SOpow_cbins_final, SOphase_cbins_final, ...
        freq_cbins_final, elect_array_use, subj_s, night_s, 'Schizophrenia', fsave_path, print_png, print_eps);
end


%% Plot Spatial Analyses

if plot_spatial
    % Concat all electrodes into 4D double
    SOpow_plot = cat(4, powhists{:});
    SOphase_plot = cat(4, phasehists{:});
    inds = (night_out==2) & (issz_out==false);
    close all;
    spatial_analyses_plot(SOpow_plot(:,:,inds,:), SOphase_plot(:,:,inds,:), ...
        SOpow_cbins_final, SOphase_cbins_final, freq_cbins_final, elect_names, ...
        freq_range, fsave_path, true, true);

    inds = (night_out==2) & (issz_out==true);
    spatial_analyses_plot(SOpow_plot(:,:,inds,:), SOphase_plot(:,:,inds,:), ...
        SOpow_cbins_final, SOphase_cbins_final, freq_cbins_final, elect_names, ...
        freq_range, fsave_path, print_png, print_eps);
end

%% Plot SZ vs Control Power
if plot_szcontrol_power
    
    ROI_pow = [.15 1; .65 1; 0.2 0.85; 0 .8; 0 .2]; % region of interest power boundaries
    ROI_freq = [12 15; 10 12; 7 10; 0 6; 8 12]; % region of interest freq boundaries

    night_inds = night_out == 2; % using only night 2
    
    % Get power hists of appropriate night and electrode
    SOpow_plot = powhists{single_elect_ind}(:,:,night_inds); 
    SOpowcount_plot = powhists_counts{single_elect_ind}(:,:,night_inds); % get counts also
    TIBpow_plot = squeeze(sum(TIBpowsmall{single_elect_ind}(night_inds,:,:),3)); % and time in bin data
    issz_plot = issz_out(night_inds); % SZ status of selected nights for each subj
    
    % Calculate group mean histograms
    powmean_cntrl = mean(SOpow_plot(:,:,~issz_plot),3,'omitnan'); 
    powmean_sz = mean(SOpow_plot(:,:,issz_plot),3,'omitnan');
      
    close all
    
    % Plot SZ vs Control histograms with ROI comparisons
    [~, ~, ~, pvals_issz_ROI, pvals_night_ROI] = meanSZcontrol_ROIs_plot(powmean_cntrl, powmean_sz, SOpow_cbins_final, ...
        freq_cbins_final, SOpowcount_plot, TIBpow_plot, SOpow_cbins, freqcbins_new, issz_plot, night_out(night_inds), SOpow_col_norm, ...
        ROI_pow, ROI_freq, fsave_path, print_png, print_eps);
    
     %% SZ vs Control parametric mode comparison
%     % Get paramtere values for each mode modeled as a skewed gaussian
%     [params, offset] = calculate_mode_skew_gaussian(powhists, SOpow_cbins_final, freq_cbins_final, night_out, ROI_pow, ROI_freq, single_elect_ind);
% 
%     % remove params outside of ROIs
% %     count = 0;
% %     for ii = 1:size(params,3)
% %         for r = 1:(size(params,1)-1)
% %             curr_params = squeeze(params(r,[9,10],ii));
% %             if (curr_params(1) < ROI_pow(r,1) || curr_params(1) > ROI_pow(r,2)) || (curr_params(2) < ROI_freq(r,1) || curr_params(2) > ROI_freq(r,2))
% %                 count = count + 1;
% %                 params(r,1:10,ii) = nan;
% % 
% %                 if mod(ii,2) == 0
% %                     params(r,1:10,ii-1) = nan;
% %                 else
% %                     params(r,1:10,ii+1) = nan;
% %                 end
% %             end
% %         end
% %     end
% %     disp([num2str(count), ' peaks outside ROI bounds removed (night pairs also removed but not included in count)']);
%     % Plot mode param scatter and boxplot
%     % Scatter plot the modeled modes
%     min_thresh = 2.75; % threshold of mode rejection
%     min_thresh_param_ind = 11; % which mode parameter on which to execute threshold (11 = centroid density)
%     mode_skew_gaussian_scatterplot(params(:,:,night_inds), issz_out(night_inds), min_thresh, fsave_path, print_png, print_eps);
%     
%     % Compare parameterization of modes across groups
%     [pvals_issz, pvals_night] = mode_parameter_boxplot(params(:,:,night_inds), [1,2,3,4], [9,10,11,7], issz_out(night_inds), night_out(night_inds), {'\sigma_{fast}', '\sigma_{slow}', '\alpha_{low}', '\theta'},...
%                                    {'% SO Power', 'Frequency (Hz)', 'Centroid Density', 'Summed Activity'}, min_thresh, min_thresh_param_ind,...
%                                    fsave_path, print_png, print_eps);
%     
%     mergefigures(figure(1), figure(2)); % merge scatter plot and mode parameter boxplot
%     close([1,2]) % close unmerged figures
    
end

%% Plot SZ vs Control Phase
if plot_szcontrol_phase
    
    ROI_phase = [-pi/4 pi/2; (-0.75*pi)/2 (4*pi)/5]; % region of interest phase boundaries;
    ROI_freq = [12 17; 5 11.5]; %
    ROI_flip_flag = [false, true];

    night_inds = night_out == 2; % using only night 2
    
    % Get power hists of appropriate night and electrode
    SOphase_plot = phasehists{single_elect_ind}(:,:,night_inds); 
    SOphase_counts_plot = phasehists_bigbin_counts{single_elect_ind}(:,:,night_inds);
    issz_plot = issz_out(night_inds); % SZ status of selected nights for each subj
      
    close all
    
    % Plot SZ vs Control histograms with ROI comparisons
    [~, ~, ~, pvals_issz_ROI_phase, pvals_night_ROI_phase] = meanSZcontrol_phase_ROIs_plot(...
        SOphase_plot, SOphase_counts_plot, SOphase_cbins_final, freq_cbins_final, issz_plot, night_out(night_inds), ...
        ROI_phase, ROI_freq, ROI_flip_flag, fsave_path, print_png, print_eps);
   
end

%% Plot Heterogeneity
 
if plot_heterogeneity
    close all;
    
    % Get power and phase hists from selected subjects for both nights
    subj_ind_n1 = find(ismember(subjects_full_2nights, {'13','5','12','3'}) & night_out==1); % subject IDs =  [11,5,12,3]
    subj_ind_n2 = subj_ind_n1+1;
    SOpow_plot = cat(4, powhists{single_elect_ind}(:,:,subj_ind_n1), powhists{single_elect_ind}(:,:,subj_ind_n2));
    SOphase_plot = cat(4, phasehists{single_elect_ind}(:,:,subj_ind_n1), phasehists{single_elect_ind}(:,:,subj_ind_n2));
    
    close all; 
    heterogeneity_histograms(SOpow_plot, SOphase_plot, SOpow_cbins_final, SOphase_cbins_final,...
        freq_cbins_final, fsave_path, print_png, print_eps);

    %
    heterogeneity_figure;
    
end

%% Plot Mean Hists
if plot_mean_hists
    
    % Get pow hists and phase hists  night 2 control data
    mask = issz_out == false & night_out == 2; % mask for control subjs, night 2 only
    SOpow_plot = cellfun(@(x) x(:,:,mask), powhists(elect_array_inds), 'UniformOutput', false);
    SOphase_plot = cellfun(@(x) x(:,:,mask), phasehists(elect_array_inds), 'UniformOutput', false);
    
    close all
    mean_powphase_plot(SOpow_plot, SOphase_plot, SOpow_cbins_final, SOphase_cbins_final, ...
                       freq_cbins_final, elect_array_use, fsave_path, print_png, print_eps);
    
end

%% Plot Mean Hists By Stage
  
if plot_mean_hists_bystage
    if use_old_data
        disp('Cannot plot mean histograms by stage with old data');
    else         % Do stage-summing and rebinning separately for each stage
        
        % Load small-bin data to use for rebinning
        load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOphase_data_smallbins.mat', 'freq_cbins', 'issz', 'SOphase_cbins', 'subjects_full', ...
         'SOphase_data', 'SOphase_prop_data', 'SOphase_time_data', 'subjects', 'SOphase_smallbinsizestep', 'freq_smallbinsizestep');
        load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpow_data_smallbins.mat', 'SOpow_cbins', 'SOpow_data', 'SOpow_prop_data', 'SOpow_time_data',...
              'SOpow_smallbinsizestep');
        
        % Turn bad subject/electrode data into nans
        elect_inds = [1,2,3,4,5,6,7, 1, 2, 3, 4, 5, 6, 7,  4, 5, 6,  5,  4];
        subj_inds =  [8,8,8,8,8,8,8, 24,24,24,24,24,24,24, 27,27,27, 28, 29];

        [SOpow_data, SOpow_prop_data, SOpow_time_data, SOphase_data, SOphase_prop_data, SOphase_time_data] = remove_subj(SOpow_data, ...
                SOpow_prop_data, SOpow_time_data, SOphase_data, SOphase_prop_data, SOphase_time_data, elect_inds, subj_inds);
        
        % Sum stages and Rebin SO Power and Phase Histograms
        stage_select_curr = {[1,2,3,4,5], 5, 4, [1,2,3], 3, 2, 1};
        issz_select_curr = false; % leave empty to get both SZ and controls
        TIB_req_power_curr = 0;
        
        count_flag_curr = true; % get TFpeak counts, not rates
        num_elects_curr = length(elect_array_inds);
        num_stages = length(stage_select_curr);
        night_curr = 2;
        num_subjs = 17;
        
        % Preallocate output variables
        mean_powhists = zeros(num_elects_curr, num_stages, length(freq_cbins_final), length(SOpow_cbins_final));
        mean_phasehists = zeros(num_elects_curr, num_stages, length(freq_cbins_final), length(SOphase_cbins_final));
        SOpow_rebinned_all = zeros(num_elects_curr, num_stages, length(freq_cbins_final), length(SOpow_cbins_final), num_subjs);
        mean_TIBpows = zeros(num_elects_curr, num_stages, length(SOpow_cbins_final));
        
        for ss = 1:num_stages
            for ee = 1:num_elects_curr
                % Get TFpeak counts in SOpow hist for single electrode and stage combination
                [SOpow, freqcbins_new, TIBpow, ~, issz_out,~] = sumstages_SOpowphase(SOpow_data{elect_array_inds(ee)}, ...
                    SOpow_time_data{elect_array_inds(ee)}, SOpow_prop_data{elect_array_inds(ee)},...
                    freq_cbins, 'pow', night_curr, issz_select_curr, stage_select_curr{ss}, ...
                    TIB_req_power_curr, freq_range, [], count_flag_curr);
                
                % Get TFpeak counts in SOphase hist for single electrode and stage combination
                [SOphase,~, TIBphase,~,~,~] = sumstages_SOpowphase(SOphase_data{elect_array_inds(ee)}, SOphase_time_data{elect_array_inds(ee)}, ...
                    SOphase_prop_data{elect_array_inds(ee)}, freq_cbins, 'phase', night_curr, issz_select_curr, ...
                    stage_select_curr{ss}, [], freq_range, [], count_flag_curr);
                
                % Reorder dims
                SOpow = permute(SOpow, [3,2,1]);
                SOphase = permute(SOphase, [3,2,1]);
                
                % Rebin histograms
                [SOpow_resize_curr, ~, ~, ~, TIBpow] = rebin_histogram(SOpow, TIBpow, ...
                    freqcbins_new, SOpow_cbins, freq_binsizestep, SOpow_binsizestep,...
                    'pow', freq_smallbinsizestep, SOpow_smallbinsizestep,[],[],[],[],[],1);

                [SOphase_resize_curr, ~, ~,~] = rebin_histogram(SOphase, TIBphase, freqcbins_new, ...
                    SOphase_cbins, freq_binsizestep, SOphase_binsizestep,'phase',...
                    freq_smallbinsizestep, SOphase_smallbinsizestep);
                
                % Reorder dims and add to cell array
                SOpow_rebinned_curr = permute(SOpow_resize_curr, [2,3,1]);
                SOpow_rebinned_all(ee, ss, :, :, :) = SOpow_rebinned_curr;
                SOphase_rebinned_curr = permute(SOphase_resize_curr, [2,3,1]);
                
                % Get means
                mask = squeeze(mean(sum(TIBpow,2,'omitnan'),1,'omitnan')) < 1;
                powmean = mean(SOpow_rebinned_curr,3,'omitnan');
                powmean(:,mask) = nan;
                mean_powhists(ee,ss,:,:) = powmean;
                mean_phasehists(ee,ss,:,:) = mean(SOphase_rebinned_curr,3,'omitnan');
            end
        end
        
        close all;
        powphase_hist_bystage_plot(mean_powhists, mean_phasehists, SOpow_cbins_final, SOphase_cbins_final, ...
            freq_cbins_final, elect_array_use, freq_range, fsave_path, print_png, print_eps)
        
    end
end

%% Plot Pow Peak Dynamics
% Must run powphase_hist_bystage_plot first to get data necessary to run this analysis/figure
if plot_power_peak_dynamics
    
    load_data_pow_dynamics = false;
    
    if use_old_data
        peak_dynamics_summary_script;
    else
        if ~load_data_pow_dynamics
            % Select which subj/night/elect to use
            subj_num = 3; %3;
            subj_str = num2str(subj_num);
            
            subj_mask = strcmp(subj_str, subjects_full_2nights);
            night = 2;
            
            % Get histogram, time in bin, and proportion time in bin for subj
            SOpow_hist = powhists{single_elect_ind}(:,:,(night_out==night)&subj_mask);
            TIB_allstages = squeeze(TIBpow_all{single_elect_ind}((night_out==night)&subj_mask,:,:));
            stage_prop =  TIB_allstages ./ sum(TIB_allstages,1);
            
            % Load in subject data
            [data, Fs, t, ~, stages] = load_Lunesta_data(subj_num, night, 'SZ', false, 'channels', single_elect_use);
            stages.pick_t = true(1,length(stages.stage)); % use all timepoints
            stages.stage = stages.stage';
            stages.time = stages.time';
            time_range(1) = max( min(t(stages.stage~=5))-5*60, 0); % x min before first non-wake stage
            time_range(2) = min( max(t(stages.stage~=5))+5*60, max(t)); % x min after last non-wake stage

            % Get SO power for subject
            artifacts = detect_artifacts(data, Fs); % detect artifacts
            nanEEG = data;
            nanEEG(artifacts) = nan; % turn artifacts to nans
            [SOpow, SOpow_times] = compute_mtspect_power(nanEEG, Fs, 'freq_range', [0.3,1.5]); % compute SO pow
            ptiles = prctile(SOpow(SOpow_times>=time_range(1) & SOpow_times<=time_range(2)), [1, 99]); % get 1 and 99th percentile
            SOpow = SOpow-ptiles(1); % subract 1st percentile
            SOpow = SOpow/(ptiles(2) - ptiles(1)); % normalize
            
            % Get peak data for subj
            file_prefix = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/watershed_results_v2';
            filepath = fullfile(file_prefix, ['Lun', subj_str, '_', elect_names{single_elect_ind}, '_', ...
                num2str(night), '/peakstats_tbl.mat']);
            load(filepath, 'saveout_table');
            peak_freqs = saveout_table.xy_wcentrd(:,2);
            peak_times = saveout_table.xy_wcentrd(:,1);
            peak_proms = saveout_table.height;
            time_window = [60*5 15];
            fwindow_size = freq_binsizestep(1);
            
        else
            load(fullfile(base_path,'figure_ResultsAndData/peak_power_dynamics_summary/SO_power_example_data.mat'));
        end

        % Get bystage data 
        assert(exist('SOpow_rebinned_all', 'var'), 'Variable "SOpow_rebinned_all" missing, must run "hists_by_stage" in cell above');
        bystage_subj_ind = find(strcmp(subj_str, subjects_full));
        bystage_data = squeeze(SOpow_rebinned_all(2, [3,5,6,7],:,:,bystage_subj_ind));
        
        % Call plotting function
        close all;
        power_dynamics_summary(data, stages, stage_prop, Fs, freq_range, SOpow, SOpow_times, SOpow_hist, SOpow_cbins_final, freq_cbins_final,...
            peak_freqs, peak_times, peak_proms, bystage_data, time_window, fwindow_size, fsave_path, print_png, print_eps);
        
    end
end

%% Plot Phase Peak Dynamics

if plot_phase_peak_dynamics
    
    if use_old_data
        SWPhase_color_peak_plot;
    else
        % Select which subj/night/elect to use
        subj_num = 11;
        subj_str = '11';
        
        subj_mask = strcmp(subj_str, subjects_full_2nights);
        night = 2;
        
        % Get phase histogram
        phasehist = phasehists{single_elect_ind}(:,:,(night_out==night)&subj_mask);
        
        % Get peak data for subj
        if ~use_old_data
            file_prefix = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/watershed_results_v2';
            filepath = fullfile(file_prefix, ['Lun', num2str(subj_num), '_', single_elect_use, '_', num2str(night), '/peakstats_tbl.mat']);
            load(filepath, 'saveout_table');
            peak_data = nan(height(saveout_table), 5);
            peak_data(:,2) = saveout_table.xy_wcentrd(:,1);
            peak_data(:,3) = ones(height(saveout_table),1);
            peak_data(:,4) = saveout_table.xy_wcentrd(:,2);
            peak_data(:,5) = saveout_table.height;
        else
            
        end
        
        disp(['Generating figure for ',num2str(subj_num),'_',single_elect_use,'_',num2str(night)]);
        
        % Get subject EEG data
        [data, Fs, ~, ~, stages] = load_Lunesta_data(subj_num, night, 'SZ', false, 'channels', single_elect_use);
        stage_struct.pick_t = true(1,length(stages.stage));
        stage_struct.stage = stages.stage';
        stage_struct.time = stages.time';
       
        % Call plotting function
        close all;
        phase_dynamics_summary(data, Fs, stage_struct, phasehist, peak_data, SOphase_cbins_final, freq_cbins_final,...
            freq_range, fsave_path, print_png, print_eps);

    end
end

%% Plot Merge Method

if plot_merge_method
    close all;
    merge_factor_simulation;   
    merge_steps_summary;
end

%% Plot Histogram Schematics

if plot_hist_schematic
    
%     hist_schematics;
%     phase_hist_schematic;
%     power_hist_schematic;
    power_phase_joint_figure;
    
end

%% Plot method summary
if plot_methods_summary
    % Must run with MATLAB version earlier than 2021b
    zoom_methods_summary;
end

%% Plot Phase cube animation

if plot_phase_cube
    close all;
    phase_cube_animation;
    plot_selected_cube_slices;
end

%% GCRC night 2 night comparison
if plot_GCRC_compare
    GCRC_Lun_compare;
end

%% Plot TFpeak properties

if plot_TFpeak_props
    subjs = [12,3,13,5]; % select subjects
    num_subjs = length(subjs);
    
    % Preallocate 
    n1_peaktables = cell(num_subjs,1);
    n2_peaktables = cell(num_subjs,1);
    
    % Get watershed peak data from selected subjects
    for s = 1:num_subjs
        file_prefix = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/watershed_results_v2';
        filepath = fullfile(file_prefix, ['Lun', num2str(subjs(s)), '_', single_elect_use, '_', ...
            num2str(1), '/peakstats_tbl.mat']);
        load(filepath, 'saveout_table');
        n1_peaktables{s} = saveout_table;
        
        file_prefix = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/watershed_results_v2';
        filepath = fullfile(file_prefix, ['Lun', num2str(subjs(s)), '_', single_elect_use, '_', ...
            num2str(2), '/peakstats_tbl.mat']);
        load(filepath, 'saveout_table');
        n2_peaktables{s} = saveout_table;
    end
    
    close all;
    plot_TFpeak_properties(n1_peaktables, n2_peaktables, fsave_path, print_png, print_eps);
    
end

%% Plot power histograms with different normalization techniques
if plot_pownorms
    
    % Load perctentile SOpower normalization mean histograms
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_percentile.mat')
    SOpow_perc = SOpowhist_data(:,elect_array_inds);
    SOpow_cbins_perc = SOpow_cbins{1}(:,1)*100;
    
    % Load shift SOpower normalization mean histograms
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_shift.mat')
    SOpow_shift = SOpowhist_data(:,elect_array_inds);
    SOpow_cbins_shift = SOpow_cbins{1}(:,1);
    
    % Load proportion SOpower normalization mean histograms
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_proportion.mat')
    SOpow_prop = SOpowhist_data(:,elect_array_inds);
    SOpow_cbins_prop = SOpow_cbins{1}(:,1);
    
    % Load absolute SOpower normalization mean histograms
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_absolute.mat')
    SOpow_abs = SOpowhist_data(:,elect_array_inds);
    SOpow_cbins_abs = SOpow_cbins{1}(:,1);
    
    % Concatenate histograms and bins
    SOpows = cat(1, SOpow_perc, SOpow_shift, SOpow_prop, SOpow_abs); % norm method x electrode
    SOpow_cbins_all = cat(2, SOpow_cbins_perc, SOpow_cbins_shift, SOpow_cbins_prop, SOpow_cbins_abs);
    
    xlims = {[0,100], [-5,21], [0,1], [5,35]};
    xlabs = {'% SO power', '5th Percentile Aligned (dB)', 'Proportional Power', 'Unscaled Power (dB)'};
    
    close all
    other_normalizations(SOpows, SOpow_cbins_all, freq_cbins, xlims, elect_array_use, [], xlabs, fsave_path, print_png, print_eps);
        
end


%% Rate Reconstruction
if plot_reconstructions
    rate_reconstructions;
end


%%
if plot_PIB_per_stage

    % Load perctentile SOpower normalization mean histograms
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_percentile.mat',...
        'SOpow_prop_data', 'SOpow_cbins');
    ptile_propdata = SOpow_prop_data(elect_array_inds);
    ptile_powbins = SOpow_cbins{1}(:,1);
    
    % Load shift SOpower normalization mean histograms
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_shift.mat',...
        'SOpow_prop_data', 'SOpow_cbins')
    shift_propdata = SOpow_prop_data(elect_array_inds);
    shift_powbins = SOpow_cbins{1}(:,1);
    
    % Load proportion SOpower normalization mean histograms
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_proportion.mat',...
        'SOpow_prop_data', 'SOpow_cbins');
    prop_propdata = SOpow_prop_data(elect_array_inds);
    prop_powbins = SOpow_cbins{1}(:,1);

    % Load absolute SOpower normalization mean histograms
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_absolute.mat',...
        'SOpow_prop_data', 'SOpow_cbins');
    none_propdata = SOpow_prop_data(elect_array_inds);
    none_powbins = SOpow_cbins{1}(:,1);
    
    % Concatenate 
    propdata_all = cat(1, ptile_propdata, shift_propdata, prop_propdata, none_propdata);
    powbins_all = [ptile_powbins, shift_powbins, prop_powbins, none_powbins];
    xlims = {[0 1],[-5 22],[0 1],[0 35]};
    
    norm_strs = {'% SO Power', '5th Percentile Aligned (dB)', 'Porportional Power', 'Unscaled Power (dB)'};
    PIB_per_stage_figure(propdata_all, powbins_all, elect_names(elect_array_inds), norm_strs, xlims,...
                        fsave_path, print_png, print_eps);

end

%% SOpower means per electrode/stage/normalization TABLE
if SOpow_mean_table

    % Load perctentile SOpower normalization mean histograms
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_percentile_fullrecord.mat',...
        'SOpow_data');
    ptile_powdata_n2 = SOpow_data(elect_array_inds);
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_percentile_fullrecord_n1.mat',...
        'SOpow_data');
    ptile_powdata_n1 = SOpow_data(elect_array_inds);
    
    % Load shift SOpower normalization mean histograms
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_shift_fullrecord.mat',...
        'SOpow_data');
    shift_powdata_n2 = SOpow_data(elect_array_inds);
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_shift_fullrecord_n1.mat',...
        'SOpow_data');
    shift_powdata_n1 = SOpow_data(elect_array_inds);

    % Load proportion SOpower normalization mean histograms
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_proportion_fullrecord.mat',...
        'SOpow_data');
    prop_powdata_n2 = SOpow_data(elect_array_inds);
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_proportion_fullrecord_n1.mat',...
        'SOpow_data');
    prop_powdata_n1 = SOpow_data(elect_array_inds);

    % Load absolute SOpower normalization mean histograms
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_absolute_fullrecord.mat',...
        'SOpow_data');
    none_powdata_n2 = SOpow_data(elect_array_inds);
    load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/SOpow_data_absolute_fullrecord_n1.mat',...
        'SOpow_data', 'subjects');
    none_powdata_n1 = SOpow_data(elect_array_inds);


    % Concatenate 
    powdata_all = cat(3, [ptile_powdata_n1; shift_powdata_n1; prop_powdata_n1; none_powdata_n1], ...
                         [ptile_powdata_n2; shift_powdata_n2; prop_powdata_n2; none_powdata_n2]);
    [SOpow_subj_means, SOpow_subj_SDs] = calc_SOpow_means(powdata_all, subjects);
    
    % Average subjs and nights 
    SOpow_means = squeeze(mean(SOpow_subj_means,[3,4],'omitnan'));
    SOpow_SDs = squeeze(mean(SOpow_subj_SDs,[3,4],'omitnan'));
    
end


%% Graphical Abstract

if graphical_abstract_plot
        % Select which subj/night/elect to use
        subj_num = 11;
        subj_str = '11';
        
        subj_mask = strcmp(subj_str, subjects_full_2nights);
        night = 2;
        
        % Get TFpeak data
        file_prefix = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/watershed_results_v2';
        filepath = fullfile(file_prefix, ['Lun', num2str(subj_num), '_', single_elect_use, '_', num2str(night), '/peakstats_tbl.mat']);
        load(filepath, 'saveout_table');
        peak_data = nan(height(saveout_table), 5);
        peak_data(:,2) = saveout_table.xy_wcentrd(:,1);
        peak_data(:,3) = ones(height(saveout_table),1);
        peak_data(:,4) = saveout_table.xy_wcentrd(:,2);
        peak_data(:,5) = saveout_table.height;
        
        % Get phase histogram
        phasehist = phasehists{single_elect_ind}(:,:,(night_out==night)&subj_mask);

        % Get pow histogram
        powhist = powhists{single_elect_ind}(:,:,(night_out==night)&subj_mask);
                
        % Get subject EEG data
        [data, Fs, ~, ~, stage_struct] = load_Lunesta_data(subj_num, night, 'SZ', false, 'channels', single_elect_use);
        stages = stage_struct.stage';
        stage_times = stage_struct.time';

        graphical_abstract(data, Fs, stages, stage_times, powhist, phasehist, peak_data, ...
                           SOphase_cbins_final, SOpow_cbins_final, freq_cbins_final, freq_range,...
                           fsave_path, print_png, print_eps);

end
    
