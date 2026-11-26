--!strict

local Types = require(script.Core.Types)
local SnapshotManager = require(script.Core.SnapshotManager)
local TransitionRunner = require(script.Core.TransitionRunner)
local ZoneController = require(script.Core.ZoneController)

local AtmosEngine = {}

local activePresetName: string? = nil
local activePresetRef: (string | Types.AtmosPreset)? = nil

local function getPresetsFolder(): Folder?
	local folder = script:FindFirstChild("Presets")
	if folder ~= nil and folder:IsA("Folder") then
		return folder
	end
	return nil
end

local function mergeLightingWithSnapshot(
	presetLighting: Types.LightingSpec?,
	snapLighting: Types.LightingSpec
): Types.LightingSpec?
	if presetLighting == nil then
		return nil
	end
	return {
		ClockTime = if presetLighting.ClockTime ~= nil then presetLighting.ClockTime else snapLighting.ClockTime,
		Brightness = if presetLighting.Brightness ~= nil then presetLighting.Brightness else snapLighting.Brightness,
		Ambient = if presetLighting.Ambient ~= nil then presetLighting.Ambient else snapLighting.Ambient,
		OutdoorAmbient = if presetLighting.OutdoorAmbient ~= nil
			then presetLighting.OutdoorAmbient
			else snapLighting.OutdoorAmbient,
		ColorShift_Top = if presetLighting.ColorShift_Top ~= nil
			then presetLighting.ColorShift_Top
			else snapLighting.ColorShift_Top,
		ColorShift_Bottom = if presetLighting.ColorShift_Bottom ~= nil
			then presetLighting.ColorShift_Bottom
			else snapLighting.ColorShift_Bottom,
		EnvironmentDiffuseScale = if presetLighting.EnvironmentDiffuseScale ~= nil
			then presetLighting.EnvironmentDiffuseScale
			else snapLighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = if presetLighting.EnvironmentSpecularScale ~= nil
			then presetLighting.EnvironmentSpecularScale
			else snapLighting.EnvironmentSpecularScale,
		ExposureCompensation = if presetLighting.ExposureCompensation ~= nil
			then presetLighting.ExposureCompensation
			else snapLighting.ExposureCompensation,
		GeographicLatitude = if presetLighting.GeographicLatitude ~= nil
			then presetLighting.GeographicLatitude
			else snapLighting.GeographicLatitude,
		ShadowSoftness = if presetLighting.ShadowSoftness ~= nil
			then presetLighting.ShadowSoftness
			else snapLighting.ShadowSoftness,
		GlobalShadows = if presetLighting.GlobalShadows ~= nil
			then presetLighting.GlobalShadows
			else snapLighting.GlobalShadows,
		FogColor = if presetLighting.FogColor ~= nil then presetLighting.FogColor else snapLighting.FogColor,
		FogStart = if presetLighting.FogStart ~= nil then presetLighting.FogStart else snapLighting.FogStart,
		FogEnd = if presetLighting.FogEnd ~= nil then presetLighting.FogEnd else snapLighting.FogEnd,
	}
end

local function buildApplyTarget(
	preset: Types.AtmosPreset,
	snap: Types.SnapshotData,
	managed: Types.ManagedInstances
): Types.TransitionTarget
	local target: Types.TransitionTarget = {
		lighting = mergeLightingWithSnapshot(preset.lighting, snap.lighting),
		atmosphere = preset.atmosphere,
		bloom = preset.bloom,
		colorCorrection = preset.colorCorrection,
		depthOfField = preset.depthOfField,
		sunRays = preset.sunRays,
	}

	-- Smoothly fade out any managed instances from a previous preset that the new preset omits
	if target.atmosphere == nil and managed.atmosphere ~= nil then
		target.atmosphere = snap.atmosphere or {
			Density = 0,
			Offset = 0,
			Glare = 0,
			Haze = 0,
		}
	end
	if target.bloom == nil and managed.bloom ~= nil then
		target.bloom = snap.bloom or {
			Enabled = true,
			Intensity = 0,
		}
	end
	if target.colorCorrection == nil and managed.colorCorrection ~= nil then
		target.colorCorrection = snap.colorCorrection or {
			Enabled = true,
			Brightness = 0,
			Contrast = 0,
			Saturation = 0,
			TintColor = Color3.new(1, 1, 1),
		}
	end
	if target.depthOfField == nil and managed.depthOfField ~= nil then
		target.depthOfField = snap.depthOfField or {
			Enabled = true,
			FarIntensity = 0,
			NearIntensity = 0,
		}
	end
	if target.sunRays == nil and managed.sunRays ~= nil then
		target.sunRays = snap.sunRays or {
			Enabled = true,
			Intensity = 0,
		}
	end

	return target
end

