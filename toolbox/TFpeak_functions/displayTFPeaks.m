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
%       data_time_range:    [1xn] double - timeseries data in time_range
%       t_time_range:       [1xn] double - timestamps for data in time_range
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

addOptional(p, 'data_time_range', [], @(x) validateattributes(x, {'numeric'}, {'real','2d'}));
addOptional(p, 't_time_range', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addOptional(p, 'artifacts', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));

addOptional(p, 'stage_times', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nondecreasing','2d'}));
addOptional(p, 'stage_vals', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nonnegative','2d'}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

%% Create figure
fh = figure;

if ~isempty(data_time_range) && ~isempty(t_time_range)
    hypn_spect_ax = figdesign(6, 1, 'PaperType', 'usletter', 'orient', 'landscape' , 'margins', [0.067917 0.05 0.083427 0.0456 0.08 0.0021714], 'merge', {[2 3 4 5]}, 'Position', [0.14041 0.19722 0.70262 0.61597]);
else
    hypn_spect_ax = figdesign(6, 1, 'PaperType', 'usletter', 'orient', 'landscape' , 'margins', [0.067917 0.05 0.083427 0.0456 0.08 0.0021714], 'merge', {[2 3 4 5 6]}, 'Position', [0.14041 0.19722 0.70262 0.61597]);
end

%% Plot hypnogram
if isgraphics(hypn_spect_ax(1))
    axes(hypn_spect_ax(1));
    hypnoplot(stage_times/3600, stage_vals, 'Artifacts', artifacts, 'ArtifactTimes', t_time_range/3600, 'TimesUnit', 'hours');
    th(1) = title('EEG Spectrogram and Detected TF-peaks');
    set(hypn_spect_ax(1), 'XTick', []);
end

%% Plot spectrogram
axes(hypn_spect_ax(2))
imagesc(stimes/3600, sfreqs, pow2db(spect));
axis xy
colormap(hypn_spect_ax(2), rainbow4);
climscale;

c = colorbar_noresize; % set colobar
c.Label.String = 'PSD (dB)'; % colobar label
c.Label.Rotation = -90; % rotate colorbar label
c.Label.VerticalAlignment = "bottom";

ylabel('Frequency (Hz)');

if ~isgraphics(hypn_spect_ax(1))
    th(1) = title('EEG Spectrogram and Detected TF-peaks');
end

if length(hypn_spect_ax) > 2 && isgraphics(hypn_spect_ax(3))
    set(hypn_spect_ax(2), 'XtickLabel', []);
end

% overlay TF-peak boundaries on the spectrogram
bd = stats_table.Boundaries;
hold on;
for ii = 1:length(bd)
    plot(bd{ii}(:, 1)/3600, bd{ii}(:, 2), 'w', 'LineWidth', 2)
end

%% Plot EEG trace
if length(hypn_spect_ax) > 2 && isgraphics(hypn_spect_ax(3))
    axes(hypn_spect_ax(3))
    plot(t_time_range/3600, data_time_range, 'linewidth', 1)
    min_trace = prctile(data_time_range, 1);
    max_trace = prctile(data_time_range, 99);
    ylim([min_trace-(0.1*abs(min_trace)), max_trace+(0.1*abs(max_trace))])
    set(hypn_spect_ax(3), 'YTick', [round(min_trace, 2, 'significant') 0 round(max_trace, 2, 'significant')]);
    set(hypn_spect_ax(3), 'YTickLabel', num2str(get(hypn_spect_ax(3),'ytick')','%.1f'));
    ylabel('Voltage (\muV)');
end
xlabel('Time (hr)')

%% Additional axes adjustments
hypn_spect_ax = hypn_spect_ax(isgraphics(hypn_spect_ax));
linkaxes(hypn_spect_ax, 'x');
xlim([min(stimes)/3600, max(stimes)/3600])
set(hypn_spect_ax, 'FontSize', 10)
if exist('th', 'var')
    set(th, 'FontSize', 15)
end

scrollzoompan;
