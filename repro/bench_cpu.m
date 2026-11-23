function bench_cpu()
%BENCH_CPU  CPU version of the same core step, for speed comparison.
cd(fileparts(fileparts(mfilename('fullpath')))); addpath(pwd);
N=512; dt=0.015; phi0=0.10; kappa=4.2; A=1.2;
C11=2.33; C12=C11*(122/180); C44=C11*(104/180);
eps0x=0.005; eps0y=0.005; eps0xy=0; h_pow=2; mu_scale=3.0; k2_eps=1e-14;
rng(1,'twister');
eta = make_initial_eta_CH_uniform(N,phi0,300,2.5,0.005);
eta = min(max(eta,1e-6),1-1e-6);
kvec=(2*pi/N)*[0:N/2-1,-N/2:-1]; [kx,ky]=meshgrid(kvec,kvec);
K2=kx.^2+ky.^2; K4=K2.^2; z=zeros(N); M=1.0;
fprintf('CPU threads = %d\n', maxNumCompThreads);
for k=1:10
  [mu_el,~,~,~,~]=elastic_mu_aniso_cubic_2d_allstress(eta,C11,C12,C44,eps0x,eps0y,eps0xy,h_pow,0,0,z,z,z,mu_scale,kx,ky,k2_eps);
  dfdeta=2*A*eta.*(1-eta).*(1-2*eta)+mu_el;
  eh=fft2(eta); eh=(eh-dt*M*K2.*fft2(dfdeta))./(1+dt*M*kappa*K4);
  eta=real(ifft2(eh)); eta=eta-mean(eta(:))+phi0; eta=min(max(eta,1e-6),1-1e-6);
end
nb=100; tic;
for k=1:nb
  [mu_el,~,~,~,~]=elastic_mu_aniso_cubic_2d_allstress(eta,C11,C12,C44,eps0x,eps0y,eps0xy,h_pow,0,0,z,z,z,mu_scale,kx,ky,k2_eps);
  dfdeta=2*A*eta.*(1-eta).*(1-2*eta)+mu_el;
  eh=fft2(eta); eh=(eh-dt*M*K2.*fft2(dfdeta))./(1+dt*M*kappa*K4);
  eta=real(ifft2(eh)); eta=eta-mean(eta(:))+phi0; eta=min(max(eta,1e-6),1-1e-6);
end
t=toc/nb;
fprintf('CPU step = %.3f ms -> 120000 steps = %.1f min/case; 9 cases = %.2f h\n', t*1e3, t*1.2e5/60, t*1.2e5*9/3600);
end
