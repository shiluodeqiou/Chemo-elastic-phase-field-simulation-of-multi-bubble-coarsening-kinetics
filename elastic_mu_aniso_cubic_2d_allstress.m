function [mu_el,f_el,sigxx,sigyy,sigxy] = elastic_mu_aniso_cubic_2d_allstress( ...
    eta,C11,C12,C44,eps0x,eps0y,eps0xy,p,sx_app,sy_app, ...
    sigxx_disl,sigyy_disl,sigxy_disl,mu_scale,kx,ky,k2_eps)

h=eta.^p; dh=p*eta.^(p-1);
exx_star=eps0x*h; eyy_star=eps0y*h; exy_star=eps0xy*h;
k2=kx.^2+ky.^2; mask=(k2>k2_eps);
ExxS=fft2(exx_star); EyyS=fft2(eyy_star); ExyS=fft2(exy_star);
SxxS=C11*ExxS+C12*EyyS;
SyyS=C12*ExxS+C11*EyyS;
SxyS=2*C44*ExyS;
bx=1i*(kx.*SxxS+ky.*SxyS);
by=1i*(kx.*SxyS+ky.*SyyS);
A11=C11*kx.^2+C44*ky.^2;
A22=C44*kx.^2+C11*ky.^2;
A12=(C12+C44)*kx.*ky; A21=A12;
detA=A11.*A22-A12.*A21;
Ux=zeros(size(eta),'like',eta);
Uy=zeros(size(eta),'like',eta);
Ux(mask)=( A22(mask).*bx(mask)-A12(mask).*by(mask) )./max(detA(mask),k2_eps);
Uy(mask)=(-A21(mask).*bx(mask)+A11(mask).*by(mask) )./max(detA(mask),k2_eps);
exx=real(ifft2(1i*kx.*Ux));
eyy=real(ifft2(1i*ky.*Uy));
exy=0.5*real(ifft2(1i*ky.*Ux+1i*kx.*Uy));
exx_e=exx-exx_star; eyy_e=eyy-eyy_star; exy_e=exy-exy_star;
sigxx = C11*exx_e + C12*eyy_e + sx_app + sigxx_disl;
sigyy = C12*exx_e + C11*eyy_e + sy_app + sigyy_disl;
sigxy = 2*C44*exy_e + sigxy_disl;
f_el=0.5*(sigxx.*exx_e+sigyy.*eyy_e+2*sigxy.*exy_e);
dexx=eps0x*dh; deyy=eps0y*dh; dexy=eps0xy*dh;
mu_el=mu_scale*(-(sigxx.*dexx + sigyy.*deyy + 2*sigxy.*dexy));
end