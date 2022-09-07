%%% Plots peak detection merge method for real data example

%clear;

if exist('/data/preraugp/','dir')
    sys_name = '/data';
else
    sys_name='/eris';
end

% Add paths to access required functions
addpath([sys_name,'/preraugp/code/multitaper']);
addpath([sys_name,'/preraugp/users/prath/projects/EDF_Deidentification']);
addpath([sys_name '/preraugp/archive/Lunesta Study/sleep_stages/']); % add path to the sleep stage text files
addpath([sys_name,'/preraugp/projects/spindle_detection/code/wshed/']);
addpath([sys_name, '/preraugp/users/prath/projects/Spindle Detection/code/Exploratory_Analysis/main_code/export_fig_func/']);

% Build file path
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

t_bounds = [21280 21295]; %Lun20 magnified spectrogram region

% Set Spectrogram parameters
frequency_max = 40;
taper_params = [2, 3];
window_params = [1, .05];
min_NFFT = 2^10;
ploton = false;

% Set Parameters for watershed and stats
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
merge_rule = 'absolute';%
max_merges = inf;       % Maximum number of merges
max_area = 487900;      % Maximum area of chunk
f_verb = 0;             % Flag for verbose
f_outputs = [1 1];      % Flag to compute full and/or trim outputs
f_disp = false;         % Flag for whether to plot

% Load edf
[hdr,shdr,sdata] = blockEdfLoad(ifile_w_path);
channels = {shdr.signal_labels};

chan_num = find(strcmp(channels, chan_name));
if ~isempty(chan_num)

    data_eeg = sdata{chan_num}'; %extract eeg data
    Fs = shdr(chan_num).samples_in_record / hdr.data_record_duration;

    % create a time vector
    t=0:1/Fs:(length(data_eeg)-1)/Fs;
    % parse the sleep stage data in the text file above
    disp('Parsing staging info...')
    all_staging_data=read_staging_data_lunesta(staging_file);
    % all_staging_data(1,:)=[];
    [raw_stages]= parse_staging_data_lunesta(all_staging_data,t);

    %** Compute spectrogram for full night **%
    frequency_range = [0 min([Fs/2, frequency_max])];
    [sspect, sstimes, ssfreqs] = multitaper_spectrogram(data_eeg,Fs,frequency_range,taper_params,window_params,min_NFFT,'off',[],ploton,false,true); % 1:round(size(data,2)/2)

    ifile_parsed = strsplit(ifile_w_path,'/'); % parse file path
    disp(['computing peak stats for ' ifile_parsed{end} ', ' chan_name '.']);

    % The 2d matrix to be analyzed
    pick_f = ssfreqs>=0 & ssfreqs<=max(ssfreqs);
    f1 = find(pick_f,1,'first');
    f2 = find(pick_f,1,'last');
    idx_f = f1:f2;

    pick_t = sstimes>=t_bounds(1) & sstimes<=t_bounds(2);
    t1 = find(pick_t,1,'first');
    t2 = find(pick_t,1,'last');
    idx_t = t1:t2;

    % set font size
    f_size=10;

    % x-axis
    x = sstimes(pick_t);
    % y-axis
    y = ssfreqs(pick_f);
    data_sspect = sspect(idx_t,idx_f)';

    % compute baseline on full night spectrogram
    sspect(sspect==0) = NaN;
    bl = prctile(sspect,bl_prc,1)'; %
    sspect(isnan(sspect)) = 0;

    %****
    %* Option to smooth baseline using a windowed average
    %****
    if (bl_sm_win > 1)
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
    sspect_bs = sspect./repmat(bl,1,length(sstimes))';

    % Subselect segment of baseline subtracted
    data_sspect_bs = sspect_bs(idx_t,idx_f)';

    % initial segmentation of spectrogram
    [rgn, rgn_lbls, Lborders, amatr] = peaksWShed(data_sspect_bs);
    rgn_init = rgn;
    bndry_init = Lborders;

    nr = length(y);
    nc = length(x);
    tmp_Ldata = cell2Ldata(rgn_init,[nr nc],bndry_init);
    RGB_init = label2rgb(tmp_Ldata, 'jet', 'w', 'shuffle');

    % half segmentation
    [rgn_half, bndry_half] = regionMergeByWeight(data_sspect_bs,rgn,rgn_lbls,Lborders,amatr,2*merge_thresh,max_merges,merge_rule,f_verb);
    tmp_Ldata = cell2Ldata(rgn_half,[nr nc],bndry_half);
    RGB2_half = label2rgb(tmp_Ldata, 'jet', 'w', 'shuffle');

    % full segmentation
    [rgn_full, bndry_full] = regionMergeByWeight(data_sspect_bs,rgn,rgn_lbls,Lborders,amatr,merge_thresh,max_merges,merge_rule,f_verb);

    tmp_Ldata = cell2Ldata(rgn_full,[nr nc],bndry_full);
    RGB2_final = label2rgb(tmp_Ldata, 'jet', 'w', 'shuffle');

    % trimming
    trim_shift = min(min(data_sspect_bs));
    [trim_rgn, trim_bndry] = trimRegionsWShed(data_sspect_bs, rgn_full, 0.8, trim_shift);
    tmp_Ldata = cell2Ldata(trim_rgn,[nr nc],trim_bndry);
    RGB2_trim = label2rgb(tmp_Ldata, 'jet', 'w', 'shuffle');

    % Get stats for trimmed regions
    [trim_matr, matr_names, matr_fields, trim_PixelIdxList,trim_PixelList, trim_PixelValues, ...
        trim_rgn,trim_bndry] = peaksWShedStats_LData(trim_rgn,trim_bndry,data_sspect_bs,x,y,1,conn);

    disp(['saving peak stats for ' ifile_parsed{end} ', ' chan_name]);
    disp(['done with peak stats for ' ifile_parsed{end} ', ' chan_name '.']);
