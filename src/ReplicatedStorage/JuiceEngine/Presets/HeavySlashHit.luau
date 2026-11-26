--!strict

local Types = require(script.Parent.Parent.Core.Types)

local TEX_SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"
local TEX_CORE_GLOW = "rbxasset://textures/particles/explosion01_core_main.dds"
local TEX_SHOCKWAVE = "rbxasset://textures/particles/explosion01_shockwave_main.dds"

local Preset: Types.JuicePreset = {
	meta = {
		id = "HeavySlashHit",
		displayName = "重擊斬擊命中 (Heavy Slash Hit)",
		category = "Melee",
		author = "JuiceEngine",
		description = "沉重刀劍命中：紮實中頻相機震動、65ms 頓幀、白轉琥珀受擊閃光與斬擊火花爆發。",
		tags = { "melee", "slash", "heavy", "impact" },
	},
	cameraShake = {
		magnitude = 1.65,
		roughness = 14,
		fadeIn = 0.01,
		sustain = 0.05,
		fadeOut = 0.28,
		posInfluence = Vector3.new(0.28, 0.22, 0.35),
		rotInfluence = Vector3.new(1.5, 1.1, 2.2),
		fovPunch = -2.0,
		maxDistance = 75,
	},
	hitstop = {
		duration = 0.065,
		timeScale = 0.02,
		affectAnimations = true,
		affectParticles = true,
		applyToAttacker = true,
		applyToTarget = true,
	},
	hitFlash = {
		flashColor = Color3.fromRGB(255, 250, 235),
		targetColor = Color3.fromRGB(255, 140, 65),
		fillTransparency = 0.12,
		endFillTransparency = 1,
		outlineColor = Color3.fromRGB(255, 220, 160),
		outlineTransparency = 0,
		endOutlineTransparency = 1,
		holdDuration = 0.035,
		duration = 0.19,
		depthMode = Enum.HighlightDepthMode.Occluded,
	},
	sounds = {
		{
			id = "SlashCut",
			soundId = "rbxasset://sounds/swordslash.wav",
			group = "melee_hit",
			maxConcurrent = 6,
			spatial = true,
			volumeRange = { min = 0.65, max = 0.8 },
			pitchRange = { min = 0.86, max = 1.02 },
			rollOffMinDistance = 10,
			rollOffMaxDistance = 80,
		},
		{
			id = "HeavyThud",
			soundId = "rbxasset://sounds/collide.wav",
			group = "melee_impact",
			maxConcurrent = 5,
			spatial = true,
			volumeRange = { min = 0.7, max = 0.85 },
			pitchRange = { min = 0.68, max = 0.82 },
			rollOffMinDistance = 12,
			rollOffMaxDistance = 90,
		},
	},
	worldBurst = {
		light = {
			color = Color3.fromRGB(255, 200, 120),
			brightness = 3.0,
			range = 18,
			duration = 0.16,
		},
		particles = {
			{
				id = "SlashCoreFlash",
				texture = TEX_CORE_GLOW,
				count = 2,
				color = {
					{ time = 0, color = Color3.fromRGB(255, 252, 235) },
					{ time = 1, color = Color3.fromRGB(255, 145, 55) },
				},
				size = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 1.2 },
						{ time = 0.25, value = 4.2 },
						{ time = 1, value = 0.2 },
					},
				},
				transparency = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0.05 },
						{ time = 0.5, value = 0.35 },
						{ time = 1, value = 1 },
					},
				},
				lifetime = { min = 0.12, max = 0.18 },
				speed = { min = 0, max = 1 },
				lightEmission = 1,
				brightness = 2.6,
				zOffset = 1.8,
			},
			{
				id = "SlashShockwave",
				texture = TEX_SHOCKWAVE,
				count = 1,
				color = {
					{ time = 0, color = Color3.fromRGB(255, 225, 175) },
					{ time = 1, color = Color3.fromRGB(255, 120, 45) },
				},
				size = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0.8 },
						{ time = 0.4, value = 4.8 },
						{ time = 1, value = 7.2 },
					},
				},
				transparency = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0.15 },
						{ time = 0.6, value = 0.6 },
						{ time = 1, value = 1 },
					},
				},
				lifetime = { min = 0.18, max = 0.24 },
				speed = { min = 0, max = 0.5 },
				lightEmission = 0.9,
				brightness = 2.0,
				zOffset = 1.2,
			},
			{
				id = "SlashSparks",
				texture = TEX_SPARKS,
				count = 16,
				color = {
					{ time = 0, color = Color3.fromRGB(255, 245, 200) },
					{ time = 0.5, color = Color3.fromRGB(255, 165, 60) },
					{ time = 1, color = Color3.fromRGB(220, 75, 25) },
				},
				size = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0.55 },
						{ time = 0.6, value = 0.3 },
						{ time = 1, value = 0 },
					},
				},
				transparency = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0 },
						{ time = 0.7, value = 0.25 },
						{ time = 1, value = 1 },
					},
				},
				squash = -0.6,
				lifetime = { min = 0.18, max = 0.34 },
				speed = { min = 18, max = 38 },
				spreadAngle = Vector2.new(180, 180),
				acceleration = Vector3.new(0, -28, 0),
				drag = 5,
				orientation = Enum.ParticleOrientation.VelocityParallel,
				lightEmission = 0.95,
				brightness = 2.8,
				zOffset = 1.4,
			},
		},
	},
}

return Preset
