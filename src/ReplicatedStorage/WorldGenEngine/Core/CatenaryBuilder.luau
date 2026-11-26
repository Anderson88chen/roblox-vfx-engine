--!strict

local Types = require(script.Parent.Types)

local CatenaryBuilder = {}

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3,
	anchored: boolean,
	canCollide: boolean,
	castShadow: boolean,
	parent: Instance,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Material = material
	part.Color = color
	part.Anchored = anchored
	part.CanCollide = canCollide
	part.CastShadow = castShadow
	if shape ~= nil then
		part.Shape = shape
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function attachLight(
	parent: Instance,
	color: Color3?,
	range: number?,
	brightness: number?
)
	if color == nil and range == nil then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = color or Color3.fromRGB(255, 210, 140)
	light.Range = math.clamp(range or 20, 1, 60)
	light.Brightness = brightness or 1.4
	light.Shadows = false
	light.Parent = parent
end

-- Solves a > 0 such that a * (cosh(halfSpan / a) - 1) = sag
local function solveCatenaryParameter(halfSpan: number, sag: number): number
	local low = 1e-3
	local high = math.max(halfSpan * 4, (halfSpan * halfSpan) / math.max(2 * sag, 1e-4) * 2)

	-- Ensure high is large enough so f(high) < sag
	for _ = 1, 16 do
		local fHigh = high * (math.cosh(halfSpan / high) - 1)
		if fHigh <= sag then
			break
		end
		high *= 2
	end

	for _ = 1, 28 do
		local mid = 0.5 * (low + high)
		local ratio = halfSpan / mid
		local fMid: number
		if ratio > 40 then
			fMid = math.huge
		else
			fMid = mid * (math.cosh(ratio) - 1)
		end
		if fMid > sag then
			low = mid
		else
			high = mid
		end
	end

	return 0.5 * (low + high)
end

local function createPointEvaluator(p0: Vector3, p1: Vector3, sag: number, useCosh: boolean): (number) -> Vector3
	local deltaXZ = Vector3.new(p1.X - p0.X, 0, p1.Z - p0.Z)
	local horizDist = deltaXZ.Magnitude

	if sag <= 1e-4 or horizDist < 1e-3 then
		return function(t: number): Vector3
			return p0:Lerp(p1, t)
		end
	end

	if not useCosh then
		return function(t: number): Vector3
			local base = p0:Lerp(p1, t)
			local dip = 4 * sag * t * (1 - t)
			return Vector3.new(base.X, base.Y - dip, base.Z)
		end
	end

	local halfSpan = horizDist * 0.5
	local a = solveCatenaryParameter(halfSpan, sag)
	local endCosh = math.cosh(halfSpan / a)

	return function(t: number): Vector3
		local base = p0:Lerp(p1, t)
		local x = (t - 0.5) * horizDist
		local ySym = a * (math.cosh(x / a) - endCosh)
		return Vector3.new(base.X, base.Y + ySym, base.Z)
	end
end

