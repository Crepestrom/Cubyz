const std = @import("std");

const main = @import("main");
const graphics = main.graphics;
const Texture = graphics.Texture;
const Vec2f = main.vec.Vec2f;
const draw = graphics.draw;

const c = @import("c");

const gui = @import("../gui.zig");
const GuiComponent = gui.GuiComponent;
const GuiWindow = gui.GuiWindow;
const Button = @import("../components/Button.zig");
const VerticalList = @import("../components/VerticalList.zig");
const random = main.random;
// objects
const PhysicsBody = struct {
	position: Vec2f,
	velocity: Vec2f,
};
const StemRendering = struct {
	start: Vec2f,
	end: PhysicsBody,
	thickness: f32,
};
const Seed = struct {
	physics: PhysicsBody,
	timeAlive: f32,
};
const GrassBlade = struct {
	basePos: PhysicsBody,
	baseMiddleConnection: StemRendering,
	middleTipConnection: StemRendering,
	timeAlive: f32,
};
const pushTargets = enum {
	all,
	seeds,
	grass,
};
const PushField = struct { // circular field that applies a force
	position: Vec2f = Vec2f{0, 0},
	radius: f32 = 0,
	strength: f32 = 0,
	direction: Vec2f = Vec2f{0, 0}, // if vec2f{0, 0} then pushes away from center
	pushTargets: pushTargets = .all,
};
const gravity: Vec2f = Vec2f{0 , 1};
var seedList: main.ListManaged(Seed) = undefined;
var grassList: main.ListManaged(GrassBlade) = undefined;
var pushFieldList: main.ListManaged(PushField) = undefined;
var mouseSeedPushField: PushField = PushField{
	.radius = 10,
	.strength = 20,
	.pushTargets = .seeds,
};
var mouseGrassPushField: PushField = PushField{
	.radius = 40,
	.strength = 10,
	.pushTargets = .grass,
};

pub var window = GuiWindow{
	.contentSize = Vec2f{64, 64},
	.isHud = true,
	.showTitleBar = false,
	.hasBackground = false,
	.hideIfMouseIsGrabbed = false,
	.closeable = false,
};

var texture: Texture = undefined;
const padding: f32 = 8;

pub fn init() void {
	texture = Texture.initFromFile("assets/cubyz/ui/hud/crosshair.png");
}

pub fn onOpen() void {
	seedList = .init(main.globalAllocator);
	grassList = .init(main.globalAllocator);
	pushFieldList = .init(main.globalAllocator);
	gui.updateWindowPositions();
	createSeed();
	window.pos = Vec2f{0, 0};
}

pub fn onClose() void {
	if (window.rootComponent) |*comp| {
		comp.deinit();
	}
	seedList.deinit();
	grassList.deinit();
	pushFieldList.deinit();
}

pub fn render() void {
	if ((window.size[0] != main.Window.getWindowSize()[0]) or (window.size[1] != main.Window.getWindowSize()[1])) resizeWindow();
	const deltaTime: f32 = @floatCast(main.lastFrameTime.load(.monotonic)*100.0);
	animateObjects(deltaTime);

	texture.bindTo(0);
	const seedSize = Vec2f{32, 32};
	for (seedList.items) |seed| {
		draw.image(texture, seed.physics.position - (seedSize/Vec2f{2, 2}), seedSize);
	}
	draw.image(texture, mouseSeedPushField.position - (seedSize/Vec2f{2, 2}), seedSize);
	for (grassList.items) |grassBlade| {
		{
			const oldColor = draw.setColor(0xff11dd11);
			defer draw.restoreColor(oldColor);
			draw.line(grassBlade.basePos.position, grassBlade.baseMiddleConnection.end.position);
		}
		{
			const oldColor = draw.setColor(0xff44ff44);
			defer draw.restoreColor(oldColor);
			draw.line(grassBlade.middleTipConnection.start, grassBlade.middleTipConnection.end.position);
		}
	}
}
pub fn updateHovered(mousePosition: Vec2f) main.callbacks.Result {
	const randomX: random.RandomRange(f32) = .init(-1, 1);
	mouseSeedPushField.position = mousePosition;
	mouseSeedPushField.direction = Vec2f{randomX.get(&main.seed), -5};
	mouseGrassPushField.position = mousePosition;
	return .handled;
}
// MARK: Object Handling

