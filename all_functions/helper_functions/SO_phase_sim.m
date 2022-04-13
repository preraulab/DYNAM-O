function SO_phase_sim(Fs, minutes, phase_pref, sim_density, method)

if nargin == 0
%Set simulation time
Fs = 200;
minutes = 120;

%Set phase pref and max prob
phase_pref = -pi/4;
sim_density = 20;

%Chose pure sinusoid or random SO
method = 'sin';

SO_phase_sim(Fs, minutes, phase_pref, sim_density, method);
return;
end

if nargin<1
    Fs = 200;
end

if nargin<2
    minutes = 60;
end

if nargin<3
    phase_pref = 0;
end

if nargin<4
    sim_density = 10;
end

if nargin<4
    method = 'sin';
end

T = 60*minutes*Fs;
t = (1:T)/Fs;

switch lower(method)
    case 'sin'
        %Set SO as sinwave
        SO = sin(t*2*pi);
    case 'random'
        %Set random SO-pow by filtering white noise at SO range
        SO = quickbandpass(randn(1,T)*10,Fs,[.3 1.5]);
    otherwise
        error('Invalid method. Use "random" or "sin"');
end

%Extract SO-phase
SO_phase = angle(hilbert(SO));

%Set peak probability
prob_peak = 1-(min([abs(SO_phase - phase_pref);...
    abs((SO_phase + 2*pi)  - phase_pref); ...
    abs((SO_phase - 2*pi)  - phase_pref)] )/pi);

% peak_times = find(rand(1,T)<prob_peak);
peak_inds = poissrnd(prob_peak/Fs/60*sim_density*2,1,T)>0;
num_peaks = sum(peak_inds);
peak_times = t(peak_inds);
peak_phases = SO_phase(peak_inds);
num_min = length(t)/Fs/60;
mean_density = num_peaks/num_min;

figure
phasehistogram(peak_phases,1,'NumBins',100);
title(['Density: ' num2str(mean_density) ' events/min'])