else
    disp(['*** ' chan_name ' not available for ' ifile_parsed{end} '.' ]);
end


%% plotting
fh = figure;
axs = figdesign(16,2,'margin',[.05 .05 .05 .05 .01],'type','usletter','orient','portrait',...
    'merge',{[1:2:7],[9:2:15],[17:2:23],[25:2:31],[2:2:8],[10:2:16],[18:2:24],[26:2:32]});

% original spectrogram segment
axes(axs(1));
imagesc(x,y,pow2db(data_sspect));
axis xy;
climscale;
colormap(jet(1024));
caxis([-19.7366 13.6733]);

ylabel('Frequency (Hertz)');
ax=gca;
ax.FontSize=f_size;
set(ax,'XTickLabel',[]);

% plot baseline subtracted spectrogram segment
axes(axs(3));
imagesc(x,y,(data_sspect_bs));
axis xy;
colormap(jet(1024));
caxis([-7 90]);

ylabel('Frequency (Hertz)');
ax=gca;
ax.FontSize=f_size;
set(ax,'XTickLabel',[]);

% plot initial segmentation
axes(axs(2));
imagesc(x,y,RGB_init);
axis xy;

ax=gca;
ax.FontSize=f_size;

% plot boundaries as black and white lines
hold on;
for ii = 1:length(bndry_init)
    if ~isempty(bndry_init{ii})
        tmp = zeros(nr,nc);
        tmp(rgn_init{ii}) = 1;
        bndry_rc = bwboundaries(tmp,'noholes');
        plot(x(bndry_rc{1}(:,2)),y(bndry_rc{1}(:,1)),'k');
    end
end
set(ax, 'YTickLabel',[], 'XTickLabel',[]);


% plot half segmentation
axes(axs(4));
imagesc(x,y,RGB2_half);
axis xy;
[~,scalelabel_x]=scaleline(gca,5,'5 seconds');
scalelabel_x.FontSize=f_size;

ax=gca;
ax.FontSize=f_size;

% plot boundaries as black and white lines
hold on;
for ii = 1:length(bndry_half)
    if ~isempty(bndry_half{ii})
        tmp = zeros(nr,nc);
        tmp(rgn_half{ii}) = 1;
        bndry_rc = bwboundaries(tmp,'noholes');
        plot(x(bndry_rc{1}(:,2)),y(bndry_rc{1}(:,1)),'k');
    end
end
set(ax, 'YTickLabel',[], 'XTickLabel',[])


% Plot full segmentation
axes(axs(6));

% plot as regions
imagesc(x,y,RGB2_final);
axis xy;

ax=gca;
ax.FontSize=f_size;
set(ax, 'YTickLabel',[], 'XTickLabel',[])

% plot boundaries as black and white lines
hold on;
for ii = 1:length(bndry_full)
    if ~isempty(bndry_full{ii})
        tmp = zeros(nr,nc);
        tmp(rgn_full{ii}) = 1;
        bndry_rc = bwboundaries(tmp,'noholes');
        plot(x(bndry_rc{1}(:,2)),y(bndry_rc{1}(:,1)),'k');
    end
end

% Plot trimming
axes(axs(8));
imagesc(x,y,RGB2_trim);
axis xy;
[~,scalelabel_x]=scaleline(gca,5,'5 seconds');
scalelabel_x.FontSize=f_size;
ax=gca;
ax.FontSize=f_size;
set(ax, 'YTickLabel',[], 'XTickLabel',[])

