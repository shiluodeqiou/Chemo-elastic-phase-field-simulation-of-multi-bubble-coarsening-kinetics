function calib_phi(phi0, sig)
%CALIB_PHI  Evaluate the paper IC generator for a given mean phase fraction
% and seed radius. Targets at t=0: N=300, r_eff=5.9494, P/A=0.33617.
cd(fileparts(fileparts(mfilename('fullpath')))); addpath(pwd);
N=512; num_seeds=300; noise_amp=0.0050;
rng(1,'twister');
eta = make_initial_eta_CH_uniform(N,phi0,num_seeds,sig,noise_amp);
eta = min(max(eta,1e-6),1-1e-6);
[nb,rnum,raw,reff,ta,tp] = measure_bubbles_refined_CH(eta,1.0);
fprintf('phi0=%.3f sig=%.2f N=%3d r_num=%7.4f r_eff=%7.4f Afrac=%.4f P/A=%.4f  mean=%.4f\n', ...
    phi0, sig, nb, rnum, reff, ta/N^2, tp/max(ta,1), mean(eta(:)));
end
