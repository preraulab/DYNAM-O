function ticks = sparseSliderTicks(N)
% Cap a slider's MajorTicks to ~10 evenly spaced positions so
% sliders covering 100s/1000s of pages stay readable.
if N <= 1
    ticks = 1;
elseif N <= 10
    ticks = 1:N;
else
    ticks = unique(round(linspace(1, N, 10)));
end
end

