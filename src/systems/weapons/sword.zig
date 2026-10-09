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
		if (!(@"cubyz:player_hand_animation".client.isPlayingAnimation(main.game.Player.id) orelse false)) return;
		animateSwordSwing();
		animateBlock();
		
	}
	fn animateSwordSwing() void {
		if (!(@"cubyz:player_hand_animation".client.get(main.game.Player.id).?.animationName orelse return == main.Tag.find("swordSwing"))) return;
		const swingProgress = @"cubyz:player_hand_animation".client.getPredictedAnimationProgress(main.game.Player.id) orelse 0;
		const swingWidth: f32 = 1;
		const horizontalMovement = (sampleQuadratic(@max(2*swingProgress - 1, 0)) - @min(sampleQuadratic(2*swingProgress), 1))*swingWidth;
		const pos = Vec3d{horizontalMovement, 1.0, 0.0};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationX(-std.math.pi*0.5));
		@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.Player.id, modelMatrix);
	}
	fn animateBlock() void {
		if (!(@"cubyz:player_hand_animation".client.get(main.game.Player.id).?.animationName orelse return == main.Tag.find("swordBlock"))) return;
		const pos = Vec3d{-1, 0.6, 0.0};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationX(-std.math.pi*0.25));
		@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.Player.id, modelMatrix);
	}
	fn sampleQuadratic(inputValue: f32) f32 {
		return std.math.clamp(inputValue*inputValue, 0, 1);
	}
	fn sampleQuadraticAlt(inputValue: f32) f32 {
		return std.math.clamp((inputValue - 1)*(inputValue - 1) + 1, 0, 1);
	}

	pub fn swingSword(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".server.isPlayingAnimation(givenEntity) orelse true) return;
		@"cubyz:player_hand_animation".client.setPredictedAnimation(givenEntity, .{.animationName = main.Tag.find("swordSwing"), .animationLength = 10});
	}
	pub fn block(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".server.isPlayingAnimation(givenEntity) orelse true) return;
		@"cubyz:player_hand_animation".client.setPredictedAnimation(givenEntity, .{.animationName = main.Tag.find("swordBlock"), .animationLength = 2});
	}
};
// ############################# Server only stuff ################################
pub const server = struct {
	pub fn init() void {}
	pub fn deinit() void {}
	
	pub fn swingSword(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".server.isPlayingAnimation(givenEntity) orelse true) return;
		@"cubyz:player_hand_animation".server.setAnimation(givenEntity, .{.animationName = main.Tag.find("swordSwing"), .animationLength = 10});
		systems.systems.selection_box.server.selectInCube(@"cubyz:position".server.getPosition(givenEntity) orelse return, 5, dealDamage, .{ .ignoreSelf = givenEntity });
	}
	pub fn block(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".server.isPlayingAnimation(givenEntity) orelse true) return;
		@"cubyz:player_hand_animation".server.setAnimation(givenEntity, .{.animationName = main.Tag.find("swordBlock"), .animationLength = 2});
	}

	fn dealDamage(givenEntity: Entity) void {
		std.log.debug("damaged a entity", .{});
		main.sync.addHealth(-2, .kill, .server, givenEntity);
	}
};
