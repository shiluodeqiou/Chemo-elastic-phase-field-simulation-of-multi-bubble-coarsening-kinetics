function R = repro_run_case(T, S_GPa, opt)
%REPRO_RUN_CASE  One (temperature, residual-stress) realisation of the paper.
%
%   R = repro_run_case(T, S_GPa)              % defaults of the released Code.m
%   R = repro_run_case(T, S_GPa, opt)         % opt may override fields of P,
%                                             % e.g. struct('nisteps',20000,
%                                             %            'phi0',0.10,'tag','pilot')
%
%   The integration loop is a line-by-line reproduction of Code.m: the same
%   semi-implicit Fourier scheme, the same elastic solver, the same
%   normalisation and clipping, the same measurement cadence.

if nargin < 3, opt = struct(); end
P = repro_params();
fn = fieldnames(opt);
for i = 1:numel(fn), P.(fn{i}) = opt.(fn{i}); end

tag = sprintf('T%d_S%+.1fGPa', T, S_GPa);
if isfield(P,'tag'), tag = [P.tag '_' tag]; end

here   = fileparts(fileparts(which('repro_params')));
addpath(here);
outdir = fullfile(here,'repro','results');
if ~isfolder(outdir), mkdir(outdir); end
matfile = fullfile(outdir, ['case_' tag '.mat']);
if isfile(matfile) && ~strcmp(getenv('REPRO_FORCE'),'1')
    fprintf('[skip] %s already computed\n', tag);
    R = load(matfile); R = R.R;
    return
end

N = P.N; dx = P.dx; dt = P.dt; kappa = P.kappa; A = P.A;

%% ---------- mobility: thermal Arrhenius factor x stress factor ----------
M_T = P.M0*exp(-(P.Q_eV/P.kB_eV)*(1/T - 1/P.T_ref));
P_case_Pa   = -S_GPa*1e9;                    % sigma>0 (tension) -> P<0
stress_fac  = exp(-(P_case_Pa*P.V_act_m3)/(P.kB_J*T));
M_case      = M_T*stress_fac;

fprintf('=== %s | T=%d K | S=%+.2f GPa ===\n', tag, T, S_GPa);
fprintf('    M(T)=%.6f  stress_factor=%.6f  M_eff=%.6f\n', M_T, stress_fac, M_case);

%% ---------- initial condition ----------
rng(1,'twister');
eta = make_initial_eta_CH_uniform(N, P.phi0, P.num_seeds, P.seed_rad, P.noise_amp);
eta = min(max(eta,1e-6),1-1e-6);
eta_mean0 = mean(eta(:));

[nb0,rnum0,raw0,reff0,ta0,tp0,sr0] = measure_bubbles_refined_CH(eta,dx);
[cvb0,cvm0,cgb0,cgm0]               = compute_phase_averages(eta, 0.02+0.10*eta, 0.01+0.08*eta);
fprintf('    t=0 : N=%d  r_eff=%.4f  r_num=%.4f  P/A=%.4f\n', nb0, reff0, rnum0, tp0/max(ta0,1));

%% ---------- spectral operators ----------
kvec = (2*pi/N)*[0:N/2-1,-N/2:-1];
[kx,ky] = meshgrid(kvec,kvec);
K2 = kx.^2+ky.^2;  K4 = K2.^2;
denCH = 1 + dt*M_case*kappa*K4;      % constant in time
z = zeros(N);

use_gpu = true;
gpu_ok = false;
if use_gpu
    try, g = gpuDevice; gpu_ok = true; fprintf('    GPU: %s\n', g.Name); catch, gpu_ok = false; end
end
if gpu_ok
    eta = gpuArray(eta); kx = gpuArray(kx); ky = gpuArray(ky);
    K2 = gpuArray(K2); K4 = gpuArray(K4); denCH = gpuArray(denCH); z = gpuArray(z);
end

%% ---------- storage ----------
nsnap  = floor(P.nisteps/P.snapint)+1;
nsave  = floor(P.nisteps/P.savestep)+1;
t_a    = nan(1,nsnap);   Nb_a  = nan(1,nsnap);   reff_a = nan(1,nsnap);
rnum_a = nan(1,nsnap);   raw_a = nan(1,nsnap);   vf_a   = nan(1,nsnap);
pa_a   = nan(1,nsnap);   sr_a  = nan(1,nsnap);
cvb_a  = nan(1,nsnap);   cvm_a = nan(1,nsnap);   cgb_a  = nan(1,nsnap);  cgm_a = nan(1,nsnap);
mass_a = nan(1,nsnap);   fel_a = nan(1,nsnap);
sxxm_a = nan(1,nsnap);   syym_a = nan(1,nsnap);  sxym_a = nan(1,nsnap);
sxxr_a = nan(1,nsnap);   syyr_a = nan(1,nsnap);  sxyr_a = nan(1,nsnap);

