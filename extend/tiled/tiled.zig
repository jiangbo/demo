const std = @import("std");

/// Tiled 地图根对象
pub const Map = struct {
    /// 背景颜色，十六进制格式 (#RRGGBB 或 #AARRGGBB) (可选)
    backgroundcolor: ?[]const u8 = null,
    /// 地图的类 (自 1.9 版本起，可选)
    class: ?[]const u8 = null,
    /// 用于瓦片图层数据的压缩级别 (默认 -1，表示使用算法默认值)
    compressionlevel: i32 = -1,
    /// 瓦片行数 (高度)
    height: i32,
    /// 六边形瓦片边长（以像素为单位，仅适用于六边形地图）
    hexsidelength: ?i32 = null,
    /// 地图是否具有无限维度
    infinite: bool,
    /// 图层数组 (包含瓦片层、对象层、组等)
    layers: []Layer,
    /// 每个新图层的自动递增 ID
    nextlayerid: i32,
    /// 每个新放置对象的自动递增 ID
    nextobjectid: i32,
    /// 地图方向 (orthogonal: 正交, isometric: 等轴, staggered: 交错, hexagonal: 六边形)
    orientation: []const u8,
    /// 视差原点的 X 坐标 (以像素为单位，自 1.8 起，默认: 0)
    parallaxoriginx: f32 = 0,
    /// 视差原点的 Y 坐标 (以像素为单位，自 1.8 起，默认: 0)
    parallaxoriginy: f32 = 0,
    /// 自定义属性数组
    properties: ?[]const Property = null,
    /// 渲染顺序 (right-down (默认), right-up, left-down 或 left-up；目前仅支持正交地图)
    renderorder: []const u8 = "right-down",
    /// 交错轴 (x 或 y，仅适用于交错/六边形地图)
    staggeraxis: ?[]const u8 = null,
    /// 交错索引 (odd: 奇数 或 even: 偶数，仅适用于交错/六边形地图)
    staggerindex: ?[]const u8 = null,
    /// 用于保存文件的 Tiled 版本
    tiledversion: []const u8,
    /// 地图网格高度 (像素)
    tileheight: i32,
    /// 关联的瓦片集 (Tileset) 数组
    tilesets: []const Tileset,
    /// 地图网格宽度 (像素)
    tilewidth: i32,
    /// 类型 (固定为 "map"，自 1.0 起)
    type: []const u8 = "map",
    /// JSON 格式版本 (自 1.6 起保存为字符串)
    version: []const u8,
    /// 瓦片列数 (宽度)
    width: i32,
};

// --- 图层与块 ---

