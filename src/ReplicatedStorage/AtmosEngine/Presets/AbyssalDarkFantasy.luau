--!strict

local Types = require(script.Parent.Parent.Core.Types)

local Preset: Types.AtmosPreset = {
	meta = {
		id = "AbyssalDarkFantasy",
		displayName = "深淵暗黑奇幻 (Abyssal Dark Fantasy)",
		category = "Fantasy",
		author = "AtmosEngine",
		description = "低飽和冷冽深淵薄暮，濃密暗紫與幽青體積霧營造神秘壓迫感，適合魔王戰與地牢區域。",
		tags = { "dark", "fantasy", "abyss", "fog", "dungeon" },
	},
	lighting = {
		ClockTime = 20.5,
		Brightness = 0.65,
		Ambient = Color3.fromRGB(24, 20, 38),
		OutdoorAmbient = Color3.fromRGB(40, 48, 72),
		ColorShift_Top = Color3.fromRGB(88, 72, 138),
		ColorShift_Bottom = Color3.fromRGB(22, 42, 54),
		EnvironmentDiffuseScale = 0.65,
		EnvironmentSpecularScale = 0.75,
		ExposureCompensation = -0.15,
		GeographicLatitude = 55,
		ShadowSoftness = 0.4,
		GlobalShadows = true,
	},
	atmosphere = {
		Density = 0.52,
		Offset = 0.05,
		Color = Color3.fromRGB(72, 92, 118),
		Decay = Color3.fromRGB(48, 34, 82),
		Glare = 0.1,
		Haze = 4.5,
	},
	sky = {
		CelestialBodiesShown = true,
		SunAngularSize = 14,
		MoonAngularSize = 20,
		StarCount = 1800,
	},
	bloom = {
		Enabled = true,
		Intensity = 0.65,
		Size = 22,
		Threshold = 1.15,
	},
	colorCorrection = {
		Enabled = true,
		Brightness = -0.05,
		Contrast = 0.2,
		Saturation = -0.22,
		TintColor = Color3.fromRGB(208, 215, 245),
	},
	depthOfField = {
		Enabled = true,
		FarIntensity = 0.28,
		FocusDistance = 30,
		InFocusRadius = 26,
		NearIntensity = 0.05,
	},
}

return Preset
