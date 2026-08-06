function add_stages(ax,sb,sn,sc,ylim_hint,fs_stage)
hold(ax,'on');
yl=ylim(ax);
if nargin>=5 && numel(ylim_hint)==2
    yl=ylim_hint;
end
for s=1:4
    patch(ax,[sb(s) sb(s+1) sb(s+1) sb(s)],[yl(1) yl(1) yl(2) yl(2)],sc{s}, ...
        'FaceAlpha',0.18,'EdgeColor','none','HandleVisibility','off');
    text(ax,0.5*(sb(s)+sb(s+1)),yl(2)-0.03*(yl(2)-yl(1)),sn{s}, ...
        'HorizontalAlignment','center','VerticalAlignment','top', ...
        'FontSize',fs_stage,'FontWeight','bold','Color',[0.25 0.25 0.25], ...
        'HandleVisibility','off');
end
if nargin>=5 && numel(ylim_hint)==2
    ylim(ax,ylim_hint);
end
end