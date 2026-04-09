function img_downsampled = conv_downsample(img, scale_factor, method, plot_on)
%CONV_IMRESIZE  Downsamples indexed images through convolution and decimation
%
%   Usage:
%   Direct input:
%       img_downsampled = conv_downsample(img, scale_factor, method, plot_on)
%
%   Input:
%       img: MxN matrix - image data-- required
%       scale_factor: 1x2 vector - downsample ratio, must be integer valued  -- required
%       method: filter for convolution - 'mean' (default), 'median', 'max', <element order number>
%       plot_on: boolean to plot results (default: false)
%
%   Output:
%       img_downsampled: downsampled image
%  
%   Example:
%         %Create image
%         img = peaks(200)+randn(200)/5;
%         
%         %Downsample by 4x6 factor
%         scale_factor = [4 6];
%         
%         %Use different methods for downsampling
%         figure
%         subplot(221)
%         imagesc(img);
%         cx = get(gca,'CLim');
%         title(['Original: ' sprintf('%d x %d', size(img))])
%         
%         subplot(222)
%         img_downsampled = conv_downsample(img, scale_factor, 'mean');
%         imagesc(img_downsampled);
%         title(['Mean Downsampled: ' sprintf('%d x %d', size(img_downsampled))])
%         set(gca,'CLim',cx);
%         
%         subplot(223)
%         img_downsampled = conv_downsample(img, scale_factor, 'median');
%         imagesc(img_downsampled);
%         title(['Median Downsampled: ' sprintf('%d x %d', size(img_downsampled))])
%         set(gca,'CLim',cx);
%         
%         subplot(224)
%         img_downsampled = conv_downsample(img, scale_factor, 'max');
%         imagesc(img_downsampled);
%         title(['Max Downsampled: ' sprintf('%d x %d', size(img_downsampled))])
%         set(gca,'CLim',cx);
%
%
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
    method = 'mean';
end

if nargin<4
    plot_on = false;
end

%Check for integer inputs
if any(mod(scale_factor,1))
    scale_factor = round(scale_factor);
    warning(['Non-integer scale factor. Rounding to [' num2str(scale_factor) ']']);
end

switch lower(method)
    case 'mean'
        %Compute convolution and rescale
        img_downsampled = conv2(img, ones(scale_factor)./prod(scale_factor), 'same');
    case 'median'
        img_downsampled=ordfilt2(img,round(prod(scale_factor)/2),ones(scale_factor));
    case 'max'
        img_downsampled=ordfilt2(img,prod(scale_factor),ones(scale_factor));
    case 'min'
        img_downsampled=ordfilt2(img,1,ones(scale_factor));
    otherwise
        if isnumeric(method)
            if method <= 0 || method> prod(scale_factor)
                error(['Filter order number be between 1 and ' num2str(prod(scale_factor))]);
            else
                img_downsampled=ordfilt2(img,method,ones(scale_factor));
            end
        else
            error('Invalid method. Must be ''mean'', ''median'', ''max'', ''min'', or order number');
        end
end

img_downsampled = img_downsampled(1:scale_factor(1):end, 1:scale_factor(2):end);

%Plot data
if plot_on
    figure
    subplot(211)
    imagesc(img);
    cx = get(gca,'CLim');
    title(['Original: ' sprintf('%d x %d', size(img))])

    subplot(212)
    imagesc(img_downsampled);
    set(gca,'CLim',cx);
    title(['Downsampled: ' sprintf('%d x %d', size(img_downsampled))])
end

end
