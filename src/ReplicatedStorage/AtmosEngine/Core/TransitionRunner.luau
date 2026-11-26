--!strict

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Types = require(script.Parent.Types)

local TransitionRunner = {}

local generation = 0
local activeConnection: RBXScriptConnection? = nil
local isTransitioningClock = false

local function lerpNumber(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function lerpClockTime(a: number, b: number, t: number): number
	local diff = ((b - a + 12) % 24) - 12
	return (a + diff * t) % 24
end

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

type NumberTrack = {
	from: number,
	to: number,
	apply: (value: number) -> (),
	isClock: boolean?,
}

type ColorTrack = {
	from: Color3,
	to: Color3,
	apply: (value: Color3) -> (),
}

local function addNumberTrack(
	tracks: { NumberTrack },
	current: number,
	target: number?,
	apply: (value: number) -> (),
	isClock: boolean?
)
	if target ~= nil then
		table.insert(tracks, {
			from = current,
			to = target,
			apply = apply,
			isClock = isClock,
		})
	end
end

local function addColorTrack(
	tracks: { ColorTrack },
	current: Color3,
	target: Color3?,
	apply: (value: Color3) -> ()
)
	if target ~= nil then
		table.insert(tracks, {
			from = current,
			to = target,
			apply = apply,
		})
	end
end

function TransitionRunner.Cancel()
	generation += 1
	isTransitioningClock = false
	if activeConnection ~= nil then
		activeConnection:Disconnect()
		activeConnection = nil
	end
end

function TransitionRunner.IsTransitioningClockTime(): boolean
	return isTransitioningClock
end

function TransitionRunner.GetGeneration(): number
	return generation
end

function TransitionRunner.Run(
	target: Types.TransitionTarget,
	managed: Types.ManagedInstances,
	duration: number,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?,
	onComplete: (() -> ())?
)
	TransitionRunner.Cancel()
	local myGen = generation

	local numberTracks: { NumberTrack } = {}
	local colorTracks: { ColorTrack } = {}
	local touchesClock = false

	-- Lighting tracks
	local l = target.lighting
	if l ~= nil then
		if l.GlobalShadows ~= nil then
			Lighting.GlobalShadows = l.GlobalShadows
		end
		if l.ClockTime ~= nil then
			touchesClock = true
		end
		addNumberTrack(numberTracks, Lighting.ClockTime, l.ClockTime, function(v: number)
			Lighting.ClockTime = v
		end, true)
		addNumberTrack(numberTracks, Lighting.Brightness, l.Brightness, function(v: number)
			Lighting.Brightness = v
		end)
		addColorTrack(colorTracks, Lighting.Ambient, l.Ambient, function(v: Color3)
			Lighting.Ambient = v
		end)
		addColorTrack(colorTracks, Lighting.OutdoorAmbient, l.OutdoorAmbient, function(v: Color3)
			Lighting.OutdoorAmbient = v
		end)
		addColorTrack(colorTracks, Lighting.ColorShift_Top, l.ColorShift_Top, function(v: Color3)
			Lighting.ColorShift_Top = v
		end)
		addColorTrack(colorTracks, Lighting.ColorShift_Bottom, l.ColorShift_Bottom, function(v: Color3)
			Lighting.ColorShift_Bottom = v
		end)
		addNumberTrack(
			numberTracks,
			Lighting.EnvironmentDiffuseScale,
			l.EnvironmentDiffuseScale,
			function(v: number)
				Lighting.EnvironmentDiffuseScale = v
			end
		)
		addNumberTrack(
			numberTracks,
			Lighting.EnvironmentSpecularScale,
			l.EnvironmentSpecularScale,
			function(v: number)
				Lighting.EnvironmentSpecularScale = v
			end
		)
		addNumberTrack(numberTracks, Lighting.ExposureCompensation, l.ExposureCompensation, function(v: number)
			Lighting.ExposureCompensation = v
		end)
		addNumberTrack(numberTracks, Lighting.GeographicLatitude, l.GeographicLatitude, function(v: number)
			Lighting.GeographicLatitude = v
		end)
		addNumberTrack(numberTracks, Lighting.ShadowSoftness, l.ShadowSoftness, function(v: number)
			Lighting.ShadowSoftness = v
		end)
		addColorTrack(colorTracks, Lighting.FogColor, l.FogColor, function(v: Color3)
			Lighting.FogColor = v
		end)
		addNumberTrack(numberTracks, Lighting.FogStart, l.FogStart, function(v: number)
			Lighting.FogStart = v
		end)
		addNumberTrack(numberTracks, Lighting.FogEnd, l.FogEnd, function(v: number)
			Lighting.FogEnd = v
		end)
	end

	-- Atmosphere tracks
	local atmo = managed.atmosphere
	local atmoSpec = target.atmosphere
	if atmo ~= nil and atmo.Parent ~= nil and atmoSpec ~= nil then
		addNumberTrack(numberTracks, atmo.Density, atmoSpec.Density, function(v: number)
			atmo.Density = v
		end)
		addNumberTrack(numberTracks, atmo.Offset, atmoSpec.Offset, function(v: number)
			atmo.Offset = v
		end)
		addColorTrack(colorTracks, atmo.Color, atmoSpec.Color, function(v: Color3)
			atmo.Color = v
		end)
		addColorTrack(colorTracks, atmo.Decay, atmoSpec.Decay, function(v: Color3)
			atmo.Decay = v
		end)
		addNumberTrack(numberTracks, atmo.Glare, atmoSpec.Glare, function(v: number)
			atmo.Glare = v
		end)
		addNumberTrack(numberTracks, atmo.Haze, atmoSpec.Haze, function(v: number)
			atmo.Haze = v
		end)
	end

	-- Bloom tracks
	local bloom = managed.bloom
	local bloomSpec = target.bloom
	if bloom ~= nil and bloom.Parent ~= nil and bloomSpec ~= nil then
		if bloomSpec.Enabled ~= nil then
			bloom.Enabled = bloomSpec.Enabled
		end
		addNumberTrack(numberTracks, bloom.Intensity, bloomSpec.Intensity, function(v: number)
			bloom.Intensity = v
		end)
		addNumberTrack(numberTracks, bloom.Size, bloomSpec.Size, function(v: number)
			bloom.Size = v
		end)
		addNumberTrack(numberTracks, bloom.Threshold, bloomSpec.Threshold, function(v: number)
			bloom.Threshold = v
		end)
	end

	-- ColorCorrection tracks
	local cc = managed.colorCorrection
	local ccSpec = target.colorCorrection
	if cc ~= nil and cc.Parent ~= nil and ccSpec ~= nil then
		if ccSpec.Enabled ~= nil then
			cc.Enabled = ccSpec.Enabled
		end
		addNumberTrack(numberTracks, cc.Brightness, ccSpec.Brightness, function(v: number)
			cc.Brightness = v
		end)
		addNumberTrack(numberTracks, cc.Contrast, ccSpec.Contrast, function(v: number)
			cc.Contrast = v
		end)
		addNumberTrack(numberTracks, cc.Saturation, ccSpec.Saturation, function(v: number)
			cc.Saturation = v
		end)
		addColorTrack(colorTracks, cc.TintColor, ccSpec.TintColor, function(v: Color3)
			cc.TintColor = v
		end)
	end

	-- DepthOfField tracks
	local dof = managed.depthOfField
	local dofSpec = target.depthOfField
	if dof ~= nil and dof.Parent ~= nil and dofSpec ~= nil then
		if dofSpec.Enabled ~= nil then
			dof.Enabled = dofSpec.Enabled
		end
		addNumberTrack(numberTracks, dof.FarIntensity, dofSpec.FarIntensity, function(v: number)
			dof.FarIntensity = v
		end)
		addNumberTrack(numberTracks, dof.FocusDistance, dofSpec.FocusDistance, function(v: number)
			dof.FocusDistance = v
		end)
		addNumberTrack(numberTracks, dof.InFocusRadius, dofSpec.InFocusRadius, function(v: number)
			dof.InFocusRadius = v
		end)
		addNumberTrack(numberTracks, dof.NearIntensity, dofSpec.NearIntensity, function(v: number)
			dof.NearIntensity = v
		end)
	end

	-- SunRays tracks
	local sunRays = managed.sunRays
	local sunRaysSpec = target.sunRays
	if sunRays ~= nil and sunRays.Parent ~= nil and sunRaysSpec ~= nil then
		if sunRaysSpec.Enabled ~= nil then
			sunRays.Enabled = sunRaysSpec.Enabled
		end
		addNumberTrack(numberTracks, sunRays.Intensity, sunRaysSpec.Intensity, function(v: number)
			sunRays.Intensity = v
		end)
		addNumberTrack(numberTracks, sunRays.Spread, sunRaysSpec.Spread, function(v: number)
			sunRays.Spread = v
		end)
	end

	local function applyAtAlpha(easedAlpha: number)
		for _, track in ipairs(numberTracks) do
			local val = if track.isClock
				then lerpClockTime(track.from, track.to, easedAlpha)
				else lerpNumber(track.from, track.to, easedAlpha)
			track.apply(val)
		end
		for _, track in ipairs(colorTracks) do
			track.apply(lerpColor(track.from, track.to, easedAlpha))
		end
	end

	if duration <= 0 or (#numberTracks == 0 and #colorTracks == 0) then
		applyAtAlpha(1)
		if generation == myGen and onComplete ~= nil then
			onComplete()
		end
		return
	end

	local style = easingStyle or Enum.EasingStyle.Sine
	local dir = easingDirection or Enum.EasingDirection.InOut
	local elapsed = 0
	isTransitioningClock = touchesClock

	activeConnection = RunService.Heartbeat:Connect(function(dt: number)
		if generation ~= myGen then
			if activeConnection ~= nil then
				activeConnection:Disconnect()
				activeConnection = nil
			end
			return
		end

		elapsed += dt
		local linearAlpha = math.clamp(elapsed / duration, 0, 1)
		local easedAlpha = TweenService:GetValue(linearAlpha, style, dir)
		applyAtAlpha(easedAlpha)

		if linearAlpha >= 1 then
			isTransitioningClock = false
			if activeConnection ~= nil then
				activeConnection:Disconnect()
				activeConnection = nil
			end
			if generation == myGen and onComplete ~= nil then
				onComplete()
			end
		end
	end)
end

return TransitionRunner
