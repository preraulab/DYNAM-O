% topcolorbar(width,height,vgap)
function [c,lab] = topcolorbar_custom(w,h,vgap)
colorbar('off');
axpos=get(gca,'position');
c=colorbar('northoutside','units','normalized');

if nargin<1
w=.2;
end

if nargin<2
h=.01;
end

if nargin<3
vgap=.01;
end

cpos(4)=h;
cpos(3)=w;
cpos(2)=axpos(2)+axpos(4)+vgap;
cpos(1)=axpos(1)+axpos(3)-w;

set(c,'position',cpos);

lab=get(c,'xlabel');
labpos=get(lab,'position');
labpos(2)=1.2*labpos(2);
set(lab,'string','Power','position',labpos);    

