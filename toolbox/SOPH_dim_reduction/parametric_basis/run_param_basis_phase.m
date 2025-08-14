function run_param_basis_phase
% Set dataset and paths
dataset = 'CFS';
%base_path = '/Users/Mike/code/toolboxes/parametric_histogram/';
%dynamo_path = '/Users/Mike/code/toolboxes/DYNAM-O_dev';
base_path = '/autofs/vast/preraugp/users/hn965/SOPH_dim_reduction/SOPH_fit/';
dynamo_path = '/autofs/vast/preraugp/code/toolboxes/DYNAM-O_dev';

% Add necessary paths
addpath(genpath(base_path));
addpath(genpath(dynamo_path));

% Define file paths based on dataset
switch dataset
    case 'CFS'
        fbase_pow = '/autofs/vast/preraugp/code/toolboxes/SOPH_fit/parametric_basis/data/CFS_C3_SOPHs.mat';
        fbase_phase = '/autofs/vast/preraugp/code/toolboxes/SOPH_fit/parametric_basis/data/CFS_C3_SOPhHs.mat';
        save_fig_path = '/autofs/vast/preraugp/results/SOPH_dim_reduction/param_basis/CFS/C3/figures/test_phase_2';
        save_path = '/autofs/vast/preraugp/results/SOPH_dim_reduction/param_basis/CFS/C3/test_phase_2';
end


% Load data
load(fbase_pow, 'ages','all_SOPHs','SOpow_TIBs','SOpow_bins', 'subjIDs');

N = size(all_SOPHs,3);

SOP_range = [2 20];
freq_range = [2 16];

for sub_ind = 1:N
    % Format and preprocess data
    SOPH = squeeze(all_SOPHs(:,:,sub_ind));
    NREM_TIB = sum(SOpow_TIBs(:,1:3,sub_ind),2);
    SOPH = (SOPH./NREM_TIB)';

    all_SOPHs(:,:,sub_ind) = SOPH';
end

% Load phase data and preprocess
load(fbase_phase, 'all_SOPhHs','SOphase_TIBs','SOphase_bins','freq_bins');
parfor sub_ind = 1:N
    SOPhH = squeeze(all_SOPhHs(:,:,sub_ind));
    NREM_TIB = sum(SOphase_TIBs(:,1:3,sub_ind),2);
    SOPhH = (SOPhH./NREM_TIB)';
    SOPhH = SOPhH ./ sum(SOPhH, "omitnan");

    all_SOPhHs(:,:,sub_ind) = SOPhH';
end

%Converting to singles for storage purposes
all_SOPHs = (permute(all_SOPHs,[2 1 3]));
all_SOPhHs = (permute(all_SOPhHs,[2 1 3]));


% Check for parallel processing toolbox and set up loading bar
v = ver;
haspar = any(strcmp({v.Name}, 'Parallel Computing Toolbox'));
if haspar
    D = parallel.pool.DataQueue;
    h = waitbar(0, 'Processing Segments...');
    afterEach(D, @nUpdateWaitbar);
else
    h = waitbar(0, 'Processing Segments...');
end
subjects_processed = 1;

SOPH_params = cell(1,N);
SOPhH_params = cell(1,N);
SOPH_fitobj = cell(1,N);
SOPhH_fitobj = cell(1,N);
SOPH_gof = cell(1,N);
SOPhH_gof = cell(1,N);

%phase parameters
phase_params_opts = param_basis_opts('phase','max_peaks',10,'plot_on',false,'verbose',false);
%Set parameter bounds to frequency/phase ranges
phase_params_opts.UB_default(2) = freq_range(2)+1;
phase_params_opts.LB_default(2) = max(freq_range(1)-1,0);
phase_params_opts.UB_default(4) = 1.5*pi;
phase_params_opts.LB_default(4) = -1.5*pi;
phase_params_opts.UB_default(6) = pi/5;
phase_params_opts.LB_default(6) = -pi/5;

