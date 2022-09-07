function plotStageSOPowerSlices(hist_sopow,time_in_bins,freq_bins,half_width,stage_props,stages)

if nargin < 7
    stages = [];
end

if isempty(stages)
    stages = {'N3','N2','N1','REM','Wake'};
end

figure;
hold all;
for ss = 1:size(stage_props,1)
    [~,idx_max_prop] = max(stage_props(ss,:));
    tmp_slice = hist_sopow(:,idx_max_prop)*time_in_bins(idx_max_prop);
    for ii = 1:half_width
        if idx_max_prop-ii >= 1
            tmp_slice = tmp_slice + hist_sopow(:,idx_max_prop-ii)*time_in_bins(idx_max_prop-ii);
        end
        if idx_max_prop+ii <= size(hist_sopow,2)
            tmp_slice = tmp_slice + hist_sopow(:,idx_max_prop+ii)*time_in_bins(idx_max_prop+ii);
        end
    end
    plot(freq_bins,tmp_slice);
end
legend(stages);
