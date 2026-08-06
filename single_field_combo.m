function single_field_combo(results_s,out_mode,base_name,title_txt,yfun,xlab,ylab,regime,FS_AX,LW_AX,LW_CRV)
f=figure('Visible','off','Position',[100,100,1400,850]);
ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX);
series=initseries();
for i=1:numel(results_s)
    x=results_s{i}.times; y=yfun(results_s{i});
    plot(ax,x,y,'Color',results_s{i}.color,'LineWidth',LW_CRV,'DisplayName',sprintf('T=%d K',results_s{i}.T));
    series(end+1)=mkseries(sprintf('T=%d K',results_s{i}.T),x,y,'line');
end
xlabel(ax,xlab); ylabel(ax,ylab); title(ax,title_txt); legend(ax,'Location','best'); grid(ax,'on');
save_plot_both(f,out_mode,base_name);
export_plot_csv_xlsx(out_mode,base_name,title_txt,xlab,ylab,regime,series);
end