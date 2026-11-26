--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Types = require(script.Parent.Types)

local PoissonScatterer = {}

local WORLDGEN_CONTAINER_NAME = "__WorldGenScenes"
local HARD_MAX_INSTANCES = 450
local MAX_PIERCE_ITERATIONS = 8

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3,
	canCollide: boolean,
	castShadow: boolean,
	parent: Instance,
	shape: Enum.PartType?,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Material = material
	part.Color = color
	part.Anchored = true
	part.CanCollide = canCollide
	part.CastShadow = castShadow
	part.Transparency = transparency or 0
	if shape ~= nil then
		part.Shape = shape
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeWedge(
	name: string,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3,
	canCollide: boolean,
	castShadow: boolean,
	parent: Instance
): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Size = size
	wedge.CFrame = cframe
	wedge.Material = material
	wedge.Color = color
	wedge.Anchored = true
	wedge.CanCollide = canCollide
	wedge.CastShadow = castShadow
	wedge.Parent = parent
	return wedge
end

local function attachLight(
	parent: Instance,
	color: Color3?,
	range: number?,
	brightness: number?
)
	if color == nil and range == nil then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = color or Color3.fromRGB(160, 220, 255)
	light.Range = math.clamp(range or 16, 1, 60)
	light.Brightness = brightness or 1.2
	light.Shadows = false
	light.Parent = parent
end

local function resolveScaleRange(scaleRange: (NumberRange | Types.MinMaxRange)?): (number, number)
	if scaleRange == nil then
		return 0.85, 1.2
	end
	if typeof(scaleRange) == "NumberRange" then
		return scaleRange.Min, scaleRange.Max
	end
	local rangeTable = scaleRange :: Types.MinMaxRange
	local minV = rangeTable.min or 0.85
	local maxV = rangeTable.max or 1.2
	if maxV < minV then
		minV, maxV = maxV, minV
	end
	return minV, maxV
end

