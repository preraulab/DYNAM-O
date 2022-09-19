# Transient Oscillations Paper - 

### The code here was used for to generate all data, analyses, and figures from the following publication: 
> Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach, Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis for Electroencephalographic Phenotyping and Biomarker Identification, Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
--- 

## Table of Contents
* [General Information](#general-information)
* [Example](#example)
* [Repository Structure](#repository-structure)
* [Parameters](#parameters)
* [Citations](#citations)
* [Status](#status)
* [References](#references)

## General Information

<br/>
<p align="center">
<img src="https://prerau.bwh.harvard.edu/images/Transient%20Oscillation%20Graphical%20Abstract.png" width="600" />
</p>
<p align="center">
  <sup><sub>Stokes et. al., 2022</sup></sub>
</p>

This repository contains code to detect time-frequency peaks (TF-peaks) in a spectrogram of EEG data using the watershed image segmentation algorithm. TF-peaks represent transient oscillatory neural activity at specific frequencies with sleep spindles (a key neural biomarker) comprising a subset of TF-peaks<sup>1</sup>. An explanation of the method used to compute the multitaper spectrogram of EEG data can be found [here](https://github.com/preraulab/multitaper_toolbox). The watershed method treats the spectrogram image as a topography and identifies the catchment basins (troughs), into which water falling on the terrain would collect, thus identifying local maxima. To reduce over-segmentation, neighboring regions are merged based on a novel merge rule designed to form complete, distinct TF-peaks in the spectrogram topography. 

<br/>
<p align="center">
<img src="https://prerau.bwh.harvard.edu/images/watershed_summary_graphic.png" width="400" />
</p>
<p align="center">
  <sup><sub>Stokes et. al., 2022</sup></sub>
</p>

This repository also contains code to create slow-oscillation power (SO-power) and phase (SO-phase) histograms from the extracted TF-peak data. These histograms characterize the distribution of TF-peak rate (density) as function of oscillation frequency and SO-power or SO-phase. This creates a comprehensive representation of transient oscillation dynamics at different time scales, providing a highly informative new visualization technique and powerful basis for EEG phenotyping and biomarker identification in pathological states. To form the SO-power histogram, the central frequency of the TF-peak and SO-power at which the peak occured are computed. Each TF-peak is then sorted into its corresponding 2D frequency x SO-power bin and the count in each bin is normalized by the total sleep time in that SO-power bin to obtain TF-peak density in each grid bin. The same process is used to form the SO-phase histograms except the SO-phase at the time of the TF-peak is used in place of SO-power, and each row is normalized by the total peak count in the row to create probability densities.
<br/>

<br/>
<p align="center">
<img src="https://prerau.bwh.harvard.edu/images/power_phase_histogram_schematic.png" width="400" />
</p>
<p align="center">
  <sup><sub>Stokes et. al., 2022</sup></sub>
</p>

<br/>
<br/>

## Example
An [example script](https://github.com/preraulab/watershed_TFpeaks_toolbox/blob/master/example_script.m) is provided in the repository that takes an excerpt of a single channel of [example sleep EEG data](https://github.com/preraulab/watershed_TFpeaks_toolbox/blob/master/example_data/example_data.mat) and runs the TF-peak detection watershed algorithm and the SO-power and SO-phase analyses, plotting the resulting hypnogram, spectrogram, TF-peak scatterplot, SO-power histogram, and SO-phase histogram (shown below). It is recommended to use parallel processing to speed up the watershed and merging computation. The extract_TFpeaks function should automatically try to open parallel processing with the default number of cores. To check how many cores your machine has, use the `feature('numcores')` command. To turn on parallel processing with a specific number of cores, use the `parpool(x)` command, where x is the number of cores. 

<br/>
<p align="center">
<img src="https://prerau.bwh.harvard.edu/images/toolbox_example_segment.png" width="600" />
</p>

<br/>
<br/>

## Repository Structure
The contents of the "toolbox" folder is organized as follows:
* SOphase_filters:
  - SOphase_filters.mat: File containing precomputed digital filters used in the SO-Phase calculation. If a filter is not provided as an argument to compute_SOPhase(), it will look for a suitable filter in this .mat file. Using precomputed filters saves computing time.
* SOpowphase_functions: Functions used to compute the SO Power and Phase histograms
  - Key Functions:
    - SOpower_histogram: Top level function to compute SO Power histogram from EEG data and TF-peak times and frequencies.
    - SOphase_histogram: Top level function to compute SO Phase histogram from EEG data and TF-peak times and frequencies. 
* helper_functions: Utility functions used for plotting figures and performing generic small computations, plus the multitaper spectrogram function. 
* watershed_functions: Functions involved in carrying out the watershed image segmentation algorithm on EEG spectrograms
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


## References
1. Dimitrov, T., He, M., Stickgold, R. & Prerau, M. J. Sleep spindles comprise a subset of a broader class of electroencephalogram events. Sleep (2021). doi:10.1093/sleep/zsab099

