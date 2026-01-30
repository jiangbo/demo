const std = @import("std");

// --- 基础联合体与属性 ---
pub const PropertyEnum = enum {
    string,
    int,
    float,
    bool,
    // color,
    // file,
    // object,
    // class,
};

pub const PropertyValue = union(PropertyEnum) {
    string: []const u8, // 字符串值
    int: i32, // 整数值
    float: f32, // 浮点数值
    bool: bool, // 布尔值
    // color: []const u8, // 颜色值 (#RRGGBB)
    // file: []const u8, // 文件路径
    // object: i32, // 引用物体 ID
    // class: []const u8, // Tiled 1.8+ 类类型
};

pub const Property = struct {
    name: []const u8, // 属性名称
    // propertyType: ?[]const u8 = null, // 自定义类型名 (class使用)
    value: PropertyValue, // 具体的属性值
};

// --- 地图主结构 ---

pub const Map = struct {
    backgroundColor: ?[]const u8 = null, // 背景颜色 (#RRGGBB/AARRGGBB)
    class: ?[]const u8 = null, // 地图类 (1.9+)
    compressionLevel: i32 = -1, // 瓦片数据压缩级别
    height: i32, // 地图高度 (瓦片数)
    hexSideLength: ?i32 = null, // 六边形边长 (像素)
    infinite: bool, // 是否为无限维度地图
    layers: []const Layer, // 图层数组
    nextLayerId: i32, // 下一图层自增 ID
    nextObjectId: i32, // 下一物体自增 ID
    orientation: []const u8, // 地图方向 (orthogonal等)
    parallaxOriginX: f32 = 0, // 视差原点 X (像素)
    parallaxOriginY: f32 = 0, // 视差原点 Y (像素)
    properties: ?[]const Property = null, // 地图自定义属性
    renderOrder: []const u8 = "right-down", // 渲染顺序
    staggerAxis: ?[]const u8 = null, // 交错轴 (x/y)
    staggerIndex: ?[]const u8 = null, // 交错索引 (odd/even)
    tiledVersion: []const u8, // Tiled 工具版本
    tileHeight: i32, // 网格高度 (像素)
    tileSets: []const TileSet, // 关联瓦片集数组
    tileWidth: i32, // 网格宽度 (像素)
    type: []const u8 = "map", // 固定为 "map"
    version: []const u8, // JSON 格式版本
    width: i32, // 地图宽度 (瓦片数)
};

// --- 图层与区块 ---

pub const Layer = struct {
    chunks: ?[]const Chunk = null, // 局部块数组 (无限地图用)
    class: ?[]const u8 = null, // 图层类 (1.9+)
    compression: ?[]const u8 = null, // 压缩算法 (zlib/gzip/zstd)
    data: ?[]u32 = null, // 瓦片 GID 数组 (CSV模式)
    drawOrder: ?[]const u8 = "topdown", // 物体绘制顺序 (topdown/index)
    encoding: ?[]const u8 = "csv", // 编码方式 (csv/base64)
    height: ?i32 = null, // 图层行数
    id: i32, // 图层唯一 ID
    image: ?[]const u8 = null, // 图像路径 (图像层用)
    imageHeight: ?i32 = null, // 图像高度 (像素)
    imageWidth: ?i32 = null, // 图像宽度 (像素)
    layers: ?[]const Layer = null, // 子图层 (组图层用)
    locked: bool = false, // 是否锁定
    name: []const u8, // 图层名称
    objects: ?[]const Object = null, // 物体数组 (物体层用)
    offsetX: f32 = 0, // 水平偏移 (像素)
    offsetY: f32 = 0, // 垂直偏移 (像素)
    opacity: f32 = 1.0, // 透明度 (0-1)
    parallaxX: f32 = 1.0, // 水平视差因子
    parallaxY: f32 = 1.0, // 垂直视差因子
    properties: ?[]const Property = null, // 图层自定义属性
    repeatX: ?bool = null, // X 轴是否重复 (图像层)
    repeatY: ?bool = null, // Y 轴是否重复 (图像层)
    startX: ?i32 = null, // 起始 X 坐标 (无限地图)
    startY: ?i32 = null, // 起始 Y 坐标 (无限地图)
    tintColor: ?[]const u8 = null, // 乘法滤色 (#RRGGBB)
    transparentColor: ?[]const u8 = null, // 透明色 (#RRGGBB)
    type: []const u8, // 层类型 (tilelayer等)
    visible: bool, // 是否可见
    width: ?i32 = null, // 图层列数
    x: i32 = 0, // 水平偏移 (瓦片单位)
    y: i32 = 0, // 垂直偏移 (瓦片单位)
};

pub const Chunk = struct {
    data: []u32, // 块内瓦片 GID 数组
    height: i32, // 块高度 (瓦片)
    width: i32, // 块宽度 (瓦片)
    x: i32, // 块位置 X (瓦片)
    y: i32, // 块位置 Y (瓦片)
};

// --- 物体与文本 ---

