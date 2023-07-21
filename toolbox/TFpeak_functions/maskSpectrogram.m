function [ spect ] = maskSpectrogram(spect, stimes, sfreqs, stats_table, use_boundary)
% Mask spectrogram using existing TFpeaks

% Make sure BoundingBox properties is available
assert(any(contains(stats_table.Properties.VariableNames, 'BoundingBox')), 'BoundingBox property is not available.')
if use_boundary
    % Make sure Boundaries properties is available
    assert(any(contains(stats_table.Properties.VariableNames, 'Boundaries')), 'Boundaries property is not available.')
end
    
% Create a mask
mask = false(size(spect));
mask_size = size(mask);

% Loop through existing TFpeak events
for ii = 1:height(stats_table)
    pos =  stats_table.BoundingBox(ii,:);
    tmin = pos(1);
    fmin = pos(2);
    tmax = tmin+pos(3);
    fmax = fmin+pos(4);
    
    % Extract the BoundingBox region on spectrogram
    sfreqs_idx = find(sfreqs >= fmin & sfreqs <= fmax);
    stimes_idx = find(stimes >= tmin & stimes <= tmax);
    
    if use_boundary
        % Use the Boundaries for masking
        sfreqs_indices = repelem(sfreqs_idx, length(stimes_idx));
        stimes_indices = repmat(stimes_idx, 1, length(sfreqs_idx));
        [in, on] = inpolygon(stimes(stimes_indices), sfreqs(sfreqs_indices), stats_table.Boundaries{ii}(:,1), stats_table.Boundaries{ii}(:,2));
        valid_idx = in | on;
        mask(sub2ind(mask_size, sfreqs_indices(valid_idx), stimes_indices(valid_idx))) = true;
    else
        % Use the BoundingBox for masking
        mask(sfreqs_idx, stimes_idx) = true;
    end
end

spect(~mask(:)) = 0;

end

