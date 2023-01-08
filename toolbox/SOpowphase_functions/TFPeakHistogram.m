function [DOS_mat, freq_cbins, DOS_cbins, time_in_bin, prop_in_bin] = TFPeakHistogram(varargin)
% % TFPEAKHISTOGRAM computes TF-peak histogram versus a continuous depth of sleep (DOS) variable
% Usage:
%   [DOS_mat, freq_cbins, DOS_cbins, time_in_bin, prop_in_bin, peak_DOS, peak_selection_inds] = ...
%                           DOSHistogram(DOS, DOS_times, TFpeak_freqs, TFpeak_times, freq_range, freq_binsizestep, ...
%                                        DOS_range, DOS_binsizestep, DOSfreq_range, artifacts, ...
%                                         min_time_in_bin, rate_flag, smooth_flag, plot_flag)
%
%  Inputs:
%       TFpeak_freqs: Px1 - frequency each TF peak occurs (Hz) --required
%       TFpeak_times:  Px1 - times each TF peak occurs (s) --required
%       freq_range: 1x2 double - min and max frequencies of TF peak to include in the histogram
%                   (Hz). Default = [0,40]
%       freq_binsizestep: 1x2 double - [size, step] frequency bin size and bin step for frequency
%                         axis of DOS phase histograms (Hz). Default = [1, 0.2]
%       DOS_range: 1x2 double - min and max DOS values to consider in DOS phase analysis.
%                 Default calculated using min and max of DOS
%       DOS_binsizestep: 1x2 double - [size, step] DOS phase bin size and step for DOS phase axis 
%                            of histogram. Units are radians. Default
%                            size is (DOS_range(2)-DOSrange(1))/5, default step is
%                            (DOS_range(2)-DOSrange(1))/100
%       DOS_freqrange: 1x2 double - min and max frequencies (Hz) considered to be "slow oscillation". 
%                     Default = [0.3, 1.5]
%       min_time_in_bin: numerical - time (minutes) required in each DOS bin to include in DOS analysis.
%                                    Otherwise all values in that DOS bin will be NaN. 
%                                    Default = 1.
%       time_range: 1x2 double - min and max times for which to include TFpeaks. Also used to normalize
%                   DOS. Default = [t_data(1), t_data(end)]
%       pow_freqDOS: 1x2 logical - normalize by dividing by the sum over each dimension 
%                          of the DOS histogram [frequency, DOS]. Default = [true, false]
%       rate_flag: logical - histogram output in terms of TFpeaks/min instead of count. Default = true.
%       smooth_flag: logical - smooth the histogram using 5pt moving average 2D smoothing. Default = false.
%       plot_flag: logical - DOS histogram plots. Default = false
%
%  Outputs:
%       DOS_mat: DOS histogram (DOS x frequency)
%       freq_cbins: 1xF double - centers of the frequency bins
%       DOS_cbins: 1xPO double - centers of the power DOS bins
%       time_in_bin: 1xT double - minutes spent in each phase bin for all selected stages 
%       prop_in_bin: 1xT double - proportion of total time (all stages) in each bin spent in 
%                          the selected stages
%       peak_DOS: 1xP double - normalized slow oscillation power at each TFpeak
%       peak_selection_inds: 1xP logical - which TFpeaks are valid give the artifacts and stage_exclusion 
%                            exclusions
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

%% Parse input

