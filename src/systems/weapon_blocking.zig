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

const @"cubyz:weapon_blocking" = main.entity.components.@"cubyz:weapon_blocking";
const @"cubyz:health_change" = main.entity.components.@"cubyz:health_change";

const c = @import("c");

const entityComponent = main.entityComponent;

// ############################# Client only stuff ################################
pub const client = struct {
	pub fn init() void {}
	pub fn deinit() void {}
	pub fn clear() void {}

	pub fn render(ambientLight: Vec3f, playerPos: Vec3d, deltaTime: f64) void {
		_ = ambientLight;
		_ = playerPos;
		_ = deltaTime;
	}
	pub fn renderHud(ambientLight: Vec3f, playerPos: Vec3d) void {
		_ = ambientLight;
		_ = playerPos;
	}
};
// ############################# Server only stuff ################################
pub const server = struct {
	pub fn init() void {}
	pub fn deinit() void {}

	pub fn addHealthEventAddPhase() systems.RunOrderManager.Phase {
		return .{.self = "blockReduce", .targetSortPhase = "end", .sortDirection = .before, .priority = 0};
	}

	pub fn addHealthEventSubscribe() systems.RunOrderManager.FunctionStep {
		return systems.RunOrderManager.FunctionStep{.targetPhase = "blockReduce"};
	}

	pub fn onAddHealth() void {
		for (entity.components.@"cubyz:health_change".server.components.dense.items, entity.components.@"cubyz:health_change".server.components.denseToSparseIndex.items) |*component, id| {
			const blockComponent = @"cubyz:weapon_blocking".server.get(id) orelse return;
			component.change = component.change*(1 - blockComponent.blockingPower);
		}
	}
};
