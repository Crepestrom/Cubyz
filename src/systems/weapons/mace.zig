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

const @"cubyz:position" = main.entity.components.@"cubyz:position";

const c = @import("c");

const @"cubyz:player_hand_animation" = main.entity.components.@"cubyz:player_hand_animation";
const @"cubyz:weapon_blocking" = main.entity.components.@"cubyz:weapon_blocking";
const @"cubyz:velocity" = main.entity.components.@"cubyz:velocity";

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
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("maceWindup")) orelse return)) return;

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
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("maceFullCharged")) orelse return)) return;

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
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("maceSmallSwing")) orelse return)) return;

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
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("maceFullSwing")) orelse return)) return;
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
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("maceBlock")) orelse return)) return;

		const pos = Vec3d{-1, 0.6, 0.0};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationX(-std.math.pi*0.25));
		@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.player.id, modelMatrix);
	}
	pub fn animateBlockEnd() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("maceBlockEnd")) orelse return)) return;

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

		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("maceWindup"), .animationLength = 10, .onAnimationEnd = &chargedSwing});
	}
	fn chargedSwing(givenEntity: Entity) void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(givenEntity, main.Tag.find("maceWindup")) orelse return)) return;
		std.log.debug("fully charge strike on client", .{});
		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("maceFullCharged"), .animationLength = 2, .loop = true});
	}
	pub fn releaseSwing(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".client.get(givenEntity).?.animationName orelse return == main.Tag.find("maceWindup")) {
			@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("maceSmallSwing"), .animationLength = 3});
		} else if (@"cubyz:player_hand_animation".client.get(givenEntity).?.animationName orelse return == main.Tag.find("maceFullCharged")) {
			@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("maceFullSwing"), .animationLength = 3});
		}
	}
	pub fn block(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".isPlayingAnyAnimation(givenEntity) orelse true) return;

		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("maceBlock"), .animationLength = 1, .loop = true});
		const blockComponent = @"cubyz:weapon_blocking".client.find(givenEntity);
		blockComponent.*.blockingPower = 0.5;
	}
	pub fn blockEnd(givenEntity: Entity) void {
		if (!(@"cubyz:player_hand_animation".client.get(givenEntity).?.animationName orelse return == main.Tag.find("maceBlock"))) return;

		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("maceBlockEnd"), .animationLength = 5});
		@"cubyz:weapon_blocking".client.unload(givenEntity);
	}
};
// ############################# Server only stuff ################################
pub const server = struct {
	var launchDirection: Vec3d = .{0, 0, 0};

	const animations = struct {
		var maceWindup: @"cubyz:player_hand_animation".animationInfo = undefined;
		var maceFullCharged: @"cubyz:player_hand_animation".animationInfo = undefined;
		var maceSmallSwing: @"cubyz:player_hand_animation".animationInfo = undefined;
		var maceFullSwing: @"cubyz:player_hand_animation".animationInfo = undefined;
		var maceBlock: @"cubyz:player_hand_animation".animationInfo = undefined;
		var maceBlockEnd: @"cubyz:player_hand_animation".animationInfo = undefined;
	};

	pub fn init() void {
		animations.maceWindup = .{.animationName = main.Tag.find("maceWindup"), .animationLength = 10, .onAnimationEnd = &chargedSwing};
		animations.maceFullCharged = .{.animationName = main.Tag.find("maceFullCharged"), .animationLength = 2, .loop = true};
		animations.maceSmallSwing = .{.animationName = main.Tag.find("maceSmallSwing"), .animationLength = 3};
		animations.maceFullSwing = .{.animationName = main.Tag.find("maceFullSwing"), .animationLength = 3};
		animations.maceBlock = .{.animationName = main.Tag.find("maceBlock"), .animationLength = 1, .loop = true};
		animations.maceBlockEnd = .{.animationName = main.Tag.find("maceBlockEnd"), .animationLength = 5};
	}
	pub fn deinit() void {}

	pub fn startSwing(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".server.isPlayingAnyAnimation(givenEntity) orelse true) return;
		@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.maceWindup);
	}
	fn chargedSwing(givenEntity: Entity) void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(givenEntity, main.Tag.find("maceWindup")) orelse return)) return;
		std.log.debug("fully charge strike", .{});
		@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.maceFullCharged);
	}
	pub fn releaseSwing(givenEntity: Entity) void {
		std.log.debug("released the swing 1 {} {}", .{@"cubyz:player_hand_animation".server.get(givenEntity).?.animationName, main.Tag.find("maceWindup")});
		if (@"cubyz:player_hand_animation".server.get(givenEntity).?.animationName orelse return == main.Tag.find("maceWindup")) {
			@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.maceSmallSwing);
			systems.systems.selection_box.server.selectInCube(@"cubyz:position".server.getPosition(givenEntity) orelse return, 2, dealDamage, .{.ignoreSelf = givenEntity});
		} else if (@"cubyz:player_hand_animation".server.get(givenEntity).?.animationName orelse return == main.Tag.find("maceFullCharged")) {
			@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.maceFullSwing);
			systems.systems.selection_box.server.selectInCube(@"cubyz:position".server.getPosition(givenEntity) orelse return, 5, dealDamage, .{.ignoreSelf = givenEntity});
			@"cubyz:velocity".addVelocity(givenEntity, Vec3d{0, 0, 10}, .server);
			systems.systems.selection_box.server.selectInCube(@"cubyz:position".server.getPosition(givenEntity) orelse return, 5, launchEnemies, .{.ignoreSelf = givenEntity});
		}
		std.log.debug("released the swing 2 {}", .{@"cubyz:player_hand_animation".server.get(givenEntity).?.animationName});
	}

	pub fn block(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".isPlayingAnyAnimation(givenEntity) orelse true) return;
		@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.maceBlock);
		const blockComponent = @"cubyz:weapon_blocking".server.find(givenEntity);
		blockComponent.*.blockingPower = 0.5;
	}
	pub fn blockEnd(givenEntity: Entity) void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(givenEntity, main.Tag.find("maceBlock")) orelse true)) return;
		@"cubyz:player_hand_animation".setAnimation(givenEntity, animations.maceBlockEnd);
		@"cubyz:weapon_blocking".server.unload(givenEntity);
	}

	fn dealDamage(givenEntity: Entity, sourcePosition: Vec3d, entityPosition: Vec3d) void {
		std.log.debug("damaged a entity", .{});
		_ = sourcePosition;
		_ = entityPosition;
		main.sync.addHealth(-2, .kill, .server, givenEntity);
	}
	
	fn launchEnemies(givenEntity: Entity, sourcePosition: Vec3d, entityPosition: Vec3d) void {
		const direction = vec.normalize(sourcePosition - entityPosition);
		@"cubyz:velocity".addVelocity(givenEntity, direction*Vec3d{10, 10, 10}, .server);
	}
};
