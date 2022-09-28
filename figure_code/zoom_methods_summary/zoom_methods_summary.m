%%%%% Plots graphical summary of watershed process %%%%%

%% parse files and add paths
disp('adding paths and parsing subject file...');
if exist('/data/preraugp/','dir')
    sys_name = '/data';
else
    sys_name='/eris';
end

addpath([sys_name '/preraugp/archive/Lunesta Study/sleep_stages/']);

% load data for the selected subject
data_idir_name = [sys_name '/preraugp/archive/Lunesta Study/'];
sess_name = 'Night2';
chan_name = 'C3'; % F3 F4 C3 Cz C4 Pz O1 O2
subj_name = 'Lun20';
ifile_type = 'edf';
d = dir([data_idir_name '*' subj_name '*' sess_name '*.' ifile_type]);
ii = 1;
curr_iname = strrep(d(ii).name,['.' ifile_type],'');
ifile_w_path = [data_idir_name d(ii).name];

% get staging information
staging_file=['x',subj_name,'-',sess_name,'.txt.vmrk'];

%% set up paramters for magnification and baseline subtraction

disp('setting up parameters for spectrogram magnification and baseline subtraction... ');
% Lun20
full_night_bounds = [7535 37594];
five_min_bounds = [21045       21345];
one_min_bounds = [21275 21335];
fifteen_sec_bounds = [21280  21295];
peak_3d_xlim = [21288  21291];
peak_3d_ylim = [9.2920 17.4613];

curr_caxis = [-19.7366 13.6733];

% Spectrogram parameters
taper_params_ultradian = [3, 5];
window_params_ultradian = [6, .25];

taper_params_fullnight = [15, 29];
window_params_fullnight = [30, 5];

frequency_max = 40;
taper_params_fine = [2, 3];
window_params_fine = [1, .05];
min_NFFT = 2^10;
ploton = false;

% Parameters for watershed and stats
f_grad = false;         % Flag for whether to use gradient of data
f_zscore = false;       % Flag for whether to use z-score of data
spect_sm_typ = 'none';  % Type of smoothing of data
bl_prc = 2;             % Percent of baseline to subtract
bl_sm_win = 5;          % Number of frequency bins by which to smooth the baseline
f_thresh_mt = false;    % Flag for whether to set a threshold floor for the spectrogram
f_pow2db = false;       % Flag for whether to use dB of spectrogram
conn = [];              % Type of connection (4 or 8) for pixels. Is set to 8 within peakWShedStats_LData
wt_typ = 1;             % Type of weight for merge rule
merge_thresh = 8;       % Weight threshold to stop merge
max_merges = inf;       % Maximum number of merges
max_area = 487900;      % Maximum area of chunk
f_verb = false;         % Flag for verbose
f_outputs = [1 1];      % Flag to compute full and/or trim outputs
f_disp = false;         % Flag for whether to plot

%% GENERATE TRANSIENT OSCILLATION SIMULATION

%Sampling rate
Fs_sim=500;
%Time (in sec)
T=8.25;
%Number of samples
N=T*Fs_sim;
t_simulation=linspace(0,T,N);

%Generate the frequencies of the spindles
f=25*ones(1,N)-3*round(t_simulation-1);

%Generate blocks of sin waves of different frequencies
mask_data=100*ones(1,N);
mask_data(mod(round(t_simulation),2)==0)=0;

time_trace=mask_data.*sin(2*pi.*f.*t_simulation);

%Apply a hanning window to make it look like a spindle
[cons, inds]=consecutive(time_trace.^2>0, 5);

for i=1:length(cons)
    time_trace(inds{i})=time_trace(inds{i}).*(hanning(cons(i)))';
end

%Compute the spectrogram
[spect_sim, stimes_sim, sfreqs_sim]= multitaper_spectrogram(time_trace,Fs_sim,[0, 40],[1 1], [.5 .01], 2^16, 'off', [], false, false, true);

%% extract and compute all the data required for plotting

disp('Loading and extracting data for magnfication and baseline subtraction...');
ifile_parsed = strsplit(ifile_w_path,'/');

[hdr,shdr,sdata] = blockEdfLoad(ifile_w_path);
channels = {shdr.signal_labels};

