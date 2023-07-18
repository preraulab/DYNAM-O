function [ stats_table ] = extractFrequency(stats_table, data, Fs, t)
% Use synchrosqueeze wavelet trasnform to extract frequency estimates for
% each TFpeak event contained in stats_table

% Make sure BoundingBox property is available
assert(any(contains(stats_table.Properties.VariableNames, 'BoundingBox')), 'BoundingBox property is not available.')

% Compute the wavelet SST
[sst, sst_freqs] = wsst(double(data), Fs, 'bump');

% Instantiate property variables
sst_moment = zeros(size(stats_table.PeakFrequency));
sst_max = zeros(size(stats_table.PeakFrequency));

% Extract frequencies for each detected TFpeak event
for ii = 1:height(stats_table)
    pos =  stats_table.BoundingBox(ii,:);
    tmin = pos(1);
    fmin = pos(2);
    tmax = tmin+pos(3);
    fmax = fmin+pos(4);
    
    % Extract the BoundingBox region on SST spectrum
    t_indices = t >= tmin & t <= tmax;
    f_indices = sst_freqs >= fmin & sst_freqs <= fmax;
    t_ii = t(t_indices);
    f_ii = sst_freqs(f_indices);
    sst_ii = abs(sst(f_indices, t_indices));
    
    % Extract the first spectral moment of the SST spectrum
    ifq = instfreq(sst_ii, f_ii, t_ii);
    sst_moment(ii) = nanmean(ifq);  % use the mean instantaneous frequency

    % Find the maximum at the time of the TFpeak PeakTime
    [~, t_idx] = min(abs(t_ii - stats_table.PeakTime(ii)));
    [~, f_idx] = max(sst_ii(:, t_idx));
    sst_max(ii) = f_ii(f_idx); 
end

% Add the two frequency estimates to stats_table
stats_table.PeakFrequency_sst_mean = sst_moment;
stats_table.Properties.VariableDescriptions{'PeakFrequency_sst_mean'} = 'Peak frequency based on the mean of instantaneous frequency on synchrosqueezed wavelet transform';
stats_table.Properties.VariableUnits{'PeakFrequency_sst_mean'} = 'Hz';

stats_table.PeakFrequency_sst_max = sst_max;
stats_table.Properties.VariableDescriptions{'PeakFrequency_sst_max'} = 'Peak frequency based on the max of synchrosqueezed wavelet transform at PeakTime';
stats_table.Properties.VariableUnits{'PeakFrequency_sst_max'} = 'Hz';

end

