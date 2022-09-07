function [fh1, params] = mode_centroid_scatterplot(powhists, phasehists, issz, night, freq_cbins, SOpow_cbins, SOphase_cbins, elect_num,...
                                           fsave_path, print_png, print_eps)
% Compute and plot modes of each ROI for each subj/night and run
% statistical analysis on frequency and SOpower position of groups
%
% Inputs:
%       powhists: cell array - each cell contains an electrode's data (3D double 
%                 [SOpow, freq, subj/night]
%       phasehists: cell array - each cell contains an electrode's data (3D double 
%                 [SOphase, freq, subj/night]
%       issz: 1D logical - subject SZ status. Should be same length as 3rd dim of 
%             powhists/phasehists
%       night: 1D double - integer indicating which night. Should be same length as 
%              3rd dim of powhists/phasehists
%       freq_cbins: 1D double - center of each frequency bin in powhists and phasehists. 
%                   Should be same length as 2nd dim of powhists/phasehists
%       SOpow_cbins: 1D double - center of each SOpow bin in powhists. 
%                   Should be same length as 1st dim of powhists
%       SOphase_bins: 1D double - center of each SOphase bin in phasehists. 
%                   Should be same length as 1st dim of phasehists
%       elect_num: double - index of electrode to use for analysis
%       fsave_path: char - path to save png/eps to
%       print_png: logical - save figure as png
%       pring_eps: logical - save figure as eps
%       
% Outputs:
%       fh1: figure handle - scatter plot of ROI modes 
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - adapted script from Michael Prerau - Tom Possidente 03/28/2022
%%%************************************************************************************%%%

%% Initialize ROIs
pow_ROIs = {(SOpow_cbins >= 0.15) , (freq_cbins >= 12 & freq_cbins < 16);...
    (SOpow_cbins >= 0.7) , (freq_cbins >= 10 & freq_cbins < 12);...
    (SOpow_cbins>=0.2)&(SOpow_cbins < 0.8) , (freq_cbins >= 7.5 & freq_cbins < 10);...
    (SOpow_cbins < 0.7) , (freq_cbins >= 4 & freq_cbins < 6)};
num_pow_ROIs = size(pow_ROIs,1);

pow_ROI_names = {'\sigma_{fast}', '\sigma_{slow}', '\alpha_{low}', '\theta'};

pow_ROI1 = [15, 12, 85, 4];
pow_ROI2 = [70, 10, 30, 2];
pow_ROI3 = [20, 7.5, 60, 2.5];
pow_ROI4 = [0, 4, 70, 2];


phase_ROIs = {(SOphase_cbins >= -pi/2 & SOphase_cbins <= pi/2) , (freq_cbins >= 11 & freq_cbins < 16);...
   (SOphase_cbins >= -pi & SOphase_cbins <= pi/2), (freq_cbins >= 6 & freq_cbins < 11)};
num_phase_ROIs = size(phase_ROIs,1);


HC_inds = find(~issz & night > 0);
SZ_inds = find(issz & night > 0);

