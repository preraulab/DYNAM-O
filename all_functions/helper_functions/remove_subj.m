function [SOpow_data, SOpow_prop_data, SOpow_time_data, SOphase_data, SOphase_prop_data, SOphase_time_data] = ...
            remove_subj(SOpow_data, SOpow_prop_data, SOpow_time_data, SOphase_data, SOphase_prop_data, SOphase_time_data, ...
            elect_inds, subj_inds)
% Remove both nights of SOpow/phase data for selected subjects/electrodes
%
%   Inputs:
%       SOpow_data: cell array - each cell is an electrode with a 5D double inside: 
%                   [SOpow, freq, subj, night, stage] representing SOpower
%                   histogram data for each subj/night/stage
%       SOpow_prop_data: cell array - each cell is an electrode with a 4D
%                        double inside: [SOpow, subj, night, stage] representing proportion
%                        of time in each SOpow bin for each subj/night/stage
%       SOpow_time_data: cell array - each cell is an electrode with a 4D
%                        double inside: [SOpow, subj, night, stage]
%                        representing time in each SOpow bin for each subj/night/stage
%       SOphase_data: cell array - each cell is an electrodec with a 5D double inside: 
%                   [SOphase, freq, subj, night, elect] representing SOpower
%                   histogram data for each subj/night/stage 
%       SOphase_prop_data: cell array - each cell is an electrode with a 4D
%                        double inside: [SOphase, subj, night, stage] representing proportion
%                        of time in each SOphase bin for each subj/night/stage
%       SOphase_time_data: cell array - each cell is an electrode with a 4D
%                        double inside: [SOphase, subj, night, stage] representing proportion
%                        of time in each SOphase bin for each subj/night/stage
%       elect_inds: 1D double - indices of electrode(s)
%       subj_inds: 1D double - indices of subject(s)
%       
%   Outputs:
%       SOpow_data: Same as input with nans replacing data for selected subjs/elects
%       SOpow_prop_data: Same as input with nans replacing data for selected subjs/elects
%       SOpow_time_data: Same as input with nans replacing data for selected subjs/elects
%       SOphase_data: Same as input with nans replacing data for selected subjs/elects
%       SOphase_prop_data: Same as input with nans replacing data for selected subjs/elects
%       Sophase_time_data: Same as input with nans replacing data for selected subjs/elects
%
%

assert((length(elect_inds) == length(subj_inds)), 'elect_inds and subj_inds must be the same length');

num_remove = length(elect_inds);

for ii = 1:num_remove
    SOphase_data{elect_inds(ii)}(:, :, subj_inds(ii),:, :) = nan;
    SOphase_prop_data{elect_inds(ii)}(: , subj_inds(ii), :, :) = nan;
    SOphase_time_data{elect_inds(ii)}(: , subj_inds(ii), :, :) = nan;
    SOpow_data{elect_inds(ii)}(:, :, subj_inds(ii), :, :) = nan;
    SOpow_prop_data{elect_inds(ii)}(: , subj_inds(ii), :, :) = nan;
    SOpow_time_data{elect_inds(ii)}(: , subj_inds(ii), :, :) = nan;
end

end

