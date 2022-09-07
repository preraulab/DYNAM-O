function avg_PIBs = PIB_average_helper(PIBs)
%
%
%

size_PIBmat = size(PIBs{1}{1});     
avg_PIBs = nan(size_PIBmat(1), size_PIBmat(2), length(PIBs));

for ii = 1:length(PIBs)
    
    elect_PIBs = PIBs{ii};

    elect_mat_PIBs = nan(size_PIBmat(1), size_PIBmat(2), length(elect_PIBs));
    for ss = 1:length(elect_PIBs)

        if ~isempty(elect_PIBs{ss})
            elect_mat_PIBs(:,:,ss) = elect_PIBs{ss};
        end
        
    end

    avg_PIBs(:,:,ii) = mean(elect_mat_PIBs, 3, 'omitnan');
end

end