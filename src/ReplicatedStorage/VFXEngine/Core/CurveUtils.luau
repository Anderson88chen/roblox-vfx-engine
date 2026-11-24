--!strict

local Types = require(script.Parent.Types)

local CurveUtils = {}

local MAX_KEYPOINTS = 20
local MIN_KEYPOINTS = 2
local DEFAULT_SAMPLES = 12
local BEZIER_SEARCH_ITERATIONS = 16

local function clampValue(value: number, clampMin: number?, clampMax: number?): number
	local result = value
	if clampMin ~= nil and result < clampMin then
		result = clampMin
	end
	if clampMax ~= nil and result > clampMax then
		result = clampMax
	end
	return result
end

local function evalCubic(p0: number, p1: number, p2: number, p3: number, t: number): number
	local u = 1 - t
	return (u * u * u * p0)
		+ (3 * u * u * t * p1)
		+ (3 * u * t * t * p2)
		+ (t * t * t * p3)
end

local function solveBezierTForX(cx1: number, cx2: number, targetX: number): number
	if targetX <= 0 then
		return 0
	end
	if targetX >= 1 then
		return 1
	end

	local low = 0
	local high = 1
	local mid = targetX
	for _ = 1, BEZIER_SEARCH_ITERATIONS do
		mid = 0.5 * (low + high)
		local x = evalCubic(0, cx1, cx2, 1, mid)
		if x < targetX then
			low = mid
		else
			high = mid
		end
	end
	return mid
end

