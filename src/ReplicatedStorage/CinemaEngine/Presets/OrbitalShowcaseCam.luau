--!strict

local Types = require(script.Parent.Parent.Core.Types)

local Preset: Types.CutscenePreset = {
	meta = {
		id = "OrbitalShowcaseCam",
		displayName = "星環光環環繞特寫 (Orbital Showcase Cam)",
		category = "Showcase",
		author = "CinemaEngine",
		description = "角色與 AstralDualRing 環繞特寫運鏡：流暢 360° Catmull-Rom 環繞推鏡、微幅荷蘭角與柔和電影黑邊。",
		tags = { "showcase", "orbital", "aura", "portrait" },
	},
	duration = 4.8,
	restoreAtmosOnEnd = false,
	unmountVFXOnEnd = true,
	camera = {
		interpolation = "CatmullRom",
		relativeToSubject = true,
		lockSubjectAtStart = false,
		keyframes = {
			{
				time = 0.0,
				subjectOffset = Vector3.new(0, 2.2, -9.5),
				lookAtOffset = Vector3.new(0, 1.8, 0),
				fov = 62,
				rollDegrees = 0,
			},
			{
				time = 1.2,
				subjectOffset = Vector3.new(7.5, 1.6, -2.0),
				lookAtOffset = Vector3.new(0, 2.0, 0),
				fov = 52,
				rollDegrees = 3.5,
				easing = "Sine",
				direction = "InOut",
			},
			{
				time = 2.4,
				subjectOffset = Vector3.new(0.5, 2.8, 7.6),
				lookAtOffset = Vector3.new(0, 2.1, 0),
				fov = 48,
				rollDegrees = 0,
				easing = "Sine",
				direction = "InOut",
			},
			{
				time = 3.6,
				subjectOffset = Vector3.new(-7.2, 1.4, -1.5),
				lookAtOffset = Vector3.new(0, 2.2, 0),
				fov = 54,
				rollDegrees = -3.5,
				easing = "Sine",
				direction = "InOut",
			},
			{
				time = 4.8,
				subjectOffset = Vector3.new(0, 2.5, 9.0),
				lookAtOffset = Vector3.new(0, 1.8, 0),
				fov = 68,
				rollDegrees = 0,
				easing = "Cubic",
				direction = "InOut",
			},
		},
	},
	letterbox = {
		enabled = true,
		barRatio = 0.095,
		color = Color3.new(0, 0, 0),
		fadeInDuration = 0.4,
		fadeOutDuration = 0.4,
		subtitleHeading = "AURA SHOWCASE",
		title = "ASTRAL DUAL RING",
		titleDuration = 2.0,
	},
	subtitles = {
		{
			startTime = 0.4,
			endTime = 2.6,
			text = "雙重星軌與輝光光環已同步展開。",
			color = Color3.fromRGB(220, 235, 255),
		},
	},
	events = {
		{
			time = 0.0,
			action = "VFXMount",
			presetName = "AstralDualRing",
			scale = 1.0,
		},
		{
			time = 1.8,
			action = "RigImpulse",
			impulse = Vector3.new(math.rad(4), 0.08, 0),
		},
	},
}

return Preset
