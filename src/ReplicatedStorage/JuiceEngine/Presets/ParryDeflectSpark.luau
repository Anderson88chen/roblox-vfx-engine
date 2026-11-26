--!strict

local Types = require(script.Parent.Parent.Core.Types)

local TEX_SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"
local TEX_SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_CORE_GLOW = "rbxasset://textures/particles/explosion01_core_main.dds"

local Preset: Types.JuicePreset = {
	meta = {
		id = "ParryDeflectSpark",
		displayName = "精準彈反火花 (Parry Deflect Spark)",
		category = "Defense",
		author = "JuiceEngine",
		description = "清脆金屬彈反：極高頻微震、45ms 瞬時鎖幀、金白輪廓強閃與高音金屬鳴響火花噴射。",
		tags = { "parry", "deflect", "metallic", "spark" },
	},
	cameraShake = {
		magnitude = 1.15,
		roughness = 32,
		fadeIn = 0,
		sustain = 0.025,
		fadeOut = 0.18,
		posInfluence = Vector3.new(0.18, 0.18, 0.22),
		rotInfluence = Vector3.new(1.2, 1.4, 2.4),
		fovPunch = -1.6,
		maxDistance = 65,
	},
	hitstop = {
		duration = 0.045,
		timeScale = 0,
		affectAnimations = true,
		affectParticles = true,
		applyToAttacker = true,
		applyToTarget = true,
	},
	hitFlash = {
		flashColor = Color3.fromRGB(255, 248, 195),
		targetColor = Color3.fromRGB(255, 200, 70),
		fillTransparency = 0.35,
		endFillTransparency = 1,
		outlineColor = Color3.fromRGB(255, 245, 160),
		outlineTransparency = 0,
		endOutlineTransparency = 1,
		holdDuration = 0.025,
		duration = 0.16,
		depthMode = Enum.HighlightDepthMode.Occluded,
	},
	sounds = {
		{
			id = "MetalRing",
			soundId = "rbxasset://sounds/electronicpingshort.wav",
			group = "parry_ring",
			maxConcurrent = 6,
			spatial = true,
			volumeRange = { min = 0.65, max = 0.8 },
			pitchRange = { min = 1.38, max = 1.62 },
			rollOffMinDistance = 10,
			rollOffMaxDistance = 85,
		},
		{
			id = "BladeDeflect",
			soundId = "rbxasset://sounds/swordslash.wav",
			group = "parry_blade",
			maxConcurrent = 6,
			spatial = true,
			volumeRange = { min = 0.55, max = 0.7 },
			pitchRange = { min = 1.25, max = 1.45 },
			rollOffMinDistance = 10,
			rollOffMaxDistance = 80,
		},
	},
	worldBurst = {
		light = {
			color = Color3.fromRGB(255, 232, 145),
			brightness = 3.2,
			range = 15,
			duration = 0.12,
		},
		particles = {
			{
				id = "ParryStarCore",
				texture = TEX_CORE_GLOW,
				count = 2,
				color = Color3.fromRGB(255, 250, 210),
				size = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0.9 },
						{ time = 0.25, value = 3.2 },
						{ time = 1, value = 0 },
					},
				},
				transparency = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0 },
						{ time = 0.6, value = 0.4 },
						{ time = 1, value = 1 },
					},
				},
				lifetime = { min = 0.1, max = 0.14 },
				speed = { min = 0, max = 0.5 },
				lightEmission = 1,
				brightness = 3.0,
				zOffset = 2.0,
			},
			{
				id = "ParryCrossGlint",
				texture = TEX_SPARKLES,
				count = 4,
				color = Color3.fromRGB(255, 245, 175),
				size = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 2.2 },
						{ time = 0.4, value = 3.6 },
						{ time = 1, value = 0.1 },
					},
				},
				transparency = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0 },
						{ time = 1, value = 1 },
					},
				},
				lifetime = { min = 0.12, max = 0.18 },
				speed = { min = 1, max = 4 },
				spreadAngle = Vector2.new(180, 180),
				lightEmission = 1,
				brightness = 3.2,
				zOffset = 2.1,
			},
			{
				id = "ParryRadialSparks",
				texture = TEX_SPARKS,
				count = 22,
				color = {
					{ time = 0, color = Color3.fromRGB(255, 255, 230) },
					{ time = 0.4, color = Color3.fromRGB(255, 205, 85) },
					{ time = 1, color = Color3.fromRGB(255, 125, 35) },
				},
				size = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0.5 },
						{ time = 0.65, value = 0.25 },
						{ time = 1, value = 0 },
					},
				},
				transparency = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0 },
						{ time = 0.75, value = 0.2 },
						{ time = 1, value = 1 },
					},
				},
				squash = -0.75,
				lifetime = { min = 0.15, max = 0.28 },
				speed = { min = 26, max = 56 },
				spreadAngle = Vector2.new(180, 180),
				acceleration = Vector3.new(0, -32, 0),
				drag = 4.5,
				orientation = Enum.ParticleOrientation.VelocityParallel,
				lightEmission = 1,
				brightness = 3.0,
				zOffset = 1.6,
			},
		},
	},
}

return Preset
