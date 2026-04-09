function [img_rescaled] = conv_imresize(img, scale_factor, plot_on)
%Scales resizes images using convolution average
%
% img_rescaled = conv_imresize(img, scale_factor, plot_on)
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://harvard.edu
%   GITHUB     https://github.com
%
%   CITATION
%   If you use this toolbox, please cite:
%
%   He, M., Prerau, M. J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%    in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%    for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================

%Set example data
if nargin == 0
    img = peaks(100);
    scale_factor = [3,3];
end

if nargin<3
    plot_on = false;
end

%Check for integer inputs
if any(mod(scale_factor,1))
    scale_factor = round(scale_factor);
    warning(['Non-integer scale factor. Rounding to [' num2str(scale_factor) ']']);
end

%Create the average filter
avg_filt = ones(scale_factor)./prod(scale_factor);

%Compute convolution and rescale
img_rescaled = conv2(img, avg_filt, 'same');
img_rescaled = img_rescaled(1:scale_factor(1):end, 1:scale_factor(2):end);

%Plot data
if plot_on
    figure
    subplot(211)
    imagesc(img);
    cx = get(gca,'CLim');
    title(['Original: ' sprintf('%d x %d', size(img))])

    subplot(212)
    imagesc(img_rescaled);
    set(gca,'CLim',cx);
    title(['Rescaled: ' sprintf('%d x %d', size(img_rescaled))])
end

end