chan_num = find(strcmp(channels, chan_name));
if ~isempty(chan_num)

    data = sdata{chan_num}';
    Fs = shdr(chan_num).samples_in_record / hdr.data_record_duration;

    % create a time vector
    t=0:1/Fs:(length(data)-1)/Fs;

    % get staging info
    disp('Parsing staging info...')
    all_staging_data=read_staging_data_lunesta(staging_file);
    [raw_stages]= parse_staging_data_lunesta(all_staging_data,t);

    % compute ultradian spectrogram for first sub image
    frequency_range = [0 min([Fs/2, frequency_max])];
    [sspect_fullnight, sstimes_fullnight, ssfreqs_fullnight] = multitaper_spectrogram(data,Fs,...
        frequency_range,taper_params_fullnight,window_params_fullnight,min_NFFT,'off',[],ploton,false,true); % 1:round(size(data,2)/2)

    % compute microevent spectrograms for the magnified images
    [sspect_fine, sstimes_fine, ssfreqs_fine] = multitaper_spectrogram(data,Fs,...
        frequency_range,taper_params_fine,window_params_fine,min_NFFT,'off',[],ploton,false,true); % 1:round(size(data,2)/2)

    pow2db_sspect_fine = pow2db(sspect_fine');

    % filter the EEG for visualization while plotting
    filtered_eeg = quickbandpass(data,Fs,[0.3 35]);

    % Baseline subtraction
    disp('subtracting baseline...')
    % The 2d matrix to be analyzed
    data_eeg = data;
    data_sspect = sspect_fine';
    % x-axis
    x = sstimes_fine;
    % y-axis
    y = ssfreqs_fine;

    pick_f = ssfreqs_fine>=0 & ssfreqs_fine<=max(ssfreqs_fine);
    f1 = find(pick_f,1,'first');
    f2 = find(pick_f,1,'last');
    idx_f = f1:f2;

    pick_t = sstimes_fine>=one_min_bounds(1) & sstimes_fine<=one_min_bounds(2);
    t1 = find(pick_t,1,'first');
    t2 = find(pick_t,1,'last');
    idx_t = t1:t2;

    % set font size
    f_size=11;

    %****
    %* Option to use the gradient of the spectrogram
    %****
    if f_grad
        [data_gx,data_gy] = gradient(data_sspect);
        abs_grad_data = sqrt(data_gx.^2+data_gy.^2);
        data_sspect = abs_grad_data;
    end

    %****
    %* Option to z-score across time
    %****
    if f_zscore
        data_mean = mean(data_sspect,2);
        data_std = std(data_sspect,0,2);
        data_sspect = (data_sspect - repmat(data_mean,1,length(x)))./repmat(data_std,1,length(x));
    end

    %****
    %* Option to smooth
    %****
    if strcmp(spect_sm_typ,'box')
        data_sspect = imboxfilt(data_sspect,3);
    elseif strcmp(spect_sm_typ,'gauss')
        data_sspect = imgaussfilt(data_sspect,1);
    else
    end

    %****
    %* Option to remove baseline based on percentile across time
    %****
    data_sspect(data_sspect==0) = NaN;
    bl = prctile(data_sspect,bl_prc,2);
    data_sspect(isnan(data_sspect)) = 0;

    %****
    %* Option to smooth baseline using a windowed average
    %****
    if(bl_sm_win > 1)
        bl_old = bl;
        sm_hwin = floor(bl_sm_win/2);
        for ii = 1:length(bl)
            if (ii-sm_hwin) < 1
                bl(ii) = sum(bl_old(1:(ii+sm_hwin)))/(ii+sm_hwin);
            elseif (ii+sm_hwin) > length(bl)
                bl(ii) = sum(bl_old((ii-sm_hwin):end))/(length(bl)-(ii-sm_hwin));
            else
                bl(ii) = sum(bl_old((ii-sm_hwin):(ii+sm_hwin)))/bl_sm_win;
            end
        end
    end
    data_bsspect = data_sspect./repmat(bl,1,length(x));

    %****
    %* Option to threshold based on MT uncertainy
    %****
    if f_thresh_mt
        lambda = 10*log10(1e1);
        K = 3;
        nu = 2*K;
        p = 0.025;
        Q_nu_p = chi2inv(p,nu);
        thresh = lambda * log(nu/Q_nu_p);
        data_bsspect(lambda * log(max(data_bsspect,1e-10)) < thresh) = 0;
    end

    %****
    %* Option to transform to dB
    %****
    if f_pow2db
        data_bsspect = pow2db(max(data_bsspect,1e-10));
    end

    % Subselect segment of baseline subtracted
    data_bsspect = data_bsspect(idx_f,idx_t);
    % x-axis
    x_bs = x(idx_t);
    % y-axis
    y_bs = y(idx_f);


    [rgn, rgn_lbls, Lborders, amatr] = peaksWShed( data_bsspect );
    rgn_init = rgn;
    Lborders_init = Lborders;

    nr = length(y_bs);
    nc = length(x_bs);

    [rgn, bndry] = regionMergeByWeight(data_bsspect,rgn,rgn_lbls,Lborders,amatr,merge_thresh,max_merges,[],f_verb,[],f_disp);

    trim_shift = min(min(data_bsspect));
    [trim_rgn, trim_bndry] = trimRegionsWShed(data_bsspect,rgn,0.8,trim_shift);

    tmp_Ldata = cell2BWBorders(trim_rgn,[nr nc],trim_bndry);

    % Get stats for trimmed regions
    [trim_matr, matr_names, matr_fields, trim_PixelIdxList,trim_PixelList, trim_PixelValues, ...
        trim_rgn,trim_bndry] = peaksWShedStats_LData(trim_rgn,trim_bndry,data_bsspect,x_bs,y_bs,1,conn);

end

%% plotting the magnified segments and baseline subtracted versions with bounndaries
% Plot the spectogram
disp('plotting...');
f=figure;

axs=figdesign(15,2,'type','usletter','orient','portrait',...
    'margin',[.05 .05 .05 .05 .01],'merge',{[3,5],[9,11],[13,15],[17,19],...
    [21,23,25,27],[2:2:8],[10:2:16],[18:2:24],[26:2:30]});

ax_sim_timeseries=axs(1);
ax_sim_spectrogram=axs(2);

ax_hypnogram=axs(3);
ax_full_night=axs(5);
ax_5_minute=axs(6);
ax_1_minute=axs(8);
ax_15_seconds=axs(10);
ax_15_seconds_waveform=axs(11);

ax_baseline_subtracted=axs(4);
ax_region_plot=axs(7);
ax_baseline_subtracted_3D=axs(9);

linkaxes([ax_sim_timeseries ax_sim_spectrogram],'x');
linkaxes([ax_15_seconds ax_15_seconds_waveform ax_baseline_subtracted ax_baseline_subtracted_3D ax_region_plot],'x');

% plot simulation time trace and spectrogram
axes(ax_sim_timeseries)
plot(t_simulation,time_trace,'linewidth',0.25);
axmult=1.5;
ylim([-axmult*max(mask_data) axmult*max(mask_data)]);
axis off

% simulation spectrogram
axes(ax_sim_spectrogram)
imagesc(stimes_sim,sfreqs_sim, (spect_sim'));
axis xy;
climscale
colormap(rainbow4)

set(gca,'xtick',[],'ytick',[]);
ylim([2.1758   31.3514]);
axis tight

% full night hypnogram
axes(ax_hypnogram);
hypnoplot(t,raw_stages);
xlim(full_night_bounds)

% full night spectrogram
axes(ax_full_night);
imagesc(sstimes_fullnight, ssfreqs_fullnight, pow2db(sspect_fullnight'));
axis xy;
colormap(rainbow4);
try
    caxis(curr_caxis);
catch
    climscale;
end
c=caxis;

hold on;
xlim(full_night_bounds)
[h_scaleline1,h_scalelabel1]=scaleline(3600,'1 hour','x');
ylabel('Frequency(Hz)');
rectangle('Position',[five_min_bounds(1) 0 diff(five_min_bounds) 40],'EdgeColor','m','LineWidth',2)

% 5 minute
axes(ax_5_minute);
cla;
segment_5_mins_tinds = sstimes_fine>=five_min_bounds(1) & sstimes_fine<=five_min_bounds(2);
imagesc(sstimes_fine(segment_5_mins_tinds), ssfreqs_fine,pow2db_sspect_fine(:,segment_5_mins_tinds));
axis xy;
colormap(rainbow4);
caxis(c);
[h_scaleline2, h_scalelabel2] = scaleline(60,'1 minute','x');

ylabel('Frequency(Hz)')
rectangle('Position',[one_min_bounds(1) 0 diff(one_min_bounds) 40],'EdgeColor','m','LineWidth',2)


% 1 minute
axes(ax_1_minute)
segment_1_min_tinds = sstimes_fine>=one_min_bounds(1) & sstimes_fine<=one_min_bounds(2);
imagesc(sstimes_fine(segment_1_min_tinds), ssfreqs_fine, pow2db_sspect_fine(:,segment_1_min_tinds));
axis xy;
colormap(rainbow4);
caxis(c);

vline(fifteen_sec_bounds,'linewidth',2,'color','m');
scaleline(5,'5 seconds');
ylabel('Frequency(Hz)');
set(gca,'xtick',[]);
set(gca,'xticklabel',[]);

% 15 sec
axes(ax_15_seconds);
segment_20_sec_tinds = sstimes_fine>=fifteen_sec_bounds(1) & sstimes_fine<=fifteen_sec_bounds(2);
imagesc(sstimes_fine(segment_20_sec_tinds), ssfreqs_fine, pow2db_sspect_fine(:,segment_20_sec_tinds));
axis xy;
colormap(rainbow4);
caxis(c);

ylabel('Frequency(Hz)');
set(gca,'xtick',[]);
set(gca,'xticklabel',[]);

% plot eeg time trace of magnified region
axes(ax_15_seconds_waveform);
t=0:(1/Fs):(length(filtered_eeg)-1)/Fs;
plot(t,filtered_eeg);
xlim(fifteen_sec_bounds);

[h_scaleline3, h_scalelabel3] = scaleline(1,'1 second','x');
[y_scaleline3, y_scalelabel3] = scaleline(50, '50 uV', 'y');
axis off;

% axis for baseline subtracted spectrogram
axes(ax_baseline_subtracted);
bs_segment_20_sec_tinds = x_bs>=fifteen_sec_bounds(1) & x_bs<=fifteen_sec_bounds(2);
imagesc(x_bs(bs_segment_20_sec_tinds),y_bs,data_bsspect(:,bs_segment_20_sec_tinds));

axis xy;

caxis([-7 90]);
colormap(rainbow4);
ylim([0 40]);
set(gca,'xtick',[],'ytick',[]);


hold on;
for ii = 2012
    if ~isempty(trim_bndry{ii})
        xy_bndbox_ind=find_indices_variable('xy_bndbox',matr_names,matr_fields);
        bw_ind=xy_bndbox_ind(2);
        dur_ind=xy_bndbox_ind(2)-1;
        inds_xy_wcentrd=find_indices_variable('xy_wcentrd',matr_names,matr_fields);
        pf_ind=inds_xy_wcentrd(2);

        if (trim_matr(ii,bw_ind)>=2)&&(trim_matr(ii,dur_ind)>=0.5)
            tmp = zeros(nr,nc);
            tmp(trim_rgn{ii}) = 1;
            bndry_rc = bwboundaries(tmp,'noholes');
            plot(x_bs(bndry_rc{1}(:,2)),y_bs(bndry_rc{1}(:,1)),'w','LineWidth',3);
            plot(x_bs(bndry_rc{1}(:,2)),y_bs(bndry_rc{1}(:,1)),'k','LineWidth',2);

        end
    end
end

% 3d surface view of baseline subtracted segment
axes(ax_baseline_subtracted_3D);

az = 60; el = 34.8;
surface_time = x_bs(bs_segment_20_sec_tinds);
surface_freq = y_bs;
surface_sspect = data_bsspect(:,bs_segment_20_sec_tinds);

% interpolate the 3d surface
interp_time=linspace(surface_time(1),surface_time(end),length(surface_time)*4);
interp_freqs=linspace(surface_freq(1),surface_freq(end),length(surface_freq)*2);

[tgrid,fgrid]=meshgrid(surface_time,surface_freq);
[tgrid_int, fgrid_int]=meshgrid(interp_time,interp_freqs);

surface_sspect_int=interp2(tgrid,fgrid,surface_sspect,tgrid_int,fgrid_int);
surface(tgrid_int,fgrid_int,surface_sspect_int,'edgecolor','none');

colormap(jet(2048));

caxis([-7 90]);
view([az,el]);
set(gca,'xtick',[],'ytick',[],'ztick',[]);
axis off;
zlim([0 420])

shading interp;
material dull;
camlight left;
camlight left;
camlight left;

hold on;
for ii = 1:length(trim_bndry)
    if ~isempty(trim_bndry{ii})

        % filter peaks that have bw 2 to 15, duration 0.5 to 5 and frequency 5 to infinity.
        xy_bndbox_ind=find_indices_variable('xy_bndbox',matr_names,matr_fields);
        bw_ind=xy_bndbox_ind(2);
        dur_ind=xy_bndbox_ind(2)-1;

        if (trim_matr(ii,bw_ind)>=2)&&(trim_matr(ii,dur_ind)>=0.5)
            tmp = zeros(nr,nc);
            tmp(trim_rgn{ii}) = 1;

            bndry_rc = bwboundaries(tmp,'noholes');

            xvals=x_bs(bndry_rc{1}(:,2));
            yvals=y_bs(bndry_rc{1}(:,1));

            [~,xinds]=findclosest(surface_time, xvals);

            [~,yinds]=findclosest(surface_freq,yvals);

            floor_offset = 5;

            zvals=zeros(size(xvals));
            for jj=1:length(xinds)
                zvals(jj)=surface_sspect(yinds(jj),xinds(jj)) + floor_offset;
            end
            if (min(xvals)>=21289 & max(xvals)<=21291 &  min(yvals)>=9 & max(yvals)<=17)
                plot3(xvals,yvals,min(zvals)*ones(size(xvals)),'m','LineWidth',8);
            else
                plot3(xvals,yvals,min(zvals)*ones(size(xvals)),'Color',[.7 .7 .7],'LineWidth',4);
            end
        end
    end
end

ylim([.1 40]);


%***** axis for spectrogram and trimmed overlay***%
axes(ax_region_plot)
imagesc(sstimes_fine(segment_20_sec_tinds), ssfreqs_fine, pow2db_sspect_fine(:,segment_20_sec_tinds));

axis xy;
climscale;
colormap(rainbow4);
caxis(curr_caxis);
ylim([0 40]);

hold on;
for ii = 1:length(trim_bndry)
    if ~isempty(trim_bndry{ii})

        xy_bndbox_ind=find_indices_variable('xy_bndbox',matr_names,matr_fields);
        bw_ind=xy_bndbox_ind(2);
        dur_ind=xy_bndbox_ind(2)-1;
        inds_xy_wcentrd=find_indices_variable('xy_wcentrd',matr_names,matr_fields);
        pf_ind=inds_xy_wcentrd(2);

        if (trim_matr(ii,bw_ind)>=2)&&(trim_matr(ii,dur_ind)>=0.5)
            tmp = zeros(nr,nc);
            tmp(trim_rgn{ii}) = 1;
            bndry_rc = bwboundaries(tmp,'noholes');
            plot(x_bs(bndry_rc{1}(:,2)),y_bs(bndry_rc{1}(:,1)),'w','LineWidth',3);
            plot(x_bs(bndry_rc{1}(:,2)),y_bs(bndry_rc{1}(:,1)),'k','LineWidth',2);
        end
    end
end

set(gca,'xtick',[],'ytick',[]);

%% 3d peak
figure;
ax_3dpeak=figdesign(1,2);

% axis for baseline subtracted spectrogram
axes(ax_3dpeak(1));
imagesc(x_bs,y_bs,data_bsspect);
xlim(fifteen_sec_bounds);
axis xy;
caxis([-7 90]);
colormap(rainbow4);
ylim([0 40]);

set(gca,'xtick',[],'ytick',[]);
set(gca,'xticklabel',[]);
xlim(peak_3d_xlim);
ylim(peak_3d_ylim);
axis square;
axis off;

hold on
for ii = 2012
    if ~isempty(trim_bndry{ii})

        xy_bndbox_ind=find_indices_variable('xy_bndbox',matr_names,matr_fields);
        bw_ind=xy_bndbox_ind(2);
        dur_ind=xy_bndbox_ind(2)-1;
        inds_xy_wcentrd=find_indices_variable('xy_wcentrd',matr_names,matr_fields);
        pf_ind=inds_xy_wcentrd(2);

        xvals=x_bs(bndry_rc{1}(:,2));
        yvals=y_bs(bndry_rc{1}(:,1));

        if (trim_matr(ii,bw_ind)>=2)&&(trim_matr(ii,dur_ind)>=0.5)
            tmp = zeros(nr,nc);
            tmp(trim_rgn{ii}) = 1;
            bndry_rc = bwboundaries(tmp,'noholes');
            if (min(xvals)>=21289 & max(xvals)<=21291 &  min(yvals)>=9 & max(yvals)<=17)
                plot(xvals,yvals,'w','LineWidth',3);
                plot(xvals,yvals,'m','LineWidth',2);
            end
        end
    end
end


plot(trim_matr(ii,pf_ind-1),trim_matr(ii,pf_ind),'wo');

% 3d surface view of baseline subtracted segment
axes(ax_3dpeak(2));
cla
az_3dpeak = 55.2; el_3dpeak= 22.8;
az_3dpeak = 60; el_3dpeak = 34.8;
surface(tgrid_int,fgrid_int,surface_sspect_int,'edgecolor','none');
colormap(jet(20148));

caxis([-7 90]);

view([az_3dpeak,el]);
set(gca,'xtick',[],'ytick',[],'ztick',[]);
axis off;
zlim([0 420])
xlim(peak_3d_xlim);
ylim(peak_3d_ylim);
axis square;
linkaxes([ax_3dpeak(1) ax_3dpeak(2)],'xy');

shading interp;
material dull;
camlight left;
camlight left;
camlight left;

hold on;
for ii = 2012
    if ~isempty(trim_bndry{ii})

        % filter peaks that have bw 2 to 15, duration 0.5 to 5 and frequency 5 to infinity.
        xy_bndbox_ind=find_indices_variable('xy_bndbox',matr_names,matr_fields);
        bw_ind=xy_bndbox_ind(2);
        dur_ind=xy_bndbox_ind(2)-1;
        inds_xy_wcentrd=find_indices_variable('xy_wcentrd',matr_names,matr_fields);
        pf_ind=inds_xy_wcentrd(2);

        if (trim_matr(ii,bw_ind)>=2)&&(trim_matr(ii,dur_ind)>=0.5)
            % plot them
            tmp = zeros(nr,nc);
            tmp(trim_rgn{ii}) = 1;

            bndry_rc = bwboundaries(tmp,'noholes');


            xvals=x_bs(bndry_rc{1}(:,2));
            yvals=y_bs(bndry_rc{1}(:,1));

            [~,xinds]=findclosest(surface_time, xvals);

            [~,yinds]=findclosest(surface_freq,yvals);

            zvals=zeros(size(xvals));
            for jj=1:length(xinds)
                zvals(jj)=surface_sspect(yinds(jj),xinds(jj))+10;
            end
            plot3(xvals,yvals,min(zvals)*ones(size(xvals)),'m','LineWidth',3);
        end
    end
end

%%
function[inds_var] = find_indices_variable(variable_name,matr_names,matr_fields)
% function to find the start and index of the columns corresponding to a
% particular variable

% find the index of the variable name in matr_names
ind_var_matr_names=find(strcmp(variable_name,matr_names));

% cumsum the matr_fields to the end index of each of the variables in the
% columns of peaks_matr. The start index will be the previous value in the
% cumsum array+1
matr_fields_cumsum=cumsum(matr_fields);

if ((ind_var_matr_names)~=1)
    inds_var=[matr_fields_cumsum(ind_var_matr_names-1)+1,...
        matr_fields_cumsum(ind_var_matr_names)];
else
    inds_var=[1,1];
end
end


