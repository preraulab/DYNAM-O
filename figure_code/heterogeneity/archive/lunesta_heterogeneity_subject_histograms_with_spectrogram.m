clear;

%% SET UP PATHS
% check whether martinos / eris
fpath='/preraugp/projects/spindle_detection/results/lunesta/figures/hist_counts/';

if exist('/data/preraugp', 'dir')
    base='/data';
else
    base='/eris';
end

hist_path=fullfile(base,'/preraugp/projects/spindle_detection/results/lunesta/figures/hist_20180302/');
addpath(hist_path);

mst_path=fullfile(base,'/preraugp/archive/Lunesta Study/');

% add path to EEGs and sleep stages to plot the spectrogram
addpath([base '/preraugp/archive/Lunesta Study']);

% add path to the sleep stage text files
addpath([base '/preraugp/archive/Lunesta Study/sleep_stages/']);

% add path to load csv's
addpath(genpath([base '/preraugp/projects/spindle_detection/code/Lunesta histograms over time/All_channels_filtered_peaks']));

% add path to lunesta_load_file_from_meta
addpath([base '/preraugp/projects/spindle_detection/code/Lunesta histograms over time/']);

results_folder=fullfile(base, '/preraugp/users/prath/projects/Spindle Detection/results/Lunesta_poster_histograms_spectrograms');

%% GET FILE AND SUBJECT AND ELECTRODE INFORMATION

% import memory test results
[~,~,memory_test_results]=xlsread([mst_path,'MST.xlsx']);

% find subjects administered lunesta
lunesta_idx = cellfun(@(x) any(x==1), memory_test_results(2:end,4),'UniformOutput',false);
lunesta_idx = vertcat(lunesta_idx{:});

% find subjects that are sz and control
sz_idx=cellfun(@(x) any(x==1), memory_test_results(2:end,3),'UniformOutput',false);
sz_idx = vertcat(sz_idx{:});

control_idx=cellfun(@(x) any(x==0), memory_test_results(2:end,3),'UniformOutput',false);
control_idx = vertcat(control_idx{:});

subj_filenames=memory_test_results(2:end,2);
lunesta_subjects_sz=subj_filenames(sz_idx);
lunesta_subjects_control=subj_filenames(control_idx);

% subject night params
subject_types={'Control', 'Sz'};
all_lunesta_subjects={lunesta_subjects_control;lunesta_subjects_sz};

% all_hist_filenames={control_hist_filenames;sz_hist_filenames};
total_nights=[2,4];
channel_names = {'C3','C4','F3','F4','O1','O2','Pz','X1'};
spectrogram_night_number = 2;
% csv_columns = {'id','peak_time','volume','peak_freq','peak_height','sleep_stage'};

% csv params
peak_data_freq_idx = 4;
peak_data_stage_idx = 6;

max_nights = 4;

%% SET THE TIME SEGMENT LIMITS

segment_xlims = [[13832 13892];[17261 17321];[15010 15070];[5605 5665];...
    [22384 22444];[15346 15406];[23208 23268];[26901 26961];[14216 14276];...
    [5701 5761];[18926 18986];[11246 11306];[13867 13927];[6102 6162];...
    [12276 12336];[16737 16797];[27497 27557]];

full_night_xlims = [[6195 25503];[3279 33447];[6366 34121];[4246 30893];...
    [3669 34990];[7377 35069];[5878 35700];[8068 34798];[2801 34359];[830  31016];...
    [3826 37673];[3831 33033];[5021 34169];[4867 31445];[10296 36805];[7535 37594];...
    [9428 37120]];

segment_caxis = [[-20.1675 8.6379];[-15.9600 11.2222];[-13.5 8.9]%[-17.9102 7.0252];...
    [-13.2586 15.6159];[-19.7046 11.6287];[-20.6206 11.1964];[-19.1564 12.5432];...
    [-18.6624 11.0005];[-18.6936 15.9467];[-19.0248 13.0286];[-24.3071 13.5660];...
    [-18.9699 12.2408];[-21.6855 11.7767];[-20.6119 14.3111];[-17.0974 17.7243];...
    [-19.7366 13.6733];[-20.9828 14.3816]];

