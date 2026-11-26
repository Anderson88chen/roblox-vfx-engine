--!strict

local Lighting = game:GetService("Lighting")

local Types = require(script.Parent.Types)

local SnapshotManager = {}

local MANAGED_ATTR = "AtmosEngineManaged"
local MANAGED_NAMES = {
	atmosphere = "__AtmosEngine_Atmosphere",
	sky = "__AtmosEngine_Sky",
	bloom = "__AtmosEngine_Bloom",
	colorCorrection = "__AtmosEngine_ColorCorrection",
	depthOfField = "__AtmosEngine_DepthOfField",
	sunRays = "__AtmosEngine_SunRays",
}

local activeSnapshot: Types.SnapshotData? = nil
local managed: Types.ManagedInstances = {}

local function isManagedInstance(inst: Instance): boolean
	if inst:GetAttribute(MANAGED_ATTR) == true then
		return true
	end
	return string.sub(inst.Name, 1, 14) == "__AtmosEngine_"
end

local function readLightingSpec(): Types.LightingSpec
	return {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ColorShift_Top = Lighting.ColorShift_Top,
		ColorShift_Bottom = Lighting.ColorShift_Bottom,
		EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
		ExposureCompensation = Lighting.ExposureCompensation,
		GeographicLatitude = Lighting.GeographicLatitude,
		ShadowSoftness = Lighting.ShadowSoftness,
		GlobalShadows = Lighting.GlobalShadows,
		FogColor = Lighting.FogColor,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
	}
end

local function readAtmosphereSpec(inst: Atmosphere): Types.AtmosphereSpec
	return {
		Density = inst.Density,
		Offset = inst.Offset,
		Color = inst.Color,
		Decay = inst.Decay,
		Glare = inst.Glare,
		Haze = inst.Haze,
	}
end

local function readSkySpec(inst: Sky): Types.SkySpec
	return {
		CelestialBodiesShown = inst.CelestialBodiesShown,
		MoonAngularSize = inst.MoonAngularSize,
		SunAngularSize = inst.SunAngularSize,
		StarCount = inst.StarCount,
		SkyboxBk = inst.SkyboxBk,
		SkyboxDn = inst.SkyboxDn,
		SkyboxFt = inst.SkyboxFt,
		SkyboxLf = inst.SkyboxLf,
		SkyboxRt = inst.SkyboxRt,
		SkyboxUp = inst.SkyboxUp,
		MoonTextureId = inst.MoonTextureId,
		SunTextureId = inst.SunTextureId,
	}
end

local function readBloomSpec(inst: BloomEffect): Types.BloomSpec
	return {
		Enabled = inst.Enabled,
		Intensity = inst.Intensity,
		Size = inst.Size,
		Threshold = inst.Threshold,
	}
end

local function readColorCorrectionSpec(inst: ColorCorrectionEffect): Types.ColorCorrectionSpec
	return {
		Enabled = inst.Enabled,
		Brightness = inst.Brightness,
		Contrast = inst.Contrast,
		Saturation = inst.Saturation,
		TintColor = inst.TintColor,
	}
end

local function readDepthOfFieldSpec(inst: DepthOfFieldEffect): Types.DepthOfFieldSpec
	return {
		Enabled = inst.Enabled,
		FarIntensity = inst.FarIntensity,
		FocusDistance = inst.FocusDistance,
		InFocusRadius = inst.InFocusRadius,
		NearIntensity = inst.NearIntensity,
	}
end

local function readSunRaysSpec(inst: SunRaysEffect): Types.SunRaysSpec
	return {
		Enabled = inst.Enabled,
		Intensity = inst.Intensity,
		Spread = inst.Spread,
	}
end

function SnapshotManager.IsManaged(inst: Instance): boolean
	return isManagedInstance(inst)
end

function SnapshotManager.GetSnapshot(): Types.SnapshotData?
	return activeSnapshot
end

function SnapshotManager.GetManaged(): Types.ManagedInstances
	return managed
end

function SnapshotManager.HasManagedInstances(): boolean
	return managed.atmosphere ~= nil
		or managed.sky ~= nil
		or managed.bloom ~= nil
		or managed.colorCorrection ~= nil
		or managed.depthOfField ~= nil
		or managed.sunRays ~= nil
end

