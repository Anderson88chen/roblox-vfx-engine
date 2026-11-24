--!strict

local Types = require(script.Parent.Types)
local CurveUtils = require(script.Parent.CurveUtils)

local InstanceFactory = {}

local MAX_LIGHT_RANGE = 60

local function registerInstance(
	registry: Types.InstanceRegistry,
	id: string,
	tags: { string }?,
	instance: Instance
)
	if registry.byId[id] ~= nil then
		warn(string.format("[VFXEngine.InstanceFactory] Duplicate effect id '%s'; overwriting registry entry.", id))
	end
	registry.byId[id] = instance
	table.insert(registry.all, instance)

	if tags ~= nil then
		for _, tag in ipairs(tags) do
			local bucket = registry.byTag[tag]
			if bucket == nil then
				bucket = {}
				registry.byTag[tag] = bucket
			end
			table.insert(bucket, instance)
		end
	end
end

local function createParticle(spec: Types.ParticleSpec, rig: Types.RigContext, registry: Types.InstanceRegistry)
	local anchor = rig.anchors[spec.anchor]
	if anchor == nil then
		warn(
			string.format(
				"[VFXEngine.InstanceFactory] Unknown anchor '%s' for Particle '%s'.",
				spec.anchor,
				spec.id
			)
		)
		return
	end

	local scale = rig.scale
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = spec.id
	emitter.Texture = spec.texture
	emitter.Color = CurveUtils.ResolveColorSequence(spec.color)
	emitter.Size = CurveUtils.ResolveNumberSequence(spec.size, 1, 0, nil, scale)
	emitter.Transparency = CurveUtils.ResolveNumberSequence(spec.transparency, 0, 0, 1, 1)
	emitter.Squash = CurveUtils.ResolveNumberSequence(spec.squash, 0, -5, 5, 1)
	emitter.Lifetime = CurveUtils.ResolveNumberRange(spec.lifetime, 1, 1, 1)
	emitter.Rate = if spec.rate ~= nil then math.max(0, spec.rate) else 20
	emitter.Speed = CurveUtils.ResolveNumberRange(spec.speed, 2, 2, scale)
	emitter.SpreadAngle = spec.spreadAngle or Vector2.zero
	emitter.Acceleration = if spec.acceleration ~= nil then spec.acceleration * scale else Vector3.zero
	emitter.Drag = if spec.drag ~= nil then spec.drag else 0
	emitter.Rotation = CurveUtils.ResolveNumberRange(spec.rotation, 0, 0, 1)
	emitter.RotSpeed = CurveUtils.ResolveNumberRange(spec.rotSpeed, 0, 0, 1)
	emitter.EmissionDirection = spec.emissionDirection or Enum.NormalId.Top
	emitter.Orientation = spec.orientation or Enum.ParticleOrientation.FacingCamera
	emitter.LightEmission = math.clamp(spec.lightEmission or 0, 0, 1)
	emitter.LightInfluence = math.clamp(if spec.lightInfluence ~= nil then spec.lightInfluence else 1, 0, 1)
	emitter.Brightness = math.max(0, if spec.brightness ~= nil then spec.brightness else 1)
	emitter.ZOffset = spec.zOffset or 0
	emitter.LockedToPart = spec.lockedToPart == true
	emitter.TimeScale = if spec.timeScale ~= nil then math.clamp(spec.timeScale, 0, 1) else 1
	emitter.VelocityInheritance = if spec.velocityInheritance ~= nil then spec.velocityInheritance else 0
	emitter.WindAffectsDrag = spec.windAffectsDrag == true

	if spec.flipbookLayout ~= nil and spec.flipbookLayout ~= Enum.ParticleFlipbookLayout.None then
		emitter.FlipbookLayout = spec.flipbookLayout
		emitter.FlipbookMode = spec.flipbookMode or Enum.ParticleFlipbookMode.Loop
		emitter.FlipbookFramerate = CurveUtils.ResolveNumberRange(spec.flipbookFramerate, 1, 1, 1)
	end

	emitter.Enabled = if spec.enabledByDefault ~= nil then spec.enabledByDefault else true
	emitter:SetAttribute("VFXEngineSession", rig.sessionId)
	emitter:SetAttribute("VFXEngineId", spec.id)

	-- Always parent after setting all properties
	emitter.Parent = anchor

	table.insert(rig.instances, emitter)
	table.insert(registry.particles, emitter)
	registerInstance(registry, spec.id, spec.tags, emitter)
