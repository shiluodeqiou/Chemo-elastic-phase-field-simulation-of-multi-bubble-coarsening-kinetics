function savefieldsnapshot_CH(eta,cv,cg,base_path,num_seeds,T,time_t,step_num,rhoFe,gasfrac,cvb,cvm,cgb,cgm,FS_AX,FS_LAB,FS_TIT)
eta_file  = [base_path '_eta.png'];
comp_file = [base_path '_composition.png'];

f1 = figure('Visible','off','Position',[50,50,1000,850]);
ax1 = axes('Parent',f1,'Position',[0.11 0.11 0.72 0.75]);
eta_lo   = prctile(eta(:),5);
eta_hi   = prctile(eta(:),99);
eta_plot = (eta - eta_lo) / max(eta_hi - eta_lo, eps);
eta_plot = max(min(eta_plot,1),0);
imagesc(ax1, eta_plot);
set(ax1,'DataAspectRatio',[1 1 1],'PlotBoxAspectRatio',[1 1 1],'YDir','normal');
colormap(ax1,'jet');
caxis(ax1,[0 1]);
cb1 = colorbar(ax1);
cb1.FontSize   = FS_AX - 4;
cb1.FontWeight = 'bold';
set(ax1,'FontSize',FS_AX,'FontWeight','bold','LineWidth',1.5);
box(ax1,'on');
xlabel(ax1,'X lattice units','FontSize',FS_LAB,'FontWeight','bold');
ylabel(ax1,'Y lattice units','FontSize',FS_LAB,'FontWeight','bold');
title(ax1,sprintf('\\eta | Fe | T=%d K | t=%.2f',T,time_t),'FontSize',FS_TIT,'FontWeight','bold');
print(f1,eta_file,'-dpng','-r300');
savefig(f1,[base_path '_eta.fig']);
close(f1);

f2 = figure('Visible','off','Position',[50,50,1800,950]);
ax2 = subplot(2,2,1,'Parent',f2); imagesc(ax2,cv); set(ax2,'DataAspectRatio',[1 1 1],'PlotBoxAspectRatio',[1 1 1],'YDir','normal'); box(ax2,'on'); colorbar(ax2); title(ax2,'Vacancy map, c_v');
ax3 = subplot(2,2,2,'Parent',f2); imagesc(ax3,cg); set(ax3,'DataAspectRatio',[1 1 1],'PlotBoxAspectRatio',[1 1 1],'YDir','normal'); box(ax3,'on'); colorbar(ax3); title(ax3,'Gas map, c_g');
mid = round(size(eta,1)/2); x = 1:size(eta,2);
ax4 = subplot(2,2,3,'Parent',f2); plot(ax4,x,cv(mid,:),'b-','LineWidth',2.0); hold(ax4,'on'); yline(ax4,cvb,'--r','Bubble avg'); yline(ax4,cvm,'--k','Matrix avg'); grid(ax4,'on'); box(ax4,'on'); title(ax4,'c_v profile');
ax5 = subplot(2,2,4,'Parent',f2); plot(ax5,x,cg(mid,:),'m-','LineWidth',2.0); hold(ax5,'on'); yline(ax5,cgb,'--r','Bubble avg'); yline(ax5,cgm,'--k','Matrix avg'); grid(ax5,'on'); box(ax5,'on'); title(ax5,'c_g profile');
sgtitle(f2,sprintf('Composition | T=%d K | t=%.2f | step=%d',T,time_t,step_num),'FontSize',FS_TIT,'FontWeight','bold');
print(f2,comp_file,'-dpng','-r300');
savefig(f2,[base_path '_composition.fig']);
close(f2);
end