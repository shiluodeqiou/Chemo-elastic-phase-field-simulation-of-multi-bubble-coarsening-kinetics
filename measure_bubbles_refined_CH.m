function [nb,r_num,r_aw,r_eff,total_area,total_perim,shape_ratio]=measure_bubbles_refined_CH(eta,dx)
BW=eta>0.55; BW=bwareaopen(BW,8,8); CC=bwconncomp(BW,8);
if CC.NumObjects==0, nb=0;r_num=0;r_aw=0;r_eff=0;total_area=0;total_perim=0;shape_ratio=0; return; end
st=regionprops(CC,'Area','Perimeter'); A=[st.Area]; P=[st.Perimeter];
v=(A>0)&(P>0); A=A(v); P=P(v);
if isempty(A), nb=0;r_num=0;r_aw=0;r_eff=0;total_area=0;total_perim=0;shape_ratio=0; return; end
A_m=A*dx^2; P_m=P*dx; r_i=sqrt(A_m/pi);
nb=numel(A); r_num=mean(r_i); r_aw=sum(A_m.*r_i)/max(sum(A_m),eps);
At=sum(A_m); Pt=sum(P_m); r_eff=2*At/max(Pt,eps);
total_area=sum(A); total_perim=sum(P); shape_ratio=total_perim/max(total_area,1);
end