--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AtmosEngineModule = ReplicatedStorage:WaitForChild("AtmosEngine")
local AtmosEngine = require(AtmosEngineModule :: any)

local localPlayer = Players.LocalPlayer
local DEFAULT_DAY_NIGHT_SPEED = 0.25

-- Initialize preview control attributes if missing; default ActiveAtmos = "None" preserves original scene lighting
if localPlayer:GetAttribute("ActiveAtmos") == nil then
	localPlayer:SetAttribute("ActiveAtmos", "None")
end
if localPlayer:GetAttribute("AtmosTransitionDuration") == nil then
	localPlayer:SetAttribute("AtmosTransitionDuration", 1.2)
end
if localPlayer:GetAttribute("AtmosDayNightSpeed") == nil then
	localPlayer:SetAttribute("AtmosDayNightSpeed", 0)
end
if localPlayer:GetAttribute("AtmosForceReload") == nil then
	localPlayer:SetAttribute("AtmosForceReload", false)
end

local function getTransitionDuration(): number
	local val = localPlayer:GetAttribute("AtmosTransitionDuration")
	if type(val) == "number" then
		return math.max(0, val)
	end
	return 1.2
end

local function getForceReload(): boolean
	local val = localPlayer:GetAttribute("AtmosForceReload")
	if type(val) == "boolean" then
		return val
	end
	return false
end

local function applyActiveAtmos()
	local presetAttr = localPlayer:GetAttribute("ActiveAtmos")
	local presetName = if type(presetAttr) == "string" then presetAttr else "None"
	local duration = getTransitionDuration()

	if presetName == "" or presetName == "None" or presetName == "Reset" then
		AtmosEngine.Reset(duration)
		return
	end

	AtmosEngine.Apply(presetName, {
		duration = duration,
		forceReload = getForceReload(),
	})
end

local function syncDayNightCycle()
	local speedAttr = localPlayer:GetAttribute("AtmosDayNightSpeed")
	local speed = if type(speedAttr) == "number" then speedAttr else 0
	if speed > 0 then
		AtmosEngine.SetDayNightCycle(true, speed)
	else
		AtmosEngine.SetDayNightCycle(false)
	end
end

localPlayer:GetAttributeChangedSignal("ActiveAtmos"):Connect(applyActiveAtmos)
localPlayer:GetAttributeChangedSignal("AtmosDayNightSpeed"):Connect(syncDayNightCycle)

-- Sync day/night speed if user pre-configured a non-zero initial speed before script ran
local initialSpeed = localPlayer:GetAttribute("AtmosDayNightSpeed")
if type(initialSpeed) == "number" and initialSpeed > 0 then
	syncDayNightCycle()
end

-- If ActiveAtmos was already set to a non-None preset on join, apply it; otherwise leave original scene untouched
local initialAtmos = localPlayer:GetAttribute("ActiveAtmos")
if type(initialAtmos) == "string" and initialAtmos ~= "" and initialAtmos ~= "None" and initialAtmos ~= "Reset" then
	applyActiveAtmos()
end

-- Preview convenience hotkeys:
-- [L] Cycle presets (including "None" to restore original lighting)
-- [N] Toggle Day-Night Cycle
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.L then
		local presets = AtmosEngine.ListPresets()
		local cycleList: { string } = { "None" }
		for _, name in ipairs(presets) do
			table.insert(cycleList, name)
		end

		local currentAttr = localPlayer:GetAttribute("ActiveAtmos")
		local current = if type(currentAttr) == "string" and currentAttr ~= "" and currentAttr ~= "Reset"
			then currentAttr
			else "None"
		local currentIndex = table.find(cycleList, current) or 1
		local nextIndex = (currentIndex % #cycleList) + 1
		localPlayer:SetAttribute("ActiveAtmos", cycleList[nextIndex])
	elseif input.KeyCode == Enum.KeyCode.N then
		local speedAttr = localPlayer:GetAttribute("AtmosDayNightSpeed")
		local currentSpeed = if type(speedAttr) == "number" then speedAttr else 0
		if currentSpeed > 0 then
			localPlayer:SetAttribute("AtmosDayNightSpeed", 0)
		else
			localPlayer:SetAttribute("AtmosDayNightSpeed", DEFAULT_DAY_NIGHT_SPEED)
		end
	end
end)
