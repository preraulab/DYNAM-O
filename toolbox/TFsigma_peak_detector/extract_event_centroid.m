function [ event_center_time, event_center_frequency ] = extract_event_centroid(mt_spect, tpeak_properties, signal_idx)
%EXTRACT_EVENT_CENTROID  Compute centroid of 2D spectrogram to define center time and frequency of TF peak events
%
%   Usage:
%       [event_center_time, event_center_frequency] = extract_event_centroid(mt_spect, tpeak_properties, signal_idx)
%
%   Inputs:
%       mt_spect:           struct - multitaper spectrogram with fields:
%                             .stimes: [1xT] double - time axis (s)
%                             .spect:  [TxF] double - spectrogram power matrix
%                             .sfreqs: [1xF] double - frequency axis (Hz)
%       tpeak_properties:   struct - TF peak properties with fields:
%                             .times: [Px2] double - [start, end] times for each peak (s)
%                             .bandwidth_bounds: [Px2] double - [low, high] frequency bounds (Hz)
%       signal_idx:         [1xP] logical - index of peaks to process (default: all true)
%
%   Outputs:
%       event_center_time:      [1xP] double - centroid time for each TF peak event (s)
%       event_center_frequency: [1xP] double - centroid frequency for each TF peak event (Hz)
%
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://harvard.edu
%   GITHUB     https://github.com
%
%   CITATION
%   If you use this toolbox, please cite:
%
%   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
if nargin < 3 || isempty(signal_idx)
    signal_idx = true(size(tpeak_properties.times, 1), 1);
end

assert(size(tpeak_properties.times, 1) == size(tpeak_properties.bandwidth_bounds, 1), 'Incorrect length of tpeak_properties.')
assert(size(tpeak_properties.times, 2) == 2, 'tpeak_properties.times is not two columns.')
assert(size(tpeak_properties.bandwidth_bounds, 2) == 2, 'tpeak_properties.bandwidth_bounds is not two columns.')

% set up the parameters
stimes = mt_spect.stimes;
spect = mt_spect.spect;
sfreqs = mt_spect.sfreqs;

% plot spectrogram - debugging only
% H = figure;
% imagesc(stimes, sfreqs, nanpow2db(spect'))
% axis xy;
% colormap jet;
% climscale;
% title('Spectrogram');
% xlabel('Time (sec)');
% ylabel('Frequency (Hz)');
% set(gca, 'FontSize', 16)

% event onset offset times 
time_bounds = tpeak_properties.times(signal_idx, :);

% frequency start and end bounds 
freq_bounds = tpeak_properties.bandwidth_bounds(signal_idx, :);

% output space holder 
event_center_time = zeros(size(time_bounds,1), 1);
event_center_frequency = zeros(size(time_bounds,1), 1);

for ii = 1:size(time_bounds,1)
    t_start = time_bounds(ii,1);
    t_end = time_bounds(ii,2); %#ok<*PFBNS>
    f_start = freq_bounds(ii,1);
    f_end = freq_bounds(ii,2);
    
    % grab the 2D spectrogram 
    t_select = stimes >= t_start & stimes <= t_end;
    f_select = sfreqs >= f_start & sfreqs <= f_end;
    S = spect(t_select, f_select);
    t = stimes(t_select);
    f = sfreqs(f_select);
    
    % obtain the weighted centroid of the 2D spectrogram
    sizeS = size(S);
    In = cell(1,2);
    [In{:}] = ind2sub(sizeS, [1:prod(sizeS)]');
    cent_coord = sum([In{:}] .* S(:)) / sum(S(:));
    
    % convert to physical units and add to output variables
    if length(t) > 1
        event_center_time(ii) = interp1(1:length(t), t, cent_coord(1), 'linear');
    elseif length(t) == 1
        event_center_time(ii) = t;
    else
        event_center_time(ii) = nan;
    end
    
    if length(f) > 1
        event_center_frequency(ii) = interp1(1:length(f), f, cent_coord(2), 'linear');
    elseif length(f) == 1
        event_center_frequency(ii) = f;
    else
        event_center_frequency(ii) = nan;
    end
    
    % visualize for debugging
%     figure(H)
%     xlim([t_start-15, t_end+15])
%     pos = [ t_start, f_start, t_end-t_start, f_end-f_start ];
%     r = rectangle('Position', pos,'LineStyle',':','EdgeColor','k','LineWidth',2);
%     delete(r)

%     close_f = figure;
%     surf(t, f, S') % note that this is not in dB scale! 
%     xlabel('Time')
%     ylabel('Frequency')
%     close(close_f)

%     close_f = figure; 
%     surf(1:length(t), 1:length(f), S')
%     xlabel('Time')
%     ylabel('Frequency')
%     hold on
%     scatter3(t_coord, f_coord, 0, 'filled')
%     close(close_f)
      
%     close_f = figure;
%     surf(t, f, S') % note that this is not in dB scale! 
%     xlabel('Time')
%     ylabel('Frequency')
%     hold on
%     scatter3(cent_t, cent_f, 0, 'filled')
%     close(close_f)

end

end

