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
};
// ############################# Server only stuff ################################
pub const server = struct {
	pub fn init() void {}
	pub fn deinit() void {}

	pub fn addManaCharge(givenEntity: Entity, change: f32) void {
		const startingTags: [0]main.Tag = .{};
		main.entity.components.@"cubyz:resource_change".server.loadFromValues(givenEntity, change, &startingTags);
		const onEventFunctionName: []const u8 = "onAddManaCharge";
		const subscribeFunctionName: []const u8 = "addManaChargeEventSubscribe";
		const addPhaseFunctionName: []const u8 = "addManaChargeEventAddPhase";
		const sortedTypes = comptime systems.RunOrderManager.getSortedOrder(@typeInfo(systems.systems).@"struct".decls, subscribeFunctionName, addPhaseFunctionName);
		inline for (sortedTypes) |decl| {
			if (@hasDecl(@field(systems.systems, decl.name).server, onEventFunctionName)) {
				@field(@field(systems.systems, decl.name).server, onEventFunctionName)();
			} else {
				continue;
			}
		}
		main.entity.components.@"cubyz:resource_change".server.unload(givenEntity);
	}

	pub fn addManaChargeEventSubscribe() systems.RunOrderManager.FunctionStep {
		return systems.RunOrderManager.FunctionStep{.targetPhase = "end"};
	}

	pub fn onAddManaCharge() void {
		for (entity.components.@"cubyz:resource_change".server.components.dense.items, entity.components.@"cubyz:resource_change".server.components.denseToSparseIndex.items) |component, id| {
			main.entity.components.@"cubyz:mana_charge".server.addHealth(id, component.change);
		}
	}
};
