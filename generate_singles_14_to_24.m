function generate_singles_14_to_24(results_s,out_mode,cap_suffix,stage_bounds,stage_names,stage_clrs,tmax,R_display_all,FS_AX,FS_LAB,FS_TIT,FS_LEG,FS_STG,LW_AX,LW_CRV,regime)
num_cases_D=numel(results_s);

f=figure('Visible','off','Position',[100,100,1500,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX); series=initseries();
for i=1:num_cases_D
    t=results_s{i}.times; R=R_display_all{i}; valid=(t>0)&isfinite(R)&(R>0); x=t(valid); y=R(valid);
    if numel(x)<12, continue; end
    ly=smoothdata(log(y),'sgolay',min(15,numel(y))); nloc=gradient(ly)./max(gradient(log(x)),eps); nloc=smoothdata(nloc,'movmean',min(15,numel(nloc)));
    keep=x>=stage_bounds(3); if nnz(keep)<5, continue; end
    plot(ax,x(keep),nloc(keep),'-','LineWidth',LW_CRV-0.4,'Color',results_s{i}.color,'DisplayName',sprintf('T=%d K',results_s{i}.T));
    series(end+1)=mkseries(sprintf('T=%d K',results_s{i}.T),x(keep),nloc(keep),'line');
end
xlim(ax,[0 tmax]); ylim(ax,[-0.2 1.4]); add_stages(ax,stage_bounds,stage_names,stage_clrs,ylim(ax),FS_STG); yline(ax,1/3,'--k','n=1/3'); yline(ax,1/2,':k','n=1/2');
xlabel(ax,'Time (t)'); ylabel(ax,'n(t)=dln(r)/dln(t)'); title(ax,['14 Local exponent' cap_suffix]); legend(ax,'show'); grid(ax,'on');
save_plot_both(f,out_mode,'14_LocalExponent_vs_Time'); if ~isempty(series), export_plot_csv_xlsx(out_mode,'14_LocalExponent_vs_Time',['14 Local exponent' cap_suffix],'Time (t)','n(t)',regime,series); end

f=figure('Visible','off','Position',[100,100,1600,900]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX); add_stages(ax,stage_bounds,stage_names,stage_clrs,[],FS_STG); series=initseries();
for i=1:num_cases_D
    t=results_s{i}.times; R=R_display_all{i}; idx3=find(t>=stage_bounds(3),1,'first');
    if ~isempty(idx3)&&R(idx3)>0
        y=R/R(idx3); plot(ax,t,y,'-','LineWidth',LW_CRV,'Color',results_s{i}.color,'DisplayName',sprintf('T=%d K',results_s{i}.T));
        series(end+1)=mkseries(sprintf('T=%d K',results_s{i}.T),t,y,'line');
    end
end
yline(ax,1.0,'--k','Stage-3 start'); xlim(ax,[0 tmax]); xlabel(ax,'Time (t)'); ylabel(ax,'r_{eff}/r_{eff}(t_{S3})'); title(ax,['15 Normalized radius' cap_suffix]); legend(ax,'Location','northwest'); grid(ax,'on');
save_plot_both(f,out_mode,'15_Normalized_Radius_vs_Time'); if ~isempty(series), export_plot_csv_xlsx(out_mode,'15_Normalized_Radius_vs_Time',['15 Normalized radius' cap_suffix],'Time (t)','r_eff/r_eff(tS3)',regime,series); end

f=figure('Visible','off','Position',[100,100,1500,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX); series=initseries();
for i=1:num_cases_D
    Nn=results_s{i}.num_bubbles; if Nn(1)>0
        y=Nn/Nn(1); plot(ax,results_s{i}.times,y,'-','LineWidth',LW_CRV,'Color',results_s{i}.color,'DisplayName',sprintf('T=%d K',results_s{i}.T));
        series(end+1)=mkseries(sprintf('T=%d K',results_s{i}.T),results_s{i}.times,y,'line');
    end
end
xlim(ax,[0 tmax]); add_stages(ax,stage_bounds,stage_names,stage_clrs,ylim(ax),FS_STG); yline(ax,1.0,'--k','N/N0=1');
xlabel(ax,'Time (t)'); ylabel(ax,'N/N0'); title(ax,['16 Normalized bubble count' cap_suffix]); legend(ax,'show'); grid(ax,'on');
save_plot_both(f,out_mode,'16_Normalized_BubbleCount_vs_Time'); if ~isempty(series), export_plot_csv_xlsx(out_mode,'16_Normalized_BubbleCount_vs_Time',['16 Normalized bubble count' cap_suffix],'Time (t)','N/N0',regime,series); end

single_field_plot(results_s,out_mode,'17_Vacancy_Bubble_vs_Time',['17 Vacancy bubble' cap_suffix],'cv_bubble','Time (t)','c_v bubble',regime,FS_AX,LW_AX,LW_CRV);
single_field_plot(results_s,out_mode,'18_Vacancy_Matrix_vs_Time',['18 Vacancy matrix' cap_suffix],'cv_matrix','Time (t)','c_v matrix',regime,FS_AX,LW_AX,LW_CRV);
single_field_plot(results_s,out_mode,'19_Gas_Bubble_vs_Time',['19 Gas bubble' cap_suffix],'cg_bubble','Time (t)','c_g bubble',regime,FS_AX,LW_AX,LW_CRV);
single_field_plot(results_s,out_mode,'20_Gas_Matrix_vs_Time',['20 Gas matrix' cap_suffix],'cg_matrix','Time (t)','c_g matrix',regime,FS_AX,LW_AX,LW_CRV);

f=figure('Visible','off','Position',[100,100,1400,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX); series=initseries();
for i=1:num_cases_D
    t=results_s{i}.times; y=max(results_s{i}.avg_radius,eps).^3;
    plot(ax,t,y,'LineWidth',LW_CRV,'Color',results_s{i}.color,'DisplayName',sprintf('T=%d K',results_s{i}.T));
    series(end+1)=mkseries(sprintf('T=%d K',results_s{i}.T),t,y,'line');
end
xlabel(ax,'Time (t)'); ylabel(ax,'r_{eff}^3'); title(ax,['21 Ostwald check r^3' cap_suffix]); legend(ax,'Location','best'); grid(ax,'on');
save_plot_both(f,out_mode,'21_Rcubed_raw_vs_Time'); export_plot_csv_xlsx(out_mode,'21_Rcubed_raw_vs_Time',['21 Ostwald check r^3' cap_suffix],'Time (t)','r_eff^3',regime,series);

f=figure('Visible','off','Position',[100,100,1400,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX); series=initseries();
for i=1:num_cases_D
    mask=results_s{i}.times>=stage_bounds(3);
    x=max(results_s{i}.avg_radius(mask),eps).^(-3);
    y=results_s{i}.num_bubbles(mask);
    scatter(ax,x,y,34,results_s{i}.color,'filled','DisplayName',sprintf('T=%d K',results_s{i}.T));
    if numel(x)>=6
        p=polyfit(x,y,1); xf=linspace(min(x),max(x),120); plot(ax,xf,polyval(p,xf),'-','Color',results_s{i}.color,'LineWidth',1.8,'HandleVisibility','off');
    end
    series(end+1)=mkseries(sprintf('T=%d K',results_s{i}.T),x,y,'scatter');
end
xlabel(ax,'r_{eff}^{-3}'); ylabel(ax,'N'); title(ax,['22 LSW consistency N vs r^{-3}' cap_suffix]); legend(ax,'Location','best'); grid(ax,'on');
save_plot_both(f,out_mode,'22_N_vs_Rminus3'); export_plot_csv_xlsx(out_mode,'22_N_vs_Rminus3',['22 LSW consistency' cap_suffix],'r_eff^{-3}','N',regime,series);

single_field_combo(results_s,out_mode,'23_DeltaCv_vs_Time',['23 Mass-transfer driving proxy' cap_suffix],@(r)(r.cv_bubble-r.cv_matrix),'Time (t)','Delta c_v',regime,FS_AX,LW_AX,LW_CRV);
single_field_combo(results_s,out_mode,'24_InterfaceCompactness_vs_Time',['24 Interface compactness' cap_suffix],@(r)(r.total_perimeter./max(r.total_area,eps)),'Time (t)','P_tot/A_tot',regime,FS_AX,LW_AX,LW_CRV);
end