local function smoothstep(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

local function evalPiecewiseSmooth(points: { { number } }, t: number): number
	local count = #points
	if count == 0 then
		return 0
	end
	if t <= points[1][1] then
		return points[1][2]
	end
	if t >= points[count][1] then
		return points[count][2]
	end

	for i = 1, count - 1 do
		local t0 = points[i][1]
		local v0 = points[i][2]
		local t1 = points[i + 1][1]
		local v1 = points[i + 1][2]
		if t >= t0 and t <= t1 then
			local span = t1 - t0
			if span <= 1e-6 then
				return v1
			end
			local alpha = (t - t0) / span
			local mu = 0.5 * (1 - math.cos(alpha * math.pi))
			return v0 + (v1 - v0) * mu
		end
	end
	return points[count][2]
end

local PULSE_KEYS: { { number } } = {
	{ 0, 0 },
	{ 0.2, 1 },
	{ 0.5, 0.35 },
	{ 0.75, 0.9 },
	{ 1, 0 },
}

local SHRINK_OUT_KEYS: { { number } } = {
	{ 0, 1 },
	{ 0.55, 0.95 },
	{ 1, 0 },
}

local POP_AND_FADE_KEYS: { { number } } = {
	{ 0, 0 },
	{ 0.15, 1.15 },
	{ 0.35, 0.95 },
	{ 1, 0 },
}

local function evalPresetCurve(name: Types.PresetCurveName, t: number): number
	if name == "Linear" then
		return t
	elseif name == "EaseIn" then
		return t * t
	elseif name == "EaseOut" then
		local inv = 1 - t
		return 1 - inv * inv
	elseif name == "EaseInOut" then
		return smoothstep(t)
	elseif name == "Bell" then
		return math.sin(math.pi * t)
	elseif name == "FadeInOut" then
		if t < 0.15 then
			return 1 - smoothstep(t / 0.15)
		elseif t > 0.75 then
			return smoothstep((t - 0.75) / 0.25)
		end
		return 0
	elseif name == "SharpDecay" then
		return math.exp(-5.0 * t) * (1 - t)
	elseif name == "Pulse" then
		return evalPiecewiseSmooth(PULSE_KEYS, t)
	elseif name == "ShrinkOut" then
		return evalPiecewiseSmooth(SHRINK_OUT_KEYS, t)
	elseif name == "PopAndFade" then
		return evalPiecewiseSmooth(POP_AND_FADE_KEYS, t)
	end
	return t
end

local function normalizeNumberKeypoints(
	rawKeypoints: { NumberSequenceKeypoint },
	clampMin: number?,
	clampMax: number?,
	extraScale: number?
): NumberSequence
	local scale = if extraScale ~= nil then extraScale else 1
	local sorted = table.clone(rawKeypoints)
	table.sort(sorted, function(a: NumberSequenceKeypoint, b: NumberSequenceKeypoint): boolean
		return a.Time < b.Time
	end)

	if #sorted == 0 then
		local fallback = clampValue(1 * scale, clampMin, clampMax)
		return NumberSequence.new(fallback)
	end

	-- Downsample to <= 20 keypoints while preserving exact endpoints
	if #sorted > MAX_KEYPOINTS then
		local reduced: { NumberSequenceKeypoint } = table.create(MAX_KEYPOINTS)
		local total = #sorted
		for i = 1, MAX_KEYPOINTS do
			local idx = if i == 1
				then 1
				elseif i == MAX_KEYPOINTS then total
				else math.clamp(math.floor(1 + (i - 1) * (total - 1) / (MAX_KEYPOINTS - 1) + 0.5), 2, total - 1)
			table.insert(reduced, sorted[idx])
		end
		sorted = reduced
	end

	-- Ensure start (Time = 0) and end (Time = 1)
	local sanitized: { NumberSequenceKeypoint } = {}
	local lastTime = 0
	for i, kp in ipairs(sorted) do
		local t = math.clamp(kp.Time, 0, 1)
		if i == 1 then
			t = 0
		elseif i == #sorted then
			t = 1
		elseif t < lastTime then
			t = lastTime
		end
		lastTime = t

		local val = clampValue(kp.Value * scale, clampMin, clampMax)
		local env = math.max(0, kp.Envelope * math.abs(scale))
		table.insert(sanitized, NumberSequenceKeypoint.new(t, val, env))
	end

	if #sanitized == 1 then
		local only = sanitized[1]
		sanitized = {
			NumberSequenceKeypoint.new(0, only.Value, only.Envelope),
			NumberSequenceKeypoint.new(1, only.Value, only.Envelope),
		}
	elseif sanitized[1].Time > 0 then
		local first = sanitized[1]
		table.insert(sanitized, 1, NumberSequenceKeypoint.new(0, first.Value, first.Envelope))
	end

	if sanitized[#sanitized].Time < 1 then
		local last = sanitized[#sanitized]
		table.insert(sanitized, NumberSequenceKeypoint.new(1, last.Value, last.Envelope))
	end

	-- Safety cap after endpoint insertion
	if #sanitized > MAX_KEYPOINTS then
		table.remove(sanitized, #sanitized - 1)
	end

	return NumberSequence.new(sanitized)
end

function CurveUtils.CubicBezierToNumberSequence(
	spec: Types.BezierCurveSpec,
	clampMin: number?,
	clampMax: number?
): NumberSequence
	local samples = math.clamp(math.floor((spec.samples or DEFAULT_SAMPLES) + 0.5), MIN_KEYPOINTS, MAX_KEYPOINTS)
	local cx1 = math.clamp(spec.cx1, 0, 1)
	local cx2 = math.clamp(spec.cx2, 0, 1)
	local scale = if spec.scale ~= nil then spec.scale else 1
	local envelope = math.max(0, spec.envelope or 0)

	local keypoints: { NumberSequenceKeypoint } = table.create(samples)
	for i = 1, samples do
		local u = if i == 1 then 0 elseif i == samples then 1 else (i - 1) / (samples - 1)
		local t = solveBezierTForX(cx1, cx2, u)
		local y = evalCubic(spec.y0, spec.cy1, spec.cy2, spec.y3, t) * scale
		local clamped = clampValue(y, clampMin, clampMax)
		table.insert(keypoints, NumberSequenceKeypoint.new(u, clamped, envelope))
	end

	return NumberSequence.new(keypoints)
end

function CurveUtils.ResolveNumberSequence(
	spec: Types.NumberCurveSpec?,
	defaultValue: number?,
	clampMin: number?,
	clampMax: number?,
	valueScale: number?
): NumberSequence
	local scale = if valueScale ~= nil then valueScale else 1
	local fallback = if defaultValue ~= nil then defaultValue else 1

	if spec == nil then
		local val = clampValue(fallback * scale, clampMin, clampMax)
		return NumberSequence.new(val)
	end

	if typeof(spec) == "number" then
		local val = clampValue(spec * scale, clampMin, clampMax)
		return NumberSequence.new(val)
	end

	if typeof(spec) == "NumberSequence" then
		return normalizeNumberKeypoints(spec.Keypoints, clampMin, clampMax, scale)
	end

	if type(spec) == "table" then
		local kind = (spec :: any).kind
		if kind == "Bezier" then
			local bezierSpec = spec :: Types.BezierCurveSpec
			local scaledBezier: Types.BezierCurveSpec = {
				kind = "Bezier",
				y0 = bezierSpec.y0,
				cx1 = bezierSpec.cx1,
				cy1 = bezierSpec.cy1,
				cx2 = bezierSpec.cx2,
				cy2 = bezierSpec.cy2,
				y3 = bezierSpec.y3,
				samples = bezierSpec.samples,
				envelope = if bezierSpec.envelope ~= nil
					then math.max(0, bezierSpec.envelope * math.abs(scale))
					else 0,
				scale = (if bezierSpec.scale ~= nil then bezierSpec.scale else 1) * scale,
			}
			return CurveUtils.CubicBezierToNumberSequence(scaledBezier, clampMin, clampMax)
		elseif kind == "Preset" then
			local presetSpec = spec :: Types.PresetCurveSpec
			local samples = math.clamp(
				math.floor((presetSpec.samples or DEFAULT_SAMPLES) + 0.5),
				MIN_KEYPOINTS,
				MAX_KEYPOINTS
			)
			local presetScale = (if presetSpec.scale ~= nil then presetSpec.scale else 1) * scale
			local envelope = math.max(0, (presetSpec.envelope or 0) * math.abs(scale))
			local invert = presetSpec.invert == true

			local keypoints: { NumberSequenceKeypoint } = table.create(samples)
			for i = 1, samples do
				local u = if i == 1 then 0 elseif i == samples then 1 else (i - 1) / (samples - 1)
				local raw = evalPresetCurve(presetSpec.name, u)
				local baseVal = if invert then (1 - raw) else raw
				local val = clampValue(baseVal * presetScale, clampMin, clampMax)
				table.insert(keypoints, NumberSequenceKeypoint.new(u, val, envelope))
			end
			return NumberSequence.new(keypoints)
		elseif kind == "Keypoints" then
			local kpSpec = spec :: Types.KeypointsSpec
			local rawKeypoints: { NumberSequenceKeypoint } = table.create(#kpSpec.points)
			for _, pt in ipairs(kpSpec.points) do
				table.insert(
					rawKeypoints,
					NumberSequenceKeypoint.new(math.clamp(pt.time, 0, 1), pt.value, math.max(0, pt.envelope or 0))
				)
			end
			return normalizeNumberKeypoints(rawKeypoints, clampMin, clampMax, scale)
		end
	end

	local val = clampValue(fallback * scale, clampMin, clampMax)
	return NumberSequence.new(val)
end

function CurveUtils.ResolveColorSequence(spec: Types.ColorCurveSpec?, defaultColor: Color3?): ColorSequence
	local fallback = defaultColor or Color3.new(1, 1, 1)
	if spec == nil then
		return ColorSequence.new(fallback)
	end

	if typeof(spec) == "Color3" then
		return ColorSequence.new(spec)
	end

	if typeof(spec) == "ColorSequence" then
		local keypoints = spec.Keypoints
		if #keypoints <= MAX_KEYPOINTS and #keypoints >= MIN_KEYPOINTS then
			return spec
		end
		local stops: { Types.ColorStop } = table.create(#keypoints)
		for _, kp in ipairs(keypoints) do
			table.insert(stops, { time = kp.Time, color = kp.Value })
		end
		return CurveUtils.ResolveColorSequence(stops, fallback)
	end

	if type(spec) == "table" then
		local inputStops = spec :: { Types.ColorStop }
		if #inputStops == 0 then
			return ColorSequence.new(fallback)
		end

		local stops = table.clone(inputStops)
		table.sort(stops, function(a: Types.ColorStop, b: Types.ColorStop): boolean
			return a.time < b.time
		end)

		if #stops > MAX_KEYPOINTS then
			local reduced: { Types.ColorStop } = table.create(MAX_KEYPOINTS)
			local total = #stops
			for i = 1, MAX_KEYPOINTS do
				local idx = if i == 1
					then 1
					elseif i == MAX_KEYPOINTS then total
					else math.clamp(math.floor(1 + (i - 1) * (total - 1) / (MAX_KEYPOINTS - 1) + 0.5), 2, total - 1)
				table.insert(reduced, stops[idx])
			end
			stops = reduced
		end

		local keypoints: { ColorSequenceKeypoint } = {}
		local lastTime = 0
		for i, stop in ipairs(stops) do
			local t = math.clamp(stop.time, 0, 1)
			if i == 1 then
				t = 0
			elseif i == #stops then
				t = 1
			elseif t < lastTime then
				t = lastTime
			end
			lastTime = t
			table.insert(keypoints, ColorSequenceKeypoint.new(t, stop.color))
		end

		if #keypoints == 1 then
			local only = keypoints[1]
			keypoints = {
				ColorSequenceKeypoint.new(0, only.Value),
				ColorSequenceKeypoint.new(1, only.Value),
			}
		end

		return ColorSequence.new(keypoints)
	end

	return ColorSequence.new(fallback)
end

function CurveUtils.ResolveNumberRange(
	spec: Types.NumberRangeSpec?,
	defaultMin: number,
	defaultMax: number?,
	valueScale: number?
): NumberRange
	local scale = if valueScale ~= nil then valueScale else 1
	local fallbackMax = if defaultMax ~= nil then defaultMax else defaultMin

	if spec == nil then
		local a = defaultMin * scale
		local b = fallbackMax * scale
		return NumberRange.new(math.min(a, b), math.max(a, b))
	end

	if typeof(spec) == "number" then
		local v = spec * scale
		return NumberRange.new(v, v)
	end

	if typeof(spec) == "NumberRange" then
		local a = spec.Min * scale
		local b = spec.Max * scale
		return NumberRange.new(math.min(a, b), math.max(a, b))
	end

	if type(spec) == "table" then
		local arr = spec :: { number }
		local first = arr[1]
		local second = arr[2]
		if first ~= nil and second ~= nil then
			local a = first * scale
			local b = second * scale
			return NumberRange.new(math.min(a, b), math.max(a, b))
		elseif first ~= nil then
			local v = first * scale
			return NumberRange.new(v, v)
		end
	end

	local a = defaultMin * scale
	local b = fallbackMax * scale
	return NumberRange.new(math.min(a, b), math.max(a, b))
end

return CurveUtils
