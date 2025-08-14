function SOPHs = reject_TIB(SOPHs, SOpow_TIBs, stage_inds, TIB_required, interp_on)
%REJECT_TIB  Reject columns in the Slow Oscillation Power Histogram (SOPH) if the time is below the minimum time in bin (TIB)
%
%   Usage:
%       SOPHs = reject_TIB(SOPHs, SOpow_TIBs, stage_inds, TIB_required, interp_on)
%
%   Input:
%       SOPHs: MxNxP matrix - Slow Oscillation Power Histograms (SOPHs) where M is the number of time bins, N is the number of frequency bins, and P is the number of instances -- required
%       SOpow_TIBs: LxRxP matrix - Time in bin (TIB) values where L is the number of time bins, R is the number of stages, and P is the number of instances -- required
%       stage_inds: 1xQ vector - Indices of the stages to consider - 5=W, 4=R, 3=N1 2=N2 1=N3
%       (default: 1:3)
%       TIB_required: double - Minimum time in bin (TIB) required for a column to be retained (default: 10)
%       interp_on: logical - Flag to enable interpolation for NaN columns (default: true)
%
%   Output:
%       SOPHs: MxNxP matrix - SOPHs with columns rejected if their TIB is below the required threshold
%
%   Description:
%       This function takes SOPHs (Slow Oscillation Power Histograms) and associated TIB values and removes
%       columns from SOPHs where the TIB is less than the specified requirement. Optionally, it can interpolate 
%       across any resulting NaN columns.
%
% Copyright 2023 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

if nargin<3
    stage_inds = 1:3;
end

if nargin<4
    TIB_required = 10;
end

if nargin<5
    interp_on = true;
end


%Remove the columns where TIB is less than requirement
for ii = 1:size(SOPHs,3)
    SOPH_mat = squeeze(SOPHs(:,:,ii));

    %Remove columns below minimum TIB
    nan_inds = sum(SOpow_TIBs(:,stage_inds,ii),2)<TIB_required;
    SOPH_mat(nan_inds,:) = nan;

    %Interpolate across any NaN columns
    if interp_on
        %Find the bounds of the non-nan section
        start_ind = find(~nan_inds,1,'first');
        end_ind = find(~nan_inds,1,'last');

        all_inds = start_ind:end_ind;
        good_inds = setdiff(all_inds, find(nan_inds));

        %Interpolate the nan columns within the SOPH
        if ~isequal(all_inds, good_inds)
            SOPH_filt = SOPH_mat(good_inds,:);
            p = good_inds;
            f = 1:size(SOPH_mat,2);
            [P,F] = meshgrid(p,f);
            [Pi,Fi] = meshgrid(all_inds,f);

            SOPH_mat(start_ind:end_ind,:) = interp2(P,F, SOPH_filt', Pi,Fi)';
        end
    end

    SOPHs(:,:,ii) = SOPH_mat;
end