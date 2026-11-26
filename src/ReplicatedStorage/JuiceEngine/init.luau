--!strict

local Types = require(script.Core.Types)
local CameraShaker = require(script.Core.CameraShaker)
local HitstopController = require(script.Core.HitstopController)
local HitFlashRunner = require(script.Core.HitFlashRunner)
local SoundPool = require(script.Core.SoundPool)
local WorldBurstEmitter = require(script.Core.WorldBurstEmitter)

local JuiceEngine = {}

local function getPresetsFolder(): Folder?
	local folder = script:FindFirstChild("Presets")
	if folder ~= nil and folder:IsA("Folder") then
		return folder
	end
	return nil
end

local function getModelAnchorPosition(model: Model?): Vector3?
	if model == nil then
		return nil
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp ~= nil and hrp:IsA("BasePart") then
		return hrp.Position
	end
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart.Position
	end
	local pivot = model:GetPivot()
	return pivot.Position
end

function JuiceEngine.GetPreset(presetName: string, forceReload: boolean?): Types.JuicePreset?
	local presetsFolder = getPresetsFolder()
	if presetsFolder == nil then
		warn("[JuiceEngine] Presets folder not found under JuiceEngine.")
		return nil
	end

	local moduleInst = presetsFolder:FindFirstChild(presetName)
	if moduleInst == nil or not moduleInst:IsA("ModuleScript") then
		warn(string.format("[JuiceEngine] Preset '%s' not found.", presetName))
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
			warn(string.format("[JuiceEngine] Failed to hot-reload preset '%s': %s", presetName, tostring(result)))
			return nil
		end
		return result :: Types.JuicePreset
	end

	local ok, result = pcall(function()
		return require(moduleInst :: any)
	end)
	if not ok then
		warn(string.format("[JuiceEngine] Failed to require preset '%s': %s", presetName, tostring(result)))
		return nil
	end
	return result :: Types.JuicePreset
end

function JuiceEngine.ListPresets(): { string }
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

function JuiceEngine.ShakeCamera(
	shakeSpec: Types.CameraShakeSpec,
	origin: Vector3?,
	maxDistance: number?,
	intensity: number?
): Types.CameraShakeHandle
	return CameraShaker.Shake(shakeSpec, origin, maxDistance, intensity)
end

function JuiceEngine.Hitstop(targets: { Model } | Model, spec: Types.HitstopSpec)
	if typeof(targets) == "Instance" then
		HitstopController.Apply({ targets :: Model }, spec)
	else
		HitstopController.Apply(targets :: { Model }, spec)
	end
end

function JuiceEngine.FlashTarget(model: Model, spec: Types.HitFlashSpec)
	HitFlashRunner.Flash(model, spec)
end

function JuiceEngine.Play(
	presetOrName: string | Types.JuicePreset,
	context: Types.PlayContext?
): Types.JuiceHandle?
	local ctx: Types.PlayContext = context or {}
	local preset: Types.JuicePreset?
	if type(presetOrName) == "string" then
		preset = JuiceEngine.GetPreset(presetOrName, ctx.forceReload)
	else
		preset = presetOrName
	end

	if preset == nil then
		return nil
	end

	local intensity = math.max(0, if ctx.intensity ~= nil then ctx.intensity else 1)
	local scale = math.max(0.05, if ctx.scale ~= nil then ctx.scale else 1)

	local impactCFrame: CFrame? = ctx.cframe
	local impactPos: Vector3? = ctx.position
	if impactPos == nil and impactCFrame ~= nil then
		impactPos = impactCFrame.Position
	end
	if impactPos == nil then
		impactPos = getModelAnchorPosition(ctx.target) or getModelAnchorPosition(ctx.attacker)
	end
	if impactCFrame == nil and impactPos ~= nil then
		impactCFrame = CFrame.new(impactPos)
	end

	local shakeHandle: Types.CameraShakeHandle? = nil
	if preset.cameraShake ~= nil and intensity > 0 then
		shakeHandle = CameraShaker.Shake(
			preset.cameraShake,
			impactPos,
			preset.cameraShake.maxDistance,
			intensity
		)
	end

	local hitstopModels: { Model } = {}
	if preset.hitstop ~= nil then
		if ctx.attacker ~= nil and preset.hitstop.applyToAttacker ~= false then
			table.insert(hitstopModels, ctx.attacker)
		end
		if ctx.target ~= nil and preset.hitstop.applyToTarget ~= false then
			table.insert(hitstopModels, ctx.target)
		end
		if ctx.targets ~= nil then
			for _, m in ipairs(ctx.targets) do
				table.insert(hitstopModels, m)
			end
		end
		if #hitstopModels > 0 then
			HitstopController.Apply(hitstopModels, preset.hitstop)
		end
	end

	if preset.hitFlash ~= nil then
		local flashed: { [Model]: boolean } = {}
		if ctx.target ~= nil then
			flashed[ctx.target] = true
			HitFlashRunner.Flash(ctx.target, preset.hitFlash)
		end
		if ctx.targets ~= nil then
			for _, m in ipairs(ctx.targets) do
				if not flashed[m] then
					flashed[m] = true
					HitFlashRunner.Flash(m, preset.hitFlash)
				end
			end
		end
	end

	if preset.sounds ~= nil and #preset.sounds > 0 then
		SoundPool.PlayList(preset.sounds, impactPos, intensity)
	end

	if preset.worldBurst ~= nil and impactCFrame ~= nil and intensity > 0 then
		WorldBurstEmitter.Emit(preset.worldBurst, impactCFrame, scale, intensity)
	end

	if preset.vfxTrigger ~= nil or ctx.vfxAura ~= nil then
		WorldBurstEmitter.TriggerVFX(preset.vfxTrigger, ctx)
	end

	local stopped = false
	local handle: Types.JuiceHandle = {
		presetId = preset.meta.id,
		intensity = intensity,
		Stop = function(_self: Types.JuiceHandle)
			if stopped then
				return
			end
			stopped = true
			if shakeHandle ~= nil then
				shakeHandle:Stop(0.05)
			end
			for _, m in ipairs(hitstopModels) do
				HitstopController.RestoreTarget(m)
			end
		end,
		IsActive = function(_self: Types.JuiceHandle): boolean
			if stopped then
				return false
			end
			return shakeHandle ~= nil and shakeHandle:IsActive()
		end,
	}

	return handle
end

function JuiceEngine.StopAll()
	CameraShaker.StopAll()
	HitstopController.RestoreAll()
	HitFlashRunner.StopAll()
	SoundPool.StopAll()
	WorldBurstEmitter.StopAll()
end

return JuiceEngine
