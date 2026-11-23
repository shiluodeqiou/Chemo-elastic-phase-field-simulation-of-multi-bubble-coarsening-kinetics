function figinfo(fname)
%FIGINFO  Dump the variable structure of a .fig file from the paper data set.
here = fileparts(fileparts(mfilename('fullpath')));
f = fullfile(here,'Chemo_Elastic_Simulation_Data',fname);
fprintf('file exists: %d\n', isfile(f));
S = load(f,'-mat');
fn = fieldnames(S);
fprintf('vars: %s\n', strjoin(fn',', '));
for k=1:numel(fn)
    v = S.(fn{k});
    fprintf('  %s : %s  %s\n', fn{k}, class(v), mat2str(size(v)));
end
end
