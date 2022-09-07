function [eeg_channel_data, stage_struct, Fs, peak_data, peak_times] = lunesta_load_from_meta(subject_name, night, electrode_name)

if nargin==0
    electrode_name='F3';
    night=2;
end

%Get appropriate paths
% addpath('/data/preraugp/users/prath/projects/EDF_Deidentification'); % needed for blockEDFLoad
addpath('/data/preraugp/projects/transient_oscillations/transient_oscillations_original/code/plot_lunesta_hist_and_spect'); % needed for find_stage_indices

%Grab all of the CSVs from the folder
path = '/data/preraugp/projects/transient_oscillations/transient_oscillations_original/code/Lunesta histograms over time/All_channels_filtered_peaks'; %'/data/preraugp/projects/spindle_detection/code/Lunesta histograms over time';

%Extract the different file properties from file names
d = dir(fullfile(path,'*.csv'));
% fnames = string({d(:).name});
% file_parts = squeeze(split(fnames,'_'));
% 
% subjects = unique(file_parts(:,1));
% electrodes = unique(file_parts(:,2));
% nights = unique(file_parts(:,3));

fnames={d(:).name};

for ii=1:length(fnames)
    split_out=strsplit(fnames{ii},'_');
    subs{ii}=split_out{1};
    elecs{ii}=split_out{2};
    ngts{ii}=split_out{3};
end

subjects=unique(subs);
electrodes=unique(elecs);
nights=unique(ngts);

% Lunesta meta data for available/useable data
dir_edf = '/data/preraugp/archive/Lunesta Study/';
load([dir_edf 'meta.mat']);

%Check electrode name
if isnumeric(electrode_name)
    ee=electrode_name;s
    if ee>length(electrodes)
        error('Invalid electrode ID');
    end
else
    ee=find(strcmpi(electrodes,electrode_name));
    if isempty(ee)
        error('Invalid electrode name');
    end
end
electrode = char(electrodes(ee));

%Check night
if isempty(find(strcmp(num2str(night),nights)))
    error('Invalid night');
end

if ischar(night)
    night=str2double(night);
end

%Check subject name
if isnumeric(subject_name)
    ss=subject_name;
    if ss>length(subjects)
        error('Invalid subject ID');
    end
else
    ss=find(strcmpi(subjects,subject_name));
    if isempty(ss)
        error('Invalid electrode name');
    end
end
subject_name = subjects{ss};

disp(['*********' upper([ subject_name '_' electrode '_' num2str(night)]) '*********']);

%Load CSV for peak data
if nargout>3
    csv_fname = fullfile(path,['/' subject_name '_' electrode '_' num2str(night) '_filtered_peak_table.csv']);
    if ~exist(csv_fname,'file')
        error(['CSV file not found for ' subject_name]);
        peak_data=[];
        peak_times=[];
    else
        disp('     Loading peak data...');
        
        % DATA I/O Pre-Processing
        
        % Read in peak feature data from CSV
        peak_data = csvread(csv_fname,1,0);
        peak_times = peak_data(:,2);
    end
else
    peak_data=[];
    peak_times=[];
end

disp('     Loading EDF...');

% Check meta file for available EDF
pick_file = cellfun(@(x) ~isempty(x), strfind(edf_filenames,[subject_name '-Night' num2str(night)]));
pick_file = pick_file &  selected_edf_files;
if sum(pick_file)==1
    edf_fname = [dir_edf edf_filenames{pick_file}];
    if ~exist(edf_fname,'file')
        warning('EDF file not found, despite file match in edf_filenames from meta file.');
        edf_fname = [];
    end
elseif sum(pick_file)>0
    warning('Found more than one file match in edf_filenames from meta file.');
    edf_fname = [];
    
else
    warning('Did not find a file match in edf_filenames from meta file.');
    edf_fname = [];
end

if ~isempty(edf_fname)
    % Check meta file info if channel is available
    pick_channel = strcmpi(all_channels,electrode);
    if ~available_channels(pick_file,pick_channel)
        disp('Electrode not available for this subject-night.');
    else
        
        % Load edf data
        % [hdr, eegdata] = edfreader(edf_fname);
        [hdr,shdr,eeg_data] = blockEdfLoad(edf_fname);
        chan_labels = {shdr.signal_labels};
        
        
        % Find electrode index
        eind = find(strcmpi(chan_labels,electrode));
        
        % Check index was found
        if isempty(eind)
            warning('Electrode not found.');
        else
            
            % Check channel is not dead
            if ~any(eeg_data{eind}(:))
                warning([subject_name ' Night' num2str(night) ' ' electrode '  has no data!'])
            end
            
            Fs = hdr.samplingfrequency(eind);
            eeg_channel_data=eeg_data{eind}';
%             eeg_times=(0:length(eeg_channel_data)-1)/Fs;
        end
    end
end

disp('     Loading stages...');
%Handle stage selection
dir_stage = '/data/preraugp/archive/Lunesta Study/sleep_stages';
search_stage = [dir_stage,'/',subject_name,'-Night',num2str(night),'*.mat'];
d = dir(search_stage);

fname_stage = d(1).name;
load([dir_stage '/' fname_stage]);



