%%% Plots schematic explanation of phase histogram with simulated data
%ccc

%Number of simulation points
N_phase_peaks=10000;

%Time vector
T_phase=linspace(0,3.5,N_phase_peaks);

%Generate slow wave amlitude and phase
SWA=sin(2*pi*T_phase);
SWA_phase=mod(unwrap(angle(hilbert(SWA))-pi),2*pi)-pi;

%Create frequency vector
N_phase_freqs=100;
freqs=linspace(0,20,N_phase_freqs);

%Generate phase bins
N_phase_bins=100;
phases=linspace(-pi,pi,N_phase_bins);

%Create the phase probability matrix
phase_prob_mat=ones(N_phase_freqs,N_phase_bins)*.5;

%Set width of modes
mode_spread=3;
%Set mode frequencies
mode_freqs=[14 5];

%Generate the probability matrix
for ff=1:N_phase_freqs
    %Generate upper mode
    if freqs(ff)>mode_freqs(1)-mode_spread && freqs(ff)<mode_freqs(1)+mode_spread
        phase_prob_mat(ff,:)=(sin(phases+pi/2)*(mode_spread^2-(mode_freqs(1)-freqs(ff)).^2)+1);
    end
%     
%     %Generate lower mode
%     if freqs(ff)>mode_freqs(2)-mode_spread && freqs(ff)<mode_freqs(2)+mode_spread
%         phase_prob_mat(ff,:)=(cos(phases+pi/2)*(mode_spread^2-(mode_freqs(2)-freqs(ff)).^2)+1);
%     end
end


%Normalize probability matrix and scale for good visual results
phase_prob_mat=phase_prob_mat-min(phase_prob_mat(:));
phase_prob_mat=phase_prob_mat./max(phase_prob_mat(:));
phase_prob_mat=phase_prob_mat*5;

%Simulate peaks
iterations=100000;
simulated_peaks=zeros(iterations,3);

parfor ii=1:iterations
    %Pick a random time
    peak_time=rand*T_phase(end);
    [~,t_ind]=min(abs(T_phase-peak_time));
    
    %Find the phase at that time
    peak_phase=SWA_phase(t_ind);
    [~,p_ind]=min(abs(phases-peak_phase));
    
    %Generate a random frequency
    peak_freq=rand*freqs(N_phase_freqs);
    [~,f_ind]=min(abs(freqs-peak_freq));
    
    %Create a spike based on the probability matrix at that phase/freq
    peak_count=poissrnd(phase_prob_mat(f_ind,p_ind));
    
    %Add to matrix
    simulated_peaks(ii,:)=[peak_time peak_freq peak_count];
end

%Scale the peak counts so that the max count is 1. This improves
%visualization since each sim peak likely to produce multiple counts
simulated_peaks(:,3)=round(simulated_peaks(:,3)./max(simulated_peaks(:,3)));
good_inds=simulated_peaks(:,3)>0;

%Create the histogram
bin_width=.5;
bins=linspace(-pi,pi,100);

%Create rectangles to show similar phase regions in all plots
phase_rect_center=0;
phase_rect_width=.4;

%Find the rectangle boundaries
phase_rect_inds=SWA_phase>(phase_rect_center(1)-phase_rect_width) & SWA_phase<phase_rect_center(1)+phase_rect_width;
phase_rect_starts=find(diff(phase_rect_inds)==1)+1;
phase_rect_ends=find(diff(phase_rect_inds)==-1);

%% CREATE THE PHASE FIGURE

figure
ax=figdesign(5,1,'type','usletter','orient','portrait','merge',{1:2,4:5});
linkaxes(ax(1:2),'x');

%Extracted Peaks
axes(ax(1))
hold all
plot(simulated_peaks(good_inds,1),simulated_peaks(good_inds,2),'.');
axis tight

ylabel('Frequency (Hz)');
title('Extracted Peaks');
xlim([0 max(T_phase)])

scaleline(1,'1 second');
xlabel('Time');

hold on
yl=ylim;
for rr=1:length(phase_rect_starts)
    fill(T_phase([phase_rect_starts(rr)  phase_rect_starts(rr) phase_rect_ends(rr) phase_rect_ends(rr)]),[yl(1) yl(2) yl(2) yl(1)],'r'); 
end

%Slow Wave and Phase
axes(ax(2))
hold on
axy=plotyy(T_phase,SWA,T_phase,SWA_phase);
ylim(axy(2),[-pi,pi])
ylabel(axy(2),'Slow Wave Phase')
hline(0);

ylabel(axy(1),'Slow Waveform')
set(axy(1),'ytick',[])
set(axy,'xtick',[])

%Phase histogram
axes(axy(2));
hold on;
hline(linspace(-pi,pi,5),'linewidth',1,'color','k','linestyle',':');
title('Slow Waveform and Phase')
scaleline(1,'1 second');
xlabel('Time');
yticks([-pi -pi/2 0 pi/2 pi]);
yticklabels({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'})

hold on
yl=ylim;
for rr=1:length(phase_rect_starts)
    fill(T_phase([phase_rect_starts(rr)  phase_rect_starts(rr) phase_rect_ends(rr) phase_rect_ends(rr)]),[yl(1) yl(2) yl(2) yl(1)],'r'); 
end

axes(ax(3))
imagesc(phases,freqs,phase_prob_mat); axis xy
xlabel('Phase (rad)');
ylabel('Frequency (Hz)');
climscale(ax(3),[],false);
axis tight;
title('Phase Histogram');
colormap(magma(2^12));

phase_rect_inds=phases>(phase_rect_center(1)-phase_rect_width) & phases<phase_rect_center(1)+phase_rect_width;
phase_rect_starts=find(diff(phase_rect_inds)==1)+1;
phase_rect_ends=find(diff(phase_rect_inds)==-1);

hold on
yl=ylim;
for rr=1:length(phase_rect_starts)
    fill(phases([phase_rect_starts(rr)  phase_rect_starts(rr) phase_rect_ends(rr) phase_rect_ends(rr)]),[yl(1) yl(2) yl(2) yl(1)],'r'); 
end

xticks([-pi -pi/2 0 pi/2 pi]);
xticklabels({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'})
axis square
