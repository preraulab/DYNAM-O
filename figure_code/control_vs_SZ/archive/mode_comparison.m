%%
close all;
clc;

elect_num = 1;
night = 2;

freq_bins = freq_cbins_final;
pow_bins = SOpow_cbins_final;
phase_bins =  SOphase_cbins_final;


pow_ROIs = {(pow_bins >= 0.2) , (freq_bins >= 12.5 & freq_bins < 16);...
    (pow_bins >= 0.7) , (freq_bins >= 10 & freq_bins < 12.5);...
    (pow_bins >=.1 & pow_bins<0.7) , (freq_bins >= 7.5 & freq_bins < 10);...
    (pow_bins < 0.8) , (freq_bins >= 4 & freq_bins < 6)};
num_pow_ROIs = size(pow_ROIs,1);


pow_ROI1 = [20, 12, 80, 4];
pow_ROI2 = [70, 10, 30, 2];
pow_ROI3 = [0, 7.5, 70, 2.5];
pow_ROI4 = [0, 4, 80, 2];


pow_ROI_names = {'\sigma_{high}','\sigma_{low}','\alpha_{low}','\theta'};

phase_ROIs = {(phase_bins >= -pi/2 & phase_bins <= pi/2) , (freq_bins >= 11 & freq_bins < 16);...
   (phase_bins >= -pi & phase_bins <= pi/2), (freq_bins >= 6 & freq_bins < 11)};
num_phase_ROIs = size(phase_ROIs,1);

phase_ROI_names = {'\sigma_{high}','\sigma_{low}','\alpha_{low}','\theta'};


HC_inds = find(~issz_out & night_out == 2);
SZ_inds = find(issz_out & night_out == 2);

markers = 'ooooo';%^v';
clear pow_centroids
for group = 1:2
    if group == 1
        sub_inds = HC_inds;
    else
        sub_inds = SZ_inds;
    end
    
    for ii = 1:length(sub_inds)
        disp(ii);
        pow_hist = squeeze(powhists{elect_num}(:,:,sub_inds(ii)));
