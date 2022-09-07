function [mean_stage_prop_ctrl] = phaseCubeSmoothStageTimes_allChans(elec_hists, bin_edges, elec_bin_times, elec_stage_prop, pick_subjs, win_sizes, elec_labels, comps)
% [mean_stage_prop_ctrl] = phaseCubeSmoothStageTimes_allChans(electrode_hists, bin_edges, electrode_time_in_bin, electrode_stage_prop, logical(issz), [41 31 11],electrodes,{'F4','C4','Pz','O2';'F3','C3','Pz','O1'});

% This function was made to correct stage_props already saved for the phase
% cube animation (phase_cube_data_vis1.mat). It is primarily a copy of generateCubeAnimation_allChans 
% with the histogram smoothing commented out.
%
% Ultimately, while the smoothing worked, several intances of power bins
% with times but no stage props occurred, resulting in those bins and
% corresponding group averages not summing to one.
%*** Instances of positive bin time and zero stage values for (F4, subj 36), (C3, subj 23), and (O1, subj 36)
for jj = 1:size(comps,1)
    for kk = 1:size(comps,2)
        eind = find(strcmpi(elec_labels,comps{jj,kk}));
        % labels_array{jj,kk} = elec_labels{eind};

        % channel_hist = elec_hists{eind};
        stage_prop = elec_stage_prop{eind};
        bin_times = elec_bin_times{eind};

        stage_prop(isnan(stage_prop)) = 0;
        % sm_hist = channel_hist;
        for ii = 1:38
            % % sm_hist(:,:,:,ii) = cconv(sm_hist(:,:,:,ii),ones(win_sizes(2),1));
            % sm_hist(:,:,:,ii) = imfilter(sm_hist(:,:,:,ii),ones(win_sizes(1),win_sizes(2),win_sizes(3)));
            
            stage_time = imfilter(stage_prop(:,:,ii).*repmat(bin_times(:,ii),[1 5]),ones(win_sizes(3),1));
            bin_times(:,ii) = imfilter(bin_times(:,ii),ones(win_sizes(3),1));
            stage_prop(:,:,ii) = stage_time./repmat(bin_times(:,ii),[1 5]);
            pick_empty_bins = bin_times(:,ii) == 0;
            stage_prop(pick_empty_bins,:,ii) = nan;
        end
        
        % find(any(abs(sum(stage_prop,2)-1)>10^-10,1))
        % sum(any(abs(sum(stage_prop,2)-1)>10^-10,1))

        % channel_hist = sm_hist(ceil(win_sizes(1)/2):(end-floor(win_sizes(1)/2)),...
        %     ceil(win_sizes(2)/2):(end-floor(win_sizes(2)/2)),...
        %     ceil(win_sizes(3)/2):(end-floor(win_sizes(3)/2)),:);
        bin_times = bin_times(ceil(win_sizes(3)/2):(end-floor(win_sizes(3)/2)),:);
        stage_prop = stage_prop(ceil(win_sizes(3)/2):(end-floor(win_sizes(3)/2)),:,:);

        if jj==1 && kk==1 % only do once during first channel
            for ii = 1:3
                bin_edges{ii} = [bin_edges{ii}(1:(end-(win_sizes(ii)-1)),1) bin_edges{ii}(win_sizes(ii):end,2)];
                bin_centers{ii} = (bin_edges{ii}(:,2)+bin_edges{ii}(:,1))./2;
            end

            freqs = bin_centers{1};
            phase = bin_centers{2};
            SWP_percent = bin_centers{3};

            power_bin_width_percent = bin_edges{3}(1,2)-bin_edges{3}(1,1);
        end

        % hist_norm=nan(size(channel_hist));

        % for pp=1:length(SWP_percent)
        %     for ss=1:size(hist_norm,4)
        %         subject_hist=squeeze(channel_hist(:,:,pp,ss)); % /bin_times(pp,ss);

        %         norm_factor=nansum(subject_hist,2);
        %         hist_norm(:,:,pp,ss)=subject_hist./repmat(norm_factor,1,size(subject_hist,2));
        %     end
        % end

        % hist_norm_ctrl{jj,kk} = hist_norm;
        bin_times_ctrl{jj,kk} = bin_times;
        stage_prop_ctrl{jj,kk} = stage_prop;
        stage_times_ctrl{jj,kk} = permute(repmat(reshape(bin_times_ctrl{jj,kk},[1 size(bin_times_ctrl{jj,kk})]),[5 1 1]), [2 1 3]) .* stage_prop_ctrl{jj,kk};
        
        mean_stage_prop_ctrl{jj,kk} = nansum(stage_times_ctrl{jj,kk}(:,:,pick_subjs),3) ./ repmat(nansum(bin_times_ctrl{jj,kk}(:,pick_subjs),2),[1 5]);
        % control_hists{jj,kk}=nanmean(hist_norm_ctrl{jj,kk}(:,:,:,pick_subjs),4);
    end
end

