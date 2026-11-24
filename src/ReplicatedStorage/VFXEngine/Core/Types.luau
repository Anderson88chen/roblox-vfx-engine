--!strict

export type BezierCurveSpec = {
	kind: "Bezier",
	y0: number,
	cx1: number,
	cy1: number,
	cx2: number,
	cy2: number,
	y3: number,
	samples: number?,
	envelope: number?,
	scale: number?,
}

export type PresetCurveName =
	"Linear"
	| "EaseIn"
	| "EaseOut"
	| "EaseInOut"
	| "Bell"
	| "FadeInOut"
	| "SharpDecay"
	| "Pulse"
	| "ShrinkOut"
	| "PopAndFade"

export type PresetCurveSpec = {
	kind: "Preset",
	name: PresetCurveName,
	scale: number?,
	invert: boolean?,
	samples: number?,
	envelope: number?,
}

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
	| BezierCurveSpec
	| PresetCurveSpec
	| KeypointsSpec

export type ColorStop = {
	time: number,
	color: Color3,
}

export type ColorCurveSpec =
	Color3
	| ColorSequence
	| { ColorStop }

export type NumberRangeSpec =
	number
	| { number }
	| NumberRange

export type RigConfig = {
	orbitCount: number?,
	pillarHeight: number?,
	haloOffset: number?,
	groundLift: number?,
	customAnchors: { [string]: Vector3 }?,
}

export type OrbitSpec = {
	id: string,
	group: string?,
	anchorIndex: number,
	radius: number,
	angularSpeed: number,
	phaseOffset: number?,
	heightOffset: number?,
	tiltDegrees: Vector3?,
	trailHalfWidth: number?,
	radiusPulseAmp: number?,
	radiusPulseFreq: number?,
	verticalBobAmp: number?,
	verticalBobFreq: number?,
}

export type LightPulseSpec = {
	amplitude: number,
	frequency: number,
	rangeAmplitude: number?,
	phaseOffset: number?,
}

export type ParticleSpec = {
	id: string,
	tags: { string }?,
	anchor: string,
	enabledByDefault: boolean?,
	texture: string,
	color: ColorCurveSpec?,
	size: NumberCurveSpec?,
	transparency: NumberCurveSpec?,
	squash: NumberCurveSpec?,
	lifetime: NumberRangeSpec?,
	rate: number?,
	speed: NumberRangeSpec?,
	spreadAngle: Vector2?,
	acceleration: Vector3?,
	drag: number?,
	rotation: NumberRangeSpec?,
	rotSpeed: NumberRangeSpec?,
	emissionDirection: Enum.NormalId?,
	orientation: Enum.ParticleOrientation?,
	lightEmission: number?,
	lightInfluence: number?,
	brightness: number?,
	zOffset: number?,
	lockedToPart: boolean?,
	flipbookLayout: Enum.ParticleFlipbookLayout?,
	flipbookMode: Enum.ParticleFlipbookMode?,
	flipbookFramerate: NumberRangeSpec?,
	timeScale: number?,
	velocityInheritance: number?,
	windAffectsDrag: boolean?,
}

export type BeamSpec = {
	id: string,
	tags: { string }?,
	anchor0: string,
	anchor1: string,
	enabledByDefault: boolean?,
	texture: string?,
	color: ColorCurveSpec?,
	transparency: NumberCurveSpec?,
	width0: number?,
	width1: number?,
	curveSize0: number?,
	curveSize1: number?,
	segments: number?,
	textureLength: number?,
	textureMode: Enum.TextureMode?,
	textureSpeed: number?,
	faceCamera: boolean?,
	lightEmission: number?,
	lightInfluence: number?,
	brightness: number?,
	zOffset: number?,
}

