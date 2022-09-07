function [x_new,y_new] = sort_boundary_points(x_old, y_old)


P = [x_old(:)'; y_old(:)']; % coordinates / points
c = mean(P,2); % mean/ central point
d = P-c ; % vectors connecting the central point and the given points
th = atan2(d(2,:),d(1,:)); % angle above x axis
[~, idx] = sort(th);   % sorting the angles
P = P(:,idx); % sorting the given points
P = [P P(:,1)]; % add the first at the end to close the polygon

x_new = P(1,:);
y_new = P(2,:);
end