function SnapshotManager.RestoreUnmanaged()
	local snap = activeSnapshot
	if snap == nil then
		return
	end

	for _, record in ipairs(snap.unmanagedEffects) do
		local inst = record.instance
		if inst:IsA("Atmosphere") or inst:IsA("Sky") then
			if record.originalParent ~= nil and inst.Parent ~= record.originalParent then
				pcall(function()
					inst.Parent = record.originalParent
				end)
			end
		elseif
			inst:IsA("BloomEffect")
			or inst:IsA("ColorCorrectionEffect")
			or inst:IsA("DepthOfFieldEffect")
			or inst:IsA("SunRaysEffect")
		then
			if inst.Parent ~= nil and record.wasEnabled ~= nil then
				(inst :: PostEffect).Enabled = record.wasEnabled
			end
		end
	end
end

function SnapshotManager.SuspendUnmanaged()
	local snap = activeSnapshot
	if snap == nil then
		return
	end

	for _, record in ipairs(snap.unmanagedEffects) do
		local inst = record.instance
		if inst:IsA("Atmosphere") or inst:IsA("Sky") then
			if inst.Parent == Lighting then
				inst.Parent = nil
			end
		elseif
			inst:IsA("BloomEffect")
			or inst:IsA("ColorCorrectionEffect")
			or inst:IsA("DepthOfFieldEffect")
			or inst:IsA("SunRaysEffect")
		then
			if inst.Parent ~= nil then
				(inst :: PostEffect).Enabled = false
			end
		end
	end
end

function SnapshotManager.CaptureSnapshot(): Types.SnapshotData
	-- If managed instances are currently active, temporarily restore unmanaged ones so capture sees the true baseline
	local hadManaged = SnapshotManager.HasManagedInstances()
	if hadManaged and activeSnapshot ~= nil then
		SnapshotManager.RestoreUnmanaged()
	end

	local snapshot: Types.SnapshotData = {
		capturedAt = os.clock(),
		lighting = readLightingSpec(),
		atmosphere = nil,
		sky = nil,
		bloom = nil,
		colorCorrection = nil,
		depthOfField = nil,
		sunRays = nil,
		unmanagedEffects = {},
	}

	for _, child in ipairs(Lighting:GetChildren()) do
		if not isManagedInstance(child) then
			if child:IsA("Atmosphere") then
				if snapshot.atmosphere == nil then
					snapshot.atmosphere = readAtmosphereSpec(child)
				end
				table.insert(snapshot.unmanagedEffects, {
					instance = child,
					originalParent = child.Parent,
				})
			elseif child:IsA("Sky") then
				if snapshot.sky == nil then
					snapshot.sky = readSkySpec(child)
				end
				table.insert(snapshot.unmanagedEffects, {
					instance = child,
					originalParent = child.Parent,
				})
			elseif child:IsA("BloomEffect") then
				if snapshot.bloom == nil and child.Enabled then
					snapshot.bloom = readBloomSpec(child)
				end
				table.insert(snapshot.unmanagedEffects, {
					instance = child,
					wasEnabled = child.Enabled,
				})
			elseif child:IsA("ColorCorrectionEffect") then
				if snapshot.colorCorrection == nil and child.Enabled then
					snapshot.colorCorrection = readColorCorrectionSpec(child)
				end
				table.insert(snapshot.unmanagedEffects, {
					instance = child,
					wasEnabled = child.Enabled,
				})
			elseif child:IsA("DepthOfFieldEffect") then
				if snapshot.depthOfField == nil and child.Enabled then
					snapshot.depthOfField = readDepthOfFieldSpec(child)
				end
				table.insert(snapshot.unmanagedEffects, {
					instance = child,
					wasEnabled = child.Enabled,
				})
			elseif child:IsA("SunRaysEffect") then
				if snapshot.sunRays == nil and child.Enabled then
					snapshot.sunRays = readSunRaysSpec(child)
				end
				table.insert(snapshot.unmanagedEffects, {
					instance = child,
					wasEnabled = child.Enabled,
				})
			end
		end
	end

	activeSnapshot = snapshot

	if hadManaged then
		SnapshotManager.SuspendUnmanaged()
	end

	return snapshot
end

