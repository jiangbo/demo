const std = @import("std");
const zhu = @import("zhu");

const Entity = zhu.ecs.Entity;

pub const Animation = zhu.graphics.Animation;
pub const AnimationFinished = struct {};
pub const AnimationPlay = struct { index: u8, loop: bool = false };

pub const Position = zhu.Vector2;
pub const Sprite = struct {
    image: zhu.graphics.Image,
    offset: zhu.Vector2,
    flip: bool = false,
};

pub const Timer = struct {
    remaining: f32,
    entity: zhu.ecs.Entity,
    type: enum { attack },
};

///
/// 移动相关组件
///
pub const motion = struct {
    pub const Velocity = struct { v: zhu.Vector2 }; // 速度
    pub const FaceLeft = struct {}; // 面向左侧
    pub const Blocker = struct { max: u8, current: u8 = 0 }; // 阻挡者
    pub const BlockBy = struct { v: Entity }; // 被阻挡
};

///
/// 攻击相关组件
///
pub const attack = struct {
    pub const Target = struct { v: Entity }; // 攻击目标
    pub const Ready = struct {}; // 冷却完毕，可以攻击。
    pub const Range = struct { v: f32 }; // 攻击范围
    pub const Lock = struct {}; // 攻击锁定
    pub const Healer = struct {}; // 治疗者
    pub const Injured = struct {}; // 受伤标签
    pub const CoolDown = struct { v: f32 }; // 冷却时间
};

pub const SoundPath = struct { action: ActionEnum, path: [:0]const u8 };

pub const Path = struct {
    point: zhu.Vector2, // 路径点位置
    next: u8 = 0, // 终点没有下一个路径点
    next2: u8 = 0, // 可选的第二条分支路径
};

pub const Enemy = struct { target: Path, speed: f32 };
pub const Player = struct {}; // 占位符

pub const StateEnum = enum { idle, walk, damage, attack, ranged };
pub const ActionEnum = enum(u32) { none = 0, hit = 1, emit = 2 };

pub const Ranged = struct {};

pub const Stats = struct {
    health: i32,
    maxHealth: i32,
    attack: i32,
    defense: i32,
};

pub const Dead = struct {}; // 死亡标签