export type TrailSpec = {
	id: string,
	tags: { string }?,
	anchor0: string,
	anchor1: string,
	enabledByDefault: boolean?,
	texture: string?,
	color: ColorCurveSpec?,
	transparency: NumberCurveSpec?,
	widthScale: NumberCurveSpec?,
	lifetime: number?,
	minLength: number?,
	maxLength: number?,
	textureLength: number?,
	textureMode: Enum.TextureMode?,
	faceCamera: boolean?,
	lightEmission: number?,
	lightInfluence: number?,
	brightness: number?,
}

export type LightSpec = {
	id: string,
	tags: { string }?,
	anchor: string,
	enabledByDefault: boolean?,
	color: Color3?,
	brightness: number?,
	range: number?,
	shadows: boolean?,
	pulse: LightPulseSpec?,
}

export type TimelineActionType =
	"SetEnabled"
	| "EmitBurst"
	| "TweenBeamWidth"
	| "FlashLight"
	| "SetOrbitSpeed"
	| "SetOrbitRadiusScale"

export type TimelineStep = {
	time: number,
	action: TimelineActionType,
	targetId: string?,
	targetTag: string?,
	enabled: boolean?,
	count: number?,
	width0: number?,
	width1: number?,
	duration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?,
	peakBrightness: number?,
	peakRange: number?,
	speedMultiplier: number?,
	radiusMultiplier: number?,
}

export type TimelineConfig = {
	loop: boolean?,
	loopDuration: number?,
	steps: { TimelineStep },
}

export type PresetMeta = {
	id: string,
	displayName: string,
	author: string?,
	description: string?,
	tags: { string }?,
}

export type AuraPreset = {
	meta: PresetMeta,
	rig: RigConfig?,
	orbits: { OrbitSpec }?,
	particles: { ParticleSpec }?,
	beams: { BeamSpec }?,
	trails: { TrailSpec }?,
	lights: { LightSpec }?,
	timeline: TimelineConfig?,
}

export type MountOptions = {
	scale: number?,
	autoplay: boolean?,
	forceReload: boolean?,
}

export type RigContext = {
	character: Model,
	hrp: BasePart,
	humanoid: Humanoid?,
	rigType: Enum.HumanoidRigType?,
	scale: number,
	sessionId: string,
	groundY: number,
	headTopY: number,
	anchors: { [string]: Attachment },
	instances: { Instance },
}

export type LightMeta = {
	instance: PointLight,
	baseBrightness: number,
	baseRange: number,
	pulse: LightPulseSpec?,
}

export type BeamMeta = {
	instance: Beam,
	baseWidth0: number,
	baseWidth1: number,
}

export type InstanceRegistry = {
	byId: { [string]: Instance },
	byTag: { [string]: { Instance } },
	all: { Instance },
	particles: { ParticleEmitter },
	beams: { Beam },
	trails: { Trail },
	lights: { LightMeta },
	beamMetaById: { [string]: BeamMeta },
	lightMetaById: { [string]: LightMeta },
}

export type OrbitControllerHandle = {
	Step: (self: OrbitControllerHandle, dt: number) -> (),
	SetGroupSpeedMultiplier: (self: OrbitControllerHandle, group: string, multiplier: number) -> (),
	SetGroupRadiusMultiplier: (self: OrbitControllerHandle, group: string, multiplier: number) -> (),
	TriggerLightFlash: (
		self: OrbitControllerHandle,
		lightId: string,
		peakBrightness: number?,
		peakRange: number?,
		duration: number?
	) -> (),
	Destroy: (self: OrbitControllerHandle) -> (),
}

export type TimelineHandle = {
	Start: (self: TimelineHandle) -> (),
	Replay: (self: TimelineHandle) -> (),
	Destroy: (self: TimelineHandle) -> (),
}

export type AuraHandle = {
	presetId: string,
	character: Model,
	scale: number,
	rig: RigContext,
	registry: InstanceRegistry,
	orbitController: OrbitControllerHandle,
	timeline: TimelineHandle?,
	Destroy: (self: AuraHandle) -> (),
	IsDestroyed: (self: AuraHandle) -> boolean,
}

return nil
