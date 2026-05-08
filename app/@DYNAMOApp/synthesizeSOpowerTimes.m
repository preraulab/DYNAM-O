function t = synthesizeSOpowerTimes(~, N, Fs, retain_Fs, window_params)
    % synthesizeSOpowerTimes  Reconstruct the time grid for a SOpower
    %   trace of length N without storing it explicitly.
    %
    %   Two regimes:
    %     - retain_Fs = true  (default): SOpower_norm was upsampled to
    %       data Fs in computeSOpower, so the grid is (0:N-1)/Fs.
    %     - retain_Fs = false: SOpower_norm lives on the spectrogram
    %       step grid. The first window's center is window_size/2,
    %       subsequent samples step by window_step. window_params is
    %       [window_size, window_step] in seconds.
    %
    %   Method form takes an unused first arg (the app) so the helper
    %   can be invoked as app.synthesizeSOpowerTimes(...). The output
    %   is in seconds — convert to hours / minutes at the call site.
    if nargin < 4 || isempty(retain_Fs), retain_Fs = true; end
    if nargin < 5,                       window_params = [5, 0.5]; end

    if N <= 0 || ~isfinite(Fs) || Fs <= 0
        t = [];
        return
    end

    if retain_Fs
        t = (0:N-1) / double(Fs);
    else
        ws = double(window_params(1));   % window_size  (s)
        wp = double(window_params(2));   % window_step  (s)
        t  = ws/2 + (0:N-1) * wp;
    end
end
