--!strict

local Types = require(script.Parent.Parent.Core.Types)

local function buildAlleyRibArcs(): { Types.ArcSpec }
	local arcs: { Types.ArcSpec } = {}

	-- Left & right curved neon walkway curbs
	table.insert(arcs, {
		name = "LeftNeonCurb",
		origin = CFrame.new(-10, 0.33, 20),
		partSize = Vector3.new(1.4, 0.7, 5.5),
		axis = "Yaw",
		angleDegrees = 0,
		count = 10,
		hingeSide = "Center",
		material = Enum.Material.Metal,
		color = Color3.fromRGB(34, 38, 52),
		alternateMaterial = Enum.Material.Metal,
		alternateColor = Color3.fromRGB(42, 48, 66),
		addRimTrim = true,
		trimColor = Color3.fromRGB(0, 235, 255),
	})

	table.insert(arcs, {
		name = "RightNeonCurb",
		origin = CFrame.new(10, 0.33, 20),
		partSize = Vector3.new(1.4, 0.7, 5.5),
		axis = "Yaw",
		angleDegrees = 0,
		count = 10,
		hingeSide = "Center",
		material = Enum.Material.Metal,
		color = Color3.fromRGB(34, 38, 52),
		alternateMaterial = Enum.Material.Metal,
		alternateColor = Color3.fromRGB(42, 48, 66),
		addRimTrim = true,
		trimColor = Color3.fromRGB(255, 65, 210),
	})

	-- Three arched overhead neon ribs spanning the alley
	for idx, zPos in ipairs({ 14, -4, -22 }) do
		local ribColor = if idx % 2 == 1 then Color3.fromRGB(0, 235, 255) else Color3.fromRGB(255, 65, 210)
		table.insert(arcs, {
			name = string.format("OverheadRib_%02d", idx),
			origin = CFrame.new(-11.4, 1.2, zPos) * CFrame.Angles(0, 0, math.rad(78)),
			partSize = Vector3.new(1.5, 2.2, 1.6),
			axis = "Roll",
			angleDegrees = -13,
			count = 13,
			hingeSide = "Inner",
			material = Enum.Material.Metal,
			color = Color3.fromRGB(38, 42, 56),
			alternateMaterial = Enum.Material.Metal,
			alternateColor = Color3.fromRGB(48, 54, 70),
			addRimTrim = true,
			trimColor = ribColor,
		})
	end

	-- Spiral cyber maintenance catwalk on the side
	table.insert(arcs, {
		name = "CyberSpiralCatwalk",
		origin = CFrame.new(15, 0.5, -8) * CFrame.Angles(0, math.rad(180), 0),
		partSize = Vector3.new(3.6, 0.45, 2.2),
		axis = "Yaw",
		angleDegrees = 12,
		count = 15,
		hingeSide = "Inner",
		spiralStep = 0.65,
		material = Enum.Material.Metal,
		color = Color3.fromRGB(42, 46, 62),
		alternateMaterial = Enum.Material.CorrodedMetal,
		alternateColor = Color3.fromRGB(54, 58, 72),
		addRimTrim = true,
		trimColor = Color3.fromRGB(0, 235, 255),
	})

	return arcs
end

