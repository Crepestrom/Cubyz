const std = @import("std");

const main = @import("main");
const vec = main.vec;
const Vec3d = vec.Vec3d;
const Vec3f = vec.Vec3f;

pub const systems = @import("systems/_list.zig");
const PhaseSortType = enum {
	before,
	after,
};
pub const Phase = struct {
	phaseSortType: PhaseSortType,
};

var phaseTypeList: main.List([]const u8) = .empty;
var phaseTypeIds: std.StringHashMapUnmanaged(PhaseType) = .{};

pub const PhaseType = enum(u32) {
	pub fn clearPhaseTypes() void {
		phaseTypeList = .empty;
		phaseTypeIds = .{};
	}

	pub fn get(tag: []const u8) ?PhaseType {
		return phaseTypeIds.get(tag);
	}

	pub fn find(tag: []const u8) PhaseType {
		if (phaseTypeIds.get(tag)) |res| return res;
		const result: PhaseType = @enumFromInt(phaseTypeList.items.len);
		const dupedTag = main.worldArena.dupe(u8, tag);
		phaseTypeList.append(main.worldArena, dupedTag);
		phaseTypeIds.put(main.worldArena.allocator, dupedTag, result) catch unreachable;
		return result;
	}

	pub fn getName(tag: PhaseType) []const u8 {
		return phaseTypeList.items[@intFromEnum(tag)];
	}
};

pub const client = struct {
	pub fn init() void {
		inline for (@typeInfo(systems).@"struct".decls) |decl| {
			@field(systems, decl.name).client.init();
		}
	}
	pub fn deinit() void {
		inline for (@typeInfo(systems).@"struct".decls) |decl| {
			@field(systems, decl.name).client.deinit();
		}
	}
	pub fn clear() void {
		inline for (@typeInfo(systems).@"struct".decls) |decl| {
			@field(systems, decl.name).client.clear();
		}
	}
	pub fn render(ambientLight: Vec3f, playerPos: Vec3d, deltaTime: f64) void {
		main.client.entity_manager.update();
		inline for (@typeInfo(systems).@"struct".decls) |decl| {
			@field(systems, decl.name).client.render(ambientLight, playerPos, deltaTime);
		}
	}
	pub fn renderHud(ambientLight: Vec3f, playerPos: Vec3d) void {
		inline for (@typeInfo(systems).@"struct".decls) |decl| {
			@field(systems, decl.name).client.renderHud(ambientLight, playerPos);
		}
	}
};

pub const server = struct {
	pub fn init() void {
		inline for (@typeInfo(systems).@"struct".decls) |decl| {
			@field(systems, decl.name).server.init();
		}
	}
	pub fn deinit() void {
		inline for (@typeInfo(systems).@"struct".decls) |decl| {
			@field(systems, decl.name).server.deinit();
		}
	}
};