pub fn createSeed() void {
	const randomX: random.RandomRange(f32) = .init(0, window.size[0]/2);
	const randomVelocity: random.RandomRange(f32) = .init(-5, 5);
	const newSeed = Seed{
		.physics = PhysicsBody{
			.position = Vec2f{randomX.get(&main.seed), 100},
			.velocity = Vec2f{randomVelocity.get(&main.seed), 0},
		},
		.timeAlive = 0,
	};
	seedList.append(newSeed);
}

fn animateObjects(deltaTime: f32) void {
	calculatePushFields(deltaTime);

	seedPhysics(deltaTime);
	grassPhysics(deltaTime);
}
// MARK: Seed
fn seedPhysics(deltaTime: f32) void {
	window.size = main.Window.getWindowSize();
	const seedBounds = window.size/Vec2f{2, 2};
	const bounceAbsorption: Vec2f = Vec2f{0.5, 0.5};
	var listIterator: usize = 0;
	for (seedList.items) |*seed| {
		var givenSeedPhysics = &seed.physics;
		seed.timeAlive += deltaTime;
		const onGround: bool = (givenSeedPhysics.position[1] > seedBounds[1]);
		if (!onGround) givenSeedPhysics.velocity += gravity*Vec2f{deltaTime, deltaTime};
		givenSeedPhysics.position += givenSeedPhysics.velocity*Vec2f{deltaTime, deltaTime};
		// screenloop (currently broken with screen resizing)
		// givenSeedPhysics.position[0] = @mod(givenSeedPhysics.position[0], window.size);
		// bounces
		if (givenSeedPhysics.position[1] > seedBounds[1]) {
			givenSeedPhysics.position[1] = seedBounds[1];
			givenSeedPhysics.velocity = Vec2f{givenSeedPhysics.velocity[0], -givenSeedPhysics.velocity[1]}*bounceAbsorption;
		}
		const decisecondsUntilGrowth = 100;
		if (seed.timeAlive > decisecondsUntilGrowth) {
			const newPhysicsBody = PhysicsBody{
				.position = givenSeedPhysics.position,
				.velocity = givenSeedPhysics.velocity,
			};
			const newGrassBlade = GrassBlade{
				.basePos = newPhysicsBody,
				.baseMiddleConnection = StemRendering{
					.start = newPhysicsBody.position,
					.end = newPhysicsBody,
					.thickness = 0,
				},
				.middleTipConnection = StemRendering{
					.start = newPhysicsBody.position,
					.end = newPhysicsBody,
					.thickness = 0,
				},
				.timeAlive = 0,
			};
			grassList.append(newGrassBlade);
			_ = seedList.orderedRemove(listIterator);
		}
		listIterator += 1;
	}
}
// MARK: Grass
fn grassPhysics(deltaTime: f32) void {
	for (grassList.items) |*grassBlade| {
		grassBlade.timeAlive += deltaTime;
		const baseMiddleConnection: *StemRendering = &grassBlade.baseMiddleConnection;
		const middleTipConnection: *StemRendering = &grassBlade.middleTipConnection;
		baseMiddleConnection.thickness = 5;
		baseMiddleConnection.start = grassBlade.basePos.position;
		std.log.debug("{}", .{baseMiddleConnection.end.velocity});
		const transferEffeciency = 0.3;
		const middleVelocity = (baseMiddleConnection.end.velocity*vectorize(1 - transferEffeciency) + middleTipConnection.end.velocity*vectorize(transferEffeciency))*vectorize(0.8);
		baseMiddleConnection.end = PhysicsBody{
			.position = baseMiddleConnection.start + Vec2f{0, -50} + baseMiddleConnection.end.velocity,
			.velocity = middleVelocity,
		};
		middleTipConnection.thickness = 3;
		middleTipConnection.start = baseMiddleConnection.end.position;
		var tipVelocity = (middleTipConnection.end.velocity*vectorize(1 - transferEffeciency) + baseMiddleConnection.end.velocity*vectorize(transferEffeciency))*vectorize(0.8);
		tipVelocity += vectorize((1 + @sin(grassBlade.timeAlive/10))*@sin(grassBlade.timeAlive/600));
		middleTipConnection.end = PhysicsBody{
			.position = middleTipConnection.start + Vec2f{0, -50} + middleTipConnection.end.velocity,
			.velocity = tipVelocity,
		};
	}
}

