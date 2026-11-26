--!strict

export type PresetMeta = {
	id: string,
	displayName: string,
	category: string?,
	author: string?,
	description: string?,
	tags: { string }?,
}

export type ArcAxis = "Yaw" | "Pitch" | "Roll"

export type HingeSide = "Inner" | "Outer" | "Center"

export type MinMaxRange = {
	min: number,
	max: number,
}

export type ArcSpec = {
	name: string?,
	origin: CFrame?,
	partSize: Vector3,
	axis: ArcAxis?,
	angleDegrees: number,
	count: number,
	hingeSide: HingeSide?,
	spiralStep: number?,
	sizeScalePerStep: Vector3?,
	uniformScalePerStep: number?,
	material: Enum.Material?,
	color: Color3?,
	alternateMaterial: Enum.Material?,
	alternateColor: Color3?,
	transparency: number?,
	reflectance: number?,
	anchored: boolean?,
	canCollide: boolean?,
	castShadow: boolean?,
	addRimTrim: boolean?,
	trimColor: Color3?,
	trimMaterial: Enum.Material?,
}

export type PolygonRingMode = "RingBase" | "Pillars" | "TwinArchPillars" | "SteppedRing"

export type PolygonRingSpec = {
	name: string?,
	center: CFrame?,
	radius: number,
	count: number,
	mode: PolygonRingMode?,
	segmentSize: Vector3?,
	pillarSize: Vector3?,
	archWidth: number?,
	archHeight: number?,
	archThickness: number?,
	stepCount: number?,
	stepHeight: number?,
	stepInset: number?,
	faceCenter: boolean?,
	skipIndices: { number }?,
	material: Enum.Material?,
	color: Color3?,
	accentMaterial: Enum.Material?,
	accentColor: Color3?,
	transparency: number?,
	anchored: boolean?,
	canCollide: boolean?,
	castShadow: boolean?,
	addPillarCap: boolean?,
	addPillarLight: boolean?,
	lightColor: Color3?,
	lightRange: number?,
	lightBrightness: number?,
}

export type ScatterAssetKind =
	"CrystalCluster"
	| "StonePillar"
	| "StylizedShrub"
	| "FloatingRune"
	| "NeonCrate"
	| "MossBoulder"
	| "RunicObelisk"

export type ScatterAssetTemplate = {
	kind: ScatterAssetKind,
	weight: number?,
	primaryColor: Color3?,
	secondaryColor: Color3?,
	accentColor: Color3?,
	primaryMaterial: Enum.Material?,
	secondaryMaterial: Enum.Material?,
	lightColor: Color3?,
	lightRange: number?,
	lightBrightness: number?,
	scaleMultiplier: number?,
	yOffset: number?,
}

export type ScatterSpec = {
	name: string?,
	origin: CFrame?,
	areaSize: Vector2?,
	radius: number?,
	minDistance: number,
	seed: number?,
	kAttempts: number?,
	maxInstances: number?,
	clearRadius: number?,
	minSlopeDegrees: number?,
	maxSlopeDegrees: number?,
	alignToNormal: number?,
	scaleRange: (NumberRange | MinMaxRange)?,
	tiltRangeDegrees: number?,
	raycastHeight: number?,
	raycastDepth: number?,
	fallbackToOriginPlane: boolean?,
	templates: { ScatterAssetTemplate },
}

export type HangingPropKind = "Lantern" | "EnergyCrystal" | "WarningSign" | "NeonSign" | "VineCluster"

export type HangingPropSpec = {
	t: number,
	kind: HangingPropKind,
	dropLength: number?,
	scale: number?,
	color: Color3?,
	accentColor: Color3?,
	lightColor: Color3?,
	lightRange: number?,
	lightBrightness: number?,
}

export type RopeStyle = "Rope" | "Chain" | "NeonCable" | "Vine"

export type RopeSpec = {
	name: string?,
	p0: Vector3,
	p1: Vector3,
	sag: number?,
	segments: number?,
	thickness: number?,
	style: RopeStyle?,
	color: Color3?,
	secondaryColor: Color3?,
	material: Enum.Material?,
	useCosh: boolean?,
	addJoints: boolean?,
	hangingProps: { HangingPropSpec }?,
	canCollide: boolean?,
	castShadow: boolean?,
	anchored: boolean?,
}

export type GroundPadSpec = {
	enabled: boolean?,
	size: Vector3?,
	color: Color3?,
	material: Enum.Material?,
	offset: Vector3?,
	canCollide: boolean?,
	castShadow: boolean?,
}

export type WorldScenePreset = {
	meta: PresetMeta,
	defaultSeed: number?,
	groundPad: GroundPadSpec?,
	arcs: { ArcSpec }?,
	polygonRings: { PolygonRingSpec }?,
	scatters: { ScatterSpec }?,
	ropes: { RopeSpec }?,
}

export type BuildOptions = {
	origin: CFrame?,
	seed: number?,
	scale: number?,
	forceReload: boolean?,
	clearPrevious: boolean?,
	ignoreInstances: { Instance }?,
	batchSize: number?,
}

export type WorldSceneHandle = {
	id: string,
	presetId: string,
	rootFolder: Folder,
	partCount: number,
	createdAt: number,
	Clear: (self: WorldSceneHandle) -> (),
	GetPartCount: (self: WorldSceneHandle) -> number,
	GetRoot: (self: WorldSceneHandle) -> Folder,
}

return nil
