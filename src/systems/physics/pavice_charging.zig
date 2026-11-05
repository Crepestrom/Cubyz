const std = @import("std");

const main = @import("main");
const chunk = main.chunk;
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
const Vec2f = vec.Vec2f;
const NeverFailingAllocator = main.heap.NeverFailingAllocator;
const blocks = main.blocks;
const World = game.World;
const ServerWorld = main.server.ServerWorld;
const items = main.items;
const ItemStack = items.ItemStack;
const random = main.random;
const systems = main.systems;
const entity = main.entity;
const Entity = entity.Entity;
const keyboard = main.keyboard;
const camera = main.game.camera;
const physics = main.physics;
const player = main.game.player;

const @"cubyz:physics_body" = main.entity.components.@"cubyz:physics_body";
const @"cubyz:pavice_charging" = main.entity.components.@"cubyz:pavice_charging";


const c = @import("c");

const entityComponent = main.entityComponent;

// ############################# Client only stuff ################################
pub const client = struct {
	pub fn init() void {}
	pub fn deinit() void {}
	pub fn clear() void {}

	pub fn render(currentFrame: *graphics.vulkan.Frame, ambientLight: Vec3f, playerPos: Vec3d, deltaTime: f64) void {
		_ = currentFrame;
		_ = ambientLight;
		_ = playerPos;
		_ = deltaTime;
	}
	pub fn renderHud(currentFrame: *graphics.vulkan.Frame, ambientLight: Vec3f, playerPos: Vec3d) void {
		_ = currentFrame;
		_ = ambientLight;
		_ = playerPos;
	}

	pub const calculateFriction: systems.RunOrderManager.FunctionHook(fn() void) = .{
		.addedPhase = .{.self = "paviceChargingOverride", .targetSortPhase = "fromVolumeProperties", .sortDirection = .after, .priority = 10},
		.addedFunctionStep = .{.targetPhase = "paviceChargingOverride"},
		.function = update,
	};

	fn update() void {
		if (@"cubyz:pavice_charging".client.get(main.game.player.id) != null) {
			player.friction = .{.current = 2, .mobile = 2};
		}
	}
};
// ############################# Server only stuff ################################
pub const server = struct {
	pub fn init() void {}
	pub fn deinit() void {}

	pub const updateEvent: systems.RunOrderManager.FunctionHook(fn() void) = .{
		.addedFunctionStep = .{.targetPhase = "start"},
		.function = update,
	};

	fn update() void {
		for (@"cubyz:pavice_charging".server.components.dense.items, entity.components.@"cubyz:pavice_charging".server.components.denseToSparseIndex.items) |*component, id| {
			component.update(id);
		}
	}

};
