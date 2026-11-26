--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local WorldGenModule = ReplicatedStorage:WaitForChild("WorldGenEngine")
local WorldGenEngine = require(WorldGenModule :: any)

local localPlayer = Players.LocalPlayer
local DEFAULT_SCENE = "None"
local DEFAULT_SEED = 42

local CYCLE_ORDER: { string } = {
	"AstralSanctuaryArena",
	"CyberpunkAlleyway",
	"MistyStoneRuins",
	"None",
}

-- Initialize preview control attributes without auto-spawning into blank scenes
if localPlayer:GetAttribute("ActiveWorldScene") == nil then
	localPlayer:SetAttribute("ActiveWorldScene", DEFAULT_SCENE)
end
if localPlayer:GetAttribute("WorldSeed") == nil then
	localPlayer:SetAttribute("WorldSeed", DEFAULT_SEED)
end
if localPlayer:GetAttribute("WorldOriginOffset") == nil then
	localPlayer:SetAttribute("WorldOriginOffset", Vector3.zero)
end
if localPlayer:GetAttribute("WorldGenForceReload") == nil then
	localPlayer:SetAttribute("WorldGenForceReload", false)
end

local currentHandle: any = nil

local function getActiveSceneName(): string
	local val = localPlayer:GetAttribute("ActiveWorldScene")
	if type(val) == "string" and val ~= "" then
		return val
	end
	return DEFAULT_SCENE
end

local function getWorldSeed(): number
	local val = localPlayer:GetAttribute("WorldSeed")
	if type(val) == "number" then
		return math.floor(val)
	end
	return DEFAULT_SEED
end

local function getOriginOffset(): Vector3
	local val = localPlayer:GetAttribute("WorldOriginOffset")
	if typeof(val) == "Vector3" then
		return val
	end
	return Vector3.zero
end

local function getForceReload(): boolean
	local val = localPlayer:GetAttribute("WorldGenForceReload")
	if type(val) == "boolean" then
		return val
	end
	return false
end

local function computePlayerBaseOrigin(): CFrame
	local offset = getOriginOffset()
	local character = localPlayer.Character
	if character ~= nil then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart ~= nil and rootPart:IsA("BasePart") then
			local look = rootPart.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			if flatLook.Magnitude < 1e-4 then
				flatLook = Vector3.new(0, 0, -1)
			else
				flatLook = flatLook.Unit
			end

			local groundY = rootPart.Position.Y - 3
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local exclude: { Instance } = { character }
			local scenesRoot = Workspace:FindFirstChild("__WorldGenScenes")
			if scenesRoot ~= nil then
				table.insert(exclude, scenesRoot)
			end
			params.FilterDescendantsInstances = exclude
			params.IgnoreWater = true

			local hit = Workspace:Raycast(rootPart.Position, Vector3.new(0, -40, 0), params)
			if hit ~= nil then
				groundY = hit.Position.Y
			end

			local basePos = Vector3.new(rootPart.Position.X, groundY, rootPart.Position.Z)
			local yawCF = CFrame.lookAt(basePos, basePos + flatLook)
			return yawCF * CFrame.new(offset)
		end
	end

	return CFrame.new(offset)
end

local function clearCurrentPreview()
	if currentHandle ~= nil then
		WorldGenEngine.Clear(currentHandle)
		currentHandle = nil
	end
	WorldGenEngine.ClearAll()
end

local function applyActiveScene()
	clearCurrentPreview()

	local sceneName = getActiveSceneName()
	if sceneName == "None" then
		return
	end

	local origin = computePlayerBaseOrigin()
	currentHandle = WorldGenEngine.BuildScene(sceneName, {
		origin = origin,
		seed = getWorldSeed(),
		forceReload = getForceReload(),
		clearPrevious = true,
	})
end

localPlayer:GetAttributeChangedSignal("ActiveWorldScene"):Connect(applyActiveScene)

localPlayer:GetAttributeChangedSignal("WorldSeed"):Connect(function()
	if getActiveSceneName() ~= "None" then
		applyActiveScene()
	end
end)

localPlayer:GetAttributeChangedSignal("WorldOriginOffset"):Connect(function()
	if getActiveSceneName() ~= "None" then
		applyActiveScene()
	end
end)

-- Preview convenience hotkey:
-- [G] Cycle preview world scene: AstralSanctuaryArena -> CyberpunkAlleyway -> MistyStoneRuins -> None
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.G then
		local current = getActiveSceneName()
		local idx = table.find(CYCLE_ORDER, current) or 0
		local nextIdx = (idx % #CYCLE_ORDER) + 1
		local nextScene = CYCLE_ORDER[nextIdx]
		localPlayer:SetAttribute("ActiveWorldScene", nextScene)
		print(string.format("[WorldGenPreview] ActiveWorldScene -> %s", nextScene))
	end
end)