function SnapshotManager.EnsureSnapshot(): Types.SnapshotData
	if activeSnapshot ~= nil then
		return activeSnapshot
	end
	return SnapshotManager.CaptureSnapshot()
end

local function createManagedAtmosphere(initial: Types.AtmosphereSpec?): Atmosphere
	local inst = Instance.new("Atmosphere")
	inst.Name = MANAGED_NAMES.atmosphere
	inst:SetAttribute(MANAGED_ATTR, true)
	if initial ~= nil then
		inst.Density = initial.Density or 0
		inst.Offset = initial.Offset or 0
		inst.Color = initial.Color or Color3.fromRGB(199, 199, 199)
		inst.Decay = initial.Decay or Color3.fromRGB(106, 112, 125)
		inst.Glare = initial.Glare or 0
		inst.Haze = initial.Haze or 0
	else
		inst.Density = 0
		inst.Offset = 0
		inst.Glare = 0
		inst.Haze = 0
	end
	inst.Parent = Lighting
	return inst
end

local function createManagedSky(): Sky
	local inst = Instance.new("Sky")
	inst.Name = MANAGED_NAMES.sky
	inst:SetAttribute(MANAGED_ATTR, true)
	inst.Parent = Lighting
	return inst
end

local function createManagedBloom(initial: Types.BloomSpec?): BloomEffect
	local inst = Instance.new("BloomEffect")
	inst.Name = MANAGED_NAMES.bloom
	inst:SetAttribute(MANAGED_ATTR, true)
	if initial ~= nil then
		inst.Enabled = if initial.Enabled ~= nil then initial.Enabled else true
		inst.Intensity = initial.Intensity or 0
		inst.Size = initial.Size or 24
		inst.Threshold = initial.Threshold or 2
	else
		inst.Enabled = true
		inst.Intensity = 0
		inst.Size = 24
		inst.Threshold = 2
	end
	inst.Parent = Lighting
	return inst
end

local function createManagedColorCorrection(initial: Types.ColorCorrectionSpec?): ColorCorrectionEffect
	local inst = Instance.new("ColorCorrectionEffect")
	inst.Name = MANAGED_NAMES.colorCorrection
	inst:SetAttribute(MANAGED_ATTR, true)
	if initial ~= nil then
		inst.Enabled = if initial.Enabled ~= nil then initial.Enabled else true
		inst.Brightness = initial.Brightness or 0
		inst.Contrast = initial.Contrast or 0
		inst.Saturation = initial.Saturation or 0
		inst.TintColor = initial.TintColor or Color3.new(1, 1, 1)
	else
		inst.Enabled = true
		inst.Brightness = 0
		inst.Contrast = 0
		inst.Saturation = 0
		inst.TintColor = Color3.new(1, 1, 1)
	end
	inst.Parent = Lighting
	return inst
end

local function createManagedDepthOfField(initial: Types.DepthOfFieldSpec?): DepthOfFieldEffect
	local inst = Instance.new("DepthOfFieldEffect")
	inst.Name = MANAGED_NAMES.depthOfField
	inst:SetAttribute(MANAGED_ATTR, true)
	if initial ~= nil then
		inst.Enabled = if initial.Enabled ~= nil then initial.Enabled else true
		inst.FarIntensity = initial.FarIntensity or 0
		inst.FocusDistance = initial.FocusDistance or 0.05
		inst.InFocusRadius = initial.InFocusRadius or 30
		inst.NearIntensity = initial.NearIntensity or 0
	else
		inst.Enabled = true
		inst.FarIntensity = 0
		inst.FocusDistance = 0.05
		inst.InFocusRadius = 30
		inst.NearIntensity = 0
	end
	inst.Parent = Lighting
	return inst
end

local function createManagedSunRays(initial: Types.SunRaysSpec?): SunRaysEffect
	local inst = Instance.new("SunRaysEffect")
	inst.Name = MANAGED_NAMES.sunRays
	inst:SetAttribute(MANAGED_ATTR, true)
	if initial ~= nil then
		inst.Enabled = if initial.Enabled ~= nil then initial.Enabled else true
		inst.Intensity = initial.Intensity or 0
		inst.Spread = initial.Spread or 1
	else
		inst.Enabled = true
		inst.Intensity = 0
		inst.Spread = 1
	end
	inst.Parent = Lighting
	return inst
end

