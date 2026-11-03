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
		switch (params.useType) {
			.normal => main.systems.systems.warhammer.client.startSwing(params.entity),
			.alt => main.systems.systems.warhammer.client.block(params.entity),
			.normalEnd => main.systems.systems.warhammer.client.releaseSwing(params.entity),
			.altEnd => main.systems.systems.warhammer.client.blockEnd(params.entity),
		}
	} else if (main.sync.threadContext == .server) {
		switch (params.useType) {
			.normal => main.systems.systems.warhammer.server.startSwing(params.entity),
			.alt => main.systems.systems.warhammer.server.block(params.entity),
			.normalEnd => main.systems.systems.warhammer.server.releaseSwing(params.entity),
			.altEnd => main.systems.systems.warhammer.server.blockEnd(params.entity),
		}
	}
	return .handled;
}
