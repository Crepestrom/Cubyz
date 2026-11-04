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

const @"cubyz:position" = main.entity.components.@"cubyz:position";
const @"cubyz:velocity" = main.entity.components.@"cubyz:velocity";

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

	pub const onPhysicsUpdate: systems.RunOrderManager.FunctionHook(fn(deltaTime: f64) void) = .{
		.addedPhase = .{.self = "calculateFriction", .targetSortPhase = "start", .sortDirection = .after, .priority = 0},
		.addedFunctionStep = .{.targetPhase = "calculateFriction"},
		.function = update,
	};

	fn update(deltaTime: f64) void {
		_ = deltaTime;
		systems.RunOrderManager.createBasicHook("calculateFriction", systems.systems, .client);
	}

	pub const calculateFriction: systems.RunOrderManager.FunctionHook(fn() void) = .{
		.addedPhase = .{.self = "fromVolumeProperties", .targetSortPhase = "start", .sortDirection = .after, .priority = 0},
		.addedFunctionStep = .{.targetPhase = "fromVolumeProperties"},
		.function = friction,
	};

	fn friction() void {
		const playerPos = @"cubyz:position".getPositionPointer(player.id, .client).?;
		physics.calculateVolumeProperties(.client, &player.volumeProperties, playerPos.*, player.outerBoundingBox, physics.playerAirTerminalVelocity);
		physics.calculateFriction(.client, &player.volumeProperties, &player.friction, playerPos.*, player.outerBoundingBox, player.onGround);
		std.log.debug("player.volumeProperties {}", .{player.volumeProperties.terminalVelocity});
		std.log.debug("calculated friction {}", .{player.friction});
	}
};
// ############################# Server only stuff ################################
pub const server = struct {
	pub fn init() void {}
	pub fn deinit() void {}
};
