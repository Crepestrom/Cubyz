const std = @import("std");

const main = @import("main");
const chunk = main.chunk;
const game = main.game;
const graphics = main.graphics;
const ZonElement = main.ZonElement;
const renderer = main.renderer;
const settings = main.settings;
const utils = main.utils;
const BinaryReader = utils.BinaryReader;
const vec = main.vec;
const Mat4f = vec.Mat4f;
const Vec3d = vec.Vec3d;
const Vec3f = vec.Vec3f;
const Vec4f = vec.Vec4f;
const NeverFailingAllocator = main.heap.NeverFailingAllocator;
const @"cubyz:physics_body" = main.entity.components.@"cubyz:physics_body";

const c = @import("c");

interpolatedValues: utils.GenericInterpolation(6) = undefined,
_interpolationPos: [6]f64 = undefined,
_interpolationVel: [6]f64 = undefined,

width: f64,
height: f64,

id: main.entity.Entity,
name: []const u8,

pub fn init(self: *@This(), zon: ZonElement, allocator: NeverFailingAllocator) !void {
	self.* = @This(){
		.id = @fromBackingInt(zon.get(u32, "id") orelse std.math.maxInt(u32)),
		.width = zon.get(f64, "width") orelse 1,
		.height = zon.get(f64, "height") orelse 1,
		.name = allocator.dupe(u8, zon.get([]const u8, "name") orelse ""),
	};

	if (zon.getChildOrNull("components")) |components| {
		try main.entity.loadComponentsFromBase64(components.as([]const u8) orelse "", self.id, .client);
	}

	const entityPos = @"cubyz:physics_body".getPositionPointer(self.id, .client).?;
	const entityRot = @"cubyz:physics_body".getPositionPointer(self.id, .client).?;
	entityPos.* = zon.get(Vec3d, "position") orelse .{0, 0, 0};
	entityRot.* = zon.get(Vec3f, "rotation") orelse .{0, 0, 0};
	self._interpolationPos = [_]f64{
		entityPos.*[0],
		entityPos.*[1],
		entityPos.*[2],
		@floatCast(entityRot.*[0]),
		@floatCast(entityRot.*[1]),
		@floatCast(entityRot.*[2]),
	};
	self._interpolationVel = @splat(0);
	self.interpolatedValues.init(&self._interpolationPos, &self._interpolationVel);
}

pub fn deinit(self: @This(), allocator: NeverFailingAllocator) void {
	main.entity.client.removeAllComponents(self.id);
	allocator.free(self.name);
}

pub fn getRenderPosition(self: *const @This()) Vec3d {
	const entityPos = @"cubyz:physics_body".getPositionPointer(self.id, .client).?;
	return Vec3d{entityPos.*[0], entityPos.*[1], entityPos.*[2]};
}

pub fn updatePosition(self: *@This(), pos: *const [6]f64, vel: *const [6]f64, time: i16) void {
	self.interpolatedValues.updatePosition(pos, vel, time);
}

pub fn update(self: *@This(), time: i16, lastTime: i16) void {
	self.interpolatedValues.update(time, lastTime);
	const entityPos = @"cubyz:physics_body".getPositionPointer(self.id, .client).?;
	const entityRot = @"cubyz:physics_body".getRotationPointer(self.id, .client).?;
	entityPos.*[0] = self.interpolatedValues.outPos[0];
	entityPos.*[1] = self.interpolatedValues.outPos[1];
	entityPos.*[2] = self.interpolatedValues.outPos[2];
	entityRot[0] = @floatCast(self.interpolatedValues.outPos[3]);
	entityRot[1] = @floatCast(self.interpolatedValues.outPos[4]);
	entityRot[2] = @floatCast(self.interpolatedValues.outPos[5]);
}

pub fn format(self: *const @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
	if (main.settings.showPlayerIndexWithName and main.entity.components.@"cubyz:player".client.get(self.id) != null) {
		try self.formatWithPlayerIndex(writer);
	} else {
		try writer.print("{s}", .{self.name});
	}
}

pub fn formatWithPlayerIndex(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
	std.debug.assert(main.entity.components.@"cubyz:player".client.get(self.id) != null);
	try writer.print("{s}@{d}", .{self.name, main.entity.components.@"cubyz:player".client.get(self.id).?.playerIndex});
}