%                 close all;
%         ax1 = gca;
%                 imagesc(pow_bins, freq_bins, pow_hist)
%                 axis xy;
%                 climscale(false);
%         
%         hold on
        
        for ROI_num = 1:num_pow_ROIs
            

            
            freq_inds = pow_ROIs{ROI_num,2};
            pow_inds = pow_ROIs{ROI_num,1};
            
            ROI_pows = pow_bins(pow_inds);
            ROI_freqs = freq_bins(freq_inds);
            
            ROI_data = pow_hist(freq_inds, pow_inds);
            ROIexp = exp(ROI_data);
            
            sum_data = sum(ROIexp,'all');
            
            pow_centroid = sum(repmat(ROI_pows,length(ROI_freqs),1).*ROIexp,'all')/sum_data;
            freq_centroid = sum(repmat(ROI_freqs,length(ROI_pows),1)'.*ROIexp,'all')/sum_data;
            
            [F,P] = meshgrid(ROI_freqs, ROI_pows);
            centroid_density = interp2(F,P,ROI_data', freq_centroid, pow_centroid);
            
            pow_centroids(group).ROI(ROI_num).coords(ii,:) = [pow_centroid, freq_centroid, centroid_density];
            
            
%             figure
%             ax = figdesign(2,1);
%             axes(ax(1))
%             imagesc(ROI_pows, ROI_freqs, ROI_data);
%              climscale(false);
%             axis xy;
%             
%             axes(ax(2))
%             fit_results = create3dGaussFit(ROI_pows, ROI_freqs, ROI_data);
%            param_fits(group).ROI(ROI_num).params(ii,:) = [fit_results.pmean fit_results.fmean fit_results.amp];
            
%             plot(ax1,pow_centroid, freq_centroid,'o','markerfacecolor','m');
            
        end
        
%             pause
%             close all
    end
end
%%
close all;
for group = 1:2
    if group == 1
        sub_inds = HC_inds;
    else
        sub_inds = SZ_inds;
    end
    
    for ii = 1:length(sub_inds)
        disp(ii);
        phasehist = squeeze(phasehists{elect_num}(:,:,sub_inds(ii)));
%                 close all;
%         ax1 = gca;
%                 imagesc(phase_bins, freq_bins, phasehist)
%                 axis xy;
%                 climscale(false);
        
        hold on
        
        for ROI_num = 1:num_phase_ROIs
            

            
            freq_inds = phase_ROIs{ROI_num,2};
            phase_inds = phase_ROIs{ROI_num,1};
            
            ROI_phases = phase_bins(phase_inds);
            ROI_freqs = freq_bins(freq_inds);
            
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
            
            
%             figure
% %             ax = figdesign(2,1);
% %             axes(ax(1))
%             imagesc(ROI_phases, ROI_freqs, ROI_data);
%              climscale(false);
%             axis xy;
%             hold on
%             plot(phase_centroid, freq_centroid,'o','markerfacecolor','m');
%         pause
%             axes(ax(2))
%             fit_results = create3dGaussFit(ROI_pows, ROI_freqs, ROI_data);
%            param_fits(group).ROI(ROI_num).params(ii,:) = [fit_results.pmean fit_results.fmean fit_results.amp];
            
%             plot(ax1,phase_centroid, freq_centroid,'o','markerfacecolor','m');
            
        end
%         pause
        
    end
end

%%

% views = [-113.3522   15.1301;...
%     0.0351    3.8289;...
%    48.5180    5.0185;...
%  -272.8766    9.7769];

close all

figure;
ax1 = figdesign(1,2,'type','usletter','orient','landscape','margins',[.05 .1 .1 .05 .1]);
set(gcf,'position',[0.0404    2.7071   17.9798    5.8586]);
all_data = [];

group = issz_out(night_out == 2);
axes(ax1(1))
for rr = 1:num_pow_ROIs
%     rr
%     axes(ax1(rr));
%     hold on
%     plot3(centroids(1).ROI(rr).coords(:,1),centroids(1).ROI(rr).coords(:,2),centroids(1).ROI(rr).coords(:,3),'.b')
%     plot3(centroids(2).ROI(rr).coords(:,1),centroids(2).ROI(rr).coords(:,2),centroids(2).ROI(rr).coords(:,3),'xr')
%     
%     xlabel('%SO Power'),
%     ylabel('Freq.(HZ)');
%     zlabel('Density');
%     title(pow_ROI_names{rr})
%     view(views(rr,:))
%     
%     
    
%         ROI_all = [param_fits(1).ROI(rr).params; param_fits(2).ROI(rr).params];

    ROI_all = [pow_centroids(1).ROI(rr).coords; pow_centroids(2).ROI(rr).coords];
    ginds = ~isnan(ROI_all(:,1));

    xlim([0 100]);
    ylim([4 25]);
    hold on;
    
    sizemag = 20;
    s1 = scatter(ROI_all(group(ginds),1)*100,  ROI_all(group(ginds),2), ROI_all(group(ginds),3)*sizemag,[markers(rr) 'r'],'filled','linewidth',1);
    s2 = scatter(ROI_all(~group(ginds),1)*100,  ROI_all(~group(ginds),2), ROI_all(~group(ginds),3)*sizemag,[markers(rr) 'b'],'filled','linewidth',1);
    
    
%     all_data = [all_data  ROI_all];
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

%%
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
    
    
%     all_data = [all_data  ROI_all];
end

alpha(ax1(1),.6);
xlabel(ax1(1),'%SO-Phase');
ylabel(ax1(1),'Frequency (Hz)');
% 
% rectangle('Position',pow_ROI1,'linestyle','--');
% rectangle('Position',pow_ROI2,'linestyle','-');
% rectangle('Position',pow_ROI3,'linestyle',':');
% rectangle('Position',pow_ROI4,'linestyle','-.');

legend([s2 s1],{'HC','SZ'})
title('Power Mode Centroids');
