%%% Plots graphic of watershed merge rule

%ccc

%Generate mesh for simulation
N = 6.0;
x=linspace(-6, 8, 75);
y=x;
[X,Y]=meshgrid(x,y);

%Compute 3 surfaces
%Partially merged
Z{1}=(2000/sqrt(2*pi).*exp(-(X.^2/2)-(Y.^2/2))) + (1600/sqrt(2*pi).*exp(-((X-3).^2/2)-(Y.^2/2)));
%Single peak
Z{2}=(2000/sqrt(2*pi).*exp(-(X.^2/2)-(Y.^2/2)));
%Separate peaks
Z{3}=(2000/sqrt(2*pi).*exp(-(X.^2/2)-(Y.^2/2))) + (2600/sqrt(5*pi).*exp(-((X-5.3).^2/2)-(Y.^2/2)));

%Slices for the region separation
slice_inds = [1.5 .9 2.8];

%Create the figure for the three examples
fh = figure('color','w','units','normalized','position',[ 0.0578    0.4352    0.9094    0.4685]);
ax = figdesign(1,3,'margins', [.025 .025 .025 .025 .00125 .00125]);

for ii = 1:3
    %Grab the surface
    z = Z{ii};
    
    axes(ax(ii))
    hold on
    
    %Slice the surface at the slice point and color blue and green
    ind = find(Y(:,1)>slice_inds(ii),1,'first');
    
    s1=surface(X(:,1:ind),Y(:,1:ind),z(:,1:ind), 'facecolor',[.3 .3 1]);
    s2=surface(X(:,ind:end),Y(:,ind:end),z(:,ind:end), 'facecolor',[.3  1 .3]);
    
    %Create a contour around the bottom
    [c,h] = contour3(X,Y,z,[20 20]);
    r = c(:,2:end);
    set(h(:),'linewidth',1,'edgecolor','k')
       
    %Plot the the boundaries for each region
    inds = r(1,:)<=Y(ind);
    plot3(r(1,inds),r(2,inds),25*ones(size(r(1,inds))),'b','linewidth',5)
    inds = r(1,:)>=Y(ind);
    plot3(r(1,inds),r(2,inds),25*ones(size(r(1,inds))),'color',[0 .6 0],'linewidth',5)
    
    %Plot the joint boundary    
    lh = plot3(X(:,ind),Y(:,ind),z(:,ind)+1,'r','linewidth',6);
    uistack(lh,'top');
    
    %Set the 3d view params
    view(12,20)
    zlim([20 850])
    
    if ii == 2
        xlim([-3 4]);
    else
        xlim([-3 8])
    end
    
    ylim([-4 3])
    
    axis off;
    
    %Set the rendering
    alpha(.6)
    camlight right
    camlight headlight
    camlight headlight
    material dull
    lighting gouraud
end

set(gcf,'renderer','painters');

%% Print if selected
if print_png
    print(fh,'-dpng', '-r600',fullfile( fsave_path, 'PNG','peak_merge_schematic.png'));
end

if print_eps
    print(fh,'-depsc', fullfile(fsave_path, 'EPS', 'peak_merge_schematic.eps'));
end