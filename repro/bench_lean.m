function bench_lean()
%BENCH_LEAN  Profiling / optimisation study for the GPU kernel.
% Physics identical to elastic_mu_aniso_cubic_2d_allstress + Code.m update;
% only masked (gather/scatter) GPU ops are replaced by elementwise algebra.
cd(fileparts(fileparts(mfilename('fullpath')))); addpath(pwd);
N=512; dt=0.015; phi0=0.10; kappa=4.2; A=1.2;
C11=2.33; C12=C11*(122/180); C44=C11*(104/180);
eps0x=0.005; eps0y=0.005; eps0xy=0; h_pow=2; mu_scale=3.0; k2_eps=1e-14;
rng(1,'twister');
eta = make_initial_eta_CH_uniform(N,phi0,300,2.5,0.005);
eta = min(max(eta,1e-6),1-1e-6);
kvec=(2*pi/N)*[0:N/2-1,-N/2:-1]; [kx,ky]=meshgrid(kvec,kvec);
K2=kx.^2+ky.^2; K4=K2.^2; z=zeros(N);

g=gpuDevice; fprintf('GPU %s | CC %s\n', g.Name, g.ComputeCapability);
eta=gpuArray(eta); kx=gpuArray(kx); ky=gpuArray(ky); K2=gpuArray(K2); K4=gpuArray(K4);
zg=gpuArray(z); M=1.0;

% ---- precomputed coefficient arrays (identical for every step) ----
denCH = 1+dt*M*kappa*K4;
dtM_K2 = dt*M*K2;
A11 = C11*kx.^2+C44*ky.^2;  A22 = C44*kx.^2+C11*ky.^2;
A12 = (C12+C44)*kx.*ky;
detA = A11.*A22 - A12.*A12;  detA(1,1)=k2_eps;   % k=0 row is zero anyway
invdet = 1./detA;
ikx = 1i*kx; iky = 1i*ky;

% ---------- original function, timing ----------
warm=10;
for k=1:warm
  [mu_el,~,~,~,~]=elastic_mu_aniso_cubic_2d_allstress(eta,C11,C12,C44,eps0x,eps0y,eps0xy,h_pow,0,0,zg,zg,zg,mu_scale,kx,ky,k2_eps);
  dfdeta=2*A*eta.*(1-eta).*(1-2*eta)+mu_el;
  eh=fft2(eta); eh=(eh-dtM_K2.*fft2(dfdeta))./denCH;
  eta=real(ifft2(eh)); eta=eta-mean(eta(:))+phi0; eta=min(max(eta,1e-6),1-1e-6);
end
wait(g); n=50; tic;
for k=1:n
  [mu_el,~,~,~,~]=elastic_mu_aniso_cubic_2d_allstress(eta,C11,C12,C44,eps0x,eps0y,eps0xy,h_pow,0,0,zg,zg,zg,mu_scale,kx,ky,k2_eps);
  dfdeta=2*A*eta.*(1-eta).*(1-2*eta)+mu_el;
  eh=fft2(eta); eh=(eh-dtM_K2.*fft2(dfdeta))./denCH;
  eta=real(ifft2(eh)); eta=eta-mean(eta(:))+phi0; eta=min(max(eta,1e-6),1-1e-6);
end
wait(g); t1=toc/n;

% ---------- lean kernel, timing ----------
h2=eta.^2; dh2=2*eta;
exx_s=eps0x*h2; eyy_s=eps0y*h2; exy_s=eps0xy*h2;
SxxS=C11*fft2(exx_s)+C12*fft2(eyy_s);
SyyS=C12*fft2(exx_s)+C11*fft2(eyy_s);
SxyS=2*C44*fft2(exy_s);
bx=1i*(kx.*SxxS+ky.*SxyS); by=1i*(kx.*SxyS+ky.*SyyS);
Ux=( A22.*bx-A12.*by).*invdet; Uy=(-A12.*bx+A11.*by).*invdet;
exx=real(ifft2(ikx.*Ux)); eyy=real(ifft2(iky.*Uy));
exy=0.5*real(ifft2(iky.*Ux+ikx.*Uy));
exx_e=exx-exx_s; eyy_e=eyy-eyy_s; exy_e=exy-exy_s;
sigxx=C11*exx_e+C12*eyy_e; sigyy=C12*exx_e+C11*eyy_e; sigxy=2*C44*exy_e;
mu_el=mu_scale*(-(sigxx.*(eps0x*dh2)+sigyy.*(eps0y*dh2)+2*sigxy.*(eps0xy*dh2)));
wait(g); tic;
for k=1:n
  h2=eta.^2; dh2=2*eta;
  exx_s=eps0x*h2; eyy_s=eps0y*h2;
  ExxS=fft2(exx_s); EyyS=fft2(eyy_s);
  SxxS=C11*ExxS+C12*EyyS; SyyS=C12*ExxS+C11*EyyS;
  bx=1i*(kx.*SxxS);  by=1i*(ky.*SyyS);
  Ux=A22.*bx.*invdet; Uy=A11.*by.*invdet;
  exx=real(ifft2(ikx.*Ux)); eyy=real(ifft2(iky.*Uy));
  exx_e=exx-exx_s; eyy_e=eyy-eyy_s;
  sigxx=C11*exx_e+C12*eyy_e; sigyy=C12*exx_e+C11*eyy_e;
  mu_el=mu_scale*(-(sigxx.*(eps0x*dh2)+sigyy.*(eps0y*dh2)));
  dfdeta=2*A*eta.*(1-eta).*(1-2*eta)+mu_el;
  eh=fft2(eta); eh=(eh-dtM_K2.*fft2(dfdeta))./denCH;
  eta=real(ifft2(eh)); eta=eta-mean(eta(:))+phi0; eta=min(max(eta,1e-6),1-1e-6);
end
wait(g); t2=toc/n;
fprintf('original : %.2f ms/step  -> %.1f min/case\n', t1*1e3, t1*1.2e5/60);
fprintf('lean     : %.2f ms/step  -> %.1f min/case\n', t2*1e3, t2*1.2e5/60);
fprintf('speedup  : %.2fx  |  9 cases: %.2f h -> %.2f h\n', t1/t2, t1*1.2e5*9/3600, t2*1.2e5*9/3600);
end
