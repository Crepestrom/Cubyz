const std = @import("std");

const main = @import("main");
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
	animationName: main.Tag,
	animationLength: i64 = 0, // stored in milliseconds
	overwritable: bool = true,
	loop: bool = false,
};

// ############################# Client only stuff ################################
pub const client = struct {
	const Component = struct {
		animationName: ?main.Tag,
		length: i64,
		endTime: i64,
		handMatrix: Mat4f,
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

		const hasAnimationName = reader.readBool() catch return error.UnreadableComponentData;
		ptr.* = Component{
			.animationName = if (hasAnimationName) reader.readEnum(main.Tag) catch return error.UnreadableComponentData else null,
			.length = reader.readInt(i64) catch return error.UnreadableComponentData,
			.endTime = reader.readInt(i64) catch return error.UnreadableComponentData,
			.handMatrix = Mat4f.identity(),
			.overwritable = reader.readBool() catch return error.UnreadableComponentData,
			.loop = reader.readBool() catch return error.UnreadableComponentData,
		};
	}
	pub fn unload(entity: Entity) void {
		components.remove(entity) catch {};
	}

	pub fn setPredictedAnimation(entity: Entity, attemptedAnimation: animationInfo) void {
		const animationComponent: Component = components.get(entity) orelse return;
		if (animationComponent.overwritable) {
			animationComponent.animationName = attemptedAnimation.animationName;
			animationComponent.length = attemptedAnimation.animationLength;
			animationComponent.endTime = attemptedAnimation.animationLength + game.world.?.gameTime.load(.monotonic);
			animationComponent.overwritable = attemptedAnimation.overwritable;
		}
	}
	pub fn setAnimationMatrix(entity: Entity, givenMatrix: Mat4f) void {
		const animationComponent = components.get(entity) orelse return;
		if (animationComponent.animationName == null) return;
		animationComponent.handMatrix = givenMatrix;
	}
	pub fn getPredictedAnimationProgress(entity: Entity) f32 {
		const animationComponent = components.get(entity) orelse return;
		if (animationComponent.animationName == null) return;
		const currentTimePassed = -(game.world.?.gameTime.load(.monotonic) - animationComponent.endTime);
		return std.math.clamp(currentTimePassed/animationComponent.length, 0, 1);
	}
	pub fn getAnimationMatrix(entity: Entity) ?Mat4f {
		const animationComponent = components.get(entity) orelse return null;
		if (animationComponent.animationName == null) return null;
		return animationComponent.handMatrix;
	}
	pub fn isPlayingAnimation(entity: Entity) ?bool {
		const animationComponent  = components.get(entity) orelse return null;
		if (animationComponent.animationName == null) return false;
		return true;
	}
};

// ############################# Server only stuff ################################
pub const server = struct {
	pub const Component = struct {
		animationName: ?main.Tag,
		length: i64,
		endTime: i64,
		overwritable: bool = true,
		loop: bool = false,
		pub fn save(self: *Component, writer: *utils.BinaryWriter, audience: main.entity.AudienceInfo) main.entity.ComponentSaveBehaviour {
			_ = audience;
			writer.writeBool(self.animationName != null);
			if (self.animationName != null) writer.writeEnum(main.Tag, self.animationName orelse return .discard);
			writer.writeInt(i64, self.length);
			writer.writeInt(i64, self.endTime);
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
			.animationName = null,
			.length = 0,
			.endTime = 0,
		};
	}
	pub fn unload(entity: Entity) void {
		components.remove(entity) catch {};
	}
};
