clear; close all; clc;
%% --------------------------------
regime_list = {'50'};       
T_values    = [800 900 1000];
num_T       = numel(T_values);
colors_list = lines(max(num_T,3));

N_global          = 512;                  
dx_global         = 1.0;
dt_global         = 0.015;
num_isteps_global  = 120000;              
snapshot_int      = 400;
save_snap_every   = 2000;
init_mode_global  = 'droplets';

FS_AX=16; FS_LAB=18; FS_TIT=20; FS_LEG=14; FS_STG=11;
LW_AX=1.8; LW_CRV=2.8;

stage_bounds = [0,250,800,1400,2000];
stage_names  = {'Stage 1: Early separation','Stage 2: Droplet selection', ...
                'Stage 3: Ostwald ripening','Stage 4: Late coarsening'};
stage_clrs   = {[0.88 0.93 1.00],[0.88 1.00 0.90],[1.00 0.98 0.84],[1.00 0.90 0.90]};

% Fe labels
M_Fe=55.845e-3; N_A=6.02214076e23; a_Fe=2.884e-10;
rho_Fe_mass=(2*M_Fe/N_A)/a_Fe^3;
rho_Fe_num =2/a_Fe^3;
fprintf('Fe mass density   = %.2f kg/m^3\n', rho_Fe_mass);
fprintf('Fe number density = %.4e atoms/m^3\n\n', rho_Fe_num);

kB_eV=8.617333262e-5; 
kB_J =1.380649e-23;
T_ref=900; 
M0=1.0;

%% ---------------- GPU SETTINGS ----------------
use_gpu = true;     % true = try GPU, false = CPU
gpu_ok  = false;
if use_gpu
    try
        g = gpuDevice;
        fprintf('GPU enabled: %s | ComputeCapability: %s\n\n', g.Name, g.ComputeCapability);
        gpu_ok = true;
    catch ME
        warning('GPU not available. Falling back to CPU. (%s)', ME.message);
        gpu_ok = false;
    end
else
    fprintf('GPU disabled by user. Running on CPU.\n\n');
end

%% ---------------- ELASTIC + STRESS SETTINGS ----------------
use_elasticity_global = true;
C11_const = 2.33;
C12_const = C11_const * (122.0 / 180.0);   % 1.5792222222
C44_const = C11_const * (104.0 / 180.0);   % 1.3462222222
    
k2_eps   = 1e-14;
mu_scale = 3.0;
h_pow    = 2;

eps0x  = 0.005;
eps0y  = 0.005;
eps0xy = 0.00;

fprintf('================ ELASTIC SETTINGS =================\n');
fprintf('   C11_const = %.9f  <-> 180 GPa\n', C11_const);
fprintf('   C12_const = %.9f  <-> 122 GPa\n', C12_const);
fprintf('   C44_const = %.9f  <-> 104 GPa\n', C44_const);
fprintf('   Eigenstrain bias: eps0x=%.3f, eps0y=%.3f, eps0xy=%.3f\n', eps0x, eps0y, eps0xy);

%% ---------------- RESIDUAL STRESS ----------------
% residual equi-biaxial matrix stress in GPa
C11_phys_900K_GPa = 180.0;
stress_scale_GPa_per_model = C11_phys_900K_GPa / C11_const;

S_levels_GPa   = [-2 0 +2];
S_levels_model = S_levels_GPa ./ stress_scale_GPa_per_model;

V_act_nm3 = 0.0037;
V_act_m3  = V_act_nm3 * 1e-27;

fprintf('\n================ STRESS SETTINGS ==================\n');
fprintf('Stress scale: 1 model stress unit = %.6f GPa\n', stress_scale_GPa_per_model);
fprintf('Residual stress sweep (GPa -> solver units):\n');
for ii = 1:numel(S_levels_GPa)
    fprintf('   %+5.2f GPa -> %+0.6f model\n', S_levels_GPa(ii), S_levels_model(ii));
end
fprintf('Only residual biaxial matrix stress is retained.\n');
fprintf('==================================================\n\n');

%% --------------------------------
scenario = struct([]);
sidx = 0;

for iS = 1:numel(S_levels_GPa)
    sidx = sidx + 1;

    g = S_levels_GPa(iS);
    m = S_levels_model(iS);

    if g > 0
        gtag = sprintf('p%.1f', g);
    elseif g < 0
        gtag = sprintf('m%.1f', abs(g));
    else
        gtag = '0p0';
    end
    gtag = strrep(gtag, '.', 'p');

    scenario(sidx).case_name = 'WEN_900K_RESIDUAL_STRESS';
    scenario(sidx).tag       = ['RS_' gtag 'GPa'];
    scenario(sidx).S_model   = m;
    scenario(sidx).S_GPa     = g;
end

ALL = struct([]);
all_idx = 0;

%% ================= OUTER LOOP OVER STRESS SCENARIOS =================
for sc=1:numel(scenario)

    S_current_model = scenario(sc).S_model;
    S_current_GPa   = scenario(sc).S_GPa;
    scenario_tag    = scenario(sc).tag;
    scenario_name   = scenario(sc).case_name;

    fprintf('\n############################################################\n');
    fprintf('SCENARIO %d/%d | %s | S_GPa=%+.3f | S_model=%+.6f\n', ...
        sc, numel(scenario), scenario_name, S_current_GPa, S_current_model);
    fprintf('############################################################\n');

    if abs(S_current_GPa) < 1e-12
        stress_modes = { ...
            struct('name','NO_STRESS',      'sx',0.0,             'sy',0.0,             'S_GPa',0.0,           'use_disl',false), ...
            struct('name','RESIDUAL_BIAX',  'sx',0.0,             'sy',0.0,             'S_GPa',0.0,           'use_disl',false) ...
        };
    else
        stress_modes = { ...
            struct('name','NO_STRESS',      'sx',0.0,             'sy',0.0,             'S_GPa',0.0,           'use_disl',false), ...
            struct('name','RESIDUAL_BIAX',  'sx',S_current_model, 'sy',S_current_model, 'S_GPa',S_current_GPa, 'use_disl',false) ...
        };
    end
    num_modes = numel(stress_modes);

    %% ================= OUTER LOOP OVER REGIMES =================
