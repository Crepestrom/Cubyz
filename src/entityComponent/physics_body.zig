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

pub fn getPosition(entity: Entity, side: main.sync.Side) ?Vec3d {
	return switch (side) {
		.client => client.getPosition(entity),
		.server => server.getPosition(entity),
	};
}
pub fn getPositionPointer(entity: Entity, side: main.sync.Side) ?*Vec3d {
	return switch (side) {
		.client => &(client.get(entity) orelse return null).position,
		.server => &(server.get(entity) orelse return null).position,
	};
}
pub fn setPosition(entity: Entity, givenPosition: Vec3d, side: main.sync.Side) void {
	return switch (side) {
		.client => client.setPosition(entity, givenPosition),
		.server => server.setPosition(entity, givenPosition),
	};
}
pub fn addPosition(entity: Entity, addedPosition: Vec3d, side: main.sync.Side) void {
	return switch (side) {
		.client => client.addPosition(entity, addedPosition),
		.server => server.addPosition(entity, addedPosition),
	};
}
pub fn getVelocity(entity: Entity, side: main.sync.Side) ?Vec3d {
	return switch (side) {
		.client => client.getVelocity(entity),
		.server => server.getVelocity(entity),
	};
}
pub fn getVelocityPointer(entity: Entity, side: main.sync.Side) ?*Vec3d {
	return switch (side) {
		.client => &(client.get(entity) orelse return null).velocity,
		.server => &(server.get(entity) orelse return null).velocity,
	};
}
pub fn setVelocity(entity: Entity, givenVelocity: Vec3d, side: main.sync.Side) void {
	return switch (side) {
		.client => client.setVelocity(entity, givenVelocity),
		.server => server.setVelocity(entity, givenVelocity),
	};
}
pub fn addVelocity(entity: Entity, addedVelocity: Vec3d, side: main.sync.Side) void {
	return switch (side) {
		.client => client.addVelocity(entity, addedVelocity),
		.server => server.addVelocity(entity, addedVelocity),
	};
}
pub fn getRotation(entity: Entity, side: main.sync.Side) ?Vec3f {
	return switch (side) {
		.client => client.getRotation(entity),
		.server => server.getRotation(entity),
	};
}
pub fn getRotationPointer(entity: Entity, side: main.sync.Side) ?*Vec3f {
	return switch (side) {
		.client => &(client.get(entity) orelse return null).rotation,
		.server => &(server.get(entity) orelse return null).rotation,
	};
}
pub fn setRotation(entity: Entity, givenRotation: Vec3f, side: main.sync.Side) void {
	return switch (side) {
		.client => client.setRotation(entity, givenRotation),
		.server => server.setRotation(entity, givenRotation),
	};
}

// ############################# Client only stuff ################################
pub const client = struct {
	const Component = struct {
		position: Vec3d,
		velocity: Vec3d,
		rotation: Vec3f,
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
			p.position = reader.readVec(Vec3d) catch return error.UnreadableComponentData;
			p.velocity = reader.readVec(Vec3d) catch return error.UnreadableComponentData;
			p.rotation = reader.readVec(Vec3f) catch return error.UnreadableComponentData;
		} else {
			ptr = components.add(main.globalAllocator, entity);
			ptr.position = reader.readVec(Vec3d) catch return error.UnreadableComponentData;
			ptr.velocity = reader.readVec(Vec3d) catch return error.UnreadableComponentData;
			if (entity != main.game.player.id) ptr.rotation = reader.readVec(Vec3f) catch return error.UnreadableComponentData;
		}
	}
	pub fn unload(entity: Entity) void {
		components.remove(entity) catch {};
	}

	fn getPosition(entity: Entity) ?Vec3d {
		const positionComponent = components.get(entity) orelse return null;
		return positionComponent.position;
	}
	fn setPosition(entity: Entity, givenPosition: Vec3d) void {
		const positionComponent = components.get(entity) orelse return;
		positionComponent.position = givenPosition;
	}
	fn addPosition(entity: Entity, givenPosition: Vec3d) void {
		const positionComponent = components.get(entity) orelse return;
		positionComponent.position += givenPosition;
	}
	pub fn getVelocity(entity: Entity) ?Vec3d {
		const velocityComponent = components.get(entity) orelse return null;
		return velocityComponent.velocity;
	}
	pub fn setVelocity(entity: Entity, givenVelocity: Vec3d) void {
		const velocityComponent = components.get(entity) orelse return;
		velocityComponent.velocity = givenVelocity;
	}
	pub fn addVelocity(entity: Entity, givenVelocity: Vec3d) void {
		const velocityComponent = components.get(entity) orelse return;
		velocityComponent.velocity += givenVelocity;
	}
	fn getRotation(entity: Entity) ?Vec3f {
		const positionComponent = components.get(entity) orelse return null;
		return positionComponent.rotation;
	}
	fn setRotation(entity: Entity, givenRotation: Vec3f) void {
		const positionComponent = components.get(entity) orelse return;
		positionComponent.rotation = givenRotation;
	}
};

