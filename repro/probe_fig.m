function probe_fig(fname)
%PROBE_FIG  Inspect a .fig from the paper's data set: recover the plotted
%           image data, its colour limits and hence the phase fraction.
if nargin<1, fname='Fig. 1 (a).fig'; end
here = fileparts(fileparts(mfilename('fullpath')));
f = fullfile(here,'Chemo_Elastic_Simulation_Data',fname);
S = load(f,'-mat');
fn = fieldnames(S);
fprintf('--- %s : %d top-level vars\n', fname, numel(fn));
h = S.(fn{1});
objs = findall(h,'Type','image');
fprintf('image objects: %d\n', numel(objs));
for k=1:numel(objs)
    C = get(objs(k),'CData');
    fprintf(' image %d: size %s class %s  min=%.4g max=%.4g  clim=[%.4g %.4g]\n', ...
        k, mat2str(size(C)), class(C), min(C(:)), max(C(:)), ...
        min(get(objs(k),'CDataMapping')=='scaled')*0 + 0, 0);
end
ax = findall(h,'Type','axes');
for k=1:numel(ax)
    t = get(ax(k),'Title'); ts = '';
    try, ts = t.String; catch, end
    if iscell(ts), ts = strjoin(ts,' | '); end
    fprintf(' axes %d: title="%s"  CLim=[%s]\n', k, ts, mat2str(get(ax(k),'CLim')));
end
end
