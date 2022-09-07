function[stage_time]= findStageTotalTime_Lunesta(stages,stage_nums,Fs)

% % Function to find the total time in a particular sleep stage

% extract all the indices of stages as defined by user
stage = stages.stage;
is_stage = false(size(stage));

for ii = 1 : length (stage_nums)
        is_stage = is_stage|stage==stage_nums(ii);
end
% sum all the binary indices and divide by Fs 

stage_time = sum(is_stage)./Fs; 
end