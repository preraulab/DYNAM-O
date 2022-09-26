# Transient Oscillation Dynamics Toolbox v1.0 - Prerau Laboratory ([sleepEEG.org](https://prerau.bwh.harvard.edu/))

### This repository contains the updated and optimized toolbox code for extracting time-frequency peaks from EEG data and creating slow-oscillation power and phase histograms. 

## Citation

Please cite the following paper when using this package: 
> Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach, Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis for Electroencephalographic Phenotyping and Biomarker Identification, Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223

which can be referred to in the text as:
> Transient Oscillation Dynamics Toolbox v1.0 (sleepEEG.org/transient_oscillations)

The paper is available open access at https://doi.org/10.1093/sleep/zsac223

### Preceptually Uniform Colormaps
Included in this package are versions of a rainbow and "gouldian" colormap, designed to be more perceptually uniform than jet and parula, respectively. If you use them, please cite:
> Peter Kovesi. Good Colour Maps: How to Design Them. arXiv:1509.03700 [cs.GR] 2015 https://arxiv.org/abs/1509.03700
--- 

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

An [example script](https://github.com/preraulab/watershed_TFpeaks_toolbox/blob/master/example_script.m) is provided in the repository that takes an excerpt of a single channel of [example sleep EEG data](https://github.com/preraulab/watershed_TFpeaks_toolbox/blob/master/example_data/example_data.mat) and runs the TF-peak detection watershed algorithm and the SO-power and SO-phase analyses, plotting the resulting hypnogram, spectrogram, TF-peak scatterplot, SO-power histogram, and SO-phase histogram (shown below). 

After installing the package, execute the example script on the command line:

``` matlab
> example_script;
```

Once a parallel pool has started (if applicable), the following result should be generated: 

<figure ><img src="https://prerau.bwh.harvard.edu/images/segment_fast.png" alt="example segment" width="40%;">
<figcaption><b>Output from the example segment of data provided with the toolbox.</b></figcaption></figure>
<br/><br/>

This is the general output for the algorithm. On top is the hypnogram, EEG spectrogram, and the SO-power trace. In the middle is a scatterplot of the TF-peaks with x = time, y = frequency, size = peak prominence, and color = SO-phase. On the bottom are the SO-power and SO-phase histograms.

Once the segment has succesfully completed, you can run the full night of data by changing the following line in the example script under `DATA SETTINGS`, such that the variable data_range changes from 'segment' to 'night'.

``` matlab
%%Select 'segment' or 'night' for example data range
data_range = 'night';
```
This should produce the following output:
<figure><img src="https://prerau.bwh.harvard.edu/images/night_fast.png" alt="full night example" style="width:40%"> <figcaption align = "center"><b>Output from the example full night of data provided with the toolbox.</b></figcaption></figure>
<br/><br/>

For more in-depth information and documentation on the Transient Oscillation Dynamics algorithms visit [the Prerau Lab website.](https://prerau.bwh.harvard.edu/transient-oscillations-dynamics)
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

-	'none': No normalization. The unaltered SO-power in dB.
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
The main function to run is run_watershed_SOpowphase.m

``` matlab
run_watershed_SOpowphase(data, Fs, stage_times, stage_vals, 'time_range', time_range, 'quality_setting', 
                         quality_setting, 'SOpower_norm_method', SOpower_norm_method);
```
It uses the following basic inputs:
``` matlab
%       data (req):                [1xn] double - timeseries data to be analyzed
%       Fs (req):                  double - sampling frequency of data (Hz)
%       stage_times (req):         [1xm] double - timestamps of stage_vals
%       stage_vals (req):          [1xm] double - sleep stage values at eaach time in
%                                  stage_times. Note the staging convention: 0=unidentified, 1=N3,
%                                  2=N2, 3=N1, 4=REM, 5=WAKE
%       t_data (opt):              [1xn] double - timestamps for data. Default = (0:length(data)-1)/Fs;
%       time_range (opt):          [1x2] double - section of EEG to use in analysis
%                                  (seconds). Default = [0, max(t)]
%       stages_include (opt):      [1xp] double - which stages to include in the SOpower and
%                                  SOphase analyses. Default = [1,2,3,4]
%       SOpower_norm_method (opt): character - normalization method for SO-power
```

The main outputs are:
``` matlab
%       peak_props:   table - time, frequency, height, SOpower, and SOphase
%                     for each TFpeak
%       SOpow_mat:    2D double - SO power histogram data
%       SOphase_mat:  2D double - SO phase histogram data
%       SOpow_bins:   1D double - SO power bin center values for dimension 1 of SOpow_mat
%       SOphase_bins: 1D double - SO phase bin center values for dimension
%                     1 of SOphase_mat
%       freq_bins:    1D double - frequency bin center values for dimension 2
%                     of SOpow_mat and SOphase_mat
%       spect:        2D double - spectrogram of data
%       stimes:       1D double - timestamp bin center values for dimension 2 of
%                     spect
%       sfreqs:       1D double - frequency bin center values for dimension 1 of
%                     spect
%       SOpower_norm: 1D double - normalized SO-power used to compute histogram
%       SOpow_times:  1D double - SO-power times
```

View the full documentation for all parameters and outputs.

# Documentation and Tutorials

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
This code is an optimized version of what was used in Stokes et. al., 2022. The following is a list of the changes made during optimization. The original unoptimized paper code can be found [here](https://github.com/preraulab/watershed_TFpeaks_toolbox/tree/transient_oscillation_paper).
* Candidate TF-Peak regions that are below the duration and bandwidth cutoffs are now removed prior to trimming and peak property calculations
* Empty regions that come out of the merge procedure are now removed prior to trimming and peak property calculations
* Watershed and the merging procedure now run on a lower resolution spectrogram (downsampled from the input spectrogram using decimation) to get the rough watershed regions, which are then mapped back onto the high-resolution spectrogram, from which trimming and peak property calculations are done.
* Spectrogram segment size reduced from 60s to 30s
* During the merging process, the adjacency list is now stored as unidirectional graph (instead of bidirectional), and only the larger of the merging weights between two regions is stored during iterative merge weight computation. 

## Repository Structure
The contents of the "toolbox" folder is organized as follows:

```
/
│   example_script.m: Runs the full TFpeak finding algorithm, computes the SO-Power and SO-Phase histograms, and plots a summary figure. Uses example data │   contained in example_data folder.
│
└───/toolbox/
    │
    └───/SOphase_filters/ - Contains pre-computed filters for SO-phase
    │       - SOphase_filters.mat: File containing precomputed digital filters used in the SO-Phase calculation. If a filter is not provided as an argument to compute_SOPhase(), it will look for a suitable filter in this .mat file. Using precomputed filters saves computing time.
    │     
    └─── /SOpowphase_functions/ - Functions used to compute the SO Power and Phase histograms
    │    - Key Functions:
    │      - SOpower_histogram.m: Top level function to compute SO Power histogram from EEG data and TF-peak times and frequencies.
    │      - SOphase_histogram.m: Top level function to compute SO Phase histogram from EEG data and TF-peak times and frequencies. 
    │ 
    └─── /helper_functions/ - Utility functions used for plotting figures and performing generic small computations, plus the multitaper spectrogram │   function. 
    │ 
    └─── /watershed_functions/ Functions involved in carrying out the watershed image segmentation algorithm on EEG spectrograms
        - Key Functions:
          - extract_TFpeaks.m: Top level function to run the watershed pipeline on a given spectrogram, 
            including baseline removal, data chunking, imageegmentation, peak merging, peak trimming, and 
            calculating and saving out the TF-peak statistics.  
```
