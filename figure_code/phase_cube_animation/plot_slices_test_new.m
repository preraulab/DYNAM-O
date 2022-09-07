
ccc;
load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOphase_slice_data/SOphase_slice_data.mat');
load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOphase_slice_data/SOphase_slice_data_10percPowBins_v1.mat');

%%

elect_phase_slices = SOphase_slice_data{2};

cx = prctile(elect_phase_slices(:),[7 98]);

figure;
for s = 1:size(elect_phase_slices,3)

    imagesc(SOphase_cbins, freq_cbins, elect_phase_slices(:,:,s)');
    axis xy;
    colormap magma;
    caxis(cx);

    xlabel('Phase (radians)');
    ylabel('Frequency (Hz)');
    ylim([4,25]);

    drawnow

end