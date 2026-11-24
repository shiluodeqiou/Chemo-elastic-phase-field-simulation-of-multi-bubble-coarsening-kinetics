% Startup for the chemo-elastic multi-bubble coarsening project.
% Configures the working directory and the search path of the current MATLAB
% session only; the upstream sources are not modified.
%
% NOTE: this file is deliberately ASCII-only. MATLAB picks up the system
% default character set (GBK on zh-CN Windows), so non-ASCII text in a .m file
% is decoded incorrectly and prints as mojibake. Keep all MATLAB sources ASCII;
% the Chinese documentation lives in README.md and repro/REPORT.md.

projectRoot = fileparts(mfilename('fullpath'));
cd(projectRoot);
addpath(projectRoot);
addpath(fullfile(projectRoot,'repro'));

fprintf('Chemo-elastic multi-bubble coarsening project\n');
fprintf('  project root : %s\n', projectRoot);
fprintf('  MATLAB       : %s\n', version);
fprintf('  charset      : %s\n', feature('DefaultCharacterSet'));

requiredFiles = {
    'Code.m'
    'make_initial_eta_CH_uniform.m'
    'elastic_mu_aniso_cubic_2d_allstress.m'
    'measure_bubbles_refined_CH.m'
    'compute_phase_averages.m'
    'savefieldsnapshot_CH.m'
    'save_plot_both.m'
    'export_plot_csv_xlsx.m'
    };

missingFiles = requiredFiles(~cellfun(@(name) isfile(fullfile(projectRoot, name)), requiredFiles));
if isempty(missingFiles)
    fprintf('  core sources : OK\n');
else
    warning('ChemoElastic:MissingFiles', ...
        'Missing core sources: %s', strjoin(missingFiles, ', '));
end

% Helpers called by Code.m; they were absent from the original upload.
optionalHelpers = {'save_stress_maps.m', 'make_default_disl.m', 'make_disl_dipole_stress.m'};
missingHelpers = optionalHelpers(~cellfun(@(name) isfile(fullfile(projectRoot, name)), optionalHelpers));
if isempty(missingHelpers)
    fprintf('  Code.m helpers: OK\n');
else
    fprintf('  Code.m helpers missing: %s\n', strjoin(missingHelpers, ', '));
end

fprintf('  entry point  : Code.m (full campaign) or repro/run_all.m (reproduction)\n');
