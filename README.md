<p align="center">
<img src=https://user-images.githubusercontent.com/78376124/214062562-4f8fc73b-5a0a-4cf7-b219-9d0de101528d.png>
</p>

## DYNAM-O: The Dynamic Oscillation Toolbox for MATLAB - Prerau Laboratory ([sleepEEG.org](https://prerau.bwh.harvard.edu/))

#### This repository contains the updated and optimized MATLAB toolbox code for extracting time-frequency peaks from EEG data and creating slow-oscillation power and phase histograms. [Our Python port, pyDYNAM-O is available here.](https://github.com/preraulab/pyDYNAM-O)

## Citations
### Paper and Toolbox
Please cite the following paper when using this package: 
> Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach, Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis for Electroencephalographic Phenotyping and Biomarker Identification, Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223

The toolbox can be referred to in the text as:
> Prerau Lab's Dynamic Oscillation Toolbox (DYNAM-O) v1.0 (sleepEEG.org/)

The paper is available open access at https://doi.org/10.1093/sleep/zsac223

#### Perceptually Uniform Colormaps
Included in this package are versions of a rainbow and "gouldian" colormap, designed to be more perceptually uniform than jet and parula, respectively. If you use them, please cite:
> Peter Kovesi. Good Colour Maps: How to Design Them. arXiv:1509.03700 [cs.GR] 2015 https://arxiv.org/abs/1509.03700
--- 
## Tutorial
A full description of the toolbox and tutorial [can be found on the Prerau Lab site](https://prerau.bwh.harvard.edu/DYNAM-O/).

## Table of Contents
* [Overview](#overview)
* [Background and Motiviation](#background-and-motivation)
* [Quick Start](#quick-start-using-the-toolbox)
* [Algorithm Summary](#algorithm-summary)
* [Optimizations](#optimizations)
* [Repository Structure](#repository-structure)

## Overview 

This repository contains code to detect time-frequency peaks (TF-peaks) in a spectrogram of EEG data using the approach based on the one described in ([Stokes et. al, 2022](https://doi.org/10.1093/sleep/zsac223)). TF-peaks represent transient oscillatory neural activity with in the EEG, which by definition will appear as a peak in the time-frequency topography of the spectrogram. Within sleep, perhaps the most important transient EEG oscillation is the sleep spindle, which has been linked to memory consolidation, and changes spindle activity have been linked with natural aging as well as numerous psychiatric and neurodegenerative disorders. This approach extracts TF-peaks by identifies salient peaks in the time-frequency topography of the spectrogram, using a method based on the watershed algorithm, which was original developed for computer vision applications. The dynamics of the TF-peaks can then be described in terms of continuous correlates of sleep depth and cortical up/down states using representations called slow-oscillation (SO) power and phase histograms. This package provides the tools for TF-peak extraction as well as the creation of the SO-power/phase histograms.

## Background and Motivation

Scientists typically study brain activity during sleep using the electroencephalogram, or EEG, which measures brainwaves at the scalp. Starting in the mid 1930s, the sleep EEG was first studied by looking at the traces of brainwaves drawn on a paper tape by a machine. Many important features of sleep are still based on what people almost a century ago could most easily observe in the complex waveform traces. Even the latest machine learning and signal processing algorithms for detecting sleep waveforms are judged against their ability to recreate human observation. What then can we learn if we expand our notion of sleep brainwaves beyond what was historically easy to identify by eye? 

<figure><img src="https://prerau.bwh.harvard.edu/images/EEG-time%20trace.png" alt="eeg trace" style="width:100%">
<figcaption align = "center"><b>An original paper tape trace of EEG from the 1930s, showing sleep spindles. (Loomis et. al 1935)</b></figcaption></figure>
<br/><br/>

One particularly important set of sleep brainwave events are called sleep spindles. These spindles are short oscillation waveforms, usually lasting less than 1-2 seconds, that are linked to our ability to convert short-term memories to long-term memories. Changes in spindle activity have been linked with numerous disorders such as schizophrenia, autism, and Alzheimer’s disease, as well as with natural aging. Rather than looking for spindle activity according to the historical definition, we develop a new approach to automatically extract tens of thousands of short spindle-like transient oscillation waveform events from the EEG data throughout the entire night. This approach takes advantage of the fact that transient oscillations will looks like high-power regions in the spectrogram, which represent salient time-frequency peaks (TF-peaks) in the spectrogram.
<br/><br/>

<figure><img src="https://prerau.bwh.harvard.edu/images/TF-peak%20detection_small.png" alt="tf-peaks" style="width:100%"> <figcaption align = "center"><b>Transient oscillation activity in the time domain will appear as contiguous high-power regions in the spectrogram, which represent salient peaks (TF-peaks) in the time-frequency topography.</b></figcaption></figure>
<br/><br/>

The TF-peak detection method is based on the watershed algorithm, which is commonly used in computer vision applications to segment an image into distinct objects. The watershed method treats an image as a topography and identifies the catchment basins, that is, the troughs, into which water falling on the terrain would collect.
<br/><br/>

<figure><img src="https://prerau.bwh.harvard.edu/images/SOpowphase_small.png" alt="SO-power/phase histograms" style="width:100%"> <figcaption align = "center"><b>Slow-oscillation power and phase histograms create representations of TF-peak activity as function of continuous depth-of-sleep and as a function of timing with respect to cortical up/down states.</b></figcaption></figure>
<br/><br/>

Next, instead of looking at the waveforms in terms of fixed sleep stages (i.e., Wake, REM, and non-REM stages 1-3) as di standard sleep studies, we can characterize the full continuum of gradual changes that occur in the brain during sleep. We use the slow oscillation power (SO-phase) as a metric of continuous depth of sleep, and slow-oscillation phase (SO-phase) to represent timing with respect to cortical up/down states. By characterizing TF-peak activity in terms of these two metrics, we can create graphical representations, called SO-power and SO-phase histograms. This creates a comprehensive representation of transient oscillation dynamics at different time scales, providing a highly informative new visualization technique and powerful basis for EEG phenotyping and biomarker identification in pathological states. To form the SO-power histogram, the central frequency of the TF-peak and SO-power at which the peak occured are computed. Each TF-peak is then sorted into its corresponding 2D frequency x SO-power bin and the count in each bin is normalized by the total sleep time in that SO-power bin to obtain TF-peak density in each grid bin. The same process is used to form the SO-phase histograms except the SO-phase at the time of the TF-peak is used in place of SO-power, and each row is normalized by the total peak count in the row to create probability densities.

## Quick Start: Using the Toolbox

An [example script](https://github.com/preraulab/DYNAM-O/blob/main_public/example_script.m) is provided in the repository that takes an excerpt of a single channel of [example sleep EEG data](https://github.com/preraulab/DYNAM-O/blob/main_public/example_data/example_data.mat) and runs the TF-peak detection watershed algorithm and the SO-power and SO-phase analyses, plotting the resulting hypnogram, spectrogram, TF-peak scatterplot, SO-power histogram, and SO-phase histogram (shown below). 

After installing the package, execute the example script on the command line:

``` matlab
> example_script;
```

Once a parallel pool has started (if applicable), the following result should be generated: 

<figure ><img src="https://prerau.bwh.harvard.edu/images/TFpeakDynamics_segment.png" alt="example segment" width="40%;">
<figcaption><b>Output from the example segment of data provided with the toolbox.</b></figcaption></figure>
<br/><br/>

This is the general output for the algorithm. On top is the hypnogram, EEG spectrogram, and the SO-power trace. In the middle is a scatterplot of the TF-peaks with x = time, y = frequency, size = peak prominence, and color = SO-phase. On the bottom are the SO-power and SO-phase histograms.

Additionally, you should get a peak statistics table `stats_table` that has all of the detected peaks. The example script also creates `stats_table_SOPH`, which has the features for just the peaks used in the SO-power/phase histograms and is used for plotting. 

These tables have the following features for each peak:

| **Feature**   | **Description**                                                  | **Units**       |
|---------------|------------------------------------------------------------------|-----------------|
| Area          | Time-frequency area of peak                                      | sec*Hz          |
| BoundingBox   | Bounding Box: (top-left time, top-left freq, width, height)      | (sec, Hz, sec, Hz) |
| HeightData    | Height of all pixels within peak region                          | μV^2/Hz         |
| Volume        | Time-frequency volume of peak in s*μV^2                          | sec*μV^2        |
| Boundaries    | (time, frequency) of peak region boundary pixels                 | (seconds Hz)    |
| PeakTime      | Peak time based on weighted centroid                             | sec             |
| PeakFrequency | Peak frequency based on weighted centroid                        | Hz              |
| Height        | Peak height above baseline                                       | μV^2/Hz         |
| Duration      | Peak duration in seconds                                         | sec             |
| Bandwidth     | Peak bandwidth in Hz                                             | Hz              |
| SegmentNum    | Data segment number                                              | #               |
| PeakStage     | Stage: 6 = Artifact, 5 = W, 4 = R, 3 = N1, 2 = N2, 1 = N3, 0 = Unknown | Stage #         |
| SOpower       | Slow-oscillation power at peak time                              | dB              |
| SOphase       | Slow-oscillation phase at peak time                              | rad             |


You can also look at an overview of the resultant peak data by typing the following in the command prompt (omit the semicolon to see output):
``` matlab
summary(stats_table)
```
### Changing the Preset Time Range
Once the segment has succesfully completed, you can run the full night of data by changing the following line in the example script under `DATA SETTINGS`, such that the variable data_range changes from 'segment' to 'night'.

``` matlab
%%Select 'segment' or 'night' for example data range
data_range = 'night';
```
This should produce the following output:
<figure><img src="https://prerau.bwh.harvard.edu/images/TFpeakDynamics.png" alt="full night example" style="width:40%"> <figcaption><b>Output from the example full night of data provided with the toolbox.</b></figcaption></figure>
<br/><br/>

For more in-depth information and documentation on the Transient Oscillation Dynamics algorithms visit [the Prerau Lab website.](https://prerau.bwh.harvard.edu/DYNAM-O)
<br/><br/>

### Changing the Quality Settings
The following preset settings are available in our example script under `ALGORITHM SETTINGS`. As all data are different, it is essential to verify equivalency before relying on a speed-optimized solution other than precision.

- “precision”:  Most accurate assessment of individual peak bounds and phase
- “fast”: Faster approach, with accurate SO-power/phase histograms, minimal difference in phase
- “draft”: Fastest approach. Good SO-power/phase histograms but with increased high-frequency peaks. Not recommended for assessment of individual peaks or precision phase estimation.

Adjust these by selecting the appropriate and changing `quality_setting` from 'fast' to the appropriate quality setting.

``` matlab
%Quality settings for the algorithm:
%   'precision': high res settings
%   'fast': speed-up with minimal impact on results *suggested*
%   'draft': faster speed-up with increased high frequency TF-peaks, *not recommended for analyzing SOphase*
quality_setting = 'draft';
```

### Changing the SO-power Normalization

There are also multiple normalization schemes that can be used for the SO-power.

- 'none': No normalization. The unaltered SO-power in dB.
- 'p5shift':	Percentile shifted. The Nth percentile of artifact free SO-power during sleep (non-wake) times is computed and subtracted. We use the 5th percentile by default, as it roughly corresponds with aligning subjects by N1 power. This is the recommended normalization for any multi-subject comparisons.
- 'percent': %SO-power. SO-power is scaled between 1st and 99th percentile of artifact free data during sleep (non-wake) times. This this only appropriate for within-night comparisons or when it is known all subjects reach the same stage of sleep.
- 'proportional': The ratio of slow to total SO-power.

To change this, change `SOpower_norm_method` to the appropriate value.

``` matlab
%Normalization setting for computing SO-power histogram:
%   'p5shift': Aligns at the 5th percentile, important for comparing across subjects
%   'percent': Scales between 1st and 99th ptile. Use percent only if subjects all reach stage 3
%   'proportion': ratio of SO-power to total power
%   'none': No normalization. Raw dB power
SOpower_norm_method = 'p5shift';
```

### Changing Extracted Features

There are multiple different features that can be extracted for each peak region during the watershed pipeline (see table above).

To change this, adjust `features` to include the names of interested features.

``` matlab
%Select features for speed:
%To include all features swap out with the line below
%features = 'all';
%or select from:
%features = {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height', 'HeightData',...
%            'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume'}
features = {'Area', 'Bandwidth', 'Duration', 'Height', 'PeakFrequency', 'PeakTime', 'Volume'};
```

## Saving Output
You can save the image output by adjusting these lines: 
``` matlab
%Save figure image
save_output_image = false;
output_fname = [];
```

You can also save the raw data with by changing the value of `save_peak_properties`:
``` matlab
%Save peak property data
%   0: Does not save anything
%   1: Saves a subset of properties for each TFpeak 
%   2: Saves all properties for all peaks (including rejected noise peaks) 
save_peak_properties = 0;
```

## Running Your Own Data
The two main functions to run are computeTFPeaks() and SOpowerphaseHistogram().

The first function applys the watershed algorithm to extract time-frequency peaks
``` matlab
computeTFPeaks(data, Fs, stage_vals, stage_times, <options>);
```
It uses the following inputs:
``` matlab
%       data (req):                [1xn] double - timeseries data to be analyzed
%       Fs (req):                  double - sampling frequency of data (Hz)
%       stage_vals (req):          [1xm] double - sleep stage values at eaach time in
%                                  stage_times. Note the staging convention: 0=unidentified, 1=N3,
%                                  2=N2, 3=N1, 4=REM, 5=WAKE
%       stage_times (req):         [1xm] double - timestamps of stage_vals
%       t_data (opt):              [1xn] double - timestamps for data. Default = (0:length(data)-1)/Fs;
%       time_range (opt):          [1x2] double - section of EEG to use in analysis
%                                  (seconds). Default = [min(t_data), max(t_data)]
%       downsample_spect(opt):     2x1 double indicating number of rows and columns to downsize spect to
%       features (opt):            [1xf] char or cell array of char -
%                                  features to be extracted from each peak region. Can be any subset of
%                                  {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height', 'HeightData', 
%                                   'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume'} or 'all'. Default = 'all'
%       artifacts (opt):           [1xn] logical - boolean indicating artifact time points. Default = [], run detect_artifacts()
%       artifact_filters (opt):    struct with 2 digitalFilter fields "hpFilt_high","hpFilt_broad" -
%                                  filters to be used for artifact detection
%       stages_include (opt):      [1xp] double - which stages to include in the SO-power and
%                                  SO-phase histograms. Default = [1,2,3,4]
%                                  W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
%       verbose (opt):             logical - display extra info. Default = true
%       quality_setting (opt):     charcater - Quality settings for the algorithm:
%                                       'precision': high res settings
%                                       'fast' (default): speed-up with minimal impact on results *suggested*
%                                       'draft': faster speed-up with increased high frequency TF-peaks, *not recommended for analyzing SOphase*
```
The outputs are:
``` matlab
%       stats_table:  table - time, frequency, height, SOpower, and SOphase
%                     for each TFpeak
%       spect:        2D double - spectrogram of data
%       stimes:       1D double - timestamp bin center values for dimension 2 of
%                     spect
%       sfreqs:       1D double - frequency bin center values for dimension 1 of
%                     spect
%       data_trunc:   [1xn] double - timeseries data in time_range
%       t_data_trunc: [1xn] double - timestamps for data in time_range
%       artifacts:    1xT logical of times flagged as artifacts (logical OR of hf and bb artifacts)
```

The second function works in tandem with the first and computes slow-oscillation power and phase histograms
``` matlab
SOpowerphaseHistogram(data_trunc, Fs, stats_table.PeakFrequency, stats_table.PeakTime, <options>);
```
It uses the following inputs:
``` matlab
%    REQUIRED:
%       EEG: 1xN double - timeseries EEG data --required
%       Fs: numerical - sampling frequency of EEG (Hz) --required
%       TFpeak_freqs: Px1 - frequency each TF peak occurs (Hz) --required
%       TFpeak_times: Px1 - times each TF peak occurs (s) --required
%
%    OPTIONAL:
%       TFpeak_stages: Px1 - sleep stage each TF peak occurs 5=W,4=R,3=N1,2=N2,1=N3
%       stage_vals:  1xS double - numeric stage values 5=W,4=R,3=N1,2=N2,1=N3
%       stage_times: 1xS double - stage times
%       freq_range: 1x2 double - min and max frequencies of TF peak to include in the histograms
%                   (Hz). Default = [0,40]
%       freq_binsizestep: 1x2 double - [size, step] frequency bin size and bin step for frequency
%                         axis of SO power/phase histograms (Hz). Default = [1, 0.2]
%       SOpower_range: 1x2 double - min and max SO power values to consider in SO power analysis.
%                      Default calculated using min and max of SO power
%       SOpower_binsizestep: 1x2 double - [size, step] SO power bin size and step for SO power axis
%                            of histogram. Units are radians. Default
%                            size is (SOpower_range(2)-SOpower_range(1))/5, default step is
%                            (SOpower_range(2)-SOpower_range(1))/100
%       SOphase_range: 1x2 double - min and max SO phase values (radians) to consider in SO phase analysis.
%                                   Default is [-pi, pi]
%       SOphase_binsizestep: 1x2 double - [size, step] SO phase bin size and step for SO phase axis
%                            of histogram. Units are radians. Default size is 2*pi/5, default step is 2*pi/100
%       SO_freqrange: 1x2 double - min and max frequencies (Hz) considered to be "slow oscillation".
%                     Default = [0.3, 1.5]
%       SOPH_stages: stages in which to restrict the SOPHs. Default: 1:3 (NREM only)
%                    W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
%       compute_rate: logical - histogram output in terms of TFpeaks/min instead of count.
%                               Default = true.
%       SOpower_outlier_threshold: double - cutoff threshold in standard deviation for excluding outlier SOpower values.
%                                  Default = 3.
%       SOpower_norm_method: char - normalization method for SOpower. Options:'pNshiftS', 'percent', 'proportion', 'none'. Default: 'p2shift1234'
%                         For shift, it follows the format pNshiftS where N is the percentile and S is the list of stages (5=W,4=R,3=N1,2=N2,1=N3).
%                         (e.g. p2shift1234 = use the 2nd percentile of stages N3, N2, N1, and REM,
%                               p5shift123 = use the 5th percentile of stages N3, N2 and N1)
%       SOpower_retain_Fs: logical - whether to upsample calculated SOpower to the sampling rate of EEG. Default = true
%       SOpower_min_time_in_bin: numerical - time (minutes) required in each SO power bin to include
%                                          in SOpower analysis. Otherwise all values in that SO power bin will
%                                          be NaN. Default = 10.
%       SOphase_filter: 1xF double - custom filter that will be used to estimate SOphase
%       SOphase_norm_dim: integer - which dimension of the SOphase histogram to normalize to add to 1. Default = 1
%       EEG_times: 1xN double - times for each EEG sample. Default = (0:length(EEG)-1)/Fs
%       time_range: 1x2 double - min and max times for which to include TFpeaks. Also used to normalize
%                   SOpower. Default = [EEG_times(1), EEG_times(end)]
%       isexcluded: 1xN logical - marks each timestep of EEG as artifact or non-artifact. Default = all false.
%
%       plot_on: logical - SO power histogram plots. Default = false
%       verbose: logical - Verbose output. Default = true
```
The outputs are:
``` matlab
%       SOpow_mat:    2D double - SO power histogram data
%       SOphase_mat:  2D double - SO phase histogram data
%       SOpow_bins:   1D double - SO power bin center values for dimension 1 of SOpow_mat
%       SOphase_bins: 1D double - SO phase bin center values for dimension 1 of SOphase_mat
%       freq_bins:    1D double - frequency bin center values for dimension 2
%                     of SOpow_mat and SOphase_mat
%       SOpow_TIB:    1xT double - time (minutes) in each SOpower bin for all stages 1-5 (0min if not in SOPH_stages)
%       SOphase_TIB:  1xT double - time (minutes) in each SOphase bin for all stages 1-5 (0min if not in SOPH_stages)
%       peak_SOpower: 1xP double - normalized slow oscillation power at each TFpeak
%       peak_SOphase: 1xP double - slow oscillation phase at each TFpeak
%       peak_selection_inds: 1xP logical - which TFpeaks are counted in the histogram
%       SOpower: 1xM double - timeseries SO power data
%       SOpower_times: 1xM double - timeseries SO power times
%       SOphase: 1xN double - timeseries SO phase data
%       SOphase_times: 1xN double - timeseries SO phase times
```

# Documentation and Tutorials

For more comprehensive documentation see [this tutorial on the Prerau Lab site](https://prerau.bwh.harvard.edu/DYNAM-O/)

## Algorithm Summary
Here we provide a brief summary of the steps for the TF-peak detection as well as for the SO-power histogram. 

### Transient Oscillation Detection 
Inputs: Raw EEG timeseries and Spectrogram of EEG timeseries 
1. Artifact Detection 
2. Baseline Subtraction
    * Find 2nd percentile of non-artifact data and subtract from spectrogram 
3. Spectrogram Segmentation
    * Breaks spectrogram into 30 second segments enabling parallel processing on each segment concurrently
4. Extract TF-peaks for each segment (in parallel):
    * Downsample high resolution segment via decimation depending on downsampling settings. Using a lower resolution version of the segment for watershed and merging allows a large runtime decrease.
    * Run Matlab watershed image segmentation on lower resolution segment
    * Create adjacency list for each region found from watershed
      * Loop over each region and dialate slightly to find all neighboring regions
    * Merge over-segmented regions to form large, distinct TF-peaks 
      * Calculate a merge weight for each set of neighbors
      * Regions are merged iteratively starting with the largest merge weight, and affected merge weights are recalculated after each merge until all merge weights are below a set threshold.
    * Interpolate TF-peak boundaries back onto high-resolution version of spectrogram segment
    * Reject TF-peaks below bandwidth and duration cutoff criteria (done here to reduce number of peaks going forward to save on computation time)
    * Trim all TF-peaks to 80% of their total volume
    * Compute and store statistics for each peak (pixel indices, boundary indices, centroid frequency and time, amplitude, bandwidth, duration, etc.)
5. Package TF-peak statistics from all segments into a single feature matrix
6. Reject TF-peaks above or below bandwidth and duration cutoff criteria

### SO-power Histogram Calculation
Inputs: Raw EEG timeseries and TF-peak frequencies and times
1. Compute SO-Power on artifact rejected EEG timeseries
    * Compute multitaper spectrogram of EEG timeseries (30s windows, 15s stepsize, 29 tapers, 1Hz resolution)
    * Integrate spectrogram between 0.3 and 1.5 Hz 
2. Normalize SO-Power via selected method
    * Percent normalization: Subtracts 1st percentile and divides by 99th percentile. Used only if subjects all reach stage 3
    * p5shift normalization: Subtracts 5th percentile, important for comparing across subjects
    * proportion normalization: Ratio of SO-power to total power
    * No normalization
3. Create SO-Power and frequency bins based on desired SO-Power and frequency window and step sizes
4. Compute TF-peak rate in each pixel of SO-Power-Frequency histogram
    * Count how many TF-peaks fall into each pixel's given frequency and SO-Power bin
    * Divide by total sleep time spent in the given SO-Power bin
 
### SO-phase Histogram Calculation
Inputs: Raw EEG timeseries and TF-peak frequencies and times
1. Compute SO-Phase on 0.3-1.5Hz bandpassed EEG timeseries
    * Compute Herbert transform of bandpassed signal
    * Unwrap Herbert phase (so that it is in terms of cumulative radians)
    * Interpolate phase at each TF-peak time 
    * Rewrap phase of each TF-peak so that 0 radians corresponds to SO peak and -pi or pi corresponds to SO trough
2. Create SO-Phase and frequency bins based on desired SO-Phase and frequency window and step sizes
3. Compute TF-peak rate in each pixel of SO-Phase-Frequency histogram
    * Count how many TF-peaks fall into each pixel's given frequency and SO-Phase bin
    * Divide by total sleep time spent in the given SO-Phase bin
4. Normalize each frequency row of histogram so that row integration adds to 1
 
## Optimizations 
This code is an optimized version of what was used in Stokes et. al., 2022. The following is a list of the changes made during optimization. The original unoptimized paper code can be found [here](https://github.com/preraulab/DYNAM-O/tree/transient_oscillation_paper).
* Candidate TF-Peak regions that are below the duration and bandwidth cutoffs are now removed prior to trimming and peak property calculations
* Empty regions that come out of the merge procedure are now removed prior to trimming and peak property calculations
* Watershed and the merging procedure now run on a lower resolution spectrogram (downsampled from the input spectrogram using decimation) to get the rough watershed regions, which are then mapped back onto the high-resolution spectrogram, from which trimming and peak property calculations are done.
* Spectrogram segment size reduced from 60s to 30s
* During the merging process, the adjacency list is now stored as unidirectional graph (instead of bidirectional), and only the larger of the merging weights between two regions is stored during iterative merge weight computation. 

## Repository Structure
The contents of the "toolbox" folder is organized as follows, with key functions:

```
.REPO_ROOT
├── example_script.m:         Quick start example, computes the SO-Power and SO-Phase histograms, and plots a summary 
│                                 figure. Uses example data contained in example_data folder.│   
├── example_data/  CONTAINS EXAMPLE DATA
└── toolbox/       MAIN TOOLBOX FOLDER  
    ├── SOphase_filters/   
    │         - SOphase_filters.mat: File containing precomputed digital filters used in the SO-Phase calculation
    ├── SOpowphase_functions/
    │         - SOpowerphaseHistogram.m: Compute SO-power and SO-phase histograms 
    ├── TFpeak_functions/
    │         - computeTFPeaks.m: Run watershed pipeline on spectrogram to extract time-frequency peaks  
    └── helper_functions/
              - Contains various utility functions for spectral estimation and plotting
```
