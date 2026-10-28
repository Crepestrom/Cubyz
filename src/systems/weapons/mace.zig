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
		animateHandObject();
	}
	pub fn renderHud(ambientLight: Vec3f, playerPos: Vec3d) void {
		_ = ambientLight;
		_ = playerPos;
	}

	fn animateHandObject() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnyAnimation(main.game.player.id) orelse false)) return;

		animateSwordSwing();
		animateBlock();
		animateBlockEnd();
	}
	fn animateSwordSwing() void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(main.game.player.id, main.Tag.find("maceBlock")) orelse return)) return;

		const swingProgress = @"cubyz:player_hand_animation".client.getPredictedAnimationProgress(main.game.player.id) orelse 0;
		const swingWidth: f32 = 3;
		const horizontalMovement = (sampleQuadratic(swingProgress) - @min(sampleQuadratic(2*swingProgress), 1))*swingWidth;
		const pos = Vec3d{horizontalMovement, 2.0, 0.0};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationY(-0.5*std.math.pi*horizontalMovement));
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

		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("maceWindup"), .animationLength = 10});
	}
	pub fn releaseSwing(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".client.get(givenEntity).?.animationName orelse return == main.Tag.find("maceWindup")) {
			@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("maceSmallSwing"), .animationLength = 5});
		} else if (@"cubyz:player_hand_animation".client.get(givenEntity).?.animationName orelse return == main.Tag.find("maceFullCharged")) {
			@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("maceFullSwing"), .animationLength = 5});
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
	pub fn init() void {}
	pub fn deinit() void {}

	pub fn startSwing(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".server.isPlayingAnyAnimation(givenEntity) orelse true) return;
		std.log.debug("start swing mace on server", .{});
		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("maceSwing"), .animationLength = 10});
		systems.systems.selection_box.server.selectInCube(@"cubyz:position".server.getPosition(givenEntity) orelse return, 10, dealDamage, .{ .ignoreSelf = givenEntity });
		std.log.debug("testing", .{});
	}
	fn chargedSwing(givenEntity: Entity) void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(givenEntity, main.Tag.find("maceWindup")) orelse return)) return;
		std.log.debug("fully charge strike", .{});
		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("maceFullCharged"), .animationLength = 2, .loop = true});
	}
	pub fn releaseSwing(givenEntity: Entity) void {
		std.log.debug("released the swing", .{});
		if (@"cubyz:player_hand_animation".client.get(givenEntity).?.animationName orelse return == main.Tag.find("maceWindup")) {
			std.log.debug("small swing", .{});
			@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("maceSmallSwing"), .animationLength = 5});
		} else if (@"cubyz:player_hand_animation".client.get(givenEntity).?.animationName orelse return == main.Tag.find("maceFullCharged")) {
			std.log.debug("small swing", .{});
			@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("maceFullSwing"), .animationLength = 5});
		}
	}

	pub fn block(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".isPlayingAnyAnimation(givenEntity) orelse true) return;
		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("maceBlock"), .animationLength = 1, .loop = true});
		const blockComponent = @"cubyz:weapon_blocking".server.find(givenEntity);
		std.log.debug("start block server", .{});
		blockComponent.*.blockingPower = 0.5;
	}
	pub fn blockEnd(givenEntity: Entity) void {
		if (!(@"cubyz:player_hand_animation".isPlayingAnimation(givenEntity, main.Tag.find("maceBlock")) orelse true)) return;
		@"cubyz:player_hand_animation".setAnimation(givenEntity, .{.animationName = main.Tag.find("swordBlockEnd"), .animationLength = 5});
		std.log.debug("end block server", .{});
		@"cubyz:weapon_blocking".server.unload(givenEntity);
	}

	fn dealDamage(givenEntity: Entity) void {
		std.log.debug("damaged a entity", .{});
		main.sync.addHealth(-2, .kill, .server, givenEntity);
	}
};
