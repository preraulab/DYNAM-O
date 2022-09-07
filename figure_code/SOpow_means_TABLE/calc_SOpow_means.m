function [means, SDs] = calc_SOpow_means(SOpows, subjs)
% Calculate means and SDs for SOpower time traces
%
% Inputs:
%       SOpows: PxMxN cell - P is normalization method, M is electrode, N
%       is night. Each cell contains a Qx1 cell where Q is the number of
%       subjects. Each of these nested cells contains an Rx2 double where the
%       first column is the SOpower values and the second column is the
%       timestamps for each SOpower value. 
%       subjs: Qx1 array - ID of each subject in SOpows
%
% Outputs:
%       None
%
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - Tom Possidente 08/22/2022
%%%************************************************************************************%%%%
%% Deal with inputs
assert(nargin == 2, 'Requires exactly 2 inputs');

% Get number of normalization methods, electrodes, nights, subjs
[num_norms, num_elects, num_nights] = size(SOpows);
num_subjs = length(subjs);

% Create output variables
means = nan(num_norms, num_elects, num_subjs, num_nights, 5);
SDs = nan(num_norms, num_elects, num_subjs, num_nights, 5);

% Loop through subjs, nights, elects, norms, stages, to get mean/SD of SOpows
for ss = 1:num_subjs
    for ni = 1:num_nights
        
        % Get stages for each subject/night 
        [~, ~, ~, ~, stages] = load_Lunesta_data(subjs(ss), ni, 'SZ', false , 'channels', 'C3');

        for ee = 1:num_elects
            for nn = 1:num_norms
                disp([num2str(ee),' ', num2str(nn), ' ', num2str(ni)])
                if ~isempty(SOpows{nn,ee,ni}{ss})
                    
                    % extract SOpow times for single subj/nigt/norm/elect
                    SOpow_times = SOpows{nn,ee,ni}{ss}(:,2); 
                    
                    % Get stage at SOpower time stamps
                    stages_SOtimes = interp1(stages.time, stages.stage, SOpow_times, 'nearest');

                    for st = 1:5
                        
                        % Get mean and SD of SOpower for a single stage
                        stage_inds = stages_SOtimes == st;
                        means(nn,ee,ss,ni,st) = mean(SOpows{nn,ee,ni}{ss}(stage_inds,1),'omitnan');
                        SDs(nn,ee,ss,ni,st) = std(SOpows{nn,ee,ni}{ss}(stage_inds,1), 'omitnan');

                    end
                end
            end
        end
    end
end



end