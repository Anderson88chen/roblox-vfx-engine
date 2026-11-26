--!strict

local Types = require(script.Parent.Parent.Core.Types)

local Preset: Types.CutscenePreset = {
	meta = {
		id = "AwakeningCutscene",
		displayName = "深淵雷霆覺醒過場 (Abyssal Thunder Awakening)",
		category = "Awakening",
		author = "CinemaEngine",
		description = "完整三引擎連動：AbyssalDarkFantasy 壓境 → ThunderAwakening 蓄力爆發 → CriticalThunderImpact 衝擊震動 → 多段 Catmull-Rom 環繞推近仰角運鏡與電影黑邊字幕。",
		tags = { "awakening", "lightning", "tri-engine", "orbital", "dramatic" },
	},
	duration = 4.6,
	restoreAtmosOnEnd = true,
	restoreAtmosDuration = 0.75,
	unmountVFXOnEnd = true,
	camera = {
		interpolation = "CatmullRom",
		relativeToSubject = true,
		lockSubjectAtStart = false,
		keyframes = {
			{
				time = 0.0,
				subjectOffset = Vector3.new(6.5, 2.2, -11.5),
				lookAtOffset = Vector3.new(0, 1.8, 0),
				fov = 68,
				rollDegrees = -4,
			},
			{
				time = 0.75,
				subjectOffset = Vector3.new(-4.8, 1.4, -7.2),
				lookAtOffset = Vector3.new(0, 1.9, 0),
				fov = 56,
				rollDegrees = -7,
				easing = "Sine",
				direction = "InOut",
			},
			{
				time = 1.35,
				subjectOffset = Vector3.new(-2.4, 0.45, -4.8),
				lookAtOffset = Vector3.new(0, 2.3, 0),
				fov = 48,
				rollDegrees = -9,
				easing = "Quad",
				direction = "In",
			},
			{
				time = 1.58,
				subjectOffset = Vector3.new(4.2, 0.25, -8.8),
				lookAtOffset = Vector3.new(0, 3.2, 0),
				fov = 80,
				rollDegrees = 6,
				easing = "Expo",
				direction = "Out",
			},
			{
				time = 2.85,
				subjectOffset = Vector3.new(9.2, 2.8, 4.5),
				lookAtOffset = Vector3.new(0, 2.4, 0),
				fov = 64,
				rollDegrees = 2,
				easing = "Cubic",
				direction = "InOut",
			},
			{
				time = 4.6,
				subjectOffset = Vector3.new(0.8, 3.0, 9.5),
				lookAtOffset = Vector3.new(0, 2.0, 0),
				fov = 70,
				rollDegrees = 0,
				easing = "Sine",
				direction = "InOut",
			},
		},
	},
	letterbox = {
		enabled = true,
		barRatio = 0.12,
		color = Color3.new(0, 0, 0),
		fadeInDuration = 0.35,
		fadeOutDuration = 0.45,
		subtitleHeading = "AWAKENING SEQUENCE // 01",
		title = "THUNDER AWAKENING",
		titleDuration = 2.1,
	},
	subtitles = {
		{
			startTime = 0.2,
			endTime = 1.35,
			text = "深淵的雷鳴正在匯聚——極限即將臨界。",
			color = Color3.fromRGB(190, 230, 255),
		},
		{
			startTime = 1.45,
			endTime = 3.2,
			text = "「蒼雷解放！」",
			color = Color3.fromRGB(140, 225, 255),
		},
		{
			startTime = 3.3,
			endTime = 4.35,
			text = "狂暴電弧已徹底覺醒。",
			color = Color3.fromRGB(235, 245, 255),
		},
	},
	events = {
		{
			time = 0.0,
			action = "AtmosApply",
			presetName = "AbyssalDarkFantasy",
			duration = 1.0,
		},
		{
			time = 0.0,
			action = "VFXMount",
			presetName = "ThunderAwakening",
			scale = 1.0,
		},
		{
			time = 0.25,
			action = "RigImpulse",
			impulse = Vector3.new(-math.rad(6), -0.14, 0),
		},
		{
			time = 1.40,
			action = "RigImpulse",
			impulse = Vector3.new(math.rad(16), 0.24, math.rad(5)),
		},
		{
			time = 1.42,
			action = "JuicePlay",
			presetName = "CriticalThunderImpact",
			intensity = 1.0,
			scale = 1.15,
			spatialOnly = true,
		},
		{
			time = 3.85,
			action = "AtmosReset",
			duration = 0.75,
		},
	},
}

return Preset
