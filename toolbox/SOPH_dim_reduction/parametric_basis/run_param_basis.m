% Set dataset and paths
dataset = 'CFS';
%base_path = '/Users/Mike/code/toolboxes/parametric_histogram/';
%dynamo_path = '/Users/Mike/code/toolboxes/DYNAM-O_dev';
base_path = '/autofs/vast/preraugp/users/hn965/SOPH_dim_reduction/SOPH_fit/';
dynamo_path = '/autofs/vast/preraugp/users/hn965/DYNAM-O_dev';



% Add necessary paths
addpath(genpath(base_path));
addpath(genpath(dynamo_path));

% Define file paths based on dataset
switch dataset
    case 'CFS'
        % fbase_pow = '/autofs/vast/preraugp/code/toolboxes/SOPH_fit/parametric_basis/data/CFS_C3_SOPHs.mat';
        % fbase_phase = '/autofs/vast/preraugp/code/toolboxes/SOPH_fit/parametric_basis/data/CFS_C3_SOPhHs.mat';
        fbase_pow = '/autofs/vast/preraugp/results/SOPHs/stacks/CFS/C3/d99fe49/CFS_C3_all_SOPHs.mat';
        fbase_phase = '/autofs/vast/preraugp/results/SOPHs/stacks/CFS/C3/d99fe49/CFS_C3_all_SOPhHs.mat';
        save_fig_path = '/autofs/vast/preraugp/results/SOPH_dim_reduction/param_basis/CFS/C3/figures/CFS_params_28';
        save_path = '/autofs/vast/preraugp/results/SOPH_dim_reduction/param_basis/CFS/C3/CFS_params_28';
    case 'SHHS1'
        fbase_pow = '/autofs/vast/preraugp/results/SOPHs/stacks/SHHS1/C3/5262469/SHHS1_C3_all_SOPHs.mat';
        fbase_phase = '/autofs/vast/preraugp/results/SOPHs/stacks/SHHS1/C3/5262469/SHHS1_C3_all_SOPhHs.mat';
        save_fig_path = '/autofs/vast/preraugp/results/SOPH_dim_reduction/param_basis/SHHS1/C3/5262469/figures/SHHS1_params_1';
        save_path = '/autofs/vast/preraugp/results/SOPH_dim_reduction/param_basis/SHHS1/C3/5262469/SHHS1_params_1';
    case 'SHHS2'
        fbase_pow = '/autofs/vast/preraugp/results/SOPHs/stacks/SHHS2/C3/3890269/SHHS2_C3_all_SOPHs.mat';
        fbase_phase = '/autofs/vast/preraugp/results/SOPHs/stacks/SHHS2/C3/3890269/SHHS2_C3_all_SOPhHs.mat';
        save_fig_path = '/autofs/vast/preraugp/results/SOPH_dim_reduction/param_basis/SHHS2/C3/3890269/figures/SHHS2_params_1';
        save_path = '/autofs/vast/preraugp/results/SOPH_dim_reduction/param_basis/SHHS2/C3/3890269/SHHS2_params_1';
    case 'LunestaHC1'
        fbase_pow = '/autofs/vast/preraugp/results/SOPHs/stacks/LunestaHC1/C3/8dc8929/LunestaHC1_C3_all_SOPHs.mat';
        fbase_phase = '/autofs/vast/preraugp/results/SOPHs/stacks/LunestaHC1/C3/8dc8929/LunestaHC1_C3_all_SOPhHs.mat';
        save_fig_path = '/autofs/vast/preraugp/results/SOPH_dim_reduction/param_basis/LunestaHC1/C3/8dc8929/figures/LunestaHC1_params_1';
        save_path = '/autofs/vast/preraugp/results/SOPH_dim_reduction/param_basis/LunestaHC1/C3/8dc8929/LunestaHC1_params_1';
    case 'LunestaHC2'
        fbase_pow = '/autofs/vast/preraugp/results/SOPHs/stacks/LunestaHC2/C3/41d1905/LunestaHC2_C3_all_SOPHs.mat';
        fbase_phase = '/autofs/vast/preraugp/results/SOPHs/stacks/LunestaHC2/C3/41d1905/LunestaHC2_C3_all_SOPhHs.mat';
        save_fig_path = '/autofs/vast/preraugp/results/SOPH_dim_reduction/param_basis/LunestaHC2/C3/41d1905/figures/LunestaHC2_params_1';
        save_path = '/autofs/vast/preraugp/results/SOPH_dim_reduction/param_basis/LunestaHC2/C3/41d1905/LunestaHC2_params_1';
end



% Load data
if contains(dataset,'Lunesta')
    load(fbase_pow,'all_SOPHs','SOpow_TIBs','SOpow_bins', 'subjIDs');
    ages = NaN(length(subjIDs),1);
else

    load(fbase_pow, 'ages','all_SOPHs','SOpow_TIBs','SOpow_bins', 'subjIDs');
end

N = size(all_SOPHs,3);

freq_range = [1.5 18];

for sub_ind = 1:N
    % Format and preprocess data
    SOPH = squeeze(all_SOPHs(:,:,sub_ind));
    NREM_TIB = sum(SOpow_TIBs(:,1:3,sub_ind),2);
    SOPH = (SOPH./NREM_TIB)';

    all_SOPHs(:,:,sub_ind) = SOPH';
end

