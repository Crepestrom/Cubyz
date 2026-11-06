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
		.addedPhase = .{.self = "positionChange", .targetSortPhase = "playerHitbox", .sortDirection = .after, .priority = 0},
		.addedFunctionStep = .{.targetPhase = "positionChange"},
		.function = update,
	};

	fn update(deltaTime: f64) void {
		const playerPos = @"cubyz:physics_body".getPositionPointer(player.id, .client).?;
		const playerVel = @"cubyz:physics_body".getVelocityPointer(player.id, .client).?;

		const gravity: f64 = if (player.isFlying.load(.monotonic)) 0.0 else physics.baseGravity;
		const jumpHeight: f64 = if (player.jumping) player.jumpHeight else 0.0;
		var motion = physics.calculateMotion(.client, deltaTime, player.friction, player.volumeProperties, physics.playerDensity, playerPos.*, playerVel, player.acc, gravity, jumpHeight);

		{
			player.mutex.lock();
			defer player.mutex.unlock();

			var stepAmount: f64 = 0.0;
			if (!player.isGhost.load(.monotonic)) {
				const steppingHeightLimit = player.eye.pos[2] - player.eye.box.min[2];
				stepAmount = physics.calculateWallCollision(.client, &motion, playerPos, playerVel, &player.onGround, player.friction, player.outerBoundingBox, player.steppingHeight()[2], steppingHeightLimit, player.crouching);
			}
			physics.calculateEyeMovement(.client, deltaTime, playerPos.*, playerVel.*, &player.eye, stepAmount);
			var didCollide: bool = false;
			const wasOnGround = player.onGround;
			const prevPos = playerPos.*;
			const prevVel = playerVel.*;
			if (!player.isGhost.load(.monotonic)) {
				const bouncinessMultiplier: f64 = if (player.isFlying.load(.monotonic)) 0.0 else if (player.crouching) 0.5 else 1.0;
				didCollide = physics.calculateVerticalCollision(.client, deltaTime, playerPos, playerVel, &player.jumpCoyote, &player.onGround, player.outerBoundingBox, motion, bouncinessMultiplier);
				if (didCollide) {
					const velocityChange = @abs(@abs(prevVel[2]) - @abs(playerVel.*[2]));
					const damage: f32 = @floatCast(@round(@max((velocityChange*velocityChange)/(2*physics.baseGravity) - 7, 0))/2);
					if (damage > 0.01) {
						main.sync.addHealth(-damage, .fall, .client, player.id);
					}
				}
				physics.calculateVerticalCollisionEyeMovement(deltaTime, &player.eye, didCollide, player.onGround, wasOnGround, prevPos, playerPos.*, prevVel, playerVel.*, motion, player.steppingHeight()[2]);
				physics.collision.touchBlocks(.client, &player.super, player.outerBoundingBox, deltaTime);
			} else {
				playerPos.* += motion;
			}

			player.eye.pos = @max(player.eye.box.min, @min(player.eye.pos, player.eye.box.max));
			player.eye.coyote -= deltaTime;
			player.jumpCoyote -= deltaTime;
		}
	}
};
// ############################# Server only stuff ################################
pub const server = struct {
	pub fn init() void {}
	pub fn deinit() void {}
};
