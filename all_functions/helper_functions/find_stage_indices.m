function[pick_stage,stage_on,stage_off]= find_stage_indices(peaks_times,stages,stage_nums)
%
%   Copyright 2022 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%      
%   Authors: Patrick Stokes

is_stage = stages.stage == stage_nums(1);
for jj = 2:length(stage_nums)
   is_stage = is_stage | stages.stage == stage_nums(jj); 
end

is_stage = is_stage & stages.pick_t';

stage_on = stages.time(find(diff([0;is_stage])==1));
stage_off = stages.time(find(diff([0;is_stage])==-1)-1);

if length(stage_off)==length(stage_on)-1
   stage_off = [stage_off, max(stages.time(is_stage))];
end

pick_stage = zeros(length(peaks_times),1);
for jj = 1:length(stage_on)
    pick_stage = pick_stage | (peaks_times > stage_on(jj) & peaks_times < stage_off(jj));
end

end