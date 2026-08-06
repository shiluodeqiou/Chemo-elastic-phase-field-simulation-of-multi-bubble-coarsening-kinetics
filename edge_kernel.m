function [sxx,syy,sxy] = edge_kernel(X,Y,x0,y0,sgn,A,rc)
x=X-x0; y=Y-y0; r2=x.^2+y.^2+rc^2;
sxx = sgn*A*(-2*x.*y)./(r2.^2);
syy = sgn*A*( 2*x.*y)./(r2.^2);
sxy = sgn*A*(x.^2-y.^2)./(r2.^2);
end