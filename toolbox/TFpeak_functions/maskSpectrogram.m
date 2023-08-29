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
mask_indices = cell(1, height(stats_table));

BoundingBox = stats_table.BoundingBox;
Boundaries = stats_table.Boundaries;

% Loop through existing TFpeak events
parfor ii = 1:height(stats_table)
    pos =  BoundingBox(ii,:);
    tmin = pos(1);
    fmin = pos(2);
    tmax = tmin+pos(3);
    fmax = fmin+pos(4);
    
    % Extract the BoundingBox region on spectrogram
    sfreqs_idx = find(sfreqs >= fmin & sfreqs <= fmax);
    stimes_idx = find(stimes >= tmin & stimes <= tmax);
    sfreqs_indices = repelem(sfreqs_idx, length(stimes_idx));
    stimes_indices = repmat(stimes_idx, 1, length(sfreqs_idx));
    
    if use_boundary
        % Use Boundaries for masking
        [in, on] = inpolygon(stimes(stimes_indices), sfreqs(sfreqs_indices), Boundaries{ii}(:,1), Boundaries{ii}(:,2));
        valid_idx = in | on;
        mask_idx = sub2ind(mask_size, sfreqs_indices(valid_idx), stimes_indices(valid_idx));
    else
        % Use BoundingBox for masking
        mask_idx = sub2ind(mask_size, sfreqs_indices, stimes_indices);
    end
    
    mask_indices{ii} = mask_idx;
end

mask(cat(2, mask_indices{:})) = true;
spect(~mask(:)) = nan;  % regions not within Boundaries are marked as NaN

end