/// 图层对象 (涵盖 Tile Layer, Object Layer, Image Layer 和 Group)
pub const Layer = struct {
    /// 块数组 (仅限瓦片图层 tilelayer，用于无限地图)
    chunks: ?[]const Chunk = null,
    /// 图层的类 (自 1.9 起，可选)
    class: ?[]const u8 = null,
    /// 压缩算法 (zlib, gzip, zstd 或空，仅限瓦片图层)
    compression: ?[]const u8 = null,
    /// 瓦片数据 (无符号整数数组 GIDs 或 base64 编码字符串，仅限瓦片图层)
    data: []u32 = &.{},
    /// 物体绘制顺序 (topdown (默认) 或 index，仅限对象层 objectgroup)
    draworder: ?[]const u8 = "topdown",
    /// 数据编码格式 (csv (默认) 或 base64，仅限瓦片图层)
    encoding: ?[]const u8 = "csv",
    /// 行数。对于固定大小地图，与地图高度相同 (仅限瓦片图层)
    height: ?i32 = null,
    /// 唯一的增量 ID，在所有图层中唯一
    id: u32 = 0,
    /// 该图层使用的图像路径 (仅限图像图层 imagelayer)
    image: ?[]const u8 = null,
    /// 图像高度 (像素，仅限图像图层)
    imageheight: ?i32 = null,
    /// 图像宽度 (像素，仅限图像图层)
    imagewidth: ?i32 = null,
    /// 子图层数组 (仅限图层组 group)
    layers: ?[]Layer = null,
    /// 是否在编辑器中被锁定 (自 1.8.2，默认: false)
    locked: bool = false,
    /// 分配给该图层的名称
    name: []const u8,
    /// 物体数组 (仅限对象层 objectgroup)
    objects: []Object = &.{},
    /// 水平图层偏移 (像素，默认: 0)
    offsetx: f32 = 0,
    /// 垂直图层偏移 (像素，默认: 0)
    offsety: f32 = 0,
    /// 透明度值 (0 到 1 之间)
    opacity: f32 = 1.0,
    /// 水平视差因子 (自 1.5，默认: 1)
    parallaxx: f32 = 1.0,
    /// 垂直视差因子 (自 1.5，默认: 1)
    parallaxy: f32 = 1.0,
    /// 自定义属性数组
    properties: ?[]const Property = null,
    /// 图像是否在 X 轴重复 (自 1.8，仅限图像层)
    repeatx: ?bool = null,
    /// 图像是否在 Y 轴重复 (自 1.8，仅限图像层)
    repeaty: ?bool = null,
    /// 图层内容起始 X 坐标 (针对无限地图)
    startx: ?i32 = null,
    /// 图层内容起始 Y 坐标 (针对无限地图)
    starty: ?i32 = null,
    /// 乘法色 (#RRGGBB 或 #AARRGGBB，可选)
    tintcolor: ?[]const u8 = null,
    /// 透明颜色 (#RRGGBB，可选，仅限图像层)
    transparentcolor: ?[]const u8 = null,
    /// 图层类型 (tilelayer, objectgroup, imagelayer 或 group)
    type: []const u8,
    /// 图层在编辑器中是否可见
    visible: bool = true,
    /// 列数。对于固定大小地图，与地图宽度相同 (仅限瓦片图层)
    width: ?i32 = null,
    /// 水平偏移（瓦片单位，始终为 0）
    x: i32 = 0,
    /// 垂直偏移（瓦片单位，始终为 0）
    y: i32 = 0,
};

/// 块对象 (用于存储无限地图的瓦片图层数据)
pub const Chunk = struct {
    /// 瓦片数据 (GIDs 数组或 base64 编码字符串)
    data: std.json.Value,
    /// 以瓦片为单位的高度
    height: i32,
    /// 以瓦片为单位的宽度
    width: i32,
    /// 以瓦片为单位的 X 坐标
    x: i32,
    /// 以瓦片为单位的 Y 坐标
    y: i32,
};

// --- 物体与文本 ---

/// 物体对象 (位于 Object Layer)
pub const Object = struct {
    /// 是否将该物体标记为椭圆
    ellipse: bool = false,
    /// 全局瓦片 ID (GID)，仅当该物体代表一个瓦片时存在
    gid: ?u32 = null,
    /// 以像素为单位的高度
    height: f32,
    /// 唯一的增量 ID
    id: i32,
    /// 物体名称
    name: []const u8,
    /// 是否将该物体标记为点
    point: bool = false,
    /// 坐标点数组 (如果该物体是多边形 polygon)
    polygon: ?[]const Point = null,
    /// 坐标点数组 (如果该物体是折线 polyline)
    polyline: ?[]const Point = null,
    /// 自定义属性数组
    properties: []Property = &.{},
    /// 顺时针旋转角度 (度数)
    rotation: f32,
    /// 模板文件的引用 (如果是模板实例)
    template: ?[]const u8 = null,
    /// 文本属性 (仅适用于文本对象)
    text: ?Text = null,
    /// 物体的类 (自 1.9 起，之前保存为 class)
    type: []const u8,
    /// 物体在编辑器中是否可见
    visible: bool,
    /// 以像素为单位的宽度
    width: f32,
    /// 以像素为单位的 X 坐标
    x: f32,
    /// 以像素为单位的 Y 坐标
    y: f32,
};

