--!strict

local Types = require(script.Parent.Parent.Core.Types)

local Preset: Types.AtmosPreset = {
	meta = {
		id = "GoldenHourSunset",
		displayName = "黃金時刻日落 (Golden Hour Sunset)",
		category = "Sunset",
		author = "AtmosEngine",
		description = "低角度金橘夕陽與暖琥珀大氣散射，搭配強烈太陽光暈、寬廣光束與電影感暖色調。",
		tags = { "sunset", "golden-hour", "warm", "cinematic", "sunrays" },
	},
	lighting = {
		ClockTime = 17.85,
		Brightness = 2.2,
		Ambient = Color3.fromRGB(98, 66, 56),
		OutdoorAmbient = Color3.fromRGB(158, 108, 86),
		ColorShift_Top = Color3.fromRGB(255, 188, 118),
		ColorShift_Bottom = Color3.fromRGB(130, 88, 112),
		EnvironmentDiffuseScale = 0.9,
		EnvironmentSpecularScale = 0.95,
		ExposureCompensation = 0.05,
		GeographicLatitude = 28,
		ShadowSoftness = 0.32,
		GlobalShadows = true,
	},
	atmosphere = {
		Density = 0.32,
		Offset = 0.25,
		Color = Color3.fromRGB(255, 198, 148),
		Decay = Color3.fromRGB(225, 112, 68),
		Glare = 0.55,
		Haze = 2.4,
	},
	sky = {
		CelestialBodiesShown = true,
		SunAngularSize = 26,
		MoonAngularSize = 11,
		StarCount = 250,
	},
	bloom = {
		Enabled = true,
		Intensity = 0.75,
		Size = 26,
		Threshold = 1.05,
	},
	colorCorrection = {
		Enabled = true,
		Brightness = 0.02,
		Contrast = 0.14,
		Saturation = 0.18,
		TintColor = Color3.fromRGB(255, 240, 222),
	},
	sunRays = {
		Enabled = true,
		Intensity = 0.22,
		Spread = 0.78,
	},
}

return Preset
