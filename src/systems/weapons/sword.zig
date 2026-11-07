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
const swingsPerSecond = 2;
const swingEnergyCost = -2;

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
		animateSwordSwing();
		animateBlock();
		animateBlockEnd();
	}
	fn animateSwordSwing() void {
		if (!(@"cubyz:player_hand_animation".client.get(main.game.player.id).?.animationName orelse return == main.Tag.find("swordSwing"))) return;
		const swingProgress = @"cubyz:player_hand_animation".client.getPredictedAnimationProgress(main.game.player.id) orelse 0;
		const swingWidth: f32 = 3;
		const horizontalMovement = (sampleQuadratic(@max(2*swingProgress - 1, 0)) - @min(sampleQuadratic(2*swingProgress), 1))*swingWidth;
		const pos = Vec3d{horizontalMovement, 2.0, 0.0};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationX(-std.math.pi*0.5));
		modelMatrix = modelMatrix.mul(Mat4f.rotationY(0.5*std.math.pi));
		modelMatrix = modelMatrix.mul(Mat4f.rotationY(-0.5*std.math.pi*swingProgress));
		@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.player.id, modelMatrix);
	}
	fn animateBlock() void {
		if (!(@"cubyz:player_hand_animation".client.get(main.game.player.id).?.animationName orelse return == main.Tag.find("swordBlock"))) return;
		const pos = Vec3d{-1, 0.6, 0.0};
		var modelMatrix = Mat4f.identity();

		modelMatrix = modelMatrix.mul(Mat4f.translation(@floatCast(pos)));
		modelMatrix = modelMatrix.mul(Mat4f.rotationX(-std.math.pi*0.25));
		@"cubyz:player_hand_animation".client.setAnimationMatrix(main.game.player.id, modelMatrix);
	}
	pub fn animateBlockEnd() void {
		if (!(@"cubyz:player_hand_animation".client.get(main.game.player.id).?.animationName orelse return == main.Tag.find("swordBlockEnd"))) return;
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

	pub fn swingSword(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".isPlayingAnyAnimation(givenEntity) orelse true) return;
		if (!main.systems.systems.energy.client.payEnergyCost(givenEntity, swingEnergyCost).?) return;
		@"cubyz:player_hand_animation".client.setPredictedAnimation(givenEntity, .{.animationName = main.Tag.find("swordSwing"), .animationLength = 10/swingsPerSecond});
	}
	pub fn block(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".isPlayingAnyAnimation(givenEntity) orelse true) {
			if (!(@"cubyz:player_hand_animation".isPlayingAnimation(givenEntity, main.Tag.find("swordBlockEnd")) orelse false)) return;
		}
		@"cubyz:player_hand_animation".client.setPredictedAnimation(givenEntity, .{.animationName = main.Tag.find("swordBlock"), .animationLength = 1, .loop = true});
		const blockComponent = @"cubyz:weapon_blocking".client.find(givenEntity);
		blockComponent.*.blockingPower = 0.5;
	}
	pub fn blockEnd(givenEntity: Entity) void {
		if (!(@"cubyz:player_hand_animation".client.get(main.game.player.id).?.animationName orelse return == main.Tag.find("swordBlock"))) return;
		@"cubyz:player_hand_animation".client.setPredictedAnimation(givenEntity, .{.animationName = main.Tag.find("swordBlockEnd"), .animationLength = 5});
		@"cubyz:weapon_blocking".client.unload(givenEntity);
	}
};
// ############################# Server only stuff ################################
pub const server = struct {
	pub fn init() void {}
	pub fn deinit() void {}
	
	pub fn swingSword(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".isPlayingAnyAnimation(givenEntity) orelse true) return;
		if (!main.systems.systems.energy.server.payEnergyCost(givenEntity, -2).?) return;

		const entityPos: Vec3d = @"cubyz:physics_body".getPosition(givenEntity, .server) orelse return;
		const horizontalForward: Vec3d = vec.rotateZ(Vec3d{0, 1, 0}, -@"cubyz:physics_body".getRotation(givenEntity, .server).?[2]);
		const chargePower = 2;
		const swingDistance = 4;
		
		@"cubyz:player_hand_animation".server.setAnimation(givenEntity, .{.animationName = main.Tag.find("swordSwing"), .animationLength = 10/swingsPerSecond});
		systems.systems.selection_box.server.selectInCube(entityPos + horizontalForward*Vec3d{swingDistance, swingDistance, swingDistance}, 0.5, dealDamage, .{.ignoreSelf = givenEntity});
		//@"cubyz:physics_body".setPosition(givenEntity, entityPos, .server);
		@"cubyz:physics_body".addVelocity(givenEntity, horizontalForward*Vec3d{chargePower, chargePower, chargePower}, .server);
		
		const users = main.server.getUserList(main.stackAllocator);
		defer main.stackAllocator.free(users);
		for (users) |user| {
			summonPoof(entityPos + horizontalForward*Vec3d{swingDistance, swingDistance, swingDistance}, user);
			summonPoof(entityPos + vec.rotateZ(horizontalForward*Vec3d{swingDistance, swingDistance, swingDistance}, std.math.pi*0.1), user);
			summonPoof(entityPos + vec.rotateZ(horizontalForward*Vec3d{swingDistance, swingDistance, swingDistance}, std.math.pi*0.2), user);
			summonPoof(entityPos + vec.rotateZ(horizontalForward*Vec3d{swingDistance, swingDistance, swingDistance}, std.math.pi*-0.1), user);
			summonPoof(entityPos + vec.rotateZ(horizontalForward*Vec3d{swingDistance, swingDistance, swingDistance}, std.math.pi*-0.2), user);
		}
	}
	pub fn block(givenEntity: Entity) void {
		if (@"cubyz:player_hand_animation".isPlayingAnyAnimation(givenEntity) orelse true) {
			if (!(@"cubyz:player_hand_animation".isPlayingAnimation(givenEntity, main.Tag.find("swordBlockEnd")) orelse false)) return;
		}
		@"cubyz:player_hand_animation".server.setAnimation(givenEntity, .{.animationName = main.Tag.find("swordBlock"), .animationLength = 1, .loop = true});
		const blockComponent = @"cubyz:weapon_blocking".server.find(givenEntity);
		blockComponent.*.blockingPower = 0.5;
	}
	pub fn blockEnd(givenEntity: Entity) void {
		if (!(@"cubyz:player_hand_animation".server.get(main.game.player.id).?.animationName orelse return == main.Tag.find("swordBlock"))) return;
		@"cubyz:player_hand_animation".server.setAnimation(givenEntity, .{.animationName = main.Tag.find("swordBlockEnd"), .animationLength = 5});
		@"cubyz:weapon_blocking".server.unload(givenEntity);
	}

	fn dealDamage(givenEntity: Entity, sourcePosition: Vec3d, entityPosition: Vec3d) void {
		_ = sourcePosition;
		_ = entityPosition;
		main.sync.addHealth(-1, .kill, .server, givenEntity);
	}

	fn summonPoof(pos: Vec3d, user: *main.server.User) void {
		main.network.protocols.generic_update.sendParticles(
			user.conn,
			"cubyz:poof",
			pos,
			false,
			1,
			"",
		);
	}
};