function SnapshotManager.ApplySkySpec(spec: Types.SkySpec?)
	local snap = SnapshotManager.EnsureSnapshot()

	if spec == nil then
		if managed.sky ~= nil then
			managed.sky:Destroy()
			managed.sky = nil
		end
		-- Restore original unmanaged Sky if present since preset doesn't override Sky
		for _, record in ipairs(snap.unmanagedEffects) do
			if record.instance:IsA("Sky") and record.originalParent ~= nil then
				record.instance.Parent = record.originalParent
			end
		end
		return
	end

	-- Suspend unmanaged Sky so managed Sky takes priority
	for _, record in ipairs(snap.unmanagedEffects) do
		if record.instance:IsA("Sky") and record.instance.Parent == Lighting then
			record.instance.Parent = nil
		end
	end

	local sky = managed.sky
	if sky == nil or sky.Parent == nil then
		sky = createManagedSky()
		managed.sky = sky
	end

	local s = sky :: Sky
	if spec.CelestialBodiesShown ~= nil then
		s.CelestialBodiesShown = spec.CelestialBodiesShown
	end
	if spec.MoonAngularSize ~= nil then
		s.MoonAngularSize = spec.MoonAngularSize
	end
	if spec.SunAngularSize ~= nil then
		s.SunAngularSize = spec.SunAngularSize
	end
	if spec.StarCount ~= nil then
		s.StarCount = spec.StarCount
	end
	if spec.SkyboxBk ~= nil then
		s.SkyboxBk = spec.SkyboxBk
	end
	if spec.SkyboxDn ~= nil then
		s.SkyboxDn = spec.SkyboxDn
	end
	if spec.SkyboxFt ~= nil then
		s.SkyboxFt = spec.SkyboxFt
	end
	if spec.SkyboxLf ~= nil then
		s.SkyboxLf = spec.SkyboxLf
	end
	if spec.SkyboxRt ~= nil then
		s.SkyboxRt = spec.SkyboxRt
	end
	if spec.SkyboxUp ~= nil then
		s.SkyboxUp = spec.SkyboxUp
	end
	if spec.MoonTextureId ~= nil then
		s.MoonTextureId = spec.MoonTextureId
	end
	if spec.SunTextureId ~= nil then
		s.SunTextureId = spec.SunTextureId
	end
end

function SnapshotManager.PrepareManagedForPreset(preset: Types.AtmosPreset): Types.ManagedInstances
	local snap = SnapshotManager.EnsureSnapshot()
	SnapshotManager.SuspendUnmanaged()

	-- Atmosphere
	if preset.atmosphere ~= nil then
		if managed.atmosphere == nil or managed.atmosphere.Parent == nil then
			managed.atmosphere = createManagedAtmosphere(snap.atmosphere)
		end
	elseif managed.atmosphere ~= nil then
		-- Keep existing managed atmosphere so transition can smoothly fade its Density/Glare/Haze to 0
		-- or if snap.atmosphere exists, fade toward snap.atmosphere
	end

	-- Sky (instant properties)
	SnapshotManager.ApplySkySpec(preset.sky)

	-- Bloom
	if preset.bloom ~= nil then
		if managed.bloom == nil or managed.bloom.Parent == nil then
			managed.bloom = createManagedBloom(snap.bloom)
		end
		(managed.bloom :: BloomEffect).Enabled = if preset.bloom.Enabled ~= nil then preset.bloom.Enabled else true
	end

	-- ColorCorrection
	if preset.colorCorrection ~= nil then
		if managed.colorCorrection == nil or managed.colorCorrection.Parent == nil then
			managed.colorCorrection = createManagedColorCorrection(snap.colorCorrection)
		end
		(managed.colorCorrection :: ColorCorrectionEffect).Enabled = if preset.colorCorrection.Enabled ~= nil
			then preset.colorCorrection.Enabled
			else true
	end

	-- DepthOfField
	if preset.depthOfField ~= nil then
		if managed.depthOfField == nil or managed.depthOfField.Parent == nil then
			managed.depthOfField = createManagedDepthOfField(snap.depthOfField)
		end
		(managed.depthOfField :: DepthOfFieldEffect).Enabled = if preset.depthOfField.Enabled ~= nil
			then preset.depthOfField.Enabled
			else true
	end

	-- SunRays
	if preset.sunRays ~= nil then
		if managed.sunRays == nil or managed.sunRays.Parent == nil then
			managed.sunRays = createManagedSunRays(snap.sunRays)
		end
		(managed.sunRays :: SunRaysEffect).Enabled = if preset.sunRays.Enabled ~= nil
			then preset.sunRays.Enabled
			else true
	end

	return managed
