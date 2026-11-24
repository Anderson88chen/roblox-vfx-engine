--!strict

local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)

local OrbitController = {}

local TWO_PI = math.pi * 2
local MAX_LIGHT_RANGE = 60

type OrbitState = {
	spec: Types.OrbitSpec,
	group: string,
	anchor: Attachment,
	topAnchor: Attachment?,
	bottomAnchor: Attachment?,
	tiltCF: CFrame,
	planeNormal: Vector3,
	angle: number,
	baseRadius: number,
	baseHeight: number,
	halfWidth: number,
	radiusPulseAmp: number,
	radiusPulseFreq: number,
	verticalBobAmp: number,
	verticalBobFreq: number,
}

type FlashState = {
	remaining: number,
	duration: number,
	addBrightness: number,
	addRange: number,
}

local function buildOrbitStates(
	rig: Types.RigContext,
	orbitSpecs: { Types.OrbitSpec }?
): { OrbitState }
	local states: { OrbitState } = {}
	if orbitSpecs == nil then
		return states
	end

	local scale = rig.scale
	for _, spec in ipairs(orbitSpecs) do
		local baseName = "Orbit_" .. tostring(spec.anchorIndex)
		local anchor = rig.anchors[baseName]
		if anchor == nil then
			warn(
				string.format(
					"[VFXEngine.OrbitController] Missing anchor '%s' for Orbit '%s'.",
					baseName,
					spec.id
				)
			)
			continue
		end

		local tilt = spec.tiltDegrees or Vector3.zero
		local tiltCF = CFrame.Angles(math.rad(tilt.X), math.rad(tilt.Y), math.rad(tilt.Z))
		local planeNormal = tiltCF.UpVector

		table.insert(states, {
			spec = spec,
			group = spec.group or "default",
			anchor = anchor,
			topAnchor = rig.anchors[baseName .. "_Top"],
			bottomAnchor = rig.anchors[baseName .. "_Bottom"],
			tiltCF = tiltCF,
			planeNormal = planeNormal,
			angle = spec.phaseOffset or 0,
			baseRadius = spec.radius * scale,
			baseHeight = (spec.heightOffset or 0) * scale,
			halfWidth = (if spec.trailHalfWidth ~= nil then spec.trailHalfWidth else 0.35) * scale,
			radiusPulseAmp = (spec.radiusPulseAmp or 0) * scale,
			radiusPulseFreq = spec.radiusPulseFreq or 0,
			verticalBobAmp = (spec.verticalBobAmp or 0) * scale,
			verticalBobFreq = spec.verticalBobFreq or 0,
		})
	end

	return states
end

local function updateOrbitTransform(
	state: OrbitState,
	elapsed: number,
	dt: number,
	speedMult: number,
	radiusMult: number
)
	state.angle += state.spec.angularSpeed * speedMult * dt

	local radius = state.baseRadius * radiusMult
	if state.radiusPulseAmp ~= 0 and state.radiusPulseFreq ~= 0 then
		radius += math.sin(elapsed * state.radiusPulseFreq * TWO_PI) * state.radiusPulseAmp
	end

	local height = state.baseHeight
	if state.verticalBobAmp ~= 0 and state.verticalBobFreq ~= 0 then
		height += math.sin(elapsed * state.verticalBobFreq * TWO_PI) * state.verticalBobAmp
	end

	local cosA = math.cos(state.angle)
	local sinA = math.sin(state.angle)
	local localPos = Vector3.new(cosA * radius, height, sinA * radius)
	local hrpLocalPos = state.tiltCF:VectorToWorldSpace(localPos)

	state.anchor.CFrame = CFrame.new(hrpLocalPos) * state.tiltCF * CFrame.Angles(0, -state.angle, 0)

	if state.topAnchor ~= nil then
		state.topAnchor.Position = hrpLocalPos + state.planeNormal * state.halfWidth
	end
	if state.bottomAnchor ~= nil then
		state.bottomAnchor.Position = hrpLocalPos - state.planeNormal * state.halfWidth
	end
end

function OrbitController.PositionInitialAnchors(
	rig: Types.RigContext,
	orbitSpecs: { Types.OrbitSpec }?
)
	local states = buildOrbitStates(rig, orbitSpecs)
	for _, state in ipairs(states) do
		updateOrbitTransform(state, 0, 0, 1, 1)
	end
