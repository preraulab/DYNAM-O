% MUST USE vglrun matlab in order for scatter plot to work


% Modified:
% 20181212 - Changed to load from power histogram file and pass into the plotting.
ccc

base = '/data/preraugp/projects/transient_oscillations/transient_oscillations_original/code/';


%Grab all of the CSVs from the folder
path=fullfile(base,'/Lunesta histograms over time/All_channels_filtered_peaks'); %'/data/preraugp/projects/spindle_detection/code/Lunesta histograms over time';

addpath(base);

%Extract the different file properties from file names
d=dir(fullfile(path,'*.csv'));
fnames={d(:).name};

for ii=1:length(fnames)
    split_out=strsplit(fnames{ii},'_');
    subs{ii}=split_out{1};
    elecs{ii}=split_out{2};
    ngts{ii}=split_out{3};
end

%Get all the unique subjects, electrodes, and nights
subjects=unique(subs);
electrodes=unique(elecs);
nights=unique(ngts);

ipath_hist_power = fullfile(base,'Lunesta histograms over time/electrode_hists_SW_power_dB_percentLightsOutNoArtifact_compChans_20181207_checkMismatchWithNewCount.mat'); 

%%
%Define results folder for figures
results_folder = fullfile(base,'/results/lunesta/figures/peak_histogram_visualization/');

for night_idx = 2%1:length(nights)
    night=nights{night_idx};
    
    for subject_idx = 2%1 : 17%length(subjects)
        subject=subjects{subject_idx};
        
        
        for electrode_idx = 1 %: length(electrodes)
            electrode = electrodes{electrode_idx};
            
            disp(['generating figure for ',subject,'_',electrode,'_',night]);
            
            if exist(fullfile(path,[subject '_' electrode '_' night '_filtered_peak_table.csv']),'file')
                
                [eeg_channel_data, stage_struct, Fs, peak_data] = lunesta_load_from_meta(subject, night, electrode);
                
                load(ipath_hist_power,'electrode_hists','SWF_bins','freqs','electrode_time_in_bin','electrode_stage_prop');
                
                figh=peak_dynamics_summary(eeg_channel_data, stage_struct, Fs, peak_data, electrode_hists{electrode_idx}(:,:,subject_idx),...
                    SWF_bins, freqs, electrode_stage_prop{electrode_idx}(:,:,subject_idx));
                
                
%                 peak_dynamics_summary(eeg_data, stage_struct, Fs, peak_data, SWP_hists, SWP_bins, SWP_freqs, stage_prop)
                
                %                 suptitle([subject '-' night '-' electrode]);
                
                %             save_filename = [subject,'_',night,'_',electrode,'.eps'];
                %             saveas(figh,[results_folder,save_filename])
                %         pause();
                %             close(figh);
                plotStageSOPowerSlices( electrode_hists{electrode_idx}(:,:,subject_idx)', electrode_time_in_bin{electrode_idx}(:,subject_idx), freqs, 1, electrode_stage_prop{electrode_idx}(:,:,subject_idx)');
            else
                disp([subject '_' electrode '_' night,' does not exist']);
            end
        end
    end
end