local function buildResetTarget(snap: Types.SnapshotData, managed: Types.ManagedInstances): Types.TransitionTarget
	local target: Types.TransitionTarget = {
		lighting = snap.lighting,
	}

	if managed.atmosphere ~= nil then
		target.atmosphere = snap.atmosphere or {
			Density = 0,
			Offset = 0,
			Glare = 0,
			Haze = 0,
		}
	end
	if managed.bloom ~= nil then
		target.bloom = snap.bloom or {
			Enabled = true,
			Intensity = 0,
		}
	end
	if managed.colorCorrection ~= nil then
		target.colorCorrection = snap.colorCorrection or {
			Enabled = true,
			Brightness = 0,
			Contrast = 0,
			Saturation = 0,
			TintColor = Color3.new(1, 1, 1),
		}
	end
	if managed.depthOfField ~= nil then
		target.depthOfField = snap.depthOfField or {
			Enabled = true,
			FarIntensity = 0,
			NearIntensity = 0,
		}
	end
	if managed.sunRays ~= nil then
		target.sunRays = snap.sunRays or {
			Enabled = true,
			Intensity = 0,
		}
	end

	return target
end

function AtmosEngine.GetPreset(presetName: string, forceReload: boolean?): Types.AtmosPreset?
	local presetsFolder = getPresetsFolder()
	if presetsFolder == nil then
		warn("[AtmosEngine] Presets folder not found under AtmosEngine.")
		return nil
	end

	local moduleInst = presetsFolder:FindFirstChild(presetName)
	if moduleInst == nil or not moduleInst:IsA("ModuleScript") then
		warn(string.format("[AtmosEngine] Preset '%s' not found.", presetName))
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
			warn(string.format("[AtmosEngine] Failed to hot-reload preset '%s': %s", presetName, tostring(result)))
			return nil
		end
		return result :: Types.AtmosPreset
	end

	local ok, result = pcall(function()
		return require(moduleInst :: any)
	end)
	if not ok then
		warn(string.format("[AtmosEngine] Failed to require preset '%s': %s", presetName, tostring(result)))
		return nil
	end
	return result :: Types.AtmosPreset
end

function AtmosEngine.ListPresets(): { string }
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

function AtmosEngine.CaptureSnapshot(): Types.SnapshotData
	return SnapshotManager.CaptureSnapshot()
end

local function applyInternal(presetOrName: string | Types.AtmosPreset, options: Types.ApplyOptions?): boolean
	local opts: Types.ApplyOptions = options or {}
	local preset: Types.AtmosPreset?
	local resolvedName: string

	if type(presetOrName) == "string" then
		preset = AtmosEngine.GetPreset(presetOrName, opts.forceReload)
		resolvedName = presetOrName
	else
		preset = presetOrName
		resolvedName = presetOrName.meta.id
	end

	if preset == nil then
		return false
	end

	local snap = SnapshotManager.EnsureSnapshot()
	local managed = SnapshotManager.PrepareManagedForPreset(preset)
	local target = buildApplyTarget(preset, snap, managed)
	local duration = if opts.duration ~= nil then math.max(0, opts.duration) else 0

	activePresetName = resolvedName
	activePresetRef = presetOrName

	TransitionRunner.Run(
		target,
		managed,
		duration,
		opts.easingStyle,
		opts.easingDirection,
		function()
			SnapshotManager.PruneUnusedManaged(preset :: Types.AtmosPreset)
		end
	)

	return true
end

local function resetInternal(duration: number?)
	activePresetName = nil
	activePresetRef = nil

	local snap = SnapshotManager.GetSnapshot()
	if snap == nil then
		TransitionRunner.Cancel()
		SnapshotManager.DestroyAllManaged()
		return
	end

	local dur = if duration ~= nil then math.max(0, duration) else 0
	if dur <= 0 or not SnapshotManager.HasManagedInstances() then
		TransitionRunner.Cancel()
		SnapshotManager.RestoreImmediate()
		return
	end

	local managed = SnapshotManager.GetManaged()
	local resetTarget = buildResetTarget(snap, managed)
	TransitionRunner.Run(
		resetTarget,
		managed,
		dur,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		function()
			SnapshotManager.RestoreImmediate()
		end
	)
end

function AtmosEngine.Apply(presetOrName: string | Types.AtmosPreset, options: Types.ApplyOptions?): boolean
	ZoneController.NotifyManualOverride()
	return applyInternal(presetOrName, options)
end

function AtmosEngine.Reset(duration: number?)
	ZoneController.NotifyManualOverride()
	resetInternal(duration)
end

function AtmosEngine.SetDayNightCycle(enabled: boolean, speed: number?)
	ZoneController.SetDayNightCycle(enabled, speed)
end

function AtmosEngine.RegisterZone(zoneConfig: Types.ZoneConfig): () -> ()
	return ZoneController.RegisterZone(zoneConfig)
end

function AtmosEngine.ClearZones()
	ZoneController.ClearZones(true)
end

function AtmosEngine.GetActivePresetName(): string?
	return activePresetName
end

-- Bind ZoneController callbacks so zone transitions drive Apply/Reset cleanly
ZoneController.BindCallbacks({
	applyPreset = applyInternal,
	reset = resetInternal,
	getActivePreset = function(): (string | Types.AtmosPreset)?
		return activePresetRef
	end,
})

return AtmosEngine
