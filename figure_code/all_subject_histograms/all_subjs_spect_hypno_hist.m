%% Load histogram data
load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/watershed_TFpeaks/figure_code/figure_data_init_nowake.mat',...
    'powhists', 'issz_out', 'night_out', 'subjects', 'freq_cbins_final', 'SOpow_cbins_final');
subjects = repelem(subjects, 2);

%% Set subjects
cntrl_subjs = [9 10 11 12 13 15 17 18 19 20 21]; 
sz_subjs  = [1 4 5 7 8 9 10 11 13 14 15 17 18 19 20 21 22 23 24 25 26 30 31];

subj_IDs = [cntrl_subjs'; sz_subjs'];
issz = [false(length(cntrl_subjs),1); true(length(sz_subjs),1)];
nights = [1,2];
electrodes = {'C3', 'C4', 'F3', 'F4', 'O1', 'O2', 'Pz'}; 

base = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/figure_ResultsAndData/all_subjs_spect_hypno_powhist';

%% Loop through to create plots
parfor ee = 1:length(electrodes)
    for s = 1:length(subj_IDs)
        for n = 1:length(nights)
            
            %% Get data
            try
                [EEG, Fs, t, labels, stages] = load_Lunesta_data(subj_IDs(s), n, 'SZ', issz(s), 'channels', electrodes{ee});
            catch
                disp([subj_str, ' n', num2str(n), ' ', electrodes{ee}, ' --- FAILED']);
                continue 
            end
            
            %% Make spect and hypnoplot
            [fh,ax] = spectrogram_hypnoplot(EEG, Fs, stages);
            
            %% Make pow histogram
            fh2 = figure;
            mask = (subjects==subj_IDs(s)) & (night_out==n) & (issz_out==issz(s));
            if sum(mask) == 0
                continue
            end
            hist_data = powhists{ee}(:,:,mask);
            
            imagesc(SOpow_cbins_final, freq_cbins_final, hist_data);
            axis xy;
            if range(hist_data)>0
                climscale;
            end
            xlabel('% SO Power')
            ylabel('Frequency (Hz)')
            
            %% Merge
            new_fig = mergefigures(fh,fh2); 
            close([fh, fh2]);
            if issz(s)==1
                subj_str = ['S', num2str(subj_IDs(s))];
            else
                subj_str = num2str(subj_IDs(s));
            end
            suptitle([subj_str, ' n', num2str(n), ' ', electrodes{ee}])
            set(new_fig, 'paperorientation','landscape', 'units','normalized','paperunits','normalized','papertype','usletter',...
                'paperposition',[0 0 0.8 0.8],'position',[0 0 0.8 0.8]);

            %% Save
            s_path = fullfile(base, electrodes{ee}, [subj_str, 'n', num2str(n), electrodes{ee}, '.png']);
            saveas(gcf,s_path);
        end
    end
end