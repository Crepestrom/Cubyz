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
	};
	pub const Phase = struct {
		sortDirection: PhaseSortType,
		targetSortPhase: []const u8,
		self: []const u8,
		priority: i32 = 0,
	};
	pub const FunctionStep = struct {
		targetPhase: []const u8,
	};

	pub fn getSortedOrder(comptime declarations: []const std.builtin.Type.Declaration, comptime subscribeFunctionName: []const u8, comptime addPhaseFunctionName: []const u8) []const std.builtin.Type.Declaration {
		const startingArray: [0][]const u8 = .{};
		var phaseNameIds: []const[]const u8 = &startingArray;
		PhaseType.initPhaseTypes(&phaseNameIds);
		const sortedPhases = sortPhases(declarations, &phaseNameIds, addPhaseFunctionName);
		const functionSteps = getFunctionSteps(declarations, subscribeFunctionName);

		var sortedFunctionSteps = declarations;
		var nextFreeSlot: usize = 0;
		for (sortedPhases) |phase| {
			AppendCorrectFunctionSteps(declarations,
			phase,
			&nextFreeSlot,
			&sortedFunctionSteps,
			functionSteps,
			&phaseNameIds
			);
		}
		return sortedFunctionSteps;
	}

	fn AppendCorrectFunctionSteps(comptime declarations: []const std.builtin.Type.Declaration, comptime targetPhase: Phase, comptime nextFreeSlot: *usize, overwrittenArray: *[]const std.builtin.Type.Declaration, comptime functionSteps: []const FunctionStep, phaseNameIds: *[]const[]const u8) void {
		for (functionSteps, 0..) |functionStep, i| {
			if (PhaseType.fromFunctionStep(functionStep.targetPhase, phaseNameIds) == PhaseType.fromFunctionStep(targetPhase.self, phaseNameIds)) {
				overwrittenArray[nextFreeSlot] = declarations[i];
			}
		}
	} 

	fn getFunctionSteps(comptime declarations: []const std.builtin.Type.Declaration, comptime subscribeFunctionName: []const u8) []const FunctionStep {
		const startingList: [0]FunctionStep = .{};
		var stepList: []const FunctionStep = &startingList;
		for (declarations) |decl| {
			if (@hasDecl(@field(systems, decl.name).server, subscribeFunctionName)) {
				addToStepArray(&stepList, @field(@field(systems, decl.name).server, subscribeFunctionName)());
			} else {
				continue;
			}
		}
		return stepList;
	}

	fn sortPhases(comptime declarations: []const std.builtin.Type.Declaration, phaseNameIds: *[]const[]const u8, comptime addPhaseFunctionName: []const u8) []const Phase {
		const phaseList = getPhases(declarations, phaseNameIds, addPhaseFunctionName);
		const ctx: SortContext = .{.phaseNameIds = phaseNameIds.*};
		std.sort.insertion(Phase, phaseList, ctx, SortContext.lessThan);
		return phaseList;
	}

	fn getPhases(comptime declarations: []const std.builtin.Type.Declaration, phaseNameIds: *[]const[]const u8, comptime addPhaseFunctionName: []const u8) []Phase {
		var startingList: [2]Phase = .{Phase{
			.sortDirection = .before,
			.self = "start",
			.targetSortPhase = "end",
		},
		Phase{
			.sortDirection = .after,
			.self = "start",
			.targetSortPhase = "end",
		}};
		var phaseList: []Phase = &startingList;
		for (declarations) |decl| {
			if (@hasDecl(@field(systems, decl.name).server, addPhaseFunctionName)) {
				const newPhase: Phase = @field(@field(systems, decl.name).server, addPhaseFunctionName)();
				PhaseType.find(newPhase.self, phaseNameIds);
				addToPhaseArray(&phaseList, newPhase);
			} else {
				continue;
			}
		}
		return phaseList;
	}

	fn addToPhaseNameArray(phaseArray: *[]const[]const u8, addedPhase: []const u8) void {
		const extraPhaseArray: [1][]const u8 = .{addedPhase};
		const translatedPhaseArray: []const[]const u8 = &extraPhaseArray;
		const newArray = phaseArray.*;
		const newPhaseArray = newArray ++ translatedPhaseArray;
		phaseArray.* = newPhaseArray;
	}

	fn addToPhaseArray(phaseArray: *[]const Phase, addedPhase: Phase) void {
		const extraPhaseArray: [1]Phase = .{addedPhase};
		const translatedPhaseArray: []const Phase = &extraPhaseArray;
		const newArray = phaseArray.*;
		const newPhaseArray = newArray ++ translatedPhaseArray;
		phaseArray.* = newPhaseArray;
	}

	fn addToStepArray(stepArray: *[]const FunctionStep, addedStep: FunctionStep) void {
		const extraStepArray: [1]FunctionStep = .{addedStep};
		const translatedStepArray: []const FunctionStep = &extraStepArray;
		const newArray = stepArray.*;
		const newStepArray = newArray ++ translatedStepArray;
		stepArray.* = newStepArray;
	}
	 
	pub const SortContext = struct {
		phaseNameIds: []const[]const u8,

		fn lessThan(self: @This(), a: Phase, b: Phase) bool {
			return compare(self, a, b) orelse {
				return !compare(self, b, a) orelse true;
			};
		}

		fn compare(self: @This(), phaseA: Phase, phaseB: Phase) ?bool {
			switch (phaseA.sortDirection) {
				.before => {
					const phaseAtargetSortPhase = PhaseType.fromTargetSortPhase(phaseA.targetSortPhase, self.phaseNameIds);
					if (phaseAtargetSortPhase == PhaseType.fromSelfSortPhase(phaseB.self, self.phaseNameIds)) return true;
					if (phaseAtargetSortPhase == PhaseType.fromTargetSortPhase(phaseB.targetSortPhase, self.phaseNameIds)) {
						if (phaseB.sortDirection == .after) return false;
						if (phaseA.priority == phaseB.priority) @compileError("Two Phases cannot sort to the same Target Phase at the same priority");
						if (phaseA.priority <= phaseB.priority) return true;
						return false;
					}
				},
				.after => {
					const phaseAtargetSortPhase = PhaseType.fromTargetSortPhase(phaseA.targetSortPhase, self.phaseNameIds);
					if (phaseAtargetSortPhase == PhaseType.fromSelfSortPhase(phaseB.self, self.phaseNameIds)) return false;
					if (phaseAtargetSortPhase == PhaseType.fromTargetSortPhase(phaseB.targetSortPhase, self.phaseNameIds)) {
						if (phaseB.sortDirection == .before) return false;
						if (phaseA.priority == phaseB.priority) @compileError("Two Phases cannot sort to the same Target Phase at the same priority");
						if (phaseA.priority <= phaseB.priority) return false;
						return true;
					}
				},
			}
			return null;
		}
	};

	const PhaseType = enum(u32) {
		start = 0,
		end = 1,
		_,

		pub fn initPhaseTypes(phaseNameIds: *[]const[]const u8) void {
			inline for (comptime std.meta.fieldNames(PhaseType)) |tag| {
				std.debug.assert(PhaseType.findFromName(tag, phaseNameIds) == @field(PhaseType, tag));
			}
		}

		pub fn findFromName(comptime tag: []const u8, phaseNameIds: *[]const[]const u8) PhaseType {
			if (get(tag, phaseNameIds.*)) |res| return res;
			const result: PhaseType = @enumFromInt(phaseNameIds.len);
			addToPhaseNameArray(phaseNameIds, tag);
			return result;
		}

		pub fn fromFunctionStep(comptime tag: []const u8, phaseNameIds: *[]const[]const u8) PhaseType {
			return get(tag, phaseNameIds.*) orelse @compileError("FunctionStep tried to initalize a missing Phase '" ++ tag ++ "'. did you forget to add it?");
		}

		pub fn fromSelfSortPhase(comptime tag: []const u8, phaseNameIds: []const[]const u8) PhaseType {
			return get(tag, phaseNameIds) orelse @compileError("how the hell did you make this happen '" ++ tag ++ "'. i am confused");
		}

		pub fn fromTargetSortPhase(comptime tag: []const u8, phaseNameIds: []const[]const u8) PhaseType {
			return get(tag, phaseNameIds) orelse @compileError("Phase tried to sort with a nonexistant Phase '" ++ tag ++ "'. did you forget to add it?");
		}

		pub fn get(comptime tag: []const u8, phaseNameIds: []const[]const u8) ?PhaseType {
			for (phaseNameIds, 0..) |name, i| {
				if (std.mem.eql(u8, name, tag)) return @enumFromInt(i);
			}
			return null;
		}
	};
};
