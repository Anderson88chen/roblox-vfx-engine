--!strict

local Types = require(script.Parent.Parent.Core.Types)

local PILLAR_RADIUS = 34
local PILLAR_COUNT = 8
local PILLAR_TOP_Y = 14.5

local function buildSanctuaryChains(): { Types.RopeSpec }
	local ropes: { Types.RopeSpec } = {}
	for i = 1, PILLAR_COUNT do
		local nextIdx = (i % PILLAR_COUNT) + 1
		local a0 = ((i - 1) / PILLAR_COUNT) * math.pi * 2
		local a1 = ((nextIdx - 1) / PILLAR_COUNT) * math.pi * 2

		local p0 = Vector3.new(math.cos(a0) * PILLAR_RADIUS, PILLAR_TOP_Y, math.sin(a0) * PILLAR_RADIUS)
		local p1 = Vector3.new(math.cos(a1) * PILLAR_RADIUS, PILLAR_TOP_Y, math.sin(a1) * PILLAR_RADIUS)

		local isEntrance = (i == 2 or i == 6)
		table.insert(ropes, {
			name = string.format("SanctuaryChain_%02d", i),
			p0 = p0,
			p1 = p1,
			sag = if isEntrance then 2.4 else 3.8,
			segments = 12,
			thickness = 0.28,
			style = "Chain",
			color = Color3.fromRGB(92, 108, 138),
			secondaryColor = Color3.fromRGB(165, 215, 255),
			useCosh = true,
			addJoints = true,
			hangingProps = {
				{
					t = 0.5,
					kind = "EnergyCrystal",
					dropLength = 1.6,
					scale = 1.1,
					color = Color3.fromRGB(125, 220, 255),
					accentColor = Color3.fromRGB(68, 76, 102),
					lightColor = Color3.fromRGB(130, 215, 255),
					lightRange = 22,
					lightBrightness = 1.4,
				},
			},
		})
	end
	return ropes
end

local Preset: Types.WorldScenePreset = {
	meta = {
		id = "AstralSanctuaryArena",
		displayName = "星界聖殿競技場 (Astral Sanctuary Arena)",
		category = "FantasyArena",
		author = "WorldGenEngine",
		description = "同心多邊形階梯聖殿、雙柱拱門柱列、對稱螺旋階梯、柱間懸垂星界水晶鎖鏈與外圍泊松星晶石碑散布。",
		tags = { "astral", "sanctuary", "arena", "archimedes", "catenary" },
	},
	defaultSeed = 108,
	polygonRings = {
		{
			name = "InnerSteppedDais",
			center = CFrame.new(0, 0, 0),
			radius = 15,
			count = 12,
			mode = "SteppedRing",
			segmentSize = Vector3.new(8, 0.85, 3.8),
			stepCount = 3,
			stepHeight = 0.65,
			stepInset = 2.8,
			material = Enum.Material.Marble,
			color = Color3.fromRGB(58, 64, 86),
			accentMaterial = Enum.Material.Neon,
			accentColor = Color3.fromRGB(115, 210, 255),
		},
		{
			name = "ArcaneCoreRing",
			center = CFrame.new(0, 0.17, 0),
			radius = 6.5,
			count = 16,
			mode = "RingBase",
			segmentSize = Vector3.new(2.7, 0.3, 0.7),
			material = Enum.Material.Neon,
			color = Color3.fromRGB(120, 210, 255),
			canCollide = false,
			castShadow = false,
		},
		{
			name = "OuterSanctuaryArches",
			center = CFrame.new(0, 0, 0),
			radius = PILLAR_RADIUS,
			count = PILLAR_COUNT,
			mode = "TwinArchPillars",
			pillarSize = Vector3.new(2.0, 14.5, 2.0),
			archWidth = 6.8,
			archHeight = 14.5,
			archThickness = 1.9,
			material = Enum.Material.Granite,
			color = Color3.fromRGB(72, 78, 102),
			accentMaterial = Enum.Material.Neon,
			accentColor = Color3.fromRGB(130, 215, 255),
			addPillarLight = true,
			lightColor = Color3.fromRGB(135, 215, 255),
			lightRange = 26,
			lightBrightness = 1.35,
		},
	},
	arcs = {
		{
			name = "EastSpiralStair",
			origin = CFrame.new(22, 0.5, 0) * CFrame.Angles(0, 0, 0),
			partSize = Vector3.new(4.2, 0.65, 2.6),
			axis = "Yaw",
			angleDegrees = 11,
			count = 14,
			hingeSide = "Inner",
			spiralStep = 0.52,
			material = Enum.Material.Marble,
			color = Color3.fromRGB(76, 84, 110),
			alternateMaterial = Enum.Material.Slate,
			alternateColor = Color3.fromRGB(62, 68, 92),
			addRimTrim = true,
			trimColor = Color3.fromRGB(125, 215, 255),
		},
		{
			name = "WestSpiralStair",
			origin = CFrame.new(-22, 0.5, 0) * CFrame.Angles(0, math.pi, 0),
			partSize = Vector3.new(4.2, 0.65, 2.6),
			axis = "Yaw",
			angleDegrees = 11,
			count = 14,
			hingeSide = "Inner",
			spiralStep = 0.52,
			material = Enum.Material.Marble,
			color = Color3.fromRGB(76, 84, 110),
			alternateMaterial = Enum.Material.Slate,
			alternateColor = Color3.fromRGB(62, 68, 92),
			addRimTrim = true,
			trimColor = Color3.fromRGB(165, 140, 255),
		},
	},
	ropes = buildSanctuaryChains(),
	scatters = {
		{
			name = "OuterAstralScatter",
			origin = CFrame.new(0, 0, 0),
			radius = 54,
			clearRadius = 18.5,
			minDistance = 6.5,
			kAttempts = 20,
			maxInstances = 48,
			minSlopeDegrees = 0,
			maxSlopeDegrees = 42,
			alignToNormal = 0.3,
			scaleRange = NumberRange.new(0.85, 1.35),
			tiltRangeDegrees = 5,
			fallbackToOriginPlane = true,
			templates = {
				{
					kind = "CrystalCluster",
					weight = 3,
					primaryColor = Color3.fromRGB(110, 215, 255),
					accentColor = Color3.fromRGB(205, 245, 255),
					secondaryColor = Color3.fromRGB(54, 60, 82),
					lightColor = Color3.fromRGB(120, 220, 255),
					lightRange = 16,
					lightBrightness = 1.1,
				},
				{
					kind = "FloatingRune",
					weight = 2,
					primaryColor = Color3.fromRGB(165, 130, 255),
					accentColor = Color3.fromRGB(115, 225, 255),
					secondaryColor = Color3.fromRGB(56, 60, 82),
					lightColor = Color3.fromRGB(165, 135, 255),
					lightRange = 14,
					lightBrightness = 1.0,
				},
				{
					kind = "RunicObelisk",
					weight = 1.5,
					primaryColor = Color3.fromRGB(120, 215, 255),
					secondaryColor = Color3.fromRGB(66, 72, 96),
					lightColor = Color3.fromRGB(120, 215, 255),
					lightRange = 18,
					lightBrightness = 1.2,
				},
			},
		},
	},
}

return Preset