hist_mode_lists = {[[0.71 2.044];[2.445 5.731];[12.63 14.47]];...
    [[0.71 1.884];[2.445 6.132];[10.78 12.71];[12.75 14.2]];...
    [[0.71 1.804];[2.365 5.09];[7.174 10.46];[13.67 15.59]];
    [[0.71 1.723];[2.445 5.411];[8.136 9.9];[10.62 12.14];[13.59 16.39]];...
    [[0.71 2.124];[2.365 6.693];[12.06 14.95]]};
mode_list_subjects = {'Lun12';'Lun03';'Lun13';'Lun05';'Lun20'};
%% SET THE SPECTROGAM PARAMETERS

% Full night spectrogram parameters
full_spectrogram_parameters.frequency_min = 3;
full_spectrogram_parameters.frequency_max = 30;
full_spectrogram_parameters.taper_params = [15, 29];
full_spectrogram_parameters.window_params = [30, 10];
full_spectrogram_parameters.min_NFFT = [];
full_spectrogram_parameters.detrend = 'linear';
full_spectrogram_parameters.weighting = [];
full_spectrogram_parameters.ploton = false;
full_spectrogram_parameters.verbose = true;
full_spectrogram_parameters.xyflip = true;


%Segment spectrogram parameters

segment_spectrogram_parameters.frequency_min = 3;
segment_spectrogram_parameters.frequency_max = 30;
segment_spectrogram_parameters.taper_params = [2, 3];
segment_spectrogram_parameters.window_params = [1, 0.05];
segment_spectrogram_parameters.min_NFFT = 2^10;
segment_spectrogram_parameters.detrend = 'linear';
segment_spectrogram_parameters.weighting = [];
segment_spectrogram_parameters.ploton = false;
segment_spectrogram_parameters.verbose = true;
segment_spectrogram_parameters.xyflip = true;

%% SET THE HISTOGRAM PARAMETERS

% bin params
num_bins = 499;
bin_edges = linspace(0,40,num_bins+1);
stage_types = {'Sleep', 'NREM'};
stage_axis_idx = [3,6];
stage_type_vals = {[1,2,3,4]; [1,2,3]};
bin_centres = bin_edges(1:end-1) + diff(bin_edges(1:2))./2;


%% LOOP START
control_subjects = all_lunesta_subjects{1,1};
electrode = 'C3';
spectrogram_night = 2;