save_eta_t   = nan(1,nsave);
save_files   = cell(1,nsave);

%% ---------- t = 0 snapshot ----------
eta_c = gather(eta);
[~,fel0,sxx,syy,sxy] = elastic_mu_aniso_cubic_2d_allstress(eta,P.C11,P.C12,P.C44, ...
    P.eps0x,P.eps0y,P.eps0xy,P.h_pow,S_GPa/P.stress_scale,S_GPa/P.stress_scale, ...
    z,z,z,P.mu_scale,kx,ky,P.k2_eps);
idx = 1;
t_a(1)=0; Nb_a(1)=nb0; reff_a(1)=reff0; rnum_a(1)=rnum0; raw_a(1)=raw0;
vf_a(1)=mean(eta_c(:)); pa_a(1)=tp0/max(ta0,1); sr_a(1)=sr0;
cvb_a(1)=cvb0; cvm_a(1)=cvm0; cgb_a(1)=cgb0; cgm_a(1)=cgm0;
mass_a(1)=mean(eta_c(:)); fel_a(1)=mean(gather(fel0(:)));
sxx_c=gather(sxx); syy_c=gather(syy); sxy_c=gather(sxy);
sxxm_a(1)=max(abs(sxx_c(:))); syym_a(1)=max(abs(syy_c(:))); sxym_a(1)=max(abs(sxy_c(:)));
sxxr_a(1)=sqrt(mean(sxx_c(:).^2)); syyr_a(1)=sqrt(mean(syy_c(:).^2)); sxyr_a(1)=sqrt(mean(sxy_c(:).^2));

sdir = fullfile(outdir,'snapshots',tag);
if ~isfolder(sdir), mkdir(sdir); end
f0 = fullfile(sdir,'eta_istep000000.mat');
save(f0,'eta_c','-v7.3'); save_eta_t(1)=0; save_files{1}=f0;

%% ---------- time integration ----------
tstart = tic;
snap = 1; ssave = 1;
for istep = 1:P.nisteps
    if mod(istep,20000)==0 || istep==1
        fprintf('    istep %6d/%6d (%5.1f%%)  t=%7.1f  elapsed %5.1f min\n', ...
            istep,P.nisteps,100*istep/P.nisteps,istep*dt,toc(tstart)/60);
    end

    dfdeta_chem = 2*A*eta.*(1-eta).*(1-2*eta);
    [mu_el,fel,sxx,syy,sxy] = elastic_mu_aniso_cubic_2d_allstress(eta,P.C11,P.C12,P.C44, ...
        P.eps0x,P.eps0y,P.eps0xy,P.h_pow,S_GPa/P.stress_scale,S_GPa/P.stress_scale, ...
        z,z,z,P.mu_scale,kx,ky,P.k2_eps);
    dfdeta = dfdeta_chem + mu_el;

    eta_hat = fft2(eta);
    eta_hat_new = (eta_hat - dt*M_case*K2.*fft2(dfdeta))./denCH;
    eta_hat_new(1,1) = eta_hat(1,1);          % conserve the mean exactly
    eta = real(ifft2(eta_hat_new));
    eta = eta - mean(eta(:)) + eta_mean0;
    eta = min(max(eta,1e-6),1-1e-6);

    cv = 0.02+0.10*eta; cv = min(max(cv,0),0.15);
    cg = 0.01+0.08*eta; cg = min(max(cg,0),0.10);

    if mod(istep,P.snapint)==0
        snap = snap+1;
        eta_c = gather(eta);
        [nb,rnum,raw,reff,ta,tp,sr] = measure_bubbles_refined_CH(eta_c,dx);
        [cvb,cvm,cgb,cgm] = compute_phase_averages(eta_c,gather(cv),gather(cg));
        t_a(snap)=istep*dt; Nb_a(snap)=nb; reff_a(snap)=reff; rnum_a(snap)=rnum;
        raw_a(snap)=raw; vf_a(snap)=mean(eta_c(:)); pa_a(snap)=tp/max(ta,1); sr_a(snap)=sr;
        cvb_a(snap)=cvb; cvm_a(snap)=cvm; cgb_a(snap)=cgb; cgm_a(snap)=cgm;
        mass_a(snap)=mean(eta_c(:)); fel_a(snap)=mean(gather(fel(:)));
        sxx_c=gather(sxx); syy_c=gather(syy); sxy_c=gather(sxy);
        sxxm_a(snap)=max(abs(sxx_c(:))); syym_a(snap)=max(abs(syy_c(:))); sxym_a(snap)=max(abs(sxy_c(:)));
        sxxr_a(snap)=sqrt(mean(sxx_c(:).^2)); syyr_a(snap)=sqrt(mean(syy_c(:).^2)); sxyr_a(snap)=sqrt(mean(sxy_c(:).^2));
    end

    if mod(istep,P.savestep)==0
        ssave = ssave+1;
        f = fullfile(sdir,sprintf('eta_istep%06d.mat',istep));
        eta_c = gather(single(eta));
        save(f,'eta_c','-v7.3');
        save_eta_t(ssave) = istep*dt; save_files{ssave} = f;
    end
