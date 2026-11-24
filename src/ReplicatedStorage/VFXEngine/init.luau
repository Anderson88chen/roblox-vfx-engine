--!strict

local Types = require(script.Core.Types)
local RigBuilder = require(script.Core.RigBuilder)
local InstanceFactory = require(script.Core.InstanceFactory)
local OrbitController = require(script.Core.OrbitController)
local TimelineRunner = require(script.Core.TimelineRunner)

local VFXEngine = {}

type ActiveSession = {
	handle: Types.AuraHandle,
	connections: { RBXScriptConnection },
}

local activeSessions: { [Model]: ActiveSession } = {}
local sessionCounter = 0

local function nextSessionId(): string
	sessionCounter += 1
	return "vfx_" .. tostring(sessionCounter)
end

local function getPresetsFolder(): Folder?
	local folder = script:FindFirstChild("Presets")
	if folder ~= nil and folder:IsA("Folder") then
		return folder
	end
	return nil
end

function VFXEngine.GetPreset(presetName: string, forceReload: boolean?): Types.AuraPreset?
	local presetsFolder = getPresetsFolder()
	if presetsFolder == nil then
		warn("[VFXEngine] Presets folder not found under VFXEngine.")
		return nil
	end

	local moduleInst = presetsFolder:FindFirstChild(presetName)
	if moduleInst == nil or not moduleInst:IsA("ModuleScript") then
		warn(string.format("[VFXEngine] Preset '%s' not found.", presetName))
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
			warn(string.format("[VFXEngine] Failed to hot-reload preset '%s': %s", presetName, tostring(result)))
			return nil
		end
		return result :: Types.AuraPreset
	end

	local ok, result = pcall(function()
		return require(moduleInst :: any)
	end)
	if not ok then
		warn(string.format("[VFXEngine] Failed to require preset '%s': %s", presetName, tostring(result)))
		return nil
	end
	return result :: Types.AuraPreset
end

function VFXEngine.ListPresets(): { string }
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

function VFXEngine.Unmount(character: Model)
	local session = activeSessions[character]
	if session == nil then
		return
	end
	activeSessions[character] = nil

	for _, conn in ipairs(session.connections) do
		conn:Disconnect()
	end
	table.clear(session.connections)

	session.handle:Destroy()
end

function VFXEngine.GetActive(character: Model): Types.AuraHandle?
	local session = activeSessions[character]
	if session ~= nil and not session.handle:IsDestroyed() then
		return session.handle
	end
	return nil
end

function VFXEngine.Mount(
	character: Model,
	presetOrName: string | Types.AuraPreset,
	options: Types.MountOptions?
): Types.AuraHandle?
	if character == nil or not character:IsDescendantOf(game) then
		warn("[VFXEngine.Mount] Target character is nil or not in DataModel.")
		return nil
	end

	local opts: Types.MountOptions = options or {}
	local preset: Types.AuraPreset?
	if type(presetOrName) == "string" then
		preset = VFXEngine.GetPreset(presetOrName, opts.forceReload)
	else
		preset = presetOrName
	end

	if preset == nil then
		return nil
	end

	VFXEngine.Unmount(character)

	local scale = if opts.scale ~= nil then math.max(0.05, opts.scale) else 1
	local sessionId = nextSessionId()

	local okRig, rigOrErr = pcall(RigBuilder.Build, character, preset.rig, preset.orbits, scale, sessionId)
	if not okRig then
		warn(string.format("[VFXEngine.Mount] Failed to build rig: %s", tostring(rigOrErr)))
		return nil
	end
	local rig = rigOrErr :: Types.RigContext

	-- Position orbit attachments before creating Trails to avoid origin-teleport artifacts
	OrbitController.PositionInitialAnchors(rig, preset.orbits)

	local registry = InstanceFactory.Build(preset, rig)
	local orbitController = OrbitController.New(rig, preset.orbits, registry)
	local timeline: Types.TimelineHandle? = nil
	if preset.timeline ~= nil then
		timeline = TimelineRunner.New(preset, rig, registry, orbitController)
	end

	local destroyed = false
	local connections: { RBXScriptConnection } = {}

	local handle: Types.AuraHandle = {
		presetId = preset.meta.id,
		character = character,
		scale = scale,
		rig = rig,
		registry = registry,
		orbitController = orbitController,
		timeline = timeline,

		Destroy = function(_self: Types.AuraHandle)
			if destroyed then
				return
			end
			destroyed = true

			if activeSessions[character] ~= nil and activeSessions[character].handle == _self then
				activeSessions[character] = nil
			end

			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
			table.clear(connections)

			if timeline ~= nil then
				timeline:Destroy()
			end
			orbitController:Destroy()
			RigBuilder.Destroy(rig)
		end,

		IsDestroyed = function(_self: Types.AuraHandle): boolean
			return destroyed
		end,
	}

	activeSessions[character] = {
		handle = handle,
		connections = connections,
	}

	table.insert(
		connections,
		character.AncestryChanged:Connect(function(_child: Instance, parent: Instance?)
			if parent == nil then
				handle:Destroy()
			end
		end)
	)

	if rig.humanoid ~= nil then
		table.insert(
			connections,
			rig.humanoid.Died:Connect(function()
				handle:Destroy()
			end)
		)
	end

	if timeline ~= nil and (opts.autoplay == nil or opts.autoplay == true) then
		timeline:Start()
	end

	return handle
end

function VFXEngine.Reload(
	character: Model,
	presetOrName: string?,
	options: Types.MountOptions?
): Types.AuraHandle?
	local active = VFXEngine.GetActive(character)
	local targetPreset: string | Types.AuraPreset
	if presetOrName ~= nil then
		targetPreset = presetOrName
	elseif active ~= nil then
		targetPreset = active.presetId
	else
		warn("[VFXEngine.Reload] No active aura and no preset name provided.")
		return nil
	end

	local opts: Types.MountOptions = if options ~= nil then table.clone(options) else {}
	if opts.scale == nil and active ~= nil then
		opts.scale = active.scale
	end
	opts.forceReload = true

	return VFXEngine.Mount(character, targetPreset, opts)
end

return VFXEngine
