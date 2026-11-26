--!strict

export type PresetMeta = {
	id: string,
	displayName: string,
	category: string?,
	author: string?,
	description: string?,
	tags: { string }?,
}

export type LightingSpec = {
	ClockTime: number?,
	Brightness: number?,
	Ambient: Color3?,
	OutdoorAmbient: Color3?,
	ColorShift_Top: Color3?,
	ColorShift_Bottom: Color3?,
	EnvironmentDiffuseScale: number?,
	EnvironmentSpecularScale: number?,
	ExposureCompensation: number?,
	GeographicLatitude: number?,
	ShadowSoftness: number?,
	GlobalShadows: boolean?,
	FogColor: Color3?,
	FogStart: number?,
	FogEnd: number?,
}

export type AtmosphereSpec = {
	Density: number?,
	Offset: number?,
	Color: Color3?,
	Decay: Color3?,
	Glare: number?,
	Haze: number?,
}

export type SkySpec = {
	CelestialBodiesShown: boolean?,
	MoonAngularSize: number?,
	SunAngularSize: number?,
	StarCount: number?,
	SkyboxBk: string?,
	SkyboxDn: string?,
	SkyboxFt: string?,
	SkyboxLf: string?,
	SkyboxRt: string?,
	SkyboxUp: string?,
	MoonTextureId: string?,
	SunTextureId: string?,
}

export type BloomSpec = {
	Enabled: boolean?,
	Intensity: number?,
	Size: number?,
	Threshold: number?,
}

export type ColorCorrectionSpec = {
	Enabled: boolean?,
	Brightness: number?,
	Contrast: number?,
	Saturation: number?,
	TintColor: Color3?,
}

export type DepthOfFieldSpec = {
	Enabled: boolean?,
	FarIntensity: number?,
	FocusDistance: number?,
	InFocusRadius: number?,
	NearIntensity: number?,
}

export type SunRaysSpec = {
	Enabled: boolean?,
	Intensity: number?,
	Spread: number?,
}

export type AtmosPreset = {
	meta: PresetMeta,
	lighting: LightingSpec?,
	atmosphere: AtmosphereSpec?,
	sky: SkySpec?,
	bloom: BloomSpec?,
	colorCorrection: ColorCorrectionSpec?,
	depthOfField: DepthOfFieldSpec?,
	sunRays: SunRaysSpec?,
}

export type ApplyOptions = {
	duration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?,
	forceReload: boolean?,
}

export type ZoneConfig = {
	id: string,
	preset: string | AtmosPreset,
	priority: number?,
	cframe: CFrame?,
	size: Vector3?,
	part: BasePart?,
	transitionDuration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?,
}

export type UnmanagedEffectRecord = {
	instance: Instance,
	wasEnabled: boolean?,
	originalParent: Instance?,
}

export type SnapshotData = {
	capturedAt: number,
	lighting: LightingSpec,
	atmosphere: AtmosphereSpec?,
	sky: SkySpec?,
	bloom: BloomSpec?,
	colorCorrection: ColorCorrectionSpec?,
	depthOfField: DepthOfFieldSpec?,
	sunRays: SunRaysSpec?,
	unmanagedEffects: { UnmanagedEffectRecord },
}

export type ManagedInstances = {
	atmosphere: Atmosphere?,
	sky: Sky?,
	bloom: BloomEffect?,
	colorCorrection: ColorCorrectionEffect?,
	depthOfField: DepthOfFieldEffect?,
	sunRays: SunRaysEffect?,
}

export type TransitionTarget = {
	lighting: LightingSpec?,
	atmosphere: AtmosphereSpec?,
	bloom: BloomSpec?,
	colorCorrection: ColorCorrectionSpec?,
	depthOfField: DepthOfFieldSpec?,
	sunRays: SunRaysSpec?,
}

return nil
