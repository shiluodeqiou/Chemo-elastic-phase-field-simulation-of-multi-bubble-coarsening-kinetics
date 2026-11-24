function check_phi010()
%CHECK_PHI010  Quantify what the shipped phi0 = 0.10 does to the seeds.
%   Runs the released integrator with the released parameters (800 K,
%   residual-free) and records when the bubble population disappears.
root = fileparts(fileparts(which('repro_params')));
addpath(root); addpath(fullfile(root,'repro'));
P = repro_params();
P.phi0 = 0.10;            % the value shipped in Code.m

T = 800; S = 0;
M_T = P.M0*exp(-(P.Q_eV/P.kB_eV)*(1/T - 1/P.T_ref));
sf  = exp(-(-S*1e9*P.V_act_m3)/(P.kB_J*T));
M   = M_T*sf;
N = P.N; dt = P.dt; kappa = P.kappa; A = P.A;

rng(1,'twister');
eta = make_initial_eta_CH_uniform(N,P.phi0,P.num_seeds,P.seed_rad,P.noise_amp);
eta = min(max(eta,1e-6),1-1e-6); m0 = mean(eta(:));
kvec = (2*pi/N)*[0:N/2-1,-N/2:-1]; [kx,ky]=meshgrid(kvec,kvec);
K2=kx.^2+ky.^2; K4=K2.^2; z=zeros(N); den=1+dt*M*kappa*K4;

[~,~,~,reff0] = measure_bubbles_refined_CH(eta,1);
fprintf('phi0=%.2f  M=%.4f  t=0: N=%d r_eff=%.3f max=%.3f\n', ...
    P.phi0, M, P.num_seeds, reff0, max(eta(:)));

t_zero = NaN;
for istep = 1:3000
    [mu_el,~,~,~,~] = elastic_mu_aniso_cubic_2d_allstress(eta,P.C11,P.C12,P.C44, ...
        P.eps0x,P.eps0y,P.eps0xy,P.h_pow,S/P.stress_scale,S/P.stress_scale, ...
        z,z,z,P.mu_scale,kx,ky,P.k2_eps);
    df = 2*A*eta.*(1-eta).*(1-2*eta) + mu_el;
    eh = fft2(eta); eh = (eh - dt*M*K2.*fft2(df))./den;
    eta = real(ifft2(eh)); eta = eta - mean(eta(:)) + m0;
    eta = min(max(eta,1e-6),1-1e-6);
    if mod(istep,100)==0
        [nb,~,~,re] = measure_bubbles_refined_CH(eta,1);
        if nb==0 && isnan(t_zero), t_zero = istep*dt; end
        fprintf('  istep %4d  t=%6.1f  N=%4d  r_eff=%6.3f  max eta=%.3f  min eta=%.3f\n', ...
            istep, istep*dt, nb, re, max(eta(:)), min(eta(:)));
    end
end
fprintf('population extinct at t = %.2f  (%d steps)\n', t_zero, round(t_zero/dt));
end
