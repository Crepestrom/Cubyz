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
const components = main.entity.components;
const @"cubyz:hovering_ai" = components.@"cubyz:hovering_ai";
const @"cubyz:physics_body" = components.@"cubyz:physics_body";

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
};
// ############################# Server only stuff ################################
pub const server = struct {
	pub fn init() void {}
	pub fn deinit() void {}

	pub fn update() void {
		for (main.entity.components.@"cubyz:hovering_ai".server.components.denseToSparseIndex.items) |id| {
			const entityPos = @"cubyz:physics_body".getPosition(id, .server) orelse continue;
			const entityRot = @"cubyz:physics_body".getRotation(id, .server) orelse continue;
			const targetPos = @"cubyz:physics_body".getPosition(@enumFromInt(0), .server).?;
			const horizontalAngle: f64 = getAngleToPos(.{entityPos[0], entityPos[1]}, .{targetPos[0], targetPos[1]});
			const verticalAngle: f64 = getAngleToPos(.{std.math.sin(horizontalAngle)*entityPos[0] + std.math.cos(horizontalAngle)*entityPos[1], entityPos[2]}, .{std.math.sin(horizontalAngle)*targetPos[0] + std.math.cos(horizontalAngle)*targetPos[1], targetPos[2]});
			// const movement = std.math.sin(@as(f32, @floatFromInt(main.server.world.?.gameTime))/10)/16
			@"cubyz:physics_body".setRotation(id, Vec3f{@floatCast(verticalAngle - std.math.pi/2.0), entityRot[1], @floatCast(horizontalAngle)}, .server);
			const combinedPos = vec.normalize(entityPos - targetPos);
			const addedPos: Vec3d = .{@abs(combinedPos[0])*std.math.sin(horizontalAngle)*@abs(std.math.sin(verticalAngle)), @abs(combinedPos[1])*std.math.cos(horizontalAngle)*@abs(std.math.sin(verticalAngle)), @abs(combinedPos[2])*std.math.cos(verticalAngle)};
			@"cubyz:physics_body".setVelocity(id, addedPos, .server);
			@"cubyz:physics_body".setPosition(id, entityPos + @"cubyz:physics_body".getVelocity(id, .server).?, .server);
		}
	}

	fn getAngleToPos(startPos: vec.Vec2d, endPos: vec.Vec2d) f64 {
		if ((startPos[1] - endPos[1]) == 0) return @as(f64, std.math.sign(startPos[0] - endPos[0]))*std.math.pi;
		return @as(f64, @max(std.math.sign(startPos[1] - endPos[1]), 0))*std.math.pi + std.math.atan(((startPos[0] - endPos[0])/(startPos[1] - endPos[1])));
	}

	fn moveAtRotation(position: *Vec3d, rotation: Vec3f) void {
		const horizontalAngle: f32 = rotation[0];
		const verticalAngle: f32 = rotation[2];
		//.{@abs(combinedPos[0])*std.math.sin(horizontalAngle)*@abs(std.math.sin(verticalAngle)), @abs(combinedPos[1])*std.math.cos(horizontalAngle)*@abs(std.math.sin(verticalAngle)), @abs(combinedPos[2])*std.math.cos(verticalAngle)}
	}
};