end

function SnapshotManager.PruneUnusedManaged(preset: Types.AtmosPreset)
	if preset.atmosphere == nil and managed.atmosphere ~= nil then
		managed.atmosphere:Destroy()
		managed.atmosphere = nil
	end
	if preset.bloom == nil and managed.bloom ~= nil then
		managed.bloom:Destroy()
		managed.bloom = nil
	end
	if preset.colorCorrection == nil and managed.colorCorrection ~= nil then
		managed.colorCorrection:Destroy()
		managed.colorCorrection = nil
	end
	if preset.depthOfField == nil and managed.depthOfField ~= nil then
		managed.depthOfField:Destroy()
		managed.depthOfField = nil
	end
	if preset.sunRays == nil and managed.sunRays ~= nil then
		managed.sunRays:Destroy()
		managed.sunRays = nil
	end
end

function SnapshotManager.DestroyAllManaged()
	if managed.atmosphere ~= nil then
		managed.atmosphere:Destroy()
		managed.atmosphere = nil
	end
	if managed.sky ~= nil then
		managed.sky:Destroy()
		managed.sky = nil
	end
	if managed.bloom ~= nil then
		managed.bloom:Destroy()
		managed.bloom = nil
	end
	if managed.colorCorrection ~= nil then
		managed.colorCorrection:Destroy()
		managed.colorCorrection = nil
	end
	if managed.depthOfField ~= nil then
		managed.depthOfField:Destroy()
		managed.depthOfField = nil
	end
	if managed.sunRays ~= nil then
		managed.sunRays:Destroy()
		managed.sunRays = nil
	end

	-- Defensive sweep in case orphan managed instances remain under Lighting
	for _, child in ipairs(Lighting:GetChildren()) do
		if isManagedInstance(child) then
			child:Destroy()
		end
	end
end

function SnapshotManager.RestoreImmediate()
	local snap = activeSnapshot
	if snap == nil then
		SnapshotManager.DestroyAllManaged()
		return
	end

	local l = snap.lighting
	if l.ClockTime ~= nil then
		Lighting.ClockTime = l.ClockTime
	end
	if l.Brightness ~= nil then
		Lighting.Brightness = l.Brightness
	end
	if l.Ambient ~= nil then
		Lighting.Ambient = l.Ambient
	end
	if l.OutdoorAmbient ~= nil then
		Lighting.OutdoorAmbient = l.OutdoorAmbient
	end
	if l.ColorShift_Top ~= nil then
		Lighting.ColorShift_Top = l.ColorShift_Top
	end
	if l.ColorShift_Bottom ~= nil then
		Lighting.ColorShift_Bottom = l.ColorShift_Bottom
	end
	if l.EnvironmentDiffuseScale ~= nil then
		Lighting.EnvironmentDiffuseScale = l.EnvironmentDiffuseScale
	end
	if l.EnvironmentSpecularScale ~= nil then
		Lighting.EnvironmentSpecularScale = l.EnvironmentSpecularScale
	end
	if l.ExposureCompensation ~= nil then
		Lighting.ExposureCompensation = l.ExposureCompensation
	end
	if l.GeographicLatitude ~= nil then
		Lighting.GeographicLatitude = l.GeographicLatitude
	end
	if l.ShadowSoftness ~= nil then
		Lighting.ShadowSoftness = l.ShadowSoftness
	end
	if l.GlobalShadows ~= nil then
		Lighting.GlobalShadows = l.GlobalShadows
	end
	if l.FogColor ~= nil then
		Lighting.FogColor = l.FogColor
	end
	if l.FogStart ~= nil then
		Lighting.FogStart = l.FogStart
	end
	if l.FogEnd ~= nil then
		Lighting.FogEnd = l.FogEnd
	end

	SnapshotManager.DestroyAllManaged()
	SnapshotManager.RestoreUnmanaged()
end

return SnapshotManager
