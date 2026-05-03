function b = bin_centers_from_settings(txt, rangeKey, stepKey)
    import results_browser.*
b = [];
rng  = parse_settings_vec(txt, rangeKey);
step = parse_settings_vec(txt, stepKey);
if numel(rng) ~= 2 || numel(step) ~= 2, return, end
n = round((rng(2) - rng(1)) / step(2)) + 1;
b = linspace(rng(1), rng(2), n).';
end

