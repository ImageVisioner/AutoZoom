clc;
clear all;
close all;

% 图像文件列表
images = {'01-image.png', '02-gt.png', '03-BM3D.png','04-IRCNN.png','05-TV.png','06-DnCnn.png','07-TNRD.png','08-Xformer.png','09-RDDM.png','10-CTNet.png','11-IDTransformer.png','12-Ours.png'}; % 替换为实际的文件路径和名称
numImages = length(images);

% 读取并显示第一张图像，用于交互式定义切割区域
I1 = imread(images{1});
I1 = im2gray(I1); % 转换为灰度图
figure;
imshow(I1);
h = drawrectangle;

% 设定线宽和颜色
h.LineWidth = 2;
h.Color = 'green'; % 设定颜色为绿色

position = customWait(h); % 获取切割区域坐标

% 创建保存目录
figureFolderPath = './figureImage';
if ~exist(figureFolderPath, 'dir')
    mkdir(figureFolderPath)
end

subImagePath = './subImage'; 
if ~exist(subImagePath, 'dir')
    mkdir(subImagePath)
end

energy3dPath = './3dEnergyImages';
if ~exist(energy3dPath, 'dir')
    mkdir(energy3dPath)
end

% 截取各图像的指定区域并存储
croppedImages = cell(1, numImages);
energyHandles = cell(1, numImages); % 存储3D能量图的图形对象

% 创建一个大图用于显示所有3D能量图
energySubplotFig = figure('Name', 'All 3D Energy Plots', 'Position', [100, 100, 1200, 800]);
numRows = floor(sqrt(numImages));
numCols = ceil(numImages / numRows);

for i = 1:numImages
    % 读取并处理图像
    I = imread(images{i});
    I = im2gray(I); % 转换为灰度图
    croppedImage = imcrop(I, position);
    croppedImages{i} = croppedImage;  % 保存裁剪的图片
    
    % 在各图像截取区域显示红框并保存到本地
    figure; 
    imshow(I); 
    hold on;
    rectangle('Position', position, 'EdgeColor', 'green', 'LineWidth', 1);
    set(gcf, 'ToolBar', 'none');
    hold off;
    
    % 保存带红框的图像
    F = getframe(gca);
    figureCropped = F.cdata;
    figureFilename = fullfile(figureFolderPath, sprintf('figure_%d.bmp', i));
    imwrite(figureCropped, figureFilename);
    close(gcf);
    
    % 保存裁剪后的子图像
    subFilename = fullfile(subImagePath, sprintf('crop_%d.bmp', i));
    imwrite(croppedImage, subFilename);
    
    % 生成3D能量图
    [~, energyFig] = plot3DEnergy(I, position);
    energyHandles{i} = energyFig; % 存储图形对象
    
    % 保存3D能量图
    energyFilename = fullfile(energy3dPath, sprintf('energy3d_%d.png', i));
    saveas(energyFig, energyFilename);
    close(energyFig);
    
    % 在当前3D能量图中添加subplot
    figure(energySubplotFig);
    subplot(numRows, numCols, i);
    
    % 重新绘制3D图
    if size(croppedImage, 3) == 3
        Z = double(im2gray(croppedImage));
    else
        Z = double(croppedImage);
    end
    [X, Y] = meshgrid(1:size(croppedImage, 2), 1:size(croppedImage, 1));
    surf(X, Y, Z);
    shading interp;
    colormap jet;
    axis tight;
    caxis([min(Z(:)), max(Z(:))]);
    title(sprintf('Image %d', i), 'Interpreter', 'latex');
    view(3); % 确保是3D视图
end

% 保存所有3D能量图的subplot图
saveas(energySubplotFig, fullfile(energy3dPath, 'all_3d_energies.png'));
close(energySubplotFig);

% 显示所有裁剪图像
figure('Name', 'All Cropped Images');
for i = 1:numImages
    subplot(numRows, numCols, i);
    imshow(croppedImages{i});
    title(['Image ' num2str(i)], 'Interpreter', 'latex');
end

% customWait函数定义
function pos = customWait(hROI)
    l = addlistener(hROI, 'ROIClicked', @(src, evt) clickCallback(src, evt));
    uiwait;
    pos = hROI.Position;
    delete(l);
end

% clickCallback函数定义
function clickCallback(~, evt)
    if strcmp(evt.SelectionType, 'double')
        uiresume;
    end
end

function [croppedImage, energyFig] = plot3DEnergy(I, position)
    % 确保输入图像 I 不为空
    if isempty(I)
        error('输入图像为空，无法进行裁剪');
    end

    % 检查 position 是否有效
    if isempty(position) || position(3) <= 0 || position(4) <= 0
        error('裁剪区域无效，请重新选择');
    end
    
    % 获取图像的尺寸
    [height, width, ~] = size(I);

    % 修正裁剪区域，确保不会超出图像的边界
    x = max(1, position(1));
    y = max(1, position(2));
    w = min(position(3), width - x + 1);
    h = min(position(4), height - y + 1);
    correctedPosition = [x, y, w, h];
    
    % 获取裁剪区域
    croppedImage = imcrop(I, correctedPosition);

    % 检查裁剪后的图像是否为空
    if isempty(croppedImage)
        error('裁剪区域为空，请检查裁剪位置');
    end

    % 将裁剪后的图像转换为灰度图（如果是彩色图像）
    if size(croppedImage, 3) == 3
        Z = double(im2gray(croppedImage));
    else
        Z = double(croppedImage);
    end
    
    % 创建网格，用于绘制 3D 图
    [X, Y] = meshgrid(1:size(croppedImage, 2), 1:size(croppedImage, 1));
    
    % 创建新的图形窗口用于3D能量图
    energyFig = figure('Visible', 'off');
    surf(X, Y, Z);
    shading interp;
    colormap jet;
    colorbar;
    
    % 设置坐标轴和颜色范围
    axis tight;
    caxis([min(Z(:)), max(Z(:))]);
    xlabel('X', 'Interpreter', 'latex');
    ylabel('Y', 'Interpreter', 'latex');
    zlabel('Energy (Intensity)', 'Interpreter', 'latex');
    title('3D Energy Visualization', 'Interpreter', 'latex');
    view(3); % 确保是3D视图
    
    % 使图形窗口可见
    set(energyFig, 'Visible', 'on');
end
