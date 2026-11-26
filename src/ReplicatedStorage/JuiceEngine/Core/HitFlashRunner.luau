--!strict

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Types = require(script.Parent.Types)

local HitFlashRunner = {}

-- Strictly cap at 16 instances so we stay safely below Roblox's global 31 Highlight limit
local MAX_HIGHLIGHT_POOL = 16
local CONTAINER_NAME = "__JuiceEngine_Highlights"

type ActiveFlash = {
	model: Model,
	highlight: Highlight,
	generation: number,
	elapsed: number,
	holdDuration: number,
	fadeDuration: number,
	flashColor: Color3,
	targetColor: Color3,
	startFillTrans: number,
	endFillTrans: number,
	outlineColor: Color3,
	startOutlineTrans: number,
	endOutlineTrans: number,
	ancestryConn: RBXScriptConnection?,
}

local highlightContainer: Folder? = nil
local freePool: { Highlight } = {}
local activeByModel: { [Model]: ActiveFlash } = {}
local activeOrder: { ActiveFlash } = {}
local totalCreated = 0
local heartbeatConn: RBXScriptConnection? = nil
local generationCounter = 0

local function getContainer(): Folder
	if highlightContainer ~= nil and highlightContainer.Parent ~= nil then
		return highlightContainer
	end
	local existing = workspace:FindFirstChild(CONTAINER_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		highlightContainer = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = CONTAINER_NAME
	folder.Parent = workspace
	highlightContainer = folder
	return folder
end

local function releaseFlash(flash: ActiveFlash)
	if activeByModel[flash.model] == flash then
		activeByModel[flash.model] = nil
	end

	local idx = table.find(activeOrder, flash)
	if idx ~= nil then
		table.remove(activeOrder, idx)
	end

	if flash.ancestryConn ~= nil then
		flash.ancestryConn:Disconnect()
		flash.ancestryConn = nil
	end

	local hl = flash.highlight
	if hl.Parent ~= nil then
		hl.Enabled = false
		hl.Adornee = nil
		hl.Parent = getContainer()
		if table.find(freePool, hl) == nil then
			table.insert(freePool, hl)
		end
	else
		totalCreated = math.max(0, totalCreated - 1)
	end
end

local function acquireHighlight(): Highlight?
	while #freePool > 0 do
		local recycled = table.remove(freePool)
		if recycled ~= nil and recycled.Parent ~= nil then
			return recycled
		end
		totalCreated = math.max(0, totalCreated - 1)
	end

	if totalCreated < MAX_HIGHLIGHT_POOL then
		totalCreated += 1
		local hl = Instance.new("Highlight")
		hl.Name = "JuiceHitFlash_" .. tostring(totalCreated)
		hl.Enabled = false
		hl.Adornee = nil
		hl.Parent = getContainer()
		return hl
	end

	-- Pool saturated: recycle the oldest active flash to preserve the 16-instance budget
	if #activeOrder > 0 then
		local oldest = activeOrder[1]
		releaseFlash(oldest)
		return table.remove(freePool)
	end

	return nil
end

local function stopHeartbeatIfIdle()
	if #activeOrder == 0 and heartbeatConn ~= nil then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end

local function stepFlashes(dt: number)
	local clampedDt = math.min(dt, 0.1)
	local i = 1
	while i <= #activeOrder do
		local flash = activeOrder[i]
		if flash.model.Parent == nil or flash.highlight.Parent == nil then
			releaseFlash(flash)
		else
			flash.elapsed += clampedDt
			if flash.elapsed <= flash.holdDuration then
				i += 1
			else
				local fadeElapsed = flash.elapsed - flash.holdDuration
				local alpha = if flash.fadeDuration > 0
					then math.clamp(fadeElapsed / flash.fadeDuration, 0, 1)
					else 1
				if alpha >= 1 then
					releaseFlash(flash)
				else
					local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					local hl = flash.highlight
					hl.FillColor = flash.flashColor:Lerp(flash.targetColor, eased)
					hl.FillTransparency = flash.startFillTrans + (flash.endFillTrans - flash.startFillTrans) * eased
					hl.OutlineTransparency = flash.startOutlineTrans
						+ (flash.endOutlineTrans - flash.startOutlineTrans) * eased
					i += 1
				end
			end
		end
	end

	stopHeartbeatIfIdle()
end

local function ensureHeartbeat()
	if heartbeatConn ~= nil then
		return
	end
	heartbeatConn = RunService.Heartbeat:Connect(stepFlashes)
end

function HitFlashRunner.Flash(model: Model, spec: Types.HitFlashSpec)
	if model == nil or not model:IsDescendantOf(game) then
		return
	end

	local flashColor = spec.flashColor or Color3.new(1, 1, 1)
	local targetColor = spec.targetColor or flashColor
	local startFillTrans = math.clamp(if spec.fillTransparency ~= nil then spec.fillTransparency else 0.15, 0, 1)
	local endFillTrans = math.clamp(if spec.endFillTransparency ~= nil then spec.endFillTransparency else 1, 0, 1)
	local outlineColor = spec.outlineColor or Color3.new(1, 1, 1)
	local startOutlineTrans = math.clamp(if spec.outlineTransparency ~= nil then spec.outlineTransparency else 0, 0, 1)
	local endOutlineTrans = math.clamp(
		if spec.endOutlineTransparency ~= nil then spec.endOutlineTransparency else 1,
		0,
		1
	)
	local holdDuration = math.max(0, if spec.holdDuration ~= nil then spec.holdDuration else 0.03)
	local totalDuration = math.max(0.01, if spec.duration ~= nil then spec.duration else 0.18)
	local fadeDuration = math.max(0.01, totalDuration - holdDuration)
	local depthMode = spec.depthMode or Enum.HighlightDepthMode.Occluded

	local existing = activeByModel[model]
	local hl: Highlight?
	if existing ~= nil then
		hl = existing.highlight
		if existing.ancestryConn ~= nil then
			existing.ancestryConn:Disconnect()
			existing.ancestryConn = nil
		end
		local idx = table.find(activeOrder, existing)
		if idx ~= nil then
			table.remove(activeOrder, idx)
		end
		activeByModel[model] = nil
	else
		hl = acquireHighlight()
	end

	if hl == nil then
		return
	end

	generationCounter += 1
	local gen = generationCounter

	hl.Parent = getContainer()
	hl.DepthMode = depthMode
	hl.FillColor = flashColor
	hl.FillTransparency = startFillTrans
	hl.OutlineColor = outlineColor
	hl.OutlineTransparency = startOutlineTrans
	hl.Adornee = model
	hl.Enabled = true

	local flash: ActiveFlash = {
		model = model,
		highlight = hl,
		generation = gen,
		elapsed = 0,
		holdDuration = holdDuration,
		fadeDuration = fadeDuration,
		flashColor = flashColor,
		targetColor = targetColor,
		startFillTrans = startFillTrans,
		endFillTrans = endFillTrans,
		outlineColor = outlineColor,
		startOutlineTrans = startOutlineTrans,
		endOutlineTrans = endOutlineTrans,
		ancestryConn = nil,
	}

	flash.ancestryConn = model.AncestryChanged:Connect(function(_child: Instance, parent: Instance?)
		if parent == nil and flash.generation == gen then
			releaseFlash(flash)
			stopHeartbeatIfIdle()
		end
	end)

	activeByModel[model] = flash
	table.insert(activeOrder, flash)
	ensureHeartbeat()
end

function HitFlashRunner.StopAll()
	local snapshot = table.clone(activeOrder)
	for _, flash in ipairs(snapshot) do
		releaseFlash(flash)
	end
	stopHeartbeatIfIdle()
end

return HitFlashRunner
