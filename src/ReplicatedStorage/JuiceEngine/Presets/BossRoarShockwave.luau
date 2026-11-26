--!strict

local Types = require(script.Parent.Parent.Core.Types)

local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"
local TEX_SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"
local TEX_SHOCKWAVE = "rbxasset://textures/particles/explosion01_shockwave_main.dds"

local Preset: Types.JuicePreset = {
	meta = {
		id = "BossRoarShockwave",
		displayName = "首領咆哮震波 (Boss Roar Shockwave)",
		category = "Boss",
		author = "JuiceEngine",
		description = "大範圍首領咆哮震波：低頻長衰減地震波、+5.5° 視角擴張推進、微慢動作張力與厚重擴散氣浪。",
		tags = { "boss", "roar", "shockwave", "aoe" },
	},
	cameraShake = {
		magnitude = 2.6,
		roughness = 6.5,
		fadeIn = 0.06,
		sustain = 0.18,
		fadeOut = 0.95,
		posInfluence = Vector3.new(0.45, 0.55, 0.45),
		rotInfluence = Vector3.new(1.4, 1.0, 1.6),
		fovPunch = 5.5,
		maxDistance = 140,
	},
	hitstop = {
		duration = 0.11,
		timeScale = 0.4,
		affectAnimations = true,
		affectParticles = false,
		applyToAttacker = false,
		applyToTarget = true,
	},
	hitFlash = {
		flashColor = Color3.fromRGB(255, 95, 60),
		targetColor = Color3.fromRGB(165, 30, 20),
		fillTransparency = 0.55,
		endFillTransparency = 1,
		outlineColor = Color3.fromRGB(255, 150, 75),
		outlineTransparency = 0.1,
		endOutlineTransparency = 1,
		holdDuration = 0.05,
		duration = 0.28,
		depthMode = Enum.HighlightDepthMode.Occluded,
	},
	sounds = {
		{
			id = "ShockwaveBoom",
			soundId = "rbxasset://sounds/collide.wav",
			group = "boss_roar",
			maxConcurrent = 3,
			spatial = true,
			volumeRange = { min = 0.9, max = 1.05 },
			pitchRange = { min = 0.42, max = 0.52 },
			rollOffMinDistance = 18,
			rollOffMaxDistance = 140,
		},
		{
			id = "RoarRumble",
			soundId = "rbxasset://sounds/uuhhh.mp3",
			group = "boss_voice",
			maxConcurrent = 2,
			spatial = true,
			volumeRange = { min = 0.7, max = 0.85 },
			pitchRange = { min = 0.48, max = 0.6 },
			rollOffMinDistance = 16,
			rollOffMaxDistance = 130,
			delay = 0.03,
		},
	},
	worldBurst = {
		light = {
			color = Color3.fromRGB(255, 110, 55),
			brightness = 3.2,
			range = 36,
			duration = 0.35,
		},
		particles = {
			{
				id = "RoarShockwaveRing",
				texture = TEX_SHOCKWAVE,
				count = 3,
				color = {
					{ time = 0, color = Color3.fromRGB(255, 195, 125) },
					{ time = 0.5, color = Color3.fromRGB(255, 95, 45) },
					{ time = 1, color = Color3.fromRGB(140, 25, 15) },
				},
				size = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 2.0 },
						{ time = 0.35, value = 11.5 },
						{ time = 1, value = 18.0 },
					},
				},
				transparency = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0.1 },
						{ time = 0.65, value = 0.55 },
						{ time = 1, value = 1 },
					},
				},
				lifetime = { min = 0.32, max = 0.48 },
				speed = { min = 0, max = 1 },
				lightEmission = 0.85,
				brightness = 2.2,
				zOffset = 1.0,
			},
			{
				id = "RoarPressureDust",
				texture = TEX_SMOKE,
				count = 20,
				color = {
					{ time = 0, color = Color3.fromRGB(255, 155, 95) },
					{ time = 0.45, color = Color3.fromRGB(120, 65, 55) },
					{ time = 1, color = Color3.fromRGB(55, 40, 40) },
				},
				size = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 1.6 },
						{ time = 0.5, value = 4.2 },
						{ time = 1, value = 6.5 },
					},
				},
				transparency = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0.4 },
						{ time = 0.5, value = 0.65 },
						{ time = 1, value = 1 },
					},
				},
				lifetime = { min = 0.45, max = 0.75 },
				speed = { min = 18, max = 38 },
				spreadAngle = Vector2.new(180, 30),
				acceleration = Vector3.new(0, 6, 0),
				drag = 3.8,
				lightEmission = 0.35,
				brightness = 1.4,
				zOffset = 0.5,
			},
			{
				id = "RoarHeatWave",
				texture = TEX_FIRE,
				count = 10,
				color = {
					{ time = 0, color = Color3.fromRGB(255, 210, 120) },
					{ time = 1, color = Color3.fromRGB(220, 55, 20) },
				},
				size = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 1.4 },
						{ time = 0.4, value = 3.4 },
						{ time = 1, value = 0.5 },
					},
				},
				transparency = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0.2 },
						{ time = 1, value = 1 },
					},
				},
				lifetime = { min = 0.25, max = 0.45 },
				speed = { min = 14, max = 28 },
				spreadAngle = Vector2.new(180, 65),
				drag = 4.2,
				lightEmission = 0.9,
				brightness = 2.4,
				zOffset = 1.2,
			},
			{
				id = "RoarEmbers",
				texture = TEX_SPARKS,
				count = 18,
				color = {
					{ time = 0, color = Color3.fromRGB(255, 235, 175) },
					{ time = 1, color = Color3.fromRGB(255, 85, 25) },
				},
				size = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0.6 },
						{ time = 1, value = 0 },
					},
				},
				transparency = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0 },
						{ time = 0.75, value = 0.25 },
						{ time = 1, value = 1 },
					},
				},
				squash = -0.5,
				lifetime = { min = 0.3, max = 0.55 },
				speed = { min = 24, max = 48 },
				spreadAngle = Vector2.new(180, 90),
				acceleration = Vector3.new(0, -14, 0),
				drag = 4,
				orientation = Enum.ParticleOrientation.VelocityParallel,
				lightEmission = 1,
				brightness = 2.8,
				zOffset = 1.4,
			},
		},
	},
}

return Preset
