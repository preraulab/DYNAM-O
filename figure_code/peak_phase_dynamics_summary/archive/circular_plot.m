            % generate normalized circular histograms & mean vector phase and length
            while false
                figure
                subplot(2,3,1);
                polarhistogram(wamsley_phase, 30, 'Normalization', 'pdf');
                rlimit1 = rlim;
                title('Wamsley SO Phase', 'FontSize', 16)
                subplot(2,3,2);
                polarhistogram(helfrich_phase, 30, 'Normalization', 'pdf');
                rlimit2 = rlim;
                title('Helfrich SO Phase', 'FontSize', 16)
                subplot(2,3,3);
                polarhistogram(tfpeak_phase, 30, 'Normalization', 'pdf');
                rlimit3 = rlim;
                title('TFpeak SO Phase', 'FontSize', 16)
                maxrlim = max([rlimit1(2), rlimit2(2), rlimit3(2)]);
                subplot(2,3,1); rlim([0, maxrlim])
                subplot(2,3,2); rlim([0, maxrlim])
                subplot(2,3,3); rlim([0, maxrlim])
                
                phase = wamsley_phase';
                mu = circ_mean(phase);
                r = circ_r(phase);
                x = r * cos(mu);
                y = r * sin(mu);
                subplot(2,3,4)
                max_lim = 0.15;
                x_fake=[0 max_lim 0 -max_lim];
                y_fake=[max_lim 0 -max_lim 0];
                h_fake=compass(x_fake,y_fake);
                hold on;
                h=compass(x,y);
                set(h_fake,'Visible','off');
                h.LineWidth = 4;
                title('Mean Circular Vector', 'FontSize', 16)
                
                phase = helfrich_phase';
                mu = circ_mean(phase);
                r = circ_r(phase);
                x = r * cos(mu);
                y = r * sin(mu);
                subplot(2,3,5)
                max_lim = 0.15;
                x_fake=[0 max_lim 0 -max_lim];
                y_fake=[max_lim 0 -max_lim 0];
                h_fake=compass(x_fake,y_fake);
                hold on;
                h=compass(x,y);
                set(h_fake,'Visible','off');
                h.LineWidth = 4;
                title('Mean Circular Vector', 'FontSize', 16)
                
                phase = tfpeak_phase';
                mu = circ_mean(phase);
                r = circ_r(phase);
                x = r * cos(mu);
                y = r * sin(mu);
                subplot(2,3,6)
                max_lim = 0.15;
                x_fake=[0 max_lim 0 -max_lim];
                y_fake=[max_lim 0 -max_lim 0];
                h_fake=compass(x_fake,y_fake);
                hold on;
                h=compass(x,y);
                set(h_fake,'Visible','off');
                h.LineWidth = 4;
                title('Mean Circular Vector', 'FontSize', 16)
            end