function make_figures(which_figs)
%MAKE_FIGURES  Regenerate the article's figures from the reproduction output.
%
%   make_figures()            % all figures that the available data supports
%   make_figures({'02','03'}) % a subset
%
%   Figures are written to repro/figures/*.png (200 dpi) and the underlying
%   numbers to repro/figures/data/*.csv.

if nargin<1, which_figs = {'all'}; end
root = fileparts(fileparts(which('repro_params')));
addpath(root); addpath(fullfile(root,'repro'));
P = repro_params();
rdir = fullfile(root,'repro','results');
refd = fullfile(root,'repro','reference');
figd = fullfile(root,'repro','figures');
datd = fullfile(root,'repro','figures','data');
if ~isfolder(figd), mkdir(figd); end
if ~isfolder(datd), mkdir(datd); end

T_all = P.T_values; S_all = P.S_levels_GPa;
COL = [0.12 0.40 0.75; 0.93 0.52 0.10; 0.72 0.15 0.20];
SNAME = {'compressive (-2 GPa)','residual-free (0 GPa)','tensile (+2 GPa)'};
SLAB  = {'-2','0','+2'};

%% ---------- load cases ----------
C = repmat(struct('R',[]),numel(S_all),numel(T_all));
have = false(numel(S_all),numel(T_all));
for is = 1:numel(S_all)
    for it = 1:numel(T_all)
        f = fullfile(rdir,sprintf('case_T%d_S%+.1fGPa.mat',T_all(it),S_all(is)));
        if ~isfile(f), continue; end
        L = load(f); C(is,it).R = L.R; have(is,it) = true;
    end
end
if ~any(have(:)), error('no campaign results found in %s', rdir); end
fprintf('cases available:\n'); disp(have);

want = @(id) any(strcmp(which_figs,'all')) || any(strcmp(which_figs,id));

%% ================= FIG 01 : microstructure panels, residual-free ========
if want('01')
    is = 2;                                          % sigma = 0
    if all(have(is,:))
        fig_panels(C,is,fullfile(figd,'Fig01_microstructure_noStress.png'));
    end
end

%% ================= FIG 02 : N(t) and interface compactness ==============
if want('02')
    is = 2;
    if all(have(is,:))
        f = figure('Color','w','Position',[80 80 1450 560]);
        tl = tiledlayout(f,1,2,'Padding','compact','TileSpacing','compact');
        ax1 = nexttile(tl); hold(ax1,'on'); box(ax1,'on'); grid(ax1,'on');
        ax2 = nexttile(tl); hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
        refN = readmatrix(fullfile(refd,'N_vs_t_noStress.csv'));
        for it = 1:numel(T_all)
            R = C(is,it).R;
            plot(ax1,R.t,R.N,'-','Color',COL(it,:),'LineWidth',2.6, ...
                'DisplayName',sprintf('T = %d K',T_all(it)));
            plot(ax2,R.t,R.PA,'-','Color',COL(it,:),'LineWidth',2.6, ...
                'DisplayName',sprintf('T = %d K',T_all(it)));
            % paper
            cc = 2*it-1;
            ok = isfinite(refN(:,cc)) & isfinite(refN(:,cc+1));
            plot(ax1,refN(ok,cc),refN(ok,cc+1),'o','Color',COL(it,:), ...
                'MarkerSize',3.4,'MarkerFaceColor','none','HandleVisibility','off');
        end
        style_ax(ax1); style_ax(ax2);
        xlabel(ax1,'time t'); ylabel(ax1,'number of bubbles N');
        title(ax1,'(a) bubble count'); legend(ax1,'Location','northeast');
        xlabel(ax2,'time t'); ylabel(ax2,'P_{tot} / A_{tot}');
        title(ax2,'(b) interface compactness'); legend(ax2,'Location','northeast');
        sgtitle(tl,'Reproduction of Fig. 2  (residual-free, \phi_0 = 0.50)','FontWeight','bold');
        export_one(f,fullfile(figd,'Fig02_N_and_compactness.png'), ...
            fullfile(datd,'Fig02_N_and_compactness.csv'), ...
            C(is,:),{'N','PA'},T_all);
    end
end

%% ================= FIG 03 : r(t), final N, rate, efficiency =============
if want('03')
    is = 2;
    if all(have(is,:))
        f = figure('Color','w','Position',[60 60 1450 1000]);
        tl = tiledlayout(f,2,2,'Padding','compact','TileSpacing','compact');
        ax1 = nexttile(tl); hold(ax1,'on'); box(ax1,'on'); grid(ax1,'on');
        ax2 = nexttile(tl); hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
        ax3 = nexttile(tl); hold(ax3,'on'); box(ax3,'on'); grid(ax3,'on');
        ax4 = nexttile(tl); hold(ax4,'on'); box(ax4,'on'); grid(ax4,'on');
        refR = readmatrix(fullfile(refd,'r_vs_t_noStress.csv'));
        pN   = readmatrix(fullfile(refd,'finalN_vs_T_noStress.csv'));
        prate= readmatrix(fullfile(refd,'rate_vs_T_noStress.csv'));
        peff = readmatrix(fullfile(refd,'coalescenceEff_vs_T.csv'));
        Nf = nan(1,numel(T_all)); rate = Nf; eff = Nf;
        for it = 1:numel(T_all)
            R = C(is,it).R;
            plot(ax1,R.t,R.reff,'-','Color',COL(it,:),'LineWidth',2.6, ...
                'DisplayName',sprintf('T = %d K',T_all(it)));
            cc = 2*it-1; ok = isfinite(refR(:,cc)) & isfinite(refR(:,cc+1));
            plot(ax1,refR(ok,cc),refR(ok,cc+1),'o','Color',COL(it,:), ...
                'MarkerSize',3.2,'MarkerFaceColor','none','HandleVisibility','off');
            Nf(it)   = R.N(end);
            rate(it) = max(R.N(1)-R.N(end),0)/max(R.t(end)-R.t(1),eps);
            eff(it)  = 100*max(R.N(1)-R.N(end),0)/max(R.N(1),1);
        end
        style_ax(ax1); xlabel(ax1,'time t'); ylabel(ax1,'r_{eff}');
        title(ax1,'(a) effective radius'); legend(ax1,'Location','northwest');
        plot(ax2,pN(:,1),pN(:,2),'s--','Color',[0.45 0.45 0.45],'LineWidth',1.6, ...
            'MarkerFaceColor','none','DisplayName','paper');
        plot(ax2,T_all,Nf,'o-','Color',COL(3,:),'LineWidth',2.6,'MarkerFaceColor',COL(3,:), ...
            'MarkerSize',9,'DisplayName','this work');
        style_ax(ax2); xlabel(ax2,'T (K)'); ylabel(ax2,'N_{final}');
        title(ax2,'(b) final bubble count'); legend(ax2,'Location','northeast');
        plot(ax3,prate(:,1),prate(:,2),'s--','Color',[0.45 0.45 0.45],'LineWidth',1.6, ...
            'MarkerFaceColor','none','DisplayName','paper');
        plot(ax3,T_all,rate,'o-','Color',COL(1,:),'LineWidth',2.6,'MarkerFaceColor',COL(1,:), ...
            'MarkerSize',9,'DisplayName','this work');
        style_ax(ax3); xlabel(ax3,'T (K)'); ylabel(ax3,'coarsening rate (N/t)');
        title(ax3,'(c) average coarsening rate'); legend(ax3,'Location','northwest');
        b = bar(ax4,T_all,eff,0.55,'FaceColor','flat');
        for it=1:numel(T_all), b.CData(it,:)=COL(it,:); end
        hold(ax4,'on'); plot(ax4,peff(:,1),peff(:,2),'ks--','LineWidth',1.6, ...
            'MarkerFaceColor','none','DisplayName','paper');
        style_ax(ax4); xlabel(ax4,'T (K)'); ylabel(ax4,'coalescence efficiency (%)');
        title(ax4,'(d) coalescence efficiency'); ylim(ax4,[0 100]); legend(ax4,'Location','northeast');
        sgtitle(tl,'Reproduction of Fig. 3  (residual-free, \phi_0 = 0.50)','FontWeight','bold');
        savefig_png(f,fullfile(figd,'Fig03_radius_finalN_rate_efficiency.png'));
    end
end

%% ================= FIG 04 : ripening kinetics ==========================
if want('04')
    is = 2;
    if all(have(is,:))
        f = figure('Color','w','Position',[60 60 1450 1000]);
        tl = tiledlayout(f,2,2,'Padding','compact','TileSpacing','compact');
        ax1 = nexttile(tl); hold(ax1,'on'); box(ax1,'on'); grid(ax1,'on');
        ax2 = nexttile(tl); hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
        ax3 = nexttile(tl); hold(ax3,'on'); box(ax3,'on'); grid(ax3,'on');
        ax4 = nexttile(tl); hold(ax4,'on'); box(ax4,'on'); grid(ax4,'on');
        ref4a = readmatrix(fullfile(refd,'r3_vs_t_stage3.csv'));
        ref4d = readmatrix(fullfile(refd,'N_vs_rinv2_final.csv'));
        lk = nan(1,numel(T_all)); invT = 1./T_all;
        for it = 1:numel(T_all)
            R = C(is,it).R;
            R3 = max(R.reff.^3 - R.reff(1)^3,0);
            plot(ax1,R.t,R3,'-','Color',COL(it,:),'LineWidth',2.6, ...
                'DisplayName',sprintf('T = %d K',T_all(it)));
            cc = 2*it-1; ok = isfinite(ref4a(:,cc)) & isfinite(ref4a(:,cc+1));
            plot(ax1,ref4a(ok,cc),ref4a(ok,cc+1),'o','Color',COL(it,:), ...
                'MarkerSize',3.2,'MarkerFaceColor','none','HandleVisibility','off');
            % stage-3 fit window, slope = K_late
            mask = (R.t>=0.35*max(R.t))&(R.t<=0.90*max(R.t))&(R3>0);
            if nnz(mask)>=3
                pf = polyfit(R.t(mask),R3(mask),1); xf = linspace(min(R.t(mask)),max(R.t(mask)),50);
                plot(ax1,xf,polyval(pf,xf),'--','Color',COL(it,:),'LineWidth',2.0, ...
                    'HandleVisibility','off');
            end
            m3 = (R.t>=P.stage_bounds(3))&(R.t<=P.stage_bounds(4))&(R.reff>0);
            loglog(ax2,R.t(m3),R.reff(m3),'o','Color',COL(it,:),'MarkerSize',4, ...
                'HandleVisibility','off');
            if nnz(m3)>=3
                pl = polyfit(log(R.t(m3)),log(R.reff(m3)),1);
                xf = logspace(log10(min(R.t(m3))),log10(max(R.t(m3))),60);
                loglog(ax2,xf,exp(pl(2))*xf.^pl(1),'-','Color',COL(it,:),'LineWidth',2.4, ...
                    'DisplayName',sprintf('T = %d K, n = %.3f',T_all(it),pl(1)));
            end
            lk(it) = log(max(R.K_late,eps));
            % N vs 1/r^2  (final state)
            plot(ax4,1./R.reff(end).^2,R.N(end),'o','Color',COL(it,:), ...
                'MarkerSize',11,'MarkerFaceColor',COL(it,:),'DisplayName',sprintf('%d K',T_all(it)));
        end
        style_ax(ax1); xlabel(ax1,'time t'); ylabel(ax1,'\Delta r_{eff}^3');
        title(ax1,'(a) r^3 growth with late-stage fit'); legend(ax1,'Location','northwest');
        style_ax(ax2); xlabel(ax2,'time t'); ylabel(ax2,'r_{eff}');
        title(ax2,'(b) stage-3 power law'); legend(ax2,'Location','southeast');
        ok = isfinite(lk);
        plot(ax3,invT(ok),lk(ok),'o','Color',[0.15 0.15 0.15],'MarkerSize',11, ...
            'MarkerFaceColor',[0.15 0.15 0.15],'DisplayName','this work');
        if nnz(ok)>=2
            pp = polyfit(invT(ok),lk(ok),1); xf = linspace(min(invT(ok)),max(invT(ok)),50);
            plot(ax3,xf,polyval(pp,xf),'-','Color',[0.72 0.15 0.20],'LineWidth',2.4, ...
                'DisplayName',sprintf('slope = %.4g K',pp(1)));
        end
        ref4c = readmatrix(fullfile(refd,'arrhenius_noStress.csv'));
        plot(ax3,ref4c(:,1),ref4c(:,2),'s--','Color',[0.45 0.45 0.45],'LineWidth',1.6, ...
            'MarkerFaceColor','none','DisplayName','paper');
        style_ax(ax3); xlabel(ax3,'1/T (K^{-1})'); ylabel(ax3,'ln K_{late}');
        title(ax3,'(c) Arrhenius plot'); legend(ax3,'Location','northwest');
        for it=1:numel(T_all)
            R = C(is,it).R; m3 = R.t>=P.stage_bounds(3);
            plot(ax4,1./R.reff(m3).^2,R.N(m3),'.','Color',COL(it,:),'MarkerSize',7, ...
                'HandleVisibility','off');
        end
        style_ax(ax4); xlabel(ax4,'1/r_{eff}^2'); ylabel(ax4,'N');
        title(ax4,'(d) LSW consistency'); legend(ax4,'Location','northeast');
        sgtitle(tl,'Reproduction of Fig. 4  (residual-free, \phi_0 = 0.50)','FontWeight','bold');
        savefig_png(f,fullfile(figd,'Fig04_ripening_kinetics.png'));
    end
end

%% ================= FIG 05 : vacancy / gas compositions =================
if want('05')
    is = 2;
    if all(have(is,:))
        f = figure('Color','w','Position',[60 60 1450 1000]);
        tl = tiledlayout(f,2,2,'Padding','compact','TileSpacing','compact');
        fld = {'cv_bubble','cv_matrix','cg_bubble','cg_matrix'};
        ttl = {'(a) vacancy in bubbles','(b) vacancy in matrix','(c) gas in bubbles','(d) gas in matrix'};
        ylb = {'c_v (bubble)','c_v (matrix)','c_g (bubble)','c_g (matrix)'};
        for q=1:4
            ax = nexttile(tl); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
            for it=1:numel(T_all)
                R = C(is,it).R;
                plot(ax,R.t,R.(fld{q}),'-','Color',COL(it,:),'LineWidth',2.4, ...
                    'DisplayName',sprintf('T = %d K',T_all(it)));
            end
            style_ax(ax); xlabel(ax,'time t'); ylabel(ax,ylb{q}); title(ax,ttl{q});
            if q==1, legend(ax,'Location','best'); end
        end
        sgtitle(tl,'Reproduction of Fig. 5  (residual-free, \phi_0 = 0.50)','FontWeight','bold');
        savefig_png(f,fullfile(figd,'Fig05_vacancy_gas.png'));
    end
end

%% ================= FIG 09 : stress-dependent mobility ==================
if want('09')
    f = figure('Color','w','Position',[80 80 1200 470]);
    tl = tiledlayout(f,1,2,'Padding','compact','TileSpacing','compact');
    ax1=nexttile(tl); hold(ax1,'on'); box(ax1,'on'); grid(ax1,'on');
    ax2=nexttile(tl); hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
    ref9a = readmatrix(fullfile(refd,'stress_factor_vs_T.csv'));
    ref9b = readmatrix(fullfile(refd,'Msigma_vs_T.csv'));
    sf_c=nan(1,numel(T_all)); sf_t=sf_c;
    for it=1:numel(T_all)
        T=T_all(it);
        pc = -(-2.0)*1e9;  sf_c(it)=exp(-(pc*P.V_act_m3)/(P.kB_J*T));
        pt = -(+2.0)*1e9;  sf_t(it)=exp(-(pt*P.V_act_m3)/(P.kB_J*T));
    end
    plot(ax1,ref9a(:,1),ref9a(:,2),'s','Color',[0.45 0.45 0.45],'MarkerSize',10, ...
        'MarkerFaceColor','none','DisplayName','paper');
    plot(ax1,T_all,sf_c,'o-','Color',COL(1,:),'LineWidth',2.4,'MarkerFaceColor',COL(1,:), ...
        'MarkerSize',9,'DisplayName','analytic, -2 GPa');
    style_ax(ax1); xlabel(ax1,'T (K)'); ylabel(ax1,'mobility factor');
    title(ax1,'(a) compressive'); legend(ax1,'Location','southeast');
    plot(ax2,ref9b(:,1),ref9b(:,2),'s','Color',[0.45 0.45 0.45],'MarkerSize',10, ...
        'MarkerFaceColor','none','DisplayName','paper');
    plot(ax2,T_all,sf_t,'o-','Color',COL(3,:),'LineWidth',2.4,'MarkerFaceColor',COL(3,:), ...
        'MarkerSize',9,'DisplayName','analytic, +2 GPa');
    style_ax(ax2); xlabel(ax2,'T (K)'); ylabel(ax2,'mobility factor');
    title(ax2,'(b) tensile'); legend(ax2,'Location','southeast');
    sgtitle(tl,'Fig. 9 reproduction: exp[-P V_{act}/(k_B T)] mobility factor','FontWeight','bold');
    savefig_png(f,fullfile(figd,'Fig09_stress_mobility.png'));
    fprintf('  stress factor  -2 GPa: %.5f %.5f %.5f  (paper %.5f %.5f %.5f)\n', ...
        sf_c, ref9a(:,2)');
    fprintf('  stress factor  +2 GPa: %.5f %.5f %.5f  (paper %.5f %.5f %.5f)\n', ...
        sf_t, ref9b(:,2)');
end

%% ================= FIG 11 : Table-1 summary across stress ==============
if want('11')
    if all(have(:))
        f = figure('Color','w','Position',[60 60 1500 500]);
        tl = tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');
        ax1=nexttile(tl); hold(ax1,'on'); box(ax1,'on'); grid(ax1,'on');
        ax2=nexttile(tl); hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
        ax3=nexttile(tl); hold(ax3,'on'); box(ax3,'on'); grid(ax3,'on');
        pN   = readmatrix(fullfile(refd,'table1_finalN.csv'));
        pRe  = readmatrix(fullfile(refd,'table1_finalReff.csv'));
        pArr = readmatrix(fullfile(refd,'table1_arrhenius.csv'));
        for is=1:3
            Nf=nan(1,3); Rf=Nf; LK=Nf;
            for it=1:3
                R = C(is,it).R;
                Nf(it)=R.N(end); Rf(it)=R.reff(end); LK(it)=log(max(R.K_late,eps));
            end
            plot(ax1,pN(:,2*is-1),pN(:,2*is),'s--','Color',COL(is,:)*0.55+0.35, ...
                'LineWidth',1.5,'MarkerFaceColor','none','DisplayName',[SNAME{is} ' paper']);
            plot(ax1,T_all,Nf,'o-','Color',COL(is,:),'LineWidth',2.5,'MarkerSize',9, ...
                'MarkerFaceColor',COL(is,:),'DisplayName',[SNAME{is} ' repro']);
            plot(ax2,pRe(:,2*is-1),pRe(:,2*is),'s--','Color',COL(is,:)*0.55+0.35, ...
                'LineWidth',1.5,'MarkerFaceColor','none','HandleVisibility','off');
            plot(ax2,T_all,Rf,'o-','Color',COL(is,:),'LineWidth',2.5,'MarkerSize',9, ...
                'MarkerFaceColor',COL(is,:),'HandleVisibility','off');
            plot(ax3,pArr(:,2*is-1),pArr(:,2*is),'s--','Color',COL(is,:)*0.55+0.35, ...
                'LineWidth',1.5,'MarkerFaceColor','none','HandleVisibility','off');
            plot(ax3,1./T_all,LK,'o-','Color',COL(is,:),'LineWidth',2.5,'MarkerSize',9, ...
                'MarkerFaceColor',COL(is,:),'HandleVisibility','off');
        end
        style_ax(ax1); xlabel(ax1,'T (K)'); ylabel(ax1,'N_{final}');
        title(ax1,'(a) final bubble count'); legend(ax1,'Location','northeast','FontSize',8);
        style_ax(ax2); xlabel(ax2,'T (K)'); ylabel(ax2,'r_{eff,final}');
        title(ax2,'(b) final effective radius');
        style_ax(ax3); xlabel(ax3,'1/T (K^{-1})'); ylabel(ax3,'ln K_{late}');
        title(ax3,'(c) Arrhenius');
        sgtitle(tl,'Reproduction of Fig. 11 / Table 1 (dashed = paper, solid = this work)','FontWeight','bold');
        savefig_png(f,fullfile(figd,'Fig11_table1_summary.png'));
    end
end

%% ================= FIG 12 : N vs 1/r^2 =================================
if want('12')
    is = 2;
    if all(have(is,:))
        f = figure('Color','w','Position',[80 80 900 560]);
        ax=axes(f); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
        for it=1:3
            R = C(is,it).R; m = R.t>=P.stage_bounds(3);
            plot(ax,1./R.reff(m).^2,R.N(m),'o','Color',COL(it,:),'MarkerSize',5, ...
                'MarkerFaceColor',COL(it,:),'DisplayName',sprintf('T = %d K',T_all(it)));
            x=1./R.reff(m).^2; y=R.N(m);
            if numel(x)>=4, pp=polyfit(x,y,1); xf=linspace(min(x),max(x),40);
                plot(ax,xf,polyval(pp,xf),'-','Color',COL(it,:),'LineWidth',1.8,'HandleVisibility','off');
            end
        end
        style_ax(ax); xlabel(ax,'1/r_{eff}^2'); ylabel(ax,'N');
        title(ax,'Fig. 12 reproduction: LSW consistency (residual-free)','FontWeight','bold');
        legend(ax,'Location','northeast');
        savefig_png(f,fullfile(figd,'Fig12_N_vs_rinv2.png'));
    end
end

%% ================= FIG 13 : stress comparison (N(t), r(t)) ============
if want('13')
    if all(have(:))
        f = figure('Color','w','Position',[50 50 1500 950]);
        tl = tiledlayout(f,3,2,'Padding','compact','TileSpacing','compact');
        for it = 1:numel(T_all)
            ax1 = nexttile(tl); hold(ax1,'on'); box(ax1,'on'); grid(ax1,'on');
            ax2 = nexttile(tl); hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
            for is = 1:numel(S_all)
                R = C(is,it).R;
                plot(ax1,R.t,R.N,'-','Color',COL(is,:),'LineWidth',2.4,'DisplayName',SNAME{is});
                plot(ax2,R.t,R.reff,'-','Color',COL(is,:),'LineWidth',2.4,'DisplayName',SNAME{is});
            end
            style_ax(ax1); style_ax(ax2);
            ylabel(ax1,'N'); ylabel(ax2,'r_{eff}'); xlabel(ax2,'time t');
            title(ax1,sprintf('T = %d K, bubble count',T_all(it)));
            title(ax2,sprintf('T = %d K, effective radius',T_all(it)));
            if it==1, legend(ax1,'Location','northeast'); end
        end
        sgtitle(tl,'Residual-stress effect (reproduction of Figs. 6-8 kinetics)','FontWeight','bold');
        savefig_png(f,fullfile(figd,'Fig13_stress_comparison.png'));
    end
end

fprintf('\nfigures written to %s\n', figd);
end

%% =======================================================================
function fig_panels(C,is,outfile)
T_all = [800 900 1000];
R1 = C(is,1).R;
nt = numel(R1.snap_t);
pick = unique(round(linspace(1,nt,min(6,nt))));
f = figure('Color','w','Position',[40 40 1350 780]);
tl = tiledlayout(f,2,3,'Padding','compact','TileSpacing','compact');
for q=1:numel(pick)
    ax = nexttile(tl);
    L = load(R1.snap_files{pick(q)});
    imagesc(ax,L.eta_c,[0 1]); axis(ax,'image'); axis(ax,'off');
    colormap(ax,phase_cmap());
    tt = R1.snap_t(pick(q));
    Nq = interp1(R1.t,R1.N,tt,'nearest','extrap');
    title(ax,sprintf('t = %.0f    N = %d',tt,round(Nq)),'FontSize',10);
end
sgtitle(tl,sprintf('Reproduction of Fig. 1: microstructure, %s, \\phi_0 = 0.50', ...
    'T = 800 K, residual-free'),'FontWeight','bold');
savefig_png(f,outfile);
end

function cm = phase_cmap()
n = 256; t = linspace(0,1,n)';
c0 = [0.07 0.15 0.38];   % matrix: deep blue
c1 = [0.70 0.83 0.95];   % interface: pale blue
c2 = [0.78 0.16 0.12];   % bubble: brick red
cm = [interp1([0 0.5 1],[c0(1);c1(1);c2(1)],t,'pchip'), ...
      interp1([0 0.5 1],[c0(2);c1(2);c2(2)],t,'pchip'), ...
      interp1([0 0.5 1],[c0(3);c1(3);c2(3)],t,'pchip')];
end

function style_ax(ax)
set(ax,'FontSize',13,'FontWeight','bold','LineWidth',1.6,'Box','on');
ax.XGrid='on'; ax.YGrid='on'; ax.GridAlpha=0.18;
end

function savefig_png(f,outfile)
exportgraphics(f,outfile,'Resolution',200);
close(f);
end

function export_one(f,outfile,csvfile,Crow,fields,T_all)
%EXPORT_ONE  Save a figure plus the plotted series for one stress level.
exportgraphics(f,outfile,'Resolution',200);
close(f);
n = numel(Crow);
tmax = max(arrayfun(@(x) numel(x.R.t), Crow));
D = nan(tmax, 1+2*n);
for k=1:n
    R = Crow(k).R; m = numel(R.t);
    D(1:m,1) = R.t; D(1:m,2*k) = R.(fields{1}); D(1:m,2*k+1) = R.(fields{2});
end
T = array2table(D,'VariableNames',[{ 't' }, arrayfun(@(k) sprintf('N_T%d',T_all(k)),1:n,'uni',0), ...
    arrayfun(@(k) sprintf('PA_T%d',T_all(k)),1:n,'uni',0)]);
writetable(T,csvfile);
end
