--!strict

local Types = require(script.Parent.Types)

local RigBuilder = {}

local DEFAULT_PILLAR_HEIGHT = 24
local DEFAULT_HALO_OFFSET = 0.8
local DEFAULT_GROUND_LIFT = 0.08
local DEFAULT_R6_LEG_HEIGHT = 2.0
local DEFAULT_FALLBACK_GROUND_DEPTH = 3.0

local function resolveRootPart(character: Model): BasePart
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp ~= nil and hrp:IsA("BasePart") then
		return hrp
	end

	local primary = character.PrimaryPart
	if primary ~= nil then
		return primary
	end

	error("[VFXEngine.RigBuilder] Character must contain a HumanoidRootPart or PrimaryPart.")
end

local function computeGroundY(character: Model, hrp: BasePart, humanoid: Humanoid?): number
	if humanoid == nil then
		return -(hrp.Size.Y * 0.5 + DEFAULT_FALLBACK_GROUND_DEPTH)
	end

	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return -(hrp.Size.Y * 0.5 + humanoid.HipHeight)
	end

	-- R6: measure leg length safely (independent of stride pose)
	local legPart = character:FindFirstChild("Left Leg") or character:FindFirstChild("Right Leg")
	local legHeight = DEFAULT_R6_LEG_HEIGHT
	if legPart ~= nil and legPart:IsA("BasePart") then
		legHeight = legPart.Size.Y
	end

	return -(hrp.Size.Y * 0.5 + legHeight + humanoid.HipHeight)
end

local function computeHeadTopY(character: Model, hrp: BasePart): number
	local minReasonableTop = hrp.Size.Y * 0.5 + 0.5
	local head = character:FindFirstChild("Head")
	if head ~= nil and head:IsA("BasePart") then
		local localHeadPos = hrp.CFrame:PointToObjectSpace(head.Position)
		local headTop = localHeadPos.Y + head.Size.Y * 0.5
		return math.max(minReasonableTop, headTop)
	end

	return hrp.Size.Y * 0.5 + 1.8
end

local function createAnchor(
	hrp: BasePart,
	name: string,
	localPosition: Vector3,
	sessionId: string,
	anchors: { [string]: Attachment },
	instances: { Instance }
): Attachment
	-- Roblox requires Attachments to be parented directly to a BasePart
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = localPosition
	attachment:SetAttribute("VFXEngineSession", sessionId)
	attachment.Parent = hrp

	anchors[name] = attachment
	table.insert(instances, attachment)
	return attachment
end

function RigBuilder.Build(
	character: Model,
	rigConfig: Types.RigConfig?,
	orbits: { Types.OrbitSpec }?,
	scale: number,
	sessionId: string
): Types.RigContext
	local hrp = resolveRootPart(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rigType = if humanoid ~= nil then humanoid.RigType else nil

	local cfg: Types.RigConfig = rigConfig or {}
	local pillarHeight = if cfg.pillarHeight ~= nil then cfg.pillarHeight else DEFAULT_PILLAR_HEIGHT
	local haloOffset = if cfg.haloOffset ~= nil then cfg.haloOffset else DEFAULT_HALO_OFFSET
	local groundLift = if cfg.groundLift ~= nil then cfg.groundLift else DEFAULT_GROUND_LIFT

	local groundY = computeGroundY(character, hrp, humanoid)
	local headTopY = computeHeadTopY(character, hrp)

	local maxOrbitIndex = cfg.orbitCount or 0
	if orbits ~= nil then
		for _, orbitSpec in ipairs(orbits) do
			if orbitSpec.anchorIndex > maxOrbitIndex then
				maxOrbitIndex = orbitSpec.anchorIndex
			end
		end
	end

	local anchors: { [string]: Attachment } = {}
	local instances: { Instance } = {}

	-- Standard static anchors
	createAnchor(hrp, "RootCore", Vector3.zero, sessionId, anchors, instances)
	createAnchor(hrp, "Ground_Center", Vector3.new(0, groundY + groundLift * scale, 0), sessionId, anchors, instances)
	createAnchor(hrp, "Overhead_Halo", Vector3.new(0, headTopY + haloOffset * scale, 0), sessionId, anchors, instances)
	createAnchor(hrp, "Pillar_Bottom", Vector3.new(0, groundY, 0), sessionId, anchors, instances)
	createAnchor(hrp, "Pillar_Top", Vector3.new(0, groundY + pillarHeight * scale, 0), sessionId, anchors, instances)

	-- Dynamic 3D orbit anchor sets (Orbit_N + Orbit_N_Top / Orbit_N_Bottom)
	for i = 1, maxOrbitIndex do
		local baseName = "Orbit_" .. tostring(i)
		createAnchor(hrp, baseName, Vector3.zero, sessionId, anchors, instances)
		createAnchor(hrp, baseName .. "_Top", Vector3.zero, sessionId, anchors, instances)
		createAnchor(hrp, baseName .. "_Bottom", Vector3.zero, sessionId, anchors, instances)
	end

	-- Optional custom static anchors
	if cfg.customAnchors ~= nil then
		for customName, offset in pairs(cfg.customAnchors) do
			if anchors[customName] ~= nil then
				warn(
					string.format(
						"[VFXEngine.RigBuilder] customAnchors key '%s' collides with a standard anchor and was skipped.",
						customName
					)
				)
			else
				createAnchor(hrp, customName, offset * scale, sessionId, anchors, instances)
			end
		end
	end

	return {
		character = character,
		hrp = hrp,
		humanoid = humanoid,
		rigType = rigType,
		scale = scale,
		sessionId = sessionId,
		groundY = groundY,
		headTopY = headTopY,
		anchors = anchors,
		instances = instances,
	}
end

function RigBuilder.Destroy(rig: Types.RigContext)
	for _, inst in ipairs(rig.instances) do
		if inst.Parent ~= nil then
			inst:Destroy()
		end
	end
	table.clear(rig.instances)
	table.clear(rig.anchors)
end

return RigBuilder