local Preset: Types.WorldScenePreset = {
	meta = {
		id = "CyberpunkAlleyway",
		displayName = "賽博霓虹巷道 (Cyberpunk Alleyway)",
		category = "SciFi",
		author = "WorldGenEngine",
		description = "對稱霓虹門框與弧形通道肋骨、側邊螺旋維修階梯、空中交叉懸垂霓虹電纜與發光燈箱，以及路面霓虹貨箱散布。",
		tags = { "cyberpunk", "neon", "sci-fi", "cables", "alley" },
	},
	defaultSeed = 2077,
	arcs = buildAlleyRibArcs(),
	polygonRings = {
		{
			name = "AlleyEntranceFrames",
			center = CFrame.new(0, 0, -4),
			radius = 22,
			count = 4,
			mode = "TwinArchPillars",
			pillarSize = Vector3.new(1.8, 13.5, 1.8),
			archWidth = 8.0,
			archHeight = 13.5,
			archThickness = 1.6,
			skipIndices = { 2, 4 },
			material = Enum.Material.Metal,
			color = Color3.fromRGB(32, 36, 48),
			accentMaterial = Enum.Material.Neon,
			accentColor = Color3.fromRGB(0, 235, 255),
			addPillarLight = true,
			lightColor = Color3.fromRGB(0, 225, 255),
			lightRange = 24,
			lightBrightness = 1.5,
		},
	},
	ropes = {
		{
			name = "CrossCable_Cyan_A",
			p0 = Vector3.new(-10.5, 11.5, 16),
			p1 = Vector3.new(10.5, 12.2, 2),
			sag = 2.6,
			segments = 14,
			thickness = 0.22,
			style = "NeonCable",
			color = Color3.fromRGB(0, 235, 255),
			secondaryColor = Color3.fromRGB(36, 40, 52),
			hangingProps = {
				{
					t = 0.35,
					kind = "NeonSign",
					dropLength = 1.2,
					scale = 1.15,
					color = Color3.fromRGB(0, 235, 255),
					accentColor = Color3.fromRGB(28, 32, 42),
					lightColor = Color3.fromRGB(0, 235, 255),
					lightRange = 20,
					lightBrightness = 1.6,
				},
				{
					t = 0.72,
					kind = "Lantern",
					dropLength = 1.0,
					scale = 0.95,
					color = Color3.fromRGB(255, 70, 210),
					accentColor = Color3.fromRGB(36, 40, 52),
					lightColor = Color3.fromRGB(255, 70, 210),
					lightRange = 18,
					lightBrightness = 1.4,
				},
			},
		},
		{
			name = "CrossCable_Magenta_B",
			p0 = Vector3.new(10.5, 11.8, 12),
			p1 = Vector3.new(-10.5, 11.2, -10),
			sag = 3.1,
			segments = 14,
			thickness = 0.22,
			style = "NeonCable",
			color = Color3.fromRGB(255, 65, 210),
			secondaryColor = Color3.fromRGB(36, 40, 52),
			hangingProps = {
				{
					t = 0.5,
					kind = "WarningSign",
					dropLength = 1.3,
					scale = 1.1,
					color = Color3.fromRGB(255, 185, 40),
					accentColor = Color3.fromRGB(32, 34, 42),
					lightColor = Color3.fromRGB(255, 185, 40),
					lightRange = 16,
					lightBrightness = 1.2,
				},
			},
		},
		{
			name = "CrossCable_Cyan_C",
			p0 = Vector3.new(-10.5, 12.0, -6),
			p1 = Vector3.new(10.5, 11.4, -24),
			sag = 2.8,
			segments = 14,
			thickness = 0.2,
			style = "NeonCable",
			color = Color3.fromRGB(115, 145, 255),
			secondaryColor = Color3.fromRGB(36, 40, 52),
			hangingProps = {
				{
					t = 0.48,
					kind = "NeonSign",
					dropLength = 1.1,
					scale = 1.2,
					color = Color3.fromRGB(255, 65, 210),
					accentColor = Color3.fromRGB(26, 30, 40),
					lightColor = Color3.fromRGB(255, 65, 210),
					lightRange = 20,
					lightBrightness = 1.5,
				},
			},
		},
	},
	scatters = {
		{
			name = "AlleyPropsScatter",
			origin = CFrame.new(0, 0, -4),
			areaSize = Vector2.new(36, 56),
			minDistance = 5.5,
			kAttempts = 20,
			maxInstances = 36,
			clearRadius = 6.5,
			minSlopeDegrees = 0,
			maxSlopeDegrees = 35,
			alignToNormal = 0.2,
			scaleRange = NumberRange.new(0.85, 1.25),
			tiltRangeDegrees = 3,
			fallbackToOriginPlane = true,
			templates = {
				{
					kind = "NeonCrate",
					weight = 3.5,
					primaryColor = Color3.fromRGB(0, 230, 255),
					secondaryColor = Color3.fromRGB(36, 40, 54),
					lightColor = Color3.fromRGB(0, 230, 255),
					lightRange = 14,
					lightBrightness = 1.1,
				},
				{
					kind = "NeonCrate",
					weight = 2.5,
					primaryColor = Color3.fromRGB(255, 65, 210),
					secondaryColor = Color3.fromRGB(40, 38, 56),
					lightColor = Color3.fromRGB(255, 65, 210),
					lightRange = 14,
					lightBrightness = 1.1,
				},
				{
					kind = "CrystalCluster",
					weight = 1.0,
					primaryColor = Color3.fromRGB(0, 230, 255),
					accentColor = Color3.fromRGB(255, 120, 235),
					secondaryColor = Color3.fromRGB(32, 36, 48),
					lightColor = Color3.fromRGB(0, 230, 255),
					lightRange = 16,
					lightBrightness = 1.2,
				},
			},
		},
	},
}

return Preset
