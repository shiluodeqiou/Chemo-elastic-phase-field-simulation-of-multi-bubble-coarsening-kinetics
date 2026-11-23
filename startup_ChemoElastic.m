% 启动 Chemo-elastic 多泡粗化 MATLAB 项目。
% 本脚本只配置当前 MATLAB 会话的工作目录和搜索路径，不修改上游源码。

projectRoot = fileparts(mfilename('fullpath'));
cd(projectRoot);
addpath(projectRoot);

fprintf('Chemo-elastic 多泡粗化项目\n');
fprintf('项目目录: %s\n', projectRoot);
fprintf('MATLAB: %s\n', version);

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
    fprintf('基础源码文件检查: 通过\n');
else
    warning('ChemoElastic:MissingFiles', ...
        '缺少基础源码文件: %s', strjoin(missingFiles, ', '));
end

% 检查 Code.m 所需的辅助函数。
optionalHelpers = {'save_stress_maps.m', 'make_default_disl.m', 'make_disl_dipole_stress.m'};
missingHelpers = optionalHelpers(~cellfun(@(name) isfile(fullfile(projectRoot, name)), optionalHelpers));
if isempty(missingHelpers)
    fprintf('Code.m 辅助函数检查: 通过\n');
else
    fprintf('Code.m 缺少辅助函数: %s\n', strjoin(missingHelpers, ', '));
end

fprintf('可运行入口: Code.m\n');
