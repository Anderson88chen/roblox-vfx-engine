--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local JuiceEngineModule = ReplicatedStorage:WaitForChild("JuiceEngine")
local JuiceEngine = require(JuiceEngineModule :: any)

local localPlayer = Players.LocalPlayer
local DEFAULT_PRESET = "HeavySlashHit"
local IMPACT_FORWARD_OFFSET = 4.5

-- Initialize preview control attributes if missing so Studio Properties panel exposes them immediately
if localPlayer:GetAttribute("ActiveJuice") == nil then
	localPlayer:SetAttribute("ActiveJuice", DEFAULT_PRESET)
end
if localPlayer:GetAttribute("JuiceIntensity") == nil then
	localPlayer:SetAttribute("JuiceIntensity", 1)
end
if localPlayer:GetAttribute("JuiceTrigger") == nil then
	localPlayer:SetAttribute("JuiceTrigger", 0)
end
if localPlayer:GetAttribute("JuiceForceReload") == nil then
	localPlayer:SetAttribute("JuiceForceReload", false)
end

local function getActivePresetName(): string
	local val = localPlayer:GetAttribute("ActiveJuice")
	if type(val) == "string" and val ~= "" then
		return val
	end
	return DEFAULT_PRESET
end

local function getIntensity(): number
	local val = localPlayer:GetAttribute("JuiceIntensity")
	if type(val) == "number" then
		return math.max(0.05, val)
	end
	return 1
end

local function getForceReload(): boolean
	local val = localPlayer:GetAttribute("JuiceForceReload")
	if type(val) == "boolean" then
		return val
	end
	return false
end

local function resolveImpactCFrame(character: Model?): CFrame?
	if character ~= nil and character.Parent ~= nil then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp ~= nil and hrp:IsA("BasePart") then
			return hrp.CFrame * CFrame.new(0, 0, -IMPACT_FORWARD_OFFSET)
		end
		return character:GetPivot() * CFrame.new(0, 0, -IMPACT_FORWARD_OFFSET)
	end

	local camera = workspace.CurrentCamera
	if camera ~= nil then
		return camera.CFrame * CFrame.new(0, 0, -8)
	end
	return nil
end

local function triggerCurrentJuice()
	local presetName = getActivePresetName()
	if presetName == "None" then
		JuiceEngine.StopAll()
		return
	end

	local character = localPlayer.Character
	local impactCFrame = resolveImpactCFrame(character)
	local impactPos = if impactCFrame ~= nil then impactCFrame.Position else nil

	JuiceEngine.Play(presetName, {
		position = impactPos,
		cframe = impactCFrame,
		attacker = character,
		target = character,
		targetCharacter = character,
		intensity = getIntensity(),
		scale = 1,
		forceReload = getForceReload(),
	})
end

localPlayer:GetAttributeChangedSignal("JuiceTrigger"):Connect(triggerCurrentJuice)

-- Preview convenience hotkeys:
-- [J] Immediately trigger the active Juice Preset in front of and on the character
-- [H] Cycle to the next Juice Preset
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.J then
		local prev = localPlayer:GetAttribute("JuiceTrigger")
		local nextVal = if type(prev) == "number" then prev + 1 else 1
		localPlayer:SetAttribute("JuiceTrigger", nextVal)
	elseif input.KeyCode == Enum.KeyCode.H then
		local presets = JuiceEngine.ListPresets()
		if #presets == 0 then
			return
		end
		local current = getActivePresetName()
		local currentIndex = table.find(presets, current) or 0
		local nextIndex = (currentIndex % #presets) + 1
		local nextName = presets[nextIndex]
		localPlayer:SetAttribute("ActiveJuice", nextName)
		print(string.format("[JuicePreview] ActiveJuice -> %s", nextName))
	end
end)
