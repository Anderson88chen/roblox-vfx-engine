--!strict

local Types = require(script.Parent.Types)

local SpringSolver = {}

local TWO_PI = math.pi * 2
local MIN_FREQUENCY = 0.05
local MAX_DT = 0.1
local BASE_SUBSTEP = 1 / 120
local MAX_SUBSTEPS = 24

local function isFiniteNumber(v: number): boolean
	return v == v and v ~= math.huge and v ~= -math.huge
end

local function isFiniteVector3(v: Vector3): boolean
	return isFiniteNumber(v.X) and isFiniteNumber(v.Y) and isFiniteNumber(v.Z)
end

function SpringSolver.NewScalar(
	initialValue: number?,
	frequency: number?,
	dampingRatio: number?
): Types.ScalarSpring
	local initVal = if initialValue ~= nil and isFiniteNumber(initialValue) then initialValue else 0
	local freq = math.max(MIN_FREQUENCY, if frequency ~= nil and isFiniteNumber(frequency) then frequency else 4)
	local zeta = math.max(0, if dampingRatio ~= nil and isFiniteNumber(dampingRatio) then dampingRatio else 0.75)

	local value = initVal
	local target = initVal
	local velocity = 0

	local spring: Types.ScalarSpring = {
		Update = function(_self: Types.ScalarSpring, dt: number): number
			if not isFiniteNumber(dt) or dt <= 0 then
				return value
			end

			local clampedDt = math.min(dt, MAX_DT)
			local omega = TWO_PI * freq
			local maxStep = math.min(BASE_SUBSTEP, 0.25 / math.max(omega, 1))
			local steps = math.clamp(math.ceil(clampedDt / maxStep), 1, MAX_SUBSTEPS)
			local subDt = clampedDt / steps

			local omegaSq = omega * omega
			local twoZetaOmega = 2 * zeta * omega

			for _ = 1, steps do
				local accel = omegaSq * (target - value) - twoZetaOmega * velocity
				velocity += accel * subDt
				value += velocity * subDt
			end

			if not isFiniteNumber(value) or not isFiniteNumber(velocity) then
				value = target
				velocity = 0
			end

			return value
		end,

		SetTarget = function(_self: Types.ScalarSpring, newTarget: number)
			if isFiniteNumber(newTarget) then
				target = newTarget
			end
		end,

		Impulse = function(_self: Types.ScalarSpring, velocityDelta: number)
			if isFiniteNumber(velocityDelta) then
				velocity += velocityDelta
			end
		end,

		SetValue = function(_self: Types.ScalarSpring, newValue: number)
			if isFiniteNumber(newValue) then
				value = newValue
				velocity = 0
			end
		end,

		SetConfig = function(_self: Types.ScalarSpring, newFreq: number?, newZeta: number?)
			if newFreq ~= nil and isFiniteNumber(newFreq) then
				freq = math.max(MIN_FREQUENCY, newFreq)
			end
			if newZeta ~= nil and isFiniteNumber(newZeta) then
				zeta = math.max(0, newZeta)
			end
		end,

		GetValue = function(_self: Types.ScalarSpring): number
			return value
		end,

		GetVelocity = function(_self: Types.ScalarSpring): number
			return velocity
		end,

		GetTarget = function(_self: Types.ScalarSpring): number
			return target
		end,
	}

	return spring
end

function SpringSolver.NewVector3(
	initialValue: Vector3?,
	frequency: number?,
	dampingRatio: number?
): Types.Vector3Spring
	local initVal = if initialValue ~= nil and isFiniteVector3(initialValue) then initialValue else Vector3.zero
	local freq = math.max(MIN_FREQUENCY, if frequency ~= nil and isFiniteNumber(frequency) then frequency else 4)
	local zeta = math.max(0, if dampingRatio ~= nil and isFiniteNumber(dampingRatio) then dampingRatio else 0.75)

	local value = initVal
	local target = initVal
	local velocity = Vector3.zero

	local spring: Types.Vector3Spring = {
		Update = function(_self: Types.Vector3Spring, dt: number): Vector3
			if not isFiniteNumber(dt) or dt <= 0 then
				return value
			end

			local clampedDt = math.min(dt, MAX_DT)
			local omega = TWO_PI * freq
			local maxStep = math.min(BASE_SUBSTEP, 0.25 / math.max(omega, 1))
			local steps = math.clamp(math.ceil(clampedDt / maxStep), 1, MAX_SUBSTEPS)
			local subDt = clampedDt / steps

			local omegaSq = omega * omega
			local twoZetaOmega = 2 * zeta * omega

			for _ = 1, steps do
				local accel = (target - value) * omegaSq - velocity * twoZetaOmega
				velocity += accel * subDt
				value += velocity * subDt
			end

			if not isFiniteVector3(value) or not isFiniteVector3(velocity) then
				value = target
				velocity = Vector3.zero
			end

			return value
		end,

		SetTarget = function(_self: Types.Vector3Spring, newTarget: Vector3)
			if isFiniteVector3(newTarget) then
				target = newTarget
			end
		end,

		Impulse = function(_self: Types.Vector3Spring, velocityDelta: Vector3)
			if isFiniteVector3(velocityDelta) then
				velocity += velocityDelta
			end
		end,

		SetValue = function(_self: Types.Vector3Spring, newValue: Vector3)
			if isFiniteVector3(newValue) then
				value = newValue
				velocity = Vector3.zero
			end
		end,

		SetConfig = function(_self: Types.Vector3Spring, newFreq: number?, newZeta: number?)
			if newFreq ~= nil and isFiniteNumber(newFreq) then
				freq = math.max(MIN_FREQUENCY, newFreq)
			end
			if newZeta ~= nil and isFiniteNumber(newZeta) then
				zeta = math.max(0, newZeta)
			end
		end,

		GetValue = function(_self: Types.Vector3Spring): Vector3
			return value
		end,

		GetVelocity = function(_self: Types.Vector3Spring): Vector3
			return velocity
		end,

		GetTarget = function(_self: Types.Vector3Spring): Vector3
			return target
		end,
	}

	return spring
end

return SpringSolver
