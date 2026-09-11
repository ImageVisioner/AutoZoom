% 圆形 / 矩形局部放大：每次自行选择形状，双击确认，可连续添加多个区域。
% 需要 Image Processing Toolbox（drawcircle、drawrectangle、imshow）。
% 直接运行；关闭选区窗口或删除当前选区可取消操作。

%% 可修改参数
scriptFolder = fileparts(mfilename('fullpath'));
images = {'1.png', '2.png', '3.png', '4.png', ...
          '5.png', '6.png', '7.png', '8.png'};
zoomFactor = 3;                 % 放大倍数，必须大于 1
circleColor = [1, 0, 0];        % 圆框颜色，RGB 范围为 0~1
lineWidth = 2;                 % 保存图片中的圆框宽度（像素）
circleLineStyle = '-';         % '-' 实线，'--' 虚线，':' 点线，'-.' 点划线
circleDashLength = 12;         % 虚线中每段线的长度（像素）
circleGapLength = 6;           % 线段之间的间隔（像素）
outputFolder = fullfile(scriptFolder, 'circleZoom');

% 留空时交互选圆；也可填写 [圆心X, 圆心Y, 半径] 以复用选区。
circlePosition = [];
showPreview = true;            % false 可关闭批量结果预览

interactiveSelection = true;   % 默认运行时选择形状、数量和顺序，点击“完成”后导出
% 以下开关和预设坐标仅在 interactiveSelection = false 时使用。
enableCircle = true;
enableRectangle = true;
rectanglePosition = [];        % 留空交互选择，或 [左上角X, 左上角Y, 宽, 高]
rectangleColor = [0, 0.6, 1];   % 矩形框颜色
rectangleLineWidth = 2;         % 矩形框宽度（像素）
rectangleLineStyle = '-';
rectangleDashLength = 12;
rectangleGapLength = 6;
rectangleZoomFactor = 3;        % 矩形放大倍数
backgroundColor = [1, 1, 1];    % 对比图背景颜色

% 每个区域独立设置颜色、线宽和倍数，原图标记与放大图边框使用相同样式。
% 如需更多区域，可复制下面某一条 regions(end+1) 配置。
regions = struct('shape', {}, 'position', {}, 'color', {}, 'lineWidth', {}, ...
    'zoomFactor', {}, 'lineStyle', {}, 'dashLength', {}, 'gapLength', {});
if interactiveSelection || enableCircle
    regions(end+1) = struct('shape', 'circle', 'position', circlePosition, ...
        'color', circleColor, 'lineWidth', lineWidth, 'zoomFactor', zoomFactor, ...
        'lineStyle', circleLineStyle, 'dashLength', circleDashLength, 'gapLength', circleGapLength);
end
if interactiveSelection || enableRectangle
    regions(end+1) = struct('shape', 'rectangle', 'position', rectanglePosition, ...
        'color', rectangleColor, 'lineWidth', rectangleLineWidth, 'zoomFactor', rectangleZoomFactor, ...
        'lineStyle', rectangleLineStyle, 'dashLength', rectangleDashLength, 'gapLength', rectangleGapLength);
end

%% 读取图片，检查是否可以共用同一选区
assert(~isempty(regions), '请至少启用一个选区。');
validateattributes(backgroundColor, {'numeric'}, ...
    {'vector', 'numel', 3, 'real', 'finite', '>=', 0, '<=', 1});
for k = 1:numel(regions)
    validateStyle(regions(k));
    validatestring(regions(k).shape, {'circle', 'rectangle'});
    validateattributes(regions(k).zoomFactor, {'numeric'}, {'scalar', 'real', 'finite', '>', 1});
    validateattributes(regions(k).lineWidth, {'numeric'}, {'scalar', 'real', 'positive', 'finite'});
    validateattributes(regions(k).color, {'numeric'}, ...
        {'vector', 'numel', 3, 'real', 'finite', '>=', 0, '<=', 1});
