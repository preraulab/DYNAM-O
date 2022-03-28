function [SOpow_data, SOpow_prop_data, SOpow_time_data, SOphase_data, SOphase_prop_data, SOphase_time_data] = ...
            remove_subj(SOpow_data, SOpow_prop_data, SOpow_time_data, SOphase_data, SOphase_prop_data, SOphase_time_data, ...
            elect_inds, subj_inds)
%
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