// ############################# Server only stuff ################################
pub const server = struct {
	pub const Component = struct {
		position: Vec3d,
		velocity: Vec3d,
		rotation: Vec3f,
		pub fn save(self: *Component, writer: *utils.BinaryWriter, audience: main.entity.AudienceInfo) main.entity.ComponentSaveBehaviour {
			_ = audience;
			writer.writeVec(Vec3d, self.position);
			writer.writeVec(Vec3d, self.velocity);
			writer.writeVec(Vec3f, self.rotation);
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
		if (version != entityComponentVersion) return error.InvalidComponentVersion;
		const ptr: *Component = components.add(main.globalAllocator, entity);
		ptr.* = Component{
			.position = reader.readVec(Vec3d) catch return error.UnreadableComponentData,
			.velocity = reader.readVec(Vec3d) catch return error.UnreadableComponentData,
			.rotation = reader.readVec(Vec3f) catch return error.UnreadableComponentData,
		};
	}
	pub fn loadFromValues(entity: Entity, position: Vec3d, velocity: Vec3d, rotation: Vec3f) void {
		const ptr: *Component = components.add(main.globalAllocator, entity);
		ptr.* = Component{
			.position = position,
			.velocity = velocity,
			.rotation = rotation,
		};
	}
	pub fn unload(entity: Entity) void {
		components.remove(entity) catch {};
	}

	fn getPosition(entity: Entity) ?Vec3d {
		const positionComponent = components.get(entity) orelse return null;
		return positionComponent.position;
	}
	fn setPosition(entity: Entity, givenPosition: Vec3d) void {
		const positionComponent = components.get(entity) orelse return;
		positionComponent.position = givenPosition;
		main.entity.server.transmitChange(main.entity.components.@"cubyz:physics_body", entity);
	}
	fn addPosition(entity: Entity, givenPosition: Vec3d) void {
		const positionComponent = components.get(entity) orelse return;
		positionComponent.position += givenPosition;
		main.entity.server.transmitChange(main.entity.components.@"cubyz:physics_body", entity);
	}
	pub fn getVelocity(entity: Entity) ?Vec3d {
		const velocityComponent = components.get(entity) orelse return null;
		return velocityComponent.velocity;
	}
	pub fn setVelocity(entity: Entity, givenVelocity: Vec3d) void {
		const velocityComponent = components.get(entity) orelse return;
		velocityComponent.velocity = givenVelocity;
		main.entity.server.transmitChange(main.entity.components.@"cubyz:physics_body", entity);
	}
	pub fn addVelocity(entity: Entity, givenVelocity: Vec3d) void {
		const velocityComponent = components.get(entity) orelse return;
		velocityComponent.velocity += givenVelocity;
		main.entity.server.transmitChange(main.entity.components.@"cubyz:physics_body", entity);
	}
	fn getRotation(entity: Entity) ?Vec3f {
		const positionComponent = components.get(entity) orelse return null;
		return positionComponent.rotation;
	}
	fn setRotation(entity: Entity, givenRotation: Vec3f) void {
		const positionComponent = components.get(entity) orelse return;
		positionComponent.rotation = givenRotation;
		main.entity.server.transmitChange(main.entity.components.@"cubyz:physics_body", entity);
	}
};
