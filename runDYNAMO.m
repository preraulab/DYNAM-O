%RUNDYNAMO: Compute time-frequency peaks and SO-power/phase histograms
% This is an example pipeline of using the computeTFPeaks() and
% SOpowerphaseHistogram() functions together for studying sleep EEG. One
% can adapt this function for customized applications.
%
%   Usage:
%       [stats_table, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals, time_range, baseline_options, detection_options, SOPH_options, save_output_image, output_fname, verbose, plot_on)
%
%   Inputs:
%       data: <number of samples> x 1 vector - time series data -- required
%       Fs: double - sampling frequency in Hz -- required
%       stage_times: 1 x <number of stages> vector - times of sleep stages in seconds -- required
%       stage_vals: 1 x <number of stages> vector - values of sleep stages -- required
%
%   Optional inputs:
%       time_range: 1x2 vector - [<start time>, <end time>] in seconds (default: range of scored data)
%       baseline_options: structure - parameters for baseline algorithm (default: baseline_opts())
%       detection_options: structure - parameters for detection algorithm (default: detection_opts())
%       SOPH_options: structure - parameters for SO-power/phase histograms (default: SOpowerphasehist_opts())
%       stats_table: table - TF peak stats_table output from computeTFPeaks for direct computation of SOPH (default: [])
%       save_output_image: logical - flag to save the output image (default: false)
%       output_fname: char or string - filename for saving the output image (default: 'DYNAM-O_output')
%       verbose: logical - flag for verbose output (default: true)
%       plot_on: logical - flag to plot the results (default: true)
%
%   Outputs:
%       stats_table: table - table of computed time-frequency peaks
%       SOPHs: structure - structure containing SO-power/phase histograms
%
%   Running with no arguments calls the example data.
%       runDYNAMO();
%
%   Copyright 2024 Prerau Lab - http://www.sleepEEG.org
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%
%**********************************************************************

function [stats_table, SOPHs] = runDYNAMO(varargin)
%%%% Example script showing how to compute time-frequency peaks and SO-power/phase histograms
% Users are encouraged to edit this script and the data loading boilerplate
% in runExampleData() for their specific analysis. This script is provided
% only as a template for illustrative purposes on how to use various
% functions in DYNAM-O in tantem. It is not an official entry point
% function to use the DYNAM-O toolbox.

%% PATH SETTINGS
% Add necessary functions to path
addpath(genpath('./toolbox'))

%% PREPARE DATA
%Check for parallel toolbox
v = ver;
if any(strcmp({v.Name}, 'Parallel Computing Toolbox'))
    gcp;
end

%% ALGORITHM SETTINGS
if nargin == 0
    [stats_table, SOPHs] = runExampleData();
    return;
end

%% Parse inputs
p = inputParser;
p.KeepUnmatched=true;

