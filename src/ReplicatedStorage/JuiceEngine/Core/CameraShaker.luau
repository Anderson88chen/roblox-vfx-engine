--!strict

local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)

local CameraShaker = {}

local PRE_STEP_NAME = "JuiceEngine_CameraShake_Pre"
local POST_STEP_NAME = "JuiceEngine_CameraShake_Post"
local PRE_PRIORITY = Enum.RenderPriority.Camera.Value - 1
local POST_PRIORITY = Enum.RenderPriority.Camera.Value + 10
local MIN_FOV = 20
local MAX_FOV = 115

type ShakeInstance = {
	id: number,
	spec: Types.CameraShakeSpec,
	origin: Vector3?,
	maxDistance: number?,
	intensity: number,
	seed: number,
	phase: number,
	elapsed: number,
	fadeIn: number,
	sustain: number,
	fadeOut: number,
	totalDuration: number,
	stopped: boolean,
}

local activeShakes: { ShakeInstance } = {}
local shakeCounter = 0
local isBound = false

local appliedOffset = false
local lastCamera: Camera? = nil
local lastOffsetCFrame = CFrame.identity
local lastFovDelta = 0

local function computeEnvelope(inst: ShakeInstance): number
	local t = inst.elapsed
	if t >= inst.totalDuration then
		return 0
	end

	if inst.fadeIn > 0 and t < inst.fadeIn then
		local alpha = math.clamp(t / inst.fadeIn, 0, 1)
		return alpha * alpha * (3 - 2 * alpha)
	end

	local sustainEnd = inst.fadeIn + inst.sustain
	if t <= sustainEnd then
		return 1
	end

	if inst.fadeOut > 0 then
		local outAlpha = math.clamp((t - sustainEnd) / inst.fadeOut, 0, 1)
		local inv = 1 - outAlpha
		return inv * inv
	end

	return 0
end

local function computeSpatialAttenuation(inst: ShakeInstance, cameraPos: Vector3): number
	if inst.origin == nil then
		return 1
	end
	local maxDist = inst.maxDistance or inst.spec.maxDistance or 80
	if maxDist <= 0 then
		return 1
	end
	local dist = (cameraPos - inst.origin).Magnitude
	if dist >= maxDist then
		return 0
	end
	local linear = 1 - (dist / maxDist)
	return linear * linear
end

local function unbindSteps()
	if not isBound then
		return
	end
	isBound = false
	pcall(function()
		RunService:UnbindFromRenderStep(PRE_STEP_NAME)
	end)
	pcall(function()
		RunService:UnbindFromRenderStep(POST_STEP_NAME)
	end)
end

local function onPreCamera(_dt: number)
	local camera = workspace.CurrentCamera
	if appliedOffset then
		if camera ~= nil and camera == lastCamera then
			camera.CFrame = camera.CFrame * lastOffsetCFrame:Inverse()
			camera.FieldOfView = math.clamp(camera.FieldOfView - lastFovDelta, MIN_FOV, MAX_FOV)
		end
		lastOffsetCFrame = CFrame.identity
		lastFovDelta = 0
		lastCamera = nil
		appliedOffset = false
	end

	if #activeShakes == 0 then
		unbindSteps()
	end
end

