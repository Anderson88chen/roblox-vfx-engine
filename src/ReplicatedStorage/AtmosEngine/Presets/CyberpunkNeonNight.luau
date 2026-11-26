--!strict

local Types = require(script.Parent.Parent.Core.Types)

local Preset: Types.AtmosPreset = {
	meta = {
		id = "CyberpunkNeonNight",
		displayName = "賽博霓虹夜城 (Cyberpunk Neon Night)",
		category = "Night",
		author = "AtmosEngine",
		description = "深紫與青藍交錯的賽博龐克深夜氛圍，搭配高強度霓虹泛光、紫藍大氣霧氣與景深。",
		tags = { "night", "cyberpunk", "neon", "sci-fi", "bloom" },
	},
	lighting = {
		ClockTime = 23.0,
		Brightness = 0.85,
		Ambient = Color3.fromRGB(36, 22, 64),
		OutdoorAmbient = Color3.fromRGB(48, 56, 98),
		ColorShift_Top = Color3.fromRGB(165, 95, 255),
		ColorShift_Bottom = Color3.fromRGB(45, 195, 235),
		EnvironmentDiffuseScale = 0.85,
		EnvironmentSpecularScale = 1.0,
		ExposureCompensation = 0.15,
		GeographicLatitude = 42,
		ShadowSoftness = 0.3,
		GlobalShadows = true,
	},
	atmosphere = {
		Density = 0.36,
		Offset = 0.1,
		Color = Color3.fromRGB(80, 145, 215),
		Decay = Color3.fromRGB(145, 55, 195),
		Glare = 0.05,
		Haze = 3.2,
	},
	sky = {
		CelestialBodiesShown = true,
		SunAngularSize = 12,
		MoonAngularSize = 14,
		StarCount = 3500,
	},
	bloom = {
		Enabled = true,
		Intensity = 1.25,
		Size = 28,
		Threshold = 0.85,
	},
	colorCorrection = {
		Enabled = true,
		Brightness = -0.02,
		Contrast = 0.24,
		Saturation = 0.28,
		TintColor = Color3.fromRGB(228, 238, 255),
	},
	depthOfField = {
		Enabled = true,
		FarIntensity = 0.18,
		FocusDistance = 42,
		InFocusRadius = 38,
		NearIntensity = 0.04,
	},
}

return Preset