end
numImages = numel(images);
assert(numImages > 0, '请先设置图像文件列表。');
imageData = cell(1, numImages);
for i = 1:numImages
    % 相对路径以本脚本所在文件夹为基准，也支持绝对路径。
    imagePath = images{i};
    if ~java.io.File(imagePath).isAbsolute()
        imagePath = fullfile(scriptFolder, imagePath);
    end
    [I, map] = imread(imagePath);
    if ~isempty(map)
        I = ind2rgb(I, map);
    else
        I = im2double(I);
    end
    if size(I, 3) == 1
        I = repmat(I, 1, 1, 3);
    end
    if i == 1
        [imageHeight, imageWidth, ~] = size(I);
        assert(min(imageHeight, imageWidth) >= 3, '图像尺寸过小。');
    elseif size(I, 1) ~= imageHeight || size(I, 2) ~= imageWidth
        error('autoZoomCircle:SizeMismatch', ...
            '图片 %s 的尺寸与第一张不同，请先对齐图像。', images{i});
    end
    imageData{i} = I;
end

%% 依次选择区域（已确认的区域会保留在原图上）
selectionFigure = [];
if interactiveSelection || any(arrayfun(@(r) isempty(r.position), regions))
    selectionFigure = figure('Name', '选择圆形和矩形区域', 'NumberTitle', 'off');
    selectionAxes = axes('Parent', selectionFigure);
    selectionPreview = imageData{1};
    selectionImage = imshow(selectionPreview, 'Parent', selectionAxes);
end
if interactiveSelection
    regionDefaults = regions;
    regions = regions([]);
end
k = 1;
while interactiveSelection || k <= numel(regions)
    if interactiveSelection
        if ~isgraphics(selectionFigure), return; end
        choice = questdlg(sprintf('已选择 %d 个区域，请选择下一步：', numel(regions)), ...
            '选择放大区域', '圆形', '矩形', '完成', '完成');
        if isempty(choice)
            % 关闭选择对话框表示取消整个操作，不生成输出。
            if isgraphics(selectionFigure), close(selectionFigure); end
            return;
        elseif strcmp(choice, '完成')
            break;
        end
        if strcmp(choice, '圆形')
            r = regionDefaults(1);
        else
            r = regionDefaults(2);
        end
        r.position = [];
        [r, accepted] = editRegionStyle(r);
        if ~accepted, continue; end  % 取消样式设置，返回形状选择
    else
        r = regions(k);
    end
    if ~isempty(selectionFigure)
        if ~isgraphics(selectionFigure)
            return;
        end
        title(selectionAxes, sprintf('区域 %d：%s，双击确认后可继续添加或完成', ...
            k, r.shape));
        args = {'Color', r.color, 'LineWidth', r.lineWidth};
        if strcmp(r.shape, 'circle')
            if ~isempty(r.position)
                args = [args, {'Center', r.position(1:2), 'Radius', r.position(3)}]; %#ok<AGROW>
            end
            roi = drawcircle(selectionAxes, args{:});
        else
            if ~isempty(r.position)
                args = [args, {'Position', r.position}]; %#ok<AGROW>
            end
            roi = drawrectangle(selectionAxes, args{:});
        end
        if isempty(roi) || ~isvalid(roi) || ~isgraphics(selectionFigure)
            if isgraphics(selectionFigure), close(selectionFigure); end
            return;
        end
        if isempty(r.position)
            wait(roi);
            if ~isgraphics(selectionFigure) || ~isvalid(roi)
                if isgraphics(selectionFigure), close(selectionFigure); end
                return;
            end
            if strcmp(r.shape, 'circle')
                r.position = [roi.Center, roi.Radius];
            else
                r.position = roi.Position;
            end
        end
        roi.InteractionsAllowed = 'none';
        roi.Deletable = false;
    end
    if strcmp(r.shape, 'circle')
        validateattributes(r.position, {'numeric'}, {'vector', 'numel', 3, 'real', 'finite'});
        p = reshape(r.position, 1, []);
        bounds = [p(1:2)-p(3), 2*p(3), 2*p(3)];
    else
        validateattributes(r.position, {'numeric'}, {'vector', 'numel', 4, 'real', 'finite'});
        p = reshape(r.position, 1, []);
        bounds = p;
    end
    if any(bounds(3:4) <= 0) || any(bounds(1:2) < 1) || ...
            bounds(1)+bounds(3) > imageWidth || bounds(2)+bounds(4) > imageHeight
        if interactiveSelection
            delete(roi);
            uiwait(warndlg('区域必须完整位于图像内，且半径或宽高大于零，请重新选择。', ...
                '选区无效', 'modal'));
            continue;
        end
        if isgraphics(selectionFigure), close(selectionFigure); end
        error('autoZoomCircle:InvalidRegion', ...
            '区域 %d 必须完整位于图像内，且半径或宽高大于零。', k);
    end
    r.position = p;
    if ~isempty(selectionFigure) && isgraphics(selectionFigure)
        % ROI 拖动时使用默认实线，确认后用实际导出样式更新预览。
        delete(roi);
        selectionPreview = regionOutline(selectionPreview, r.shape, p, r);
        set(selectionImage, 'CData', selectionPreview);
        drawnow;
    end
    regions(k) = r;
    if interactiveSelection
        defaultIndex = 1 + strcmp(r.shape, 'rectangle');
        regionDefaults(defaultIndex) = r; % 同类型的下一个区域沿用本次样式
    end
    k = k+1;
