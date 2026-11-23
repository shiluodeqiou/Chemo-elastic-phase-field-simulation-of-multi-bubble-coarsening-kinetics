function P = repro_params()
%REPRO_PARAMS  All constants of the paper, taken verbatim from Code.m.
%
%   Grid / integrator
%     512^2 periodic box, dx = 1, dt = 0.015, 120000 steps (t_end = 1800).
%   Thermodynamics
%     f_chem = A eta^2 (1-eta)^2 with A = 1.2, kappa = 4.2.
%   Elasticity (cubic, 2D plane strain reduction, Voigt-Taylor)
%     C11 = 2.33, C12 = 2.33*122/180, C44 = 2.33*104/180  (solver units)
%     eigenstrain eps0* = [0.5%, 0.5%, 0] scaled by h = eta^2
%   Kinetics
%     M(T)     = M0 exp[-(Q/kB)(1/T - 1/900)],  Q = 0.20 eV, M0 = 1
%     M(sigma) = M(T) exp[-P V_act/(kB T)],     P = -sigma, V_act = 0.0037 nm^3
%   Residual biaxial stress levels: -2, 0, +2 GPa  (1 model unit = 77.2 GPa)

P.N          = 512;
P.dx         = 1.0;
P.dt         = 0.015;
P.nisteps    = 120000;
P.snapint    = 400;      % measurement cadence
P.savestep   = 6000;     % field-snapshot cadence
P.T_values   = [800 900 1000];
P.phi0       = 0.50;   % calibrated to the published t=0 state (see REPORT)
P.num_seeds  = 300;
P.seed_rad   = 2.5;
P.noise_amp  = 0.0050;
P.kappa      = 4.2;
P.A          = 1.2;
P.C11        = 2.33;
P.C12        = P.C11*(122.0/180.0);
P.C44        = P.C11*(104.0/180.0);
P.eps0x      = 0.005;
P.eps0y      = 0.005;
P.eps0xy     = 0.0;
P.h_pow      = 2;
P.mu_scale   = 3.0;
P.k2_eps     = 1e-14;
P.M0         = 1.0;
P.T_ref      = 900;
P.Q_eV       = 0.20;
P.kB_eV      = 8.617333262e-5;
P.kB_J       = 1.380649e-23;
P.V_act_nm3  = 0.0037;
P.V_act_m3   = P.V_act_nm3*1e-27;
P.S_levels_GPa = [-2 0 +2];
P.C11_phys_GPa = 180.0;
P.stress_scale = P.C11_phys_GPa/P.C11;   % 77.25 GPa per model unit
P.stage_bounds = [0 250 800 1400 2000];
P.stage_names  = {'Stage 1: early separation','Stage 2: droplet selection', ...
                  'Stage 3: Ostwald ripening','Stage 4: late coarsening'};
% image scale used for rho_Fe in the snapshot helper (cosmetic only)
P.M_Fe   = 55.845e-3; P.N_A = 6.02214076e23; P.a_Fe = 2.884e-10;
P.rho_Fe_mass = (2*P.M_Fe/P.N_A)/P.a_Fe^3;
end
