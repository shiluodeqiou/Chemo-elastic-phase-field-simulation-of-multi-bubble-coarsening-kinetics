function probe_all_figs()
%PROBE_ALL_FIGS  Recover every plotted microstructure field in the paper's
%.fig files and characterise it with the paper's own metrics.
here = fileparts(fileparts(mfilename('fullpath')));
addpath(here); addpath(fileparts(mfilename('fullpath')));
d = fullfile(here,'Chemo_Elastic_Simulation_Data');
fs = dir(fullfile(d,'*.fig'));
fprintf('%22s %8s %8s %8s %6s %8s %8s %8s\n', ...
        'file','mean','min','max','N','r_eff','r_num','P/A');
for i = 1:numel(fs)
    f = fullfile(d,fs(i).name);
    try
        h = hgload(f);
    catch
        fprintf('%22s  [cannot load]\n', fs(i).name); continue
    end
    ax = findall(h,'Type','axes');
    C = [];
    for k = 1:numel(ax)
        im = findall(ax(k),'Type','image');
        for j = 1:numel(im)
            Cc = get(im(j),'CData');
            if size(Cc,1) >= 100 && size(Cc,2) >= 100 && ndims(Cc)==2
                C = double(Cc); break
            end
        end
        if ~isempty(C), break; end
    end
    if isempty(C)
        fprintf('%22s  [no field]\n', fs(i).name); close(h); continue
    end
    if max(C(:)) <= 1+1e-9 && min(C(:))>=-1e-6
        A = C;                                    % already a normalised field
    else
        A = (C-min(C(:)))/max(max(C(:))-min(C(:)),eps);  % ramp image
    end
    [nb,rnum,raw,reff,ta,tp] = measure_bubbles_refined_CH(A,1.0);
    fprintf('%22s %8.4f %8.4f %8.4f %6d %8.3f %8.3f %8.4f\n', ...
        fs(i).name, mean(A(:)), min(A(:)), max(A(:)), nb, reff, rnum, tp/max(ta,1));
    close(h);
end
end
