function export_plot_csv_xlsx(out_folder, base_name, plot_title, x_label, y_label, regime, series)
%EXPORT_PLOT_CSV_XLSX Safe CSV/XLSX export for plot data
%
% Inputs:
%   out_folder  : output folder
%   base_name   : file base name, e.g. '01_BubbleCount_vs_Time'
%   plot_title  : title text
%   x_label     : x-axis label
%   y_label     : y-axis label
%   regime      : regime number/string
%   series      : struct array from initseries/mkseries

if nargin < 7
    error('export_plot_csv_xlsx requires 7 inputs.');
end

if ~exist(out_folder, 'dir')
    mkdir(out_folder);
end

csv_file  = fullfile(out_folder, [base_name '.csv']);
xlsx_file = fullfile(out_folder, [base_name '.xlsx']);

if isempty(series)
    warning('No rows to export for %s', base_name);
    return;
end

rows = {};
rowid = 0;

for k = 1:numel(series)
    sk = series(k);

    if ~isfield(sk,'x') || ~isfield(sk,'y') || isempty(sk.x) || isempty(sk.y)
        continue;
    end

    x = sk.x;
    y = sk.y;

    if iscell(x), x = x{1}; end
    if iscell(y), y = y{1}; end

    x = x(:);
    y = y(:);

    n = min(numel(x), numel(y));
    if n == 0
        continue;
    end

    x = x(1:n);
    y = y(1:n);

    if isfield(sk,'case_label') && ~isempty(sk.case_label)
        case_label = sk.case_label;
    else
        case_label = sprintf('series_%d', k);
    end

    if isstring(case_label)
        case_label = char(case_label);
    end

    if isfield(sk,'series_type') && ~isempty(sk.series_type)
        series_type = sk.series_type;
    else
        series_type = 'line';
    end

    if isstring(series_type)
        series_type = char(series_type);
    end

    for i = 1:n
        rowid = rowid + 1;
        rows(rowid,1:8) = { ...
            char(string(regime)), ...
            char(string(plot_title)), ...
            char(string(case_label)), ...
            char(string(series_type)), ...
            char(string(x_label)), ...
            x(i), ...
            char(string(y_label)), ...
            y(i)};
    end
end

if isempty(rows)
    warning('No rows to export for %s', base_name);
    return;
end

T = cell2table(rows, 'VariableNames', ...
    {'regime','plot_title','case_label','series_type','x_label','x','y_label','y'});

writetable(T, csv_file);

try
    writetable(T, xlsx_file);
catch ME
    warning('Could not write XLSX for %s. CSV written instead. Reason: %s', base_name, ME.message);
end
end