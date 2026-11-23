function calib_ic()
%CALIB_IC  Scan the seed radius of make_initial_eta_CH_uniform to match the
% paper's t=0 state: N_bubbles = 300 and r_eff = 5.9494 (Fig. 3a / Fig. 10b).
% min_spacing = 5.5*seedradius caps the feasible seed radius at ~5.3 for 300
% seeds in a 512^2 box, so the scan stays below that.
cd(fileparts(fileparts(mfilename('fullpath')))); addpath(pwd);
N=512; phi0=0.10; num_seeds=300; noise_amp=0.0050;
fprintf('%6s %6s %9s %9s %9s %9s\n','sigma','N','r_num','r_eff','A_frac','P/A');
for sr = [2.5 3.0 3.5 4.0 4.2 4.4 4.6 4.8 5.0]
    rng(1,'twister');
    eta = make_initial_eta_CH_uniform(N,phi0,num_seeds,sr,noise_amp);
    eta = min(max(eta,1e-6),1-1e-6);
    [nb,rnum,raw,reff,ta,tp] = measure_bubbles_refined_CH(eta,1.0);
    fprintf('%6.2f %6d %9.4f %9.4f %9.5f %9.5f\n', sr, nb, rnum, reff, ta/N^2, tp/max(ta,1));
end
end
