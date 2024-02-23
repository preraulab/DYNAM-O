function [ freq_TFpeaks ] = extract_freq_clusters(freq_TFpeaks, sel_freqs)
%Identify indices of TFpeaks falling within the extent of each cluster

for ii = 1:size(freq_TFpeaks,1)
    low_bound = freq_TFpeaks.peak_lower_freq(ii) - (freq_TFpeaks.peak_upper_freq(ii) - freq_TFpeaks.peak_lower_freq(ii))/2;
    low_bound = max(freq_TFpeaks.boundary_from_lastpeak(ii), low_bound);
    
    high_bound = freq_TFpeaks.peak_upper_freq(ii) + (freq_TFpeaks.peak_upper_freq(ii) - freq_TFpeaks.peak_lower_freq(ii))/2;
    if ii ~= size(freq_TFpeaks,1)
        high_bound = min(freq_TFpeaks.boundary_from_lastpeak(ii+1), high_bound);
    end
    
    % identify the indices 
    peak_indices = sel_freqs >= low_bound & sel_freqs <= high_bound;
    freq_TFpeaks.TFpeak_idx(ii) = {peak_indices};
end

