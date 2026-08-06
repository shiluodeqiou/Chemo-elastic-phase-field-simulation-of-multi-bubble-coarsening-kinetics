function eta = make_initial_eta_CH_uniform(N, phi0, numseeds, seedradius, noiseamp)
min_spacing      = 5.5 * seedradius;
max_att_per_cell = 50;
[X, Y] = meshgrid(1:N, 1:N);
eta = 0.03 + 0.01*randn(N,N);
nx     = ceil(sqrt(numseeds));
ny     = ceil(numseeds/nx);
xedges = round(linspace(1, N+1, nx+1));
yedges = round(linspace(1, N+1, ny+1));
pts = zeros(numseeds, 2);
k   = 0;
for iy = 1:ny
    for ix = 1:nx
        if k >= numseeds, break; end
        x1 = xedges(ix); x2 = xedges(ix+1) - 1;
        y1 = yedges(iy); y2 = yedges(iy+1) - 1;

        loX = max(6, min(x1, N-6));
        hiX = min(N-6, max(x2, 6));
        loY = max(6, min(y1, N-6));
        hiY = min(N-6, max(y2, 6));

        if loX > hiX, loX = 6; hiX = N-6; end
        if loY > hiY, loY = 6; hiY = N-6; end
        if loX > hiX || loY > hiY, continue; end

        for att = 1:max_att_per_cell
            x0 = randi([loX, hiX]);
            y0 = randi([loY, hiY]);
            if k == 0
                ok = true;
            else
                d  = sqrt((pts(1:k,1) - x0).^2 + (pts(1:k,2) - y0).^2);
                ok = all(d >= min_spacing);
            end
            if ok
                k = k + 1;
                pts(k,:) = [x0, y0];
                break;
            end
        end
    end
end

while k < numseeds
    x0 = randi([6, N-6]);
    y0 = randi([6, N-6]);
    if k == 0
        ok = true;
    else
        d  = sqrt((pts(1:k,1) - x0).^2 + (pts(1:k,2) - y0).^2);
        ok = all(d >= min_spacing);
    end
    if ok
        k = k + 1;
        pts(k,:) = [x0, y0];
    end
end

pts = pts(1:k, :);
pts = pts(randperm(size(pts,1)), :);
for i = 1:size(pts,1)
    x0  = pts(i,1);
    y0  = pts(i,2);
    g   = exp(-((X - x0).^2 + (Y - y0).^2) / (2 * seedradius^2));
    eta = eta + 0.88 * g;
end
eta = eta + noiseamp * randn(N,N);
eta = eta - mean(eta(:)) + phi0;
eta = min(max(eta, 0), 1);
end