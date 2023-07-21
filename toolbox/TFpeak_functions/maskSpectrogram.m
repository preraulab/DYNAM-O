function [ spect ] = maskSpectrogram(spect, stimes, sfreqs, stats_table)
% Mask spectrogram using BoundingBox of existing TFpeaks

% Make sure BoundingBox properties is available
assert(any(contains(stats_table.Properties.VariableNames, 'BoundingBox')), 'BoundingBox property is not available.')

% Create a mask
mask = false(size(spect));

% Loop through existing TFpeak events
for ii = 1:height(stats_table)
    pos =  stats_table.BoundingBox(ii,:);
    tmin = pos(1);
    fmin = pos(2);
    tmax = tmin+pos(3);
    fmax = fmin+pos(4);
    
    % Extract the BoundingBox region on spectrogram
    mask(sfreqs >= fmin & sfreqs <= fmax, stimes >= tmin & stimes <= tmax) = true;
end

spect(~mask(:)) = 0;

end