/// 文本对象属性
pub const Text = struct {
    /// 是否使用粗体 (默认: false)
    bold: bool = false,
    /// 十六进制格式颜色 (默认: #000000)
    color: []const u8 = "#000000",
    /// 字体族 (默认: sans-serif)
    fontfamily: []const u8 = "sans-serif",
    /// 水平对齐 (center, right, justify 或 left (默认))
    halign: []const u8 = "left",
    /// 是否使用斜体 (默认: false)
    italic: bool = false,
    /// 放置字符时是否使用字距调整 (默认: true)
    kerning: bool = true,
    /// 字体的像素大小 (默认: 16)
    pixelsize: i32 = 16,
    /// 是否带有删除线 (默认: false)
    strikeout: bool = false,
    /// 文本内容
    text: []const u8,
    /// 是否带有下划线 (默认: false)
    underline: bool = false,
    /// 垂直对齐 (center, bottom 或 top (默认))
    valign: []const u8 = "top",
    /// 文本是否在物体范围内换行 (默认: false)
    wrap: bool = false,
};

// --- 瓦片集相关 ---

/// 瓦片集 (Tileset)
pub const Tileset = struct {
    /// 背景颜色 (可选)
    backgroundcolor: ?[]const u8 = null,
    /// 瓦片集的类 (自 1.9 起，可选)
    class: ?[]const u8 = null,
    /// 瓦片集中的列数
    columns: i32 = 0,
    /// 渲染此瓦片集时的填充模式 (stretch (默认) 或 preserve-aspect-fit)
    fillmode: []const u8 = "stretch",
    /// 对应于集合中第一个瓦片的全局 ID (GID)
    firstgid: u32 = 0,
    /// 网格设置 (可选)
    grid: ?Grid = null,
    /// 瓦片集使用的图像路径
    image: ?[]const u8 = null,
    /// 源图像的高度 (像素)
    imageheight: ?i32 = null,
    /// 源图像的宽度 (像素)
    imagewidth: ?i32 = null,
    /// 图像边缘与第一个瓦片之间的间距 (像素)
    margin: i32 = 0,
    /// 瓦片集名称
    name: []const u8 = &.{},
    /// 瓦片物体的对齐方式 (默认 unspecified)
    objectalignment: []const u8 = "unspecified",
    /// 自定义属性数组
    properties: ?[]const Property = null,
    /// 包含此瓦片集数据的外部文件路径
    source: ?[]const u8 = null,
    /// 图像中相邻瓦片之间的间距 (像素)
    spacing: i32 = 0,
    /// 地形定义数组 (可选)
    terrains: ?[]const Terrain = null,
    /// 此瓦片集中的瓦片数量
    tilecount: i32 = 0,
    /// 用于保存文件的 Tiled 版本
    tiledversion: ?[]const u8 = null,
    /// 此集合中瓦片的最大高度
    tileheight: i32 = 0,
    /// 瓦片偏移 (可选)
    tileoffset: ?TileOffset = null,
    /// 渲染瓦片大小时使用的参考 (tile (默认) 或 grid)
    tilerendersize: []const u8 = "tile",
    /// 特殊瓦片定义的数组 (可选)
    tiles: ?[]TileDefinition = null,
    /// 此集合中瓦片的最大宽度
    tilewidth: i32 = 0,
    /// 允许的变换 (可选)
    transformations: ?Transformations = null,
    /// 透明颜色 (#RRGGBB，可选)
    transparentcolor: ?[]const u8 = null,
    /// 类型 (固定为 "tileset")
    type: []const u8 = "tileset",
    /// JSON 格式版本
    version: ?[]const u8 = null,
    /// Wang 集合数组 (自 1.1.5)
    wangsets: ?[]const WangSet = null,
};

/// 瓦片定义 (Tileset 中的具体瓦片特殊设置)
pub const TileDefinition = struct {
    /// 动画帧数组
    animation: ?[]const Frame = null,
    /// 瓦片的局部 ID
    id: u32 = 0,
    /// 代表该瓦片的图像路径 (仅限图像集合瓦片集)
    image: ?[]const u8 = null,
    /// 瓦片图像的高度 (像素)
    imageheight: ?i32 = null,
    /// 瓦片图像的宽度 (像素)
    imagewidth: ?i32 = null,
    /// 代表该瓦片的子矩形的 X 位置 (默认: 0)
    x: i32 = 0,
    /// 代表该瓦片的子矩形的 Y 位置 (默认: 0)
    y: i32 = 0,
    /// 子矩形的宽度 (默认为图像宽度)
    width: ?i32 = null,
    /// 子矩形的高度 (默认为图像高度)
    height: ?i32 = null,
    /// 当指定碰撞形状时，类型为 objectgroup 的图层
    objectgroup: ?Layer = null,
    /// 概率：在编辑器中与其他瓦片竞争时被选中的百分比机会
    probability: ?f32 = null,
    /// 自定义属性数组
    properties: ?[]Property = null,
    /// 瓦片每个角的角点索引 (由 Wang sets 取代)
    terrain: ?[]i32 = null,
    /// 瓦片的类 (自 1.9 起，之前保存为 class)
    type: ?[]const u8 = null,
};

