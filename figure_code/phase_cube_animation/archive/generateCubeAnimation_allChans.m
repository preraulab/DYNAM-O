function generateCubeAnimation_allChans(elec_hists, bin_edges, elec_bin_times, elec_stage_prop, pick_subjs, win_sizes, elec_labels, comps, save_append)
% fname_cube_hists = 'hists_freq_swpow_dB_percentLightsOutNoArtifact_swphase_raw_20181211_withPickEegSwpower.mat'; % 'hists_freq_swpow_dB_percentLightsOutNoArtifact_swphase_raw_20181204.mat';
% load(['/data/preraugp/projects/spindle_detection/code/Lunesta histograms over time/' fname_cube_hists]);
% cube_append = '20181211_ctrl';
% generateCubeAnimation_allChans(electrode_hists, bin_edges, electrode_time_in_bin, electrode_stage_prop, ~logical(issz), [41 31 11], electrodes,{'F4','C4','Pz','O2';'F3','C3','Pz','O1'},cube_append)

% ***DOES NOT CURRENTLY SAVE OR OUTPUT ANYTHING. NEEDS TO SAVE OUTPUTS
%    NECESSARY FOR phaseCubeAnimation_allChans.
%

for jj = 1:size(comps,1)
    for kk = 1:size(comps,2)
        eind = find(strcmpi(elec_labels,comps{jj,kk}));
        labels_array{jj,kk} = elec_labels{eind};

        channel_hist = elec_hists{eind};
        stage_prop = elec_stage_prop{eind};
        bin_times = elec_bin_times{eind};

        stage_prop(isnan(stage_prop)) = 0;
        sm_hist = channel_hist;
        parfor ii = 1:38
            % sm_hist(:,:,:,ii) = cconv(sm_hist(:,:,:,ii),ones(win_sizes(2),1));
            sm_hist(:,:,:,ii) = imfilter(sm_hist(:,:,:,ii),ones(win_sizes(1),win_sizes(2),win_sizes(3)));
            
            stage_time = imfilter(stage_prop(:,:,ii).*repmat(bin_times(:,ii),[1 5]),ones(win_sizes(3),1));
            bin_times(:,ii) = imfilter(bin_times(:,ii),ones(win_sizes(3),1));
            stage_prop(:,:,ii) = stage_time./repmat(bin_times(:,ii),[1 5]);
        end
        for ii = 1:38
            pick_empty_bins = bin_times(:,ii) == 0;
            stage_prop(pick_empty_bins,:,ii) = nan;
        end

        channel_hist = sm_hist(ceil(win_sizes(1)/2):(end-floor(win_sizes(1)/2)),...
            ceil(win_sizes(2)/2):(end-floor(win_sizes(2)/2)),...
            ceil(win_sizes(3)/2):(end-floor(win_sizes(3)/2)),:);
        bin_times = bin_times(ceil(win_sizes(3)/2):(end-floor(win_sizes(3)/2)),:);
        stage_prop = stage_prop(ceil(win_sizes(3)/2):(end-floor(win_sizes(3)/2)),:,:);

        if jj==1 && kk==1 % only do once during first channel
            for ii = 1:3
                bin_edges{ii} = [bin_edges{ii}(1:(end-(win_sizes(ii)-1)),1) bin_edges{ii}(win_sizes(ii):end,2)];
                bin_centers{ii} = (bin_edges{ii}(:,2)+bin_edges{ii}(:,1))./2;
            end

            freqs = bin_centers{1};
            phase = bin_centers{2};
            power = bin_centers{3};

            power_bin_width = bin_edges{3}(1,2)-bin_edges{3}(1,1);
        end

        hist_norm=nan(size(channel_hist));

        for pp=1:length(power)
            for ss=1:size(hist_norm,4)
                subject_hist=squeeze(channel_hist(:,:,pp,ss)); % /bin_times(pp,ss);

                norm_factor=nansum(subject_hist,2);
                hist_norm(:,:,pp,ss)=subject_hist./repmat(norm_factor,1,size(subject_hist,2));
            end
        end

        % hist_norm_ctrl{jj,kk} = hist_norm;
        % bin_times_ctrl{jj,kk} = bin_times;
        % stage_prop_ctrl{jj,kk} = stage_prop;
        stage_times_ctrl = permute(repmat(reshape(bin_times,[1 size(bin_times)]),[5 1 1]), [2 1 3]) .* stage_prop;
        
        mean_stage_prop_ctrl{jj,kk} = nansum(stage_times_ctrl(:,:,pick_subjs),3) ./ repmat(nansum(bin_times(:,pick_subjs),2),[1 5]);
        mean_control_hists{jj,kk} = nanmean(hist_norm(:,:,:,pick_subjs),4);
    end
end

% pow_average=nanmean(nanmean(hist_norm_ctrl{2,2}(:,:,:,pick_subjs),4),3);
pow_average=nanmean(mean_control_hists{2,2},3);

if ~isempty(save_append)
    save(['phase_cube_data_vis_' save_append '.mat'],'power','power_bin_width','pow_average','mean_stage_prop_ctrl','mean_control_hists','phase','freqs','labels_array','comps');
end


