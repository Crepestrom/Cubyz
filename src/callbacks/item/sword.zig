const std = @import("std");

const main = @import("main");
const Block = main.blocks.Block;
const vec = main.vec;
const Vec3i = vec.Vec3i;
const ZonElement = main.ZonElement;

const @"cubyz:player_hand_animation" = main.entity.components.@"cubyz:player_hand_animation";
windowName: []const u8,

pub fn init(_: ZonElement, _: main.callbacks.Creator) ?*@This() {
	return @as(*@This(), undefined);
}

pub fn run(self: *@This(), params: main.callbacks.UseItemCallback.Params) main.callbacks.Result {
	_ = self;
	if (main.sync.threadContext == .client) {
		@"cubyz:player_hand_animation".client.setPredictedAnimation(params.entity, main.Tag.find("swordSwing"));
	}
	return .handled;
}
