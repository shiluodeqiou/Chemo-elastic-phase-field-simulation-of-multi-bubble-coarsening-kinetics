function bench_conc(tag)
%BENCH_CONC  Measure per-step time when several MATLAB processes share the GPU.
cd(fileparts(fileparts(mfilename('fullpath')))); addpath(pwd);
N=512; dt=0.015; phi0=0.10; kappa=4.2; A=1.2;
C11=2.33; C12=C11*(122/180); C44=C11*(104/180);
eps0x=0.005; eps0y=0.005; eps0xy=0; h_pow=2; mu_scale=3.0; k2_eps=1e-14;
rng(1,'twister');
eta = make_initial_eta_CH_uniform(N,phi0,300,2.5,0.005);
eta = min(max(eta,1e-6),1-1e-6);
kvec=(2*pi/N)*[0:N/2-1,-N/2:-1]; [kx,ky]=meshgrid(kvec,kvec);
K2=kx.^2+ky.^2; K4=K2.^2; z=zeros(N);
g=gpuDevice; fprintf('[%s] GPU %s\n', tag, g.Name);
eta=gpuArray(eta); kx=gpuArray(kx); ky=gpuArray(ky); K2=gpuArray(K2); K4=gpuArray(K4);
zg=gpuArray(z); M=1.0;
denCH=1+dt*M*kappa*K4; dtM_K2=dt*M*K2;
for k=1:20
  [mu_el,~,~,~,~]=elastic_mu_aniso_cubic_2d_allstress(eta,C11,C12,C44,eps0x,eps0y,eps0xy,h_pow,0,0,zg,zg,zg,mu_scale,kx,ky,k2_eps);
  dfdeta=2*A*eta.*(1-eta).*(1-2*eta)+mu_el;
  eh=fft2(eta); eh=(eh-dtM_K2.*fft2(dfdeta))./denCH;
  eta=real(ifft2(eh)); eta=eta-mean(eta(:))+phi0; eta=min(max(eta,1e-6),1-1e-6);
end
wait(g); n=100; tic;
for k=1:n
  [mu_el,~,~,~,~]=elastic_mu_aniso_cubic_2d_allstress(eta,C11,C12,C44,eps0x,eps0y,eps0xy,h_pow,0,0,zg,zg,zg,mu_scale,kx,ky,k2_eps);
  dfdeta=2*A*eta.*(1-eta).*(1-2*eta)+mu_el;
  eh=fft2(eta); eh=(eh-dtM_K2.*fft2(dfdeta))./denCH;
  eta=real(ifft2(eh)); eta=eta-mean(eta(:))+phi0; eta=min(max(eta,1e-6),1-1e-6);
end
wait(g); t=toc/n;
fprintf('[%s] %.2f ms/step -> %.1f min/case\n', tag, t*1e3, t*1.2e5/60);
end
