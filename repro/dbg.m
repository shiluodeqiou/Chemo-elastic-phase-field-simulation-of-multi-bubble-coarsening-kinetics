function dbg()
%DBG  Step-by-step diagnostics of the reproduced integrator.
cd(fileparts(fileparts(mfilename('fullpath')))); addpath(pwd);
P = repro_params();
N=P.N; dt=P.dt; kappa=P.kappa; A=P.A;
T=900; S=+2;
M_T = P.M0*exp(-(P.Q_eV/P.kB_eV)*(1/T - 1/P.T_ref));
P_case_Pa=-S*1e9; sf=exp(-(P_case_Pa*P.V_act_m3)/(P.kB_J*T)); M=M_T*sf;
rng(1,'twister');
eta=make_initial_eta_CH_uniform(N,P.phi0,P.num_seeds,P.seed_rad,P.noise_amp);
eta=min(max(eta,1e-6),1-1e-6); m0=mean(eta(:));
kvec=(2*pi/N)*[0:N/2-1,-N/2:-1]; [kx,ky]=meshgrid(kvec,kvec);
K2=kx.^2+ky.^2; K4=K2.^2; z=zeros(N); den=1+dt*M*kappa*K4;
fprintf('m0=%.6f M=%.4f\n',m0,M);
fprintf('%5s %10s %10s %10s %8s %9s %11s\n','step','min','max','mean','N','r_eff','max|mu_el|');
for istep=0:600
  [mu_el,~,~,~,~]=elastic_mu_aniso_cubic_2d_allstress(eta,P.C11,P.C12,P.C44, ...
      P.eps0x,P.eps0y,P.eps0xy,P.h_pow,S/P.stress_scale,S/P.stress_scale,z,z,z,P.mu_scale,kx,ky,P.k2_eps);
  if mod(istep,100)==0
    [nb,~,~,reff]=measure_bubbles_refined_CH(eta,1);
    fprintf('%5d %10.4f %10.4f %10.6f %8d %9.3f %11.3e\n',istep,min(eta(:)),max(eta(:)),mean(eta(:)),nb,reff,max(abs(mu_el(:))));
  end
  df=2*A*eta.*(1-eta).*(1-2*eta)+mu_el;
  eh=fft2(eta); eh0=eh(1,1);
  eh=(eh-dt*M*K2.*fft2(df))./den;
  eta=real(ifft2(eh)); eta=eta-mean(eta(:))+m0; eta=min(max(eta,1e-6),1-1e-6);
end
end
