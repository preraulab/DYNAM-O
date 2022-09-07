function [data_bsspect,bl]= baseline_subtract_spectrogram(data_sspect,data_sstimes,bl_prc,bl_sm_win)

    data_sspect(data_sspect==0) = NaN;
    bl = prctile(data_sspect,bl_prc,2); % prctile(sspect,bl_prc,1)'; %
    %     bl=bl_02';
    data_sspect(isnan(data_sspect)) = 0;
    
    %****
    %* Option to smooth baseline using a windowed average
    %****
    if(bl_sm_win > 1)
        bl_old = bl;
        sm_hwin = floor(bl_sm_win/2);
        for ii = 1:length(bl)
            if (ii-sm_hwin) < 1
                bl(ii) = sum(bl_old(1:(ii+sm_hwin)))/(ii+sm_hwin);
            elseif (ii+sm_hwin) > length(bl)
                bl(ii) = sum(bl_old((ii-sm_hwin):end))/(length(bl)-(ii-sm_hwin));
            else
                bl(ii) = sum(bl_old((ii-sm_hwin):(ii+sm_hwin)))/bl_sm_win;
            end
        end
    end
    data_bsspect = data_sspect./repmat(bl,1,length(data_sstimes));
end