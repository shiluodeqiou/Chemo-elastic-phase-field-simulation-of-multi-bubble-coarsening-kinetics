function disl = make_default_disl(N)
%MAKE_DEFAULT_DISL Return the optional dislocation configuration.
%   The published Code.m keeps use_disl=false for every default stress mode.
%   The repository does not contain a dislocation parameter definition, so
%   the default configuration is intentionally empty. This preserves the
%   default no-dislocation calculation without inventing physical inputs.

arguments
    N (1,1) double {mustBeInteger,mustBePositive}
end

disl = struct('x0',{},'y0',{},'sgn',{},'A',{},'rc',{});
end
