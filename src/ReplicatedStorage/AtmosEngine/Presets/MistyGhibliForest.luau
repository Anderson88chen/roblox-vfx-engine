--!strict

local Types = require(script.Parent.Parent.Core.Types)

local Preset: Types.AtmosPreset = {
	meta = {
		id = "MistyGhibliForest",
		displayName = "晨霧森境繪本 (Misty Ghibli Forest)",
		category = "Nature",
		author = "AtmosEngine",
		description = "柔和的清晨森林薄霧與暖奶油色陽光灑落感，搭配柔和陰影、細膩光束與自然清新色彩。",
		tags = { "nature", "forest", "morning", "mist", "ghibli", "soft" },
	},
	lighting = {
		ClockTime = 8.4,
		Brightness = 2.15,
		Ambient = Color3.fromRGB(82, 96, 82),
		OutdoorAmbient = Color3.fromRGB(132, 152, 128),
		ColorShift_Top = Color3.fromRGB(255, 244, 214),
		ColorShift_Bottom = Color3.fromRGB(115, 148, 122),
		EnvironmentDiffuseScale = 0.95,
		EnvironmentSpecularScale = 0.85,
		ExposureCompensation = 0.08,
		GeographicLatitude = 32,
		ShadowSoftness = 0.45,
		GlobalShadows = true,
	},
	atmosphere = {
		Density = 0.38,
		Offset = 0.2,
		Color = Color3.fromRGB(218, 236, 208),
		Decay = Color3.fromRGB(172, 198, 165),
		Glare = 0.32,
		Haze = 2.8,
	},
	sky = {
		CelestialBodiesShown = true,
		SunAngularSize = 21,
		MoonAngularSize = 11,
		StarCount = 0,
	},
	bloom = {
		Enabled = true,
		Intensity = 0.55,
		Size = 24,
		Threshold = 1.15,
	},
	colorCorrection = {
		Enabled = true,
		Brightness = 0.03,
		Contrast = 0.08,
		Saturation = 0.16,
		TintColor = Color3.fromRGB(252, 250, 238),
	},
	depthOfField = {
		Enabled = true,
		FarIntensity = 0.14,
		FocusDistance = 48,
		InFocusRadius = 42,
		NearIntensity = 0.02,
	},
	sunRays = {
		Enabled = true,
		Intensity = 0.15,
		Spread = 0.68,
	},
}

return Preset
