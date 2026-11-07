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

const @"cubyz:energy" = main.entity.components.@"cubyz:energy";

pub var entityComponentID: main.entity.EntityComponentId = undefined;
pub const entityComponentVersion = 0;

pub fn resetDelayTime(entity: Entity) void {
	switch (main.sync.threadContext) {
		.client => client.resetDelayTime(entity),
		.server => server.resetDelayTime(entity),
		else => {
			std.log.debug("Should only run on a server or client thread", .{});
			return;
		},
	}
}

// ############################# Client only stuff ################################
pub const client = struct {
	const Component = struct {
		baseEnergyRegenRate: f32,
		energyRegenDelay: i64,
		currentDelayEndTime: i64,
		pub fn update(self: *Component, entity: Entity) void {
			if (0 < main.game.world.?.gameTime.load(.monotonic) - self.currentDelayEndTime) {
				const deltaTime: f64 = @as(f64, @floatFromInt(main.game.world.?.gameTime.load(.monotonic) - self.currentDelayEndTime))/10;
				self.currentDelayEndTime = main.server.world.?.gameTime;
				main.systems.systems.energy.client.addEnergy(entity, @floatCast(@as(f64, @floatCast(self.baseEnergyRegenRate))*deltaTime));
			}
		}
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

		const baseEnergyRegenRate = reader.readFloat(f32) catch return error.UnreadableComponentData;
		const energyRegenDelay = reader.readInt(i64) catch return error.UnreadableComponentData;
		const currentDelayEndTime = reader.readInt(i64) catch return error.UnreadableComponentData;
		const deltatime: f64 = @as(f64, @floatFromInt(main.game.world.?.gameTime.load(.monotonic) - currentDelayEndTime))/10;

		@"cubyz:energy".client.changePredictedEnergy(entity, @floatCast(@as(f64, @floatCast(baseEnergyRegenRate))*deltatime));

		ptr.* = Component{
			.baseEnergyRegenRate = baseEnergyRegenRate,
			.energyRegenDelay = energyRegenDelay,
			.currentDelayEndTime = currentDelayEndTime,
		};
	}
	pub fn unload(entity: Entity) void {
		components.remove(entity) catch {};
	}
	pub fn resetDelayTime(entity: Entity) void {
		const component = components.get(entity) orelse return;
		component.currentDelayEndTime = main.game.world.?.gameTime.load(.monotonic) + component.energyRegenDelay;
	}
};

// ############################# Server only stuff ################################
pub const server = struct {
	pub const Component = struct {
		baseEnergyRegenRate: f32,
		energyRegenDelay: i64,
		currentDelayEndTime: i64,
		pub fn save(self: *Component, writer: *utils.BinaryWriter, audience: main.entity.AudienceInfo) main.entity.ComponentSaveBehaviour {
			_ = audience;
			writer.writeFloat(f32, self.baseEnergyRegenRate);
			writer.writeInt(i64, self.energyRegenDelay);
			writer.writeInt(i64, self.currentDelayEndTime);
			return .save;
		}
		pub fn update(self: *Component, entity: Entity) void {
			if (0 < main.server.world.?.gameTime - self.currentDelayEndTime) {
				const deltaTime: f64 = @as(f64, @floatFromInt(main.server.world.?.gameTime - self.currentDelayEndTime))/10;
				self.currentDelayEndTime = main.server.world.?.gameTime;
				main.systems.systems.energy.server.addEnergy(entity, @floatCast(@as(f64, @floatCast(self.baseEnergyRegenRate))*deltaTime));
			}
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
		if (version != entityComponentVersion) return error.InvalidComponentVersion;
		const ptr: *Component = components.add(main.globalAllocator, entity);
		ptr.* = Component{
			.baseEnergyRegenRate = reader.readFloat(f32) catch return error.UnreadableComponentData,
			.energyRegenDelay = reader.readInt(i64) catch return error.UnreadableComponentData,
			.currentDelayEndTime = reader.readInt(i64) catch return error.UnreadableComponentData,
		};
	}
	pub fn loadFromValues(entity: Entity, baseEnergyRegenRate: f32, energyRegenDelay: i64) void {
		var ptr: *Component = undefined;
		if (components.get(entity)) |p| {
			ptr = p;
		} else {
			ptr = components.add(main.globalAllocator, entity);
		}
		ptr.* = Component{
			.baseEnergyRegenRate = baseEnergyRegenRate,
			.energyRegenDelay = energyRegenDelay,
			.currentDelayEndTime = 0,
		};
	}
	pub fn unload(entity: Entity) void {
		components.remove(entity) catch {};
	}
	pub fn resetDelayTime(entity: Entity) void {
		const component = components.get(entity) orelse return;
		component.currentDelayEndTime = main.server.world.?.gameTime + component.energyRegenDelay;
	}
};
