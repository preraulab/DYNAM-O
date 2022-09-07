%%% Computing multicomparison tests between different electrodes for night 2 of controls

ccc; 

test_type = 'FDR'; % FDR, perm, gperm

%% Load SO power/phase data
load('/data/preraugp/projects/transient_oscillations_paper/results/SOpowphase_results/SOphase_data_orig.mat', 'electrodes', 'freq_cbins', 'issz', 'SOphase_cbins', 'SOphase_data',...
                                                                                                         'SOphase_prop_data', 'SOphase_time_data', 'subjects');
load('/data/preraugp/projects/transient_oscillations_paper/results/SOpowphase_results/SOpow_data_orig.mat', 'SOpow_cbins', 'SOpow_data', 'SOpow_prop_data', 'SOpow_time_data');

electrodes = electrodes(1:7); % not using last electrode (x1)

%% Reconstruct power and phase data for each stage (N1, N2, N3, NREM, REM, WAKE)
electrode_inds = [1,2,3,4,5,6,7]; 
stage_select = [1,2,3,4,5];
night_select = [2];
issz_select = false;
freq_range = [4,35];
freq_cbins_length = length(freq_cbins((freq_cbins <= freq_range(2)) & (freq_cbins >= freq_range(1))));
num_subjs = sum(~issz);
num_nights = length(night_select);

num_elects = length(electrode_inds);

powhists = zeros(num_elects, num_subjs*num_nights, length(SOpow_cbins), freq_cbins_length);
phasehists = zeros(num_elects, num_subjs*num_nights, length(SOphase_cbins), freq_cbins_length);

for ee = 1:num_elects
        
        e_use = electrode_inds(ee);

        [SOpow,~,~,~,night_out] = reconstruct_SOpowphase(SOpow_data{e_use}, SOpow_time_data{e_use}, SOpow_prop_data{e_use}, freq_cbins, 'pow', night_select, issz_select, ...
                                                 stage_select, [], freq_range);
        [SOphase,~,~,~,~] = reconstruct_SOpowphase(SOphase_data{e_use}, SOphase_time_data{e_use}, SOphase_prop_data{e_use}, freq_cbins, 'phase', night_select, issz_select, ...
                                                 stage_select, [], freq_range);
        
        powhists(ee,:,:,:) = SOpow;
        phasehists(ee,:,:,:) = SOphase;
        
end


powhists = permute(powhists, [1,3,4,2]);
phasehists = permute(phasehists, [1,3,4,2]);

mean_powhists = nanmean(powhists,4);
mean_phasehists = nanmean(phasehists,4);


 %% Run multicomparisons testing
 
 switch test_type
     case 'FDR'
         iterations = false;
         FDR = 0.1;
     case 'gperm'
         iterations = 500;
         alpha_level = 0.05;
     case 'perm'
         iterations = 500;
        alpha_level = 0.05;
 end
 

disp('Comptuting power differences...');

for ee1 = 1:length(electrodes)
    for ee2 = ee1:length(electrodes)
        if ee1 ~= ee2
          
            disp(['    ' electrodes{ee1} ' vs. '  electrodes{ee2} '...']);
            
            diff_pow{ee1,ee2} = squeeze(mean_powhists(ee1,:,:,:)) - squeeze(mean_powhists(ee2,:,:,:));
            diff_pow{ee2,ee1} = squeeze(mean_powhists(ee2,:,:,:)) - squeeze(mean_powhists(ee1,:,:,:));
            
            tic
            gb_power{ee1,ee2} = FDRtest2(squeeze(powhists(ee1,:,:,:)), squeeze(powhists(ee2,:,:,:)), 'FDR', FDR, 'ploton', false);
            %gb_power{ee1,ee2} = permtest2(squeeze(powhists(ee1,:,:,:)), squeeze(powhists(ee2,:,:,:)), alpha_level, iterations, false);
            %gb_power{ee1,ee2} = gpermtest2(squeeze(powhists(ee1,:,:,:)), squeeze(powhists(ee2,:,:,:)), alpha_level, [], iterations, false);
            toc
            gb_power{ee2,ee1} = gb_power{ee1,ee2};
        end
    end
end

close all;


disp('Comptuting phase differences...');
for ee1 = 1:length(electrodes)
    for ee2 = ee1:length(electrodes)
        if ee1 ~= ee2
            close all;
            disp(['    ' electrodes{ee1} ' vs. '  electrodes{ee2} '...']);

            diff_phase{ee1,ee2} = squeeze(mean_phasehists(ee1,:,:,:)) - squeeze(mean_phasehists(ee2,:,:,:));
            diff_phase{ee2,ee1} = squeeze(mean_phasehists(ee2,:,:,:)) - squeeze(mean_phasehists(ee1,:,:,:));

            tic
            gb_phase{ee1,ee2} = FDRtest2(squeeze(phasehists(ee1,:,:,:)), squeeze(phasehists(ee2,:,:,:)), 'FDR', FDR, 'ploton', false);
            %gb_phase{ee1,ee2} = permtest2(squeeze(phasehists(ee1,:,:,:)), squeeze(phasehists(ee2,:,:,:)), alpha_level, iterations, false);
            %gb_phase{ee1,ee2} = gpermtest2(squeeze(phasehists(ee1,:,:,:)),squeeze(phasehists(ee2,:,:,:)), alpha_level, [], iterations, false);
            toc
            gb_phase{ee2,ee1} = gb_phase{ee1,ee2};
        end
    end
end


fname = ['spatial_' num2str(iterations) '_night' num2str(night_select) '.mat'];
save(fname);