% plot picked peaks as black boundaries
hold on;
for ii = 1:length(trim_bndry)
    if ~isempty(trim_bndry{ii})

        % filter peaks that have bw > 2 and duration > 0.5
        xy_bndbox_ind=find_indices_variable('xy_bndbox',matr_names,matr_fields);
        bw_ind=xy_bndbox_ind(2);
        dur_ind=xy_bndbox_ind(2)-1;
        inds_xy_wcentrd=find_indices_variable('xy_wcentrd',matr_names,matr_fields);
        pf_ind=inds_xy_wcentrd(2);

        tmp = zeros(nr,nc);
        tmp(trim_rgn{ii}) = 1;
        bndry_rc = bwboundaries(tmp,'noholes');

        if (trim_matr(ii,bw_ind)<2)||(trim_matr(ii,dur_ind)<0.5)
            plot(x(bndry_rc{1}(:,2)),y(bndry_rc{1}(:,1)),'Color',[.7 .7 .7]);
        end
    end
end

% plot unpicked peaks with grey boundaries
for ii = 1:length(trim_bndry)
    if ~isempty(trim_bndry{ii})
        % filter peaks that have bw > 2 and duration > 0.5 to infinity.
        xy_bndbox_ind=find_indices_variable('xy_bndbox',matr_names,matr_fields);
        bw_ind=xy_bndbox_ind(2);
        dur_ind=xy_bndbox_ind(2)-1;
        inds_xy_wcentrd=find_indices_variable('xy_wcentrd',matr_names,matr_fields);
        pf_ind=inds_xy_wcentrd(2);

        tmp = zeros(nr,nc);
        tmp(trim_rgn{ii}) = 1;
        bndry_rc = bwboundaries(tmp,'noholes');

        if (trim_matr(ii,bw_ind)>=2)&&(trim_matr(ii,dur_ind)>=0.5)
            plot(x(bndry_rc{1}(:,2)),y(bndry_rc{1}(:,1)),'k','LineWidth',2);
        end
    end
end


% plot trim overlay on baseline subtracted segment
axes(axs(5));
imagesc(x,y,(data_sspect_bs));
axis xy;
colormap(jet(1024));
caxis([-7 90]);

ax=gca;
ax.FontSize=f_size;
set(ax, 'XTickLabel',[])
ylabel('Frequency (Hertz)');

hold on;
for ii = 1:length(trim_bndry)
    if ~isempty(trim_bndry{ii})
        % filter peaks that have bw > 2 and duration > 0.5 to infinity.
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
            plot(x(bndry_rc{1}(:,2)),y(bndry_rc{1}(:,1)),'w','LineWidth',3);
            plot(x(bndry_rc{1}(:,2)),y(bndry_rc{1}(:,1)),'k','LineWidth',2);

        end
    end
end

% Plot trim overlay on original segment
axes(axs(7));
imagesc(x,y,pow2db(data_sspect));
axis xy;
climscale;
colormap(jet);
caxis([-19.7366 13.6733]);

[~,scalelabel_x]=scaleline(gca,5,'5 seconds');
scalelabel_x.FontSize=f_size;
ax=gca;
ax.FontSize=f_size;
ylabel('Frequency (Hertz)');

hold on;
for ii = 1:length(trim_bndry)
    if ~isempty(trim_bndry{ii})

        % filter peaks that have bw 2 to 15, duration 0.5 to 5 and frequency 5 to infinity.
        xy_bndbox_ind=find_indices_variable('xy_bndbox',matr_names,matr_fields);
        bw_ind=xy_bndbox_ind(2);
        dur_ind=xy_bndbox_ind(2)-1;
        inds_xy_wcentrd=find_indices_variable('xy_wcentrd',matr_names,matr_fields);
        pf_ind=inds_xy_wcentrd(2);

        if (trim_matr(ii,bw_ind)>=2)&&(trim_matr(ii,dur_ind)>=0.5)
            tmp = zeros(nr,nc);
            tmp(trim_rgn{ii}) = 1;
            bndry_rc = bwboundaries(tmp,'noholes');
            plot(x(bndry_rc{1}(:,2)),y(bndry_rc{1}(:,1)),'w','LineWidth',3);
            plot(x(bndry_rc{1}(:,2)),y(bndry_rc{1}(:,1)),'k','LineWidth',2);
        end
    end
end

%% Print if selected
if print_png
    print(fh,'-dpng', '-r600',fullfile( fsave_path, 'PNG','merge_steps_summary.png'));
end

if print_eps
    print(fh,'-depsc', fullfile(fsave_path, 'EPS', 'merge_steps_summary.eps'));
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


