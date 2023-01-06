%%
artifacts = detect_artifacts(data,Fs);
crits = linspace(4,6,50);
all_match = zeros(size(crits));
art_match = zeros(size(crits));
mse = zeros(size(crits));
parfor ii = 1:length(crits)
    crit = crits(ii);
    artifacts2 = detect_artifacts2(data,Fs, [], crit, [], crit);
    all_match(ii) = mean(artifacts & artifacts2 | ~artifacts & ~artifacts2)
    art_match(ii) = mean(artifacts & artifacts2)
    mse(ii) = mean((artifacts2-artifacts).^2);
end

close all
subplot(311)
plot(crits, all_match)
title('all')
subplot(312)
plot(crits, art_match)
title('arts')
subplot(313)
plot(crits, mse)
title('mse')

