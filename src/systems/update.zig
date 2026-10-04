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

	pub fn update() void {
		const sortedTypes = sortPhases(@typeInfo(main.systems.systems).@"struct".decls);
		inline for (sortedTypes) |decl| {
			if (@hasDecl(@field(main.systems.systems, decl.name).server, "onUpdate")) {
				@field(main.systems.systems, decl.name).server.onUpdate();
			} else {
				continue;
			}
		}
	}
	
	fn getPhases(comptime declarations: []const std.builtin.Type.Declaration) []const main.systems.PhaseType {
		var phaseList: []const main.systems.PhaseType = .{};
		for (declarations) |decl| {
			if (@hasDecl(@field(main.systems.systems, decl.name).server, "addUpdatePhase")) {
				phaseList = std.mem.concat(main.stackAllocator, &.{phaseList, @field(main.systems.systems, decl.name).server.addUpdatePhase()});
			} else {
				continue;
			}
		}
		return phaseList;
	}

	fn sortPhases(comptime declarations: []const std.builtin.Type.Declaration) []const main.systems.PhaseType {
		var phaseList = getPhases(declarations);
		for (declarations) |decl| {
			if (@hasDecl(@field(main.systems.systems, decl.name).server, "addUpdatePhase")) {
				@field(main.systems.systems, decl.name).server.addUpdatePhase();
			} else {
				continue;
			}
		}
	}
};