local function buildHangingProp(
	attachPoint: Vector3,
	propSpec: Types.HangingPropSpec,
	tetherColor: Color3,
	anchored: boolean,
	parent: Instance,
	index: number
)
	local propModel = Instance.new("Model")
	propModel.Name = string.format("HangingProp_%02d_%s", index, propSpec.kind)

	local dropLen = math.max(0.3, propSpec.dropLength or 1.4)
	local scale = math.max(0.25, propSpec.scale or 1)
	local primaryCol = propSpec.color or Color3.fromRGB(255, 200, 110)
	local accentCol = propSpec.accentColor or Color3.fromRGB(48, 52, 62)

	-- Vertical tether rod
	local tetherCenter = attachPoint - Vector3.new(0, dropLen * 0.5, 0)
	local tether = makePart(
		"Tether",
		Vector3.new(0.1 * scale, dropLen, 0.1 * scale),
		CFrame.new(tetherCenter),
		Enum.Material.Metal,
		tetherColor,
		anchored,
		false,
		false,
		propModel
	)
	propModel.PrimaryPart = tether

	local tipPos = attachPoint - Vector3.new(0, dropLen, 0)

	if propSpec.kind == "Lantern" then
		makePart(
			"Cap",
			Vector3.new(0.85, 0.2, 0.85) * scale,
			CFrame.new(tipPos - Vector3.new(0, 0.1 * scale, 0)),
			Enum.Material.Metal,
			accentCol,
			anchored,
			false,
			false,
			propModel
		)
		local core = makePart(
			"GlowCore",
			Vector3.new(0.6, 0.85, 0.6) * scale,
			CFrame.new(tipPos - Vector3.new(0, 0.62 * scale, 0)),
			Enum.Material.Neon,
			primaryCol,
			anchored,
			false,
			false,
			propModel
		)
		makePart(
			"BottomCap",
			Vector3.new(0.7, 0.16, 0.7) * scale,
			CFrame.new(tipPos - Vector3.new(0, 1.12 * scale, 0)),
			Enum.Material.Metal,
			accentCol,
			anchored,
			false,
			false,
			propModel
		)
		attachLight(core, propSpec.lightColor or primaryCol, propSpec.lightRange, propSpec.lightBrightness)
	elseif propSpec.kind == "EnergyCrystal" then
		local crystal = makePart(
			"CrystalBody",
			Vector3.new(0.55, 1.35, 0.55) * scale,
			CFrame.new(tipPos - Vector3.new(0, 0.7 * scale, 0)) * CFrame.Angles(0, math.rad(45), 0),
			Enum.Material.Neon,
			primaryCol,
			anchored,
			false,
			false,
			propModel
		)
		makePart(
			"CollarRing",
			Vector3.new(0.85, 0.16, 0.85) * scale,
			CFrame.new(tipPos - Vector3.new(0, 0.18 * scale, 0)),
			Enum.Material.Metal,
			accentCol,
			anchored,
			false,
			false,
			propModel
		)
		attachLight(crystal, propSpec.lightColor or primaryCol, propSpec.lightRange, propSpec.lightBrightness)
	elseif propSpec.kind == "WarningSign" or propSpec.kind == "NeonSign" then
		local isNeon = propSpec.kind == "NeonSign"
		local signW = 2.4 * scale
		local signH = 1.2 * scale
		local frame = makePart(
			"SignFrame",
			Vector3.new(signW, signH, 0.18 * scale),
			CFrame.new(tipPos - Vector3.new(0, signH * 0.5, 0)),
			Enum.Material.Metal,
			accentCol,
			anchored,
			false,
			true,
			propModel
		)
		local plate = makePart(
			"SignGlow",
			Vector3.new(signW * 0.86, signH * 0.72, 0.22 * scale),
			frame.CFrame,
			if isNeon then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			primaryCol,
			anchored,
			false,
			false,
			propModel
		)
		if isNeon or propSpec.lightRange ~= nil then
			attachLight(plate, propSpec.lightColor or primaryCol, propSpec.lightRange, propSpec.lightBrightness)
		end
	else
		-- VineCluster
		for k = 1, 3 do
			local drop = (k - 1) * 0.48 * scale
			local sz = (0.75 - (k - 1) * 0.14) * scale
			makePart(
				string.format("Leaf_%d", k),
				Vector3.new(sz, sz * 1.1, sz),
				CFrame.new(tipPos - Vector3.new(0, drop + sz * 0.5, 0)) * CFrame.Angles(0.2 * k, 0.7 * k, 0),
				Enum.Material.Grass,
				primaryCol,
				anchored,
				false,
				true,
				propModel,
				Enum.PartType.Ball
			)
		end
	end

	propModel.Parent = parent
end