local function generateBridsonPoints(
	width: number,
	depth: number,
	radiusLimit: number?,
	minDist: number,
	clearRadius: number,
	kAttempts: number,
	maxCandidates: number,
	rng: Random
): { Vector2 }
	local r = math.max(0.5, minDist)
	local cellSize = r / math.sqrt(2)
	local cols = math.max(1, math.ceil(width / cellSize))
	local rows = math.max(1, math.ceil(depth / cellSize))
	local grid: { [number]: number } = {}

	local halfW = width * 0.5
	local halfD = depth * 0.5
	local rSq = r * r
	local clearSq = clearRadius * clearRadius
	local limitSq = if radiusLimit ~= nil then radiusLimit * radiusLimit else math.huge

	local points: { Vector2 } = {}
	local active: { number } = {}

	local function isValidPoint(pt: Vector2): boolean
		if pt.X < -halfW or pt.X > halfW or pt.Y < -halfD or pt.Y > halfD then
			return false
		end
		local centerDistSq = pt.X * pt.X + pt.Y * pt.Y
		if centerDistSq < clearSq then
			return false
		end
		if centerDistSq > limitSq then
			return false
		end

		local gx = math.floor((pt.X + halfW) / cellSize) + 1
		local gz = math.floor((pt.Y + halfD) / cellSize) + 1

		local minX = math.max(1, gx - 2)
		local maxX = math.min(cols, gx + 2)
		local minZ = math.max(1, gz - 2)
		local maxZ = math.min(rows, gz + 2)

		for nz = minZ, maxZ do
			local rowOffset = (nz - 1) * cols
			for nx = minX, maxX do
				local existingIdx = grid[rowOffset + nx]
				if existingIdx ~= nil then
					local other = points[existingIdx]
					local dx = pt.X - other.X
					local dz = pt.Y - other.Y
					if (dx * dx + dz * dz) < rSq then
						return false
					end
				end
			end
		end

		return true
	end

	local function addPoint(pt: Vector2)
		table.insert(points, pt)
		local idx = #points
		table.insert(active, idx)
		local gx = math.clamp(math.floor((pt.X + halfW) / cellSize) + 1, 1, cols)
		local gz = math.clamp(math.floor((pt.Y + halfD) / cellSize) + 1, 1, rows)
		grid[(gz - 1) * cols + gx] = idx
	end

	-- Seed initial valid sample outside clearRadius
	local seeded = false
	for _ = 1, 64 do
		local sx = rng:NextNumber(-halfW, halfW)
		local sz = rng:NextNumber(-halfD, halfD)
		local candidate = Vector2.new(sx, sz)
		if isValidPoint(candidate) then
			addPoint(candidate)
			seeded = true
			break
		end
	end

	if not seeded then
		return points
	end

	while #active > 0 and #points < maxCandidates do
		local activeListIndex = rng:NextInteger(1, #active)
		local basePt = points[active[activeListIndex]]
		local found = false

		for _ = 1, kAttempts do
			local angle = rng:NextNumber(0, math.pi * 2)
			local dist = rng:NextNumber(r, r * 2)
			local candidate = Vector2.new(
				basePt.X + math.cos(angle) * dist,
				basePt.Y + math.sin(angle) * dist
			)
			if isValidPoint(candidate) then
				addPoint(candidate)
				found = true
				break
			end
		end

		if not found then
			local last = #active
			active[activeListIndex] = active[last]
			active[last] = nil
		end
	end

	return points
end

local function buildBaseExcludeList(extraIgnore: { Instance }?): { Instance }
	local exclude: { Instance } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character ~= nil then
			table.insert(exclude, player.Character)
		end
	end

	local scenesFolder = Workspace:FindFirstChild(WORLDGEN_CONTAINER_NAME)
	if scenesFolder ~= nil then
		table.insert(exclude, scenesFolder)
	end

	if extraIgnore ~= nil then
		for _, inst in ipairs(extraIgnore) do
			table.insert(exclude, inst)
		end
	end

	return exclude
end

local function raycastSolidSurface(
	rayOrigin: Vector3,
	rayDirection: Vector3,
	baseExclude: { Instance }
): RaycastResult?
	local filterList = table.clone(baseExclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filterList
	params.IgnoreWater = true

	local currentOrigin = rayOrigin
	local remainingVec = rayDirection
	local unitDir = rayDirection.Unit

	for _ = 1, MAX_PIERCE_ITERATIONS do
		local result = Workspace:Raycast(currentOrigin, remainingVec, params)
		if result == nil then
			return nil
		end

		local hitInst = result.Instance
		if hitInst:IsA("Terrain") then
			return result
		end

		if hitInst:IsA("BasePart") then
			local isDecorative = (not hitInst.CanCollide) or (hitInst.Transparency >= 0.95)
			if not isDecorative then
				return result
			end
			-- Pierce through non-collidable or fully transparent decorative parts
			table.insert(filterList, hitInst)
			params.FilterDescendantsInstances = filterList
			local advance = unitDir * 0.05
			local traveled = (result.Position - currentOrigin).Magnitude + 0.05
			if traveled >= remainingVec.Magnitude then
				return nil
			end
			currentOrigin = result.Position + advance
			remainingVec = rayDirection - (currentOrigin - rayOrigin)
		else
			return result
		end
	end

	return nil
end

local function computeAlignedRotation(
	surfaceNormal: Vector3,
	alignToNormal: number,
	yawRad: number,
	tiltPitchRad: number,
	tiltRollRad: number
): CFrame
	local up = Vector3.yAxis:Lerp(surfaceNormal.Unit, math.clamp(alignToNormal, 0, 1))
	if up.Magnitude < 1e-4 then
		up = Vector3.yAxis
	else
		up = up.Unit
	end

	local alignCF: CFrame
	local dot = math.clamp(Vector3.yAxis:Dot(up), -1, 1)
	if dot > 0.9999 then
		alignCF = CFrame.new()
	elseif dot < -0.9999 then
		alignCF = CFrame.Angles(math.pi, 0, 0)
	else
		local axis = Vector3.yAxis:Cross(up).Unit
		local angle = math.acos(dot)
		alignCF = CFrame.fromAxisAngle(axis, angle)
	end

	return alignCF * CFrame.Angles(0, yawRad, 0) * CFrame.Angles(tiltPitchRad, 0, tiltRollRad)
end

local function pickWeightedTemplate(templates: { Types.ScatterAssetTemplate }, rng: Random): Types.ScatterAssetTemplate
	local totalWeight = 0
	for _, tmpl in ipairs(templates) do
		totalWeight += math.max(0.01, tmpl.weight or 1)
	end
	local roll = rng:NextNumber(0, totalWeight)
	local accum = 0
	for _, tmpl in ipairs(templates) do
		accum += math.max(0.01, tmpl.weight or 1)
		if roll <= accum then
			return tmpl
		end
	end
	return templates[#templates]
end

local function buildCrystalCluster(
	baseCF: CFrame,
	scale: number,
	tmpl: Types.ScatterAssetTemplate,
	rng: Random,
	parent: Instance
): Model
	local model = Instance.new("Model")
	model.Name = "CrystalCluster"
	local primaryColor = tmpl.primaryColor or Color3.fromRGB(110, 215, 255)
	local accentColor = tmpl.accentColor or Color3.fromRGB(190, 240, 255)
	local mat = tmpl.primaryMaterial or Enum.Material.Neon
	local baseMat = tmpl.secondaryMaterial or Enum.Material.Slate
	local baseColor = tmpl.secondaryColor or Color3.fromRGB(58, 64, 82)

	local plinth = makePart(
		"RockBed",
		Vector3.new(2.2, 0.7, 2.2) * scale,
		baseCF * CFrame.new(0, 0.28 * scale, 0),
		baseMat,
		baseColor,
		true,
		true,
		model
	)
	model.PrimaryPart = plinth

	local mainH = rng:NextNumber(2.8, 4.2) * scale
	local mainW = rng:NextNumber(0.85, 1.15) * scale
	local mainShard = makePart(
		"MainShard",
		Vector3.new(mainW, mainH, mainW),
		baseCF * CFrame.new(0, mainH * 0.45, 0) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, math.pi), rng:NextNumber(-0.12, 0.12)),
		mat,
		primaryColor,
		true,
		false,
		model,
		nil,
		0.12
	)

	makeWedge(
		"MainTip",
		Vector3.new(mainW * 0.96, mainW * 1.1, mainW * 0.96),
		mainShard.CFrame * CFrame.new(0, mainH * 0.5 + mainW * 0.55 - 0.02 * scale, 0),
		mat,
		accentColor,
		false,
		false,
		model
	)

	local shardCount = rng:NextInteger(3, 5)
	for i = 1, shardCount do
		local a = ((i - 1) / shardCount) * math.pi * 2 + rng:NextNumber(-0.35, 0.35)
		local dist = rng:NextNumber(0.5, 0.85) * scale
		local sh = rng:NextNumber(1.4, 2.5) * scale
		local sw = rng:NextNumber(0.45, 0.72) * scale
		local tilt = rng:NextNumber(0.28, 0.62)
		local cf = baseCF
			* CFrame.Angles(0, a, 0)
			* CFrame.new(0, sh * 0.35, -dist)
			* CFrame.Angles(-tilt, 0, 0)
		makePart(
			string.format("SideShard_%d", i),
			Vector3.new(sw, sh, sw),
			cf,
			mat,
			if i % 2 == 0 then accentColor else primaryColor,
			false,
			false,
			model,
			nil,
			0.18
		)
	end

	attachLight(mainShard, tmpl.lightColor or primaryColor, tmpl.lightRange, tmpl.lightBrightness)
	model.Parent = parent
	return model
end

local function buildStonePillar(
	baseCF: CFrame,
	scale: number,
	tmpl: Types.ScatterAssetTemplate,
	rng: Random,
	parent: Instance
): Model
	local model = Instance.new("Model")
	model.Name = "StonePillar"
	local stoneMat = tmpl.primaryMaterial or Enum.Material.Slate
	local stoneCol = tmpl.primaryColor or Color3.fromRGB(115, 118, 126)
	local mossMat = tmpl.secondaryMaterial or Enum.Material.Grass
	local mossCol = tmpl.secondaryColor or Color3.fromRGB(78, 112, 68)

	local plinth = makePart(
		"Plinth",
		Vector3.new(2.4, 0.9, 2.4) * scale,
		baseCF * CFrame.new(0, 0.4 * scale, 0),
		stoneMat,
		stoneCol,
		true,
		true,
		model
	)
	model.PrimaryPart = plinth

	local shaftH = rng:NextNumber(3.5, 6.2) * scale
	local shaft = makePart(
		"Shaft",
		Vector3.new(1.5, shaftH, 1.5) * Vector3.new(scale, 1, scale),
		baseCF * CFrame.new(0, 0.83 * scale + shaftH * 0.5, 0),
		stoneMat,
		stoneCol,
		true,
		true,
		model
	)

	makeWedge(
		"BrokenTop",
		Vector3.new(1.48 * scale, 1.1 * scale, 1.48 * scale),
		shaft.CFrame * CFrame.new(0, shaftH * 0.5 + 0.53 * scale, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
		stoneMat,
		stoneCol,
		true,
		true,
		model
	)

	if rng:NextNumber() > 0.35 then
		makePart(
			"MossPatch",
			Vector3.new(1.62 * scale, 0.45 * scale, 1.1 * scale),
			baseCF * CFrame.new(0.1 * scale, 1.1 * scale, 0.35 * scale),
			mossMat,
			mossCol,
			false,
			true,
			model
		)
	end

	model.Parent = parent
	return model
end

local function buildStylizedShrub(
	baseCF: CFrame,
	scale: number,
	tmpl: Types.ScatterAssetTemplate,
	rng: Random,
	parent: Instance
): Model
	local model = Instance.new("Model")
	model.Name = "StylizedShrub"
	local leafMat = tmpl.primaryMaterial or Enum.Material.Grass
	local leafCol = tmpl.primaryColor or Color3.fromRGB(72, 132, 66)
	local accentCol = tmpl.accentColor or Color3.fromRGB(98, 158, 78)
	local woodMat = tmpl.secondaryMaterial or Enum.Material.Wood
	local woodCol = tmpl.secondaryColor or Color3.fromRGB(82, 58, 42)

	local stem = makePart(
		"Stem",
		Vector3.new(0.45, 0.9, 0.45) * scale,
		baseCF * CFrame.new(0, 0.4 * scale, 0),
		woodMat,
		woodCol,
		false,
		true,
		model
	)
	model.PrimaryPart = stem

	local clusterCount = rng:NextInteger(3, 5)
	for i = 1, clusterCount do
		local ox = rng:NextNumber(-0.8, 0.8) * scale
		local oz = rng:NextNumber(-0.8, 0.8) * scale
		local oy = rng:NextNumber(0.75, 1.45) * scale
		local r = rng:NextNumber(1.1, 1.8) * scale
		makePart(
			string.format("Foliage_%d", i),
			Vector3.new(r * 1.15, r * 0.9, r * 1.1),
			baseCF * CFrame.new(ox, oy, oz) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
			leafMat,
			if i % 2 == 0 then accentCol else leafCol,
			false,
			true,
			model,
			Enum.PartType.Ball
		)
	end

	model.Parent = parent
	return model
end

local function buildFloatingRune(
	baseCF: CFrame,
	scale: number,
	tmpl: Types.ScatterAssetTemplate,
	rng: Random,
	parent: Instance
): Model
	local model = Instance.new("Model")
	model.Name = "FloatingRune"
	local stoneMat = tmpl.secondaryMaterial or Enum.Material.Granite
	local stoneCol = tmpl.secondaryColor or Color3.fromRGB(52, 56, 72)
	local runeMat = tmpl.primaryMaterial or Enum.Material.Neon
	local runeCol = tmpl.primaryColor or Color3.fromRGB(155, 130, 255)
	local accentCol = tmpl.accentColor or Color3.fromRGB(115, 225, 255)

	local base = makePart(
		"Pedestal",
		Vector3.new(1.8, 0.5, 1.8) * scale,
		baseCF * CFrame.new(0, 0.22 * scale, 0),
		stoneMat,
		stoneCol,
		true,
		true,
		model
	)
	model.PrimaryPart = base

	local hoverY = rng:NextNumber(2.6, 3.6) * scale
	local core = makePart(
		"RuneCore",
		Vector3.new(1.0, 1.6, 1.0) * scale,
		baseCF * CFrame.new(0, hoverY, 0) * CFrame.Angles(math.rad(15), rng:NextNumber(0, math.pi), math.rad(35)),
		runeMat,
		runeCol,
		false,
		false,
		model
	)

	makePart(
		"RuneFrame",
		Vector3.new(1.8, 0.18, 1.8) * scale,
		baseCF * CFrame.new(0, hoverY, 0) * CFrame.Angles(math.rad(-25), rng:NextNumber(0, math.pi), math.rad(18)),
		runeMat,
		accentCol,
		false,
		false,
		model
	)

	attachLight(core, tmpl.lightColor or runeCol, tmpl.lightRange, tmpl.lightBrightness)
	model.Parent = parent
	return model
end

local function buildNeonCrate(
	baseCF: CFrame,
	scale: number,
	tmpl: Types.ScatterAssetTemplate,
	rng: Random,
	parent: Instance
): Model
	local model = Instance.new("Model")
	model.Name = "NeonCrate"
	local bodyMat = tmpl.secondaryMaterial or Enum.Material.Metal
	local bodyCol = tmpl.secondaryColor or Color3.fromRGB(36, 40, 52)
	local neonMat = tmpl.primaryMaterial or Enum.Material.Neon
	local neonCol = tmpl.primaryColor or Color3.fromRGB(0, 230, 255)

	local w = rng:NextNumber(2.0, 2.9) * scale
	local h = rng:NextNumber(1.6, 2.4) * scale
	local d = rng:NextNumber(2.0, 2.9) * scale

	local body = makePart(
		"CrateBody",
		Vector3.new(w, h, d),
		baseCF * CFrame.new(0, h * 0.5 - 0.02 * scale, 0),
		bodyMat,
		bodyCol,
		true,
		true,
		model
	)
	model.PrimaryPart = body

	makePart(
		"TopFrame",
		Vector3.new(w * 1.05, h * 0.12, d * 1.05),
		body.CFrame * CFrame.new(0, h * 0.465, 0),
		bodyMat,
		Color3.fromRGB(58, 64, 78),
		true,
		true,
		model
	)

	local strip = makePart(
		"NeonBand",
		Vector3.new(w * 1.035, h * 0.14, d * 1.035),
		body.CFrame * CFrame.new(0, h * 0.15, 0),
		neonMat,
		neonCol,
		false,
		false,
		model
	)

	attachLight(strip, tmpl.lightColor or neonCol, tmpl.lightRange, tmpl.lightBrightness)
	model.Parent = parent
	return model
end

local function buildMossBoulder(
	baseCF: CFrame,
	scale: number,
	tmpl: Types.ScatterAssetTemplate,
	rng: Random,
	parent: Instance
): Model
	local model = Instance.new("Model")
	model.Name = "MossBoulder"
	local rockMat = tmpl.primaryMaterial or Enum.Material.Rock
	local rockCol = tmpl.primaryColor or Color3.fromRGB(98, 102, 108)
	local mossMat = tmpl.secondaryMaterial or Enum.Material.LeafyGrass
	local mossCol = tmpl.secondaryColor or Color3.fromRGB(74, 118, 62)

	local w = rng:NextNumber(2.2, 3.4) * scale
	local h = rng:NextNumber(1.4, 2.2) * scale
	local d = rng:NextNumber(2.0, 3.2) * scale

	local mainRock = makePart(
		"MainRock",
		Vector3.new(w, h, d),
		baseCF * CFrame.new(0, h * 0.42, 0) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)),
		rockMat,
		rockCol,
		true,
		true,
		model
	)
	model.PrimaryPart = mainRock

	makePart(
		"MossCap",
		Vector3.new(w * 0.88, h * 0.25, d * 0.86),
		mainRock.CFrame * CFrame.new(0, h * 0.45, 0),
		mossMat,
		mossCol,
		false,
		true,
		model
	)

	makeWedge(
		"SideCrag",
		Vector3.new(w * 0.65, h * 0.75, d * 0.65),
		baseCF * CFrame.new(w * 0.42, h * 0.35, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		rockMat,
		rockCol,
		true,
		true,
		model
	)

	model.Parent = parent
	return model
end

local function buildRunicObelisk(
	baseCF: CFrame,
	scale: number,
	tmpl: Types.ScatterAssetTemplate,
	_rng: Random,
	parent: Instance
): Model
	local model = Instance.new("Model")
	model.Name = "RunicObelisk"
	local stoneMat = tmpl.secondaryMaterial or Enum.Material.Granite
	local stoneCol = tmpl.secondaryColor or Color3.fromRGB(62, 68, 88)
	local runeMat = tmpl.primaryMaterial or Enum.Material.Neon
	local runeCol = tmpl.primaryColor or Color3.fromRGB(130, 210, 255)

	local base = makePart(
		"Base",
		Vector3.new(2.2, 0.8, 2.2) * scale,
		baseCF * CFrame.new(0, 0.37 * scale, 0),
		stoneMat,
		stoneCol,
		true,
		true,
		model
	)
	model.PrimaryPart = base

	local bodyH = 4.6 * scale
	local body = makePart(
		"ObeliskBody",
		Vector3.new(1.35 * scale, bodyH, 1.35 * scale),
		baseCF * CFrame.new(0, 0.75 * scale + bodyH * 0.5, 0),
		stoneMat,
		stoneCol,
		true,
		true,
		model
	)

	local runeBand = makePart(
		"RuneBand",
		Vector3.new(1.42 * scale, 0.35 * scale, 1.42 * scale),
		body.CFrame * CFrame.new(0, bodyH * 0.2, 0),
		runeMat,
		runeCol,
		false,
		false,
		model
	)

	makeWedge(
		"Apex",
		Vector3.new(1.3 * scale, 1.2 * scale, 1.3 * scale),
		body.CFrame * CFrame.new(0, bodyH * 0.5 + 0.58 * scale, 0),
		runeMat,
		tmpl.accentColor or runeCol,
		false,
		false,
		model
	)

	attachLight(runeBand, tmpl.lightColor or runeCol, tmpl.lightRange, tmpl.lightBrightness)
	model.Parent = parent
	return model
end

local function spawnTemplate(
	kind: Types.ScatterAssetKind,
	baseCF: CFrame,
	scale: number,
	tmpl: Types.ScatterAssetTemplate,
	rng: Random,
	parent: Instance
): Model
	if kind == "CrystalCluster" then
		return buildCrystalCluster(baseCF, scale, tmpl, rng, parent)
	elseif kind == "StonePillar" then
		return buildStonePillar(baseCF, scale, tmpl, rng, parent)
	elseif kind == "StylizedShrub" then
		return buildStylizedShrub(baseCF, scale, tmpl, rng, parent)
	elseif kind == "FloatingRune" then
		return buildFloatingRune(baseCF, scale, tmpl, rng, parent)
	elseif kind == "NeonCrate" then
		return buildNeonCrate(baseCF, scale, tmpl, rng, parent)
	elseif kind == "MossBoulder" then
		return buildMossBoulder(baseCF, scale, tmpl, rng, parent)
	else
		return buildRunicObelisk(baseCF, scale, tmpl, rng, parent)
	end
end

function PoissonScatterer.Scatter(
	spec: Types.ScatterSpec,
	parent: Instance?,
	extraIgnore: { Instance }?
): Model
	local container = Instance.new("Model")
	container.Name = spec.name or "PoissonScatter"

	if #spec.templates == 0 then
		if parent ~= nil then
			container.Parent = parent
		end
		return container
	end

	local origin = spec.origin or CFrame.new()
	local seed = spec.seed or 42
	local rng = Random.new(seed)

	local radiusLimit = spec.radius
	local width: number
	local depth: number
	if spec.areaSize ~= nil then
		width = math.max(1, spec.areaSize.X)
		depth = math.max(1, spec.areaSize.Y)
	elseif radiusLimit ~= nil then
		width = math.max(2, radiusLimit * 2)
		depth = math.max(2, radiusLimit * 2)
	else
		width = 60
		depth = 60
		radiusLimit = 30
	end

	local minDistance = math.max(0.75, spec.minDistance)
	local kAttempts = math.clamp(spec.kAttempts or 20, 4, 50)
	local maxInstances = math.clamp(spec.maxInstances or 120, 1, HARD_MAX_INSTANCES)
	local clearRadius = math.max(0, spec.clearRadius or 0)

	local minSlope = math.clamp(spec.minSlopeDegrees or 0, 0, 89)
	local maxSlope = math.clamp(spec.maxSlopeDegrees or 45, minSlope, 89.9)
	local alignToNormal = math.clamp(spec.alignToNormal or 0.35, 0, 1)
	local tiltRange = math.max(0, spec.tiltRangeDegrees or 6)
	local minScale, maxScale = resolveScaleRange(spec.scaleRange)

	local rayHeight = math.max(5, spec.raycastHeight or 80)
	local rayDepth = math.max(10, spec.raycastDepth or 160)
	local fallbackToPlane = spec.fallbackToOriginPlane == true

	-- Oversample Bridson points slightly so slope/void rejections still yield rich coverage
	local samplePoints = generateBridsonPoints(
		width,
		depth,
		radiusLimit,
		minDistance,
		clearRadius,
		kAttempts,
		math.min(HARD_MAX_INSTANCES * 3, maxInstances * 3),
		rng
	)

	local baseExclude = buildBaseExcludeList(extraIgnore)
	local spawnedCount = 0

	for _, pt2d in ipairs(samplePoints) do
		if spawnedCount >= maxInstances then
			break
		end

		local localTop = Vector3.new(pt2d.X, rayHeight, pt2d.Y)
		local worldTop = origin:PointToWorldSpace(localTop)
		local rayVec = Vector3.new(0, -(rayHeight + rayDepth), 0)

		local hit = raycastSolidSurface(worldTop, rayVec, baseExclude)
		local hitPos: Vector3?
		local hitNormal: Vector3?

		if hit ~= nil then
			hitPos = hit.Position
			hitNormal = hit.Normal.Unit
		elseif fallbackToPlane then
			local worldPlane = origin:PointToWorldSpace(Vector3.new(pt2d.X, 0, pt2d.Y))
			hitPos = worldPlane
			hitNormal = Vector3.yAxis
		end

		if hitPos ~= nil and hitNormal ~= nil then
			local cosSlope = math.clamp(hitNormal:Dot(Vector3.yAxis), -1, 1)
			local slopeDeg = math.deg(math.acos(cosSlope))

			if slopeDeg >= minSlope and slopeDeg <= maxSlope then
				local tmpl = pickWeightedTemplate(spec.templates, rng)
				local rawScale = rng:NextNumber(minScale, maxScale)
				local finalScale = math.max(0.15, rawScale * (tmpl.scaleMultiplier or 1))
				local yawRad = rng:NextNumber(0, math.pi * 2)
				local tiltP = math.rad(rng:NextNumber(-tiltRange, tiltRange))
				local tiltR = math.rad(rng:NextNumber(-tiltRange, tiltRange))

				local rotCF = computeAlignedRotation(hitNormal, alignToNormal, yawRad, tiltP, tiltR)
				local embedOffset = (tmpl.yOffset or -0.06) * finalScale
				local spawnCF = CFrame.new(hitPos + hitNormal * embedOffset) * rotCF

				spawnTemplate(tmpl.kind, spawnCF, finalScale, tmpl, rng, container)
				spawnedCount += 1
			end
		end
	end

	if parent ~= nil then
		container.Parent = parent
	end

	return container
end

return PoissonScatterer
