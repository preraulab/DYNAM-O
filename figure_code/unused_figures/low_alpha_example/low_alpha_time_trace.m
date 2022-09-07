ccc;
%% Load data
[data, Fs, t, labels, stages] = load_Lunesta_data(17,2,true,'C3');

%% Create spectrogram 
multitaper_spectrogram_mex(data, Fs, [0,25], [15,29], [30,15]);
climscale;
colormap(jet(1024));

[spect, stimes, sfreqs] = multitaper_spectrogram_mex(data, Fs, [4,25], [2,3], [1,0.1], 2^10,'constant','unity',false);

%% Run filters

lowalpha_Filt = designfilt('bandpassiir','FilterOrder',100, ...
         'HalfPowerFrequency1',7,'HalfPowerFrequency2',10, ...
         'SampleRate',Fs);


spindle_Filt = designfilt('bandpassiir','FilterOrder',100, ...
         'HalfPowerFrequency1',12,'HalfPowerFrequency2',16, ...
         'SampleRate',Fs);
% fvtool(bpFilt)

spindledata = filtfilt(spindle_Filt,data);
lowalphadata = filtfilt(lowalpha_Filt,data);

%% Plot 
figure;
ax = figdesign(6,1, 'margins', [.025 .1 .025 .025 .04],'merge',{[2:4]});

axes(ax(1))
hypnoplot(stages);

axes(ax(2));
imagesc(stimes, sfreqs, nanpow2db(spect));
axis xy;        
colormap jet;
climscale(false);
scaleline(ax(2),5,'5s');
c = colorbar_noresize;
c.Label.String = {'Power (dB)'};
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";     
ylim([2,25]);
ylabel('Frequency (Hz)');

axes(ax(3));
plot(t(1:2:end), spindledata(1:2:end));
axis tight;
xlabel('Time (s)');
ylabel('7-10Hz Filtered Signal');
ylim([-30,30])


axes(ax(4));
plot(t(1:2:end), lowalphadata(1:2:end));
axis tight;
xlabel('Time (s)');
ylabel('7-10Hz Filtered Signal');
ylim([-30,30])

linkaxes(ax,'x')

scrollzoompan;

