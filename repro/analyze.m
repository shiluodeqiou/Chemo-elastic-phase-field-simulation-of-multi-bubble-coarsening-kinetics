function S = analyze(write_csv)
%ANALYZE  Collect the nine campaign cases, compute the paper's coarsening
%         metrics and compare them with the published values (Table 1,
%         Figs 2-4, 7, 9-12).
%
%   S = analyze()        % print the comparison, no files written
%   S = analyze(true)    % also write repro/results/*.csv

if nargin<1, write_csv = false; end
here  = fileparts(fileparts(which('repro_params')));
addpath(here); addpath(fileparts(which('repro_params')));
P     = repro_params();
rdir  = fullfile(here,'repro','results');
refd  = fullfile(here,'repro','reference');
T_all = P.T_values;  S_all = P.S_levels_GPa;

%% ---------- load ----------
C = struct('T',{},'S',{},'R',{});
for is = 1:numel(S_all)
    for it = 1:numel(T_all)
        tag = sprintf('T%d_S%+.1fGPa', T_all(it), S_all(is));
        f = fullfile(rdir,['case_' tag '.mat']);
        if ~isfile(f), continue; end
        L = load(f); R = L.R;
        C(end+1) = struct('T',T_all(it),'S',S_all(is),'R',R); %#ok<AGROW>
    end
end
if isempty(C)
    fprintf('no results yet in %s\n', rdir); S = []; return
end

%% ---------- metrics ----------
n = numel(C);
M = struct([]);
for k = 1:n
    R = C(k).R;
    t = R.t(:);  r = R.reff(:);  N = R.N(:);
    R3 = max(r.^3 - r(1)^3, 0);
    % late-stage constant, Code.m definition
    mask = (t>=0.35*max(t)) & (t<=0.90*max(t)) & (R3>0);
    if nnz(mask)>=6
        pf = polyfit(t(mask),R3(mask),1);
        yh = polyval(pf,t(mask));
        Kl = max(pf(1),0); R2 = 1-sum((R3(mask)-yh).^2)/max(sum((R3(mask)-mean(R3(mask))).^2),eps);
    else
        Kl = NaN; R2 = NaN;
    end
    % stage-3 power-law exponent
    m3 = (t>=P.stage_bounds(3))&(t<=P.stage_bounds(4))&(r>0);
    nexp = NaN;
    if nnz(m3)>=6, pl = polyfit(log(t(m3)),log(r(m3)),1); nexp = pl(1); end
    M(k).T = C(k).T; M(k).S = C(k).S;
    M(k).FinalN = N(end); M(k).FinalReff = r(end);
    M(k).N0 = N(1); M(k).reff0 = r(1);
    M(k).K_late = Kl; M(k).K_R2 = R2; M(k).n_stage3 = nexp;
    M(k).stress_factor = R.stress_factor; M(k).M_eff = R.M_eff;
    M(k).coalescence_pct = 100*max(N(1)-N(end),0)/max(N(1),1);
    M(k).rate = max(N(1)-N(end),0)/max(t(end)-t(1),eps);
    M(k).mass_err = max(abs(R.mass_err));
    M(k).elapsed_min = R.elapsed_min/60;   % stored in seconds by the runner
    M(k).t = t; M(k).r = r; M(k).N = N; M(k).R = C(k).R;
end
S = M;

%% ---------- published values (Table 1 / Fig. 11) ----------
pN   = struct('c',[146 127 107],'z',[110 96 82],'t',[81 69 61]);       % -2 / 0 / +2 GPa
pRe  = struct('c',[14.87423 16.65071 18.41823], ...
              'z',[18.17539 20.06946 21.84425], ...
              't',[22.33922 24.29461 25.93239]);
pLnK = struct('c',[0.43745 0.80642 1.14419], ...
              'z',[1.09115 1.44699 1.71503], ...
              't',[1.80503 2.03771 2.24591]);

fprintf('\n=========== REPRODUCTION vs PAPER (Table 1 / Fig. 11) ===========\n');
fprintf('%6s %7s | %14s %14s %10s | %14s\n','T(K)','sigma','N_final (sim/paper)','r_eff (sim/paper)','err%','ln K_late (sim/paper)');
fprintf('%s\n', repmat('-',1,88));
for k = 1:n
    if M(k).S<0, kk='c'; elseif M(k).S>0, kk='t'; else, kk='z'; end
    iT = find(T_all==M(k).T,1);
    eN = 100*(M(k).FinalN - pN.(kk)(iT))/pN.(kk)(iT);
    eR = 100*(M(k).FinalReff - pRe.(kk)(iT))/pRe.(kk)(iT);
    lk = log(max(M(k).K_late,eps));
    fprintf('%6d %7.1f | %6d /%6d        %8.3f /%8.3f  %+6.1f | %8.4f /%8.4f\n', ...
        M(k).T, M(k).S, M(k).FinalN, pN.(kk)(iT), M(k).FinalReff, pRe.(kk)(iT), eR, lk, pLnK.(kk)(iT));
end

%% ---------- trajectory comparison (no-stress series) ----------
fprintf('\n--- trajectory check, sigma = 0 (paper: Fig. 2a / Fig. 3a) ---\n');
fprintf('%6s %8s %16s %16s\n','T(K)','t','N sim/paper','r_eff sim/paper');
for it = 1:numel(T_all)
    k = find([M.T]==T_all(it) & [M.S]==0,1);
    if isempty(k), continue; end
    ref = readmatrix(fullfile(refd,'N_vs_t_noStress.csv'));
    refr= readmatrix(fullfile(refd,'r_vs_t_noStress.csv'));
    for tt = [300 900 1800]
        [~,i1] = min(abs(ref(:,1)-tt));  [~,i2] = min(abs(M(k).t-tt));
        [~,j1] = min(abs(refr(:,1)-tt));
        if abs(ref(i1,1)-tt)>20 || abs(M(k).t(i2)-tt)>20, continue; end
        fprintf('%6d %8.0f %7d /%7d  %8.3f /%8.3f\n', T_all(it), tt, M(k).N(i2), ref(i1,2), ...
            M(k).r(i2), refr(j1,2));
    end
end

%% ---------- stress ranking ----------
fprintf('\n--- stress ranking (paper: compressive > none > tensile) ---\n');
for it = 1:numel(T_all)
    v = nan(1,3);
    for is = 1:3
        k = find([M.T]==T_all(it) & [M.S]==S_all(is),1);
        if ~isempty(k), v(is) = M(k).FinalN; end
    end
    fprintf('  T=%4d K : N_final(-2GPa)=%4.0f  N(0)=%4.0f  N(+2GPa)=%4.0f -> monotone: %d\n', ...
        T_all(it), v(1), v(2), v(3), all(diff(v)<0));
end

%% ---------- mass conservation ----------
fprintf('\n--- mass conservation |mean(eta)-mean0|max ---\n');
for k = 1:n
    fprintf('  T=%4d S=%+.0f : %.3e\n', M(k).T, M(k).S, M(k).mass_err);
end

%% ---------- CSV ----------
if write_csv
    o = fullfile(rdir,'summary_cases.csv');
    fid = fopen(o,'w');
    fprintf(fid,'T,S_GPa,stress_factor,M_eff,FinalN,N0,FinalReff,reff0,K_late,K_R2,n_stage3,coalescence_pct,rate,mass_err_max,elapsed_min\n');
    for k = 1:n
        fprintf(fid,'%d,%g,%.6f,%.6f,%d,%d,%.5f,%.5f,%.6g,%.4f,%.4f,%.4f,%.6g,%.3e,%.1f\n', ...
            M(k).T,M(k).S,M(k).stress_factor,M(k).M_eff,M(k).FinalN,M(k).N0, ...
            M(k).FinalReff,M(k).reff0,M(k).K_late,M(k).K_R2,M(k).n_stage3, ...
            M(k).coalescence_pct,M(k).rate,M(k).mass_err,M(k).elapsed_min);
    end
    fclose(fid);
    fprintf('\nwrote %s\n', o);
end
end
