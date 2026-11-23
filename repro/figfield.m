function figfield(fname)
%FIGFIELD  Recover the field plotted in a paper .fig and report statistics.
here = fileparts(fileparts(mfilename('fullpath')));
f = fullfile(here,'Chemo_Elastic_Simulation_Data',fname);
h = hgload(f);
fprintf('--- %s\n', fname);
ax = findall(h,'Type','axes');
for k = 1:numel(ax)
    ttl = get(get(ax(k),'Title'),'String');
    if iscell(ttl), ttl = strjoin(ttl,' | '); end
    cl = get(ax(k),'CLim');
    fprintf(' axes %d  title="%s"  CLim=[%.4g %.4g]\n', k, ttl, cl(1), cl(2));
    im = findall(ax(k),'Type','image');
    for j = 1:numel(im)
        C = get(im(j),'CData');
        if size(C,1) < 20, continue; end
        Cc = double(C);
        fprintf('   image %d: %s %s  min=%.4g max=%.4g mean=%.4g\n', ...
            j, mat2str(size(C)), class(C), min(Cc(:)), max(Cc(:)), mean(Cc(:)));
        if ndims(Cc)==3
            for c=1:3
                fprintf('     ch%d mean=%.1f\n', c, mean(mean(Cc(:,:,c))));
            end
        else
            fprintf('     frac>0.55 = %.4f   frac>0.5 = %.4f\n', ...
                mean(Cc(:)>0.55), mean(Cc(:)>0.5));
        end
    end
end
close(h);
end
