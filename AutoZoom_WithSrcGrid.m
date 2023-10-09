clc 
clear 
close all
% 图像文件列表
%新增保存原图带框与显示功能
images = {'1.jpg', '2.jpg', '3.jpg','4.jpg','5.jpg','6.jpg','7.jpg','8.jpg','9.jpg'}; % 替换为实际的文件路径和名称
numImages = length(images);

% 读取并显示第一张图像，用于交互式定义切割区域
I1 = imread(images{1});
figure;
imshow(I1);
h = drawrectangle;

% 设定线宽和颜色
h.LineWidth = 2;
h.Color = 'r'; % 设定颜色为红色

position = customWait(h); % 获取切割区域坐标clocl;

% 截取各图像的指定区域并存储
croppedImages = cell(1, numImages);
figureFolderPath = './figureImage';  % 替换为你想要的路径
if ~exist(figureFolderPath, 'dir')
    mkdir(figureFolderPath)
end

for i = 1:numImages
    I = imread(images{i});
    croppedImages = imcrop(I, position);
    
    % 在各图像截取区域显示红框并保存到本地
    figure; imshow(I); hold on;
    rectangle('Position',position,...
              'EdgeColor','r',...
              'LineWidth', 2);
    hold off;
    
    % 将图像中带有红框的部分保存到新的文件夹
    % 截取包含红框的部分
    F = getframe(gca);
    figureCropped = F.cdata;
    
    % 将带有红框的图片存入新的文件夹
    figureFilename = fullfile(figureFolderPath, sprintf('figure_%d.jpg', i));
    imwrite(figureCropped, figureFilename);
    close(gcf);  % 关闭当前图形窗口
end

% 计算子图行和列的数量
numRows = floor(sqrt(numImages));
numCols = ceil(numImages / numRows);

% 各截取图像并排显示
figure;
for i = 1:numImages
    subplot(numRows, numCols, i);
    imshow(croppedImages{i});
    title(['Method ' num2str(i)]);
end

% 创建一个新的文件夹来存储剪切后的图片
newFolderPath = './subImage';  % 替换为你想要的路径
if ~exist(newFolderPath, 'dir')
    mkdir(newFolderPath)
end

% 将剪切后的图片存入新的文件夹
for i = 1 : numImages
    newFilename = fullfile(newFolderPath, ['crop_' num2str(i) '.jpg']);
    imwrite(croppedImages{i}, newFilename);
end

% customWait函数定义
function pos = customWait(hROI)
    l = addlistener(hROI,'ROIClicked',@(src, evt)clickCallback(src, evt));
    uiwait;
    pos = hROI.Position;
    delete(l);
end

% clickCallback函数定义
function clickCallback(~, evt)
    if strcmp(evt.SelectionType,'double')
        uiresume;
    end
end