--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local VFXEngineModule = ReplicatedStorage:WaitForChild("VFXEngine")
local VFXEngine = require(VFXEngineModule :: any)

local localPlayer = Players.LocalPlayer
local DEFAULT_PRESET = "AstralDualRing"

-- Initialize preview control attributes if missing so Studio Properties panel exposes them immediately
if localPlayer:GetAttribute("ActiveAura") == nil then
	localPlayer:SetAttribute("ActiveAura", DEFAULT_PRESET)
end
if localPlayer:GetAttribute("AuraScale") == nil then
	localPlayer:SetAttribute("AuraScale", 1)
end
if localPlayer:GetAttribute("ReplayTrigger") == nil then
	localPlayer:SetAttribute("ReplayTrigger", 0)
end
if localPlayer:GetAttribute("ForceReload") == nil then
	localPlayer:SetAttribute("ForceReload", false)
end

local currentCharacter: Model? = nil
local characterConnections: { RBXScriptConnection } = {}

local function getEffectiveString(char: Model?, attrName: string, fallback: string): string
	if char ~= nil then
		local charVal = char:GetAttribute(attrName)
		if type(charVal) == "string" then
			return charVal
		end
	end
	local playerVal = localPlayer:GetAttribute(attrName)
	if type(playerVal) == "string" then
		return playerVal
	end
	return fallback
end

local function getEffectiveNumber(char: Model?, attrName: string, fallback: number): number
	if char ~= nil then
		local charVal = char:GetAttribute(attrName)
		if type(charVal) == "number" then
			return charVal
		end
	end
	local playerVal = localPlayer:GetAttribute(attrName)
	if type(playerVal) == "number" then
		return playerVal
	end
	return fallback
end

local function getEffectiveBool(char: Model?, attrName: string, fallback: boolean): boolean
	if char ~= nil then
		local charVal = char:GetAttribute(attrName)
		if type(charVal) == "boolean" then
			return charVal
		end
	end
	local playerVal = localPlayer:GetAttribute(attrName)
	if type(playerVal) == "boolean" then
		return playerVal
	end
	return fallback
end

local function applyActiveAura()
	local character = currentCharacter
	if character == nil or character.Parent == nil then
		return
	end

	local auraName = getEffectiveString(character, "ActiveAura", "")
	if auraName == "" or auraName == "None" then
		VFXEngine.Unmount(character)
		return
	end

	local scale = math.max(0.05, getEffectiveNumber(character, "AuraScale", 1))
	local forceReload = getEffectiveBool(character, "ForceReload", false)

	VFXEngine.Mount(character, auraName, {
		scale = scale,
		autoplay = true,
		forceReload = forceReload,
	})
end

local function handleReplay()
	local character = currentCharacter
	if character == nil or character.Parent == nil then
		return
	end

	local forceReload = getEffectiveBool(character, "ForceReload", false)
	local active = VFXEngine.GetActive(character)
	if forceReload or active == nil then
		applyActiveAura()
		return
	end

	if active.timeline ~= nil then
		active.timeline:Replay()
	else
		applyActiveAura()
	end
end

local function clearCharacterConnections()
	for _, conn in ipairs(characterConnections) do
		conn:Disconnect()
	end
	table.clear(characterConnections)
end

local function bindCharacter(character: Model)
	clearCharacterConnections()
	currentCharacter = character

	-- Wait briefly for HumanoidRootPart if character is freshly added
	if character:FindFirstChild("HumanoidRootPart") == nil then
		character:WaitForChild("HumanoidRootPart", 5)
	end

	table.insert(
		characterConnections,
		character:GetAttributeChangedSignal("ActiveAura"):Connect(applyActiveAura)
	)
	table.insert(
		characterConnections,
		character:GetAttributeChangedSignal("AuraScale"):Connect(applyActiveAura)
	)
	table.insert(
		characterConnections,
		character:GetAttributeChangedSignal("ReplayTrigger"):Connect(handleReplay)
	)

	applyActiveAura()
end

localPlayer:GetAttributeChangedSignal("ActiveAura"):Connect(applyActiveAura)
localPlayer:GetAttributeChangedSignal("AuraScale"):Connect(applyActiveAura)
localPlayer:GetAttributeChangedSignal("ReplayTrigger"):Connect(handleReplay)

localPlayer.CharacterAdded:Connect(bindCharacter)
if localPlayer.Character ~= nil then
	task.spawn(bindCharacter, localPlayer.Character)
end

-- Preview convenience hotkeys: [K] cycle presets, [R] replay timeline
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.K then
		local presets = VFXEngine.ListPresets()
		if #presets == 0 then
			return
		end
		local current = getEffectiveString(currentCharacter, "ActiveAura", "")
		local currentIndex = table.find(presets, current) or 0
		local nextIndex = (currentIndex % #presets) + 1
		localPlayer:SetAttribute("ActiveAura", presets[nextIndex])
	elseif input.KeyCode == Enum.KeyCode.R then
		local prev = localPlayer:GetAttribute("ReplayTrigger")
		local nextVal = if type(prev) == "number" then prev + 1 else 1
		localPlayer:SetAttribute("ReplayTrigger", nextVal)
	end
end)