// --- 其他小型组件 ---

/// 网格设置
pub const Grid = struct {
    /// 单元格高度
    height: i32,
    /// 方向 (orthogonal (默认) 或 isometric)
    orientation: []const u8 = "orthogonal",
    /// 单元格宽度
    width: i32,
};

/// 瓦片渲染偏移
pub const TileOffset = struct {
    /// 水平偏移 (像素)
    x: i32,
    /// 垂直偏移 (像素，正值为向下)
    y: i32,
};

/// 变换限制
pub const Transformations = struct {
    /// 瓦片是否可以水平翻转
    hflip: bool,
    /// 瓦片是否可以垂直翻转
    vflip: bool,
    /// 瓦片是否可以以 90 度为增量旋转
    rotate: bool,
    /// 是否保留未变换的瓦片优先
    preferuntransformed: bool,
};

/// 动画帧定义
pub const Frame = struct {
    /// 帧持续时间 (毫秒)
    duration: i32,
    /// 代表该帧的局部瓦片 ID
    tileid: i32,
};

/// 地形定义
pub const Terrain = struct {
    /// 地形名称
    name: []const u8,
    /// 自定义属性数组
    properties: ?[]const Property = null,
    /// 代表该地形的局部瓦片 ID
    tile: i32,
};

/// Wang 集合 (用于自动铺路/瓦片匹配)
pub const WangSet = struct {
    /// Wang 集合的类 (自 1.9，可选)
    class: ?[]const u8 = null,
    /// Wang 颜色数组
    colors: []const WangColor,
    /// Wang 集合名称
    name: []const u8,
    /// 自定义属性数组
    properties: ?[]const Property = null,
    /// 代表该集合的局部瓦片 ID
    tile: i32,
    /// 类型 (corner, edge 或 mixed)
    type: []const u8,
    /// Wang 瓦片数组
    wangtiles: []const WangTile,
};

/// Wang 颜色定义
pub const WangColor = struct {
    /// 类的名称 (自 1.9，可选)
    class: ?[]const u8 = null,
    /// 十六进制颜色代码
    color: []const u8,
    /// 名称
    name: []const u8,
    /// 随机化时使用的概率
    probability: f32,
    /// 自定义属性数组
    properties: ?[]const Property = null,
    /// 代表该颜色的局部瓦片 ID
    tile: i32,
};

/// Wang 瓦片定义
pub const WangTile = struct {
    /// 局部瓦片 ID
    tileid: i32,
    /// Wang 颜色索引数组 (uchar[8])
    wangid: [8]u8,
};

/// 自定义属性
pub const Property = struct {
    /// 属性名称
    name: []const u8,
    /// 属性类型 (string, int, float, bool, color, file, object 或 class)
    type: []const u8 = "string",
    /// 自定义类型的名称 (如果适用)
    propertytype: ?[]const u8 = null,
    /// 属性值 (使用 std.json.Value 兼容多种基础类型)
    value: std.json.Value,
};

/// 像素坐标点
pub const Point = struct {
    /// 水平坐标 (像素)
    x: f32,
    /// 垂直坐标 (像素)
    y: f32,
};

/// 物体模板 (用于实例化重复物体)
pub const ObjectTemplate = struct {
    /// 固定为 "template"
    type: []const u8 = "template",
    /// 模板使用的外部瓦片集 (可选)
    tileset: ?Tileset = null,
    /// 由此模板实例化的物体定义
    object: Object,
};
