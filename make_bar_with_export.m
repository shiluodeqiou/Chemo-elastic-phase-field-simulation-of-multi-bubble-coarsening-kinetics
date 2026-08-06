function make_bar_with_export(folder,base_name,title_txt,labels,y,xlab,ylab,regime)
f=figure('Visible','off','Position',[100,100,1400,800]);
ax=axes(f); box(ax,'on'); hold(ax,'on'); fmtax(ax,16,1.8);
b=bar(ax,y); b.FaceColor='flat'; cmap=lines(numel(y));
for i=1:numel(y), b.CData(i,:)=cmap(i,:); end
set(ax,'XTick',1:numel(y),'XTickLabel',labels); xtickangle(ax,25);
xlabel(ax,xlab); ylabel(ax,ylab); title(ax,title_txt); grid(ax,'on');
save_plot_both(f,folder,base_name);
export_plot_csv_xlsx(folder,base_name,title_txt,'mode_idx',ylab,regime,mkseries('all_modes',1:numel(y),y,'bar'));
end