end

function OrbitController.New(
	rig: Types.RigContext,
	orbitSpecs: { Types.OrbitSpec }?,
	registry: Types.InstanceRegistry
): Types.OrbitControllerHandle
	local orbitStates = buildOrbitStates(rig, orbitSpecs)
	local lightMetas = registry.lights
	local lightMetaById = registry.lightMetaById

	local groupSpeedMultipliers: { [string]: number } = {}
	local groupRadiusMultipliers: { [string]: number } = {}
	local flashStates: { [PointLight]: FlashState } = {}

	local elapsed = 0
	local destroyed = false
	local connection: RBXScriptConnection? = nil

	local function stepInternal(dt: number)
		if destroyed then
			return
		end

		elapsed += dt

		for _, state in ipairs(orbitStates) do
			local speedMult = groupSpeedMultipliers[state.group] or 1
			local radiusMult = groupRadiusMultipliers[state.group] or 1
			updateOrbitTransform(state, elapsed, dt, speedMult, radiusMult)
		end

		for _, lightMeta in ipairs(lightMetas) do
			local light = lightMeta.instance
			if light.Parent == nil then
				continue
			end

			local brightness = lightMeta.baseBrightness
			local range = lightMeta.baseRange

			local pulse = lightMeta.pulse
			if pulse ~= nil then
				local phase = pulse.phaseOffset or 0
				local wave = math.sin(elapsed * pulse.frequency * TWO_PI + phase)
				brightness += wave * pulse.amplitude
				if pulse.rangeAmplitude ~= nil then
					range += wave * pulse.rangeAmplitude * rig.scale
				end
			end

			local flash = flashStates[light]
			if flash ~= nil then
				flash.remaining -= dt
				if flash.remaining <= 0 then
					flashStates[light] = nil
				else
					local ratio = flash.remaining / flash.duration
					local ease = ratio * ratio
					brightness += flash.addBrightness * ease
					range += flash.addRange * ease
				end
			end

			light.Brightness = math.max(0, brightness)
			light.Range = math.clamp(range, 0, MAX_LIGHT_RANGE)
		end
	end

	local handle: Types.OrbitControllerHandle = {
		Step = function(_self: Types.OrbitControllerHandle, dt: number)
			stepInternal(dt)
		end,

		SetGroupSpeedMultiplier = function(_self: Types.OrbitControllerHandle, group: string, multiplier: number)
			groupSpeedMultipliers[group] = multiplier
		end,

		SetGroupRadiusMultiplier = function(_self: Types.OrbitControllerHandle, group: string, multiplier: number)
			groupRadiusMultipliers[group] = multiplier
		end,

		TriggerLightFlash = function(
			_self: Types.OrbitControllerHandle,
			lightId: string,
			peakBrightness: number?,
			peakRange: number?,
			duration: number?
		)
			local meta = lightMetaById[lightId]
			if meta == nil then
				warn(string.format("[VFXEngine.OrbitController] Unknown lightId '%s' for FlashLight.", lightId))
				return
			end

			local dur = math.max(0.05, if duration ~= nil then duration else 0.35)
			local targetB = if peakBrightness ~= nil then peakBrightness else meta.baseBrightness * 3
			local targetR = math.clamp(
				if peakRange ~= nil then peakRange * rig.scale else meta.baseRange * 1.5,
				0,
				MAX_LIGHT_RANGE
			)

			flashStates[meta.instance] = {
				remaining = dur,
				duration = dur,
				addBrightness = targetB - meta.baseBrightness,
				addRange = targetR - meta.baseRange,
			}
		end,

		Destroy = function(_self: Types.OrbitControllerHandle)
			if destroyed then
				return
			end
			destroyed = true
			if connection ~= nil then
				connection:Disconnect()
				connection = nil
			end
			table.clear(orbitStates)
			table.clear(flashStates)
			table.clear(groupSpeedMultipliers)
			table.clear(groupRadiusMultipliers)
		end,
	}

	stepInternal(0)
	connection = RunService.Heartbeat:Connect(stepInternal)

	return handle
end

return OrbitController
