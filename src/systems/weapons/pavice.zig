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
const animateBlocks = main.animateBlocks;
const World = game.World;
const ServerWorld = main.server.ServerWorld;
const items = main.items;
const ItemStack = items.ItemStack;
const random = main.random;
const systems = main.systems;
const entity = main.entity;
const Entity = entity.Entity;

const c = @import("c");

const @"cubyz:player_hand_animation" = main.entity.components.@"cubyz:player_hand_animation";
const @"cubyz:weapon_blocking" = main.entity.components.@"cubyz:weapon_blocking";
const @"cubyz:physics_body" = main.entity.components.@"cubyz:physics_body";
const @"cubyz:pavice_charging" = main.entity.components.@"cubyz:pavice_charging";

const entityComponent = main.entityComponent;
const swingsPerSecond = 1.5;

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
		animateHandObject();
	}
	pub fn renderHud(currentFrame: *graphics.vulkan.Frame, ambientLight: Vec3f, playerPos: Vec3d) void {
		_ = currentFrame;
		_ = ambientLight;
		_ = playerPos;
	}

	fn animateHandObject() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnyAnimation(main.game.player.id) orelse false)) return;

		animateBlock();
		animateBlockEnd();
		animateSwing();
	}
	fn animateSwing() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("paviceSwing")) orelse return)) return;

		const swingProgress = @"cubyz:player_hand_animation".client.getPredictedAnimationProgress(main.game.player.id) orelse 0;
		const restingPos = .{0.4, 1.15, -0.8};
		if (swingProgress < 0.5) {
			const pos = Vec3d{0.4 - sampleQuadratic(swingProgress*2), 1.15 - sampleQuadratic(swingProgress*2)*0.2, -0.8};
			var modelMatrix = Mat4f.identity();

			modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
			modelMatrix = modelMatrix.mul(Mat4f.rotationX(-std.math.pi*0.1*sampleQuadratic(swingProgress*2)));
			@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.player.id, modelMatrix);
		} else {
			const pos = Vec3d{restingPos[0] - 1 + sampleQuadratic(swingProgress*2), restingPos[1] - 0.2 + sampleQuadratic(swingProgress*2)*0.2, -0.8};
			var modelMatrix = Mat4f.identity();

			modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
			modelMatrix = modelMatrix.mul(Mat4f.rotationX(-std.math.pi*0.1*sampleQuadratic(swingProgress*2)));
			@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.player.id, modelMatrix);
		}
	}

	fn animateBlock() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("paviceBlock")) orelse return)) return;
		const pos = Vec3d{-1, 0.6, 0.0};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationX(-std.math.pi*0.25));
		@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.player.id, modelMatrix);
	}
	pub fn animateBlockEnd() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("paviceBlockEnd")) orelse return)) return;

		const swingProgress = @"cubyz:player_hand_animation".client.getPredictedAnimationProgress(main.game.player.id) orelse 0;
		const pos = Vec3d{-1 + swingProgress, 0.6, 0.0};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationX(-std.math.pi*0.25));
		modelMatrix = modelMatrix.mul(Mat4f.rotationY(std.math.pi*0.25*swingProgress));
		@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.player.id, modelMatrix);
	}
	fn animateCharge() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("paviceBlock")) orelse return)) return;
		const swingProgress = @"cubyz:player_hand_animation".client.getPredictedAnimationProgress(main.game.player.id) orelse 0;
		const extraShake = if (@mod(swingProgress*@as(f32, @floatFromInt(@"cubyz:player_hand_animation".client.get(main.game.player.id).?.length)), 2) == 0) 0 else 1 catch 0;
		const pos = Vec3d{-1 + extraShake, 0.6, 0.0};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationX(-std.math.pi*0.25));
		@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.player.id, modelMatrix);
	}
	fn sampleQuadratic(inputValue: f32) f32 {
		return std.math.clamp(inputValue*inputValue, 0, 1);
	}
	fn sampleQuadraticAlt(inputValue: f32) f32 {
		return std.math.clamp((inputValue - 1)*(inputValue - 1) + 1, 0, 1);
	}

	pub fn startSwing(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".client.isPlayingAnyAnimation(givenEntity) orelse true) {
			if (@"cubyz:player_hand_animation".client.isPlayingAnimation(givenEntity, main.Tag.find("paviceBlock")) orelse return) {
				@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("paviceCharge"), .animationLength = 5});
			}
			return;
		}
		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("paviceSwing"), .animationLength = 10/@as(i64, @intFromFloat(swingsPerSecond))});
	}
	pub fn block(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".isPlayingAnyAnimation(givenEntity) orelse true) return;

		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("paviceBlock"), .animationLength = 1, .loop = true});
		const blockComponent = @"cubyz:weapon_blocking".client.find(givenEntity);
		blockComponent.*.blockingPower = 0.5;
	}
	pub fn blockEnd(givenEntity: Entity) void {
		if (!(@"cubyz:player_hand_animation".client.get(givenEntity).?.animationName orelse return == main.Tag.find("paviceBlock"))) return;

		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("paviceBlockEnd"), .animationLength = 5});
		@"cubyz:weapon_blocking".client.unload(givenEntity);
	}
};
// ############################# Server only stuff ################################
pub const server = struct {
	var launchDirection: Vec3d = .{0, 0, 0};

	const animations = struct {
		var paviceSwing: @"cubyz:player_hand_animation".animationInfo = undefined;
		var paviceFullSwing: @"cubyz:player_hand_animation".animationInfo = undefined;
		var paviceBlock: @"cubyz:player_hand_animation".animationInfo = undefined;
		var paviceBlockEnd: @"cubyz:player_hand_animation".animationInfo = undefined;
		var paviceCharge: @"cubyz:player_hand_animation".animationInfo = undefined;
	};

	pub fn init() void {
		animations.paviceSwing = .{.animationName = main.Tag.find("paviceSwing"), .animationLength = 10/@as(i64, @intFromFloat(swingsPerSecond))};
		animations.paviceFullSwing = .{.animationName = main.Tag.find("paviceFullSwing"), .animationLength = 3};
		animations.paviceBlock = .{.animationName = main.Tag.find("paviceBlock"), .animationLength = 1, .loop = true};
		animations.paviceBlockEnd = .{.animationName = main.Tag.find("paviceBlockEnd"), .animationLength = 5};
		animations.paviceCharge = .{.animationName = main.Tag.find("paviceCharge"), .animationLength = 5};
	}
	pub fn deinit() void {}

	pub fn startSwing(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".isPlayingAnyAnimation(givenEntity) orelse true) {
			std.log.debug("tried to charge", .{});
			if (@"cubyz:player_hand_animation".isPlayingAnimation(givenEntity, animations.paviceBlock.animationName) orelse return) {
				std.log.debug("testesetse", .{});
				@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.paviceCharge);
				charge(givenEntity);
			}
			return;
		}
		if (!main.systems.systems.energy.server.payEnergyCost(givenEntity, -3).?) return;
		const entityPos: Vec3d = @"cubyz:physics_body".getPosition(givenEntity, .server) orelse return;
		const horizontalForward = vec.rotateZ(Vec3d{0, 1, 0}, -@"cubyz:physics_body".getRotation(givenEntity, .server).?[2]);
		const swingDistance = 3;
		@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.paviceSwing);
		main.systems.systems.pavice.server.knockBackSourceRot = horizontalForward;
		systems.systems.selection_box.server.selectInCube(entityPos + horizontalForward*Vec3d{swingDistance, swingDistance, swingDistance}, 0.5, dealDamage, .{.ignoreSelf = givenEntity});
		systems.systems.selection_box.server.selectInCube(entityPos + horizontalForward*Vec3d{swingDistance, swingDistance, swingDistance}, 0.5, launchEnemies, .{.ignoreSelf = givenEntity});
		const users = main.server.getUserList(main.stackAllocator);
		defer main.stackAllocator.free(users);
		for (users) |user| {
			main.network.protocols.generic_update.sendParticles(
				user.conn,
				"cubyz:poof",
				entityPos + horizontalForward*Vec3d{swingDistance, swingDistance, swingDistance},
				false,
				1,
				"",
			);
		}
	}
	pub fn block(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".isPlayingAnyAnimation(givenEntity) orelse true) return;
		@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.paviceBlock);
		const blockComponent = @"cubyz:weapon_blocking".server.find(givenEntity);
		blockComponent.*.blockingPower = 0.5;
	}
	pub fn blockEnd(givenEntity: Entity) void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(givenEntity, animations.paviceBlock.animationName) orelse true)) return;
		@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.paviceBlockEnd);
		@"cubyz:weapon_blocking".server.unload(givenEntity);
	}
	fn charge(givenEntity: Entity) void {
		if (!main.systems.systems.energy.server.payEnergyCost(givenEntity, -4).?) return;
		std.log.debug("charging", .{});
		//const entityPos: Vec3d = @"cubyz:physics_body".getPosition(givenEntity, .server) orelse return;
		const horizontalForward = vec.rotateZ(Vec3d{0, 1, 0}, -@"cubyz:physics_body".getRotation(givenEntity, .server).?[2]);
		const chargePower = 30;
		//@"cubyz:physics_body".setPosition(givenEntity, entityPos, .server);
		@"cubyz:physics_body".addVelocity(givenEntity, horizontalForward*Vec3d{chargePower, chargePower, chargePower} + Vec3d{0, 0, 3}, .server);
		@"cubyz:pavice_charging".server.add(givenEntity, 20);
	}

	fn dealDamage(givenEntity: Entity, sourcePosition: Vec3d, entityPosition: Vec3d) void {
		std.log.debug("damaged a entity", .{});
		_ = sourcePosition;
		_ = entityPosition;
		main.sync.addHealth(-1, .kill, .server, givenEntity);
	}

	var knockBackSourceRot: Vec3d = .{0, 0, 0};
	fn launchEnemies(givenEntity: Entity, sourcePosition: Vec3d, entityPosition: Vec3d) void {
		_ = sourcePosition;
		_ = entityPosition;
		const direction = vec.rotateZ(Vec3d{0, 1, 0}, -knockBackSourceRot[2]);
		@"cubyz:physics_body".setPosition(givenEntity, @"cubyz:physics_body".getPosition(givenEntity, .server).?, .server);
		@"cubyz:physics_body".addVelocity(givenEntity, direction*Vec3d{10, 10, 10}, .server);
	}
};
