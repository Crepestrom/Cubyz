const std = @import("std");

const main = @import("main");
const vec = main.vec;
const Vec3d = vec.Vec3d;
const Vec3f = vec.Vec3f;

pub const systems = @import("systems/_list.zig");

pub const client = struct {
	pub fn init() void {
		inline for (@typeInfo(systems).@"struct".decl_names) |decl| {
			@field(systems, decl).client.init();
		}
	}
	pub fn deinit() void {
		inline for (@typeInfo(systems).@"struct".decl_names) |decl| {
			@field(systems, decl).client.deinit();
		}
	}
	pub fn clear() void {
		inline for (@typeInfo(systems).@"struct".decl_names) |decl| {
			@field(systems, decl).client.clear();
		}
	}
	pub fn render(ambientLight: Vec3f, playerPos: Vec3d, deltaTime: f64) void {
		main.client.entity_manager.update();
		inline for (@typeInfo(systems).@"struct".decl_names) |decl| {
			@field(systems, decl).client.render(ambientLight, playerPos, deltaTime);
		}
	}
	pub fn renderHud(ambientLight: Vec3f, playerPos: Vec3d) void {
		inline for (@typeInfo(systems).@"struct".decl_names) |decl| {
			@field(systems, decl).client.renderHud(ambientLight, playerPos);
		}
	}
};

pub const server = struct {
	pub fn init() void {
		inline for (@typeInfo(systems).@"struct".decl_names) |decl| {
			@field(systems, decl).server.init();
		}
	}
	pub fn deinit() void {
		inline for (@typeInfo(systems).@"struct".decl_names) |decl| {
			@field(systems, decl).server.deinit();
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
		priority: i32,
	};
	pub const FunctionStep = struct {
		targetPhase: []const u8,
		order: usize = 0,
	};

	pub fn getSortedOrder(comptime declarationNames: []const [:0]const u8, comptime subscribeFunctionName: []const u8, comptime addPhaseFunctionName: []const u8) []const [:0]const u8 {
		const startingArray: [0][]const u8 = .{};
		var phaseNameIds: []const[]const u8 = &startingArray;
		PhaseType.initPhaseTypes(&phaseNameIds);
		const sortedPhases = sortPhases(declarationNames, &phaseNameIds, addPhaseFunctionName);
		const functionSteps = getFunctionSteps(declarationNames, subscribeFunctionName);

		var intermediary: [0][:0]const u8 = .{};
		var sortedFunctionSteps: []const [:0]const u8 = &intermediary;
		for (sortedPhases) |phase| {
			for (functionSteps) |functionStep| {
				if (PhaseType.fromFunctionStep(functionStep.targetPhase, &phaseNameIds) == PhaseType.fromFunctionStep(phase.self, &phaseNameIds)) {
					addToDeclarationArray(&sortedFunctionSteps, declarationNames[functionStep.order]);
				}
			}
		}
		return sortedFunctionSteps;
	}

	fn getFunctionSteps(comptime declarationNames: []const [:0]const u8, comptime subscribeFunctionName: []const u8) []const FunctionStep {
		const startingList: [0]FunctionStep = .{};
		var stepList: []const FunctionStep = &startingList;
		for (declarationNames, 0..) |decl_names, i| {
			if (@hasDecl(@field(systems, decl_names).server, subscribeFunctionName)) {
				var newStep: FunctionStep = @field(@field(systems, decl_names).server, subscribeFunctionName)();
				newStep.order = i;
				addToStepArray(&stepList, newStep);
			} else {
				continue;
			}
		}
		return stepList;
	}

	fn sortPhases(comptime declarationNames: []const [:0]const u8, phaseNameIds: *[]const[]const u8, comptime addPhaseFunctionName: []const u8) []const Phase {
		const phaseList = getPhases(declarationNames, phaseNameIds, addPhaseFunctionName);
		const ctx: SortContext = .{.phaseNameIds = phaseNameIds.*};
		std.sort.insertion(Phase, phaseList, ctx, SortContext.lessThan);
		return phaseList;
	}

	fn getPhases(comptime declarationNames: []const [:0]const u8, phaseNameIds: *[]const[]const u8, comptime addPhaseFunctionName: []const u8) []Phase {
		var startingList: [2]Phase = .{Phase{
			.sortDirection = .before,
			.self = "start",
			.targetSortPhase = "end",
			.priority = std.math.minInt(i32),
		},
		Phase{
			.sortDirection = .after,
			.self = "end",
			.targetSortPhase = "start",
			.priority = std.math.minInt(i32),
		}};
		var phaseList: []Phase = &startingList;
		for (declarationNames) |decl| {
			if (@hasDecl(@field(systems, decl).server, addPhaseFunctionName)) {
				const newPhase: Phase = @field(@field(systems, decl).server, addPhaseFunctionName)();
				_ = PhaseType.findFromName(newPhase.self, phaseNameIds);
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

	fn addToPhaseArray(phaseArray: *[]Phase, addedPhase: Phase) void {
		var extraPhaseArray: [phaseArray.len + 1]Phase = undefined;
		for (phaseArray.*, 0..) |newPhase, i| {
			extraPhaseArray[i] = newPhase;
		}
		extraPhaseArray[phaseArray.len] = addedPhase;
		phaseArray.* = &extraPhaseArray;
	}

	fn addToDeclarationArray(stepArray: *[]const [:0]const u8, addedStep: [:0]const u8) void {
		const extraStepArray: [1][:0]const u8 = .{addedStep};
		const translatedStepArray: []const [:0]const u8 = &extraStepArray;
		const newArray = stepArray.*;
		const newStepArray = newArray ++ translatedStepArray;
		stepArray.* = newStepArray;
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
						if (phaseA.priority == phaseB.priority) {
							@compileError(std.fmt.comptimePrint("Two Phases cannot sort to the same Target Phase at the same priority | {s} and {s} targeting {s} at priority {}", .{phaseA.self, phaseB.self, phaseA.targetSortPhase, phaseA.priority}));
						}
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