subj_count = 0;
% for subject_number = 1 : length(control_subjects)
%  for subject_number = [10,2,11,3]
for subject_number = 10%[10,2]
    
    subj_count = subj_count+1;
    subject_name = control_subjects{subject_number};
    mode_list_idx = find(strcmp(subject_name, mode_list_subjects));
    
    for night = 1:2
        %% LOAD THE SUBJECT DATA
        disp(['loading data for ',subject_name,'...']);
        
        
        % load EEG
        [eeg_channel_data, stage_struct, Fs, peak_data] = lunesta_load_from_meta(subject_name, night, electrode);
        
        
        %% COMPUTE SPECTROGRAM
        disp('computing spectrogram...');
        
        if night==spectrogram_night
            % full night
            [full_sspect,full_sstimes,full_ssfreqs]=multitaper_spectrogram_mex(eeg_channel_data, Fs,...
                [full_spectrogram_parameters.frequency_min min([Fs/2 full_spectrogram_parameters.frequency_max])], ...
                full_spectrogram_parameters.taper_params,full_spectrogram_parameters.window_params, ...
                full_spectrogram_parameters.min_NFFT, full_spectrogram_parameters.detrend, full_spectrogram_parameters.weighting,...
                full_spectrogram_parameters.ploton, full_spectrogram_parameters.verbose, full_spectrogram_parameters.xyflip);

            % segment
            t=0:(1/Fs):(length(eeg_channel_data)-1)/Fs;
            segment_inds = (t>=segment_xlims(subject_number,1))&(t<=segment_xlims(subject_number,2));
            segment_eeg = eeg_channel_data(segment_inds);
            
            [full_sspect_fine,full_sstimes_fine,full_ssfreqs_fine]=multitaper_spectrogram_mex(eeg_channel_data, Fs,...
                [segment_spectrogram_parameters.frequency_min min([Fs/2 segment_spectrogram_parameters.frequency_max])], ...
                segment_spectrogram_parameters.taper_params,segment_spectrogram_parameters.window_params, ...
                segment_spectrogram_parameters.min_NFFT, segment_spectrogram_parameters.detrend, segment_spectrogram_parameters.weighting,...
                segment_spectrogram_parameters.ploton, segment_spectrogram_parameters.verbose, segment_spectrogram_parameters.xyflip);
            
            [full_bsspect,bl] = baseline_subtract_spectrogram(full_sspect_fine',full_sstimes_fine,2,5);
            
            segment_spect_inds = (full_sstimes_fine>=segment_xlims(subject_number,1))&(full_sstimes_fine<=segment_xlims(subject_number,2));
            segment_sstimes = full_sstimes_fine(segment_spect_inds);
            segment_bsspect = full_bsspect(:,segment_spect_inds);
        end
        %% COMPUTE RATE HISTOGRAM
        disp(['computing rate histograms for night',num2str(night),'...']);
        
        peak_frequencies = peak_data(:, peak_data_freq_idx);
        peak_stages = peak_data(:,peak_data_stage_idx);
        all_stages{night} = stage_struct.stage;
        stage_times{night} = stage_struct.time;
        
        % find total time in nrem, rem and wake to compute
        % rates
        nrem_time = findStageTotalTime_Lunesta(stage_struct,[1,2,3], Fs);
        sleep_time = findStageTotalTime_Lunesta(stage_struct,[1,2,3,4], Fs);
        
        % find indices of peaks in nrem and sleep
        nrem_peaks_idx = ismember(peak_stages,1:3);
        sleep_peaks_idx = ismember(peak_stages,1:4);
        
        nrem_count_hist = histcounts(peak_frequencies(nrem_peaks_idx), bin_edges);
        nrem_rate_hist(night,:) = nrem_count_hist./nrem_time;
        
        sleep_count_hist = histcounts(peak_frequencies(sleep_peaks_idx), bin_edges);
        sleep_rate_hist(night,:) = sleep_count_hist./sleep_time;
        
        % find the total rate in each mode
        [hist_mode_rates{subj_count}] = hist_mode_stats(hist_mode_lists{mode_list_idx}, sleep_rate_hist(night,:), bin_centres);
        
    end
    %% PLOT THE FIGURE
    disp('plotting figure...')
    % close all;
    % initialize new figure for the subject
    night_comparison_figure=fullfig;
    %  ax =figdesign(5,8,'type','usletter','orient','landscape','merge',...
    %                     {1:8:33,8:8:40,2:4,[10:12,18:20,26:28,34:36],5:7,[13:15,21:23,29:31,37:39]},'margins',[.05,.8,.05,.05,.01]);
    ax = figdesign(5,9,'merge',{1:4,[10:13,19:22,28:31,37:40],5:8,[14:17,23:26,32:35,41:44],9:9:45},...
        'margins',[.05,.7,.04,.01,.015]);
    
    % full night hypnoplot
    axes(ax(1));
    hypnoplot(stage_times{spectrogram_night},all_stages{spectrogram_night});
    xlim(full_night_xlims(subject_number,:));
    % scaleline(3600,'1 Hour');
    title('Full Night Spectrogram');
    ax(1).Title.FontSize = 18;
    
    % full night spectrogram
    axes(ax(3));
    imagesc(full_sstimes,full_ssfreqs,pow2db(full_sspect)');
    axis xy;
    colormap jet;
    xlim(full_night_xlims(subject_number,:));
    caxis([-12 10]);
    set(gca,'XTickLabel',[]);
    scaleline(3600,'1 hour')
    vline(segment_xlims(subject_number,:),'linewidth', 1, 'color', 'm');
    ylabel('Frequency (Hz)');
    topcolorbar(0.1, 0.01, 0.055);
    ax(3).FontSize=18;
    linkaxes([ax(1) ax(3)],'x');
    
    
    % segment hypnoplot
    axes(ax(2));
    % plot(t,filtered_eeg);
    hypnoplot(stage_times{spectrogram_night},all_stages{spectrogram_night})
    xlim(segment_xlims(subject_number,:));
    axis off;
    title('One Minute Segment');
    ylabel('Frequency (Hz)');
    % linkaxes([ax(2) ax(5)],'x');
    ax(2).FontSize=18;
    
    
    % segment spectrogram
    axes(ax(4));
    % imagesc(full_sstimes_fine,full_ssfreqs_fine,pow2db(full_sspect_fine)');
    imagesc(segment_sstimes, full_ssfreqs, pow2db(full_sspect_fine(segment_spect_inds,:)'))
    axis xy;
    colormap jet;
    % climscale;
    % xlim(segment_xlims(subject_number,:));
    caxis(segment_caxis(subject_number,:));
    scaleline(10,'10 seconds');
    topcolorbar(0.1, 0.01, 0.055);
    ax(4).FontSize=18;
    linkaxes([ax(2) ax(4)],'x');
    
    % % filter eeg and plot
    % filtered_eeg = quickbandpass(full_eeg',Fs, [0.3 35]);
    % end
    
    % plot sleep histogram
    axes(ax(5));
    hold on;
    rate_hist_plots = plot(bin_centres, sleep_rate_hist);
    set(rate_hist_plots(spectrogram_night_number),'LineWidth',2);
    % legend('Night 1','Night 2')
    set(rate_hist_plots(1),'Color',[.5 .5 .5]);
    set(rate_hist_plots(2),'Color','b');
    
    uistack(rate_hist_plots,'bottom');
    xlim([segment_spectrogram_parameters.frequency_min,segment_spectrogram_parameters.frequency_max]);
    % set(gca,'YTick',[]);
    xlabel('Frequency (Hz)');
    title('Rate Histogram');
    ax(5).FontSize=18;
    % findpeaks(sleep_rate_hist(2,:),bin_centres,'MinPeakHeight',0.0065,'MinPeakDistance',1.8,'Annotate','extents');
    
    [pks,locs,pk_widths,pk_prominence]=findpeaks(sleep_rate_hist(2,:),bin_centres,'MinPeakHeight',0.0065,'MinPeakDistance',1.8,'Annotate','extents');
    % objs = get(gca,'Children');
    % line_obj=objs.findobj('Tag','Signal');
    % delete(line_obj);% removing unneccesary line plotted by findpeaks
    ylim([0 0.015]);
    legend off;
    sub_locs = locs(locs>=8 & locs<=25);
    vline(sub_locs,'linewidth',1,'color','k');
    
    % shade the rate modes
    hist_mode_list = hist_mode_lists{mode_list_idx};
    y_l = ylim;
    for i = 1 : size(hist_mode_list,1)
        fillobj = fill([hist_mode_list(i,1) hist_mode_list(i,1) hist_mode_list(i,2) hist_mode_list(i,2)],[y_l(1) y_l(2) y_l(2) y_l(1)],'g',...
            'EdgeColor','None');
        uistack(fillobj,'bottom');
        
        text(hist_mode_list(i,1), 0.015-0.002*i, sprintf('%.1f',hist_mode_rates{subj_count}(i)*60));
        % add rate in each
    end
    
    % plot these detected peaks on spectrogram
    % axes(ax(3));
    % hline(sub_locs,2,'k');
    %
    axes(ax(4));
    for ii = 1 : length(sub_locs)
        hline(sub_locs(ii),'linewidth',1,'color','k');
    end
%     print(night_comparison_figure,[subject_name,'.eps'],'-depsc');
%     
%     print(night_comparison_figure,[subject_name,'.png'],'-dpng','-r600');
    
    %% ALTERNATIVE PLOT
    %
    %
    %  % initialize new figure for the subject
    % night_comparison_figure=figure;
    % set(night_comparison_figure,'Units','normalized','Position',[0.0895 0.1944 0.7605 0.6396]);
    %
    % ax = figdesign(5,9,'merge',{1:4,[10:13,19:22,28:31,37:40],5:8,[14:17,23:26],[32:35,41:44],9:9:45},'margins',[.05,.5,.05,.05,.01]);
    %
    % % full night hypnoplot
    % axes(ax(1));
    % hypnoplot(stage_times{spectrogram_night},all_stages{spectrogram_night});
    % xlim(full_night_xlims(subject_number,:));
    % % scaleline(3600,'1 Hour');
    % title(subject_name);
    %
    %
    % % full night spectrogram
    % axes(ax(4));
    % imagesc(full_sstimes,full_ssfreqs,pow2db(full_sspect)');
    % axis xy;
    % colormap jet;
    % xlim(full_night_xlims(subject_number,:));
    % caxis([-12 10]);
    % set(gca,'XTickLabel',[]);
    % scaleline(3600,'1 hour')
    % vline(segment_xlims(subject_number,:),1,'m');
    %
    % % segment hypnoplot
    % axes(ax(2));
    % % plot(t,filtered_eeg);
    % hypnoplot(stage_times{spectrogram_night},all_stages{spectrogram_night})
    % xlim(segment_xlims(subject_number,:));
    % axis off;
    % % linkaxes([ax(2) ax(5)],'x');
    %
    % % segment spectrogram
    % axes(ax(3));
    % imagesc(full_sstimes_fine,full_ssfreqs_fine,pow2db(full_sspect_fine)');
    % axis xy;
    % colormap jet;
    % climscale;
    % xlim(segment_xlims(subject_number,:));
    % caxis(segment_caxis(subject_number,:));
    %
    % % segment baseline subtracted spectrogram
    % % axes(ax(5))
    % % imagesc(segment_sstimes,full_ssfreqs_fine,segment_bsspect);
    % % axis xy;
    % % colormap(jet(1024));
    % % climscale;
    % % xlim(segment_xlims(subject_number,:));
    % % scaleline(10,'10 seconds');
    %
    % % segment baseline subtracted spectrogram
    % axes(ax(5))
    % imagesc(full_sstimes_fine,full_ssfreqs_fine,full_bsspect);
    % axis xy;
    % colormap(jet(1024));
    % climscale;
    % xlim(segment_xlims(subject_number,:));
    % scaleline(10,'10 seconds');
    %
    % % plot sleep histogram
    % axes(ax(6));
    % hold on;
    % rate_hist_plots = plot(bin_centres, sleep_rate_hist);
    % set(rate_hist_plots(spectrogram_night_number),'LineWidth',2);
    % % legend('Night 1','Night 2')
    % uistack(rate_hist_plots,'bottom');
    % xlim([3,25]);
    %
    % % plot nrem histogram
    % % axes(ax(6));
    % % hold on;
    % % plot(bin_centres, nrem_rate_hist,'LineWidth',2);
    % % xlim([3,35]);
    %
    % linkaxes([ax(2) ax(3) ax(5)],'x');
    %
    
end




function [hist_mode_rates] = hist_mode_stats(mode_times_list, full_hist_rates, full_hist_bin_centres)
% go through every mode on the list

num_modes = size(mode_times_list,1);
hist_mode_rates = zeros(1,num_modes);

for i = 1 : num_modes
    % get the bin times for that mode
    mode_idx = full_hist_bin_centres>=mode_times_list(i,1) & full_hist_bin_centres<=mode_times_list(i,2);
    
    % sum the hist rates within the bin
    hist_mode_rates(i) = sum(full_hist_rates(mode_idx));
    
end


end