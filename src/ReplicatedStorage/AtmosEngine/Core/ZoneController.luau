--!strict

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)
local TransitionRunner = require(script.Parent.TransitionRunner)

local ZoneController = {}

type RegisteredZone = {
	config: Types.ZoneConfig,
	order: number,
}

export type ZoneCallbacks = {
	applyPreset: (presetOrName: string | Types.AtmosPreset, options: Types.ApplyOptions?) -> boolean,
	reset: (duration: number?) -> (),
	getActivePreset: () -> (string | Types.AtmosPreset)?,
}

local DEFAULT_DAY_NIGHT_SPEED = 0.25 -- hours per second (~96s per full 24h cycle)

local zones: { RegisteredZone } = {}
local orderCounter = 0
local activeZoneId: string? = nil
local activeZoneExitDuration = 1.2
local baselinePreset: (string | Types.AtmosPreset)? = nil
local hadBaselinePreset = false
local callbacks: ZoneCallbacks? = nil
local customTarget: BasePart? = nil
local customPositionProvider: (() -> Vector3?)? = nil

local zoneHeartbeat: RBXScriptConnection? = nil
local dayNightEnabled = false
local dayNightSpeed = DEFAULT_DAY_NIGHT_SPEED
local dayNightHeartbeat: RBXScriptConnection? = nil

local function getTrackingPosition(): Vector3?
	if customPositionProvider ~= nil then
		return customPositionProvider()
	end

	if customTarget ~= nil and customTarget.Parent ~= nil then
		return customTarget.Position
	end

	if RunService:IsClient() then
		local player = Players.LocalPlayer
		if player ~= nil then
			local character = player.Character
			if character ~= nil and character.Parent ~= nil then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp ~= nil and hrp:IsA("BasePart") then
					return hrp.Position
				end
				local primary = character.PrimaryPart
				if primary ~= nil then
					return primary.Position
				end
				return character:GetPivot().Position
			end
		end
	end

	return nil
end

local function isPointInZone(point: Vector3, config: Types.ZoneConfig): boolean
	local cf: CFrame? = nil
	local size: Vector3? = nil

	if config.part ~= nil then
		if config.part.Parent == nil then
			return false
		end
		cf = config.part.CFrame
		size = config.part.Size
	else
		cf = config.cframe
		size = config.size
	end

	if cf == nil or size == nil then
		return false
	end

	local localPos = cf:PointToObjectSpace(point)
	local half = size * 0.5
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y
		and math.abs(localPos.Z) <= half.Z
end

local function pickHighestPriorityZone(point: Vector3): RegisteredZone?
	local best: RegisteredZone? = nil
	local bestPriority = -math.huge

	for _, entry in ipairs(zones) do
		if isPointInZone(point, entry.config) then
			local prio = entry.config.priority or 0
			if best == nil or prio > bestPriority or (prio == bestPriority and entry.order > best.order) then
				best = entry
				bestPriority = prio
			end
		end
	end

	return best
end

local function stepZones()
	if callbacks == nil then
		return
	end
	if #zones == 0 and activeZoneId == nil then
		return
	end

	local pos = getTrackingPosition()
	if pos == nil then
		return
	end

	local nextZone = pickHighestPriorityZone(pos)
	local nextZoneId = if nextZone ~= nil then nextZone.config.id else nil

	if nextZoneId == activeZoneId then
		return
	end

	local prevZoneId = activeZoneId
	activeZoneId = nextZoneId

	if nextZone ~= nil then
		-- Entering first zone from baseline: snapshot which preset (if any) was active
		if prevZoneId == nil then
			local active = callbacks.getActivePreset()
			if active ~= nil then
				hadBaselinePreset = true
				baselinePreset = active
			else
				hadBaselinePreset = false
				baselinePreset = nil
			end
		end

		local dur = if nextZone.config.transitionDuration ~= nil then nextZone.config.transitionDuration else 1.2
		activeZoneExitDuration = dur

		callbacks.applyPreset(nextZone.config.preset, {
			duration = dur,
			easingStyle = nextZone.config.easingStyle,
			easingDirection = nextZone.config.easingDirection,
		})
	else
		-- Exited all zones: restore baseline
		local exitDuration = activeZoneExitDuration

		if hadBaselinePreset and baselinePreset ~= nil then
			callbacks.applyPreset(baselinePreset, {
				duration = exitDuration,
			})
		else
			callbacks.reset(exitDuration)
		end

		hadBaselinePreset = false
		baselinePreset = nil
	end
