function [trimmed_regions, trimmed_borders] = trimWshedRegions(data,regions,vol_thresh,shift_val,conn,f_verb,verb_pref,f_disp)
%TRIMWSHEDREGIONS  Trim watershed regions to a target fraction of volume
%
%   Usage:
%       [trimmed_regions, trimmed_borders] = trimWshedRegions(data, regions, vol_thresh, shift_val, conn, f_verb, verb_pref, f_disp)
%
%   Required Inputs:
%       data:       [M x N] double - 2D image data
%       regions:    [1 x K] cell - linear indices of all pixels for each region
%
%   Optional Inputs:
%       vol_thresh:   double - fraction of maximum trimmed volume in (0, 1]; 1 means no trim (default: 0.8)
%       shift_val:    double - value subtracted from image prior to volume evaluation (default: min(data(:)))
%       conn:         integer - pixel connectivity used by the trim step (default: 8)
%       f_verb:       integer - verbosity level: 0 silent, 1 current level, >1 subfunctions (default: 0)
%       verb_pref:    char - prefix string prepended to verbose output (default: '')
%       f_disp:       logical/integer - plot the trimmed result when nonzero (default: 0)
%
%   Outputs:
%       trimmed_regions: [1 x K] cell - linear indices of retained pixels for each region
%       trimmed_borders: [1 x K] cell - linear indices of border pixels for each trimmed region
%
%   Notes:
%       - Borders are returned as sets (ascending linear-index order); downstream
%         consumers (cell2Ldata, computePeakStatsTable) treat them as sets.
%       - Inside a ThreadPool worker the MEX fast path is bypassed (MATLAB
%         cannot execute MEX functions inside a thread worker); the stock
%         IPT path produces identical output. Serial and ProcessPool calls
%         use the MEX whenever the binary exists.
%
%   See Also: runWatershed, mergeWshedSegment, extractTFPeaks
%
%*******************************
% Set variable inputs to empty *
%*******************************
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
%   GITHUB     https://github.com
%
%   ATTRIBUTION
%   If you use this toolbox, please cite:
%
%   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
if nargin < 1
    data = [];
end
if nargin < 2
    regions = [];
end
if nargin < 3
    vol_thresh = [];
end
if nargin < 4
    shift_val = [];
end
if nargin < 5
    conn = [];
end
if nargin < 6
    f_verb = [];
end
if nargin < 7
    verb_pref = [];
end
if nargin < 8
    f_disp = [];
end

%*************************
% Set default parameters *
%*************************
if isempty(vol_thresh)
    vol_thresh = 0.8;
end
if isempty(shift_val)
    shift_val = min(min(data));
end
if isempty(conn)
    conn = 8;
end
if isempty(f_verb)
    f_verb = 0;
end
if isempty(verb_pref)
    verb_pref = '';
end
if isempty(f_disp)
    f_disp = 0;
end

%******************************************
% Check required inputs: data and regions *
%******************************************
if isempty(data)
    error('Data must be specified')
else
    if isempty(regions)
        if f_verb > 0
            disp([verb_pref 'Regions for image data not provided to trimRegionsWShed. Computing regions...']);
        end
        [regions, rgn_lbls, Lborders, amatr] = peaksWShed(data);
        [regions, ~] = regionMergeByWeight(data,regions,rgn_lbls,Lborders,amatr);
        f_valid_inputs = true;

    else
        f_valid_inputs = true;
    end
end

