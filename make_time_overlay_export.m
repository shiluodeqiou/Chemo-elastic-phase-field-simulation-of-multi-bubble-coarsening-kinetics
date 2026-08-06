function make_time_overlay_export(folder,base_name,title_txt,row_cells,fieldname,xlab,ylab,regime)
f=figure('Visible','off','Position',[100,100,1500,900]);
ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,16,1.8);
series=initseries(); cmap=lines(numel(row_cells));
for m=1:numel(row_cells)
    r=row_cells{m}; x=r.times; y=r.(fieldname);
    plot(ax,x,y,'LineWidth',2.8,'Color',cmap(m,:),'DisplayName',r.mode_name);
    series(m)=mkseries(r.mode_name,x,y,'line');
end
xlabel(ax,xlab); ylabel(ax,ylab); title(ax,title_txt); legend(ax,'Location','best'); grid(ax,'on');
save_plot_both(f,folder,base_name);
export_plot_csv_xlsx(folder,base_name,title_txt,xlab,ylab,regime,series);
end