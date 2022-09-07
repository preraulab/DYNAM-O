function [raw_stages]= parse_staging_data_lunesta(all_staging_data,time_vector)
% function to parse the staging data and extract the sleep stage
% corresponding to each EEG time point

% get the sleep stages
raw_stages_str=all_staging_data(:,2);

% replace the stage groups as 1,2,3,4 and 5 corresponding to N3,N2,N1,REM
% and Wake
raw_stages_grouped=zeros(size(raw_stages_str));
raw_stages_grouped(strcmp(raw_stages_str,'MT')|(strcmp(raw_stages_str,'Wake')))=5;
raw_stages_grouped(strcmp(raw_stages_str,'S3'))=1;
raw_stages_grouped(strcmp(raw_stages_str,'S2'))=2;
raw_stages_grouped(strcmp(raw_stages_str,'S1'))=3;
raw_stages_grouped(strcmp(raw_stages_str,'REM'))=4;


% assign the sleep stage to each time point based on the duration of the
% sleep stage
stage_times_grouped=cell2mat(all_staging_data(:,[3,4]));
raw_stages=zeros(size(time_vector));

for ii=1:size(stage_times_grouped,1)
   stage_time_inds=(stage_times_grouped(ii,1)):(stage_times_grouped(ii,1)+stage_times_grouped(ii,2));
   raw_stages(1,stage_time_inds)=raw_stages_grouped(ii);   
end

% assume time points before 1st second are all wake
raw_stages(raw_stages==0)=5;