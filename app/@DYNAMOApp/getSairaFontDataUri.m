function uri = getSairaFontDataUri(~)
%GETSAIRAFONTDATAURI  Return Saira-Regular WOFF2 as a base64 data URI.
%
%   Caches the file under prefdir()/dynamo_cache so the first launch
%   pulls it from the Google Fonts CDN once and every subsequent
%   launch reads it from disk — no network request, splash and About
%   render with the brand font even when the box is offline after
%   first use. Returns '' when both the cache miss and the network
%   fetch fail (caller should fall back to a system font stack).
%
%   The on-disk filename includes the Google Fonts version tag
%   (currently v23) so a refreshed gstatic URL gets a fresh cache
%   entry instead of stale-mixing with the old one.

    uri = '';
    cacheDir  = fullfile(prefdir(), 'dynamo_cache');
    cachePath = fullfile(cacheDir, 'saira-v23.woff2');
    cdnUrl    = 'https://fonts.gstatic.com/s/saira/v23/memjYa2wxmKQyPMrZX79wwYZQMhsyuSLiIvS.woff2';

    if ~isfolder(cacheDir)
        try, mkdir(cacheDir); catch, end
    end

    if ~isfile(cachePath)
        try
            opts = weboptions('Timeout', 5, 'ContentType', 'binary');
            data = webread(cdnUrl, opts);
            fid  = fopen(cachePath, 'w');
            if fid < 0; return; end
            fwrite(fid, data, 'uint8');
            fclose(fid);
        catch
            return
        end
    end

    try
        fid = fopen(cachePath, 'r');
        if fid < 0; return; end
        cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
        bytes = fread(fid, inf, '*uint8');
        if isempty(bytes); return; end
        b64 = matlab.net.base64encode(bytes);
        uri = ['data:font/woff2;base64,' char(b64)];
    catch
        uri = '';
    end
end