pub const Object = struct {
    ellipse: bool = false, // 是否为椭圆
    gid: ?u32 = null, // 关联瓦片 GID (如果是瓦片物体)
    height: f32, // 像素高度
    id: i32, // 物体唯一 ID
    name: []const u8, // 物体名称
    point: bool = false, // 是否为点物体
    polygon: ?[]const Point = null, // 多边形顶点数组
    polyline: ?[]const Point = null, // 折线顶点数组
    properties: ?[]const Property = null, // 物体自定义属性
    rotation: f32, // 顺时针旋转角度
    template: ?[]const u8 = null, // 引用模板路径
    text: ?Text = null, // 文本内容及样式
    type: []const u8, // 物体类/类型 (1.9+)
    visible: bool, // 是否可见
    width: f32, // 像素宽度
    x: f32, // 像素坐标 X
    y: f32, // 像素坐标 Y
};

pub const Text = struct {
    bold: bool = false, // 是否加粗
    color: []const u8 = "#000000", // 文本颜色
    fontFamily: []const u8 = "sans-serif", // 字体族
    halign: []const u8 = "left", // 水平对齐方式
    italic: bool = false, // 是否斜体
    kerning: bool = true, // 是否使用字距调整
    pixelSize: i32 = 16, // 字体像素大小
    strikeout: bool = false, // 是否有删除线
    text: []const u8, // 文本内容
    underline: bool = false, // 是否有下划线
    valign: []const u8 = "top", // 垂直对齐方式
    wrap: bool = false, // 是否自动换行
};

// --- 瓦片集相关 ---

pub const TileSet = struct {
    backgroundColor: ?[]const u8 = null, // 背景颜色
    class: ?[]const u8 = null, // 瓦片集类 (1.9+)
    columns: i32, // 图集列数
    fillMode: []const u8 = "stretch", // 填充模式
    firstGid: u32, // 起始全局 ID
    grid: ?Grid = null, // 网格设置
    image: ?[]const u8 = null, // 源图路径
    imageHeight: ?i32 = null, // 源图高度 (像素)
    imageWidth: ?i32 = null, // 源图宽度 (像素)
    margin: i32, // 像素外边距
    name: []const u8, // 瓦片集名称
    objectAlignment: []const u8 = "unspecified", // 物体对齐方式
    properties: ?[]const Property = null, // 瓦片集属性
    source: ?[]const u8 = null, // 外部文件路径
    spacing: i32, // 瓦片像素间距
    terrains: ?[]const Terrain = null, // 地形定义
    tileCount: i32, // 瓦片总数
    tiledVersion: ?[]const u8 = null, // 保存时的 Tiled 版本
    tileHeight: i32, // 瓦片高度
    tileOffset: ?TileOffset = null, // 渲染偏移
    tileRenderSize: []const u8 = "tile", // 渲染尺寸 (tile/grid)
    tiles: ?[]const TileDefinition = null, // 特殊瓦片定义
    tileWidth: i32, // 瓦片宽度
    transformations: ?Transformations = null, // 变换支持 (翻转/旋转)
    transparentColor: ?[]const u8 = null, // 透明颜色
    type: []const u8 = "tileset", // 类型 (tileset)
    version: ?[]const u8 = null, // 格式版本
    wangSets: ?[]const u8 = null, // Wang 自动铺路集合
};

pub const TileDefinition = struct {
    animation: ?[]const Frame = null, // 动画帧数组
    id: i32, // 局部瓦片 ID
    image: ?[]const u8 = null, // 独立图像路径 (图像集合用)
    imageHeight: ?i32 = null, // 图像高度
    imageWidth: ?i32 = null, // 图像宽度
    x: i32 = 0, // 子矩形 X (像素)
    y: i32 = 0, // 子矩形 Y (像素)
    width: ?i32 = null, // 子矩形宽度
    height: ?i32 = null, // 子矩形高度
    objectGroup: ?Layer = null, // 碰撞形状层
    probability: ?f32 = null, // 随机选中概率
    properties: ?[]const Property = null, // 独立瓦片属性
    terrain: ?[]i32 = null, // 地形索引数组 (旧版)
    type: ?[]const u8 = null, // 瓦片类/类型 (1.9+)
};

// --- 小型组件 ---

pub const Point = struct { x: f32, y: f32 }; // 像素坐标点

pub const Grid = struct {
    height: i32, // 单元格高度
    width: i32, // 单元格宽度
    orientation: []const u8 = "orthogonal", // 网格方向
};

pub const TileOffset = struct {
    x: i32, // 水平像素偏移
    y: i32, // 垂直像素偏移 (正值为下)
};

pub const Frame = struct {
    duration: i32, // 持续毫秒
    tileId: i32, // 局部瓦片 ID
};

pub const Terrain = struct {
    name: []const u8, // 地形名称
    tile: i32, // 展示瓦片 ID
    properties: ?[]const Property = null, // 地形属性
};

pub const Transformations = struct {
    hflip: bool, // 支持水平翻转
    vflip: bool, // 支持垂直翻转
    rotate: bool, // 支持 90 度旋转
    preferUntransformed: bool, // 优先使用原版瓦片
};
