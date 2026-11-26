--!strict

local Types = require(script.Core.Types)
local CutsceneSequencer = require(script.Core.CutsceneSequencer)
local ProceduralRigController = require(script.Core.ProceduralRigController)

local CinemaEngine = {}

local function getPresetsFolder(): Folder?
	local folder = script:FindFirstChild("Presets")
	if folder ~= nil and folder:IsA("Folder") then
		return folder
	end
	return nil
end

function CinemaEngine.GetPreset(presetName: string, forceReload: boolean?): Types.CutscenePreset?
	local presetsFolder = getPresetsFolder()
	if presetsFolder == nil then
		warn("[CinemaEngine] Presets folder not found under CinemaEngine.")
		return nil
	end

	local moduleInst = presetsFolder:FindFirstChild(presetName)
	if moduleInst == nil or not moduleInst:IsA("ModuleScript") then
		warn(string.format("[CinemaEngine] Preset '%s' not found.", presetName))
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
			warn(string.format("[CinemaEngine] Failed to hot-reload preset '%s': %s", presetName, tostring(result)))
			return nil
		end
		return result :: Types.CutscenePreset
	end

	local ok, result = pcall(function()
		return require(moduleInst :: any)
	end)
	if not ok then
		warn(string.format("[CinemaEngine] Failed to require preset '%s': %s", presetName, tostring(result)))
		return nil
	end
	return result :: Types.CutscenePreset
end

function CinemaEngine.ListPresets(): { string }
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

function CinemaEngine.PlayCutscene(
	presetOrName: string | Types.CutscenePreset,
	options: Types.CutscenePlayOptions?
): Types.CinemaHandle?
	local opts: Types.CutscenePlayOptions = options or {}
	local preset: Types.CutscenePreset?
	if type(presetOrName) == "string" then
		preset = CinemaEngine.GetPreset(presetOrName, opts.forceReload)
	else
		preset = presetOrName
	end

	if preset == nil then
		return nil
	end

	return CutsceneSequencer.Play(preset, opts)
end

function CinemaEngine.StopCutscene()
	CutsceneSequencer.Stop()
end

function CinemaEngine.IsPlaying(): boolean
	return CutsceneSequencer.IsPlaying()
end

function CinemaEngine.AttachProceduralRig(character: Model, config: Types.ProceduralRigConfig?): boolean
	return ProceduralRigController.Attach(character, config)
end

function CinemaEngine.DetachProceduralRig(character: Model)
	ProceduralRigController.Detach(character)
end

function CinemaEngine.ImpulseRig(character: Model, impulse: Vector3)
	ProceduralRigController.Impulse(character, impulse)
end

return CinemaEngine
