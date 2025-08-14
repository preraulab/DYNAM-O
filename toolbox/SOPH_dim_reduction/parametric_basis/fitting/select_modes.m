function [model_fit, X, Y] = select_modes(fitobj, modenums, xvals, yvals)
%SELECT_MODES Select specific mode components from the model
%
%   [model_fit, X, Y] = select_modes(fitobj, modenums, xvals, yvals)
%
%   This function selects specific mode components from a fitted model object `fitobj`
%   and returns a new model with the selected modes. It sets the amplitudes of the unselected
%   modes to zero and removes any baseline if the mode 0 is not selected.
%
%   Input:
%       fitobj: Fitted model object - The model to select modes from
%       modenums: Numeric vector - Mode numbers to select (Default: all modes)
%       xvals: Numeric vector - X-values for the meshgrid
%       yvals: Numeric vector - Y-values for the meshgrid
%
%   Output:
%       model_fit: Fitted model object - The modified model with selected modes
%       X: Numeric matrix - X meshgrid
%       Y: Numeric matrix - Y meshgrid
%
%   Copyright 2023 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

if isempty(modenums)
    modenums = 0:num_modes(fitobj);
end

warning('off','curvefit:sfit:subsasgn:coeffsClearingConfBounds');
assert(all(ismember(modenums, 0:num_modes(fitobj))),'Invalid mode number');

coeff_names = coeffnames(fitobj);

%Set amps of unselected modes to zero
pnums = find(get_param_inds(fitobj, 'amp'));
for ii = 1:length(pnums)
    cname = coeff_names{pnums(ii)};
    splits = split(cname,'_');

    cnum = str2double(splits{2});

    if ~ismember(cnum, modenums)
        fitobj.(cname)=0;
    end
end

%Get rid of any baseline
if ~ismember(modenums,0)
    if any(strcmpi(coeff_names, 'xxx'))
        fitobj.xxx=0;
    end

    if any(strcmpi(coeff_names, 'yyy'))
        fitobj.yyy=0;
    end

    if any(strcmpi(coeff_names, 'zzz'))
        fitobj.zzz=0;
    end
end

%If unit_row is a problem parameter to normalize across rows, set to false
prob_names = probnames(fitobj);
if any(strcmpi(prob_names, 'unit_row'))
    fitobj.unit_row = false;
end

%Fit the object
[X,Y] = meshgrid(xvals, yvals);
model_fit = feval(fitobj,X, Y);
