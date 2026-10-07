const std = @import("std");

const main = @import("main");
const animation = main.animation;
const chunk = main.chunk;
const Entity = main.entity.Entity;
const ServerChunk = chunk.ServerChunk;
const game = main.game;
const graphics = main.graphics;
const ZonElement = main.ZonElement;
const renderer = main.renderer;
const settings = main.settings;
const utils = main.utils;
const BinaryReader = utils.BinaryReader;
const BinaryWriter = utils.BinaryWriter;
const vec = main.vec;
const Mat4f = vec.Mat4f;
const Vec3d = vec.Vec3d;
const Vec3f = vec.Vec3f;
const Vec4f = vec.Vec4f;
const Vec3i = vec.Vec3i;
const NeverFailingAllocator = main.heap.NeverFailingAllocator;
const blocks = main.blocks;
const World = game.World;
const ServerWorld = main.server.ServerWorld;
const items = main.items;
const ItemStack = items.ItemStack;
const random = main.random;

const c = @import("c");

pub var entityComponentID: main.entity.EntityComponentId = undefined;
pub const entityComponentVersion = 0;

pub const animationInfo = struct {
	playingAnimation: animation.Animation,
	overwritable: bool = true,
	loop: bool = false,
};

// ############################# Client only stuff ################################
pub const client = struct {
	const Component = struct {
		playingAnimation: ?animation.Animation,
		currentPos: Vec3d = @splat(0),
		currentRot: Vec4f = @splat(0),
		overwritable: bool = true,
		loop: bool = false,
	};
	pub var components: main.utils.SparseSet(Component, Entity) = .{};

	pub fn init() void {}
	pub fn deinit() void {
		components.deinit(main.globalAllocator);
	}
	pub fn clear() void {
		components.clear();
	}

	pub fn get(entity: Entity) ?*Component {
		return (components.get(entity) orelse return null);
	}

	pub fn load(entity: Entity, reader: *utils.BinaryReader, version: u32) main.entity.EntityComponentLoadError!void {
		if (version != entityComponentVersion) return error.InvalidComponentVersion;
		var ptr: *Component = undefined;
		if (components.get(entity)) |p| {
			ptr = p;
		} else {
			ptr = components.add(main.globalAllocator, entity);
		}

		ptr.* = Component{
			.playingAnimation = null,
			.overwritable = reader.readBool() catch return error.UnreadableComponentData,
			.loop = reader.readBool() catch return error.UnreadableComponentData,
		};
	}
	pub fn unload(entity: Entity) void {
		components.remove(entity) catch {};
	}

	pub fn setPredictedAnimation(entity: Entity, attemptedAnimation: animationInfo) void {
		const animationComponent = components.get(entity) orelse return;
		if (animationComponent.overwritable) {
			animationComponent.playingAnimation = attemptedAnimation.playingAnimation;
			animationComponent.overwritable = attemptedAnimation.overwritable;
			animationComponent.loop = attemptedAnimation.loop;
		}
	}
	pub fn UpdateAnimation(entity: Entity, deltaTime: f64) void {
		const animationComponent = components.get(entity) orelse return;
		if (animationComponent.playingAnimation == null) return;
		animationComponent.playingAnimation.?.update(deltaTime);
	}
	pub fn getPredictedAnimationProgress(entity: Entity) ?f32 {
		const animationComponent = components.get(entity) orelse return null;
		if (animationComponent.playingAnimation == null) return null;
		const currentTimePassed = -(game.world.?.gameTime.load(.monotonic) - animationComponent.endTime);
		return std.math.clamp(@as(f32, @floatFromInt(currentTimePassed))/@as(f32, @floatFromInt(animationComponent.length)), 0, 1);
	}
	pub fn getAnimationMatrix(entity: Entity) ?Mat4f {
		const animationComponent = components.get(entity) orelse return null;
		if (animationComponent.playingAnimation == null) return null;
		return animationComponent.handMatrix;
	}
	pub fn isPlayingAnimation(entity: Entity) ?bool {
		const animationComponent  = components.get(entity) orelse return null;
		if (animationComponent.playingAnimation == null) return false;
		return true;
	}
};

// ############################# Server only stuff ################################
pub const server = struct {
	pub const Component = struct {
		playingAnimation: ?animation.Animation,
		overwritable: bool = true,
		loop: bool = false,
		pub fn save(self: *Component, writer: *utils.BinaryWriter, audience: main.entity.AudienceInfo) main.entity.ComponentSaveBehaviour {
			_ = audience;
			writer.writeBool(self.overwritable);
			writer.writeBool(self.loop);
			return .save;
		}
	};
	pub var components: main.utils.SparseSet(Component, Entity) = .{};

	pub fn init() void {
		components = .{};
	}
	pub fn deinit() void {
		components.deinit(main.globalAllocator);
	}

	pub fn get(entity: Entity) ?*Component {
		return (components.get(entity) orelse return null);
	}
	pub fn loadFromData(entity: Entity, reader: *utils.BinaryReader, version: u32) main.entity.EntityComponentLoadError!void {
		_ = entity;
		_ = reader;
		_ = version;
	}
	pub fn loadEmpty(entity: Entity) void {
		const ptr: *Component = components.add(main.globalAllocator, entity);
		ptr.* = Component{
			.playingAnimation = null,
		};
	}
	pub fn unload(entity: Entity) void {
		components.remove(entity) catch {};
	}
};
