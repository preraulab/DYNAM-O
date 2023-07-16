function [img_rescaled] = conv_imresize(img, scale_factor, plot_on)
%Scales resizes images using convolution average
%
% img_rescaled = conv_imresize(img, scale_factor, plot_on)

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
    cx = clim;
    title(['Original: ' sprintf('%d x %d', size(img))])

    subplot(212)
    imagesc(img_rescaled);
    clim(cx);
    title(['Rescaled: ' sprintf('%d x %d', size(img_rescaled))])
end

end