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

// ############################# Client only stuff ################################
pub const client = struct {
	const Component = struct {
		momentum: f32,
		maxMomentum: f32,
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
	pub fn getPredictedMomentum(entity: Entity) ?f32 {
		return (components.get(entity) orelse return null).momentum;
	}
	pub fn getPredictedMaxMomentum(entity: Entity) ?f32 {
		return (components.get(entity) orelse return null).maxMomentum;
	}

	pub fn load(entity: Entity, reader: *utils.BinaryReader, version: u32) main.entity.EntityComponentLoadError!void {
		if (version != entityComponentVersion) return error.InvalidComponentVersion;
		var ptr: *Component = undefined;
		if (components.get(entity)) |p| {
			ptr = p;
		} else {
			ptr = components.add(main.globalAllocator, entity);
		}
		const currentMomentum = reader.readFloat(f32) catch return error.UnreadableComponentData;

		ptr.* = Component{
			.momentum = currentMomentum,
			.maxMomentum = reader.readFloat(f32) catch return error.UnreadableComponentData,
		};
	}
	pub fn unload(entity: Entity) void {
		_ = entity;
	}

	pub fn changePredictedMomentum(givenEntity: Entity, change: f32) void {
		main.sync.threadContext.assertCorrectContext(.client);
		const momentumComponent = main.entity.components.@"cubyz:momentum".client.components.get(givenEntity) orelse return;
		momentumComponent.momentum = std.math.clamp(momentumComponent.momentum + change, 0, momentumComponent.maxMomentum);

	}
	pub fn setPredictedMomentum(givenEntity: Entity, value: f32) void {
		main.sync.threadContext.assertCorrectContext(.client);
		const momentumComponent = main.entity.components.@"cubyz:momentum".client.components.get(givenEntity) orelse return;
		momentumComponent.momentum = std.math.clamp(value, 0, momentumComponent.maxMomentum);
	}
};

// ############################# Server only stuff ################################
pub const server = struct {
	pub const Component = struct {
		momentum: f32,
		maxMomentum: f32,
		pub fn save(self: *Component, writer: *utils.BinaryWriter, audience: main.entity.AudienceInfo) main.entity.ComponentSaveBehaviour {
			_ = audience;
			writer.writeFloat(f32, self.momentum);
			writer.writeFloat(f32, self.maxMomentum);
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
	pub fn getMomentum(entity: Entity) ?f32 {
		return (components.get(entity) orelse return null).momentum;
	}
	pub fn getMaxMomentum(entity: Entity) ?f32 {
		return (components.get(entity) orelse return null).maxMomentum;
	}
	pub fn loadFromData(entity: Entity, reader: *utils.BinaryReader, version: u32) main.entity.EntityComponentLoadError!void {
		if (version != entityComponentVersion) return error.InvalidComponentVersion;
		const ptr: *Component = components.add(main.globalAllocator, entity);
		ptr.* = Component{
			.momentum = reader.readFloat(f32) catch return error.UnreadableComponentData,
			.maxMomentum = reader.readFloat(f32) catch return error.UnreadableComponentData,
		};
	}
	pub fn loadFromNumber(entity: Entity, number: f32) void {
		const ptr: *Component = components.add(main.globalAllocator, entity);
		ptr.* = Component{
			.momentum = number,
			.maxMomentum = number,
		};
	}
	pub fn unload(entity: Entity) void {
		_ = entity;
	}

	pub fn addMomentum(entity: Entity, value: f32) void {
		main.sync.threadContext.assertCorrectContext(.server);
		const momentumComponent = main.entity.components.@"cubyz:momentum".server.components.get(entity) orelse return;
		momentumComponent.momentum = std.math.clamp(momentumComponent.momentum + value, 0, momentumComponent.maxMomentum);
		main.entity.server.transmitChange(main.entity.components.@"cubyz:momentum", entity);
	}
	pub fn setMomentum(entity: Entity, value: f32) void {
		main.sync.threadContext.assertCorrectContext(.server);
		const momentumComponent = components.get(entity) orelse return;
		momentumComponent.momentum = std.math.clamp(value, 0, momentumComponent.maxMomentum);
		main.entity.server.transmitChange(main.entity.components.@"cubyz:momentum", entity);
	}
	pub fn resetMomentum(entity: Entity) void {
		main.sync.threadContext.assertCorrectContext(.server);
		const momentumComponent = components.get(entity) orelse return;
		const value = momentumComponent.maxMomentum;
		momentumComponent.momentum = std.math.clamp(value, 0, momentumComponent.maxMomentum);
		main.entity.server.transmitChange(main.entity.components.@"cubyz:momentum", entity);
	}
};