% Load phase data and preprocess
load(fbase_phase, 'all_SOPhHs','SOphase_TIBs','SOphase_bins','freq_bins');
for sub_ind = 1:N
    SOPhH = squeeze(all_SOPhHs(:,:,sub_ind));
    NREM_TIB = sum(SOphase_TIBs(:,1:3,sub_ind),2);
    SOPhH = (SOPhH./NREM_TIB);
    SOPhH = SOPhH ./ sum(SOPhH, "omitnan");

    all_SOPhHs(:,:,sub_ind) = SOPhH;
end
all_SOPHs = reject_TIB(all_SOPHs,SOpow_TIBs,[1:3],10);
all_SOPhHs = reject_TIB(all_SOPhHs,SOphase_TIBs,[1:3],10);
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

power_params_opts = param_basis_opts('power','plot_on',0,'verbose',false); % get the default parameters
phase_params_opts = param_basis_opts('phase','plot_on',0,'verbose',false); % get the default parameters
power_params_opts.ylimits = [2,16];
phase_params_opts.prefix_modes = [];
% phase_params_opts.prefix_modes =  [1e-2, 14,     4,     0,      pi/3,  0;
%                                       1e-2, 5,      10,    pi,     pi/3,  0];
% phase_params_opts.verbose = true;
% phase_params_opts.plot_on = 3;
% power_params_opts.verbose = true;
% power_params_opts.plot_on = 3;
% Select subject index
for sub_ind = find(subjIDs==800114)%1:N
    try
        warning('off');
        disp(['Running subject ' num2str(sub_ind)]);
        subID = subjIDs(sub_ind);
        age = ages(sub_ind);
        age = ages(sub_ind);
        age = ages(sub_ind);

        % Define save path for figures
        fsave = fullfile(save_fig_path,[dataset '_' sprintf('%03d',sub_ind) '_' num2str(subID) '_param.png']);
        fsave = fullfile(save_fig_path,[dataset '_' sprintf('%03d',sub_ind) '_' num2str(subID) '_param.png']);

        % Select relevant data within specified ranges
        SOPH = squeeze(all_SOPHs(:,:,sub_ind));
        SOPhH = squeeze(all_SOPhHs(:,:,sub_ind));

        freq_inds = freq_bins >= freq_range(1) & freq_bins <= freq_range(2);
        SOPH = double(SOPH(freq_inds', :));
        freq_bins_comp = freq_bins(freq_inds);

        freq_bins_comp_SOPhH = freq_bins(freq_inds);
        SOPhH = double(SOPhH(freq_inds', :));


        [ params_pow,  SOPH_fitobj{sub_ind}, SOPH_gof{sub_ind}, model_pow, wshed_img_pow] = param_basis_power(SOPH, SOpow_bins, freq_bins_comp, power_params_opts); %#ok<*PFOUS>
        [params_phase, SOPhH_fitobj{sub_ind}, SOPhH_gof{sub_ind}, model_phase, wshed_img_phase] = param_basis_phase(SOPhH, SOphase_bins, freq_bins_comp_SOPhH,phase_params_opts);
        SOPH_params{sub_ind} = params_pow;
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

        % Plot power-related figures
        axes(ax(1)) %#ok<*LAXES>
        imagesc(SOpow_bins, freq_bins_comp, wshed_img_pow);
        axis xy;
        ylabel('Frequency (Hz)')
        set(gca,'fontsize',ax_font_size);
        title('Watershed','FontSize',title_font_size);

        axes(ax(2))
        imagesc(SOpow_bins, freq_bins_comp, SOPH);
        axis xy;
        xlabel('SO-power (dB)')
        cx = climscale(ax(2),[],false);
        colormap(ax(2),gouldian)
        set(gca,'fontsize',ax_font_size);
        title('SO-Power Histogram','FontSize',title_font_size);
        colorbar_noresize(ax(2));

        axes(ax(3))
        imagesc(SOpow_bins, freq_bins_comp, model_pow);
        axis xy;
        caxis(ax([2,3]),[0,3]);
        colormap(ax(3),gouldian)
        hold on
        if ~isempty(params_pow)
            plot(params_pow(:,4), params_pow(:,2),'o','MarkerEdgeColor','k','MarkerFaceColor','m','markersize',10)
        end
        set(gca,'fontsize',ax_font_size);
        title('Model','FontSize',title_font_size);
        colorbar_noresize(ax(3));

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

        if ~isempty(model_phase)
            axes(ax(6))
            imagesc(ax(6),SOphase_bins, freq_bins_comp, model_phase);
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
        end
        
        s = outertitle(ax(1:3),[dataset ' ' num2str(subID) ' - ' num2str(age) ' years']);
        % s.FontSize = 40;
        s.Position(2) = s.Position(2)-.02;

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

SOPH_mode_table = paramcell2table(subjIDs,ages,SOPH_params);
SOPhH_mode_table = paramcell2table(subjIDs,ages,SOPhH_params);
% Set SOPH SOpower upper and lower bound to NaN because it's upper and
% lower bound on a subject level. 
power_params_opts.UB_default(4) = NaN;
power_params_opts.LB_default(4) = NaN;
save(save_path,'SOPH_params', 'SOPhH_params', 'power_params_opts', 'phase_params_opts', ...
    'freq_range', 'SOPH_mode_table', 'SOPhH_mode_table', 'SOPH_fitobj', 'SOPH_gof', 'SOPhH_fitobj', 'SOPhH_gof')
warning('on');

%Add a parallel friendly waitbar
    function nUpdateWaitbar(~)
        waitbar(subjects_processed/N, h, [num2str(subjects_processed) ' out of ' ...
            num2str(N) ' (' num2str((subjects_processed/N*100),'%.2f') '%) segments processed...']);
        subjects_processed = subjects_processed + 1;
    end