p = inputParser;
addRequired(p, 'DOS', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'DOS_times', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'TFpeak_freqs', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'TFpeak_times', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addOptional(p, 'freq_range', [0,40], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'freq_binsizestep', [1, 0.2], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'DOS_range', [], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'DOS_binsizestep', [], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'min_time_in_bin', 1, @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','nonnan', 'nonnegative','integer'}));
addOptional(p, 'dim_normalize', []);
addOptional(p, 'rate_flag', true, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'smooth_flag', false, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'plot_flag', false, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'proportion_freqrange', [0.3, 30], @(x) validateattributes(x, {'numeric','vector'},{'real','finite','nonnan'}));
addOptional(p, 'verbose', true, @(x) validateattributes(x,{'logical'},{}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

%% Get DOS at each peak time
peak_DOS = interp1(DOS_times, DOS, TFpeak_times, 'nearest');

%% Additional DOS variables [new]
DOS_valid = ~isnan(DOS);
DOS_times_step = DOS_times(2) - DOS_times(1);

%% Compute the DOS historgram
% Get frequency bins
[freq_bin_edges, freq_cbins] = create_bins(freq_range, freq_binsizestep(1), freq_binsizestep(2), 'partial');
num_freqbins = length(freq_cbins);

% Get DOS bins
if isempty(DOS_range) %#ok<*NODEF>
    DOS_range(1) = min(DOS);
    DOS_range(2) = max(DOS);
end
if isempty(DOS_binsizestep)
    DOS_binsizestep(1) = (DOS_range(2) - DOS_range(1)) / 5;
    DOS_binsizestep(2) = (DOS_range(2) - DOS_range(1)) / 100;
end
[DOS_bin_edges, DOS_cbins] = create_bins(DOS_range, DOS_binsizestep(1), DOS_binsizestep(2), 'partial');
num_DOSbins = length(DOS_cbins);

% Display DOSH settings
if verbose
    disp(['  TF Histogram Settings' , newline, ...
          '    Frequency Window Size: ' num2str(freq_binsizestep(1)) ' Hz, Window Step: ' num2str(freq_binsizestep(2)) ' Hz', newline,...
          '    Frequency Range: ', num2str(freq_range(1)) '-' num2str(freq_range(2)) ' Hz', newline,...
          '    DOS Window Size: ' num2str(DOS_binsizestep(1)) ', Window Step: ' num2str(DOS_binsizestep(2)), newline,...
          '    DOS Range: ', num2str(DOS_range(1)), '-', num2str(DOS_range(2)),  newline,...
          '    Minimum time required in each DOS bin: ', num2str(min_time_in_bin), 'min', newline]);
end

% Intialize DOS * freq matrix
DOS_mat = nan(num_DOSbins, num_freqbins);

% Initialize time in bin
time_in_bin = zeros(num_DOSbins,1);
prop_in_bin = zeros(num_DOSbins,1);

for s = 1:num_DOSbins
    
    % Get indices of DOS that occur in this DOS bin
    TIB_inds = (DOS >= DOS_bin_edges(1,s)) & (DOS < DOS_bin_edges(2,s));
    
    % Get indices of TFpeaks that occur in this DOS bin
    DOS_inds = (peak_DOS >= DOS_bin_edges(1,s)) & (peak_DOS < DOS_bin_edges(2,s));
    
    % Get time in bin (min) and proportion of time in bin
    time_in_bin(s) = (sum(TIB_inds & DOS_valid) * DOS_times_step) / 60;
    prop_in_bin(s) = sum(TIB_inds & DOS_valid) / sum(DOS_valid); % [This is not what prop_in_bin is trying to calculate]

    % if less than threshold time in DOS bin, whole column of DOS hist should be nan
    if time_in_bin(s) < min_time_in_bin
        continue
    end 
    
    if sum(DOS_inds) >= 1
        for f = 1:num_freqbins               
            % Get indices of TFpeaks that occur in this freq bin
            freq_inds = (TFpeak_freqs >= freq_bin_edges(1,f)) & (TFpeak_freqs < freq_bin_edges(2,f));
            
            % Fill histogram with count of peaks in this freq/DOS bin
            DOS_mat(s,f) = sum(DOS_inds & freq_inds);
        end
        
    else
        DOS_mat(s,:) = 0;
    end
    
    if smooth_flag
        DOS_mat(s,:) = smooth(DOS_mat(s,:));
    end 
    
    if rate_flag
        DOS_mat(s,:) = DOS_mat(s,:) / time_in_bin(s);
    end
    
end

%% Normalize along a dimension if desired
if ~isempty(dim_normalize)
    DOS_mat = DOS_mat ./ sum(DOS_mat,dim_normalize);
end

%% Plot
if plot_flag
   figure;
   imagesc(DOS_cbins, freq_cbins, DOS_mat')
   axis xy
   colormap(gouldian)
   climscale([],[],false);
   colorbar;
   xlabel('DOS (normalized)');
   ylabel('Frequency (Hz)');
end

end


