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

	pub fn update(deltaTime: f64) void {
		const sideName = "client";
		const onEventName = "updateEvent";
		const systemList = systems.systems;
		const sortedTypes = comptime main.systems.RunOrderManager.getSortedOrder(@typeInfo(systemList).@"struct".decl_names, sideName, onEventName);
		inline for (sortedTypes) |decl| {
			if (@hasDecl(@field(@field(systemList, decl), sideName), onEventName)) {
				@field(@field(@field(@field(systemList, decl), sideName), onEventName), "function")(deltaTime);
			} else {
				continue;
			}
		}
	}
};
// ############################# Server only stuff ################################
pub const server = struct {
	pub fn init() void {}
	pub fn deinit() void {}

	pub fn update() void {
		systems.RunOrderManager.createBasicHook("updateEvent", systems.systems, .server);
	}
};