regime = '50';
phi0_global = 0.10;
num_seeds_0 = 300;
seed_radius_0 = 2.5;
seed_spacing_0 = 15;
noise_amp_0 = 0.0050;

        out_folder  = fullfile(pwd,sprintf('GROUP_D_Fe_MERGED_OriginReady_regime_%s_%s',regime,scenario_tag));
        snap_folder = fullfile(out_folder,'SNAPSHOTS');
        if ~isfolder(out_folder), mkdir(out_folder); end
        if ~isfolder(snap_folder), mkdir(snap_folder); end

        fprintf('\n============================================================\n');
        fprintf('Running regime %s%% | phi0=%.2f | scenario=%s\n', regime, phi0_global, scenario_tag);
        fprintf('Output folder: %s\n', out_folder);
        fprintf('============================================================\n');

        %% case setup temperature
        cases_D = cell(1,num_T);
        for k=1:num_T
            T=T_values(k);
            M_eff=M0*exp(-(0.20/kB_eV)*(1/T-1/T_ref));
            cases_D{k}=struct( ...
                'name',sprintf('CH+Stress+Elastic, T=%d K',T), ...
                'T',T,'color',colors_list(k,:), ...
                'phi0',phi0_global,'init_mode',init_mode_global, ...
                'num_seeds',num_seeds_0,'seed_radius',seed_radius_0, ...
                'seed_spacing',seed_spacing_0,'noise_amp',noise_amp_0, ...
                'M',M_eff,'kappa',4.2,'A',1.2,'case_num',k, ...
                'use_elasticity',use_elasticity_global, ...
                'C11',C11_const,'C12',C12_const,'C44',C44_const);
        end

        % results storage: {T,mode}
        results_D = cell(num_T,num_modes);
        snapshot_index = table();

        %% ================= RUN: MODE x TEMPERATURE =================
        for mm=1:num_modes
            md = stress_modes{mm};
            fprintf('\n---------------- MODE: %s ----------------\n', md.name);

            for case_idx=1:num_T
                ci = cases_D{case_idx};
                fprintf('CASE %d/%d | T=%d K | sx=%+.6f sy=%+.6f | S_GPa=%+.3f | disl=%d\n', ...
                    case_idx,num_T,ci.T,md.sx,md.sy,md.S_GPa,md.use_disl);

                rng(1,'twister'); 
                N=N_global; dx=dx_global; dt=dt_global;
                nisteps=num_isteps_global; snapint=snapshot_int;
                M=ci.M; kappa=ci.kappa; A=ci.A;

                P_case_Pa = -md.S_GPa * 1e9;
                stress_factor = exp(-(P_case_Pa * V_act_m3)/(kB_J * ci.T));
                M_case = M * stress_factor;

                eta=make_initial_eta_CH_uniform(N,ci.phi0,ci.num_seeds,ci.seed_radius,ci.noise_amp);
                eta=min(max(eta,1e-6),1-1e-6); 
                eta_mean0=mean(eta(:));

                cv=0.02+0.10*eta; 
                cv=min(max(cv,0),0.15);

                cg=0.01+0.08*eta; 
                cg=min(max(cg,0),0.10);

                kvec=(2*pi/N)*[0:N/2-1,-N/2:-1];
                [kx,ky]=meshgrid(kvec,kvec); 
                K2=kx.^2+ky.^2; 
                K4=K2.^2;

                if md.use_disl
                    disl = make_default_disl(N);
                    [sigxx_disl,sigyy_disl,sigxy_disl]=make_disl_dipole_stress(N,disl);
                else
                    sigxx_disl=zeros(N); 
                    sigyy_disl=zeros(N); 
                    sigxy_disl=zeros(N);
                end

                % GPU cast
                if gpu_ok
                    eta = gpuArray(eta);
                    cv  = gpuArray(cv);
                    cg  = gpuArray(cg);
                    kx  = gpuArray(kx);
                    ky  = gpuArray(ky);
                    K2  = gpuArray(K2);
                    K4  = gpuArray(K4);
                    sigxx_disl = gpuArray(sigxx_disl);
                    sigyy_disl = gpuArray(sigyy_disl);
                    sigxy_disl = gpuArray(sigxy_disl);
                end

                num_snap=floor(nisteps/snapint)+1;
                times_arr=zeros(1,num_snap); 
                n_bub_arr=zeros(1,num_snap);
                r_eff_arr=zeros(1,num_snap); 
                r_num_arr=zeros(1,num_snap); 
                r_aw_arr=zeros(1,num_snap);
                gas_vol_arr=zeros(1,num_snap); 
                shape_rat_arr=zeros(1,num_snap);
                total_perim_arr=zeros(1,num_snap); 
                total_area_arr=zeros(1,num_snap);
                cv_bub_arr=zeros(1,num_snap); 
                cv_mat_arr=zeros(1,num_snap);
                cg_bub_arr=zeros(1,num_snap); 
                cg_mat_arr=zeros(1,num_snap);
                mass_arr=zeros(1,num_snap); 
                mass_err_arr=zeros(1,num_snap);
                fel_mean_arr=zeros(1,num_snap);
                stress_factor_arr=zeros(1,num_snap);
                num_live = floor(num_isteps_global/2000) + 2;
live_t_arr   = nan(1,num_live);
live_fel_arr = nan(1,num_live);
live_idx = 0;           
% ---- stress diagnostics arrays ----
sxx_max_arr = zeros(1,num_snap);
syy_max_arr = zeros(1,num_snap);
sxy_max_arr = zeros(1,num_snap);

sxx_rms_arr = zeros(1,num_snap);
syy_rms_arr = zeros(1,num_snap);
sxy_rms_arr = zeros(1,num_snap);
                % CPU-only morphology metrics => gather
                eta_cpu = gather(eta);
                cv_cpu  = gather(cv);
                cg_cpu  = gather(cg);

                [nb0,rnum0,raw0,reff0,ta0,tp0,sr0]=measure_bubbles_refined_CH(eta_cpu,dx);
                [cvb0,cvm0,cgb0,cgm0]=compute_phase_averages(eta_cpu,cv_cpu,cg_cpu);

                [~,fel0,sigxx,sigyy,sigxy]=elastic_mu_aniso_cubic_2d_allstress( ...
                    eta,ci.C11,ci.C12,ci.C44,eps0x,eps0y,eps0xy,h_pow, ...
                    md.sx,md.sy,sigxx_disl,sigyy_disl,sigxy_disl,mu_scale,kx,ky,k2_eps);
% ---- initial stress diagnostics (istep = 0) ----
sigxx0_cpu = gather(sigxx);
sigyy0_cpu = gather(sigyy);
sigxy0_cpu = gather(sigxy);

sxx_max_arr(1) = max(abs(sigxx0_cpu(:)));
syy_max_arr(1) = max(abs(sigyy0_cpu(:)));
sxy_max_arr(1) = max(abs(sigxy0_cpu(:)));

sxx_rms_arr(1) = sqrt(mean(sigxx0_cpu(:).^2));
syy_rms_arr(1) = sqrt(mean(sigyy0_cpu(:).^2));
sxy_rms_arr(1) = sqrt(mean(sigxy0_cpu(:).^2));

fprintf('INIT stress | mode=%s | T=%d | istep=%d | max|sxx|=%.3e | max|syy|=%.3e | max|sxy|=%.3e | rms(sxx)=%.3e | rms(syy)=%.3e | rms(sxy)=%.3e\n', ...
    md.name, ci.T, 0, ...
    sxx_max_arr(1), syy_max_arr(1), sxy_max_arr(1), ...
    sxx_rms_arr(1), syy_rms_arr(1), sxy_rms_arr(1));
                snap=1;
                times_arr(1)=0; 
                n_bub_arr(1)=nb0; 
                r_eff_arr(1)=reff0; 
                r_num_arr(1)=rnum0; 
                r_aw_arr(1)=raw0;
                gas_vol_arr(1)=mean(eta_cpu(:)); 
                total_area_arr(1)=ta0; 
                total_perim_arr(1)=tp0; 
                shape_rat_arr(1)=sr0;
                cv_bub_arr(1)=cvb0; 
                cv_mat_arr(1)=cvm0; 
                cg_bub_arr(1)=cgb0; 
                cg_mat_arr(1)=cgm0;
                mass_arr(1)=mean(eta_cpu(:)); 
                mass_err_arr(1)=mass_arr(1)-eta_mean0;
                fel_mean_arr(1)=mean(gather(fel0(:)));
                stress_factor_arr(1)=stress_factor;
