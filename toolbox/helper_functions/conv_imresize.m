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

%Give warnings for uneven scale factors
if rem(size(img,1), scale_factor(1))
    warning(['Row size ' num2str(size(img,1)) ' is not divisible by row scale factor ' num2str(scale_factor(1))]);
end

if rem(size(img,2), scale_factor(2))
    warning(['Column size ' num2str(size(img,2)) ' is not divisible by column scale factor ' num2str(scale_factor(2))]);
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
    cx = caxis;
    title(['Original: ' sprintf('%d x %d', size(img))])

    subplot(212)
    imagesc(img_rescaled);
    caxis(cx);
    title(['Rescaled: ' sprintf('%d x %d', size(img_rescaled))])
end

end