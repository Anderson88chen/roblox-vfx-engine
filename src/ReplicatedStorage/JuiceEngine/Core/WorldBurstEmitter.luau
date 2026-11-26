--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)

local WorldBurstEmitter = {}

local MAX_ATTACHMENT_POOL = 24
local MAX_KEYPOINTS = 20
local MAX_LIGHT_RANGE = 60

type ActiveLightFlash = {
	light: PointLight,
	attachment: Attachment,
	elapsed: number,
	duration: number,
	peakBrightness: number,
	peakRange: number,
}

type ActiveBurstSession = {
	attachment: Attachment,
	emitters: { ParticleEmitter },
	cleanupThread: thread?,
}

local freeAttachments: { Attachment } = {}
local createdAttachments = 0
local activeBursts: { ActiveBurstSession } = {}
local activeLights: { ActiveLightFlash } = {}
local lightHeartbeatConn: RBXScriptConnection? = nil

local function resolveNumberRange(spec: Types.RangeSpec?, defaultMin: number, defaultMax: number, valueScale: number): NumberRange
	if spec == nil then
		return NumberRange.new(defaultMin * valueScale, defaultMax * valueScale)
	end
	if type(spec) == "number" then
		local v = spec * valueScale
		return NumberRange.new(v, v)
	end
	if typeof(spec) == "NumberRange" then
		return NumberRange.new(spec.Min * valueScale, spec.Max * valueScale)
	end
	if type(spec) == "table" then
		local tbl = spec :: any
		local minV = if type(tbl.min) == "number"
			then tbl.min
			elseif type(tbl[1]) == "number" then tbl[1]
			else defaultMin
		local maxV = if type(tbl.max) == "number"
			then tbl.max
			elseif type(tbl[2]) == "number" then tbl[2]
			else minV
		if maxV < minV then
			minV, maxV = maxV, minV
		end
		return NumberRange.new(minV * valueScale, maxV * valueScale)
	end
	return NumberRange.new(defaultMin * valueScale, defaultMax * valueScale)
end