%% Get power centroids for each subj in each group
for group = 1:2
    if group == 1
        sub_inds = HC_inds;
    else
        sub_inds = SZ_inds;
    end
    
    for ii = 1:length(sub_inds)
        disp(ii);
        pow_hist = squeeze(powhists{elect_num}(:,:,sub_inds(ii)));

        for ROI_num = 1:num_pow_ROIs
            
            freq_inds = pow_ROIs{ROI_num,2};
            pow_inds = pow_ROIs{ROI_num,1};
            
            ROI_pows = SOpow_cbins(pow_inds);
            ROI_freqs = freq_cbins(freq_inds);
            
            ROI_data = pow_hist(freq_inds, pow_inds);
            ROIexp = exp(ROI_data);
            
            sum_data = sum(ROIexp,'all');
            
            pow_centroid = sum(repmat(ROI_pows,length(ROI_freqs),1).*ROIexp,'all')/sum_data;
            freq_centroid = sum(repmat(ROI_freqs,length(ROI_pows),1)'.*ROIexp,'all')/sum_data;
            
            [F,P] = meshgrid(ROI_freqs, ROI_pows);
            centroid_density = interp2(F,P,ROI_data', freq_centroid, pow_centroid);
            
            pow_centroids(group).ROI(ROI_num).coords(ii,:) = [pow_centroid, freq_centroid, centroid_density];
            
            
        end

    end
end

%% Get phase centroids
for group = 1:2
    if group == 1
        sub_inds = HC_inds;
    else
        sub_inds = SZ_inds;
    end
    
    for ii = 1:length(sub_inds)
        disp(ii);
        phasehist = squeeze(phasehists{elect_num}(:,:,sub_inds(ii)));
                
        for ROI_num = 1:num_phase_ROIs
            
            freq_inds = phase_ROIs{ROI_num,2};
            phase_inds = phase_ROIs{ROI_num,1};
            
            ROI_phases = SOphase_cbins(phase_inds);
            ROI_freqs = freq_cbins(freq_inds);
            
            ROI_data = phasehist(freq_inds, phase_inds)*1000;
            ROI_data = ROI_data-min(ROI_data(:));
            ROI_data = ROI_data/max(ROI_data(:))*100;
            ROIexp = exp(ROI_data);
            
            sum_data = sum(ROIexp,'all');
            
            phase_centroid = sum(repmat(ROI_phases,length(ROI_freqs),1).*ROIexp,'all')/sum_data;
            freq_centroid = sum(repmat(ROI_freqs,length(ROI_phases),1)'.*ROIexp,'all')/sum_data;
            
            [F,P] = meshgrid(ROI_freqs, ROI_phases);
            centroid_prop = interp2(F,P,ROI_data', freq_centroid, phase_centroid);
            
            phase_centroids(group).ROI(ROI_num).coords(ii,:) = [phase_centroid, freq_centroid, centroid_prop];
            
        end
        
    end
end

%% Plot Power centroids

fh1 = figure;
ax1 = figdesign(1,2,'type','usletter','orient','landscape','margins',[.05 .1 .1 .05 .1]);
set(gcf,'position',[0.0404    2.7071   17.9798    5.8586]);

markers = 'ooooo';

group = issz(night > 0);
axes(ax1(1))
for rr = 1:num_pow_ROIs

    ROI_all = [pow_centroids(1).ROI(rr).coords; pow_centroids(2).ROI(rr).coords];
    ginds = ~isnan(ROI_all(:,1));

    xlim([0 100]);
    ylim([4 25]);
    hold on;
    
    sizemag = 20;
    s1 = scatter(ROI_all(group(ginds),1)*100,  ROI_all(group(ginds),2), ROI_all(group(ginds),3)*sizemag,[markers(rr) 'r'],'filled','linewidth',1);
    s2 = scatter(ROI_all(~group(ginds),1)*100,  ROI_all(~group(ginds),2), ROI_all(~group(ginds),3)*sizemag,[markers(rr) 'b'],'filled','linewidth',1);
    
end

alpha(ax1(1),.6);
xlabel(ax1(1),'%SO-Power');
ylabel(ax1(1),'Frequency (Hz)');

rectangle('Position',pow_ROI1,'linestyle','--');
rectangle('Position',pow_ROI2,'linestyle','-');
rectangle('Position',pow_ROI3,'linestyle',':');
rectangle('Position',pow_ROI4,'linestyle','-.');

legend([s2 s1],{'HC','SZ'})
title('Power Mode Centroids');

%% Plot phase centroids
axes(ax1(2))
for rr = 1:num_phase_ROIs

    ROI_all = [phase_centroids(1).ROI(rr).coords; phase_centroids(2).ROI(rr).coords];
    ginds = ~isnan(ROI_all(:,1));

    xlim([-pi pi]);
    ylim([4 25]);
    hold on;
    
    sizemag = 1;
    s1 = scatter(ROI_all(group(ginds),1),  ROI_all(group(ginds),2), ROI_all(group(ginds),3)*sizemag,[markers(rr) 'r'],'filled','linewidth',1);
    s2 = scatter(ROI_all(~group(ginds),1),  ROI_all(~group(ginds),2), ROI_all(~group(ginds),3)*sizemag,[markers(rr) 'b'],'filled','linewidth',1);
    
end

alpha(ax1(2),.6);
xlabel(ax1(2),'SO-Phase');
ylabel(ax1(2),'Frequency (Hz)');

legend([s2 s1],{'HC','SZ'})
title('Phase Mode Centroids');

%% Save
if print_png
    print(fh1,'-dpng', '-r300',fullfile( fsave_path, 'PNG','SZ_HC_ROI_MODES_SCATTER.png'));
end

if print_eps
    print(fh1,'-depsc', fullfile(fsave_path, 'EPS', 'SZ_HC_ROI_MODES_SCATTER.eps'));
end