end

local function ensureZoneHeartbeat()
	if zoneHeartbeat ~= nil then
		return
	end
	zoneHeartbeat = RunService.Heartbeat:Connect(function()
		stepZones()
	end)
end

local function stopZoneHeartbeatIfIdle()
	if #zones == 0 and zoneHeartbeat ~= nil then
		zoneHeartbeat:Disconnect()
		zoneHeartbeat = nil
	end
end

function ZoneController.BindCallbacks(cb: ZoneCallbacks)
	callbacks = cb
end

function ZoneController.SetTrackingTarget(target: BasePart?)
	customTarget = target
end

function ZoneController.SetPositionProvider(provider: (() -> Vector3?)?)
	customPositionProvider = provider
end

function ZoneController.RegisterZone(zoneConfig: Types.ZoneConfig): () -> ()
	assert(type(zoneConfig.id) == "string" and zoneConfig.id ~= "", "[AtmosEngine.ZoneController] zoneConfig.id must be a non-empty string.")
	assert(
		zoneConfig.part ~= nil or (zoneConfig.cframe ~= nil and zoneConfig.size ~= nil),
		"[AtmosEngine.ZoneController] zoneConfig requires either 'part' or ('cframe' and 'size')."
	)

	-- Replace existing zone with same id if present
	for i = #zones, 1, -1 do
		if zones[i].config.id == zoneConfig.id then
			table.remove(zones, i)
		end
	end

	orderCounter += 1
	local entry: RegisteredZone = {
		config = zoneConfig,
		order = orderCounter,
	}
	table.insert(zones, entry)
	ensureZoneHeartbeat()

	local unregistered = false
	return function()
		if unregistered then
			return
		end
		unregistered = true
		for i = #zones, 1, -1 do
			if zones[i] == entry then
				table.remove(zones, i)
				break
			end
		end
		if activeZoneId == zoneConfig.id then
			stepZones()
		end
		stopZoneHeartbeatIfIdle()
	end
end

function ZoneController.ClearZones(restoreBaseline: boolean?)
	local wasInZone = activeZoneId ~= nil
	table.clear(zones)
	activeZoneId = nil
	stopZoneHeartbeatIfIdle()

	if wasInZone and (restoreBaseline == nil or restoreBaseline == true) and callbacks ~= nil then
		if hadBaselinePreset and baselinePreset ~= nil then
			callbacks.applyPreset(baselinePreset, { duration = activeZoneExitDuration })
		else
			callbacks.reset(activeZoneExitDuration)
		end
	end

	hadBaselinePreset = false
	baselinePreset = nil
end

function ZoneController.GetActiveZoneId(): string?
	return activeZoneId
end

function ZoneController.NotifyManualOverride()
	-- When external code manually calls Apply/Reset while inside a zone, clear baseline override state
	if activeZoneId == nil then
		hadBaselinePreset = false
		baselinePreset = nil
	end
end

function ZoneController.SetDayNightCycle(enabled: boolean, speedHoursPerSec: number?)
	dayNightEnabled = enabled
	if speedHoursPerSec ~= nil then
		dayNightSpeed = speedHoursPerSec
	end

	if enabled then
		if dayNightHeartbeat == nil then
			dayNightHeartbeat = RunService.Heartbeat:Connect(function(dt: number)
				if not dayNightEnabled then
					return
				end
				-- Yield ClockTime control while a preset transition is actively tweening ClockTime
				if TransitionRunner.IsTransitioningClockTime() then
					return
				end
				Lighting.ClockTime = (Lighting.ClockTime + dt * dayNightSpeed) % 24
			end)
		end
	else
		if dayNightHeartbeat ~= nil then
			dayNightHeartbeat:Disconnect()
			dayNightHeartbeat = nil
		end
	end
end

function ZoneController.IsDayNightCycleEnabled(): boolean
	return dayNightEnabled
end

function ZoneController.GetDayNightSpeed(): number
	return dayNightSpeed
end

return ZoneController
