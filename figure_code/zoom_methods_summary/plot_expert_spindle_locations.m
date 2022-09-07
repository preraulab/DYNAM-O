function plot_expert_spindle_locations(ax1,spindle_score1,spindle_score2)
% plot the locations of the expert1 annotated spindles on axis ax1
spindle_start1 = spindle_score1(:,1);
spindle_end1 = spindle_score1(:,1)+spindle_score1(:,2);

% extract the locations of the expert2 annotated spindles
spindle_start2 = spindle_score2(:,1);
spindle_end2 = spindle_score2(:,1)+spindle_score2(:,2);

ylims=get(ax1,'ylim');

for idx = 1 : numel(spindle_start1)
    hold(ax1,'on');
    % plot vertical lines on the region annotated by expert1 as spindles
    plot([spindle_start1(idx) spindle_start1(idx)], [ylims(1) ylims(2)],'k:','Linewidth',2,'HitTest','off');
    hold on;
    plot([spindle_end1(idx) spindle_end1(idx)], [ylims(1) ylims(2)],'k:','Linewidth',2,'HitTest','off');
    hold on;
end

for idx = 1:numel(spindle_start2)
    % plot vertical lines on the region annotated by expert2 as spindles
    plot([spindle_start2(idx) spindle_start2(idx)], [ylims(1) ylims(2)],'m:','Linewidth',2,'HitTest','off');
    hold on;
    plot([spindle_end2(idx) spindle_end2(idx)], [ylims(1) ylims(2)],'m:','Linewidth',2,'HitTest','off');
end
end