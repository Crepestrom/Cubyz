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
		animateHandObject();
	}
	pub fn renderHud(currentFrame: *graphics.vulkan.Frame, ambientLight: Vec3f, playerPos: Vec3d) void {
		_ = currentFrame;
		_ = ambientLight;
		_ = playerPos;
	}

	fn animateHandObject() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnyAnimation(main.game.player.id) orelse false)) return;

		animateSwingWindup();
		animateFullCharged();
		animateBlock();
		animateBlockEnd();
		animateSmallSwing();
		animateFullSwing();
	}
	fn animateSwingWindup() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("warhammerWindup")) orelse return)) return;

		const swingProgress = @"cubyz:player_hand_animation".client.getPredictedAnimationProgress(main.game.player.id) orelse 0;
		const horizontalMovement = sampleQuadratic(swingProgress);
		const pos = Vec3d{0.4, 1.45, -0.3 + horizontalMovement*1.2};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationZ(-std.math.pi*0.47));
		modelMatrix = modelMatrix.mul(Mat4f.rotationY(std.math.pi*0.25 + 0.3*std.math.pi*horizontalMovement));
		@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.player.id, modelMatrix);
	}
	fn animateFullCharged() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("warhammerFullCharged")) orelse return)) return;

		const swingProgress = @"cubyz:player_hand_animation".client.getPredictedAnimationProgress(main.game.player.id) orelse 0;
		const pos = Vec3d{0.4, 1.45, 0.9};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.scale(@splat(1 + swingProgress*0.3)));
		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationZ(-std.math.pi*0.47));
		modelMatrix = modelMatrix.mul(Mat4f.rotationY(std.math.pi*0.55));
		@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.player.id, modelMatrix);
	}

	fn animateSmallSwing() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("warhammerSmallSwing")) orelse return)) return;

		const swingProgress = @"cubyz:player_hand_animation".client.getPredictedAnimationProgress(main.game.player.id) orelse 0;
		const pos = Vec3d{0.4, 1.45 + swingProgress*0.5, 0.6 - swingProgress*1.5};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.scale(@splat(1.2)));
		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationZ(-std.math.pi*0.47));
		modelMatrix = modelMatrix.mul(Mat4f.rotationY(std.math.pi*0.50 - swingProgress*1.6));
		@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.player.id, modelMatrix);
	}
	fn animateFullSwing() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("warhammerFullSwing")) orelse return)) return;
		const swingProgress = @"cubyz:player_hand_animation".client.getPredictedAnimationProgress(main.game.player.id) orelse 0;
		const pos = Vec3d{0.4, 1.45 + swingProgress*0.5, 0.9 - swingProgress*2};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.scale(@splat(1.5)));
		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationZ(-std.math.pi*0.47));
		modelMatrix = modelMatrix.mul(Mat4f.rotationY(std.math.pi*0.55 - swingProgress*1.8));
		@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.player.id, modelMatrix);
	}

	fn animateBlock() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("warhammerBlock")) orelse return)) return;

		const pos = Vec3d{-1, 0.6, 0.0};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationX(-std.math.pi*0.25));
		@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.player.id, modelMatrix);
	}
	pub fn animateBlockEnd() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("warhammerBlockEnd")) orelse return)) return;

		const swingProgress = @"cubyz:player_hand_animation".client.getPredictedAnimationProgress(main.game.player.id) orelse 0;
		const pos = Vec3d{-1 + swingProgress, 0.6, 0.0};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationX(-std.math.pi*0.25));
		modelMatrix = modelMatrix.mul(Mat4f.rotationY(std.math.pi*0.25*swingProgress));
		@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.player.id, modelMatrix);
	}
	fn sampleQuadratic(inputValue: f32) f32 {
		return std.math.clamp(inputValue*inputValue, 0, 1);
	}
	fn sampleQuadraticAlt(inputValue: f32) f32 {
		return std.math.clamp((inputValue - 1)*(inputValue - 1) + 1, 0, 1);
	}

	pub fn startSwing(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".client.isPlayingAnyAnimation(givenEntity) orelse true) return;

		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("warhammerWindup"), .animationLength = 10, .onAnimationEnd = &chargedSwing});
	}
	fn chargedSwing(givenEntity: Entity) void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(givenEntity, main.Tag.find("warhammerWindup")) orelse return)) return;
		std.log.debug("fully charge strike on client", .{});
		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("warhammerFullCharged"), .animationLength = 2, .loop = true});
	}
	pub fn releaseSwing(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".client.get(givenEntity).?.animationName orelse return == main.Tag.find("warhammerWindup")) {
			@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("warhammerSmallSwing"), .animationLength = 3});
		} else if (@"cubyz:player_hand_animation".client.get(givenEntity).?.animationName orelse return == main.Tag.find("warhammerFullCharged")) {
			@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("warhammerFullSwing"), .animationLength = 3});
		}
	}
	pub fn block(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".isPlayingAnyAnimation(givenEntity) orelse true) return;

		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("warhammerBlock"), .animationLength = 1, .loop = true});
		const blockComponent = @"cubyz:weapon_blocking".client.find(givenEntity);
		blockComponent.*.blockingPower = 0.5;
	}
	pub fn blockEnd(givenEntity: Entity) void {
		if (!(@"cubyz:player_hand_animation".client.get(givenEntity).?.animationName orelse return == main.Tag.find("warhammerBlock"))) return;

		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("warhammerBlockEnd"), .animationLength = 5});
		@"cubyz:weapon_blocking".client.unload(givenEntity);
	}
};
// ############################# Server only stuff ################################
pub const server = struct {
	var launchDirection: Vec3d = .{0, 0, 0};

	const animations = struct {
		var warhammerWindup: @"cubyz:player_hand_animation".animationInfo = undefined;
		var warhammerFullCharged: @"cubyz:player_hand_animation".animationInfo = undefined;
		var warhammerSmallSwing: @"cubyz:player_hand_animation".animationInfo = undefined;
		var warhammerFullSwing: @"cubyz:player_hand_animation".animationInfo = undefined;
		var warhammerBlock: @"cubyz:player_hand_animation".animationInfo = undefined;
		var warhammerBlockEnd: @"cubyz:player_hand_animation".animationInfo = undefined;
	};

	pub fn init() void {
		animations.warhammerWindup = .{.animationName = main.Tag.find("warhammerWindup"), .animationLength = 10, .onAnimationEnd = &chargedSwing};
		animations.warhammerFullCharged = .{.animationName = main.Tag.find("warhammerFullCharged"), .animationLength = 2, .loop = true};
		animations.warhammerSmallSwing = .{.animationName = main.Tag.find("warhammerSmallSwing"), .animationLength = 3};
		animations.warhammerFullSwing = .{.animationName = main.Tag.find("warhammerFullSwing"), .animationLength = 3};
		animations.warhammerBlock = .{.animationName = main.Tag.find("warhammerBlock"), .animationLength = 1, .loop = true};
		animations.warhammerBlockEnd = .{.animationName = main.Tag.find("warhammerBlockEnd"), .animationLength = 5};
	}
	pub fn deinit() void {}

	pub fn startSwing(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".server.isPlayingAnyAnimation(givenEntity) orelse true) return;
		@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.warhammerWindup);
	}
	fn chargedSwing(givenEntity: Entity) void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(givenEntity, main.Tag.find("warhammerWindup")) orelse return)) return;
		std.log.debug("fully charge strike", .{});
		@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.warhammerFullCharged);
	}
	pub fn releaseSwing(givenEntity: Entity) void {
		const entityPos: Vec3d = @"cubyz:physics_body".getPosition(givenEntity, .server) orelse return;
		const horizontalForward = vec.rotateZ(Vec3d{0, 1, 0}, -@"cubyz:physics_body".getRotation(givenEntity, .server).?[2]);
		const swingDistance = 3;

		if (@"cubyz:player_hand_animation".server.get(givenEntity).?.animationName orelse return == main.Tag.find("warhammerWindup")) {
			
			@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.warhammerSmallSwing);
			systems.systems.selection_box.server.selectInCube(entityPos + horizontalForward*Vec3d{swingDistance, swingDistance, swingDistance}, 0.75, dealDamage, .{.ignoreSelf = givenEntity});

			const users = main.server.getUserList(main.stackAllocator);
			defer main.stackAllocator.free(users);
			for (users) |user| {
				main.network.protocols.generic_update.sendParticles(
					user.conn,
					"cubyz:poof",
					entityPos + horizontalForward*Vec3d{swingDistance, swingDistance, swingDistance},
					false,
					10,
					"",
				);
			}

		} else if (@"cubyz:player_hand_animation".server.get(givenEntity).?.animationName orelse return == main.Tag.find("warhammerFullCharged")) {
			
			
			@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.warhammerFullSwing);
			//@"cubyz:physics_body".setPosition(givenEntity, entityPos, .server);
			const selfKnockback = -5;
			@"cubyz:physics_body".addVelocity(givenEntity, Vec3d{0, 0, 10} + horizontalForward*Vec3d{selfKnockback, selfKnockback, selfKnockback} + Vec3d{0, 0, 3}, .server);
			systems.systems.selection_box.server.selectInCube(entityPos + horizontalForward*Vec3d{swingDistance, swingDistance, swingDistance}, 1.25, dealBigDamage, .{.ignoreSelf = givenEntity});
			systems.systems.selection_box.server.selectInCube(entityPos + horizontalForward*Vec3d{swingDistance, swingDistance, swingDistance}, 1.25, launchEnemies, .{.ignoreSelf = givenEntity});
		
			const users = main.server.getUserList(main.stackAllocator);
			defer main.stackAllocator.free(users);
			for (users) |user| {
				main.network.protocols.generic_update.sendParticles(
					user.conn,
					"cubyz:flame",
					entityPos + horizontalForward*Vec3d{swingDistance, swingDistance, swingDistance},
					false,
					10,
					"",
				);
			}
		}
	}

	pub fn block(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".isPlayingAnyAnimation(givenEntity) orelse true) return;
		@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.warhammerBlock);
		const blockComponent = @"cubyz:weapon_blocking".server.find(givenEntity);
		blockComponent.*.blockingPower = 0.5;
	}
	pub fn blockEnd(givenEntity: Entity) void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(givenEntity, main.Tag.find("warhammerBlock")) orelse true)) return;
		@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.warhammerBlockEnd);
		@"cubyz:weapon_blocking".server.unload(givenEntity);
	}

	fn dealDamage(givenEntity: Entity, sourcePosition: Vec3d, entityPosition: Vec3d) void {
		std.log.debug("damaged a entity", .{});
		_ = sourcePosition;
		_ = entityPosition;
		main.sync.addHealth(-2, .kill, .server, givenEntity);
	}

	fn dealBigDamage(givenEntity: Entity, sourcePosition: Vec3d, entityPosition: Vec3d) void {
		std.log.debug("damaged a entity", .{});
		_ = sourcePosition;
		_ = entityPosition;
		main.sync.addHealth(-3, .kill, .server, givenEntity);
	}
	
	fn launchEnemies(givenEntity: Entity, sourcePosition: Vec3d, entityPosition: Vec3d) void {
		const direction = vec.normalize(entityPosition - sourcePosition);
		@"cubyz:physics_body".setPosition(givenEntity, @"cubyz:physics_body".getPosition(givenEntity, .server).?, .server);
		@"cubyz:physics_body".addVelocity(givenEntity, direction*Vec3d{10, 10, 10}, .server);
	}
};
