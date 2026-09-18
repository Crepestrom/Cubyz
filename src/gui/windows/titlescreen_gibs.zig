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
const PushField = struct { // circular field that applies a force
	position: Vec2f,
	radius: f32,
	strength: f32,
	direction: Vec2f, // if vec2f{0, 0} then pushes away from center
};
const gravity: Vec2f = Vec2f{0 , 1};
var seedList: main.ListManaged(Seed) = undefined;
var grassList: main.ListManaged(GrassBlade) = undefined;
var pushFieldList: main.ListManaged(PushField) = undefined;

pub var window = GuiWindow{
	.contentSize = Vec2f{128, 256},
	.isHud = true,
	.showTitleBar = false,
	.hasBackground = false,
	.hideIfMouseIsGrabbed = false,
	.closeable = false,
};

const size: Vec2f = Vec2f{128, 256};
var texture: Texture = undefined;
const padding: f32 = 8;

pub fn init() void {
	texture = Texture.initFromFile("assets/cubyz/ui/hud/crosshair.png");
}

pub fn onOpen() void {
	seedList = .init(main.globalAllocator);
	grassList = .init(main.globalAllocator);
	gui.updateWindowPositions();
	createSeed();
}

pub fn onClose() void {
	if (window.rootComponent) |*comp| {
		comp.deinit();
	}
	seedList.deinit();
	grassList.deinit();
}

pub fn render() void {
	const deltaTime: f32 = @floatCast(main.lastFrameTime.load(.monotonic)*100.0);
	animateObjects(deltaTime);

	texture.bindTo(0);
	for (seedList.items) |seed| {
		draw.image(texture, seed.physics.position, size);
	}
	const oldColor = draw.setColor(0xff44ff44);
	defer draw.restoreColor(oldColor);
	//const oldScale = draw.setScale(5);
	//defer draw.restoreScale(oldScale);
	for (grassList.items) |grassBlade| {
		const windowOffset = window.size / Vec2f{2, 2};
		draw.line(grassBlade.basePos.position + windowOffset, grassBlade.baseMiddleConnection.end.position + windowOffset);
		draw.line(grassBlade.middleTipConnection.start + windowOffset, grassBlade.middleTipConnection.end.position + windowOffset);
	}
}

pub fn updateHovered(mousePosition: Vec2f) main.callbacks.Result {
	_ = mousePosition;
	return .handled;
}

pub fn createSeed() void {
	const randomX: random.RandomRange(f32) = .init(-size[0]/4, size[1]/4);
	const randomVelocity: random.RandomRange(f32) = .init(-10, 10);
	const newSeed = Seed{
		.physics = PhysicsBody{
			.position = Vec2f{randomX.get(&main.seed), -size[1]/2},
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

fn seedPhysics(deltaTime: f32) void {
	const seedBounds = size/Vec2f{2, 2};
	const bounceAbsorption: Vec2f = Vec2f{0.5, 0.5};
	var listIterator: usize = 0;
	for (seedList.items) |*seed| {
		var givenSeedPhysics = &seed.physics;
		seed.timeAlive += deltaTime;
		givenSeedPhysics.position += givenSeedPhysics.velocity*Vec2f{deltaTime, deltaTime};
		const onGround: bool = (givenSeedPhysics.position[1] >= seedBounds[1]);
		if (!onGround) givenSeedPhysics.velocity += gravity*Vec2f{deltaTime, deltaTime};
		// bounces
		if (givenSeedPhysics.position[1] > seedBounds[1]) {
			givenSeedPhysics.position[1] = seedBounds[1];
			givenSeedPhysics.velocity = Vec2f{givenSeedPhysics.velocity[0], -givenSeedPhysics.velocity[0]}*bounceAbsorption;
			if (@abs(givenSeedPhysics.velocity[1]) < 0.001) {
				givenSeedPhysics.velocity[1] = 0;
			}
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

fn grassPhysics(deltaTime: f32) void {
	for (grassList.items) |*grassBlade| {
		grassBlade.timeAlive += deltaTime;
		const baseMiddleConnection: *StemRendering = &grassBlade.baseMiddleConnection;
		baseMiddleConnection.thickness = 5;
		baseMiddleConnection.start = grassBlade.basePos.position;
		baseMiddleConnection.end = PhysicsBody{
			.position = baseMiddleConnection.start + Vec2f{@sin(grassBlade.timeAlive)*10, -50} + baseMiddleConnection.end.velocity,
			.velocity = baseMiddleConnection.end.velocity,
		};
		const middleTipConnection: *StemRendering = &grassBlade.middleTipConnection;
		middleTipConnection.thickness = 3;
		middleTipConnection.start = baseMiddleConnection.end.position;
		middleTipConnection.end = PhysicsBody{
			.position = middleTipConnection.start + Vec2f{0, -50} + middleTipConnection.end.velocity,
			.velocity = middleTipConnection.end.velocity,
		};
	}
}

// MARK: PushFields
fn calculatePushFields(deltaTime: f32) void {
	for (pushFieldList.items) |pushField| {
		const magnitude = distance(Vec2f{0, 0}, pushField.direction);
		const normalizedDirection = if (magnitude != 0) pushField.direction / Vec2f{magnitude, magnitude} else Vec2f{0, 0};

		pushSeeds(pushField, normalizedDirection, deltaTime);
	}
}

fn pushSeeds(pushField: PushField, normalizedDirection: Vec2f, deltaTime: f32) void {
	for (seedList.items) |*seed| {
		seed.physics.velocity += calculatePushForce(pushField, seed.physics.position, normalizedDirection, deltaTime);
	}
}

fn calculatePushForce(pushField: PushField, targetPos: Vec2f, normalizedDirection: Vec2f, deltaTime: f32) Vec2f {
	if ((@abs(targetPos[0] - pushField.position[0]) > pushField.radius) or (@abs(targetPos[1] - pushField.position[1]) > pushField.radius)) return Vec2f{0, 0};
	const objectDistance: f32 = distance(pushField.position, targetPos);
	const calculatedPushStrength = Vec2f{pushField.strength * deltaTime, pushField.strength * deltaTime};
	if ((normalizedDirection[0] != 0) or ((normalizedDirection[1] != 0))) {
		return normalizedDirection * calculatedPushStrength;
	} else {
		const magnitude: f32 = objectDistance;
		const calculatedNormalizedDirection = if (magnitude != 0) pushField.direction / Vec2f{magnitude, magnitude} else Vec2f{0, 0};
		return calculatedNormalizedDirection * calculatedPushStrength;
	}
}

fn distance(pos1: Vec2f, pos2: Vec2f) f32 {
	return @sqrt((pos1[0] + pos2[0])*(pos1[0] + pos2[0]) + (pos1[1] + pos2[1])*(pos1[1] + pos2[1]));
}