end
if isgraphics(selectionFigure), close(selectionFigure); end
if isempty(regions)
    fprintf('未选择区域，已退出，未生成文件。\n');
    return;
end

%% 为每个区域建立采样网格，放大图在原图右侧从上到下排列
numRegions = numel(regions);
patches = cell(1, numRegions);
patchHeights = zeros(1, numRegions);
patchWidths = zeros(1, numRegions);
for k = 1:numRegions
    r = regions(k);
    p = r.position;
    if strcmp(r.shape, 'circle')
        radius = p(3)*r.zoomFactor;
        halfSize = ceil(radius);
        [dx, dy] = meshgrid(-halfSize:halfSize);
        a = double(hypot(dx, dy) <= radius);
        sx = p(1) + dx/r.zoomFactor;
        sy = p(2) + dy/r.zoomFactor;
        localPosition = [halfSize+1, halfSize+1, radius];
    else
        % ceil 向上取整到完整输出像素，端点与原选区严格对应。
        w = ceil(p(3)*r.zoomFactor)+1;
        h = ceil(p(4)*r.zoomFactor)+1;
        [sx, sy] = meshgrid(linspace(p(1), p(1)+p(3), w), ...
            linspace(p(2), p(2)+p(4), h));
        a = ones(h, w);
        localPosition = [1, 1, w-1, h-1];
    end
    patches{k} = struct('x', sx, 'y', sy, 'alpha', a, 'position', localPosition);
    [patchHeights(k), patchWidths(k)] = size(a);
end
margin = max(12, ceil(max([regions.lineWidth])*3));
stackHeight = sum(patchHeights) + (numRegions-1)*margin;
canvasHeight = max(imageHeight, stackHeight) + 2*margin;
canvasWidth = imageWidth + max(patchWidths) + 3*margin;
sourceTop = floor((canvasHeight-imageHeight)/2)+1;
zoomLeft = imageWidth + 2*margin + 1;
if ~exist(outputFolder, 'dir'), mkdir(outputFolder); end
if showPreview
    previewFigure = figure('Name', '圆形和矩形局部放大对比', 'NumberTitle', 'off');
    numRows = floor(sqrt(numImages));
    numCols = ceil(numImages/numRows);
