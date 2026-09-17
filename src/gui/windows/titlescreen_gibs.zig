const std = @import("std");

const main = @import("main");
const graphics = main.graphics;
const Texture = graphics.Texture;
const Vec2f = main.vec.Vec2f;

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
const gravity: Vec2f = Vec2f{0 , 1};
var seedList: main.ListManaged(Seed) = undefined;
var grassList: main.ListManaged(GrassBlade) = undefined;

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
	const deltaTime = main.lastFrameTime.load(.monotonic)*100.0;
	animateObjects(deltaTime);

	texture.bindTo(0);
	for (seedList.items) |seed| {
		graphics.draw.image(texture, seed.physics.position, size);
	}
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

fn animateObjects(deltaTime: f64) void {
	seedPhysics(deltaTime);
	grassPhysics(deltaTime);
}

fn seedPhysics(deltaTime: f64) void {
	const seedBounds = size/Vec2f{2, 2};
	const bounceAbsorption: Vec2f = Vec2f{0.5, 0.5};
	for (seedList.items) |*seed| {
		var givenSeedPhysics = &seed.physics;
		seed.timeAlive += @floatCast(deltaTime);
		givenSeedPhysics.position += givenSeedPhysics.velocity*Vec2f{@floatCast(deltaTime), @floatCast(deltaTime)};
		const onGround: bool = (givenSeedPhysics.position[1] >= seedBounds[1]);
		if (!onGround) givenSeedPhysics.velocity += gravity*Vec2f{@floatCast(deltaTime), @floatCast(deltaTime)};
		// bounces
		if (givenSeedPhysics.position[1] > seedBounds[1]) {
			givenSeedPhysics.position[1] = seedBounds[1];
			givenSeedPhysics.velocity = Vec2f{givenSeedPhysics.velocity[0], -givenSeedPhysics.velocity[0]}*bounceAbsorption;
			if (@abs(givenSeedPhysics.velocity[1]) < 0.001) {
				givenSeedPhysics.velocity[1] = 0;
			}
		}
		if (seed.timeAlive > 5) {
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
		}
	}
}

fn grassPhysics(deltaTime: f64) void {
	for (grassList.items) |*grassBlade| {
		grassBlade.timeAlive += @floatCast(deltaTime);
		const baseMiddleConnection: *StemRendering = &grassBlade.baseMiddleConnection;
		baseMiddleConnection.thickness = 5;
		baseMiddleConnection.start = grassBlade.basePos.position;
		baseMiddleConnection.end = PhysicsBody{
			.position = baseMiddleConnection.start + Vec2f{0, -1},
			.velocity = baseMiddleConnection.end.velocity,
		};
		const middleTipConnection: *StemRendering = &grassBlade.middleTipConnection;
		middleTipConnection.thickness = 3;
		middleTipConnection.start = baseMiddleConnection.start;
		middleTipConnection.end = PhysicsBody{
			.position = middleTipConnection.start + Vec2f{0, -1},
			.velocity = middleTipConnection.end.velocity,
		};
	}
}