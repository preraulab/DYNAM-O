function plotStageMedSpectra(spgm,times,freqs,stage_struct,stages)

if nargin < 5
    stages = [];
end
if isempty(stages)
    stages = {'N3','N2','N1','REM','Wake'};
end
times = times(:);
t_lightsout = min(stage_struct.time(stage_struct.stage~=5))-5*60;
t_lightson = max(stage_struct.time(stage_struct.stage~=5))+5*60;
pick_lightsout = times>=t_lightsout & times<=t_lightson;

figure;
hold all;
for ss = 1:5
    pick_stage = find_stage_indices(times,stage_struct,ss);
    pick_plot_times = pick_lightsout & pick_stage;
    plot(freqs,pow2db(median(spgm(:,pick_plot_times),2)));
end
legend(stages);