end

local function createBeam(spec: Types.BeamSpec, rig: Types.RigContext, registry: Types.InstanceRegistry)
	local anchor0 = rig.anchors[spec.anchor0]
	local anchor1 = rig.anchors[spec.anchor1]
	if anchor0 == nil or anchor1 == nil then
		warn(
			string.format(
				"[VFXEngine.InstanceFactory] Unknown anchor(s) '%s' -> '%s' for Beam '%s'.",
				spec.anchor0,
				spec.anchor1,
				spec.id
			)
		)
		return
	end

	local scale = rig.scale
	local width0 = (if spec.width0 ~= nil then spec.width0 else 1) * scale
	local width1 = (if spec.width1 ~= nil then spec.width1 else 1) * scale

	local beam = Instance.new("Beam")
	beam.Name = spec.id
	beam.Attachment0 = anchor0
	beam.Attachment1 = anchor1
	beam.Texture = spec.texture or ""
	beam.Color = CurveUtils.ResolveColorSequence(spec.color)
	beam.Transparency = CurveUtils.ResolveNumberSequence(spec.transparency, 0, 0, 1, 1)
	beam.Width0 = width0
	beam.Width1 = width1
	beam.CurveSize0 = (spec.curveSize0 or 0) * scale
	beam.CurveSize1 = (spec.curveSize1 or 0) * scale
	beam.Segments = math.max(1, math.floor((spec.segments or 10) + 0.5))
	beam.TextureLength = (spec.textureLength or 1) * scale
	beam.TextureMode = spec.textureMode or Enum.TextureMode.Stretch
	beam.TextureSpeed = spec.textureSpeed or 1
	beam.FaceCamera = spec.faceCamera == true
	beam.LightEmission = math.clamp(spec.lightEmission or 0, 0, 1)
	beam.LightInfluence = math.clamp(if spec.lightInfluence ~= nil then spec.lightInfluence else 1, 0, 1)
	beam.Brightness = math.max(0, if spec.brightness ~= nil then spec.brightness else 1)
	beam.ZOffset = spec.zOffset or 0
	beam.Enabled = if spec.enabledByDefault ~= nil then spec.enabledByDefault else true
	beam:SetAttribute("VFXEngineSession", rig.sessionId)
	beam:SetAttribute("VFXEngineId", spec.id)

	beam.Parent = anchor0

	table.insert(rig.instances, beam)
	table.insert(registry.beams, beam)
	registry.beamMetaById[spec.id] = {
		instance = beam,
		baseWidth0 = width0,
		baseWidth1 = width1,
	}
	registerInstance(registry, spec.id, spec.tags, beam)
end