fprintf('INIT stress | mode=%s | T=%d | step=%d | max|sxx|=%.3e | max|syy|=%.3e | max|sxy|=%.3e | rms(sxx)=%.3e | rms(syy)=%.3e | rms(sxy)=%.3e\n', ...
    md.name, ci.T, 0, ...
    sxx_max_arr(1), syy_max_arr(1), sxy_max_arr(1), ...
    sxx_rms_arr(1), syy_rms_arr(1), sxy_rms_arr(1));
                snap_name = fullfile(snap_folder,sprintf('mode_%s_T%d_case%d_istep%06d',md.name,ci.T,case_idx,0));
                savefieldsnapshot_CH(gather(eta),gather(cv),gather(cg),snap_name,ci.num_seeds,ci.T,0,0,rho_Fe_mass,mean(gather(eta(:))),cvb0,cvm0,cgb0,cgm0,FS_AX,FS_LAB,FS_TIT);
                save_stress_maps(gather(eta), gather(sigxx),gather(sigyy),gather(sigxy), ...
                    fullfile(snap_folder,sprintf('mode_%s_T%d_case%d_istep%06d_stress',md.name,ci.T,case_idx,0)), ...
                    ci.T, md.name, 0, 0);

                snapshot_index = [snapshot_index; table(string(md.name),ci.T,case_idx,0,0,string(snap_name), ...
                    'VariableNames',{'mode','T','case_idx','istep','time','base_path'})]; %#ok<AGROW>

                tic;
                for istep=1:nisteps
                    if mod(istep,2000)==0 || istep==1
                        fprintf('   istep %6d/%6d (%.1f%%) | stress_factor=%.4f\n',istep,nisteps,100*istep/nisteps,stress_factor);
                    end

                    dfdeta_chem=2*A*eta.*(1-eta).*(1-2*eta);
                    if ci.use_elasticity
                        [mu_el,fel,sigxx,sigyy,sigxy]=elastic_mu_aniso_cubic_2d_allstress( ...
                            eta,ci.C11,ci.C12,ci.C44,eps0x,eps0y,eps0xy,h_pow, ...
                            md.sx,md.sy,sigxx_disl,sigyy_disl,sigxy_disl,mu_scale,kx,ky,k2_eps);
                        dfdeta=dfdeta_chem+mu_el;
                    else
                        dfdeta=dfdeta_chem; 
                        fel=zeros(size(eta),'like',eta);
                        sigxx=zeros(N,N,'like',eta); 
                        sigyy=zeros(N,N,'like',eta); 
                        sigxy=zeros(N,N,'like',eta);
                    end

if mod(istep,2000)==0 || istep==1

    eta_cpu   = gather(eta);
    sigxx_cpu = gather(sigxx);
    sigyy_cpu = gather(sigyy);
    sigxy_cpu = gather(sigxy);
    fel_cpu   = gather(fel);

    live_idx = live_idx + 1;
    live_t_arr(live_idx)   = istep*dt;
    live_fel_arr(live_idx) = mean(fel_cpu(:));

    mx_live = max(abs([sigxx_cpu(:); sigyy_cpu(:); sigxy_cpu(:)]));
    if mx_live < 1e-12
        mx_live = 1e-12;
    end

    red_rgb = cat(3, ones(size(eta_cpu)), zeros(size(eta_cpu)), zeros(size(eta_cpu)));

  
end

                    eta_hat=fft2(eta);
                    eta_hat_new=(eta_hat-dt*M_case*K2.*fft2(dfdeta))./(1+dt*M_case*kappa*K4);
                    eta_hat_new(1,1)=eta_hat(1,1);

                    eta=real(ifft2(eta_hat_new));
                    eta=eta-mean(eta(:))+eta_mean0;
                    eta=min(max(eta,1e-6),1-1e-6);

                    cv=0.02+0.10*eta; 
                    cv=min(max(cv,0),0.15);
                    cg=0.01+0.08*eta; 
                    cg=min(max(cg,0),0.10);

                    if mod(istep,snapint)==0
                        snap=snap+1; 
                        ct=istep*dt;

                        eta_cpu = gather(eta);
                        cv_cpu  = gather(cv);
                        cg_cpu  = gather(cg);

                        [nb,rnum,raw,reff,ta,tp,sr]=measure_bubbles_refined_CH(eta_cpu,dx);
                        [cvb,cvm,cgb,cgm]=compute_phase_averages(eta_cpu,cv_cpu,cg_cpu);

                        times_arr(snap)=ct; 
                        n_bub_arr(snap)=nb;
                        r_eff_arr(snap)=reff; 
                        r_num_arr(snap)=rnum; 
                        r_aw_arr(snap)=raw;
                        gas_vol_arr(snap)=mean(eta_cpu(:));
                        total_area_arr(snap)=ta; 
                        total_perim_arr(snap)=tp; 
                        shape_rat_arr(snap)=sr;
                        cv_bub_arr(snap)=cvb; 
                        cv_mat_arr(snap)=cvm; 
                        cg_bub_arr(snap)=cgb; 
                        cg_mat_arr(snap)=cgm;
                        mass_arr(snap)=mean(eta_cpu(:)); 
                        mass_err_arr(snap)=mass_arr(snap)-eta_mean0;
                        fel_mean_arr(snap)=mean(gather(fel(:)));
                        stress_factor_arr(snap)=stress_factor;
                         sigxx_cpu = gather(sigxx);
sigyy_cpu = gather(sigyy);
sigxy_cpu = gather(sigxy);

sxx_max_arr(snap) = max(abs(sigxx_cpu(:)));
syy_max_arr(snap) = max(abs(sigyy_cpu(:)));
sxy_max_arr(snap) = max(abs(sigxy_cpu(:)));

