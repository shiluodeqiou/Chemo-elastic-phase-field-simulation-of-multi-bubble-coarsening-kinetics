function t = bench_repro()
%BENCH_REPRO  Time the core Cahn-Hilliard/elastic step at the paper settings.
cd(fileparts(fileparts(mfilename('fullpath'))));
addpath(pwd);

N = 512; dx = 1.0; dt = 0.015;
phi0 = 0.10; num_seeds = 300; seed_radius = 2.5; noise_amp = 0.0050;
kappa = 4.2; A = 1.2;
C11 = 2.33; C12 = C11*(122.0/180.0); C44 = C11*(104.0/180.0);
eps0x = 0.005; eps0y = 0.005; eps0xy = 0.0; h_pow = 2; mu_scale = 3.0;
k2_eps = 1e-14;

rng(1,'twister');
eta = make_initial_eta_CH_uniform(N,phi0,num_seeds,seed_radius,noise_amp);
eta = min(max(eta,1e-6),1-1e-6);

[nb0,rnum0,raw0,reff0,ta0,tp0,sr0] = measure_bubbles_refined_CH(eta,dx);
fprintf('INIT: N_bubbles=%d  r_num=%.4f  r_aw=%.4f  r_eff=%.5f  A_tot=%d P_tot=%d\n', ...
    nb0, rnum0, raw0, reff0, ta0, tp0);

kvec = (2*pi/N)*[0:N/2-1,-N/2:-1];
[kx,ky] = meshgrid(kvec,kvec);
K2 = kx.^2+ky.^2; K4 = K2.^2;

eta = gpuArray(eta); kx = gpuArray(kx); ky = gpuArray(ky); K2 = gpuArray(K2); K4 = gpuArray(K4);
z = zeros(N,'like',eta);
M = 1.0;

% warm-up
for k=1:20
    [mu_el,~,~,~,~] = elastic_mu_aniso_cubic_2d_allstress(eta,C11,C12,C44, ...
        eps0x,eps0y,eps0xy,h_pow,0,0,z,z,z,mu_scale,kx,ky,k2_eps);
    dfdeta = 2*A*eta.*(1-eta).*(1-2*eta) + mu_el;
    eh = fft2(eta);
    eh = (eh - dt*M*K2.*fft2(dfdeta))./(1+dt*M*kappa*K4);
    eh(1,1)=fft2(eta(1,1)*0+0);
    eta = real(ifft2(eh));
    eta = eta-mean(eta(:))+phi0;
    eta = min(max(eta,1e-6),1-1e-6);
end
wait(gpuDevice);

nbench = 200; tic;
for k=1:nbench
    [mu_el,~,~,~,~] = elastic_mu_aniso_cubic_2d_allstress(eta,C11,C12,C44, ...
        eps0x,eps0y,eps0xy,h_pow,0,0,z,z,z,mu_scale,kx,ky,k2_eps);
    dfdeta = 2*A*eta.*(1-eta).*(1-2*eta) + mu_el;
    eh = fft2(eta);
    eh = (eh - dt*M*K2.*fft2(dfdeta))./(1+dt*M*kappa*K4);
    eta = real(ifft2(eh));
    eta = eta-mean(eta(:))+phi0;
    eta = min(max(eta,1e-6),1-1e-6);
end
wait(gpuDevice);
t = toc/nbench;
fprintf('GPU step time = %.3f ms  -> 120000 steps = %.1f min/case\n', t*1e3, t*120000/60);
fprintf('18 cases  -> %.1f h\n', t*120000*18/3600);
end
