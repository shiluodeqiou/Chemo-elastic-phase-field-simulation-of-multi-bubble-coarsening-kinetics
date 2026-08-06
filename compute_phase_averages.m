function [cvb,cvm,cgb,cgm]=compute_phase_averages(eta,cv,cg)
BWb=eta>0.5; BWm=~BWb;
if any(BWb(:)), cvb=mean(cv(BWb)); cgb=mean(cg(BWb)); else, cvb=mean(cv(:)); cgb=mean(cg(:)); end
if any(BWm(:)), cvm=mean(cv(BWm)); cgm=mean(cg(BWm)); else, cvm=mean(cv(:)); cgm=mean(cg(:)); end
end