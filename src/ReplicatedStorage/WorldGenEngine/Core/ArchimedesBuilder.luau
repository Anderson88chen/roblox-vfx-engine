--!strict

local Types = require(script.Parent.Types)

local ArchimedesBuilder = {}

local ZFIGHT_EPS = 0.005
local GROUND_SINK = 0.02

local function ringCycleLayer(i: number, count: number): number
	-- 3-coloring for closed rings: adjacent segments (including wrap-around count -> 1) never share a layer
	if (count % 2) == 1 and i == count then
		return 2
	end
	return (i - 1) % 2
end

local function createPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3,
	transparency: number,
	reflectance: number,
	anchored: boolean,
	canCollide: boolean,
	castShadow: boolean,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Material = material
	part.Color = color
	part.Transparency = transparency
	part.Reflectance = reflectance
	part.Anchored = anchored
	part.CanCollide = canCollide
	part.CastShadow = castShadow
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function computeHingeVectors(
	axis: Types.ArcAxis,
	hingeSide: Types.HingeSide,
	angleDegrees: number,
	size: Vector3
): (Vector3, Vector3)
	-- Returns (frontEdgeLocal, backEdgeLocal) in part-local space.
	-- Positive angleDegrees curves:
	--   Yaw   (+Y): -Z turns toward -X (Inner = -X, Outer = +X)
	--   Pitch (+X): -Z turns toward +Y (Inner = +Y, Outer = -Y)
	--   Roll  (+Z): +X turns toward +Y (Inner = +Y, Outer = -Y)
	local sign = if angleDegrees >= 0 then 1 else -1
	local hx = size.X * 0.5
	local hy = size.Y * 0.5
	local hz = size.Z * 0.5

	if axis == "Yaw" then
		local sideX = 0
		if hingeSide == "Inner" then
			sideX = -sign * hx
		elseif hingeSide == "Outer" then
			sideX = sign * hx
		end
		return Vector3.new(sideX, 0, -hz), Vector3.new(sideX, 0, hz)
	elseif axis == "Pitch" then
		local sideY = 0
		if hingeSide == "Inner" then
			sideY = sign * hy
		elseif hingeSide == "Outer" then
			sideY = -sign * hy
		end
		return Vector3.new(0, sideY, -hz), Vector3.new(0, sideY, hz)
	else
		-- Roll: curves in the XY plane around Z; progression along +X
		local sideY = 0
		if hingeSide == "Inner" then
			sideY = sign * hy
		elseif hingeSide == "Outer" then
			sideY = -sign * hy
		end
		return Vector3.new(hx, sideY, 0), Vector3.new(-hx, sideY, 0)
	end
end

local function makeAxisRotation(axis: Types.ArcAxis, angleRad: number): CFrame
	if axis == "Yaw" then
		return CFrame.Angles(0, angleRad, 0)
	elseif axis == "Pitch" then
		return CFrame.Angles(angleRad, 0, 0)
	else
		return CFrame.Angles(0, 0, angleRad)
	end
end

local function makeSpiralOffset(axis: Types.ArcAxis, spiralStep: number): CFrame
	if spiralStep == 0 then
		return CFrame.new()
	end
	if axis == "Yaw" then
		return CFrame.new(0, spiralStep, 0)
	elseif axis == "Pitch" then
		return CFrame.new(spiralStep, 0, 0)
	else
		return CFrame.new(0, 0, spiralStep)
	end
end

local function clampSize(size: Vector3): Vector3
	return Vector3.new(
		math.max(0.05, size.X),
		math.max(0.05, size.Y),
		math.max(0.05, size.Z)
	)
end

