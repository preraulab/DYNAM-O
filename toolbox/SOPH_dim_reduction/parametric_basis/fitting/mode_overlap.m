%MODE_OVERLAP Computes the pair-wise proportional volume overlap between modes
%
%  overlap = mode_overlap(powfit, goodpeaks, SOpow_bins,freq_bins)
%
function overlap = mode_overlap(powfit, goodpeaks, SOpow_bins,freq_bins)

overlap = zeros(length(goodpeaks));
%Get all pairwise overlap
for p = 1:length(goodpeaks)
    for q = p+1:length(goodpeaks)
        p1 = select_modes(powfit, goodpeaks(p), SOpow_bins, freq_bins);
        p2 = select_modes(powfit, goodpeaks(q), SOpow_bins, freq_bins);

        overlap(p,q) = sum(min(p1,p2),'all')/(sum(max(p1,p2),'all'));
    end
end
