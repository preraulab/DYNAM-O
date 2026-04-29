function [SOPHs] = createSOPHsStruct(SOpower_mat, SOphase_mat, SOpower_bins, SOpower_norm, SOpower_times, SOphase_bins, SOphase, SOphase_times, SOfiltered, freq_bins, num_peaks_at_freq, SOpower_TIB, SOphase_TIB)
%CREATESOPHSSTRUCT  Pack SO-power/phase histograms and bins into a struct.
SOPHs = struct;
SOPHs.SOpower_mat = SOpower_mat;
SOPHs.SOphase_mat = SOphase_mat;
SOPHs.SOpower_bins = SOpower_bins;
SOPHs.SOphase_bins = SOphase_bins;
SOPHs.freq_bins = freq_bins;
SOPHs.num_peaks_at_freq = num_peaks_at_freq;
SOPHs.SOpower_TIB = SOpower_TIB;
SOPHs.SOphase_TIB = SOphase_TIB;
SOPHs.SOpower_norm = SOpower_norm;
SOPHs.SOpower_times = SOpower_times;
SOPHs.SOphase = SOphase;
SOPHs.SOphase_times = SOphase_times;
SOPHs.SOfiltered = SOfiltered;
end