end
elapsed = toc(tstart);

%% ---------- final stress field (for the elastic-map panels) ----------
fs = fullfile(sdir,'stress_final.mat');
sxx_c = gather(single(sxx)); syy_c = gather(single(syy)); sxy_c = gather(single(sxy));
eta_c = gather(single(eta));
save(fs,'eta_c','sxx_c','syy_c','sxy_c','-v7.3');

%% ---------- late-stage coarsening constant (Code.m definition) ----------
t = t_a(1:snap); R = max(reff_a(1:snap),eps);
R3 = max(R.^3 - R(1)^3, 0);
mask = (t>=0.35*max(t)) & (t<=0.90*max(t)) & (R3>0);
K_late = NaN; K_R2 = NaN; pfit = [NaN NaN];
if nnz(mask)>=6
    pfit = polyfit(t(mask),R3(mask),1);
    yhat = polyval(pfit,t(mask)); y = R3(mask);
    K_late = max(pfit(1),0);
    K_R2 = 1 - sum((y-yhat).^2)/max(sum((y-mean(y)).^2),eps);
end
% stage-3 power-law exponent
m3 = (t>=P.stage_bounds(3))&(t<=P.stage_bounds(4))&(R>0);
n_exp = NaN;
if nnz(m3)>=6
    pl = polyfit(log(t(m3)),log(R(m3)),1); n_exp = pl(1);
end

R = struct();
R.tag=tag; R.T=T; R.S_GPa=S_GPa; R.M_T=M_T; R.stress_factor=stress_fac; R.M_eff=M_case;
R.t=t; R.N=Nb_a(1:snap); R.reff=reff_a(1:snap); R.r_num=rnum_a(1:snap);
R.r_aw=raw_a(1:snap); R.vf=vf_a(1:snap); R.PA=pa_a(1:snap); R.shape_ratio=sr_a(1:snap);
R.cv_bubble=cvb_a(1:snap); R.cv_matrix=cvm_a(1:snap);
R.cg_bubble=cgb_a(1:snap); R.cg_matrix=cgm_a(1:snap);
R.mass=mass_a(1:snap); R.mass_err=mass_a(1:snap)-eta_mean0; R.fel_mean=fel_a(1:snap);
R.sxx_max=sxxm_a(1:snap); R.syy_max=syym_a(1:snap); R.sxy_max=sxym_a(1:snap);
R.sxx_rms=sxxr_a(1:snap); R.syy_rms=syyr_a(1:snap); R.sxy_rms=sxyr_a(1:snap);
R.N0=nb0; R.reff0=reff0; R.PA0=tp0/max(ta0,1); R.eta_mean0=eta_mean0;
R.K_late=K_late; R.K_R2=K_R2; R.K_fit=pfit; R.n_stage3=n_exp;
R.elapsed_min=elapsed; R.P=P; R.snap_t=save_eta_t(1:ssave); R.snap_files={save_files{1:ssave}};

save(matfile,'R','-v7.3');
fprintf('    DONE %s | %.1f min | N_final=%d r_eff_final=%.3f K_late=%.4g (R2=%.3f) n=%.3f\n', ...
    tag, elapsed/60, R.N(end), R.reff(end), R.K_late, R.K_R2, R.n_stage3);
end
