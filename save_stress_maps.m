function save_stress_maps(eta,sigxx,sigyy,sigxy,base_path,T,mode_name,step_num,time_t)
%SAVE_STRESS_MAPS Save the phase field and stress components for a snapshot.
%   This helper only writes diagnostic images and does not alter the solver
%   state. The numerical evolution is controlled by Code.m and the elastic
%   chemical-potential helper.

base_path = char(base_path);
mode_name = char(mode_name);

folder = fileparts(base_path);
if ~isempty(folder) && ~isfolder(folder)
    mkdir(folder);
end

f = figure('Visible','off','Color','w','Position',[50 50 1600 900]);
tiledlayout(f,2,3,'TileSpacing','compact','Padding','compact');

nexttile;
imagesc(eta);
axis image; set(gca,'YDir','normal'); colorbar;
title('\eta');

nexttile;
imagesc(sigxx);
axis image; set(gca,'YDir','normal'); colorbar;
title('\sigma_{xx}');

nexttile;
imagesc(sigyy);
axis image; set(gca,'YDir','normal'); colorbar;
title('\sigma_{yy}');

nexttile;
imagesc(sigxy);
axis image; set(gca,'YDir','normal'); colorbar;
title('\sigma_{xy}');

nexttile;
imagesc(sqrt(sigxx.^2 + sigyy.^2 + 2*sigxy.^2));
axis image; set(gca,'YDir','normal'); colorbar;
title('von Mises-like stress magnitude');

nexttile;
axis off;
text(0,0.80,sprintf('T = %g K',T),'Units','normalized');
text(0,0.60,sprintf('mode = %s',mode_name),'Units','normalized','Interpreter','none');
text(0,0.40,sprintf('step = %g',step_num),'Units','normalized');
text(0,0.20,sprintf('time = %.6g',time_t),'Units','normalized');

sgtitle(sprintf('Stress diagnostics | %s',mode_name),'Interpreter','none');
saveas(f,[base_path '_stress.png']);
savefig(f,[base_path '_stress.fig']);
close(f);
end
