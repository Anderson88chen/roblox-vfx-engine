--!strict

local Types = require(script.Parent.Parent.Core.Types)

local TEX_SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"
local TEX_SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_CORE_GLOW = "rbxasset://textures/particles/explosion01_core_main.dds"
local TEX_SHOCKWAVE = "rbxasset://textures/particles/explosion01_shockwave_main.dds"

local Preset: Types.JuicePreset = {
	meta = {
		id = "CriticalThunderImpact",
		displayName = "暴擊雷霆貫穿 (Critical Thunder Impact)",
		category = "Elemental",
		author = "JuiceEngine",
		description = "高壓雷電暴擊：高粗糙度電擊抖動與 -3.5° 視角內縮、85ms 頓幀、電青閃白與聯動 VFXEngine 時間軸重播。",
		tags = { "critical", "lightning", "burst", "elemental" },
	},
	cameraShake = {
		magnitude = 2.25,
		roughness = 26,
		fadeIn = 0.005,
		sustain = 0.06,
		fadeOut = 0.34,
		posInfluence = Vector3.new(0.32, 0.32, 0.42),
		rotInfluence = Vector3.new(1.8, 1.5, 2.8),
		fovPunch = -3.5,
		maxDistance = 90,
	},
	hitstop = {
		duration = 0.085,
		timeScale = 0.01,
		affectAnimations = true,
		affectParticles = true,
		applyToAttacker = true,
		applyToTarget = true,
	},
	hitFlash = {
		flashColor = Color3.fromRGB(235, 250, 255),
		targetColor = Color3.fromRGB(55, 165, 255),
		fillTransparency = 0.08,
		endFillTransparency = 1,
		outlineColor = Color3.fromRGB(140, 230, 255),
		outlineTransparency = 0,
		endOutlineTransparency = 1,
		holdDuration = 0.045,
		duration = 0.24,
		depthMode = Enum.HighlightDepthMode.Occluded,
	},
	sounds = {
		{
			id = "ThunderThrust",
			soundId = "rbxasset://sounds/swordlunge.wav",
			group = "thunder_crit",
			maxConcurrent = 4,
			spatial = true,
			volumeRange = { min = 0.72, max = 0.88 },
			pitchRange = { min = 1.05, max = 1.22 },
			rollOffMinDistance = 12,
			rollOffMaxDistance = 95,
		},
		{
			id = "ThunderCrack",
			soundId = "rbxasset://sounds/collide.wav",
			group = "thunder_crit",
			maxConcurrent = 4,
			spatial = true,
			volumeRange = { min = 0.75, max = 0.9 },
			pitchRange = { min = 1.15, max = 1.35 },
			rollOffMinDistance = 12,
			rollOffMaxDistance = 95,
		},
		{
			id = "ElectricSnap",
			soundId = "rbxasset://sounds/electronicpingshort.wav",
			group = "thunder_snap",
			maxConcurrent = 4,
			spatial = true,
			volumeRange = { min = 0.42, max = 0.55 },
			pitchRange = { min = 1.45, max = 1.75 },
			rollOffMinDistance = 10,
			rollOffMaxDistance = 75,
			delay = 0.02,
		},
	},
	worldBurst = {
		light = {
			color = Color3.fromRGB(115, 215, 255),
			brightness = 3.6,
			range = 26,
			duration = 0.2,
		},
		particles = {
			{
				id = "ThunderCore",
				texture = TEX_CORE_GLOW,
				count = 2,
				color = {
					{ time = 0, color = Color3.fromRGB(240, 252, 255) },
					{ time = 1, color = Color3.fromRGB(65, 165, 255) },
				},
				size = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 1.5 },
						{ time = 0.2, value = 5.4 },
						{ time = 1, value = 0.3 },
					},
				},
				transparency = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0 },
						{ time = 0.45, value = 0.3 },
						{ time = 1, value = 1 },
					},
				},
				lifetime = { min = 0.14, max = 0.22 },
				speed = { min = 0, max = 1 },
				lightEmission = 1,
				brightness = 3.2,
				zOffset = 2.0,
			},
			{
				id = "ThunderRing",
				texture = TEX_SHOCKWAVE,
				count = 2,
				color = {
					{ time = 0, color = Color3.fromRGB(185, 240, 255) },
					{ time = 1, color = Color3.fromRGB(50, 125, 255) },
				},
				size = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 1.0 },
						{ time = 0.35, value = 6.2 },
						{ time = 1, value = 9.5 },
					},
				},
				transparency = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0.1 },
						{ time = 0.6, value = 0.55 },
						{ time = 1, value = 1 },
					},
				},
				lifetime = { min = 0.2, max = 0.28 },
				speed = { min = 0, max = 0.5 },
				lightEmission = 0.95,
				brightness = 2.4,
				zOffset = 1.4,
			},
			{
				id = "ElectricArcSparks",
				texture = TEX_SPARKS,
				count = 24,
				color = {
					{ time = 0, color = Color3.fromRGB(235, 252, 255) },
					{ time = 0.45, color = Color3.fromRGB(95, 200, 255) },
					{ time = 1, color = Color3.fromRGB(45, 95, 255) },
				},
				size = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0.7 },
						{ time = 0.5, value = 0.38 },
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
				squash = -0.8,
				lifetime = { min = 0.18, max = 0.36 },
				speed = { min = 24, max = 52 },
				spreadAngle = Vector2.new(180, 180),
				acceleration = Vector3.new(0, -10, 0),
				drag = 6,
				orientation = Enum.ParticleOrientation.VelocityParallel,
				lightEmission = 1,
				brightness = 3.2,
				zOffset = 1.6,
			},
			{
				id = "ThunderGlitter",
				texture = TEX_SPARKLES,
				count = 10,
				color = Color3.fromRGB(185, 240, 255),
				size = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0.85 },
						{ time = 1, value = 0 },
					},
				},
				transparency = {
					kind = "Keypoints",
					points = {
						{ time = 0, value = 0.1 },
						{ time = 1, value = 1 },
					},
				},
				lifetime = { min = 0.24, max = 0.42 },
				speed = { min = 6, max = 16 },
				spreadAngle = Vector2.new(180, 180),
				drag = 4,
				lightEmission = 1,
				brightness = 2.6,
				zOffset = 1.5,
			},
		},
	},
	vfxTrigger = {
		presetName = "ThunderAwakening",
		mountIfMissing = false,
		replayTimeline = true,
		targetRole = "target",
	},
}

return Preset
