--!strict

export type PresetMeta = {
	id: string,
	displayName: string,
	category: string?,
	author: string?,
	description: string?,
	tags: { string }?,
}

export type RangeSpec =
	number
	| { number }
	| NumberRange
	| { min: number, max: number }

export type NumberPoint = {
	time: number,
	value: number,
	envelope: number?,
}

export type KeypointsSpec = {
	kind: "Keypoints",
	points: { NumberPoint },
}

export type NumberCurveSpec =
	number
	| NumberSequence
	| KeypointsSpec
	| { NumberPoint }

export type ColorStop = {
	time: number,
	color: Color3,
}

export type ColorCurveSpec =
	Color3
	| ColorSequence
	| { ColorStop }

export type CameraShakeSpec = {
	magnitude: number,
	roughness: number,
	fadeIn: number?,
	sustain: number?,
	fadeOut: number?,
	posInfluence: Vector3?,
	rotInfluence: Vector3?,
	fovPunch: number?,
	maxDistance: number?,
}

export type HitstopSpec = {
	duration: number,
	timeScale: number?,
	affectAnimations: boolean?,
	affectParticles: boolean?,
	applyToAttacker: boolean?,
	applyToTarget: boolean?,
}

export type HitFlashSpec = {
	flashColor: Color3?,
	targetColor: Color3?,
	fillTransparency: number?,
	endFillTransparency: number?,
	outlineColor: Color3?,
	outlineTransparency: number?,
	endOutlineTransparency: number?,
	holdDuration: number?,
	duration: number?,
	depthMode: Enum.HighlightDepthMode?,
}

export type SoundSpec = {
	id: string?,
	soundId: string,
	group: string?,
	maxConcurrent: number?,
	spatial: boolean?,
	volume: number?,
	volumeRange: RangeSpec?,
	pitchRange: RangeSpec?,
	rollOffMinDistance: number?,
	rollOffMaxDistance: number?,
	delay: number?,
}

export type BurstParticleSpec = {
	id: string?,
	texture: string,
	count: number,
	color: ColorCurveSpec?,
	size: NumberCurveSpec?,
	transparency: NumberCurveSpec?,
	squash: NumberCurveSpec?,
	lifetime: RangeSpec?,
	speed: RangeSpec?,
	spreadAngle: Vector2?,
	acceleration: Vector3?,
	drag: number?,
	rotation: RangeSpec?,
	rotSpeed: RangeSpec?,
	orientation: Enum.ParticleOrientation?,
	emissionDirection: Enum.NormalId?,
	lightEmission: number?,
	lightInfluence: number?,
	brightness: number?,
	zOffset: number?,
}

export type WorldBurstLightSpec = {
	color: Color3?,
	brightness: number?,
	range: number?,
	duration: number?,
}

export type WorldBurstSpec = {
	particles: { BurstParticleSpec }?,
	light: WorldBurstLightSpec?,
	scale: number?,
}

export type VFXTriggerSpec = {
	presetName: string?,
	mountIfMissing: boolean?,
	replayTimeline: boolean?,
	scale: number?,
	targetRole: ("attacker" | "target")?,
}

export type JuicePreset = {
	meta: PresetMeta,
	cameraShake: CameraShakeSpec?,
	hitstop: HitstopSpec?,
	hitFlash: HitFlashSpec?,
	sounds: { SoundSpec }?,
	worldBurst: WorldBurstSpec?,
	vfxTrigger: VFXTriggerSpec?,
}

export type PlayContext = {
	position: Vector3?,
	cframe: CFrame?,
	attacker: Model?,
	target: Model?,
	targets: { Model }?,
	targetCharacter: Model?,
	vfxCharacter: Model?,
	vfxAura: string?,
	intensity: number?,
	scale: number?,
	forceReload: boolean?,
}

export type CameraShakeHandle = {
	Stop: (self: CameraShakeHandle, fadeOutOverride: number?) -> (),
	IsActive: (self: CameraShakeHandle) -> boolean,
}

export type JuiceHandle = {
	presetId: string,
	intensity: number,
	Stop: (self: JuiceHandle) -> (),
	IsActive: (self: JuiceHandle) -> boolean,
}

return nil
