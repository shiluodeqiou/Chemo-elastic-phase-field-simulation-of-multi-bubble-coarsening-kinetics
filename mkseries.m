function s = mkseries(lbl, x, y, stype)
%MKSERIES Create one series entry for export helpers

if nargin < 4 || isempty(stype)
    stype = 'line';
end

if isstring(lbl)
    lbl = char(lbl);
end

x = x(:);
y = y(:);

n = min(numel(x), numel(y));
x = x(1:n);
y = y(1:n);

s = struct( ...
    'case_label', lbl, ...
    'x', {x}, ...
    'y', {y}, ...
    'series_type', stype );
end