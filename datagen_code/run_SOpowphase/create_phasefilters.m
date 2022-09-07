ccc;

Fss = [50,100,128,200,256,500,512];

SO_freq_low = [0.3, 0.5];
SO_freq_low_strs = {'0dot3', '0dot5'};

SO_freq_high = [1, 1.5, 5];
SO_freq_high_strs = {'1', '1dot5', '5'};

for f = 1:length(Fss)
    for fl = 1:length(SO_freq_low)
        for fh = 1:length(SO_freq_high)
            Fs = Fss(f);
            SO_freqrange = [SO_freq_low(fl), SO_freq_high(fh)];
            
            filter_str = ['filter_', num2str(Fs), 'Hz_', SO_freq_low_strs{fl}, '_', SO_freq_high_strs{fh}];

            d = designfilt('bandpassiir', ...       % Response type
                           'StopbandFrequency1',SO_freqrange(1)-0.1, ...    % Frequency constraints
                           'PassbandFrequency1',SO_freqrange(1), ...
                           'PassbandFrequency2',SO_freqrange(2), ...
                           'StopbandFrequency2',SO_freqrange(2)+0.1, ...
                           'StopbandAttenuation1',60, ...   % Magnitude constraints
                           'PassbandRipple',1, ...
                           'StopbandAttenuation2',60, ...
                           'DesignMethod','ellip', ...      % Design method
                           'MatchExactly','passband', ...   % Design method options
                           'SampleRate',Fs);

            eval([filter_str, ' = d;']);

        end
    end
end

save('SOphase_filters2.mat');