end

%% 批量生成对比图、独立局部图和可复用选区参数
for i = 1:numImages
    I = imageData{i};
    annotatedImage = I;
    canvas = repmat(reshape(backgroundColor, 1, 1, 3), canvasHeight, canvasWidth);
    canvas(sourceTop:sourceTop+imageHeight-1, margin+1:margin+imageWidth, :) = I;
    zoomTop = floor((canvasHeight-stackHeight)/2)+1;
    for k = 1:numRegions
        r = regions(k);
        patch = patches{k};
        a = patch.alpha;
        zoomImage = zeros(patchHeights(k), patchWidths(k), 3);
        rows = zoomTop:zoomTop+patchHeights(k)-1;
        cols = zoomLeft:zoomLeft+patchWidths(k)-1;
        for channel = 1:3
            zoomImage(:, :, channel) = interp2(I(:, :, channel), ...
                patch.x, patch.y, 'linear', 0);
            canvas(rows, cols, channel) = zoomImage(:, :, channel).*a + backgroundColor(channel)*(1-a);
        end
        sourcePosition = r.position;
        sourcePosition(1:2) = sourcePosition(1:2) + [margin, sourceTop-1];
        zoomPosition = patch.position;
        zoomPosition(1:2) = zoomPosition(1:2) + [zoomLeft-1, zoomTop-1];
        canvas = regionOutline(canvas, r.shape, sourcePosition, r);
        canvas = regionOutline(canvas, r.shape, zoomPosition, r);
        annotatedImage = regionOutline(annotatedImage, r.shape, r.position, r);
        % 第一处同类型选区沿用 circle_1.png / rectangle_1.png 命名。
        shapeIndex = sum(strcmp({regions(1:k).shape}, r.shape));
        if shapeIndex == 1
            filename = sprintf('%s_%d.png', r.shape, i);
        else
            filename = sprintf('%s_region%d_%d.png', r.shape, shapeIndex, i);
        end
        % 独立局部图保留原始内容，边框只绘制在 figure 对比图上。
        imwrite(zoomImage, fullfile(outputFolder, filename), 'Alpha', a);
        zoomTop = zoomTop + patchHeights(k) + margin;
    end
    imwrite(canvas, fullfile(outputFolder, sprintf('figure_%d.png', i)));
    % 原始尺寸的独立标注图：包含全部选区框，不含右侧放大图和留白。
    imwrite(annotatedImage, fullfile(outputFolder, sprintf('annotated_%d.png', i)));
    if showPreview && isgraphics(previewFigure)
        ax = subplot(numRows, numCols, i, 'Parent', previewFigure);
        imshow(canvas, 'Parent', ax);
        title(ax, images{i}, 'Interpreter', 'none');
    end
end
% regions 保存所有选区坐标、形状及样式；circlePosition 保留旧版兼容字段。
circleIndex = find(strcmp({regions.shape}, 'circle'), 1);
rectangleIndex = find(strcmp({regions.shape}, 'rectangle'), 1);
if ~isempty(circleIndex), circlePosition = regions(circleIndex).position; end
if ~isempty(rectangleIndex), rectanglePosition = regions(rectangleIndex).position; end
save(fullfile(outputFolder, 'selection.mat'), 'regions', 'circlePosition', ...
    'rectanglePosition', 'zoomFactor', 'images', 'backgroundColor');
fprintf('局部放大结果已保存至：%s\n', outputFolder);