% Select subject index
parfor sub_ind = 1:N
    try
        warning('off');
        disp(['Running subject ' num2str(sub_ind)]);
        subID = subjIDs(sub_ind);
        age = ages(sub_ind);

        % Define save path for figures
        fsave = fullfile(save_fig_path,[dataset '_' sprintf('%03d',sub_ind) '_' num2str(subID) '_param.png']);

        % Select relevant data within specified ranges
        SOPH = squeeze(all_SOPHs(:,:,sub_ind));
        SOPhH = squeeze(all_SOPhHs(:,:,sub_ind));

        SOP_inds = SOpow_bins >= SOP_range(1) & SOpow_bins <= SOP_range(2);
        freq_inds = freq_bins >= freq_range(1) & freq_bins <= freq_range(2);
        valid_freqs = ~all(isnan(SOPH),2) & freq_inds';
        valid_SOpow = ~all(isnan(SOPH),1) & SOP_inds;
        SOPH = double(SOPH(valid_freqs, valid_SOpow));

        freq_inds = freq_bins >= freq_range(1) & freq_bins <= freq_range(2);
        valid_freqs = ~all(isnan(SOPhH),2) & freq_inds';

        SOpower_bins_comp = SOpow_bins(valid_SOpow);
        freq_bins_comp = freq_bins(valid_freqs);
        SOPhH = double(SOPhH(valid_freqs, :));


        [params_phase, SOPhH_fitobj{sub_ind}, SOPhH_gof{sub_ind}, model_phase, wshed_img_phase] = param_basis_phase(SOPhH, SOphase_bins, freq_bins_comp,phase_params_opts);
        SOPhH_params{sub_ind} = params_phase;

        % Plot the results
        ax_font_size = 18;
        title_font_size = 30;
        f = figure;
        ax = figdesign(2, 3, 'type', 'usletter', 'orient', 'landscape' , 'margins', [0.1 0.05 0.1 0.1 0.1 0.1]);
        linkaxes(ax(1:3));
        linkaxes(ax(4:6));
        linkcaxes(ax([2 3]));
        linkcaxes(ax([5 6]));
        % Plot phase-related figures
        axes(ax(4))
        imagesc([SOphase_bins-2*pi, SOphase_bins, SOphase_bins + 2*pi], freq_bins_comp, wshed_img_phase);
        axis xy;
        ylabel('Frequency (Hz)')
        xlim([-pi pi])
        set(gca,'fontsize',ax_font_size);
        title('Watershed','FontSize',title_font_size);

        axes(ax(5))
        imagesc(SOphase_bins, freq_bins_comp, SOPhH);
        axis xy;
        xlabel('SO-power (dB)')
        cx = climscale(ax(5),[],false);
        colormap(ax(5),magma)
        set(gca,'fontsize',ax_font_size);
        title('SO-Phase Histogram','FontSize',title_font_size);
        colorbar_noresize(ax(5));

        axes(ax(6))
        imagesc(SOphase_bins, freq_bins_comp, model_phase);
        axis xy;
        caxis(ax(6),cx);
        colormap(ax(6),magma)
        hold on
        if ~isempty(params_phase)
            plot(params_phase(:,4), params_phase(:,2),'o','MarkerEdgeColor','k','MarkerFaceColor','m','markersize',10)
        end
        set(ax(4:6),'XTick',[-pi -pi/2 0 pi/2 pi],'XTickLabel',{'-\pi', '-\pi/2' '0' '\pi/2' '\pi'})
        set(gca,'fontsize',ax_font_size);
        title('Model','FontSize',title_font_size);
        colorbar_noresize(ax(6));
        s = suptitle(['CFS ' num2str(subID) ' - ' num2str(age) ' years']);
        s.FontSize = 40;
        s.Position(2) = s.Position(2)+.02;

        f.Units = 'inches';
        f.Position = [0.7788    1.7220   23.7073   16.8340];
        print(f,'-dpng','-r100', fsave);

        % Update loading bar
        if haspar
            send(D, sub_ind);
        else
            h = waitbar(sub_ind/N, [num2str(ii) ' out of ' num2str(N) ' (' num2str((sub_ind/N*100),'%.2f') '%) segments processed...']);
        end

        close(f);
    catch ME
        disp(['Error at index ' num2str(sub_ind) ': ' ME.message]);
    end
end

delete(h); % delete loading bar

SOPhH_mode_table = paramcell2table(subjIDs,ages,SOPhH_params);

save(save_path,'SOPhH_params','phase_params_opts', ...
    'SOP_range','freq_range','SOPhH_mode_table', 'SOPhH_fitobj', 'SOPhH_gof');
warning('on');

%Add a parallel friendly waitbar
    function nUpdateWaitbar(~)
        waitbar(subjects_processed/N, h, [num2str(subjects_processed) ' out of ' ...
            num2str(N) ' (' num2str((subjects_processed/N*100),'%.2f') '%) segments processed...']);
        subjects_processed = subjects_processed + 1;
    end
end