function CatenaryBuilder.BuildRope(spec: Types.RopeSpec, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = spec.name or "CatenaryRope"

	local p0 = spec.p0
	local p1 = spec.p1
	local sag = math.max(0, spec.sag or 2.5)
	local segments = math.clamp(math.floor(spec.segments or 14), 2, 64)
	local thickness = math.max(0.06, spec.thickness or 0.25)
	local style: Types.RopeStyle = spec.style or "Rope"
	local useCosh = if spec.useCosh == nil then true else spec.useCosh
	local addJoints = if spec.addJoints == nil then true else spec.addJoints
	local anchored = if spec.anchored == nil then true else spec.anchored
	local canCollide = if spec.canCollide == nil then false else spec.canCollide
	local castShadow = if spec.castShadow == nil then false else spec.castShadow

	local defaultMaterial = Enum.Material.Fabric
	local defaultColor = Color3.fromRGB(145, 112, 78)
	local defaultJointColor = Color3.fromRGB(70, 62, 54)

	if style == "Chain" then
		defaultMaterial = Enum.Material.Metal
		defaultColor = Color3.fromRGB(88, 96, 112)
		defaultJointColor = Color3.fromRGB(150, 175, 210)
	elseif style == "NeonCable" then
		defaultMaterial = Enum.Material.Neon
		defaultColor = Color3.fromRGB(0, 230, 255)
		defaultJointColor = Color3.fromRGB(36, 42, 54)
	elseif style == "Vine" then
		defaultMaterial = Enum.Material.Grass
		defaultColor = Color3.fromRGB(64, 112, 54)
		defaultJointColor = Color3.fromRGB(82, 134, 62)
	end

	local material = spec.material or defaultMaterial
	local color = spec.color or defaultColor
	local secondaryColor = spec.secondaryColor or defaultJointColor

	local evaluate = createPointEvaluator(p0, p1, sag, useCosh)

	local points: { Vector3 } = {}
	for i = 0, segments do
		points[i] = evaluate(i / segments)
	end

	local firstPart: BasePart? = nil

	for i = 1, segments do
		local a = points[i - 1]
		local b = points[i]
		local delta = b - a
		local len = math.max(0.05, delta.Magnitude)
		local mid = (a + b) * 0.5
		local segCF = CFrame.lookAt(mid, b)

		local segSize: Vector3
		local segShape: Enum.PartType? = nil
		if style == "Chain" then
			local isEven = (i % 2) == 0
			local chainAlt = ((i - 1) % 3) * 0.004
			if isEven then
				segSize = Vector3.new(thickness * 1.35 + chainAlt, thickness * 0.55 + chainAlt, len + thickness * 0.25)
			else
				segSize = Vector3.new(thickness * 0.55 + chainAlt, thickness * 1.35 + chainAlt, len + thickness * 0.25)
			end
		else
			local alt = if (i % 2) == 0 then 0.005 else -0.005
			segSize = Vector3.new(thickness + alt, thickness - alt, len + thickness * 0.18)
		end

		local segPart = makePart(
			string.format("RopeSeg_%02d", i),
			segSize,
			segCF,
			material,
			color,
			anchored,
			canCollide,
			castShadow,
			model,
			segShape
		)
		if firstPart == nil then
			firstPart = segPart
		end
	end

	if addJoints then
		local jointScale = if style == "NeonCable" then 1.3 else 1.15
		local jointMat = if style == "NeonCable" or style == "Chain" then Enum.Material.Metal else material
		for i = 0, segments do
			local pt = points[i]
			makePart(
				string.format("Joint_%02d", i),
				Vector3.new(thickness * jointScale, thickness * jointScale, thickness * jointScale),
				CFrame.new(pt),
				jointMat,
				secondaryColor,
				anchored,
				false,
				false,
				model,
				Enum.PartType.Ball
			)
		end
	end

	if spec.hangingProps ~= nil then
		for idx, propSpec in ipairs(spec.hangingProps) do
			local t = math.clamp(propSpec.t, 0.02, 0.98)
			local attachPt = evaluate(t)
			buildHangingProp(attachPt, propSpec, secondaryColor, anchored, model, idx)
		end
	end

	if firstPart ~= nil then
		model.PrimaryPart = firstPart
	end

	if parent ~= nil then
		model.Parent = parent
	end

	return model
end

return CatenaryBuilder
