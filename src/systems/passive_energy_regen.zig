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

const c = @import("c");

const entityComponent = main.entityComponent;

const @"cubyz:passive_energy_regen" = main.entity.components.@"cubyz:passive_energy_regen";

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

	pub const updateEvent: systems.RunOrderManager.FunctionHook(fn(deltaTime: f64) void) = .{
		.addedPhase = .{.self = "passiveCombatResourceRegen", .targetSortPhase = "start", .sortDirection = .after, .priority = 0},
		.addedFunctionStep = .{.targetPhase = "passiveCombatResourceRegen"},
		.function = update,
	};

	fn update(deltaTime: f64) void {
		_ = deltaTime;
		for (@"cubyz:passive_energy_regen".client.components.dense.items, entity.components.@"cubyz:passive_energy_regen".client.components.denseToSparseIndex.items) |*component, id| {
			component.update(id);
		}
	}

	pub const addEnergyEvent: systems.RunOrderManager.FunctionHook(fn() void) = .{
		.addedFunctionStep = .{.targetPhase = "end"},
		.function = resetDelay,
	};

	fn resetDelay() void {
		for (entity.components.@"cubyz:resource_change".client.components.dense.items, entity.components.@"cubyz:resource_change".client.components.denseToSparseIndex.items) |component, id| {
			if (component.change < 0) @"cubyz:passive_energy_regen".resetDelayTime(id);
		}
	}
};
// ############################# Server only stuff ################################
pub const server = struct {
	pub fn init() void {}
	pub fn deinit() void {}

	pub const updateEvent: systems.RunOrderManager.FunctionHook(fn() void) = .{
		.addedPhase = .{.self = "passiveCombatResourceRegen", .targetSortPhase = "start", .sortDirection = .after, .priority = 0},
		.addedFunctionStep = .{.targetPhase = "passiveCombatResourceRegen"},
		.function = update,
	};

	fn update() void {
		for (@"cubyz:passive_energy_regen".server.components.dense.items, entity.components.@"cubyz:passive_energy_regen".server.components.denseToSparseIndex.items) |*component, id| {
			component.update(id);
		}
	}

	pub const addEnergyEvent: systems.RunOrderManager.FunctionHook(fn() void) = .{
		.addedFunctionStep = .{.targetPhase = "end"},
		.function = resetDelay,
	};

	fn resetDelay() void {
		for (entity.components.@"cubyz:resource_change".server.components.dense.items, entity.components.@"cubyz:resource_change".server.components.denseToSparseIndex.items) |component, id| {
			if (component.change < 0) @"cubyz:passive_energy_regen".resetDelayTime(id);
		}
	}
};