local function createTrail(spec: Types.TrailSpec, rig: Types.RigContext, registry: Types.InstanceRegistry)
	local anchor0 = rig.anchors[spec.anchor0]
	local anchor1 = rig.anchors[spec.anchor1]
	if anchor0 == nil or anchor1 == nil then
		warn(
			string.format(
				"[VFXEngine.InstanceFactory] Unknown anchor(s) '%s' / '%s' for Trail '%s'.",
				spec.anchor0,
				spec.anchor1,
				spec.id
			)
		)
		return
	end

	local scale = rig.scale
	local desiredEnabled = if spec.enabledByDefault ~= nil then spec.enabledByDefault else true

	local trail = Instance.new("Trail")
	trail.Name = spec.id
	trail.Attachment0 = anchor0
	trail.Attachment1 = anchor1
	trail.Texture = spec.texture or ""
	trail.Color = CurveUtils.ResolveColorSequence(spec.color)
	trail.Transparency = CurveUtils.ResolveNumberSequence(spec.transparency, 0, 0, 1, 1)
	trail.WidthScale = CurveUtils.ResolveNumberSequence(spec.widthScale, 1, 0, 1, 1)
	trail.Lifetime = if spec.lifetime ~= nil then math.max(0.01, spec.lifetime) else 0.5
	trail.MinLength = (if spec.minLength ~= nil then spec.minLength else 0.1) * scale
	trail.MaxLength = (if spec.maxLength ~= nil then spec.maxLength else 0) * scale
	trail.TextureLength = (spec.textureLength or 1) * scale
	trail.TextureMode = spec.textureMode or Enum.TextureMode.Stretch
	trail.FaceCamera = spec.faceCamera == true
	trail.LightEmission = math.clamp(spec.lightEmission or 0, 0, 1)
	trail.LightInfluence = math.clamp(if spec.lightInfluence ~= nil then spec.lightInfluence else 1, 0, 1)
	trail.Brightness = math.max(0, if spec.brightness ~= nil then spec.brightness else 1)
	trail.Enabled = desiredEnabled
	trail:SetAttribute("VFXEngineSession", rig.sessionId)
	trail:SetAttribute("VFXEngineId", spec.id)

	trail.Parent = anchor0
	trail:Clear()

	table.insert(rig.instances, trail)
	table.insert(registry.trails, trail)
	registerInstance(registry, spec.id, spec.tags, trail)
end

local function createLight(spec: Types.LightSpec, rig: Types.RigContext, registry: Types.InstanceRegistry)
	local anchor = rig.anchors[spec.anchor]
	if anchor == nil then
		warn(
			string.format(
				"[VFXEngine.InstanceFactory] Unknown anchor '%s' for PointLight '%s'.",
				spec.anchor,
				spec.id
			)
		)
		return
	end

	local scale = rig.scale
	local baseBrightness = math.max(0, if spec.brightness ~= nil then spec.brightness else 1.5)
	local baseRange = math.clamp((if spec.range ~= nil then spec.range else 14) * scale, 0, MAX_LIGHT_RANGE)

	local light = Instance.new("PointLight")
	light.Name = spec.id
	light.Color = spec.color or Color3.new(1, 1, 1)
	light.Brightness = baseBrightness
	light.Range = baseRange
	light.Shadows = spec.shadows == true
	light.Enabled = if spec.enabledByDefault ~= nil then spec.enabledByDefault else true
	light:SetAttribute("VFXEngineSession", rig.sessionId)
	light:SetAttribute("VFXEngineId", spec.id)

	light.Parent = anchor

	local meta: Types.LightMeta = {
		instance = light,
		baseBrightness = baseBrightness,
		baseRange = baseRange,
		pulse = spec.pulse,
	}

	table.insert(rig.instances, light)
	table.insert(registry.lights, meta)
	registry.lightMetaById[spec.id] = meta
	registerInstance(registry, spec.id, spec.tags, light)
end

function InstanceFactory.Build(preset: Types.AuraPreset, rig: Types.RigContext): Types.InstanceRegistry
	local registry: Types.InstanceRegistry = {
		byId = {},
		byTag = {},
		all = {},
		particles = {},
		beams = {},
		trails = {},
		lights = {},
		beamMetaById = {},
		lightMetaById = {},
	}

	if preset.particles ~= nil then
		for _, spec in ipairs(preset.particles) do
			createParticle(spec, rig, registry)
		end
	end

	if preset.beams ~= nil then
		for _, spec in ipairs(preset.beams) do
			createBeam(spec, rig, registry)
		end
	end

	if preset.trails ~= nil then
		for _, spec in ipairs(preset.trails) do
			createTrail(spec, rig, registry)
		end
	end

	if preset.lights ~= nil then
		for _, spec in ipairs(preset.lights) do
			createLight(spec, rig, registry)
		end
	end

	return registry
end

return InstanceFactory