addRequired(p, 'data', @(x) validateattributes(x, {'numeric'}, {'real','vector'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','scalar'}));
addRequired(p, 'stage_times', @(x) validateattributes(x, {'numeric'}, {'real','finite','nondecreasing','vector'}));
addRequired(p, 'stage_vals', @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector'}));
% section of EEG to use in analysis (seconds)
addOptional(p, 'time_range', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
% parameters managed using struct outputs from opts functions
addOptional(p, 'baseline_options', baseline_opts(), @(x) validateattributes(x, {'struct'}, {'nonempty'}));
addOptional(p, 'detection_options', detection_opts(), @(x) validateattributes(x, {'struct'}, {'nonempty'}));
addOptional(p, 'SOPH_options', SOpowerphasehist_opts(), @(x) validateattributes(x, {'struct'}, {'nonempty'}));
% additional inputs to control the outputs from runDYNAMO()
addOptional(p, 'stats_table', [], @(x) validateattributes(x, {'double','table'}, {'real','2d'}));
addOptional(p, 'save_output_image', false, @(x) validateattributes(x, {'logical'}, {'scalar'}));
addOptional(p, 'output_fname', 'DYNAM-O_output', @(x) validateattributes(x, {'char','string'}, {'nonempty','scalartext'}));
addOptional(p, 'verbose', true, @(x) validateattributes(x, {'logical'}, {'scalar'}));
addOptional(p, 'plot_on', true, @(x) validateattributes(x, {'logical'}, {'scalar'}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

%Force data to be a column vector
if isrow(data)
    data = data(:);
end

%Check sleep stages
valid_stages = stage_vals>0 & stage_vals<6;
assert(~isempty(valid_stages),'No valid stages found');

%Set to range of valid scored data by default
if isempty(time_range) %#ok<*NODEF>
    valid_stage_inds = find(valid_stages);
    time_range = stage_times(valid_stage_inds([1, end]));
end

%Cast stage_vals to single for interpolations
stage_vals = single(stage_vals);

%Start a timer
ttotal = datetime('now');

%% PART 1: COMPUTE TIME-FREQUENCY PEAKS
% See computeTFPeaks() for a full list of optional arguments for finer
% control of watershed extraction of Time-Frequency Peaks

if isempty(stats_table)
    % If no stats table provided
    [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts]= computeTFPeaks(data, Fs, stage_times, stage_vals,...
        'time_range', time_range, detection_options, baseline_options); %#ok<*ASGLU>

else
    % If stats table provided, check to be sure SOPH is requested by output
    assert(nargout==2, 'Nothing to compute. Must provide SOPH output if stats table is used as input.');

    if verbose
        disp('TF peaks stats table provided. Computing SOPH only.');
    end

    data_time_range = data;
    t_time_range = (0:length(data)-1)/Fs;
    artifacts = detect_artifacts(data, Fs);

end

%% PART 2: COMPUTE ADDITIONAL PEAK FEATURES
% Additional useful features that describe each detected TF peak in the
% stats_table are computed here. Customized functions can be added in this
% section to populate the table with other feature columns.

% Compute sleep stage at each TF peak
stats_table = computePeakStage(stats_table, stage_times, stage_vals, t_time_range, artifacts);
% Compute slow oscillation power at each TF peak
[stats_table, SOpower_norm, SOpower_times] = computePeakSOpower(stats_table, data_time_range, Fs,...
    'EEG_times', t_time_range, 'isexcluded', artifacts, SOPH_options);
% Compute slow oscillation phase at each TF peak
[stats_table, SOphase, SOphase_times] = computePeakSOphase(stats_table, data_time_range, Fs,...
    'EEG_times', t_time_range, 'isexcluded', artifacts, SOPH_options);

%% PART 3: COMPUTE SO-POWER/PHASE HISTOGRAMS
% See SOpowerphaseHistogram() for a full list of optional arguments for
% finer control of Histogram generation

if nargout==2
    [SOpower_mat, SOphase_mat, SOpower_bins, SOphase_bins, freq_bins,...
        SOpower_TIB, SOphase_TIB, ~, ~, hist_peakidx] = SOpowerphaseHistogram(...
        data_time_range, Fs, stats_table.PeakFrequency, stats_table.PeakTime,...
        'stage_times', stage_times, 'stage_vals', stage_vals,...
        'SOpower', SOpower_norm, 'SOpower_times', SOpower_times,...
        'SOphase', SOphase, 'SOphase_times', SOphase_times,...
        'verbose', verbose, SOPH_options);

    %Create SOPHs structure for output
    SOPHs.SOpower_mat = SOpower_mat;
    SOPHs.SOphase_mat = SOphase_mat;
    SOPHs.SOpower_bins = SOpower_bins;
    SOPHs.SOphase_bins = SOphase_bins;
    SOPHs.freq_bins = freq_bins;
    SOPHs.SOpower_TIB = SOpower_TIB;
    SOPHs.SOphase_TIB = SOphase_TIB;

    if verbose
        disp([newline, 'Total time: ' char(datetime('now')-ttotal)]);
    end

else
    if verbose
        disp('Computing TF peaks only. No SOPH output requested.');
    end

    % This index generally comes from the SOPH, otherwise set as all true
    hist_peakidx = true(1, height(stats_table));

end

%% PLOT RESULTS FIGURE
if plot_on

    % COMPUTE SPECTROGRAM FOR DISPLAY
    freq_limits = [2,25];
    [spect_disp, stimes_disp, sfreqs_disp] = multitaper_spectrogram_mex(data, Fs, freq_limits, [15 29], [30 15], [],'linear',[],false,false);

    % Plot only TF peaks that contribute to SO-power/phase histograms
    stats_table_SOPH = stats_table(hist_peakidx, :);

    if nargout==2
        % Create figure
        fh = figure('Color',[1 1 1],'units','inches','position',[0 0 8.5 11]);
        orient portrait;

        %Hypnogram/spectrogram/SO-power axes
        hypn_spect_ax(1) = axes('Parent',fh,'Position',[0.06 0.913 0.83 0.056]);
        hypn_spect_ax(2) = axes('Parent',fh,'Position',[0.06 0.756 0.83 0.157]);
        hypn_spect_ax(3) = axes('Parent',fh,'Position',[0.06 0.7   0.83 0.056]);

        %Scatter plot axes
        ax(1) = axes('Parent',fh,'Position',[0.06 0.45 0.83 0.2]);

        %SO-power/phase axes
        ax(2) = axes('Parent',fh,'Position',[0.06  0.07 0.335 0.3]);
        ax(3) = axes('Parent',fh,'Position',[0.555 0.07 0.335 0.3]);

        % Link axes of appropriate plots
        linkaxes([hypn_spect_ax, ax(1)], 'x');
        linkaxes([hypn_spect_ax(2), ax(1)], 'y');

        % Set yaxis limits
        ylimits = freq_limits;  % can be modified to change the figure limits

        % Plot hypnogram
        axes(hypn_spect_ax(1));
        %Adds artifacts raster below hypnogram, as computed in the time-domain,
        %will not match up to the spectrogram due to windowing
        hypnoplot(stage_times/3600,stage_vals,'Artifacts',artifacts','ArtifactTimes',t_time_range/3600);
        xlim(time_range/3600)
        ylim(hypn_spect_ax(1),[.3 5.1])
        th(1) = title('EEG Spectrogram');

        % Plot spectrogram
        axes(hypn_spect_ax(2))
        stimes_inds = stimes_disp >= time_range(1) & stimes_disp <= time_range(2);
        imagesc(stimes_disp(stimes_inds)/3600, sfreqs_disp, pow2db(spect_disp(:, stimes_inds)));
        axis xy
        colormap(hypn_spect_ax(2), rainbow4);
        climscale;

        c = colorbar_noresize; % set colobar
        c.Label.String = 'Power (dB)'; % colobar label
        c.Label.Rotation = -90; % rotate colorbar label
        c.Label.VerticalAlignment = "bottom";

        ylabel('Frequency (Hz)');
        xlabel('')
        ylim(ylimits);
        hypn_spect_ax(1).XTick = [];
        xlim(time_range/3600)

        % Plot SO-Power trace
        axes(hypn_spect_ax(3))
        plot(SOpower_times/3600,SOpower_norm,'linewidth',2)
        xlim(time_range/3600)
        min_SOP = min(SOpower_norm);
        max_SOP = max(SOpower_norm);
        ylim([min_SOP-(0.1*abs(min_SOP)), max_SOP+(0.1*abs(max_SOP))])
        hypn_spect_ax(1).YTick = [round(min_SOP, 2, 'significant') round((max_SOP+min_SOP)/2, 2, 'significant') round(max_SOP, 2, 'significant')];
        hypn_spect_ax(1).YTickLabel = num2str(get(hypn_spect_ax(3),'ytick')','%.1f');

        switch SOPH_options.SOpower_norm_method
            case 'percent'
                ylab = '%SOP';
            case 'proportion'
                ylab = 'SO Prop.';
            otherwise
                ylab = 'SOP (dB)';
        end

        ylabel(ylab);

        % Plot time-frequency peak scatterplot
        axes(ax(1))
        %Compute peak dot size
        pmin = prctile(stats_table_SOPH.Volume, 5); % get 5th ptile of heights
        peak_size = stats_table_SOPH.Volume / pmin * 0.5;  % 5th ptile fixed at size 0.5

        %Do not plot larger than 95th ptile or else dots could obscure other things on the plot
        pmax = prctile(stats_table_SOPH.Volume, 95); % get 95th ptile of heights
        pmax_inds = stats_table_SOPH.Volume> pmax;
        peak_size(pmax_inds) = nan;

        scatter(stats_table_SOPH.PeakTime/3600, stats_table_SOPH.PeakFrequency, peak_size, stats_table_SOPH.SOphase, 'filled'); % scatter plot all peaks

        %Make circular colormap
        colormap(ax(1),circshift(hsv(2^12),-650))

        c = colorbar_noresize;
        c.Label.String = 'Phase (radians)';
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
        c.XTick = [-pi -pi/2 0 pi/2 pi];
        c.XTickLabel = {'-\pi', '-\pi/2', '0', '\pi/2', '\pi'};

        ylabel('Frequency (Hz)');
        ylim(ylimits);

        xlabel('Time (hrs)')
        th(2) = title('Extracted Time-Frequency Peaks');
        xlim(time_range/3600)

        % Plot SO-power histogram
        axes(ax(2))
        imagesc(SOpower_bins, freq_bins, SOpower_mat');
        axis xy;
        colormap(ax(2), gouldian);

        %Set colorscale
        c_ptiles = prctile(SOpower_mat(:), [5, 98]);
        clim(gca,[c_ptiles(1) c_ptiles(2)]);

        c = colorbar_noresize;
        c.Label.String = {'Density', '(peaks/min in bin)'};
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";

        switch SOPH_options.SOpower_norm_method
            case 'percent'
                xlab = '% SO-Power';
            case 'proportion'
                xlab = 'SO-Power Proportion';
            otherwise
                xlab = 'SO-Power (dB)';
        end
        xlabel(xlab);
        ylabel('Frequency (Hz)');
        ylim(ylimits);
        th(3) = title('SO-Power Histogram');

        % Plot SO-phase histogram
        axes(ax(3))
        imagesc(SOphase_bins, freq_bins, SOphase_mat');
        axis xy;
        colormap(ax(3), 'magma');

        %Scale color limits
        c_ptiles = prctile(SOphase_mat(:), [5, 98]);
        clim([c_ptiles(1) c_ptiles(2)]);

        c = colorbar_noresize;
        c.Label.String = {'Proportion'};
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";

        xlabel('SO-Phase (rad)');
        xticks([-pi -pi/2 0 pi/2 pi])
        xticklabels({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'});
        ylim(ylimits);
        th(4) = title('SO-Phase Histogram');

        set([ax(1:3) hypn_spect_ax],'fontsize',10)
        set(th,'fontsize',15)

    else
        % Create figure
        fh = figure('Color',[1 1 1],'units','inches','position',[0 0 8.5 11]);
        orient portrait;

        %Hypnogram/spectrogram/SO-power axes
        hypn_spect_ax(1) = axes('Parent',fh,'Position',[0.06 0.913 0.83 0.056]);
        hypn_spect_ax(2) = axes('Parent',fh,'Position',[0.06 0.756 0.83 0.157]);

        %Scatter plot axes
        ax(1) = axes('Parent',fh,'Position',[0.06 0.45 0.83 0.2]);

        % Link axes of appropriate plots
        linkaxes([hypn_spect_ax, ax(1)], 'x');
        linkaxes([hypn_spect_ax(2), ax(1)], 'y');

        % Set yaxis limits
        ylimits = freq_limits;  % can be modified to change the figure limits

        % Plot hypnogram
        axes(hypn_spect_ax(1));
        %Adds artifacts raster below hypnogram, as computed in the time-domain,
        %will not match up to the spectrogram due to windowing
        hypnoplot(stage_times/3600,stage_vals,'Artifacts',artifacts','ArtifactTimes',t_time_range/3600);
        xlim(time_range/3600)
        ylim(hypn_spect_ax(1),[.3 5.1])
        th(1) = title('EEG Spectrogram');

        % Plot spectrogram
        axes(hypn_spect_ax(2))
        stimes_inds = stimes_disp >= time_range(1) & stimes_disp <= time_range(2);
        imagesc(stimes_disp(stimes_inds)/3600, sfreqs_disp, pow2db(spect_disp(:, stimes_inds)));
        axis xy
        colormap(hypn_spect_ax(2), rainbow4);
        climscale;

        c = colorbar_noresize; % set colobar
        c.Label.String = 'Power (dB)'; % colobar label
        c.Label.Rotation = -90; % rotate colorbar label
        c.Label.VerticalAlignment = "bottom";

        ylabel('Frequency (Hz)');
        xlabel('')
        ylim(ylimits);
        hypn_spect_ax(1).XTick = [];
        xlim(time_range/3600)

        % Plot time-frequency peak scatterplot
        axes(ax(1))
        %Compute peak dot size
        pmin = prctile(stats_table_SOPH.Volume, 5); % get 5th ptile of heights
        peak_size = stats_table_SOPH.Volume / pmin * 0.5;  % 5th ptile fixed at size 0.5

        %Do not plot larger than 95th ptile or else dots could obscure other things on the plot
        pmax = prctile(stats_table_SOPH.Volume, 95); % get 95th ptile of heights
        pmax_inds = stats_table_SOPH.Volume> pmax;
        peak_size(pmax_inds) = nan;

        scatter(stats_table.PeakTime/3600, stats_table.PeakFrequency, peak_size, 'k', 'filled'); % scatter plot all peaks

        ylabel('Frequency (Hz)');
        ylim(ylimits);

        xlabel('Time (hrs)')
        th(2) = title('Extracted Time-Frequency Peaks');
        xlim(time_range/3600)

        set([ax(1) hypn_spect_ax],'fontsize',10)
        set(th,'fontsize',15)

    end

    %% PRINT OUTPUT
    if save_output_image
        %Output filename
        print(fh,'-dpng','-r200',output_fname);
    end

end
end


function [stats_table, SOPHs] = runExampleData()
disp('Running Example Data...');

%Load default options
baseline_options = baseline_opts();
detection_options = detection_opts();
SOPH_options = SOpowerphasehist_opts();

%% DATA SETTINGS
%Location of example data
data_fname = 'example_data/example_data.mat';

%Select 'segment' or 'night' for example data range
data_range = 'night'; %Only works for provided example data

%% LOAD DATA
%Load example EEG data
load(data_fname, 'data', 'stage_times', 'stage_vals', 'Fs');

switch data_range
    case 'segment'
        % Choose an example segment from the data
        time_range = [8420 13446];

        %Set the minimum time in SO-power bin to include in the SOPH
        SOPH_options.SOpower_min_time_in_bin = 5;

        disp(['Running example segment', newline])
    case 'night'
        % Choose an example segment from the data
        wake_buffer = 5*60; %5 minute buffer before/after first/last wake
        start_time = stage_times(find(stage_vals < 5 & stage_vals > 0, 1, 'first')) - wake_buffer;
        end_time = stage_times(find(stage_vals < 5 & stage_vals > 0, 1, 'last')) + wake_buffer;

        time_range = [start_time end_time];

        %Set the minimum time in SO-power bin to include in the SOPH
        SOPH_options.SOpower_min_time_in_bin = 10;

        disp(['Running full night', newline])
end

%Call main function
[stats_table, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals, time_range, baseline_options, detection_options, SOPH_options);
end