// MARK: PushFields
fn calculatePushFields(deltaTime: f32) void {
	calculateSinglePushField(mouseSeedPushField, deltaTime);
	calculateSinglePushField(mouseGrassPushField, deltaTime);
	for (pushFieldList.items) |pushField| {
		calculateSinglePushField(pushField, deltaTime);
	}
}

fn calculateSinglePushField(pushField: PushField, deltaTime: f32) void {
	switch (pushField.pushTargets) {
		.all => {
			pushSeeds(pushField, deltaTime);
			pushGrass(pushField, deltaTime);
		},
		.seeds => pushSeeds(pushField, deltaTime),
		.grass => pushGrass(pushField, deltaTime),
	}
}

fn pushSeeds(pushField: PushField, deltaTime: f32) void {
	const magnitude = distance(Vec2f{0, 0}, pushField.direction);
	const normalizedDirection = if (magnitude != 0) pushField.direction/Vec2f{magnitude, magnitude} else Vec2f{0, 0};
	for (seedList.items) |*seed| {
		seed.physics.velocity += calculatePushForce(pushField, seed.physics.position, normalizedDirection, deltaTime);
	}
}

fn pushGrass(pushField: PushField, deltaTime: f32) void {
	const magnitude = distance(Vec2f{0, 0}, pushField.direction);
	const normalizedDirection = if (magnitude != 0) pushField.direction/Vec2f{magnitude, magnitude} else Vec2f{0, 0};
	for (grassList.items) |*grassBlade| {
		grassBlade.baseMiddleConnection.end.velocity += calculatePushForce(pushField, grassBlade.baseMiddleConnection.end.position, normalizedDirection, deltaTime);
		grassBlade.middleTipConnection.end.velocity += calculatePushForce(pushField, grassBlade.middleTipConnection.end.position, normalizedDirection, deltaTime);
	}
}

fn calculatePushForce(pushField: PushField, targetPos: Vec2f, normalizedDirection: Vec2f, deltaTime: f32) Vec2f {
	//if ((@abs(targetPos[0] - pushField.position[0]) > pushField.radius) or (@abs(targetPos[1] - pushField.position[1]) > pushField.radius)) return Vec2f{0, 0};
	const calculatedPushStrength = vectorize(pushField.strength * deltaTime);
	if ((normalizedDirection[0] != 0) or ((normalizedDirection[1] != 0))) {
		const calculatedDirection = targetPos - pushField.position;
		const magnitude: f32 = distance(calculatedDirection, Vec2f{0, 0});
		const distFalloff = vectorize(@max(pushField.radius - magnitude, 0)/pushField.radius);
		return normalizedDirection * calculatedPushStrength * distFalloff;
	} else {
		const calculatedDirection = targetPos - pushField.position;
		const magnitude: f32 = distance(calculatedDirection, Vec2f{0, 0});
		const calculatedNormalizedDirection: Vec2f = if (magnitude != 0) calculatedDirection/vectorize(magnitude) else Vec2f{0, 0};
		const distFalloff = vectorize(@max(pushField.radius - magnitude, 0)/pushField.radius);
		return calculatedNormalizedDirection * calculatedPushStrength * distFalloff;
	}
}

// MARK: utility functions
fn distance(pos1: Vec2f, pos2: Vec2f) f32 {
	return @sqrt(((pos1[0] + pos2[0])*(pos1[0] + pos2[0])) + ((pos1[1] + pos2[1])*(pos1[1] + pos2[1])));
}

inline fn vectorize(inputFloat: f32) Vec2f {
	return Vec2f{inputFloat, inputFloat};
}

fn resizeWindow() void { // TODO: delete objects that land outside of a screen
	window.size = main.Window.getWindowSize();
}