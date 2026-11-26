--!strict

local Workspace = game:GetService("Workspace")

local Types = require(script.Core.Types)
local ArchimedesBuilder = require(script.Core.ArchimedesBuilder)
local PoissonScatterer = require(script.Core.PoissonScatterer)
local CatenaryBuilder = require(script.Core.CatenaryBuilder)

local WorldGenEngine = {}

local SCENES_ROOT_NAME = "__WorldGenScenes"
local DEFAULT_BATCH_SIZE = 250

type ActiveSceneRecord = {
	handle: Types.WorldSceneHandle,
	rootFolder: Folder,
}

local activeScenes: { [string]: ActiveSceneRecord } = {}
local sceneSequence = 0

local function getPresetsFolder(): Folder?
	local folder = script:FindFirstChild("Presets")
	if folder ~= nil and folder:IsA("Folder") then
		return folder
	end
	return nil
end

local function ensureScenesRoot(): Folder
	local existing = Workspace:FindFirstChild(SCENES_ROOT_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	if existing ~= nil then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = SCENES_ROOT_NAME
	folder.Parent = Workspace
	return folder
end

local function countBaseParts(root: Instance): number
	local count = 0
	for _, desc in ipairs(root:GetDescendants()) do
		if desc:IsA("BasePart") then
			count += 1
		end
	end
	if root:IsA("BasePart") then
		count += 1
	end
	return count
end

local function transformCFrame(rootOrigin: CFrame, localCF: CFrame?, scale: number): CFrame
	local cf = localCF or CFrame.new()
	local scaledPos = cf.Position * scale
	return rootOrigin * CFrame.new(scaledPos) * cf.Rotation
end

local function transformPoint(rootOrigin: CFrame, localPoint: Vector3, scale: number): Vector3
	return rootOrigin:PointToWorldSpace(localPoint * scale)
end

-- Packs offline-built children into batch containers of <= batchSize BaseParts
-- before mounting into Workspace to minimize replication/rendering churn.
local function mountRegionInBatches(
	regionName: string,
	offlineContainers: { Instance },
	targetParent: Instance,
	batchSize: number
): number
	if #offlineContainers == 0 then
		return 0
	end

	local clampedBatch = math.clamp(batchSize, 1, DEFAULT_BATCH_SIZE)
	local totalParts = 0

	local currentBatchIndex = 1
	local currentBatchParts = 0
	local currentBatchFolder = Instance.new("Folder")
	currentBatchFolder.Name = string.format("%s_Batch_%02d", regionName, currentBatchIndex)

	local function flushBatch()
		if #currentBatchFolder:GetChildren() > 0 then
			currentBatchFolder.Parent = targetParent
		else
			currentBatchFolder:Destroy()
		end
	end

	for _, container in ipairs(offlineContainers) do
		local containerParts = countBaseParts(container)
		if containerParts <= clampedBatch then
			if currentBatchParts > 0 and (currentBatchParts + containerParts) > clampedBatch then
				flushBatch()
				currentBatchIndex += 1
				currentBatchParts = 0
				currentBatchFolder = Instance.new("Folder")
				currentBatchFolder.Name = string.format("%s_Batch_%02d", regionName, currentBatchIndex)
			end
			container.Parent = currentBatchFolder
			currentBatchParts += containerParts
			totalParts += containerParts
		else
			-- Split oversized container children into <= clampedBatch chunks
			flushBatch()
			currentBatchIndex += 1
			currentBatchParts = 0
			currentBatchFolder = Instance.new("Folder")
			currentBatchFolder.Name = string.format("%s_Batch_%02d", regionName, currentBatchIndex)

			local subChildren = container:GetChildren()
			for _, child in ipairs(subChildren) do
				local childParts = countBaseParts(child)
				if currentBatchParts > 0 and (currentBatchParts + childParts) > clampedBatch then
					flushBatch()
					currentBatchIndex += 1
					currentBatchParts = 0
					currentBatchFolder = Instance.new("Folder")
					currentBatchFolder.Name = string.format("%s_Batch_%02d", regionName, currentBatchIndex)
				end
				child.Parent = currentBatchFolder
				currentBatchParts += childParts
				totalParts += childParts
			end
			container:Destroy()
		end
	end

	flushBatch()
	return totalParts
end

local function scaleArcSpec(spec: Types.ArcSpec, rootOrigin: CFrame, scale: number): Types.ArcSpec
	local cloned = table.clone(spec)
	cloned.origin = transformCFrame(rootOrigin, spec.origin, scale)
	cloned.partSize = spec.partSize * scale
	if spec.spiralStep ~= nil then
		cloned.spiralStep = spec.spiralStep * scale
	end
	return cloned
end

local function scaleRingSpec(spec: Types.PolygonRingSpec, rootOrigin: CFrame, scale: number): Types.PolygonRingSpec
	local cloned = table.clone(spec)
	cloned.center = transformCFrame(rootOrigin, spec.center, scale)
	cloned.radius = spec.radius * scale
	if spec.segmentSize ~= nil then
		cloned.segmentSize = spec.segmentSize * scale
	end
	if spec.pillarSize ~= nil then
		cloned.pillarSize = spec.pillarSize * scale
	end
	if spec.archWidth ~= nil then
		cloned.archWidth = spec.archWidth * scale
	end
	if spec.archHeight ~= nil then
		cloned.archHeight = spec.archHeight * scale
	end
	if spec.archThickness ~= nil then
		cloned.archThickness = spec.archThickness * scale
	end
	if spec.stepHeight ~= nil then
		cloned.stepHeight = spec.stepHeight * scale
	end
	if spec.stepInset ~= nil then
		cloned.stepInset = spec.stepInset * scale
	end
	if spec.lightRange ~= nil then
		cloned.lightRange = math.clamp(spec.lightRange * scale, 1, 60)
	end
	return cloned
end

local function scaleScatterSpec(
	spec: Types.ScatterSpec,
	rootOrigin: CFrame,
	scale: number,
	seedOverride: number?
): Types.ScatterSpec
	local cloned = table.clone(spec)
	cloned.origin = transformCFrame(rootOrigin, spec.origin, scale)
	cloned.minDistance = spec.minDistance * scale
	if spec.areaSize ~= nil then
		cloned.areaSize = spec.areaSize * scale
	end
	if spec.radius ~= nil then
		cloned.radius = spec.radius * scale
	end
	if spec.clearRadius ~= nil then
		cloned.clearRadius = spec.clearRadius * scale
	end
	if seedOverride ~= nil then
		cloned.seed = seedOverride
	end
	if scale ~= 1 then
		local baseRange = spec.scaleRange
		local minS = 0.85
		local maxS = 1.2
		if typeof(baseRange) == "NumberRange" then
			minS = baseRange.Min
			maxS = baseRange.Max
		elseif baseRange ~= nil then
			local tbl = baseRange :: Types.MinMaxRange
			minS = tbl.min or 0.85
			maxS = tbl.max or 1.2
		end
		cloned.scaleRange = NumberRange.new(minS * scale, maxS * scale)
	end
	return cloned
end

local function scaleRopeSpec(spec: Types.RopeSpec, rootOrigin: CFrame, scale: number): Types.RopeSpec
	local cloned = table.clone(spec)
	cloned.p0 = transformPoint(rootOrigin, spec.p0, scale)
	cloned.p1 = transformPoint(rootOrigin, spec.p1, scale)
	if spec.sag ~= nil then
		cloned.sag = spec.sag * scale
	end
	if spec.thickness ~= nil then
		cloned.thickness = spec.thickness * scale
	end
	if spec.hangingProps ~= nil and scale ~= 1 then
		local scaledProps: { Types.HangingPropSpec } = {}
		for _, prop in ipairs(spec.hangingProps) do
			local pClone = table.clone(prop)
			if pClone.dropLength ~= nil then
				pClone.dropLength = pClone.dropLength * scale
			end
			if pClone.scale ~= nil then
				pClone.scale = pClone.scale * scale
			end
			if pClone.lightRange ~= nil then
				pClone.lightRange = math.clamp(pClone.lightRange * scale, 1, 60)
			end
			table.insert(scaledProps, pClone)
		end
		cloned.hangingProps = scaledProps
	end
	return cloned
end

function WorldGenEngine.GetPreset(presetName: string, forceReload: boolean?): Types.WorldScenePreset?
	local presetsFolder = getPresetsFolder()
	if presetsFolder == nil then
		warn("[WorldGenEngine] Presets folder not found under WorldGenEngine.")
		return nil
	end

	local moduleInst = presetsFolder:FindFirstChild(presetName)
	if moduleInst == nil or not moduleInst:IsA("ModuleScript") then
		warn(string.format("[WorldGenEngine] Preset '%s' not found.", presetName))
		return nil
	end

	if forceReload == true then
		local clone = moduleInst:Clone()
		clone.Name = "__HotReloadTemp_" .. presetName
		clone.Parent = presetsFolder
		local ok, result = pcall(function()
			return require(clone :: any)
		end)
		clone:Destroy()
		if not ok then
			warn(string.format("[WorldGenEngine] Failed to hot-reload preset '%s': %s", presetName, tostring(result)))
			return nil
		end
		return result :: Types.WorldScenePreset
	end

	local ok, result = pcall(function()
		return require(moduleInst :: any)
	end)
	if not ok then
		warn(string.format("[WorldGenEngine] Failed to require preset '%s': %s", presetName, tostring(result)))
		return nil
	end
	return result :: Types.WorldScenePreset
end

function WorldGenEngine.ListPresets(): { string }
	local names: { string } = {}
	local presetsFolder = getPresetsFolder()
	if presetsFolder == nil then
		return names
	end

	for _, child in ipairs(presetsFolder:GetChildren()) do
		if child:IsA("ModuleScript") and string.sub(child.Name, 1, 16) ~= "__HotReloadTemp_" then
			table.insert(names, child.Name)
		end
	end
	table.sort(names)
	return names
end

function WorldGenEngine.BuildArc(spec: Types.ArcSpec, parent: Instance?): Model
	local targetParent = parent or ensureScenesRoot()
	return ArchimedesBuilder.BuildArc(spec, targetParent)
end

function WorldGenEngine.BuildPolygonRing(spec: Types.PolygonRingSpec, parent: Instance?): Model
	local targetParent = parent or ensureScenesRoot()
	return ArchimedesBuilder.BuildPolygonRing(spec, targetParent)
end

function WorldGenEngine.Scatter(spec: Types.ScatterSpec, parent: Instance?): Model
	local targetParent = parent or ensureScenesRoot()
	return PoissonScatterer.Scatter(spec, targetParent, nil)
end

function WorldGenEngine.BuildRope(spec: Types.RopeSpec, parent: Instance?): Model
	local targetParent = parent or ensureScenesRoot()
	return CatenaryBuilder.BuildRope(spec, targetParent)
end

function WorldGenEngine.Clear(handleOrId: (Types.WorldSceneHandle | string)?)
	if handleOrId == nil then
		WorldGenEngine.ClearAll()
		return
	end

	local targetId: string
	if type(handleOrId) == "string" then
		targetId = handleOrId
	else
		targetId = handleOrId.id
	end

	local record = activeScenes[targetId]
	if record ~= nil then
		activeScenes[targetId] = nil
		if record.rootFolder.Parent ~= nil then
			record.rootFolder:Destroy()
		end
		return
	end

	-- Also allow clearing by presetId when a string name is passed
	if type(handleOrId) == "string" then
		local toDelete: { string } = {}
		for id, rec in pairs(activeScenes) do
			if rec.handle.presetId == handleOrId then
				table.insert(toDelete, id)
			end
		end
		for _, id in ipairs(toDelete) do
			local rec = activeScenes[id]
			activeScenes[id] = nil
			if rec ~= nil and rec.rootFolder.Parent ~= nil then
				rec.rootFolder:Destroy()
			end
		end
	end
end

function WorldGenEngine.ClearAll()
	for id, rec in pairs(activeScenes) do
		activeScenes[id] = nil
		if rec.rootFolder.Parent ~= nil then
			rec.rootFolder:Destroy()
		end
	end

	local existingRoot = Workspace:FindFirstChild(SCENES_ROOT_NAME)
	if existingRoot ~= nil then
		existingRoot:ClearAllChildren()
	end
end

function WorldGenEngine.GetActiveSceneNames(): { string }
	local names: { string } = {}
	for id, rec in pairs(activeScenes) do
		if rec.rootFolder.Parent == nil then
			activeScenes[id] = nil
		else
			table.insert(names, rec.handle.presetId)
		end
	end
	table.sort(names)
	return names
end

function WorldGenEngine.BuildScene(
	presetOrName: string | Types.WorldScenePreset,
	options: Types.BuildOptions?
): Types.WorldSceneHandle?
	local opts: Types.BuildOptions = options or {}
	local preset: Types.WorldScenePreset?
	if type(presetOrName) == "string" then
		preset = WorldGenEngine.GetPreset(presetOrName, opts.forceReload)
	else
		preset = presetOrName
	end

	if preset == nil then
		return nil
	end

	if opts.clearPrevious == true then
		WorldGenEngine.ClearAll()
	end

	local rootOrigin = opts.origin or CFrame.new()
	local scale = math.max(0.1, opts.scale or 1)
	local batchSize = math.clamp(opts.batchSize or DEFAULT_BATCH_SIZE, 1, DEFAULT_BATCH_SIZE)

	sceneSequence += 1
	local handleId = string.format("%s_%d", preset.meta.id, sceneSequence)

	local sceneFolder = Instance.new("Folder")
	sceneFolder.Name = handleId

	local totalPartCount = 0

	-- 1. Optional ground pad (offline assembly)
	if preset.groundPad ~= nil and preset.groundPad.enabled ~= false then
		local padSpec = preset.groundPad
		local padSize = (padSpec.size or Vector3.new(90, 0.5, 90)) * scale
		local padOffset = (padSpec.offset or Vector3.new(0, -padSize.Y * 0.5 - 0.015, 0)) * scale
		local pad = Instance.new("Part")
		pad.Name = "GroundPad"
		pad.Size = padSize
		pad.CFrame = rootOrigin * CFrame.new(padOffset)
		pad.Material = padSpec.material or Enum.Material.Slate
		pad.Color = padSpec.color or Color3.fromRGB(48, 52, 62)
		pad.Anchored = true
		pad.CanCollide = if padSpec.canCollide == nil then true else padSpec.canCollide
		pad.CastShadow = if padSpec.castShadow == nil then false else padSpec.castShadow
		pad.TopSurface = Enum.SurfaceType.Smooth
		pad.BottomSurface = Enum.SurfaceType.Smooth
		totalPartCount += mountRegionInBatches("GroundPad", { pad }, sceneFolder, batchSize)
	end

	-- 2. Archimedes arcs (offline assembly -> <=250 batch mount)
	if preset.arcs ~= nil and #preset.arcs > 0 then
		local arcModels: { Instance } = {}
		for _, arcSpec in ipairs(preset.arcs) do
			local scaled = scaleArcSpec(arcSpec, rootOrigin, scale)
			table.insert(arcModels, ArchimedesBuilder.BuildArc(scaled, nil))
		end
		totalPartCount += mountRegionInBatches("Arcs", arcModels, sceneFolder, batchSize)
	end

	-- 3. Polygon rings / pillars / arches (offline assembly -> <=250 batch mount)
	if preset.polygonRings ~= nil and #preset.polygonRings > 0 then
		local ringModels: { Instance } = {}
		for _, ringSpec in ipairs(preset.polygonRings) do
			local scaled = scaleRingSpec(ringSpec, rootOrigin, scale)
			table.insert(ringModels, ArchimedesBuilder.BuildPolygonRing(scaled, nil))
		end
		totalPartCount += mountRegionInBatches("PolygonRings", ringModels, sceneFolder, batchSize)
	end

	-- 4. Poisson-Disc surface scatter (raycasts World, builds offline -> <=250 batch mount)
	if preset.scatters ~= nil and #preset.scatters > 0 then
		local scatterModels: { Instance } = {}
		for idx, scatterSpec in ipairs(preset.scatters) do
			local seedToUse: number? = nil
			if opts.seed ~= nil then
				seedToUse = opts.seed + (idx - 1) * 97
			elseif scatterSpec.seed == nil and preset.defaultSeed ~= nil then
				seedToUse = preset.defaultSeed + (idx - 1) * 97
			end
			local scaled = scaleScatterSpec(scatterSpec, rootOrigin, scale, seedToUse)
			table.insert(scatterModels, PoissonScatterer.Scatter(scaled, nil, opts.ignoreInstances))
		end
		totalPartCount += mountRegionInBatches("Scatters", scatterModels, sceneFolder, batchSize)
	end

	-- 5. Catenary ropes & hanging props (offline assembly -> <=250 batch mount)
	if preset.ropes ~= nil and #preset.ropes > 0 then
		local ropeModels: { Instance } = {}
		for _, ropeSpec in ipairs(preset.ropes) do
			local scaled = scaleRopeSpec(ropeSpec, rootOrigin, scale)
			table.insert(ropeModels, CatenaryBuilder.BuildRope(scaled, nil))
		end
		totalPartCount += mountRegionInBatches("Ropes", ropeModels, sceneFolder, batchSize)
	end

	-- Mount completed scene folder to Workspace.__WorldGenScenes
	local scenesRoot = ensureScenesRoot()
	sceneFolder.Parent = scenesRoot

	local handle: Types.WorldSceneHandle = {
		id = handleId,
		presetId = preset.meta.id,
		rootFolder = sceneFolder,
		partCount = totalPartCount,
		createdAt = os.clock(),
		Clear = function(self: Types.WorldSceneHandle)
			WorldGenEngine.Clear(self.id)
		end,
		GetPartCount = function(self: Types.WorldSceneHandle): number
			return self.partCount
		end,
		GetRoot = function(self: Types.WorldSceneHandle): Folder
			return self.rootFolder
		end,
	}

	activeScenes[handleId] = {
		handle = handle,
		rootFolder = sceneFolder,
	}

	return handle
end

return WorldGenEngine
