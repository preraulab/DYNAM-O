%%% Plots basic sinewave and sawtooth curves

%ccc;
N=1000;
Np=8;

x=linspace(0,2,N);
y=sin(2*pi*x);
phase=mod(unwrap(angle(hilbert(y))-pi),2*pi)-pi;


peak_freq=rand(Np,N)*100+repmat(mod(-unwrap(phase),2*pi)*20, Np,1);
step=round(N/8);
xstep=[1:step:N N];


bins=-pi:pi/100:pi;

h=[];

for ii=1:length(bins)-1
    pinds=phase>bins(ii) & phase<=bins(ii+1);
    peaks=peak_freq(:,pinds);
    h=[h smooth(hist(peaks(:),linspace(min(peak_freq(:)),max(peak_freq(:)),50)))];
end

n=sum(h); h=h./repmat(n,size(h,1),1);

figure
ax=figdesign(3,1);
linkaxes(ax,'x');
axes(ax(1))
hold all
plot(x(xstep),peak_freq(:,xstep)'+10,'or','markerfacecolor','r','markersize',4);
axis tight
lh=vline(x(xstep),'linewidth',1,'color','k','linestyle',':');
uistack(lh,'bottom');

axes(ax(2))
plot(x,sin(2*pi*x)*pi);
axis tight
lh=vline(x(xstep),'linewidth',1,'color','k','linestyle',':');
uistack(lh,'bottom');

axes(ax(3))
plot(x,phase);
hline(phase(xstep),'linewidth',1,'color','k','linestyle',':')
uistack(lh,'bottom');
axis tight
ylim([-pi pi]*1.1);
xlim([-.1 2.1])

