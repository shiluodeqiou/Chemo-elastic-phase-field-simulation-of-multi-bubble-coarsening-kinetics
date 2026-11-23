function calib_one(sig)
%CALIB_ONE  Evaluate the paper IC generator for a single seed radius.
cd(fileparts(fileparts(mfilename('fullpath')))); addpath(pwd);
N=512; phi0=0.10; num_seeds=300; noise_amp=0.0050;
rng(1,'twister');
tic;
eta = make_initial_eta_CH_uniform(N,phi0,num_seeds,sig,noise_amp);
eta = min(max(eta,1e-6),1-1e-6);
[nb,rnum,raw,reff,ta,tp] = measure_bubbles_refined_CH(eta,1.0);
fprintf('sigma=%.2f N=%d r_num=%.4f r_eff=%.4f Afrac=%.4f P/A=%.4f  (%.1fs)\n', ...
    sig, nb, rnum, reff, ta/N^2, tp/max(ta,1), toc);
end
