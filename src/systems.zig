const std = @import("std");

const main = @import("main");
const vec = main.vec;
const Vec3d = vec.Vec3d;
const Vec3f = vec.Vec3f;

pub const systems = @import("systems/_list.zig");

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

pub const RunOrderManager = struct { // MARK: RunOrderManager

	const PhaseSortType = enum {
		before,
		after,
		start,
	};
	pub const Phase = struct {
		sortDirection: PhaseSortType,
		sortTargetType: PhaseType,
		self: PhaseType,
		priority: i32 = 0,
	};
	pub const FunctionStep = struct {
		sortTargetType: PhaseType,
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

	pub fn getSortedOrder(comptime declarations: []const std.builtin.Type.Declaration, comptime subscribeFunctionName: []const u8) []const std.builtin.Type.Declaration {
		const functionSteps = getFunctionSteps(declarations, subscribeFunctionName);
		const sortedPhases = sortPhases(declarations);
		var sortedFunctionSteps = declarations;
		var nextFreeSlot: usize = 0;
		for (sortedPhases) |phase| {
			AppendCorrectFunctionSteps(declarations, phase, &nextFreeSlot, &sortedFunctionSteps, functionSteps);
		}
		return sortedFunctionSteps;
	}

	fn AppendCorrectFunctionSteps(comptime declarations: []const std.builtin.Type.Declaration, comptime targetPhase: Phase, comptime nextFreeSlot: usize, overwrittenArray: []const ?std.builtin.Type.Declaration, comptime functionSteps: []const FunctionStep) void {
		for (functionSteps, 0..) |functionStep, i| {
			if (functionStep.sortTargetType == targetPhase.self) {
				overwrittenArray[nextFreeSlot] = declarations[i];
			}
		}
	} 

	fn getFunctionSteps(comptime declarations: []const std.builtin.Type.Declaration, comptime subscribeFunctionName: []const u8) []const FunctionStep {
		var stepList: []const systems.FunctionStep = .{};
		for (declarations) |decl| {
			if (@hasDecl(@field(systems.systems, decl.name).server, subscribeFunctionName)) {
				stepList = std.mem.concat(main.stackAllocator, &.{stepList, @field(systems.systems, decl.name).server.addUpdatePhase()});
			} else {
				continue;
			}
		}
	}
	
	fn getPhases(comptime declarations: []const std.builtin.Type.Declaration) []const Phase {
		var phaseList: []const systems.Phase = .{systems.Phase{
			.sortDirection = .start,
			.self = systems.PhaseType.find("start"),
			.sortTargetType = systems.PhaseType.find("start"),
		}};

		for (declarations) |decl| {
			if (@hasDecl(@field(systems.systems, decl.name).server, "addUpdatePhase")) {
				phaseList = std.mem.concat(main.stackAllocator, &.{phaseList, @field(systems.systems, decl.name).server.addUpdatePhase()});
			} else {
				continue;
			}
		}
		return phaseList;
	}

	fn sortPhases(comptime declarations: []const std.builtin.Type.Declaration) []const Phase {
		var phaseList = getPhases(declarations);
		std.sort.insertion(usize, &phaseList.items, .{}, lessThan);
		return phaseList;
	}

	fn lessThan(ctx: @This(), a: usize, b: usize) bool {
		return compare(ctx, a, b) orelse {
			return !compare(ctx, b, a) orelse true;
		};
	}

	fn compare(ctx: @This(), a: usize, b: usize) ?bool {
		const phaseA = ctx.sortlist.items[a];
		const phaseB = ctx.sortlist.items[b];
		switch (phaseA.sortDirection) {
			.start => {},
			.before => {
				if (phaseA.sortTargetType == phaseB.self) return true;
				if (phaseA.sortTargetType == phaseB.sortTargetType) {
					if (phaseA.priority == phaseB.priority) @compileError("Two Phases cannot sort to the same Target Phase at the same priority");
					if (phaseA.priority <= phaseB.priority) return true;
					return false;
				}
			},
			.after => {
				if (phaseA.sortTargetType == phaseB.self) return false;
				if (phaseA.sortTargetType == phaseB.sortTargetType) {
					if (phaseA.priority == phaseB.priority) @compileError("Two Phases cannot sort to the same Target Phase at the same priority");
					if (phaseA.priority <= phaseB.priority) return false;
					return true;
				}
			},
		}
	}
};