function I = regionOutline(I, shape, p, style)
% 抗锯齿边框直接写入像素，保存结果不依赖屏幕分辨率或 getframe。
    width = style.lineWidth;
    color = style.color;
    [x, y] = meshgrid(1:size(I, 2), 1:size(I, 1));
    if strcmp(shape, 'circle')
        distance = abs(hypot(x-p(1), y-p(2))-p(3));
        arc = mod(atan2(y-p(2), x-p(1)), 2*pi)*p(3);
    else
        % 到矩形边界的距离，同时覆盖边内和边外的半线宽。
        qx = abs(x-(p(1)+p(3)/2))-p(3)/2;
        qy = abs(y-(p(2)+p(4)/2))-p(4)/2;
        distance = abs(hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0));
        % 将像素投影到最近的一条边，沿矩形周长连续计算线型相位。
        u = min(max(x-p(1), 0), p(3));
        v = min(max(y-p(2), 0), p(4));
        edgeDistance = cat(3, hypot(x-p(1)-u, y-p(2)), ...
            hypot(x-p(1)-p(3), y-p(2)-v), ...
            hypot(x-p(1)-u, y-p(2)-p(4)), hypot(x-p(1), y-p(2)-v));
        [~, edge] = min(edgeDistance, [], 3);
        arc = u;
        value = p(3)+v; arc(edge == 2) = value(edge == 2);
        value = p(3)+p(4)+p(3)-u; arc(edge == 3) = value(edge == 3);
        value = 2*p(3)+p(4)+p(4)-v; arc(edge == 4) = value(edge == 4);
    end
    coverage = min(1, max(0, width/2+0.5-distance));
    switch style.lineStyle
        case '--'
            ink = mod(arc, style.dashLength+style.gapLength) < style.dashLength;
        case ':'
            ink = mod(arc, width+style.gapLength) < width;
        case '-.'
            phase = mod(arc, style.dashLength+2*style.gapLength+width);
            ink = phase < style.dashLength | ...
                (phase >= style.dashLength+style.gapLength & ...
                 phase < style.dashLength+style.gapLength+width);
        otherwise
            ink = true(size(arc));
    end
    coverage = coverage .* ink;
    for channel = 1:3
        I(:, :, channel) = I(:, :, channel).*(1-coverage) + color(channel).*coverage;
    end
end

function validateStyle(r)
    assert(any(strcmp(r.lineStyle, {'-', '--', ':', '-.'})), ...
        '线型必须是 -、--、: 或 -.');
    validateattributes(r.lineWidth, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    validateattributes(r.dashLength, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    validateattributes(r.gapLength, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    validateattributes(r.zoomFactor, {'numeric'}, {'scalar', 'real', 'finite', '>', 1});
    validateattributes(r.color, {'numeric'}, {'vector', 'numel', 3, 'real', 'finite', '>=', 0, '<=', 1});
end

function [r, accepted] = editRegionStyle(r)
% 每次选区均可调整样式；所有数字按字面解析，不执行输入内容。
    accepted = false;
    defaults = {r.lineStyle, num2str(r.lineWidth), sprintf('%g %g %g', r.color), ...
        num2str(r.dashLength), num2str(r.gapLength), num2str(r.zoomFactor)};
    while true
        answer = inputdlg({'线型：- 实线 / -- 虚线 / : 点线 / -. 点划线', ...
            '线宽（像素，大于 0）', 'RGB 颜色（0~1，例如 1 0 0）', ...
            '虚线段长度（像素，大于 0）', '间隔长度（像素，大于 0）', ...
            '放大倍数（大于 1）'}, '设置当前选区样式', [1, 60], defaults);
        if isempty(answer), return; end
        candidate = r;
        candidate.lineStyle = strtrim(answer{1});
        candidate.lineWidth = str2double(answer{2});
        tokens = regexp(strtrim(answer{3}), '[,，;；\s]+', 'split');
        candidate.color = str2double(tokens);
        candidate.dashLength = str2double(answer{4});
        candidate.gapLength = str2double(answer{5});
        candidate.zoomFactor = str2double(answer{6});
        try
            validateStyle(candidate);
        catch problem
            uiwait(errordlg(problem.message, '样式参数无效', 'modal'));
            defaults = answer;
            continue;
        end
        r = candidate;
        accepted = true;
        return;
    end
end
