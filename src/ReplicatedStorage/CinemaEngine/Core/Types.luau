--!strict

export type PresetMeta = {
	id: string,
	displayName: string,
	category: string?,
	author: string?,
	description: string?,
	tags: { string }?,
}

export type EasingName = "Linear" | "Sine" | "Quad" | "Cubic" | "Expo" | "Back"

export type EasingDirectionName = "In" | "Out" | "InOut"

export type CameraInterpolation = "CatmullRom" | "Linear"

export type CameraKeyframe = {
	time: number,
	position: Vector3?,
	lookAt: Vector3?,
	subjectOffset: Vector3?,
	lookAtOffset: Vector3?,
	relativeToSubject: boolean?,
	fov: number?,
	rollDegrees: number?,
	easing: EasingName?,
	direction: EasingDirectionName?,
}

export type CameraTrackSpec = {
	interpolation: CameraInterpolation?,
	relativeToSubject: boolean?,
	lockSubjectAtStart: boolean?,
	keyframes: { CameraKeyframe },
}

export type LetterboxTrackSpec = {
	enabled: boolean?,
	barRatio: number?,
	color: Color3?,
	fadeInDuration: number?,
	fadeOutDuration: number?,
	title: string?,
	subtitleHeading: string?,
	titleDuration: number?,
}

export type SubtitleCue = {
	startTime: number,
	endTime: number?,
	duration: number?,
	speaker: string?,
	text: string,
	color: Color3?,
	fadeIn: number?,
	fadeOut: number?,
}

export type EngineEventAction =
	"VFXMount"
	| "VFXUnmount"
	| "VFXReplay"
	| "JuicePlay"
	| "AtmosApply"
	| "AtmosReset"
	| "RigImpulse"
	| "Callback"

export type EngineEventContext = {
	character: Model?,
	target: Model?,
	origin: Vector3?,
	cframe: CFrame?,
	elapsed: number,
}

export type EngineEventStep = {
	time: number,
	action: EngineEventAction,
	presetName: string?,
	scale: number?,
	intensity: number?,
	duration: number?,
	impulse: Vector3?,
	offset: Vector3?,
	spatialOnly: boolean?,
	forceReload: boolean?,
	callback: ((context: EngineEventContext) -> ())?,
}

export type CutscenePreset = {
	meta: PresetMeta,
	duration: number,
	camera: CameraTrackSpec?,
	letterbox: LetterboxTrackSpec?,
	subtitles: { SubtitleCue }?,
	events: { EngineEventStep }?,
	restoreAtmosOnEnd: boolean?,
	restoreAtmosDuration: number?,
	unmountVFXOnEnd: boolean?,
}

export type CutscenePlayOptions = {
	subject: Model?,
	target: Model?,
	scale: number?,
	intensity: number?,
	forceReload: boolean?,
	onCompleted: ((completedNormally: boolean) -> ())?,
}

export type CinemaHandle = {
	presetId: string,
	Stop: (self: CinemaHandle) -> (),
	IsPlaying: (self: CinemaHandle) -> boolean,
	GetElapsed: (self: CinemaHandle) -> number,
	GetDuration: (self: CinemaHandle) -> number,
}

export type ProceduralRigConfig = {
	breathingEnabled: boolean?,
	breathingFrequency: number?,
	breathingAmplitude: number?,
	leanEnabled: boolean?,
	maxForwardLeanDegrees: number?,
	maxSideLeanDegrees: number?,
	referenceSpeed: number?,
	leanFrequency: number?,
	leanDampingRatio: number?,
	landingSpringEnabled: boolean?,
	landingImpulseScale: number?,
	jumpImpulseScale: number?,
	impulseFrequency: number?,
	impulseDampingRatio: number?,
}

export type ScalarSpring = {
	Update: (self: ScalarSpring, dt: number) -> number,
	SetTarget: (self: ScalarSpring, target: number) -> (),
	Impulse: (self: ScalarSpring, velocityDelta: number) -> (),
	SetValue: (self: ScalarSpring, value: number) -> (),
	SetConfig: (self: ScalarSpring, frequency: number?, dampingRatio: number?) -> (),
	GetValue: (self: ScalarSpring) -> number,
	GetVelocity: (self: ScalarSpring) -> number,
	GetTarget: (self: ScalarSpring) -> number,
}

export type Vector3Spring = {
	Update: (self: Vector3Spring, dt: number) -> Vector3,
	SetTarget: (self: Vector3Spring, target: Vector3) -> (),
	Impulse: (self: Vector3Spring, velocityDelta: Vector3) -> (),
	SetValue: (self: Vector3Spring, value: Vector3) -> (),
	SetConfig: (self: Vector3Spring, frequency: number?, dampingRatio: number?) -> (),
	GetValue: (self: Vector3Spring) -> Vector3,
	GetVelocity: (self: Vector3Spring) -> Vector3,
	GetTarget: (self: Vector3Spring) -> Vector3,
}

return nil