sxx_rms_arr(snap) = sqrt(mean(sigxx_cpu(:).^2));
syy_rms_arr(snap) = sqrt(mean(sigyy_cpu(:).^2));
sxy_rms_arr(snap) = sqrt(mean(sigxy_cpu(:).^2));
                        if mod(istep,save_snap_every)==0
                            snap_name = fullfile(snap_folder,sprintf('mode_%s_T%d_case%d_istep%06d',md.name,ci.T,case_idx,istep));
                            savefieldsnapshot_CH(gather(eta),gather(cv),gather(cg),snap_name,ci.num_seeds,ci.T,ct,istep,rho_Fe_mass,mean(gather(eta(:))),cvb,cvm,cgb,cgm,FS_AX,FS_LAB,FS_TIT);
                            save_stress_maps(gather(eta), gather(sigxx),gather(sigyy),gather(sigxy), ...
                                fullfile(snap_folder,sprintf('mode_%s_T%d_case%d_istep%06d_stress',md.name,ci.T,case_idx,istep)), ...
                                ci.T, md.name, istep, ct);
                            snapshot_index = [snapshot_index; table(string(md.name),ci.T,case_idx,istep,ct,string(snap_name), ...
                                'VariableNames',{'mode','T','case_idx','istep','time','base_path'})]; %#ok<AGROW>
                        end
                    end
                end

                fprintf('   DONE in %.2f min | FinalN=%d Reff=%.3f |dM|=%.3e\n', ...
                    toc/60,n_bub_arr(snap),r_eff_arr(snap),abs(mass_err_arr(snap)));

                idx=1:snap;
                results_D{case_idx,mm}=struct( ...
                    'name',ci.name,'T',ci.T,'color',ci.color, ...
                    'mode_name',md.name,'sx',md.sx,'sy',md.sy,'S_GPa',md.S_GPa,'use_disl',md.use_disl, ...
                    'times',times_arr(idx),'num_bubbles',n_bub_arr(idx), ...
                    'avg_radius',r_eff_arr(idx),'radius_num',r_num_arr(idx),'radius_aw',r_aw_arr(idx), ...
                    'gas_volume',gas_vol_arr(idx),'shape_ratio',shape_rat_arr(idx), ...
                    'total_perimeter',total_perim_arr(idx),'total_area',total_area_arr(idx), ...
                    'cv_bubble',cv_bub_arr(idx),'cv_matrix',cv_mat_arr(idx), ...
                    'cg_bubble',cg_bub_arr(idx),'cg_matrix',cg_mat_arr(idx), ...
                    'mass',mass_arr(idx), ...
'mass_error',mass_err_arr(idx), ...
'fel_mean',fel_mean_arr(idx), ...
'stress_factor',stress_factor_arr(idx), ...
'stress_sxx_max',sxx_max_arr(idx), ...
'stress_syy_max',syy_max_arr(idx), ...
'stress_sxy_max',sxy_max_arr(idx), ...
'stress_sxx_rms',sxx_rms_arr(idx), ...
'stress_syy_rms',syy_rms_arr(idx), ...
'stress_sxy_rms',sxy_rms_arr(idx), ...
'eta_mean0',eta_mean0, ...
'case_num',case_idx,'mode_idx',mm);              
            end
        end

        %% ---------------- metrics mode x T ----------------
        metrics=struct([]);
        for mm=1:num_modes
            temperatures=zeros(1,num_T); 
            final_bubbles=zeros(1,num_T);
            final_reff=nan(1,num_T); 
            final_shape=nan(1,num_T); 
            final_vf=nan(1,num_T);
            K_late=nan(1,num_T); 
            K_late_R2=nan(1,num_T);
            stress_factor_T=nan(1,num_T);

            for i=1:num_T
                r=results_D{i,mm}; 
                temperatures(i)=r.T;
                final_bubbles(i)=r.num_bubbles(end);
                final_reff(i)=r.avg_radius(end);
                final_shape(i)=r.shape_ratio(end);
                final_vf(i)=r.gas_volume(end);
                stress_factor_T(i)=r.stress_factor(end);

                t=r.times; 
                R=max(r.avg_radius,eps); 
                R3=max(R.^3-R(1)^3,0);
                mask=(t>=0.35*max(t))&(t<=0.90*max(t))&(R3>0);
                if nnz(mask)>=6
                    x=t(mask); y=R3(mask);
                    pfit=polyfit(x,y,1); 
                    yhat=polyval(pfit,x);
                    SSr=sum((y-yhat).^2); 
                    SSt=sum((y-mean(y)).^2);
                    K_late(i)=max(pfit(1),0); 
                    K_late_R2(i)=1-SSr/max(SSt,eps);
                end
            end

            metrics(mm).mode_name=stress_modes{mm}.name;
            metrics(mm).temperatures=temperatures;
            metrics(mm).final_bubbles=final_bubbles;
            metrics(mm).final_reff=final_reff;
            metrics(mm).final_shape=final_shape;
            metrics(mm).final_vf=final_vf;
            metrics(mm).K_late=K_late;
            metrics(mm).K_late_R2=K_late_R2;
            metrics(mm).stress_factor=stress_factor_T;
        end

        %% ---------------- save run data ----------------
        save_file=fullfile(out_folder,sprintf('Fe_He_MERGED_OriginReady_regime_%s.mat',regime));
        save(save_file,'results_D','cases_D','metrics','stress_modes','T_values','regime', ...
            'stage_bounds','stage_names','rho_Fe_num','rho_Fe_mass', ...
            'C11_const','C12_const','C44_const','eps0x','eps0y','eps0xy','h_pow','mu_scale', ...
            'scenario_name','scenario_tag','S_current_model','S_current_GPa', ...
            'stress_scale_GPa_per_model','V_act_nm3','V_act_m3');
        writetable(snapshot_index,fullfile(out_folder,'Snapshot_Index.csv'));

        rows=table();
        for mm=1:num_modes
            for it=1:num_T
                r=results_D{it,mm};
                rows=[rows; table(string(regime),string(scenario_tag),S_current_GPa,r.T,string(r.mode_name), ...
                    r.sx,r.sy,r.use_disl,r.stress_factor(end), ...
                    r.num_bubbles(end),r.avg_radius(end),r.gas_volume(end), ...
                    metrics(mm).K_late(it),metrics(mm).K_late_R2(it),r.mass_error(end), ...
                    'VariableNames',{'regime','scenario_tag','S_GPa','T','mode','sx','sy','use_disl','stress_factor','FinalN','FinalReff','FinalVF','K_late','K_late_R2','mass_error_final'})]; %#ok<AGROW>
            end
        end
        writetable(rows,fullfile(out_folder,'Stress_Summary_All.csv'));

        all_idx = all_idx + 1;
        ALL(all_idx).regime = regime;
        ALL(all_idx).results_D = results_D;
        ALL(all_idx).metrics = metrics;
        ALL(all_idx).stress_modes = stress_modes;
        ALL(all_idx).out_folder = out_folder;
        ALL(all_idx).scenario_name = scenario_name;
        ALL(all_idx).scenario_tag = scenario_tag;
        ALL(all_idx).S_current_model = S_current_model;
        ALL(all_idx).S_current_GPa = S_current_GPa;
        ALL(all_idx).stress_scale_GPa_per_model = stress_scale_GPa_per_model;

        %% ========================= PLOTTING =========================
num_modes_local = numel(stress_modes);
num_T_local     = numel(T_values);

