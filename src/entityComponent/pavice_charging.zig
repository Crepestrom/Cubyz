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

const @"cubyz:physics_body" = main.entity.components.@"cubyz:physics_body";

pub var entityComponentID: main.entity.EntityComponentId = undefined;
pub const entityComponentVersion = 0;

pub const animationInfo = struct {
	animationName: main.Tag,
	animationLength: i64 = 0, // stored in deciseconds
	overwritable: bool = true,
	loop: bool = false,
	onAnimationEnd: ?*const fn (entity: Entity) void = null,
};

// ############################# Client only stuff ################################
pub const client = struct {
	const Component = struct {
		endTime: i64,
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
			.endTime = reader.readInt(i64) catch return error.UnreadableComponentData,
		};
	}
	pub fn unload(entity: Entity) void {
		components.remove(entity) catch {};
	}
};

// ############################# Server only stuff ################################
pub const server = struct {
	pub const Component = struct {
		endTime: i64,
		pub fn save(self: *Component, writer: *utils.BinaryWriter, audience: main.entity.AudienceInfo) main.entity.ComponentSaveBehaviour {
			_ = audience;
			writer.writeInt(i64, self.endTime);
			return .save;
		}
		pub fn update(self: *Component, entity: Entity) void {
			const stoppingSpeed = 5;
			var entityVel = @"cubyz:physics_body".getVelocity(entity, .server).?;
			entityVel[2] = 0;
			if ((self.endTime < main.server.world.?.gameTime) or (vec.length(entityVel) < stoppingSpeed)) {
				removeFromBothSides(entity);
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
		_ = entity;
		_ = reader;
		_ = version;
	}
	pub fn unload(entity: Entity) void {
		components.remove(entity) catch {};
	}

	pub fn add(entity: Entity, length: i64) void {
		if (get(entity) == null) {
			const component = components.add(main.globalAllocator, entity);
			component.endTime = main.server.world.?.gameTime + length;
			main.entity.server.transmitChange(main.entity.components.@"cubyz:pavice_charging", entity);
		}
	}
	pub fn removeFromBothSides(entity: Entity) void {
		components.remove(entity) catch {};
		main.entity.server.transmitChange(main.entity.components.@"cubyz:pavice_charging", entity);
	}
};
