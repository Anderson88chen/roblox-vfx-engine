--!strict

local Types = require(script.Parent.Parent.Core.Types)

local Preset: Types.CutscenePreset = {
	meta = {
		id = "SlashFinisherCam",
		displayName = "極限斬擊終結技運鏡 (Slash Finisher Cam)",
		category = "Combat",
		author = "CinemaEngine",
		description = "快節奏斬擊終結技：急遽拉近蓄勢 → 大斜角揮砍釋放 → HeavySlashHit 衝擊震動與 FOV 擴張回彈。",
		tags = { "combat", "slash", "finisher", "fast", "action" },
	},
	duration = 2.6,
	restoreAtmosOnEnd = false,
	unmountVFXOnEnd = false,
	camera = {
		interpolation = "CatmullRom",
		relativeToSubject = true,
		lockSubjectAtStart = false,
		keyframes = {
			{
				time = 0.0,
				subjectOffset = Vector3.new(3.6, 2.0, -7.5),
				lookAtOffset = Vector3.new(0, 1.6, -1.5),
				fov = 66,
				rollDegrees = -3,
			},
			{
				time = 0.45,
				subjectOffset = Vector3.new(-3.2, 1.1, -4.4),
				lookAtOffset = Vector3.new(0, 1.7, -2.0),
				fov = 50,
				rollDegrees = -12,
				easing = "Back",
				direction = "Out",
			},
			{
				time = 0.92,
				subjectOffset = Vector3.new(-1.8, 0.9, -3.6),
				lookAtOffset = Vector3.new(0, 1.5, -3.5),
				fov = 44,
				rollDegrees = -15,
				easing = "Quad",
				direction = "In",
			},
			{
				time = 1.12,
				subjectOffset = Vector3.new(5.8, 1.6, -9.2),
				lookAtOffset = Vector3.new(0, 1.5, -4.0),
				fov = 84,
				rollDegrees = 11,
				easing = "Expo",
				direction = "Out",
			},
			{
				time = 1.85,
				subjectOffset = Vector3.new(3.4, 2.4, 5.5),
				lookAtOffset = Vector3.new(0, 1.6, -1.5),
				fov = 64,
				rollDegrees = 2,
				easing = "Cubic",
				direction = "InOut",
			},
			{
				time = 2.6,
				subjectOffset = Vector3.new(0, 2.8, 8.2),
				lookAtOffset = Vector3.new(0, 1.6, 0),
				fov = 70,
				rollDegrees = 0,
				easing = "Sine",
				direction = "Out",
			},
		},
	},
	letterbox = {
		enabled = true,
		barRatio = 0.13,
		color = Color3.new(0, 0, 0),
		fadeInDuration = 0.18,
		fadeOutDuration = 0.3,
		subtitleHeading = "FINISHER",
		title = "CRIMSON CLEAVE",
		titleDuration = 1.35,
	},
	subtitles = {
		{
			startTime = 0.88,
			endTime = 2.2,
			text = "「一閃——斷絕！」",
			color = Color3.fromRGB(255, 220, 155),
			fadeIn = 0.08,
			fadeOut = 0.2,
		},
	},
	events = {
		{
			time = 0.35,
			action = "RigImpulse",
			impulse = Vector3.new(math.rad(10), -0.18, -math.rad(8)),
		},
		{
			time = 0.95,
			action = "RigImpulse",
			impulse = Vector3.new(-math.rad(22), -0.25, math.rad(14)),
		},
		{
			time = 0.96,
			action = "JuicePlay",
			presetName = "HeavySlashHit",
			offset = Vector3.new(0, 1.3, -3.8),
			intensity = 1.15,
			scale = 1.2,
		},
	},
}

return Preset
