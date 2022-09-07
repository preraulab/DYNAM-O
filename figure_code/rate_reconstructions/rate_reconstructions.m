%%% Plot rate reconstructions for all subjects %%%

% Load histogram data that includes wake
load('../figure_data_init.mat');


%% Set night and group selection
night = 2;

run_controls = true;

if run_controls
    IDS = subjects(~issz);
else
    IDS = subjects(issz & ~ismember(subjects,[30,25])); % not using IDs 30 and 25 for SZ
end

%% Plot
num_sub = length(IDS);

M=7;
N=3;
close all;
fh = figure; % open figure
ax = figdesign(M,N,'type','usletter','orient','portrait','margins',[.05 .05, .05 .075 .08, .05]);
set(ax,'visible','off');
delete(ax(num_sub+1:end)); % delete extra axes on figure

c = 0;
for aa = 1:length(ax)
    c = c + 1;
    if c<=num_sub 
        subj_num = IDS(c);

        if subj_num==10 % leave out subj 10 
            continue
        end
        
        % Set subject string
        if run_controls
            subj_str = num2str(subj_num);
        else
            subj_str = ['S' num2str(subj_num)];
        end

        subj_mask = strcmp(subj_str, repelem(subjects_full,2)); % logical index for subject

        ax_split = split_axis(ax(aa),[.5 .5],1); % split axis in 2 for observed and reconstruction

        set(ax_split,'visible','on');
        ax_split(2).Position(2) = ax_split(2).Position(2) + .01;

        % Get histogram, time in bin, and proportion time in bin for subj
        SOpow_hist = squeeze(powhists{single_elect_ind}(:,:,(night_out==night)&subj_mask));
        TIB_allstages = squeeze(TIBpow_all{single_elect_ind}((night_out==night)&subj_mask,:,:));
        stage_prop =  TIB_allstages ./ sum(TIB_allstages,1);

        try
            % Load in subject data
            [data, Fs, t, ~, stages] = load_Lunesta_data(subj_num, night, 'SZ', ~run_controls, 'channels', single_elect_use);
            stages.pick_t = true(1,length(stages.stage)); % use all timepoints
            stages.stage = stages.stage';
            stages.time = stages.time';
            time_range(1) = max( min(t(stages.stage~=5))-5*60, 0); % 5 min before first non-wake stage
            time_range(2) = min( max(t(stages.stage~=5))+5*60, max(t)); % 5 min after last non-wake stage

            % Get SO power for subject
            artifacts = detect_artifacts(data, Fs); % detect artifacts
            nanEEG = data;
            nanEEG(artifacts) = nan; % turn artifacts to nans
            [SOpow, SOpow_times] = compute_mtspect_power(nanEEG, Fs, 'freq_range', [0.3,1.5]); % compute SO pow
            ptiles = prctile(SOpow(SOpow_times>=time_range(1) & SOpow_times<=time_range(2)), [1, 99]); % get 1 and 99th percentile
            SOpow = SOpow-ptiles(1); % subract 1st percentile
            SOpow = SOpow/(ptiles(2) - ptiles(1)); % normalize

            % Get watershed peak data for subj
            file_prefix = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/watershed_results_v2';
            filepath = fullfile(file_prefix, ['Lun', subj_str, '_', single_elect_use, '_', ...
                num2str(night), '/peakstats_tbl.mat']);
            load(filepath, 'saveout_table');
            peak_freqs = saveout_table.xy_wcentrd(:,2);
            peak_times = saveout_table.xy_wcentrd(:,1);
            peak_proms = saveout_table.height;
            time_window = [60*10 15];
            fwindow_size = freq_binsizestep(1);

            %Compute the rate reconstruction
            [rate_true, rate_recon, rate_times, rate_SOP] = SOpow_hist_rate_recon(SOpow, SOpow_times, SOpow_hist, SOpow_cbins_final, ...
                                                                freq_cbins_final, peak_freqs, peak_times, time_window, fwindow_size, false);

            linkaxes(ax_split,'xy');

            axes(ax_split(2))
            imagesc(rate_times,freq_cbins_final,rate_true); % plot observed rates across time
            axis xy;
            cx = climscale(false);
            if run_controls
                title(['HC' subj_str], 'fontsize', 14);
            else
                title(['SZ' subj_str(2:end)], 'fontsize', 14);
            end

            set(gca,'xtick',[]);
            cbar = colorbar_noresize(ax_split(2));
            cbar.Label.String = 'Density';
            cbar.Label.Rotation = -90;
            cbar.Label.VerticalAlignment = "bottom";

            axes(ax_split(1))
            imagesc(rate_times,freq_cbins_final,rate_recon); % plot reconstructed rates across time
            caxis(cx);
            axis xy;
            scaleline(ax_split(1),3600,'1 Hour');
            cbar = colorbar_noresize(ax_split(1));
            cbar.Label.String = 'Density';
            cbar.Label.Rotation = -90;
            cbar.Label.VerticalAlignment = "bottom";
            xlim(time_range);
            ylim([4 18]);
            if mod(c-1, N) ==0 
                [~,yl] = outerlabels(ax_split,'','Freq. (Hz)','fontsize',10);
                yl.Position(1) = 0.08;
                yl.Position(2) = yl.Position(2)-0.1;
            end
            drawnow;
        catch
            disp('Bad file!');
        end
    end
end

set(gcf,'units','normalized','paperunits','normalized','papertype','usletter','paperposition',[0 0 2 2],'position',[0 0 2 2]);

% Save png and/or eps if desired
if print_png
    print(fh,'-dpng', '-r300', fullfile( fsave_path, 'PNG', 'all_recons.png'));
end

if print_eps
    print(fh,'-depsc', fullfile(fsave_path, 'EPS', 'all_recons.eps'));
end




