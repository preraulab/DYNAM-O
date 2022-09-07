%%% Plots schematic explanation of power histogram with simulated data

%Maximum power simulation value
max_value=1;

%Rate maximum
r_max=.01;

%Create the time vector
T_pow=0:.05:475;

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
        r_max=.8*r_max;
        
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

%% CREATE POWER SCHEMATIC FIGURE
figure
%Create the figure
ax=figdesign(5,1,'type','usletter','orient','portrait','merge',{1:2,4:5});
linkaxes(ax(1:2),'x');

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

axes(ax(2))
plot(T_pow,SWP*100,'k','linewidth',2)
axis tight;
hline(0:25:100,'linewidth',1,'color','k','linestyle',':');
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


axes(ax(3))
imagesc(pow_bin_centers*100,pow_freqs,pow_hist'); axis xy;
xlabel('% Slow Wave Power');
ylabel('Frequency (Hz)');
climscale(ax(3), [],false);
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