%***************
% Trim regions *
%***************
if f_valid_inputs
    if f_verb > 0
        disp([verb_pref 'Trimming regions...']);
    end
    if f_verb > 1
        waitbar(0);
    end

    % Constants and initialization
    [num_rows,num_cols] = size(data);
    num_regions = length(regions);
    trimmed_regions = regions;
    trimmed_borders = cell(1, num_regions);

    % Shift data for determination of volume
    shift_data = data - shift_val;
    shift_data(shift_data<0) = 0;

    for ii = 1:num_regions
        if ~isempty(regions{ii})
            % Get pixel list of current region and sort by height
            list_pixels = regions{ii};
            [list_vals,idx_sort] = sort(shift_data(list_pixels));
            list_pixels = list_pixels(idx_sort);

            %***********************************
            % Convert to subimage for trimming *
            %***********************************
            % Get row-col locations of region pixels
            [i_full,j_full] = ind2sub([num_rows,num_cols],list_pixels);

            % Size of padding around subimage
            im_buffer = 1;

            % Get bounding box of region pixels
            i_min = max(min(i_full)-im_buffer,1);
            i_max = min(max(i_full)+im_buffer,num_rows);
            j_min = max(min(j_full)-im_buffer,1);
            j_max = min(max(j_full)+im_buffer,num_cols);

            % Get the subimage
            sub_shift_data = shift_data(i_min:i_max, j_min:j_max);

            % Size of the subimage
            num_sub_rows = i_max-i_min+1;
            num_sub_cols = j_max-j_min+1;

            % Convert row-col locations to those in subimage
            i_sub = i_full-(i_min-1);
            j_sub = j_full-(j_min-1);

            % Get linear pixel indices in subimage
            % sub_pixels = sub2ind([num_sub_rows num_sub_cols],i_sub,j_sub);
            sub_pixels = i_sub + (j_sub-1)*num_sub_rows;

            %***********************
            % Find cutoff and trim *
            %***********************
            % Get total region volume and cutoff index
            total_volume = sum(list_vals,'omitnan');
            jj = find(cumsum(list_vals)/total_volume >= (1-vol_thresh),1);

            % Check for constant region, one pixel region, or impossible threshold
            if max(list_vals)~=min(list_vals) && length(list_vals)>1 && ~isempty(jj)

                % Find pixels above cutoff
                level = list_vals(jj);
                sub_trim = sub_pixels(list_vals>=level);

                % Form binary subimage. logical() instead of double so
                % imreconstruct takes its faster binary path.
                tmp_data = false(num_sub_rows,num_sub_cols);
                tmp_data(sub_trim) = true;

                % Inline imfill(tmp_data, 'holes'): reconstruct the complement
                % from its border pixels, then complement back. Bit-identical
                % to imfill('holes') on a pre-padded 2D logical input. Uses
                % 4-connectivity explicitly (imfill's conndef default).
                not_bw = ~tmp_data;
                marker = false(num_sub_rows, num_sub_cols);
                marker(1, :)   = not_bw(1, :);
                marker(end, :) = not_bw(end, :);
                marker(:, 1)   = not_bw(:, 1);
                marker(:, end) = not_bw(:, end);
                tmp_data = ~imreconstruct(marker, not_bw, 4);

                % Connected components → pick largest by shifted-volume.
                tmp_cc = bwconncomp(tmp_data,conn);
                trimmed_vols = cellfun(@(x)sum(sub_shift_data(x),'omitnan'),tmp_cc.PixelIdxList);
                [~,idx] = max(trimmed_vols);
                sub_trim_cc = tmp_cc.PixelIdxList{idx};
                trimmed_regions{ii} = subLidx2FullLidx(sub_trim_cc,[num_sub_rows num_sub_cols],[i_min j_min],[num_rows num_cols]);

                % Inline 4-neighbor perimeter extraction on cc_mask.
                cc_mask = false(num_sub_rows,num_sub_cols);
                cc_mask(sub_trim_cc) = true;
                padded = false(num_sub_rows+2, num_sub_cols+2);
                padded(2:end-1, 2:end-1) = cc_mask;
                bnd_mask = cc_mask & ~( ...
                    padded(1:end-2, 2:end-1) & padded(3:end, 2:end-1) & ...
                    padded(2:end-1, 1:end-2) & padded(2:end-1, 3:end));
                [bi, bj] = find(bnd_mask);
                bi = bi + (i_min-1);
                bj = bj + (j_min-1);
                trimmed_borders{ii} = sub2ind([num_rows num_cols], bi, bj);

                if f_verb > 1
                    if mod(ii,50)==0
                        waitbar(ii/num_regions);
                    end
                end

            else
                % Check for constant region, one pixel region, or impossible threshold
                if f_verb > 0
                    disp([verb_pref '  Constant region encountered: ' num2str(ii)]);
                end
                region_img = zeros(size(data));
                region_img(list_pixels) = 1;
                tmp1 = regionprops(region_img,'centroid');
                tmp2 = round(cat(1,tmp1.Centroid));
                tmp3 = sub2ind(size(data),tmp2(:,2),tmp2(:,1));
                if tmp2(:,1) > 1 && tmp2(:,1) < size(data,2)
                    pad_col = [-1 0 1];
                elseif tmp2(:,1) > 1
                    pad_col = [-1 0];
                elseif tmp2(:,1) < size(data,2)
                    pad_col = [0 1];
                else
                    pad_col = 0;
                end
                if tmp2(:,2) > 1 && tmp2(:,2) < size(data,1)
                    pad_row = [-1 0 1];
                elseif tmp2(:,2) > 1
                    pad_row = [-1 0];
                elseif tmp2(:,2) < size(data,1)
                    pad_row = [0 1];
                else
                    pad_row = 0;
                end
                tmp4 = zeros(length(pad_col)*length(pad_row),1);
                for aa = 1:length(pad_col)
                    for bb = 1:length(pad_row)
                        tmp4((aa-1)*length(pad_row)+bb) = tmp3+pad_col(aa)*size(data,1)+pad_row(bb);
                    end
                end
                trimmed_regions{ii} = intersect(list_pixels,tmp4); % [];
                trimmed_borders{ii} = setdiff(trimmed_regions{ii},tmp3); % [];
            end
        else
            % Region is empty
            trimmed_regions{ii} = [];
            trimmed_borders{ii} = [];
        end
    end
    if f_verb > 1
        waitbar(1);
    end

    % Display trimmed regions
    if f_disp > 0
        tmp_Ldata = cell2Ldata(trimmed_regions,size(data),trimmed_borders);
        RGB2 = label2rgb(tmp_Ldata, 'jet', 'c', 'shuffle');
        R = squeeze(RGB2(:,:,1));
        G = squeeze(RGB2(:,:,2));
        B = squeeze(RGB2(:,:,3));
        R(~tmp_Ldata) = 100;
        G(~tmp_Ldata) = 100;
        B(~tmp_Ldata) = 100;
        RGB2 = cat(3,R,G,B);
        fh = figure('units','normalized','position',[0.7674    0.3978    0.4007    0.4811]);
        ax = axes(fh);
        imagesc(ax,RGB2);
        axis(ax,'xy');
        title(ax,['Regions Trimmed to ' num2str(vol_thresh*100) ' Percent Volume']);
    end

    % else
    %     % Image data not provided for regions
    %     disp('         Returning original regions and empty boundaries.');
    %     trimmed_regions = regions;
    %     trimmed_borders = cell(1, length(regions));
end
