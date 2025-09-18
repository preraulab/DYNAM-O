function opts = SOpowerphasehist_opts(varargin)
%SOPOWERPHASEHIST_OPTS Create a structure with default parameters for SOPH calculation
%
%   Usage:
%       opts = SOpowerphasehist_opts(varargin)
%
%   SOPOWERPHASEHIST_OPTS STRUCTURE PARAMETERS
%       freq_range: 1x2 double - min and max frequencies of TF peak to include in the histograms (Hz).
%                   Default = [0, 30]
%       freq_binsizestep: 1x2 double - [size, step] frequency bin size and bin step for frequency
%                         axis of SO power/phase histograms (Hz). Default = [1, 0.2]
%       compute_rate: logical - histogram output in terms of TFpeaks/min instead of count.
%                     Default = true.
%       SOPH_stages: stages in which to restrict the SOPHs. Default: 1:3 (NREM only)
%                    W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
%
%       SO_freqrange: 1x2 double - min and max frequencies (Hz) considered to be "slow oscillation".
%                     Default = [0.3, 1.5]
%       SOpower_tapers: 1x2 double - multitaper method parameters. [time half-bandwidth product, number of tapers].
%                       Default = [5, 9]
%       SOpower_window_params: 1x2 double - multitaper method window parameters. [window size, window step size].
%                              Default = [5, .5]
%       SOpower_outlier_threshold: double - cutoff threshold in standard deviation for excluding outlier SOpower values.
%                                  Default = 3.
%       SOpower_norm_method: char - normalization method for SOpower. Options:'pNshiftS', 'percent', 'proportion', 'none'. Default = 'p2shift1234'
%                            For shift, it follows the format pNshiftS where N is the percentile and S is the list of stages (5=W,4=R,3=N1,2=N2,1=N3).
%                            (e.g. p2shift1234 = use the 2nd percentile of stages N3, N2, N1, and REM, p5shift123 = use the 5th percentile of stages
%                            N3, N2 and N1)
%       SOpower_retain_Fs: logical - whether to upsample calculated SOpower to the sampling rate of data. Default = true
%
%       SOpower_min_time_in_bin: numerical - time (minutes) required in each SO power bin to include in SOpower analysis. Otherwise all values
%                                in that SO power bin will be NaN. Default = 10.
%       SOpower_range: 1x2 double - min and max SO power values to consider in SO power analysis.
%                      Default calculated using min and max of SO power
%       SOpower_binsizestep: 1x2 double - [size, step] SO power bin size and step for SO power axis
%                            of histogram. Units are radians. Default size is (SOpower_range(2)-SOpower_range(1))/10;
%                            default step size is (SOpower_range(2)-SOpower_range(1))/100
%
%       SOphase_filter: 1xF double - custom filter that will be used to estimate SOphase
%
%       SOphase_min_peak_at_freq: numerical - number of TF peaks required at a frequency to include in SOphase analysis. Otherwise all values
%                                in that frequency bin will be NaN. Default = 0.
%       SOphase_norm_dim: integer - which dimension of the SOphase histogram to normalize to add to 1. Default = 1
%       SOphase_range: 1x2 double - min and max SO phase values (radians) to consider in SO phase analysis.
%                      Default is [-pi, pi]
%       SOphase_binsizestep: 1x2 double - [size, step] SO phase bin size and step for SO phase axis
%                            of histogram. Units are radians. Default size is 2*pi/5; default step suze is 2*pi/100
%
%       plot_on: logical - SO power histogram plots. Default = false
%       verbose: logical - Verbose output. Default = true
%
%   Output:
%       opts: Structure containing the parameters with either default or user-specified values
%
%   Example:
%       opts = SOpowerphasehist_opts();
%       opts = SOpowerphasehist_opts('freq_range', [0, 30]);
%
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

%% Parse inputs
p = inputParser;

%General settings
addOptional(p, 'freq_range', [0, 30], @(x) validateattributes(x,{'numeric'},{'real','finite','vector','numel',2}));
addOptional(p, 'freq_binsizestep', [1, 0.2], @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'compute_rate', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'SOPH_stages', 1:3, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','vector'})); % W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0

%SOpower computation params
addOptional(p, 'SO_freqrange', [0.3, 1.5], @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector','numel',2}));
addOptional(p, 'SOpower_tapers', [5, 9], @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'SOpower_window_params', [5, .5], @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'SOpower_outlier_threshold', 3, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addOptional(p, 'SOpower_norm_method', 'p2shift1234', @(x) validateattributes(x, {'char','string'}, {'nonempty','scalartext'}));
addOptional(p, 'SOpower_retain_Fs', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));

%SOpower Histogram specific settings
addOptional(p, 'SOpower_min_time_in_bin', 10, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));
%Ranges and bin step sizes determined dynamically with empty input [], user should set to fixed values when comparing between subjects
addOptional(p, 'SOpower_range', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addOptional(p, 'SOpower_binsizestep', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));

%SOphase computation params
addOptional(p, 'SOphase_filter', []);

%SOphase Histogram specific settings
addOptional(p, 'SOphase_min_peak_at_freq', 0, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));
addOptional(p, 'SOphase_norm_dim', 1, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));
addOptional(p, 'SOphase_range', [-pi, pi], @(x) validateattributes(x, {'numeric'}, {'real','finite','vector','numel',2}));
addOptional(p, 'SOphase_binsizestep', [(2*pi)/5, (2*pi)/100], @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));

parse(p,varargin{:});
opts = p.Results;