for mm = 1:num_modes_local
    md = stress_modes{mm};
    mode_tag = regexprep(md.name,'[^a-zA-Z0-9]','');
    out_mode = fullfile(out_folder, ['PLOTS_' mode_tag]);
    if ~isfolder(out_mode), mkdir(out_mode); end

    results_s = cell(1,num_T_local);
    for i = 1:num_T_local
        results_s{i} = results_D{i,mm};
    end

    num_cases_D = numel(results_s);

    for i = 1:num_cases_D
        r = results_s{i};

    if isfield(r,'num_bubbles')     && ~isfield(r,'numbubbles'),      r.numbubbles      = r.num_bubbles;      end
    if isfield(r,'avg_radius')      && ~isfield(r,'avgradius'),       r.avgradius       = r.avg_radius;       end
    if isfield(r,'radius_num')      && ~isfield(r,'radiusnum'),       r.radiusnum       = r.radius_num;       end
    if isfield(r,'radius_aw')       && ~isfield(r,'radiusaw'),        r.radiusaw        = r.radius_aw;        end
    if isfield(r,'gas_volume')      && ~isfield(r,'gasvolume'),       r.gasvolume       = r.gas_volume;       end
    if isfield(r,'shape_ratio')     && ~isfield(r,'shaperatio'),      r.shaperatio      = r.shape_ratio;      end
    if isfield(r,'total_perimeter') && ~isfield(r,'totalperimeter'),  r.totalperimeter  = r.total_perimeter;  end
    if isfield(r,'total_area')      && ~isfield(r,'totalarea'),       r.totalarea       = r.total_area;       end
    if isfield(r,'cv_bubble')       && ~isfield(r,'cvbubble'),        r.cvbubble        = r.cv_bubble;        end
    if isfield(r,'cv_matrix')       && ~isfield(r,'cvmatrix'),        r.cvmatrix        = r.cv_matrix;        end
    if isfield(r,'cg_bubble')       && ~isfield(r,'cgbubble'),        r.cgbubble        = r.cg_bubble;        end
    if isfield(r,'cg_matrix')       && ~isfield(r,'cgmatrix'),        r.cgmatrix        = r.cg_matrix;        end
    if isfield(r,'mass_error')      && ~isfield(r,'masserror'),       r.masserror       = r.mass_error;       end
    if isfield(r,'fel_mean')        && ~isfield(r,'felmean'),         r.felmean         = r.fel_mean;         end
    if isfield(r,'stress_factor')   && ~isfield(r,'stressfactor'),    r.stressfactor    = r.stress_factor;    end

    if isfield(r,'stress_sxx_max')  && ~isfield(r,'stresssxxmax'),    r.stresssxxmax    = r.stress_sxx_max;   end
    if isfield(r,'stress_syy_max')  && ~isfield(r,'stresssyymax'),    r.stresssyymax    = r.stress_syy_max;   end
    if isfield(r,'stress_sxy_max')  && ~isfield(r,'stresssxymax'),    r.stresssxymax    = r.stress_sxy_max;   end

    if isfield(r,'stress_sxx_rms')  && ~isfield(r,'stresssxxrms'),    r.stresssxxrms    = r.stress_sxx_rms;   end
    if isfield(r,'stress_syy_rms')  && ~isfield(r,'stresssyyrms'),    r.stresssyyrms    = r.stress_syy_rms;   end
    if isfield(r,'stress_sxy_rms')  && ~isfield(r,'stresssxyrms'),    r.stresssxyrms    = r.stress_sxy_rms;   end

    if isfield(r,'mode_name')       && ~isfield(r,'modename'),        r.modename        = r.mode_name;        end
    if isfield(r,'case_num')        && ~isfield(r,'casenum'),         r.casenum         = r.case_num;         end
    if isfield(r,'mode_idx')        && ~isfield(r,'modeidx'),         r.modeidx         = r.mode_idx;         end
    if isfield(r,'eta_mean0')       && ~isfield(r,'etamean0'),        r.etamean0        = r.eta_mean0;        end

    results_s{i} = r;