function ArchimedesBuilder.BuildArc(spec: Types.ArcSpec, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = spec.name or "ArchimedesArc"

	local count = math.max(1, math.floor(spec.count))
	local axis: Types.ArcAxis = spec.axis or "Yaw"
	local hingeSide: Types.HingeSide = spec.hingeSide or "Inner"
	local angleDegrees = spec.angleDegrees
	local angleRad = math.rad(angleDegrees)
	local spiralStep = spec.spiralStep or 0
	local origin = spec.origin or CFrame.new()

	local baseMaterial = spec.material or Enum.Material.SmoothPlastic
	local baseColor = spec.color or Color3.fromRGB(163, 162, 165)
	local altMaterial = spec.alternateMaterial or baseMaterial
	local altColor = spec.alternateColor or baseColor
	local transparency = spec.transparency or 0
	local reflectance = spec.reflectance or 0
	local anchored = if spec.anchored == nil then true else spec.anchored
	local canCollide = if spec.canCollide == nil then true else spec.canCollide
	local castShadow = if spec.castShadow == nil then true else spec.castShadow

	local addRimTrim = spec.addRimTrim == true
	local trimColor = spec.trimColor or Color3.fromRGB(120, 210, 255)
	local trimMaterial = spec.trimMaterial or Enum.Material.Neon

	local currentSize = clampSize(spec.partSize)
	local currentCF = origin
	local rotCF = makeAxisRotation(axis, angleRad)
	local spiralCF = makeSpiralOffset(axis, spiralStep)

	local firstPart: BasePart? = nil

	for i = 1, count do
		local isOdd = (i % 2) == 1
		local mat = if isOdd then baseMaterial else altMaterial
		local col = if isOdd then baseColor else altColor

		local layerEps = ((i - 1) % 3) * ZFIGHT_EPS
		local renderSize: Vector3
		if axis == "Yaw" then
			renderSize = currentSize + Vector3.new(layerEps, layerEps * 2, 0)
		elseif axis == "Pitch" then
			renderSize = currentSize + Vector3.new(layerEps * 2, layerEps, 0)
		else
			renderSize = currentSize + Vector3.new(0, layerEps, layerEps * 2)
		end

		local segPart = createPart(
			string.format("ArcSeg_%03d", i),
			renderSize,
			currentCF,
			mat,
			col,
			transparency,
			reflectance,
			anchored,
			canCollide,
			castShadow,
			model
		)
		if firstPart == nil then
			firstPart = segPart
		end

		if addRimTrim then
			local trimSize: Vector3
			local trimOffset: CFrame
			if axis == "Roll" then
				trimSize = Vector3.new(currentSize.X * 0.96, math.max(0.12, currentSize.Y * 0.14) + layerEps, currentSize.Z + 0.08 + layerEps * 2)
				trimOffset = CFrame.new(0, renderSize.Y * 0.5 + trimSize.Y * 0.45, 0)
			else
				trimSize = Vector3.new(currentSize.X + 0.08 + layerEps * 2, math.max(0.12, currentSize.Y * 0.16) + layerEps, currentSize.Z * 0.96)
				trimOffset = CFrame.new(0, renderSize.Y * 0.5 + trimSize.Y * 0.4, 0)
			end
			createPart(
				string.format("ArcTrim_%03d", i),
				trimSize,
				currentCF * trimOffset,
				trimMaterial,
				trimColor,
				transparency,
				0,
				anchored,
				false,
				false,
				model
			)
		end

		if i < count then
			-- Compute next segment's size if radial/size scaling is requested
			local nextSize = currentSize
			if spec.uniformScalePerStep ~= nil then
				nextSize = clampSize(nextSize * spec.uniformScalePerStep)
			end
			if spec.sizeScalePerStep ~= nil then
				nextSize = clampSize(Vector3.new(
					nextSize.X * spec.sizeScalePerStep.X,
					nextSize.Y * spec.sizeScalePerStep.Y,
					nextSize.Z * spec.sizeScalePerStep.Z
				))
			end

			local frontHingeLocal, _ = computeHingeVectors(axis, hingeSide, angleDegrees, currentSize)
			local _, nextBackHingeLocal = computeHingeVectors(axis, hingeSide, angleDegrees, nextSize)

			local pivotWorld = currentCF * CFrame.new(frontHingeLocal)
			local rotatedPivot = pivotWorld * rotCF * spiralCF
			currentCF = rotatedPivot * CFrame.new(-nextBackHingeLocal)
			currentSize = nextSize
		end
	end

	if firstPart ~= nil then
		model.PrimaryPart = firstPart
	end

	if parent ~= nil then
		model.Parent = parent
	end

	return model
end

local function makeSkipSet(skipIndices: { number }?): { [number]: boolean }
	local set: { [number]: boolean } = {}
	if skipIndices ~= nil then
		for _, idx in ipairs(skipIndices) do
			set[idx] = true
		end
	end
	return set
end

local function orientAtRingPoint(center: CFrame, angleRad: number, radius: number, yOffset: number, faceCenter: boolean): CFrame
	local localPos = Vector3.new(math.cos(angleRad) * radius, yOffset, math.sin(angleRad) * radius)
	local worldPos = center:PointToWorldSpace(localPos)
	local centerAtHeight = center:PointToWorldSpace(Vector3.new(0, yOffset, 0))
	if faceCenter then
		return CFrame.lookAt(worldPos, centerAtHeight, center.UpVector)
	else
		local outward = (worldPos - centerAtHeight)
		if outward.Magnitude < 1e-4 then
			outward = center.LookVector
		end
		return CFrame.lookAt(worldPos, worldPos + outward, center.UpVector)
	end
end

local function createPointLightIfRequested(
	parent: Instance,
	color: Color3?,
	range: number?,
	brightness: number?
)
	if color == nil and range == nil then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = color or Color3.fromRGB(160, 210, 255)
	light.Range = math.clamp(range or 22, 1, 60)
	light.Brightness = brightness or 1.4
	light.Shadows = false
	light.Parent = parent
end

function ArchimedesBuilder.BuildPolygonRing(spec: Types.PolygonRingSpec, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = spec.name or "PolygonRing"

	local center = spec.center or CFrame.new()
	local radius = math.max(1, spec.radius)
	local count = math.max(3, math.floor(spec.count))
	local mode: Types.PolygonRingMode = spec.mode or "RingBase"
	local faceCenter = if spec.faceCenter == nil then true else spec.faceCenter
	local skipSet = makeSkipSet(spec.skipIndices)

	local material = spec.material or Enum.Material.Slate
	local color = spec.color or Color3.fromRGB(95, 100, 112)
	local accentMaterial = spec.accentMaterial or Enum.Material.Neon
	local accentColor = spec.accentColor or Color3.fromRGB(120, 200, 255)
	local transparency = spec.transparency or 0
	local anchored = if spec.anchored == nil then true else spec.anchored
	local canCollide = if spec.canCollide == nil then true else spec.canCollide
	local castShadow = if spec.castShadow == nil then true else spec.castShadow

	local firstPart: BasePart? = nil

	if mode == "RingBase" or mode == "SteppedRing" then
		local stepCount = if mode == "SteppedRing" then math.max(1, spec.stepCount or 3) else 1
		local baseSeg = spec.segmentSize or Vector3.new(2 * radius * math.tan(math.pi / count), 1.5, 4)
		local stepHeight = spec.stepHeight or baseSeg.Y
		local stepInset = spec.stepInset or (baseSeg.Z * 0.72)

		for s = 1, stepCount do
			local stepRadius = math.max(1.5, radius - (s - 1) * stepInset)
			local stepActualH: number
			local yPos: number
			if canCollide then
				-- Sink bottom by GROUND_SINK into ground (s == 1) or previous step (s > 1) while preserving top Y
				stepActualH = stepHeight + GROUND_SINK
				yPos = s * stepHeight - stepActualH * 0.5
			else
				-- Lift non-colliding decorative ground rings slightly above ground plane
				stepActualH = stepHeight
				yPos = (s - 0.5) * stepHeight + 0.015
			end
			local chordWidth = math.max(0.5, 2 * (stepRadius + baseSeg.Z * 0.5) * math.tan(math.pi / count))
			local segBaseWidth = if spec.segmentSize ~= nil and stepCount == 1 then spec.segmentSize.X else chordWidth + 0.08
			local isAccentStep = (s == stepCount and stepCount > 1)

			for i = 1, count do
				if not skipSet[i] then
					local layerEps = ringCycleLayer(i, count) * ZFIGHT_EPS
					local segSize = Vector3.new(
						segBaseWidth,
						stepActualH + layerEps * 2,
						baseSeg.Z + layerEps * 2
					)
					local theta = ((i - 1) / count) * math.pi * 2
					local cf = orientAtRingPoint(center, theta, stepRadius, yPos, faceCenter)
					local part = createPart(
						string.format("RingStep%d_Seg%02d", s, i),
						segSize,
						cf,
						if isAccentStep and spec.accentMaterial ~= nil then accentMaterial else material,
						if isAccentStep and spec.accentColor ~= nil then accentColor else color,
						transparency,
						0,
						anchored,
						canCollide,
						castShadow,
						model
					)
					if firstPart == nil then
						firstPart = part
					end
				end
			end
		end
	elseif mode == "Pillars" then
		local pillarSize = spec.pillarSize or Vector3.new(2.4, 14, 2.4)
		for i = 1, count do
			if not skipSet[i] then
				local layerEps = ringCycleLayer(i, count) * ZFIGHT_EPS
				local theta = ((i - 1) / count) * math.pi * 2
				local baseCF = orientAtRingPoint(center, theta, radius, 0, faceCenter)

				local plinthH = math.max(1, pillarSize.Y * 0.1)
				local plinthSize = Vector3.new(pillarSize.X * 1.4 + layerEps * 2, plinthH + GROUND_SINK, pillarSize.Z * 1.4 + layerEps * 2)
				local plinth = createPart(
					string.format("PillarPlinth_%02d", i),
					plinthSize,
					baseCF * CFrame.new(0, plinthH * 0.5 - GROUND_SINK * 0.5, 0),
					material,
					color,
					transparency,
					0,
					anchored,
					canCollide,
					castShadow,
					model
				)
				if firstPart == nil then
					firstPart = plinth
				end

				local shaft = createPart(
					string.format("PillarShaft_%02d", i),
					Vector3.new(pillarSize.X + layerEps, pillarSize.Y + GROUND_SINK * 2, pillarSize.Z + layerEps),
					baseCF * CFrame.new(0, plinthH + pillarSize.Y * 0.5, 0),
					material,
					color,
					transparency,
					0,
					anchored,
					canCollide,
					castShadow,
					model
				)

				if spec.addPillarCap ~= false then
					local capSize = Vector3.new(pillarSize.X * 1.35 + layerEps * 2, math.max(0.8, pillarSize.Y * 0.08), pillarSize.Z * 1.35 + layerEps * 2)
					local cap = createPart(
						string.format("PillarCap_%02d", i),
						capSize,
						baseCF * CFrame.new(0, plinthH + pillarSize.Y + capSize.Y * 0.5, 0),
						accentMaterial,
						accentColor,
						transparency,
						0,
						anchored,
						canCollide,
						castShadow,
						model
					)
					if spec.addPillarLight then
						createPointLightIfRequested(cap, spec.lightColor or accentColor, spec.lightRange, spec.lightBrightness)
					end
				elseif spec.addPillarLight then
					createPointLightIfRequested(shaft, spec.lightColor or accentColor, spec.lightRange, spec.lightBrightness)
				end
			end
		end
	elseif mode == "TwinArchPillars" then
		local pillarSize = spec.pillarSize or Vector3.new(2.0, 14, 2.0)
		local archWidth = spec.archWidth or 7.5
		local archHeight = spec.archHeight or pillarSize.Y
		local archThickness = spec.archThickness or 1.8
		local halfSpan = archWidth * 0.5

		for i = 1, count do
			if not skipSet[i] then
				local layerEps = ringCycleLayer(i, count) * ZFIGHT_EPS
				local theta = ((i - 1) / count) * math.pi * 2
				local frameCF = orientAtRingPoint(center, theta, radius, 0, faceCenter)
				local plinthH = math.max(0.9, pillarSize.Y * 0.08)

				for sideIndex, sideSign in ipairs({ -1, 1 }) do
					local localX = sideSign * halfSpan
					local plinthSize = Vector3.new(pillarSize.X * 1.35 + layerEps * 2, plinthH + GROUND_SINK, pillarSize.Z * 1.35 + layerEps * 2)
					local plinth = createPart(
						string.format("Arch%02d_Plinth_%d", i, sideIndex),
						plinthSize,
						frameCF * CFrame.new(localX, plinthH * 0.5 - GROUND_SINK * 0.5, 0),
						material,
						color,
						transparency,
						0,
						anchored,
						canCollide,
						castShadow,
						model
					)
					if firstPart == nil then
						firstPart = plinth
					end

					createPart(
						string.format("Arch%02d_Col_%d", i, sideIndex),
						Vector3.new(pillarSize.X + layerEps, archHeight + GROUND_SINK * 2, pillarSize.Z + layerEps),
						frameCF * CFrame.new(localX, plinthH + archHeight * 0.5, 0),
						material,
						color,
						transparency,
						0,
						anchored,
						canCollide,
						castShadow,
						model
					)
				end

				-- Top lintel + keystone accent
				local lintelWidth = archWidth + pillarSize.X * 1.35 + layerEps * 2
				local lintelY = plinthH + archHeight + archThickness * 0.5
				local lintel = createPart(
					string.format("Arch%02d_Lintel", i),
					Vector3.new(lintelWidth, archThickness + layerEps, pillarSize.Z * 1.25 + layerEps * 2),
					frameCF * CFrame.new(0, lintelY, 0),
					material,
					color,
					transparency,
					0,
					anchored,
					canCollide,
					castShadow,
					model
				)

				local keystone = createPart(
					string.format("Arch%02d_Keystone", i),
					Vector3.new(lintelWidth * 0.36, archThickness * 0.65 + layerEps, pillarSize.Z * 1.35 + layerEps * 2),
					frameCF * CFrame.new(0, lintelY + archThickness * 0.55, 0),
					accentMaterial,
					accentColor,
					transparency,
					0,
					anchored,
					canCollide,
					false,
					model
				)

				if spec.addPillarLight then
					createPointLightIfRequested(
						if keystone ~= nil then keystone else lintel,
						spec.lightColor or accentColor,
						spec.lightRange,
						spec.lightBrightness
					)
				end
			end
		end
	end

	if firstPart ~= nil then
		model.PrimaryPart = firstPart
	end

	if parent ~= nil then
		model.Parent = parent
	end

	return model
end

return ArchimedesBuilder
