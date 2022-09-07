function peak_powdynamics_summary_plot(subj, night, elect_name, powhist, peak_data, SOpow_cbins, freq_cbins, ...
                                       PIB_allstages)
% Plots summary of many SO power histogram features as well as spectrogram.
% NOTE: must run matlab with vglrun to plot properly: use command: vglrun -d "$DISPLAY" matlab
%
% Inputs:
%       subj: int - subject number (ID) whose data is to be used for plotting
%       night: int - night number to be used (1 or 2)
%       elect_name: char - electrode to be used  
%       powhist: 2D double - SO power histogram [freq, SOpow]
%       peak_data: Px5 double - specifies the following for each peak
%                  detected for the subj, night, and electrode being used:
%                  col1=nans, col2=peak time, col3=logical peak selection, col4=peak freq,
%                  col5=peak height
%       SOpow_cbins: 1D double - SO power bin centers for powhist
%       freq_cbins: 1D double - Frequency bin centers for powhist
%       PIB_allstages: 5xB double - Proportion of time in each SOpower bin
%                      for each of the 5 stages (N3, N2, N1, REM, NREM)
%
% Outputs:
%       None
%
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - Tom Possidente 1/03/2022
%%%************************************************************************************%%%



% Lun03 C3 night 2

disp(['generating figure for ',num2str(subj),'_',elect_name,'_',num2str(night)]);

% Load in subject data
[data, Fs, ~, ~, stages] = load_Lunesta_data(subj, night, 'SZ', false, 'channels', elect_name);
stages.pick_t = true(1,length(stages.stage)); % use all timepoints
stages.stage = stages.stage';
stages.time = stages.time';

% Call main plotting function
peak_dynamics_summary(data, stages, Fs, peak_data, powhist, SOpow_cbins, freq_cbins, PIB_allstages);

end

