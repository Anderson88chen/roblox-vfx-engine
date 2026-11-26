--!strict

local Types = require(script.Parent.Parent.Core.Types)

local Preset: Types.AtmosPreset = {
	meta = {
		id = "CrispAnimeNoon",
		displayName = "晴空動畫正午 (Crisp Anime Noon)",
		category = "Day",
		author = "AtmosEngine",
		description = "高通透日系動畫正午光影，具備蔚藍大氣散射、銳利陰影、柔和泛光與明亮飽和色彩分級。",
		tags = { "day", "noon", "anime", "bright", "clear" },
	},
	lighting = {
		ClockTime = 13.5,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(108, 128, 158),
		OutdoorAmbient = Color3.fromRGB(132, 162, 198),
		ColorShift_Top = Color3.fromRGB(255, 250, 238),
		ColorShift_Bottom = Color3.fromRGB(140, 175, 220),
		EnvironmentDiffuseScale = 1.0,
		EnvironmentSpecularScale = 1.0,
		ExposureCompensation = 0.1,
		GeographicLatitude = 35,
		ShadowSoftness = 0.15,
		GlobalShadows = true,
	},
	atmosphere = {
		Density = 0.22,
		Offset = 0.15,
		Color = Color3.fromRGB(185, 222, 255),
		Decay = Color3.fromRGB(115, 165, 235),
		Glare = 0.15,
		Haze = 1.2,
	},
	sky = {
		CelestialBodiesShown = true,
		SunAngularSize = 18,
		MoonAngularSize = 11,
		StarCount = 0,
	},
	bloom = {
		Enabled = true,
		Intensity = 0.45,
		Size = 20,
		Threshold = 1.35,
	},
	colorCorrection = {
		Enabled = true,
		Brightness = 0.03,
		Contrast = 0.12,
		Saturation = 0.22,
		TintColor = Color3.fromRGB(250, 253, 255),
	},
	sunRays = {
		Enabled = true,
		Intensity = 0.08,
		Spread = 0.55,
	},
}

return Preset