local function onPostCamera(dt: number)
	local camera = workspace.CurrentCamera
	if camera == nil or #activeShakes == 0 then
		return
	end

	local clampedDt = math.min(dt, 0.1)
	local cameraPos = camera.CFrame.Position

	local totalPos = Vector3.zero
	local totalRot = Vector3.zero
	local totalFov = 0
	local anyContribution = false

	local i = 1
	while i <= #activeShakes do
		local inst = activeShakes[i]
		inst.elapsed += clampedDt

		if inst.stopped or inst.elapsed >= inst.totalDuration then
			table.remove(activeShakes, i)
		else
			local env = computeEnvelope(inst)
			if env > 0 then
				local atten = computeSpatialAttenuation(inst, cameraPos)
				if atten > 0 then
					anyContribution = true
					local mag = inst.spec.magnitude * inst.intensity * env * atten
					local roughness = math.max(0.1, inst.spec.roughness)
					local nTime = inst.elapsed * roughness

					-- Blend 75% Perlin noise (scaled from ~[-0.5, 0.5] to [-1, 1]) with 25% damped harmonic wave
					local harmonic = math.sin(nTime * math.pi * 1.35 + inst.phase)
					local px = (math.noise(inst.seed + 1.17, nTime, 0) * 2) * 0.75 + harmonic * 0.25
					local py = (math.noise(inst.seed + 2.41, nTime, 11) * 2) * 0.75
						+ math.cos(nTime * math.pi * 1.15 + inst.phase) * 0.25
					local pz = (math.noise(inst.seed + 3.73, nTime, 23) * 2) * 0.75 - harmonic * 0.25

					local rx = (math.noise(inst.seed + 5.13, nTime, 37) * 2) * 0.75 + harmonic * 0.25
					local ry = (math.noise(inst.seed + 6.59, nTime, 49) * 2) * 0.75
						+ math.cos(nTime * math.pi * 1.25 + inst.phase) * 0.25
					local rz = (math.noise(inst.seed + 8.07, nTime, 61) * 2) * 0.75 - harmonic * 0.25

					local posInf = inst.spec.posInfluence or Vector3.new(0.25, 0.25, 0.25)
					local rotInf = inst.spec.rotInfluence or Vector3.new(1.2, 1.0, 1.8)

					totalPos += Vector3.new(px * posInf.X, py * posInf.Y, pz * posInf.Z) * mag
					totalRot += Vector3.new(rx * rotInf.X, ry * rotInf.Y, rz * rotInf.Z) * mag

					local fovPunch = inst.spec.fovPunch or 0
					if fovPunch ~= 0 then
						totalFov += fovPunch * inst.intensity * env * atten
					end
				end
			end
			i += 1
		end
	end

	if not anyContribution then
		return
	end

	local offsetCFrame = CFrame.new(totalPos)
		* CFrame.Angles(math.rad(totalRot.X), math.rad(totalRot.Y), math.rad(totalRot.Z))

	camera.CFrame = camera.CFrame * offsetCFrame

	local baseFov = camera.FieldOfView
	local targetFov = math.clamp(baseFov + totalFov, MIN_FOV, MAX_FOV)
	local actualFovDelta = targetFov - baseFov
	camera.FieldOfView = targetFov

	lastOffsetCFrame = offsetCFrame
	lastFovDelta = actualFovDelta
	lastCamera = camera
	appliedOffset = true
end

local function ensureBound()
	if isBound or not RunService:IsClient() then
		return
	end
	isBound = true
	RunService:BindToRenderStep(PRE_STEP_NAME, PRE_PRIORITY, onPreCamera)
	RunService:BindToRenderStep(POST_STEP_NAME, POST_PRIORITY, onPostCamera)
end

function CameraShaker.Shake(
	spec: Types.CameraShakeSpec,
	origin: Vector3?,
	maxDistance: number?,
	intensity: number?
): Types.CameraShakeHandle
	shakeCounter += 1
	local fadeIn = math.max(0, spec.fadeIn or 0)
	local sustain = math.max(0, spec.sustain or 0)
	local fadeOut = math.max(0, if spec.fadeOut ~= nil then spec.fadeOut else 0.35)
	local totalDuration = fadeIn + sustain + fadeOut

	local inst: ShakeInstance = {
		id = shakeCounter,
		spec = spec,
		origin = origin,
		maxDistance = maxDistance,
		intensity = math.max(0, intensity or 1),
		seed = ((os.clock() * 13.7) % 1000) + shakeCounter * 19.31,
		phase = (shakeCounter * 1.6180339) % (math.pi * 2),
		elapsed = 0,
		fadeIn = fadeIn,
		sustain = sustain,
		fadeOut = fadeOut,
		totalDuration = totalDuration,
		stopped = false,
	}

	if RunService:IsClient() and totalDuration > 0 and inst.intensity > 0 then
		table.insert(activeShakes, inst)
		ensureBound()
	else
		inst.stopped = true
	end

	local handle: Types.CameraShakeHandle = {
		Stop = function(_self: Types.CameraShakeHandle, fadeOutOverride: number?)
			if inst.stopped then
				return
			end
			if fadeOutOverride ~= nil and fadeOutOverride > 0 then
				inst.fadeIn = 0
				inst.sustain = 0
				inst.fadeOut = fadeOutOverride
				inst.elapsed = 0
				inst.totalDuration = fadeOutOverride
			else
				inst.stopped = true
			end
		end,
		IsActive = function(_self: Types.CameraShakeHandle): boolean
			return not inst.stopped and inst.elapsed < inst.totalDuration
		end,
	}

	return handle
end

function CameraShaker.StopAll()
	for _, inst in ipairs(activeShakes) do
		inst.stopped = true
	end
	table.clear(activeShakes)
	-- Leave PreCamera bound for one frame if appliedOffset is true so it cleanly restores Camera CFrame/FOV
	if not appliedOffset then
		unbindSteps()
	end
end

return CameraShaker
