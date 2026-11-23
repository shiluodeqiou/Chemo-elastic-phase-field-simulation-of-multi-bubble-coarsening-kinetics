function make_fig_sensitivity()
%MAKE_FIG_SENSITIVITY  Quantify how the unpublished initial composition
%   controls the residual gap to the published 800 K / stress-free series.
%
%   Compares phi0 = 0.50 (calibrated to the published t = 0 metrics) with
%   phi0 = 0.45 (best fit of the late-stage metrics) against Fig. 2a/3a.

root = fileparts(fileparts(which('repro_params')));
addpath(root); addpath(fullfile(root,'repro'));
rdir = fullfile(root,'repro','results');
refd = fullfile(root,'repro','reference');
figd = fullfile(root,'repro','figures');
if ~isfolder(figd), mkdir(figd); end

A = load(fullfile(rdir,'case_T800_S+0.0GPa.mat'));   A = A.R;   % phi0 = 0.50
B = load(fullfile(rdir,'case_sens_T800_S+0.0GPa.mat')); B = B.R; % phi0 = 0.45
refN = readmatrix(fullfile(refd,'N_vs_t_noStress.csv'));
refR = readmatrix(fullfile(refd,'r_vs_t_noStress.csv'));

c50 = [0.12 0.40 0.75];
c45 = [0.93 0.52 0.10];

f = figure('Color','w','Position',[70 70 1420 560]);
tl = tiledlayout(f,1,2,'Padding','compact','TileSpacing','compact');

ax1 = nexttile(tl); hold(ax1,'on'); box(ax1,'on'); grid(ax1,'on');
plot(ax1,refN(:,1),refN(:,2),'o','Color',[0.35 0.35 0.35],'MarkerSize',4, ...
    'MarkerFaceColor','none','DisplayName','paper (Fig. 2a)');
plot(ax1,A.t,A.N,'-','Color',c50,'LineWidth',2.6,'DisplayName','\phi_0 = 0.50 (t_0-calibrated)');
plot(ax1,B.t,B.N,'-','Color',c45,'LineWidth',2.6,'DisplayName','\phi_0 = 0.45');

ax2 = nexttile(tl); hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
plot(ax2,refR(:,1),refR(:,2),'o','Color',[0.35 0.35 0.35],'MarkerSize',4, ...
    'MarkerFaceColor','none','DisplayName','paper (Fig. 3a)');
plot(ax2,A.t,A.reff,'-','Color',c50,'LineWidth',2.6,'DisplayName','\phi_0 = 0.50');
plot(ax2,B.t,B.reff,'-','Color',c45,'LineWidth',2.6,'DisplayName','\phi_0 = 0.45');

for ax = [ax1 ax2]
    set(ax,'FontSize',13,'FontWeight','bold','LineWidth',1.6,'Box','on');
    ax.XGrid='on'; ax.YGrid='on'; ax.GridAlpha=0.18;
    xlabel(ax,'time t');
end
ylabel(ax1,'number of bubbles N'); ylabel(ax2,'r_{eff}');
title(ax1,'(a) bubble count, T = 800 K, residual-free');
title(ax2,'(b) effective radius, T = 800 K, residual-free');
legend(ax1,'Location','northeast'); legend(ax2,'Location','southeast');
sgtitle(tl,'Sensitivity to the undocumented initial composition','FontWeight','bold');
exportgraphics(f,fullfile(figd,'Fig14_phi0_sensitivity.png'),'Resolution',200);
close(f);

fprintf('\n%-22s %8s %8s %8s %8s\n','case','N_f','r_eff,f','K_late','n');
fprintf('%-22s %8d %8.3f %8.3f %8.3f\n','phi0 = 0.50 (run)',A.N(end),A.reff(end),A.K_late,A.n_stage3);
fprintf('%-22s %8d %8.3f %8.3f %8.3f\n','phi0 = 0.45 (run)',B.N(end),B.reff(end),B.K_late,B.n_stage3);
fprintf('%-22s %8d %8.3f %8.3f %8s\n','paper',110,18.17539,exp(1.09115),'1/3');
fprintf('\ninitial state  phi0=0.50: r_eff0=%.4f  P/A=%.4f | phi0=0.45: r_eff0=%.4f  P/A=%.4f | paper 5.9494 / 0.33617\n', ...
    A.reff0, A.PA0, B.reff0, B.PA0);
end
