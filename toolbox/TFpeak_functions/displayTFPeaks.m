function [fh] = displayTFPeaks(varargin)
%DISPLAYTFPEAKS  Display TF peaks detected by computeTFPeaks() on a spectrogram
%
%   Usage:
%       [fh] = displayTFPeaks(stats_table, spect, stimes, sfreqs)
%
%   Inputs:
%       stats_table:        table - features of each TFpeak
%       spect:              2D double - spectrogram of data
%       stimes:             1D double - timestamp bin center values for dimension 2 of spect
%       sfreqs:             1D double - frequency bin center values for dimension 1 of spect
%
%   Optional inputs:
%       data:               1xN double - timeseries data
%       t:                  1xN double - timestamps for data (seconds). If
%                                        omitted and Fs is supplied, t is
%                                        generated as (0:N-1)/Fs starting at 0.
%       Fs:                 scalar - sampling rate (Hz) for `data`. Used to
%                                    construct t when t is not provided.
%       artifacts:          1xT logical of times flagged as artifacts (logical OR of hf and bb artifacts)
%       stage_times:        [1x<number of stages>] vector - times of sleep stages in seconds
%       stage_vals:         [1x<number of stages>] - values of sleep stages
%
%   Output:
%       fh:                 figure handle
%
%
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
%   GITHUB     https://github.com
%
%   ATTRIBUTION
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
%%
p = inputParser;

addRequired(p, 'stats_table', @(x) validateattributes(x, {'table'}, {'real','nonempty','2d'}));
addRequired(p, 'spect', @(x) validateattributes(x, {'numeric'}, {'real','2d'}));
addRequired(p, 'stimes', @(x) validateattributes(x, {'numeric'}, {'real','finite','nondecreasing','vector'}));
addRequired(p, 'sfreqs', @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector'}));

addOptional(p, 'data', [], @(x) validateattributes(x, {'numeric'}, {'real','2d'}));
addOptional(p, 't', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addOptional(p, 'Fs', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','scalar'}));
addOptional(p, 'artifacts', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));

addOptional(p, 'stage_times', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nondecreasing','2d'}));
addOptional(p, 'stage_vals', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nonnegative','2d'}));

parse(p,varargin{:});
stats_table = p.Results.stats_table;
spect       = p.Results.spect;
stimes      = p.Results.stimes;
sfreqs      = p.Results.sfreqs;
data        = p.Results.data;
t           = p.Results.t;
Fs          = p.Results.Fs;
artifacts   = p.Results.artifacts;
stage_times = p.Results.stage_times;
stage_vals  = p.Results.stage_vals;

%% Build t from Fs if needed
if ~isempty(data) && isempty(t) && ~isempty(Fs)
    t = (0:numel(data)-1) / Fs;
end

need_hyp = ~isempty(stage_times) && ~isempty(stage_vals);
need_eeg = ~isempty(data) && ~isempty(t);

%% Create figure with full-size base axis, then split as needed
fh = figure;
base_ax = figdesign(1, 1, 'PaperType', 'usletter', 'orient', 'landscape', ...
    'margins', [0.067917 0.1 0.083427 0.1 0.08 0.05], ...
    'Position', [0.14041 0.19722 0.70262 0.61597]);

hyp_ax   = gobjects(0);
spect_ax = gobjects(0);
eeg_ax   = gobjects(0);

if need_hyp && need_eeg
    sub = split_axis(base_ax, [0.1 0.7 0.2], 1);
    hyp_ax   = sub(1);
    spect_ax = sub(2);
    eeg_ax   = sub(3);
elseif need_hyp
    sub = split_axis(base_ax, [0.2 0.8], 1);
    hyp_ax   = sub(1);
    spect_ax = sub(2);
elseif need_eeg
    sub = split_axis(base_ax, [0.8 0.2], 1);
    spect_ax = sub(1);
    eeg_ax   = sub(2);
else
    spect_ax = base_ax;
end

%% Plot hypnogram
if need_hyp
    axes(hyp_ax);
    hypnoplot(stage_times/3600, stage_vals, 'Artifacts', artifacts, ...
        'ArtifactTimes', t/3600, 'TimesUnit', 'hours');
    th = title('EEG Spectrogram and Detected TF-peaks');
    set(hyp_ax, 'XTick', []);
end

%% Plot spectrogram
axes(spect_ax)
imagesc(stimes/3600, sfreqs, pow2db(spect));
axis xy
colormap(spect_ax, rainbow4);
climscale;

c = colorbar_noresize;
c.Label.String = 'PSD (dB)';
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";

ylabel('Frequency (Hz)');

if ~need_hyp
    th = title('EEG Spectrogram and Detected TF-peaks');
end

if need_eeg
    set(spect_ax, 'XTickLabel', []);
end

% overlay TF-peak boundaries on the spectrogram
bd = stats_table.Boundaries;
hold on;
for ii = 1:length(bd)
    plot(bd{ii}(:, 1)/3600, bd{ii}(:, 2), 'w', 'LineWidth', 2)
end

%% Plot EEG trace
if need_eeg
    % Remove the lowest tick on the spectrogram axis to avoid overlapping tick labels
    yt = get(spect_ax, 'YTick');
    set(spect_ax, 'YTick', yt(yt > yt(1)));

    axes(eeg_ax)
    plot(t/3600, data, 'linewidth', 1)
    min_trace = prctile(data, 1);
    max_trace = prctile(data, 99);
    ylim([min_trace-(0.1*abs(min_trace)), max_trace+(0.1*abs(max_trace))])
    set(eeg_ax, 'YTick', [round(min_trace, 2, 'significant') 0 round(max_trace, 2, 'significant')]);
    set(eeg_ax, 'YTickLabel', num2str(get(eeg_ax,'ytick')','%.1f'));
    ylabel('Voltage (\muV)');
end
xlabel('Time (hr)')

%% Link x-axes for scrolling and final adjustments
all_ax = [hyp_ax spect_ax eeg_ax];
all_ax = all_ax(isgraphics(all_ax));
linkaxes(all_ax, 'x');
xlim(spect_ax, [min(stimes)/3600, max(stimes)/3600])
set(all_ax, 'FontSize', 16)
if exist('th', 'var')
    set(th, 'FontSize', 20)
end

scrollzoompan;