end
            num_cases_D = numel(results_s);

            temperatures=zeros(1,num_cases_D);
            final_bubbles=zeros(1,num_cases_D);
            coalescence_eff=zeros(1,num_cases_D);
            ripening_rate=nan(1,num_cases_D);
            stress_factor_curve=nan(1,num_cases_D);

            K_late = metrics(mm).K_late;
            K_late_R2 = metrics(mm).K_late_R2;
            n_late = nan(1,num_cases_D);

            R_display_all=cell(1,num_cases_D);
            R3_corr_all=cell(1,num_cases_D);
            fit_mask_all=cell(1,num_cases_D);

            tmax=max(results_s{1}.times);

            for i=1:num_cases_D
                r=results_s{i};
                temperatures(i)=r.T;
                final_bubbles(i)=r.num_bubbles(end);
                coalescence_eff(i)=100*max(r.num_bubbles(1)-r.num_bubbles(end),0)/max(r.num_bubbles(1),1);
                ripening_rate(i)=max(r.num_bubbles(1)-r.num_bubbles(end),0)/max(r.times(end)-r.times(1),eps);
                stress_factor_curve(i)=r.stress_factor(end);

                R_display_all{i}=r.avg_radius;
                R3_corr_all{i}=max(r.avg_radius.^3-r.avg_radius(1)^3,0);

                mask=(r.times>=stage_bounds(3))&(r.times<=stage_bounds(4))&(R3_corr_all{i}>0);
                fit_mask_all{i}=mask;
                if nnz(mask)>=6
                    p=polyfit(log(r.times(mask)),log(r.avg_radius(mask)),1);
                    n_late(i)=p(1);
                end
            end

            cap_suffix = sprintf(' | Regime %s%% | Mode=%s | %s', regime, md.name, scenario_tag);

            % ---------- 01 ----------
            f=figure('Visible','off','Position',[100,100,1500,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX);
            series=initseries();
            for i=1:num_cases_D
                plot(ax,results_s{i}.times,results_s{i}.num_bubbles,'Color',results_s{i}.color,'LineWidth',LW_CRV,'DisplayName',sprintf('T=%d K',results_s{i}.T));
                series(end+1)=mkseries(sprintf('T=%d K',results_s{i}.T),results_s{i}.times,results_s{i}.num_bubbles,'line');
            end
            xlim(ax,[0 tmax]); ylim(ax,[0 max(cellfun(@(r)max(r.num_bubbles),results_s))+10]);
            add_stages(ax,stage_bounds,stage_names,stage_clrs,ylim(ax),FS_STG);
            xlabel(ax,'Time (t)'); ylabel(ax,'Number of bubbles'); title(ax,['01 Bubble count vs time' cap_suffix]);
            legend(ax,'Location','best'); grid(ax,'on'); save_plot_both(f,out_mode,'01_BubbleCount_vs_Time');
            export_plot_csv_xlsx(out_mode,'01_BubbleCount_vs_Time',['01 Bubble count vs time' cap_suffix],'Time (t)','Number of bubbles',regime,series);

            % ---------- 02 ----------
            f=figure('Visible','off','Position',[100,100,1500,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX);
            series=initseries();
            for i=1:num_cases_D
                plot(ax,results_s{i}.times,R_display_all{i},'Color',results_s{i}.color,'LineWidth',LW_CRV,'DisplayName',sprintf('T=%d K',results_s{i}.T));
                series(end+1)=mkseries(sprintf('T=%d K',results_s{i}.T),results_s{i}.times,R_display_all{i},'line');
            end
            xlim(ax,[0 tmax]); add_stages(ax,stage_bounds,stage_names,stage_clrs,ylim(ax),FS_STG);
            xlabel(ax,'Time (t)'); ylabel(ax,'Effective radius r_{eff}'); title(ax,['02 Radius vs time' cap_suffix]);
            legend(ax,'Location','best'); grid(ax,'on'); save_plot_both(f,out_mode,'02_Radius_vs_Time');
            export_plot_csv_xlsx(out_mode,'02_Radius_vs_Time',['02 Radius vs time' cap_suffix],'Time (t)','Effective radius r_eff',regime,series);

            % ---------- 03 ----------
            f=figure('Visible','off','Position',[100,100,1300,850]); ax=axes(f); box(ax,'on'); hold(ax,'on'); fmtax(ax,FS_AX,LW_AX);
            plot(ax,temperatures,final_bubbles,'s-','Color',[0.8,0.1,0.1],'LineWidth',LW_CRV,'MarkerFaceColor',[0.8,0.1,0.1],'MarkerSize',12);
            xlabel(ax,'Temperature (K)'); ylabel(ax,'Final number of bubbles'); title(ax,['03 Final bubble count vs T' cap_suffix]); grid(ax,'on');
            save_plot_both(f,out_mode,'03_FinalBubbles_vs_Temperature');
            export_plot_csv_xlsx(out_mode,'03_FinalBubbles_vs_Temperature',['03 Final bubble count vs T' cap_suffix], ...
                'Temperature (K)','Final number of bubbles',regime,mkseries('all_temperatures',temperatures,final_bubbles,'line'));

            % ---------- 04 ----------
            f=figure('Visible','off','Position',[100,100,1300,850]); ax=axes(f); box(ax,'on'); fmtax(ax,FS_AX,LW_AX);
            b=bar(ax,temperatures,coalescence_eff); b.FaceColor='flat';
            for i=1:num_cases_D, b.CData(i,:)=results_s{i}.color; end
            xlabel(ax,'Temperature (K)'); ylabel(ax,'Coalescence efficiency (%)'); title(ax,['04 Coalescence efficiency vs T' cap_suffix]); ylim(ax,[0,100]); grid(ax,'on');
            save_plot_both(f,out_mode,'04_CoalescenceEfficiency');
            export_plot_csv_xlsx(out_mode,'04_CoalescenceEfficiency',['04 Coalescence efficiency vs T' cap_suffix], ...
                'Temperature (K)','Coalescence efficiency (%)',regime,mkseries('all_temperatures',temperatures,coalescence_eff,'bar'));

            % ---------- 06 ----------
            vr=ripening_rate>0;
            f=figure('Visible','off','Position',[100,100,1300,850]); ax=axes(f); box(ax,'on'); fmtax(ax,FS_AX,LW_AX);
            if any(vr)
                plot(ax,temperatures(vr),ripening_rate(vr),'d-','Color',[0.5,0.2,0.8],'LineWidth',LW_CRV,'MarkerFaceColor',[0.8,0.6,1.0],'MarkerSize',12);
            end
            xlabel(ax,'Temperature (K)'); ylabel(ax,'Average rate (particles/t)'); title(ax,['06 Coarsening rate vs T' cap_suffix]); grid(ax,'on');
            save_plot_both(f,out_mode,'06_RipeningRate_vs_Temperature');
            export_plot_csv_xlsx(out_mode,'06_RipeningRate_vs_Temperature',['06 Coarsening rate vs T' cap_suffix], ...
                'Temperature (K)','Average rate (particles/t)',regime,mkseries('valid_temperatures',temperatures(vr),ripening_rate(vr),'line'));

            % ---------- 10 ----------
            f=figure('Visible','off','Position',[100,100,1500,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX);
            series=initseries();
            for i=1:num_cases_D
                t=results_s{i}.times; R=R_display_all{i};
                valid=(t>=stage_bounds(3))&(t<=stage_bounds(4))&isfinite(R)&(R>0); x=t(valid); y=R(valid);
                if numel(x)<6, continue; end
                pll=polyfit(log(x),log(y),1); nfit=pll(1); Cfit=exp(pll(2));
                xf=logspace(log10(min(x)),log10(max(x)),200); yf=Cfit*xf.^nfit;
                loglog(ax,x,y,'o','Color',results_s{i}.color,'MarkerFaceColor',results_s{i}.color,'MarkerSize',5,'HandleVisibility','off');
                loglog(ax,xf,yf,'-','Color',results_s{i}.color,'LineWidth',LW_CRV,'DisplayName',sprintf('T=%d K, n=%.3f',results_s{i}.T,nfit));
                series(end+1)=mkseries(sprintf('T=%d K',results_s{i}.T),x,y,'scatter');
            end
            xlabel(ax,'Time (t)'); ylabel(ax,'r_{eff}'); title(ax,['10 Stage-3 loglog radius' cap_suffix]); legend(ax,'Location','best'); grid(ax,'on');
            save_plot_both(f,out_mode,'10_Radius_LogLog_Stage3');
            if ~isempty(series), export_plot_csv_xlsx(out_mode,'10_Radius_LogLog_Stage3',['10 Stage-3 loglog radius' cap_suffix],'Time (t)','r_eff',regime,series); end

            % ---------- 11 ----------
            f=figure('Visible','off','Position',[100,100,1500,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX);
            series=initseries();
            for i=1:num_cases_D
                plot(ax,results_s{i}.times,R3_corr_all{i},'Color',results_s{i}.color,'LineWidth',LW_CRV,'DisplayName',sprintf('T=%d K',results_s{i}.T));
                series(end+1)=mkseries(sprintf('T=%d K',results_s{i}.T),results_s{i}.times,R3_corr_all{i},'line');
            end
            xlim(ax,[0 tmax]); add_stages(ax,stage_bounds,stage_names,stage_clrs,ylim(ax),FS_STG);
            xlabel(ax,'Time (t)'); ylabel(ax,'Corrected \Delta r_{eff}^3'); title(ax,['11 Rcubed corrected' cap_suffix]); legend(ax,'Location','best'); grid(ax,'on');
            save_plot_both(f,out_mode,'11_Rcubed_vs_Time');
            export_plot_csv_xlsx(out_mode,'11_Rcubed_vs_Time',['11 Rcubed corrected' cap_suffix],'Time (t)','Corrected Delta r_eff^3',regime,series);

            % ---------- 12A ----------
            f=figure('Visible','off','Position',[100,100,1500,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX);
            series=initseries();
            for i=1:num_cases_D
                t=results_s{i}.times; y3=R3_corr_all{i}; s3=(t>=stage_bounds(3))&(t<=stage_bounds(4))&(y3>0);
                if any(s3), plot(ax,t(s3),y3(s3),'o','Color',results_s{i}.color,'MarkerSize',5,'HandleVisibility','off'); end
                if any(fit_mask_all{i})
                    xf=t(fit_mask_all{i}); yf=y3(fit_mask_all{i}); pf=polyfit(xf,yf,1); xl=linspace(min(xf),max(xf),200);
                    plot(ax,xl,polyval(pf,xl),'-','Color',results_s{i}.color,'LineWidth',LW_CRV,'DisplayName',sprintf('T=%d K K=%.2f',results_s{i}.T,K_late(i)));
                    series(end+1)=mkseries(sprintf('T=%d K',results_s{i}.T),xf,yf,'scatter');
                end
            end
            xlim(ax,[stage_bounds(3),stage_bounds(4)]); xlabel(ax,'Time (t)'); ylabel(ax,'\Delta r_{eff}^3'); title(ax,['12A Stage-3 fit window' cap_suffix]); legend(ax,'Location','best'); grid(ax,'on');
            save_plot_both(f,out_mode,'12A_Rcubed_Stage3FitWindow');
            if ~isempty(series), export_plot_csv_xlsx(out_mode,'12A_Rcubed_Stage3FitWindow',['12A Stage-3 fit window' cap_suffix],'Time (t)','Delta r_eff^3',regime,series); end

            % ---------- 12B ----------
            f=figure('Visible','off','Position',[100,100,1500,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX);
            add_stages(ax,stage_bounds,stage_names,stage_clrs,[],FS_STG);
            series=initseries();
            for i=1:num_cases_D
                valid=isfinite(R3_corr_all{i});
                plot(ax,results_s{i}.times(valid),R3_corr_all{i}(valid),'-','Color',results_s{i}.color,'LineWidth',LW_CRV,'DisplayName',sprintf('T=%d K',results_s{i}.T));
                series(end+1)=mkseries(sprintf('T=%d K',results_s{i}.T),results_s{i}.times(valid),R3_corr_all{i}(valid),'line');
            end
            xlim(ax,[0 tmax]); xlabel(ax,'Time (t)'); ylabel(ax,'\Delta r_{eff}^3'); title(ax,['12B Full run with stages' cap_suffix]); legend(ax,'Location','best'); grid(ax,'on');
            save_plot_both(f,out_mode,'12B_Rcubed_FullRun_Stages');
            export_plot_csv_xlsx(out_mode,'12B_Rcubed_FullRun_Stages',['12B Full run with stages' cap_suffix],'Time (t)','Delta r_eff^3',regime,series);

            % ---------- 13 ----------
            f=figure('Visible','off','Position',[100,100,1400,900]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX);
            vk=isfinite(K_late)&(K_late>0); x=1./temperatures(vk); y=log(K_late(vk));
            if any(vk), scatter(ax,x,y,150,'filled'); end
            if numel(x)>=2, p=polyfit(x,y,1); xf=linspace(min(x),max(x),200); plot(ax,xf,polyval(p,xf),'-','LineWidth',LW_CRV); end
            xlabel(ax,'1/T (K^{-1})'); ylabel(ax,'ln(K_{late})'); title(ax,['13 Arrhenius lnK' cap_suffix]); grid(ax,'on');
            save_plot_both(f,out_mode,'13_Arrhenius_lnK_vs_invT');
            export_plot_csv_xlsx(out_mode,'13_Arrhenius_lnK_vs_invT',['13 Arrhenius lnK' cap_suffix],'1/T (K^{-1})','ln(K_late)',regime,mkseries('valid_temperatures',x,y,'scatter'));

            % ---------- 14 ----------
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
            save_plot_both(f,out_mode,'14_LocalExponent_vs_Time'); 
            if ~isempty(series), export_plot_csv_xlsx(out_mode,'14_LocalExponent_vs_Time',['14 Local exponent' cap_suffix],'Time (t)','n(t)',regime,series); end

           
            % ---------- 17 ----------
            single_field_plot(results_s,out_mode,'17_Vacancy_Bubble_vs_Time',['17 Vacancy bubble' cap_suffix],'cv_bubble','Time (t)','c_v bubble',regime,FS_AX,LW_AX,LW_CRV);
            % ---------- 18 ----------
            single_field_plot(results_s,out_mode,'18_Vacancy_Matrix_vs_Time',['18 Vacancy matrix' cap_suffix],'cv_matrix','Time (t)','c_v matrix',regime,FS_AX,LW_AX,LW_CRV);
            % ---------- 19 ----------
            single_field_plot(results_s,out_mode,'19_Gas_Bubble_vs_Time',['19 Gas bubble' cap_suffix],'cg_bubble','Time (t)','c_g bubble',regime,FS_AX,LW_AX,LW_CRV);
            % ---------- 20 ----------
            single_field_plot(results_s,out_mode,'20_Gas_Matrix_vs_Time',['20 Gas matrix' cap_suffix],'cg_matrix','Time (t)','c_g matrix',regime,FS_AX,LW_AX,LW_CRV);

            % ---------- 21 ----------
            f=figure('Visible','off','Position',[100,100,1400,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX); series=initseries();
            for i=1:num_cases_D
                t=results_s{i}.times; y=max(results_s{i}.avg_radius,eps).^3;
                plot(ax,t,y,'LineWidth',LW_CRV,'Color',results_s{i}.color,'DisplayName',sprintf('T=%d K',results_s{i}.T));
                series(end+1)=mkseries(sprintf('T=%d K',results_s{i}.T),t,y,'line');
            end
            xlabel(ax,'Time (t)'); ylabel(ax,'r_{eff}^3'); title(ax,['21 Ostwald check r^3' cap_suffix]); legend(ax,'Location','best'); grid(ax,'on');
            save_plot_both(f,out_mode,'21_Rcubed_raw_vs_Time'); export_plot_csv_xlsx(out_mode,'21_Rcubed_raw_vs_Time',['21 Ostwald check r^3' cap_suffix],'Time (t)','r_eff^3',regime,series);

            % ---------- 22 ----------
            f=figure('Visible','off','Position',[100,100,1400,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,FS_AX,LW_AX); series=initseries();
            for i=1:num_cases_D
                mask=results_s{i}.times>=stage_bounds(3); 
                x=max(results_s{i}.avg_radius(mask),eps).^(-3); 
                y=results_s{i}.num_bubbles(mask);
                scatter(ax,x,y,34,results_s{i}.color,'filled','DisplayName',sprintf('T=%d K',results_s{i}.T));
                if numel(x)>=6, p=polyfit(x,y,1); xf=linspace(min(x),max(x),120); plot(ax,xf,polyval(p,xf),'-','Color',results_s{i}.color,'LineWidth',1.8,'HandleVisibility','off'); end
                series(end+1)=mkseries(sprintf('T=%d K',results_s{i}.T),x,y,'scatter');
            end
            xlabel(ax,'r_{eff}^{-3}'); ylabel(ax,'N'); title(ax,['22 LSW consistency N vs r^{-3}' cap_suffix]); legend(ax,'Location','best'); grid(ax,'on');
            save_plot_both(f,out_mode,'22_N_vs_Rminus3'); export_plot_csv_xlsx(out_mode,'22_N_vs_Rminus3',['22 LSW consistency' cap_suffix],'r_eff^{-3}','N',regime,series);

            % ---------- 23 ----------
            single_field_combo(results_s,out_mode,'23_DeltaCv_vs_Time',['23 Mass-transfer driving proxy' cap_suffix], ...
                @(r)(r.cv_bubble-r.cv_matrix),'Time (t)','Delta c_v',regime,FS_AX,LW_AX,LW_CRV);

            % ---------- 24 ----------
            single_field_combo(results_s,out_mode,'24_InterfaceCompactness_vs_Time',['24 Interface compactness' cap_suffix], ...
                @(r)(r.total_perimeter./max(r.total_area,eps)),'Time (t)','P_tot/A_tot',regime,FS_AX,LW_AX,LW_CRV);

            % ---------- 25 NEW ----------
            f=figure('Visible','off','Position',[100,100,1300,850]); ax=axes(f); box(ax,'on'); hold(ax,'on'); fmtax(ax,FS_AX,LW_AX);
            plot(ax,temperatures,stress_factor_curve,'o-','LineWidth',LW_CRV,'MarkerSize',10,'MarkerFaceColor',[0.15 0.45 0.85],'Color',[0.15 0.45 0.85]);
            xlabel(ax,'Temperature (K)'); ylabel(ax,'Stress mobility factor'); title(ax,['25 Stress-factor vs T' cap_suffix]); grid(ax,'on');
            save_plot_both(f,out_mode,'25_StressFactor_vs_T');
            export_plot_csv_xlsx(out_mode,'25_StressFactor_vs_T',['25 Stress-factor vs T' cap_suffix], ...
                'Temperature (K)','Stress factor',regime,mkseries('stress_factor',temperatures,stress_factor_curve,'line'));
        end


        %% ---------- NO_STRESS vs STRESS OVERLAYS ---------- 
        compare_folder = fullfile(out_folder,'PLOTS_NO_STRESS_VS_STRESS');
        if ~isfolder(compare_folder), mkdir(compare_folder); end

        mode_names = cellfun(@(m)m.name, stress_modes, 'UniformOutput', false);
        idx_no = find(strcmp(mode_names,'NO_STRESS'),1);

        if ~isempty(idx_no)

            % C01 Final N vs T
            f=figure('Visible','off','Position',[100,100,1400,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,16,1.8);
            series=initseries();
            for mm=1:num_modes
                y=zeros(1,num_T);
                for it=1:num_T, y(it)=results_D{it,mm}.num_bubbles(end); end
                plot(ax,T_values,y,'-o','LineWidth',2.8,'MarkerSize',9,'DisplayName',stress_modes{mm}.name);
                series(end+1)=mkseries(stress_modes{mm}.name,T_values,y,'line');
            end
            xlabel(ax,'Temperature (K)'); ylabel(ax,'Final number of bubbles');
            title(ax,sprintf('C01 Final N vs T | Regime %s%% | %s',regime,scenario_tag));
            legend(ax,'Location','best'); grid(ax,'on');
            save_plot_both(f,compare_folder,'C01_FinalN_vs_T_NO_STRESS_vs_STRESS');
            export_plot_csv_xlsx(compare_folder,'C01_FinalN_vs_T_NO_STRESS_vs_STRESS', ...
                sprintf('C01 Final N vs T | Regime %s%% | %s',regime,scenario_tag),'Temperature (K)','Final N',regime,series);

            % C02 Final Reff vs T
            f=figure('Visible','off','Position',[100,100,1400,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,16,1.8);
            series=initseries();
            for mm=1:num_modes
                y=zeros(1,num_T);
                for it=1:num_T, y(it)=results_D{it,mm}.avg_radius(end); end
                plot(ax,T_values,y,'-s','LineWidth',2.8,'MarkerSize',9,'DisplayName',stress_modes{mm}.name);
                series(end+1)=mkseries(stress_modes{mm}.name,T_values,y,'line');
            end
            xlabel(ax,'Temperature (K)'); ylabel(ax,'Final r_{eff}');
            title(ax,sprintf('C02 Final Reff vs T | Regime %s%% | %s',regime,scenario_tag));
            legend(ax,'Location','best'); grid(ax,'on');
            save_plot_both(f,compare_folder,'C02_FinalReff_vs_T_NO_STRESS_vs_STRESS');
            export_plot_csv_xlsx(compare_folder,'C02_FinalReff_vs_T_NO_STRESS_vs_STRESS', ...
                sprintf('C02 Final Reff vs T | Regime %s%% | %s',regime,scenario_tag),'Temperature (K)','Final Reff',regime,series);

            % C03..C08 per temperature
            for it=1:num_T
                T=T_values(it);

                % C03 N(t)
                f=figure('Visible','off','Position',[100,100,1500,900]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,16,1.8);
                series=initseries();
                for mm=1:num_modes
                    r=results_D{it,mm};
                    plot(ax,r.times,r.num_bubbles,'LineWidth',2.8,'DisplayName',r.mode_name);
                    series(end+1)=mkseries(r.mode_name,r.times,r.num_bubbles,'line');
                end
                xlabel(ax,'Time (t)'); ylabel(ax,'Number of bubbles');
                title(ax,sprintf('C03 N(t) compare | T=%d K | Regime %s%% | %s',T,regime,scenario_tag));
                legend(ax,'Location','best'); grid(ax,'on');
                base=sprintf('C03_N_vs_time_T%d_NO_STRESS_vs_STRESS',T);
                save_plot_both(f,compare_folder,base);
                export_plot_csv_xlsx(compare_folder,base,sprintf('C03 N(t) compare | T=%d K | Regime %s%% | %s',T,regime,scenario_tag),'Time (t)','Number of bubbles',regime,series);

                % C04 Reff(t)
                f=figure('Visible','off','Position',[100,100,1500,900]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,16,1.8);
                series=initseries();
                for mm=1:num_modes
                    r=results_D{it,mm};
                    plot(ax,r.times,r.avg_radius,'LineWidth',2.8,'DisplayName',r.mode_name);
                    series(end+1)=mkseries(r.mode_name,r.times,r.avg_radius,'line');
                end
                xlabel(ax,'Time (t)'); ylabel(ax,'r_{eff}');
                title(ax,sprintf('C04 Reff(t) compare | T=%d K | Regime %s%% | %s',T,regime,scenario_tag));
                legend(ax,'Location','best'); grid(ax,'on');
                base=sprintf('C04_Reff_vs_time_T%d_NO_STRESS_vs_STRESS',T);
                save_plot_both(f,compare_folder,base);
                export_plot_csv_xlsx(compare_folder,base,sprintf('C04 Reff(t) compare | T=%d K | Regime %s%% | %s',T,regime,scenario_tag),'Time (t)','r_eff',regime,series);

        % C07 Delta Reff^3
        f=figure('Visible','off','Position',[100,100,1500,900]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,16,1.8);
        series=initseries();
        for mm=1:num_modes
            r=results_D{it,mm};
            y=max(r.avg_radius.^3 - r.avg_radius(1)^3, 0);
            plot(ax,r.times,y,'LineWidth',2.8,'DisplayName',r.mode_name);
            series(end+1)=mkseries(r.mode_name,r.times,y,'line');
        end
        xlabel(ax,'Time (t)'); ylabel(ax,'\Delta r_{eff}^3');
        title(ax,sprintf('C07 Delta Reff^3 compare | T=%d K | Regime %s%% | %s',T,regime,scenario_tag));
        legend(ax,'Location','best'); grid(ax,'on');
        base=sprintf('C07_DeltaReff3_vs_time_T%d_NO_STRESS_vs_STRESS',T);
        save_plot_both(f,compare_folder,base);
        export_plot_csv_xlsx(compare_folder,base,sprintf('C07 Delta Reff^3 compare | T=%d K | Regime %s%% | %s',T,regime,scenario_tag),'Time (t)','Delta r_eff^3',regime,series);
    end

    % C08 Arrhenius compare
    f=figure('Visible','off','Position',[100,100,1400,850]); ax=axes(f); hold(ax,'on'); box(ax,'on'); fmtax(ax,16,1.8);
    series=initseries(); cc=0;
    for mm=1:num_modes
        K = metrics(mm).K_late;
        valid = isfinite(K) & (K>0);
        if nnz(valid)<2, continue; end
        x = 1./T_values(valid);
        y = log(K(valid));
        cc=cc+1;
        plot(ax,x,y,'o-','LineWidth',2.8,'MarkerSize',8,'DisplayName',stress_modes{mm}.name);
        series(end+1)=mkseries(stress_modes{mm}.name,x,y,'line');
    end
    xlabel(ax,'1/T (K^{-1})'); ylabel(ax,'ln(K_{late})');
    title(ax,sprintf('C08 Arrhenius compare | Regime %s%% | %s',regime,scenario_tag));
    legend(ax,'Location','best'); grid(ax,'on');
    save_plot_both(f,compare_folder,'C08_Arrhenius_NO_STRESS_vs_STRESS');
    if ~isempty(series)
        export_plot_csv_xlsx(compare_folder,'C08_Arrhenius_NO_STRESS_vs_STRESS', ...
            sprintf('C08 Arrhenius compare | Regime %s%% | %s',regime,scenario_tag), ...
            '1/T (K^-1)','ln(K_late)',regime,series);
    end
end
    end
end