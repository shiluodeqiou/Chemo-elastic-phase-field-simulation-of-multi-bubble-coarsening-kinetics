function [sigxx,sigyy,sigxy] = make_disl_dipole_stress(N,disl)
%MAKE_DISL_DIPOLE_STRESS Build the optional dislocation stress maps.
%   An empty configuration gives zero stress. A configured entry is passed
%   through edge_kernel, which is the dislocation kernel shipped with the
%   repository. No dislocation entries are enabled by default.

arguments
    N (1,1) double {mustBeInteger,mustBePositive}
    disl struct
end

[X,Y] = meshgrid(0:N-1,0:N-1);
sigxx = zeros(N,N);
sigyy = zeros(N,N);
sigxy = zeros(N,N);

for k = 1:numel(disl)
    required = {'x0','y0','sgn','A','rc'};
    if ~all(isfield(disl(k),required))
        error('ChemoElastic:InvalidDislocation', ...
            'Each dislocation must contain x0, y0, sgn, A, and rc.');
    end
    [sxx_k,syy_k,sxy_k] = edge_kernel(X,Y,disl(k).x0,disl(k).y0, ...
        disl(k).sgn,disl(k).A,disl(k).rc);
    sigxx = sigxx + sxx_k;
    sigyy = sigyy + syy_k;
    sigxy = sigxy + sxy_k;
end
end
