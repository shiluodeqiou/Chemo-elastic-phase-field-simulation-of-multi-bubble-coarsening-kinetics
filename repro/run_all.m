function run_all(varargin)
%RUN_ALL  Full reproduction campaign: 3 temperatures x 3 residual-stress levels.
%
%   The nine (T, sigma) pairs are exactly the distinct configurations that
%   Code.m would execute (Code.m repeats NO_STRESS three times and runs an
%   extra zero-stress RESIDUAL_BIAX case that is identical to NO_STRESS).
%
%   Resumable: rerunning skips cases whose .mat already exists.

here = fileparts(fileparts(which('repro_params')));
addpath(here); addpath(fileparts(which('repro_params')));
P = repro_params();

S_levels = P.S_levels_GPa;          % [-2 0 +2]
T_all    = P.T_values;              % [800 900 1000]

t0 = tic; done = 0; total = numel(S_levels)*numel(T_all);
for is = 1:numel(S_levels)
    for it = 1:numel(T_all)
        done = done + 1;
        fprintf('\n### campaign %d/%d  (T=%d K, sigma=%+d GPa)  [%.1f min elapsed]\n', ...
            done, total, T_all(it), S_levels(is), toc(t0)/60);
        repro_run_case(T_all(it), S_levels(is));
    end
end
fprintf('\n### campaign finished in %.1f min\n', toc(t0)/60);
end
