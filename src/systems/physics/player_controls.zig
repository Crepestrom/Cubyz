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
		.addedPhase = .{.self = "playerControls", .targetSortPhase = "start", .sortDirection = .after, .priority = 0},
		.addedFunctionStep = .{.targetPhase = "playerControls"},
		.function = update,
	};

	fn update(deltaTime: f64) void {
		std.log.debug("testing", .{});
		const playerPos = @"cubyz:position".getPositionPointer(main.game.player.id, .client).?;
		main.physics.calculateVolumeProperties(.client, &main.game.player.volumeProperties, playerPos.*, main.game.player.outerBoundingBox, main.physics.playerAirTerminalVelocity);
		if (main.game.player.isFlying.load(.monotonic)) {
			main.game.player.friction = .{.current = 20, .mobile = 20};
		} else {
			main.physics.calculateFriction(.client, &main.game.player.volumeProperties, &main.game.player.friction, playerPos.*, main.game.player.outerBoundingBox, main.game.player.onGround);
		}
		main.game.player.acc = Vec3d{0, 0, 0};
		const speedMultiplier: f32 = if (main.game.player.hyperSpeed.load(.monotonic)) 4.0 else 1.0;

		const density = if (main.game.player.isFlying.load(.monotonic)) 0.0 else main.game.player.volumeProperties.density;
		const maxDensity = if (main.game.player.isFlying.load(.monotonic)) 0.0 else main.game.player.volumeProperties.maxDensity;

		main.game.player.jumping = false;
		main.game.player.jumpCooldown -= deltaTime;
		// At equillibrium we want to have dv/dt = a - λv = 0 → a = λ*v
		const fricMul = speedMultiplier*main.game.player.friction.mobile;

		const horizontalForward = vec.rotateZ(Vec3d{0, 1, 0}, -camera.rotation[2]);
		const forward = vec.normalize(std.math.lerp(horizontalForward, camera.direction, @as(Vec3d, @splat(density/@max(1.0, maxDensity)))));
		const right = Vec3d{-horizontalForward[1], horizontalForward[0], 0};
		var movementDir: Vec3d = .{0, 0, 0};

		main.game.player.inputSpeed = 0;

		if (main.Window.grabbed) {
			const walkingSpeed: f64 = if (main.game.player.crouching) 2.5 else 4.5;
			var movementSpeed: f64 = walkingSpeed*@min(1, vec.length(Vec2f{
				@max(keyboard.key("forward").value, keyboard.key("backward").value),
				@max(keyboard.key("left").value, keyboard.key("right").value),
			}));

			var isSprintingOnGround = false;
			var speedModifier = walkingSpeed;
			if (keyboard.key("sprint").pressed and !main.game.player.crouching) {
				if (main.game.player.isGhost.load(.monotonic)) {
					speedModifier = 128;
				} else if (main.game.player.isFlying.load(.monotonic)) {
					speedModifier = 32;
				} else {
					isSprintingOnGround = true;
				}
			}

			if (keyboard.key("forward").value > 0.0) {
				var forwardSpeedModifier = speedModifier;
				if (isSprintingOnGround) forwardSpeedModifier = 8;

				const totalSpeed = forwardSpeedModifier*keyboard.key("forward").value;
				movementSpeed = @max(movementSpeed, totalSpeed);
				movementDir += forward*@as(Vec3d, @splat(totalSpeed));
			}
			if (keyboard.key("backward").value > 0.0) {
				const totalSpeed = speedModifier*keyboard.key("backward").value;
				movementSpeed = @max(movementSpeed, totalSpeed);
				movementDir += forward*@as(Vec3d, @splat(-totalSpeed));
			}
			if (keyboard.key("left").value > 0.0) {
				const totalSpeed = speedModifier*keyboard.key("left").value;
				movementSpeed = @max(movementSpeed, totalSpeed);
				movementDir += right*@as(Vec3d, @splat(totalSpeed));
			}
			if (keyboard.key("right").value > 0.0) {
				const totalSpeed = speedModifier*keyboard.key("right").value;
				movementSpeed = @max(movementSpeed, totalSpeed);
				movementDir += right*@as(Vec3d, @splat(-totalSpeed));
			}
			if (keyboard.key("jump").pressed) {
				if (main.game.player.isFlying.load(.monotonic)) {
					if (keyboard.key("sprint").pressed) {
						if (main.game.player.isGhost.load(.monotonic)) {
							movementSpeed = @max(movementSpeed, 60);
							movementDir[2] += 60;
						} else {
							movementSpeed = @max(movementSpeed, 25);
							movementDir[2] += 25;
						}
					} else {
						movementSpeed = @max(movementSpeed, 5.5);
						movementDir[2] += 5.5;
					}
				} else if ((main.game.player.onGround or main.game.player.jumpCoyote > 0.0) and main.game.player.jumpCooldown <= 0) {
					main.game.player.jumping = true;
					main.game.player.jumpCooldown = main.game.player.jumpCooldownConstant;
					if (!main.game.player.onGround) {
						main.game.player.eye.coyote = 0;
					}
					main.game.player.jumpCoyote = 0;
				} else if (!keyboard.key("fall").pressed) {
					movementSpeed = @max(movementSpeed, walkingSpeed);
					movementDir[2] += walkingSpeed;
				}
			} else {
				main.game.player.jumpCooldown = 0;
			}
			if (keyboard.key("fall").pressed) {
				if (main.game.player.isFlying.load(.monotonic)) {
					if (keyboard.key("sprint").pressed) {
						if (main.game.player.isGhost.load(.monotonic)) {
							movementSpeed = @max(movementSpeed, 60);
							movementDir[2] -= 60;
						} else {
							movementSpeed = @max(movementSpeed, 25);
							movementDir[2] -= 25;
						}
					} else {
						movementSpeed = @max(movementSpeed, 5.5);
						movementDir[2] -= 5.5;
					}
				} else if (!keyboard.key("jump").pressed) {
					movementSpeed = @max(movementSpeed, walkingSpeed);
					movementDir[2] -= walkingSpeed;
				}
			}

			if (movementSpeed != 0 and vec.lengthSquare(movementDir) != 0) {
				if (vec.lengthSquare(movementDir) > movementSpeed*movementSpeed) {
					movementDir = vec.normalize(movementDir);
				} else {
					movementDir /= @splat(movementSpeed);
				}
				main.game.player.acc += movementDir*@as(Vec3d, @splat(movementSpeed*fricMul));
			}

			const newSlot: i32 = @as(i32, @intCast(main.game.player.selectedSlot)) -% main.Window.scrollOffsetInteger;
			main.game.player.selectedSlot = @intCast(@mod(newSlot, 12));

			const newPos = Vec2f{
				@floatCast(main.keyboard.key("cameraRight").value - main.keyboard.key("cameraLeft").value),
				@floatCast(main.keyboard.key("cameraDown").value - main.keyboard.key("cameraUp").value),
			}*@as(Vec2f, @splat(std.math.pi*settings.controllerSensitivity));
			main.game.camera.moveRotation(newPos[0]/64.0, newPos[1]/64.0);

			main.game.player.inputSpeed = movementSpeed*speedMultiplier;
		}

		main.game.player.crouching = main.Window.grabbed and keyboard.key("crouch").pressed and !main.game.player.isFlying.load(.monotonic);
	}
};
// ############################# Server only stuff ################################
pub const server = struct {
	pub fn init() void {}
	pub fn deinit() void {}
};
