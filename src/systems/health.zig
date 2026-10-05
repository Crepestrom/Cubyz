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

	pub fn getPredictedHealth(givenEntity: Entity) ?f32 {
		main.sync.threadContext.assertCorrectContext(.client);
		const healthComponent = main.entity.components.@"cubyz:health".client.components.get(givenEntity) orelse return null;
		return healthComponent.health;
	}
	pub fn getPredictedMaxHealth(givenEntity: Entity) ?f32 {
		main.sync.threadContext.assertCorrectContext(.client);
		const healthComponent = main.entity.components.@"cubyz:health".client.components.get(givenEntity) orelse return null;
		return healthComponent.maxHealth;
	}
};
// ############################# Server only stuff ################################
pub const server = struct {
	pub fn init() void {}
	pub fn deinit() void {}

	pub fn addHealth() void {
		const onEventFunctionName: []const u8 = "onAddHealth";
		const subscribeFunctionName: []const u8 = "addHealthEventSubscribe";
		const addPhaseFunctionName: []const u8 = "addHealthEventAddPhase";
		const sortedTypes = comptime systems.RunOrderManager.getSortedOrder(@typeInfo(systems.systems).@"struct".decls, subscribeFunctionName, addPhaseFunctionName);
		inline for (sortedTypes) |decl| {
			if (@hasDecl(@field(systems.systems, decl.name).server, onEventFunctionName)) {
				@field(@field(systems.systems, decl.name).server, onEventFunctionName)();
			} else {
				continue;
			}
		}
	}

	pub fn addHealthEventSubscribe() systems.RunOrderManager.FunctionStep {
		return systems.RunOrderManager.FunctionStep{.targetPhase = "end"};
	}

	pub fn onAddHealth() void {
		for (entity.components.@"cubyz:health_change".client.components.dense.items, entity.components.@"cubyz:health_change".client.components.denseToSparseIndex.items) |component, id| {
		
		}
	}
	pub fn actuallyChangeHealth(givenEntity: Entity, change: f32, cause: main.game.DamageType) bool {
		main.sync.threadContext.assertCorrectContext(.server);
		_ = cause;
		const healthComponent = main.entity.components.@"cubyz:health".server.components.get(givenEntity) orelse return false;
		healthComponent.health = std.math.clamp(healthComponent.health + change, 0, healthComponent.maxHealth);
		main.entity.server.transmitChange(main.entity.components.@"cubyz:health", givenEntity);
		var ifKilled = false;
		if (healthComponent.health == 0) ifKilled = true;
		return ifKilled;
	}
	pub fn setHealth(givenEntity: Entity, value: f32) void {
		main.sync.threadContext.assertCorrectContext(.server);
		const healthComponent = main.entity.components.@"cubyz:health".server.components.get(givenEntity) orelse return;
		healthComponent.health = std.math.clamp(value, 0, healthComponent.maxHealth);
		main.entity.server.transmitChange(main.entity.components.@"cubyz:health", givenEntity);
	}
	pub fn getHealth(givenEntity: Entity) ?f32 {
		main.sync.threadContext.assertCorrectContext(.server);
		const healthComponent = main.entity.components.@"cubyz:health".server.components.get(givenEntity) orelse return null;
		return healthComponent.health;
	}
	pub fn getMaxHealth(givenEntity: Entity) ?f32 {
		main.sync.threadContext.assertCorrectContext(.server);
		const healthComponent = main.entity.components.@"cubyz:health".server.components.get(givenEntity) orelse return null;
		return healthComponent.maxHealth;
	}
};
