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
		.addedPhase = .{.self = "playerHitbox", .targetSortPhase = "playerControls", .sortDirection = .after, .priority = 0},
		.addedFunctionStep = .{.targetPhase = "playerHitbox"},
		.function = update,
	};

	fn update(deltaTime: f64) void {
		const playerPos = @"cubyz:position".getPositionPointer(player.id, .client).?;
		if (physics.collision.collides(.client, .x, 0, playerPos.* + player.standingBoundingBoxExtent - player.crouchingBoundingBoxExtent, .{
			.min = -player.standingBoundingBoxExtent,
			.max = player.standingBoundingBoxExtent,
		}) == null) {
			if (player.onGround) {
				if (player.crouching) {
					player.crouchPerc += @floatCast(deltaTime*10);
				} else {
					player.crouchPerc -= @floatCast(deltaTime*10);
				}
				player.crouchPerc = std.math.clamp(player.crouchPerc, 0, 1);
			}

			const smoothPerc = player.crouchPerc*player.crouchPerc*(3 - 2*player.crouchPerc);

			const newOuterBox = (player.crouchingBoundingBoxExtent - player.standingBoundingBoxExtent)*@as(Vec3d, @splat(smoothPerc)) + player.standingBoundingBoxExtent;

			@"cubyz:position".setPosition(player.super.id, playerPos.* + newOuterBox - player.outerBoundingBoxExtent + Vec3d{0.0, 0.0, 0.0001*@abs(newOuterBox[2] - player.outerBoundingBoxExtent[2])}, .client);

			player.outerBoundingBoxExtent = newOuterBox;

			player.outerBoundingBox = .{
				.min = -player.outerBoundingBoxExtent,
				.max = player.outerBoundingBoxExtent,
			};
			player.eye.box = .{
				.min = -Vec3d{player.outerBoundingBoxExtent[0]*0.2, player.outerBoundingBoxExtent[1]*0.2, player.outerBoundingBoxExtent[2] - 0.2},
				.max = Vec3d{player.outerBoundingBoxExtent[0]*0.2, player.outerBoundingBoxExtent[1]*0.2, player.outerBoundingBoxExtent[2] - 0.05},
			};
			player.eye.desiredPos = (Vec3d{0, 0, 1.3 - player.crouchingBoundingBoxExtent[2]} - Vec3d{0, 0, 1.7 - player.standingBoundingBoxExtent[2]})*@as(Vec3f, @splat(smoothPerc)) + Vec3d{0, 0, 1.7 - player.standingBoundingBoxExtent[2]};
		}
	}
};
// ############################# Server only stuff ################################
pub const server = struct {
	pub fn init() void {}
	pub fn deinit() void {}
};
