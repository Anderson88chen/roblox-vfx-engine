--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CinemaEngineModule = ReplicatedStorage:WaitForChild("CinemaEngine")
local CinemaEngine = require(CinemaEngineModule :: any)

local localPlayer = Players.LocalPlayer
local DEFAULT_PRESET = "AwakeningCutscene"

-- Initialize preview control attributes if missing so Studio Properties panel exposes them immediately
if localPlayer:GetAttribute("ActiveCutscene") == nil then
	localPlayer:SetAttribute("ActiveCutscene", DEFAULT_PRESET)
end
if localPlayer:GetAttribute("CutsceneTrigger") == nil then
	localPlayer:SetAttribute("CutsceneTrigger", 0)
end
if localPlayer:GetAttribute("ProceduralRigEnabled") == nil then
	localPlayer:SetAttribute("ProceduralRigEnabled", true)
end
if localPlayer:GetAttribute("CinemaForceReload") == nil then
	localPlayer:SetAttribute("CinemaForceReload", false)
end

local function getActivePresetName(): string
	local val = localPlayer:GetAttribute("ActiveCutscene")
	if type(val) == "string" and val ~= "" then
		return val
	end
	return DEFAULT_PRESET
end

local function getForceReload(): boolean
	local val = localPlayer:GetAttribute("CinemaForceReload")
	if type(val) == "boolean" then
		return val
	end
	return false
end

local function isProceduralRigEnabled(): boolean
	local val = localPlayer:GetAttribute("ProceduralRigEnabled")
	if type(val) == "boolean" then
		return val
	end
	return true
end

local function syncProceduralRig(character: Model?)
	if character == nil then
		return
	end
	if isProceduralRigEnabled() then
		-- Wait briefly for HumanoidRootPart / Motor6D rig if freshly spawned
		if character:FindFirstChild("HumanoidRootPart") == nil then
			character:WaitForChild("HumanoidRootPart", 5)
		end
		if character:FindFirstChildOfClass("Humanoid") == nil then
			character:WaitForChild("Humanoid", 5)
		end
		if isProceduralRigEnabled() and character.Parent ~= nil then
			CinemaEngine.AttachProceduralRig(character)
		end
	else
		CinemaEngine.DetachProceduralRig(character)
	end
end

localPlayer.CharacterAdded:Connect(function(character: Model)
	syncProceduralRig(character)
end)

localPlayer:GetAttributeChangedSignal("ProceduralRigEnabled"):Connect(function()
	syncProceduralRig(localPlayer.Character)
end)

if localPlayer.Character ~= nil then
	task.spawn(syncProceduralRig, localPlayer.Character)
end

local function playActiveCutscene()
	local presetName = getActivePresetName()
	if presetName == "None" or presetName == "Stop" then
		CinemaEngine.StopCutscene()
		return
	end

	CinemaEngine.PlayCutscene(presetName, {
		subject = localPlayer.Character,
		forceReload = getForceReload(),
	})
end

localPlayer:GetAttributeChangedSignal("CutsceneTrigger"):Connect(playActiveCutscene)

-- Preview convenience hotkeys:
-- [C] Play or abort the current cutscene Preset
-- [V] Cycle to the next cutscene Preset
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.C then
		if CinemaEngine.IsPlaying() then
			CinemaEngine.StopCutscene()
		else
			local prev = localPlayer:GetAttribute("CutsceneTrigger")
			local nextVal = if type(prev) == "number" then prev + 1 else 1
			localPlayer:SetAttribute("CutsceneTrigger", nextVal)
		end
	elseif input.KeyCode == Enum.KeyCode.V then
		local presets = CinemaEngine.ListPresets()
		if #presets == 0 then
			return
		end
		local current = getActivePresetName()
		local currentIndex = table.find(presets, current) or 0
		local nextIndex = (currentIndex % #presets) + 1
		local nextName = presets[nextIndex]
		localPlayer:SetAttribute("ActiveCutscene", nextName)
		print(string.format("[CinemaPreview] ActiveCutscene -> %s", nextName))
	end
end)