local function normalizeNumberPoints(rawPoints: { Types.NumberPoint }, clampMin: number?, clampMax: number?, valueScale: number): NumberSequence
	local sorted = table.clone(rawPoints)
	table.sort(sorted, function(a, b)
		return a.time < b.time
	end)

	local clamped: { NumberSequenceKeypoint } = {}
	for _, pt in ipairs(sorted) do
		local t = math.clamp(pt.time, 0, 1)
		local v = pt.value * valueScale
		if clampMin ~= nil and v < clampMin then
			v = clampMin
		end
		if clampMax ~= nil and v > clampMax then
			v = clampMax
		end
		local env = math.max(0, pt.envelope or 0) * valueScale
		table.insert(clamped, NumberSequenceKeypoint.new(t, v, env))
	end

	if #clamped == 0 then
		return NumberSequence.new(0)
	end
	if clamped[1].Time > 0 then
		table.insert(clamped, 1, NumberSequenceKeypoint.new(0, clamped[1].Value, clamped[1].Envelope))
	end
	if clamped[#clamped].Time < 1 then
		local last = clamped[#clamped]
		table.insert(clamped, NumberSequenceKeypoint.new(1, last.Value, last.Envelope))
	end

	if #clamped > MAX_KEYPOINTS then
		local reduced: { NumberSequenceKeypoint } = {}
		for i = 0, MAX_KEYPOINTS - 1 do
			local idx = 1 + math.floor((i / (MAX_KEYPOINTS - 1)) * (#clamped - 1) + 0.5)
			local kp = clamped[idx]
			local time = if i == 0 then 0 elseif i == MAX_KEYPOINTS - 1 then 1 else kp.Time
			table.insert(reduced, NumberSequenceKeypoint.new(time, kp.Value, kp.Envelope))
		end
		return NumberSequence.new(reduced)
	end

	return NumberSequence.new(clamped)
end

local function resolveNumberSequence(
	spec: Types.NumberCurveSpec?,
	defaultVal: number,
	clampMin: number?,
	clampMax: number?,
	valueScale: number
): NumberSequence
	if spec == nil then
		local v = defaultVal * valueScale
		if clampMin ~= nil and v < clampMin then
			v = clampMin
		end
		if clampMax ~= nil and v > clampMax then
			v = clampMax
		end
		return NumberSequence.new(v)
	end

	if type(spec) == "number" then
		local v = spec * valueScale
		if clampMin ~= nil and v < clampMin then
			v = clampMin
		end
		if clampMax ~= nil and v > clampMax then
			v = clampMax
		end
		return NumberSequence.new(v)
	end

	if typeof(spec) == "NumberSequence" then
		local kps = spec.Keypoints
		local pts: { Types.NumberPoint } = {}
		for _, kp in ipairs(kps) do
			table.insert(pts, { time = kp.Time, value = kp.Value, envelope = kp.Envelope })
		end
		return normalizeNumberPoints(pts, clampMin, clampMax, valueScale)
	end

	if type(spec) == "table" then
		local tbl = spec :: any
		if tbl.kind == "Keypoints" and type(tbl.points) == "table" then
			return normalizeNumberPoints(tbl.points :: { Types.NumberPoint }, clampMin, clampMax, valueScale)
		end
		return normalizeNumberPoints(spec :: { Types.NumberPoint }, clampMin, clampMax, valueScale)
	end

	return NumberSequence.new(defaultVal * valueScale)
end

local function resolveColorSequence(spec: Types.ColorCurveSpec?, defaultColor: Color3): ColorSequence
	if spec == nil then
		return ColorSequence.new(defaultColor)
	end
	if typeof(spec) == "Color3" then
		return ColorSequence.new(spec)
	end
	if typeof(spec) == "ColorSequence" then
		local kps = spec.Keypoints
		if #kps <= MAX_KEYPOINTS then
			return spec
		end
		local reduced: { ColorSequenceKeypoint } = {}
		for i = 0, MAX_KEYPOINTS - 1 do
			local idx = 1 + math.floor((i / (MAX_KEYPOINTS - 1)) * (#kps - 1) + 0.5)
			local kp = kps[idx]
			local t = if i == 0 then 0 elseif i == MAX_KEYPOINTS - 1 then 1 else kp.Time
			table.insert(reduced, ColorSequenceKeypoint.new(t, kp.Value))
		end
		return ColorSequence.new(reduced)
	end
	if type(spec) == "table" then
		local stops = table.clone(spec :: { Types.ColorStop })
		table.sort(stops, function(a, b)
			return a.time < b.time
		end)
		if #stops == 0 then
			return ColorSequence.new(defaultColor)
		end
		local kps: { ColorSequenceKeypoint } = {}
		for _, stop in ipairs(stops) do
			table.insert(kps, ColorSequenceKeypoint.new(math.clamp(stop.time, 0, 1), stop.color))
		end
		if kps[1].Time > 0 then
			table.insert(kps, 1, ColorSequenceKeypoint.new(0, kps[1].Value))
		end
		if kps[#kps].Time < 1 then
			table.insert(kps, ColorSequenceKeypoint.new(1, kps[#kps].Value))
		end
		if #kps > MAX_KEYPOINTS then
			local reduced: { ColorSequenceKeypoint } = {}
			for i = 0, MAX_KEYPOINTS - 1 do
				local idx = 1 + math.floor((i / (MAX_KEYPOINTS - 1)) * (#kps - 1) + 0.5)
				local kp = kps[idx]
				local t = if i == 0 then 0 elseif i == MAX_KEYPOINTS - 1 then 1 else kp.Time
				table.insert(reduced, ColorSequenceKeypoint.new(t, kp.Value))
			end
			return ColorSequence.new(reduced)
		end
		return ColorSequence.new(kps)
	end
	return ColorSequence.new(defaultColor)
end

local function acquireAttachment(): Attachment
	while #freeAttachments > 0 do
		local att = table.remove(freeAttachments)
		if att ~= nil and att.Parent ~= nil then
			return att
		end
		createdAttachments = math.max(0, createdAttachments - 1)
	end

	createdAttachments += 1
	local att = Instance.new("Attachment")
	att.Name = "__JuiceEngine_BurstAtt_" .. tostring(createdAttachments)
	att.Parent = workspace.Terrain
	return att
end

local function releaseBurstSession(session: ActiveBurstSession)
	if session.cleanupThread ~= nil then
		pcall(task.cancel, session.cleanupThread)
		session.cleanupThread = nil
	end

	local idx = table.find(activeBursts, session)
	if idx ~= nil then
		table.remove(activeBursts, idx)
	end

	for _, emitter in ipairs(session.emitters) do
		if emitter.Parent ~= nil then
			emitter:Clear()
			emitter.Enabled = false
			emitter:Destroy()
		end
	end
	table.clear(session.emitters)

	if session.attachment.Parent ~= nil and #freeAttachments < MAX_ATTACHMENT_POOL then
		if table.find(freeAttachments, session.attachment) == nil then
			table.insert(freeAttachments, session.attachment)
		end
	end
end

local function stepLights(dt: number)
	local clampedDt = math.min(dt, 0.1)
	local i = 1
	while i <= #activeLights do
		local entry = activeLights[i]
		if entry.light.Parent == nil or entry.attachment.Parent == nil then
			table.remove(activeLights, i)
		else
			entry.elapsed += clampedDt
			local alpha = if entry.duration > 0 then math.clamp(entry.elapsed / entry.duration, 0, 1) else 1
			if alpha >= 1 then
				entry.light.Enabled = false
				entry.light:Destroy()
				table.remove(activeLights, i)
			else
				local decay = (1 - alpha) * (1 - alpha)
				entry.light.Brightness = entry.peakBrightness * decay
				entry.light.Range = math.clamp(entry.peakRange * (0.4 + 0.6 * decay), 0, MAX_LIGHT_RANGE)
				i += 1
			end
		end
	end

	if #activeLights == 0 and lightHeartbeatConn ~= nil then
		lightHeartbeatConn:Disconnect()
		lightHeartbeatConn = nil
	end
end

local function spawnLightFlash(attachment: Attachment, lightSpec: Types.WorldBurstLightSpec, scale: number, intensity: number)
	local light = Instance.new("PointLight")
	light.Name = "JuiceBurstLight"
	light.Shadows = false
	light.Color = lightSpec.color or Color3.fromRGB(255, 225, 175)

	local peakBrightness = math.clamp((lightSpec.brightness or 2.8) * math.clamp(intensity, 0.25, 2.0), 0, 8)
	local peakRange = math.clamp((lightSpec.range or 16) * scale, 0, MAX_LIGHT_RANGE)
	light.Brightness = peakBrightness
	light.Range = peakRange
	light.Enabled = true
	light.Parent = attachment

	table.insert(activeLights, {
		light = light,
		attachment = attachment,
		elapsed = 0,
		duration = math.max(0.04, lightSpec.duration or 0.16),
		peakBrightness = peakBrightness,
		peakRange = peakRange,
	})

	if lightHeartbeatConn == nil then
		lightHeartbeatConn = RunService.Heartbeat:Connect(stepLights)
	end
end

function WorldBurstEmitter.Emit(spec: Types.WorldBurstSpec, worldCFrame: CFrame, scale: number?, intensity: number?)
	local finalScale = math.max(0.1, scale or 1) * (spec.scale or 1)
	local finalIntensity = math.max(0.1, intensity or 1)

	local attachment = acquireAttachment()
	attachment.WorldCFrame = worldCFrame

	local emitters: { ParticleEmitter } = {}
	local maxLifetime = 0.25

	if spec.particles ~= nil then
		for idx, pSpec in ipairs(spec.particles) do
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = pSpec.id or ("BurstLayer_" .. tostring(idx))
			emitter.Enabled = false
			emitter.Rate = 0
			emitter.Texture = pSpec.texture
			emitter.Color = resolveColorSequence(pSpec.color, Color3.new(1, 1, 1))
			emitter.Size = resolveNumberSequence(pSpec.size, 1, 0, nil, finalScale)
			emitter.Transparency = resolveNumberSequence(pSpec.transparency, 0, 0, 1, 1)
			emitter.Squash = resolveNumberSequence(pSpec.squash, 0, nil, nil, 1)

			local lifeRange = resolveNumberRange(pSpec.lifetime, 0.2, 0.4, 1)
			emitter.Lifetime = lifeRange
			if lifeRange.Max > maxLifetime then
				maxLifetime = lifeRange.Max
			end

			emitter.Speed = resolveNumberRange(pSpec.speed, 12, 24, finalScale)
			emitter.SpreadAngle = pSpec.spreadAngle or Vector2.new(180, 180)
			emitter.Acceleration = (pSpec.acceleration or Vector3.zero) * finalScale
			emitter.Drag = pSpec.drag or 4
			emitter.Rotation = resolveNumberRange(pSpec.rotation, 0, 360, 1)
			emitter.RotSpeed = resolveNumberRange(pSpec.rotSpeed, -90, 90, 1)
			emitter.Orientation = pSpec.orientation or Enum.ParticleOrientation.FacingCamera
			emitter.EmissionDirection = pSpec.emissionDirection or Enum.NormalId.Top
			emitter.LightEmission = math.clamp(pSpec.lightEmission or 0.9, 0, 1)
			emitter.LightInfluence = math.clamp(pSpec.lightInfluence or 0, 0, 1)
			emitter.Brightness = math.clamp(pSpec.brightness or 2.2, 0, 6)
			emitter.ZOffset = pSpec.zOffset or 1
			emitter.LockedToPart = false
			emitter.Parent = attachment

			local emitCount = math.max(1, math.round(pSpec.count * math.clamp(finalIntensity, 0.35, 2.2)))
			emitter:Emit(emitCount)
			table.insert(emitters, emitter)
		end
	end

	if spec.light ~= nil then
		spawnLightFlash(attachment, spec.light, finalScale, finalIntensity)
		local lightDur = spec.light.duration or 0.16
		if lightDur > maxLifetime then
			maxLifetime = lightDur
		end
	end

	local session: ActiveBurstSession = {
		attachment = attachment,
		emitters = emitters,
		cleanupThread = nil,
	}
	table.insert(activeBursts, session)

	session.cleanupThread = task.delay(maxLifetime + 0.2, function()
		session.cleanupThread = nil
		releaseBurstSession(session)
	end)
end

function WorldBurstEmitter.TriggerVFX(spec: Types.VFXTriggerSpec?, context: Types.PlayContext)
	local vfxModule = ReplicatedStorage:FindFirstChild("VFXEngine")
	if vfxModule == nil or not vfxModule:IsA("ModuleScript") then
		return
	end

	local okReq, vfxEngine = pcall(function()
		return require(vfxModule :: any)
	end)
	if not okReq or type(vfxEngine) ~= "table" then
		return
	end

	local targetRole = if spec ~= nil and spec.targetRole ~= nil then spec.targetRole else "target"
	local targetChar = context.targetCharacter
		or context.vfxCharacter
		or (if targetRole == "attacker" then context.attacker else context.target)
		or context.attacker
	if targetChar == nil or not targetChar:IsDescendantOf(game) then
		return
	end

	local auraName = context.vfxAura or (if spec ~= nil then spec.presetName else nil)
	local mountIfMissing = (context.vfxAura ~= nil) or (spec ~= nil and spec.mountIfMissing == true)
	local replayTimeline = if spec ~= nil and spec.replayTimeline ~= nil then spec.replayTimeline else true
	local vfxScale = (context.scale or 1) * (if spec ~= nil and spec.scale ~= nil then spec.scale else 1)

	pcall(function()
		local active = if type(vfxEngine.GetActive) == "function" then vfxEngine.GetActive(targetChar) else nil
		if active ~= nil then
			if auraName ~= nil and active.presetId ~= auraName and mountIfMissing and type(vfxEngine.Mount) == "function" then
				vfxEngine.Mount(targetChar, auraName, {
					scale = vfxScale,
					autoplay = true,
					forceReload = context.forceReload,
				})
			elseif replayTimeline and active.timeline ~= nil and type(active.timeline.Replay) == "function" then
				active.timeline:Replay()
			end
		elseif auraName ~= nil and mountIfMissing and type(vfxEngine.Mount) == "function" then
			vfxEngine.Mount(targetChar, auraName, {
				scale = vfxScale,
				autoplay = true,
				forceReload = context.forceReload,
			})
		end
	end)
end

function WorldBurstEmitter.StopAll()
	local burstSnapshot = table.clone(activeBursts)
	for _, session in ipairs(burstSnapshot) do
		releaseBurstSession(session)
	end

	for _, entry in ipairs(activeLights) do
		if entry.light.Parent ~= nil then
			entry.light.Enabled = false
			entry.light:Destroy()
		end
	end
	table.clear(activeLights)

	if lightHeartbeatConn ~= nil then
		lightHeartbeatConn:Disconnect()
		lightHeartbeatConn = nil
	end
end

return WorldBurstEmitter
