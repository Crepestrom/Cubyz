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
		energy: f32,
		maxEnergy: f32,
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
	pub fn getPredictedEnergy(entity: Entity) ?f32 {
		return (components.get(entity) orelse return null).energy;
	}
	pub fn getPredictedMaxEnergy(entity: Entity) ?f32 {
		return (components.get(entity) orelse return null).maxEnergy;
	}

	pub fn load(entity: Entity, reader: *utils.BinaryReader, version: u32) main.entity.EntityComponentLoadError!void {
		if (version != entityComponentVersion) return error.InvalidComponentVersion;
		var ptr: *Component = undefined;
		if (components.get(entity)) |p| {
			ptr = p;
		} else {
			ptr = components.add(main.globalAllocator, entity);
		}
		const currentEnergy = reader.readFloat(f32) catch return error.UnreadableComponentData;

		ptr.* = Component{
			.energy = currentEnergy,
			.maxEnergy = reader.readFloat(f32) catch return error.UnreadableComponentData,
		};
	}
	pub fn unload(entity: Entity) void {
		_ = entity;
	}

	pub fn changePredictedEnergy(givenEntity: Entity, change: f32) void {
		main.sync.threadContext.assertCorrectContext(.client);
		const energyComponent = main.entity.components.@"cubyz:energy".client.components.get(givenEntity) orelse return;
		energyComponent.energy = std.math.clamp(energyComponent.energy + change, 0, energyComponent.maxEnergy);

	}
	pub fn setPredictedEnergy(givenEntity: Entity, value: f32) void {
		main.sync.threadContext.assertCorrectContext(.client);
		const energyComponent = main.entity.components.@"cubyz:energy".client.components.get(givenEntity) orelse return;
		energyComponent.energy = std.math.clamp(value, 0, energyComponent.maxEnergy);
	}
};

// ############################# Server only stuff ################################
pub const server = struct {
	pub const Component = struct {
		energy: f32,
		maxEnergy: f32,
		pub fn save(self: *Component, writer: *utils.BinaryWriter, audience: main.entity.AudienceInfo) main.entity.ComponentSaveBehaviour {
			_ = audience;
			writer.writeFloat(f32, self.energy);
			writer.writeFloat(f32, self.maxEnergy);
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
	pub fn getEnergy(entity: Entity) ?f32 {
		return (components.get(entity) orelse return null).energy;
	}
	pub fn getMaxEnergy(entity: Entity) ?f32 {
		return (components.get(entity) orelse return null).maxEnergy;
	}
	pub fn loadFromData(entity: Entity, reader: *utils.BinaryReader, version: u32) main.entity.EntityComponentLoadError!void {
		if (version != entityComponentVersion) return error.InvalidComponentVersion;
		const ptr: *Component = components.add(main.globalAllocator, entity);
		ptr.* = Component{
			.energy = reader.readFloat(f32) catch return error.UnreadableComponentData,
			.maxEnergy = reader.readFloat(f32) catch return error.UnreadableComponentData,
		};
	}
	pub fn loadFromNumber(entity: Entity, number: f32) void {
		const ptr: *Component = components.add(main.globalAllocator, entity);
		ptr.* = Component{
			.energy = number,
			.maxEnergy = number,
		};
	}
	pub fn unload(entity: Entity) void {
		_ = entity;
	}

	pub fn addEnergy(entity: Entity, value: f32) void {
		main.sync.threadContext.assertCorrectContext(.server);
		const energyComponent = main.entity.components.@"cubyz:energy".server.components.get(entity) orelse return;
		energyComponent.energy = std.math.clamp(energyComponent.energy + value, 0, energyComponent.maxEnergy);
		main.entity.server.transmitChange(main.entity.components.@"cubyz:energy", entity);
	}
	pub fn setEnergy(entity: Entity, value: f32) void {
		main.sync.threadContext.assertCorrectContext(.server);
		const energyComponent = components.get(entity) orelse return;
		energyComponent.energy = std.math.clamp(value, 0, energyComponent.maxEnergy);
		main.entity.server.transmitChange(main.entity.components.@"cubyz:energy", entity);
	}
	pub fn resetEnergy(entity: Entity) void {
		main.sync.threadContext.assertCorrectContext(.server);
		const energyComponent = components.get(entity) orelse return;
		const value = energyComponent.maxEnergy;
		energyComponent.energy = std.math.clamp(value, 0, energyComponent.maxEnergy);
		main.entity.server.transmitChange(main.entity.components.@"cubyz:energy", entity);
	}
};
