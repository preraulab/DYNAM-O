%% CREATE POWER SCHEMATIC

%Maximum power simulation value
max_value=1;

%Rate maximum
r_max=.01;

%Create the time vector
T_pow=0:.05:375;

%Set the slow wave power to close to zero to start
SWP=zeros(size(T_pow));
SWP(1)=.001;

%Loop over all time
for ii=2:length(T_pow)
    
    %Compute the slow wave using logistic growth
    dNdt=r_max*((max_value-SWP(ii-1))/max_value)*SWP(ii-1);
    SWP(ii)=SWP(ii-1)+dNdt;
    
    %Reset the SW every 90 seconds
    if ~mod(T_pow(ii),90)
        %Reset the power
        SWP(ii)=.001;
        
        %Reduce the rate
        r_max=.75*r_max;
        
        %Redice the max values
        max_value=max_value*.95;
    end
    
    %Randomly decide to create a spindle peak or slow peak
    if rand<1-SWP(ii)/2
        %Create spindle peak
        
        %Make it unlikely to fire below .1
        if rand<1-10*(SWP(ii)-.1)
            power_peaks(ii)=nan;
        else
            %Create a spindle peak with frequency based on the SWP
            power_peaks(ii)=randn*.6+15-(SWP(ii))*3;
            
            %Jump to "slow" spindles when SWP is high enough
            if SWP(ii)>.85
                power_peaks(ii)=randn*.4+13.5-(SWP(ii))*3;
            end
        end
    else
        %Create a slow peak
        power_peaks(ii)=max(randn*SWP(ii)/2+SWP(ii),.1);
    end
end

%Create the histogram
pow_bin_width=.2;
pow_bin_centers=0:.01:1;
pow_freqs=linspace(0,20,100);

for ii=1:length(pow_bin_centers)-1
    inds=SWP>max(0,pow_bin_centers(ii)-pow_bin_width/2) & SWP<=min(pow_bin_centers(ii)+pow_bin_width/2,1);
    pow_hist(ii,:)=smooth(hist(power_peaks(inds),pow_freqs))./sum(inds);
end

pow_rect=50/100;
pow_rect_width=10/100;

pow_rect_inds=SWP>(pow_rect(1)-pow_rect_width) & SWP<pow_rect(1)+pow_rect_width;
pow_rect_starts=find(diff(pow_rect_inds)==1)+1;
pow_rect_ends=find(diff(pow_rect_inds)==-1);

%% CREATE PHASE SCHEMATIC

%Number of simulation points
N_phase_peaks=10000;

%Time vector
T_phase=linspace(0,8,N_phase_peaks);

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
    
    %Generate lower mode
    if freqs(ff)>mode_freqs(2)-mode_spread && freqs(ff)<mode_freqs(2)+mode_spread
        phase_prob_mat(ff,:)=(cos(phases+pi/2)*(mode_spread^2-(mode_freqs(2)-freqs(ff)).^2)+1);
    end
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

%% CREATE JOINT SCHEMATIC FIGURE

fh = figure;
%Create the figure
ax=figdesign(5,2,'type','usletter','orient','landscape','merge',{[1 3],[2 4],[7 9],[8 10]});
linkaxes(ax([1 3]),'x');
linkaxes(ax([2 4]),'x');

axes(ax(1))
plot(T_pow(1:2:end),power_peaks(1:2:end),'.');

ylabel('Frequency (Hz)');
title('Extracted Peaks');
xlim([0 max(T_pow)])
ylim([0 20]);

hold on
yl=ylim;
for rr=1:length(pow_rect_starts)
    fill(T_pow([pow_rect_starts(rr)  pow_rect_starts(rr) pow_rect_ends(rr) pow_rect_ends(rr)]),[yl(1) yl(2) yl(2) yl(1)],'r');
end

scaleline(60,'1 hour');
xlabel('Time');

axes(ax(3))
plot(T_pow,SWP*100,'k','linewidth',2)
axis tight;
hline(0:25:100, 'linewidth', 1,'color', 'k', 'linestyle',':');
ylabel('% Slow Wave Power');
title('Slow Wave Power');
xlim([0 max(T_pow)])
ylim([0 100]);

hold on
yl=ylim;
for rr=1:length(pow_rect_starts)
    fill(T_pow([pow_rect_starts(rr)  pow_rect_starts(rr) pow_rect_ends(rr) pow_rect_ends(rr)]),[yl(1) yl(2) yl(2) yl(1)],'r');
end

scaleline(60,'1 hour');
xlabel('Time');

axes(ax(5))
imagesc(pow_bin_centers*100,pow_freqs,pow_hist'); axis xy;
xlabel('% Slow Wave Power');
ylabel('Frequency (Hz)');
climscale(ax(5), [], false);
axis tight;
title('Power Histogram');
axis square

pow_rect_inds=pow_bin_centers>(pow_rect(1)-pow_rect_width) & pow_bin_centers<(pow_rect(1)+pow_rect_width);
pow_rect_starts=find(diff(pow_rect_inds)==1)+1;
pow_rect_ends=find(diff(pow_rect_inds)==-1);

hold on
yl=ylim;
for rr=1:length(pow_rect_starts)
    fill(pow_bin_centers([pow_rect_starts(rr)  pow_rect_starts(rr) pow_rect_ends(rr) pow_rect_ends(rr)])*100,[yl(1) yl(2) yl(2) yl(1)],'r');
end

%% CREATE THE PHASE FIGURE

%Extracted Peaks
axes(ax(2))
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
axes(ax(4))
hold on
axy=plotyy(T_phase,SWA,T_phase,SWA_phase);

linkaxes([axy ax(4)],'x');

ylim(axy(2),[-pi,pi])
ylabel(axy(2),'Slow Wave Phase')
hline(0);

ylabel(axy(1),'Slow Waveform')
set(axy(1),'ytick',[])
set(axy,'xtick',[])

%Phase histogram
axes(axy(2));
hold on;
axis tight

hline(linspace(-pi,pi,5), 'linewidth', 1, 'color', 'k', 'linestyle', ':');
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

xlim([2 5.5])

axes(ax(6))
imagesc(phases,freqs,phase_prob_mat); axis xy
xlabel('Phase (rad)');
ylabel('Frequency (Hz)');
climscale;
axis tight;
title('Phase Histogram');

colormap(ax(6),magma(2^12));

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

%% Print if selected
if print_png
    print(fh,'-dpng', '-r600',fullfile( fsave_path, 'PNG','schematic_pow_phase.png'));
end

if print_eps
    print(fh,'-depsc', fullfile(fsave_path, 'EPS', 'schematic_pow_phase.eps'));
end
