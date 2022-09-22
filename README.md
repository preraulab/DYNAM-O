# Transient Oscillation Dynamics Toolbox v1.0 - Prerau Laboratory (sleepEEG.org)

### This repository contains the updated and optimized toolbox code for extracting time-frequency peaks from EEG data and creating slow-oscillation power and phase histograms. 

## Citation

Please cite the following paper when using this package: 
> Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach, Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis for Electroencephalographic Phenotyping and Biomarker Identification, Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223

as well as:
> Transient Oscillation Dynamics Toolbox v1.0 (sleepEEG.org/transient_oscillations)

The paper is available open access at https://doi.org/10.1093/sleep/zsac223

--- 

## Table of Contents
* [Overview](#general-information)
* [Example](#example)
* [Algorithm Description](#algorithm-description)
* [Optimizations](#optimizations)
* [Repository Structure](#repository-structure)
* [Parameters](#parameters)
* [Citations](#citations)
* [Status](#status)

## Overview 

This repository contains code to detect time-frequency peaks (TF-peaks) in a spectrogram of EEG data using the approach based on the one described in ([Stokes et. al, 2022](https://doi.org/10.1093/sleep/zsac223)). TF-peaks represent transient oscillatory neural activity with in the EEG, which by definition will appear as a peak in the time-frequency topography of the spectrogram. Within sleep, perhaps the most important transient EEG oscillation is the sleep spindle, which has been linked to memory consolidation, and changes spindle activity have been linked with natural aging as well as numerous psychiatric and neurodegenerative disorders. This approach extracts TF-peaks by identifies salient peaks in the time-frequency topography of the spectrogram, using a method based on the watershed algorithm, which was original developed for computer vision applications. The dynamics of the TF-peaks can then be described in terms of continuous correlates of sleep depth and cortical up/down states using representations called slow-oscillation (SO) power and phase histograms. This package provides the tools for TF-peak extraction as well as the creation of the SO-power/phase histograms.

## Background and Motivation

Scientists typically study brain activity during sleep using the electroencephalogram, or EEG, which measures brainwaves at the scalp. Starting in the mid 1930s, the sleep EEG was first studied by looking at the traces of brainwaves drawn on a paper tape by a machine. Many important features of sleep are still based on what people almost a century ago could most easily observe in the complex waveform traces. Even the latest machine learning and signal processing algorithms for detecting sleep waveforms are judged against their ability to recreate human observation. What then can we learn if we expand our notion of sleep brainwaves beyond what was historically easy to identify by eye? 

<figure><img src="https://prerau.bwh.harvard.edu/images/EEG-time%20trace.png" alt="eeg trace" style="width:100%">
<figcaption align = "center"><b>An original paper tape trace of EEG from the 1930s, showing sleep spindles. (Loomis et. al 1935)</b></figcaption></figure>
<br><br><br>

One particularly important set of sleep brainwave events are called sleep spindles. These spindles are short oscillation waveforms, usually lasting less than 1-2 seconds, that are linked to our ability to convert short-term memories to long-term memories. Changes in spindle activity have been linked with numerous disorders such as schizophrenia, autism, and Alzheimer’s disease, as well as with natural aging. Rather than looking for spindle activity according to the historical definition, we develop a new approach to automatically extract tens of thousands of short spindle-like transient oscillation waveform events from the EEG data throughout the entire night. This approach takes advantage of the fact that transient oscillations will looks like high-power regions in the spectrogram, which represent salient time-frequency peaks (TF-peaks) in the spectrogram.

<figure><img src="https://prerau.bwh.harvard.edu/images/TF-peak%20detection_small.png" alt="tf-peaks" style="width:100%"> <figcaption align = "center"><b>Transient oscillation activity in the time domain will appear as contiguous high-power regions in the spectrogram, which represent salient peaks (TF-peaks) in the time-frequency topography.</b></figcaption></figure>
<br><br><br>

The TF-peak detection method is based on the watershed algorithm, which is commonly used in computer vision applications to segment an image into distinct objects. The watershed method treats an image as a topography and identifies the catchment basins, that is, the troughs, into which water falling on the terrain would collect.

<figure><img src="https://prerau.bwh.harvard.edu/images/SOpowphase_small.png" alt="SO-power/phase histograms" style="width:100%"> <figcaption align = "center"><b>Slow-oscillation power and phase histograms create representations of TF-peak activity as function of continuous depth-of-sleep and as a function of timing with respect to cortical up/down states.</b></figcaption></figure>
<br><br><br>

Next, instead of looking at the waveforms in terms of fixed sleep stages (i.e., Wake, REM, and non-REM stages 1-3) as di standard sleep studies, we can characterize the full continuum of gradual changes that occur in the brain during sleep. We use the slow oscillation power (SO-phase) as a metric of continuous depth of sleep, and slow-oscillation phase (SO-phase) to represent timing with respect to cortical up/down states. By characterizing TF-peak activity in terms of these two metrics, we can create graphical representations, called SO-power and SO-phase histograms, which provide a powerful visualization of the activity of all the waveforms as a function of continuous sleep depth and synchronized activity in the cortex. 


Typically, transient sleep events such as spindles are described in terms of fixed sleep stages (i.e., Wake, REM, NREM stages 1-3). By descr

<p align="center">
<img src="https://prerau.bwh.harvard.edu/images/watershed_summary_graphic.png" width="400" />
</p>
<p align="center">
  <sup><sub>Stokes et. al., 2022</sup></sub>
</p>

This repository also contains code to create slow-oscillation power (SO-power) and phase (SO-phase) histograms from the extracted TF-peak data. These histograms characterize the distribution of TF-peak rate (density) as function of oscillation frequency and SO-power or SO-phase. This creates a comprehensive representation of transient oscillation dynamics at different time scales, providing a highly informative new visualization technique and powerful basis for EEG phenotyping and biomarker identification in pathological states. To form the SO-power histogram, the central frequency of the TF-peak and SO-power at which the peak occured are computed. Each TF-peak is then sorted into its corresponding 2D frequency x SO-power bin and the count in each bin is normalized by the total sleep time in that SO-power bin to obtain TF-peak density in each grid bin. The same process is used to form the SO-phase histograms except the SO-phase at the time of the TF-peak is used in place of SO-power, and each row is normalized by the total peak count in the row to create probability densities.

## Quick Start: Using the Transient Oscillation Dynamics Toolbox
An [example script](https://github.com/preraulab/watershed_TFpeaks_toolbox/blob/master/example_script.m) is provided in the repository that takes an excerpt of a single channel of [example sleep EEG data](https://github.com/preraulab/watershed_TFpeaks_toolbox/blob/master/example_data/example_data.mat) and runs the TF-peak detection watershed algorithm and the SO-power and SO-phase analyses, plotting the resulting hypnogram, spectrogram, TF-peak scatterplot, SO-power histogram, and SO-phase histogram (shown below). It is recommended to use parallel processing to speed up the watershed and merging computation. The extract_TFpeaks function may automatically try to open parallel processing with the default number of cores. To check how many cores your machine has, use the `feature('numcores')` command. To turn on parallel processing with a specific number of cores, use the `parpool(x)` command, where x is the number of cores, before running the script. 

<br/>
<p align="center">
<img src="https://prerau.bwh.harvard.edu/images/toolbox_example_segment.png" width="600" />
</p>

<br/>
<br/>

## Algorithm Description
### Transient Oscillation Detection 
Inputs: Raw EEG timeseries and Spectrogram of EEG timeseries 
1. Artifact Detection 
    * iteratively marks artifacts 3.5 SDs above the mean
2. Baseline Subtraction
    * Find 2nd percentile of non-artifact data and subtract from spectrogram 
3. Spectrogram Segmentation
    * Breaks spectrogram into 30 second segments enabling parallel processing on each segment concurrently
4. Extract TF-peaks for each segment (in parallel):
    * Downsample high resolution segment via decimation depending on downsampling settings. Using a lower resolution version of the segment for watershed and merging allows a large runtime decrease.
    * Run Matlab watershed image segmentation on lower resolution segment
    * Create adjacency list for each region found from watershed
      * loop over each region and dialate slightly to find all neighboring regions
    * Merge over-segmented regions to form large, distinct TF-peaks 
      * calculate a merging weight for each set of neighbors
        * C = maximum value in boundary between regions - minimum value of total boundary of region 1
        * D = maximum height of region 2 - maximum value in boundary between regions
        * merge weight = C - D
      * regions are merged iteratively starting with the largest merge weight, and affected merge weights are recalculated after each merge until all merge weights are below a set threshold.
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
* Watershed and the merging procedure now run on a lower resolution spectrogram (downsampled from the input spectrogram using decimation) to get the rough watershed regions,w hich are then mapped back onto the high-resolution spectrogram, from which trimming and peak property calculations are done.
* Spectrogram segment size reduced from 60s to 30s
* During the merging process, the adjacency list is now stored as unidirectional graph (instead of bidirectional), and only the larger of the merging weights between two regions is stored during iterative merge weight computation. 

<br/>
<br/>

## Repository Structure
The contents of the "toolbox" folder is organized as follows:
* example_script
  - Runs the full TFpeak finding algorithm, computes the SO-Power and SO-Phase histograms, and plots a summary figure. Uses example data contained in example_data folder.
* toolbox
  - SOphase_filters:
    - SOphase_filters.mat: File containing precomputed digital filters used in the SO-Phase calculation. If a filter is not provided as an argument to compute_SOPhase(), it will look for a suitable filter in this .mat file. Using precomputed filters saves computing time.
  - SOpowphase_functions: Functions used to compute the SO Power and Phase histograms
    - Key Functions:
      - SOpower_histogram: Top level function to compute SO Power histogram from EEG data and TF-peak times and frequencies.
      - SOphase_histogram: Top level function to compute SO Phase histogram from EEG data and TF-peak times and frequencies. 
  - helper_functions: Utility functions used for plotting figures and performing generic small computations, plus the multitaper spectrogram function. 
  - watershed_functions: Functions involved in carrying out the watershed image segmentation algorithm on EEG spectrograms
    - Key Functions:
      - extract_TFpeaks: Top level function to run the watershed pipeline on a given spectrogram, including baseline removal, data chunking, image segmentation, peak merging, peak trimming, and calculating and saving out the TF-peak statistics.  
  

<br/>
<br/>

## Parameters
Input and output parameter descriptions and function descriptions for each function can be found in the documentation string under the function definition in each function file (.m). The top-level function to identify TF-peaks using the watershed algorithm is the [extract_TFpeaks](https://github.com/preraulab/watershed_TFpeaks_toolbox/blob/master/all_functions/watershed_functions/extract_TFpeaks.m) function. The top level functions to compute and plot the SO-power and SO-phase histograms are [SOpower_histogram](https://github.com/preraulab/watershed_TFpeaks_toolbox/blob/master/all_functions/SOpowphase_functions/SOpower_histogram.m) and [SOphase_histogram](https://github.com/preraulab/watershed_TFpeaks_toolbox/blob/master/all_functions/SOpowphase_functions/SOphase_histogram.m).

<br/>
<br/>

## Citations
The code contained in this repository is companion to the paper:  
> Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach, Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis for Electroencephalographic Phenotyping and Biomarker Identification, Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223

which should be cited for academic use of this code.  

<br/>
<br/>


## Status 
All implementations are complete and functional, but are subject to change.

<br/>
<br/>

