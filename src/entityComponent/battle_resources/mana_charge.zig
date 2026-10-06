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
		manaCharge: f32,
		maxManaCharge: f32,
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
	pub fn getPredictedManaCharge(entity: Entity) ?f32 {
		return (components.get(entity) orelse return null).manaCharge;
	}
	pub fn getPredictedMaxManaCharge(entity: Entity) ?f32 {
		return (components.get(entity) orelse return null).maxManaCharge;
	}

	pub fn load(entity: Entity, reader: *utils.BinaryReader, version: u32) main.entity.EntityComponentLoadError!void {
		if (version != entityComponentVersion) return error.InvalidComponentVersion;
		var ptr: *Component = undefined;
		if (components.get(entity)) |p| {
			ptr = p;
		} else {
			ptr = components.add(main.globalAllocator, entity);
		}
		const currentManaCharge = reader.readFloat(f32) catch return error.UnreadableComponentData;

		ptr.* = Component{
			.manaCharge = currentManaCharge,
			.maxManaCharge = reader.readFloat(f32) catch return error.UnreadableComponentData,
		};
	}
	pub fn unload(entity: Entity) void {
		_ = entity;
	}

	pub fn changePredictedManaCharge(givenEntity: Entity, change: f32) void {
		main.sync.threadContext.assertCorrectContext(.client);
		const manaChargeComponent = main.entity.components.@"cubyz:manaCharge".client.components.get(givenEntity) orelse return;
		manaChargeComponent.manaCharge = std.math.clamp(manaChargeComponent.manaCharge + change, 0, manaChargeComponent.maxManaCharge);

	}
	pub fn setPredictedManaCharge(givenEntity: Entity, value: f32) void {
		main.sync.threadContext.assertCorrectContext(.client);
		const manaChargeComponent = main.entity.components.@"cubyz:manaCharge".client.components.get(givenEntity) orelse return;
		manaChargeComponent.manaCharge = std.math.clamp(value, 0, manaChargeComponent.maxManaCharge);
	}
};

// ############################# Server only stuff ################################
pub const server = struct {
	pub const Component = struct {
		manaCharge: f32,
		maxManaCharge: f32,
		pub fn save(self: *Component, writer: *utils.BinaryWriter, audience: main.entity.AudienceInfo) main.entity.ComponentSaveBehaviour {
			_ = audience;
			writer.writeFloat(f32, self.manaCharge);
			writer.writeFloat(f32, self.maxManaCharge);
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
	pub fn getManaCharge(entity: Entity) ?f32 {
		return (components.get(entity) orelse return null).manaCharge;
	}
	pub fn getMaxManaCharge(entity: Entity) ?f32 {
		return (components.get(entity) orelse return null).maxManaCharge;
	}
	pub fn loadFromData(entity: Entity, reader: *utils.BinaryReader, version: u32) main.entity.EntityComponentLoadError!void {
		if (version != entityComponentVersion) return error.InvalidComponentVersion;
		const ptr: *Component = components.add(main.globalAllocator, entity);
		ptr.* = Component{
			.manaCharge = reader.readFloat(f32) catch return error.UnreadableComponentData,
			.maxManaCharge = reader.readFloat(f32) catch return error.UnreadableComponentData,
		};
	}
	pub fn loadFromNumber(entity: Entity, number: f32) void {
		const ptr: *Component = components.add(main.globalAllocator, entity);
		ptr.* = Component{
			.manaCharge = number,
			.maxManaCharge = number,
		};
	}
	pub fn unload(entity: Entity) void {
		_ = entity;
	}

	pub fn addManaCharge(entity: Entity, value: f32) void {
		main.sync.threadContext.assertCorrectContext(.server);
		const manaChargeComponent = main.entity.components.@"cubyz:manaCharge".server.components.get(entity) orelse return;
		manaChargeComponent.manaCharge = std.math.clamp(manaChargeComponent.manaCharge + value, 0, manaChargeComponent.maxManaCharge);
		main.entity.server.transmitChange(main.entity.components.@"cubyz:manaCharge", entity);
	}
	pub fn setManaCharge(entity: Entity, value: f32) void {
		main.sync.threadContext.assertCorrectContext(.server);
		const manaChargeComponent = components.get(entity) orelse return;
		manaChargeComponent.manaCharge = std.math.clamp(value, 0, manaChargeComponent.maxManaCharge);
		main.entity.server.transmitChange(main.entity.components.@"cubyz:manaCharge", entity);
	}
	pub fn resetManaCharge(entity: Entity) void {
		main.sync.threadContext.assertCorrectContext(.server);
		const manaChargeComponent = components.get(entity) orelse return;
		const value = manaChargeComponent.maxManaCharge;
		manaChargeComponent.manaCharge = std.math.clamp(value, 0, manaChargeComponent.maxManaCharge);
		main.entity.server.transmitChange(main.entity.components.@"cubyz:manaCharge", entity);
	}
};
