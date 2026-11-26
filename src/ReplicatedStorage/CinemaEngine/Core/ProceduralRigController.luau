--!strict

local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)
local SpringSolver = require(script.Parent.SpringSolver)

local ProceduralRigController = {}

type RigJoints = {
	isR15: boolean,
	rootMotor: Motor6D?,
	waistMotor: Motor6D?,
	neckMotor: Motor6D?,
}

type RigSession = {
	character: Model,
	humanoid: Humanoid,
	hrp: BasePart,
	joints: RigJoints,
	config: Types.ProceduralRigConfig,
	leanSpring: Types.Vector3Spring,
	impactSpring: Types.Vector3Spring,
	breathPhase: number,
	prevVelY: number,
	connections: { RBXScriptConnection },
	detached: boolean,
}

local activeSessions: { [Model]: RigSession } = {}
local steppedConn: RBXScriptConnection? = nil

local function findMotor(parent: Instance?, motorName: string): Motor6D?
	if parent == nil then
		return nil
	end
	local inst = parent:FindFirstChild(motorName)
	if inst ~= nil and inst:IsA("Motor6D") then
		return inst
	end
	return nil
end

local function resolveRigJoints(character: Model, hrp: BasePart): RigJoints
	local lowerTorso = character:FindFirstChild("LowerTorso")
	local upperTorso = character:FindFirstChild("UpperTorso")
	local head = character:FindFirstChild("Head")

	-- Prefer R15 structure when LowerTorso / UpperTorso exist
	if lowerTorso ~= nil or upperTorso ~= nil then
		return {
			isR15 = true,
			rootMotor = findMotor(lowerTorso, "Root"),
			waistMotor = findMotor(upperTorso, "Waist"),
			neckMotor = findMotor(head, "Neck"),
		}
	end

	-- Fallback to R6 structure
	local torso = character:FindFirstChild("Torso")
	return {
		isR15 = false,
		rootMotor = findMotor(hrp, "RootJoint"),
		waistMotor = nil,
		neckMotor = findMotor(torso, "Neck"),
	}
end

local function disconnectSession(session: RigSession)
	if session.detached then
		return
	end
	session.detached = true
	activeSessions[session.character] = nil

	for _, conn in ipairs(session.connections) do
		conn:Disconnect()
	end
	table.clear(session.connections)

	if next(activeSessions) == nil and steppedConn ~= nil then
		steppedConn:Disconnect()
		steppedConn = nil
	end
end

local function stepSession(session: RigSession, dt: number)
	if session.detached then
		return
	end
	local character = session.character
	local hrp = session.hrp
	local humanoid = session.humanoid

	if not character:IsDescendantOf(game) or not hrp:IsDescendantOf(character) or humanoid.Health <= 0 then
		disconnectSession(session)
		return
	end

	local cfg = session.config
	local joints = session.joints

	-- Re-resolve joints once if character parts loaded asynchronously
	if joints.rootMotor == nil and joints.waistMotor == nil then
		joints = resolveRigJoints(character, hrp)
		session.joints = joints
	end

	-- 1. Breathing rhythm
	local breathY = 0
	local breathPitch = 0
	if cfg.breathingEnabled ~= false then
		local breathFreq = math.max(0.05, cfg.breathingFrequency or 0.42)
		local breathAmp = cfg.breathingAmplitude or 0.032
		session.breathPhase = (session.breathPhase + dt * breathFreq * math.pi * 2) % (math.pi * 2)
		local s = math.sin(session.breathPhase)
		breathY = s * breathAmp
		breathPitch = s * math.rad(1.4)
	end

	-- 2. Horizontal velocity lean
	local vel = hrp.AssemblyLinearVelocity
	local targetForwardLean = 0
	local targetSideLean = 0

	if cfg.leanEnabled ~= false then
		local horizVel = Vector3.new(vel.X, 0, vel.Z)
		local speed = horizVel.Magnitude
		local refSpeed = math.max(1, cfg.referenceSpeed or 16)
		local forwardSpeed = horizVel:Dot(hrp.CFrame.LookVector)
		local sideSpeed = horizVel:Dot(hrp.CFrame.RightVector)

		local fwdNorm = math.clamp(forwardSpeed / refSpeed, -1.4, 1.4)
		local sideNorm = math.clamp(sideSpeed / refSpeed, -1.4, 1.4)

		local maxFwdRad = math.rad(cfg.maxForwardLeanDegrees or 11)
		local maxSideRad = math.rad(cfg.maxSideLeanDegrees or 9)

		-- Negative X rotation pitches character forward along LookVector (-Z)
		targetForwardLean = -fwdNorm * maxFwdRad
		-- Negative Z rotation banks character toward RightVector (+X)
		targetSideLean = -sideNorm * maxSideRad

		-- Reduce breathing amplitude slightly while sprinting
		local moveDampen = 1 - math.clamp(speed / (refSpeed * 1.5), 0, 0.65)
		breathY *= moveDampen
		breathPitch *= moveDampen
	end

	session.leanSpring:SetTarget(Vector3.new(targetForwardLean, 0, targetSideLean))
	local leanVal = session.leanSpring:Update(dt)

	-- 3. Vertical velocity sudden-change backup landing detection
	if cfg.landingSpringEnabled ~= false then
		local vy = vel.Y
		if session.prevVelY < -18 and vy > -3 and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
			local strength = math.clamp(math.abs(session.prevVelY) / 42, 0.35, 1.5)
			local landScale = cfg.landingImpulseScale or 1
			session.impactSpring:Impulse(Vector3.new(
				-math.rad(12) * strength * landScale,
				-0.42 * strength * landScale,
				0
			))
		end
		session.prevVelY = vy
	end

	local impactVal = session.impactSpring:Update(dt)

	-- 4. Layer onto Motor6D.Transform (STRICTLY inside RunService.Stepped; NEVER touch C0/C1)
	local rootPitch = leanVal.X * 0.45 + impactVal.X * 0.4
	local rootRoll = leanVal.Z * 0.55 + impactVal.Z * 0.45
	local rootOffsetY = breathY + impactVal.Y

	if joints.isR15 then
		if joints.rootMotor ~= nil and joints.rootMotor.Parent ~= nil then
			joints.rootMotor.Transform = joints.rootMotor.Transform
				* CFrame.new(0, rootOffsetY, 0)
				* CFrame.Angles(rootPitch, 0, rootRoll)
		end

		if joints.waistMotor ~= nil and joints.waistMotor.Parent ~= nil then
			local waistPitch = breathPitch + leanVal.X * 0.55 + impactVal.X * 0.6
			local waistRoll = leanVal.Z * 0.45 + impactVal.Z * 0.55
			joints.waistMotor.Transform = joints.waistMotor.Transform
				* CFrame.Angles(waistPitch, 0, waistRoll)
		end

		if joints.neckMotor ~= nil and joints.neckMotor.Parent ~= nil then
			-- Subtle head counter-stabilization so gaze feels grounded
			local neckPitch = -breathPitch * 0.55 - leanVal.X * 0.35 - impactVal.X * 0.3
			local neckRoll = -leanVal.Z * 0.35 - impactVal.Z * 0.25
			joints.neckMotor.Transform = joints.neckMotor.Transform
				* CFrame.Angles(neckPitch, 0, neckRoll)
		end
	else
		-- R6: RootJoint uses Z-up local space in classic R6 rigs; apply lean/bounce cleanly
		if joints.rootMotor ~= nil and joints.rootMotor.Parent ~= nil then
			local totalPitch = breathPitch + leanVal.X + impactVal.X
			local totalRoll = leanVal.Z + impactVal.Z
			joints.rootMotor.Transform = joints.rootMotor.Transform
				* CFrame.new(0, 0, rootOffsetY)
				* CFrame.Angles(totalPitch, totalRoll, 0)
		end

		if joints.neckMotor ~= nil and joints.neckMotor.Parent ~= nil then
			local neckPitch = -breathPitch * 0.5 - leanVal.X * 0.35 - impactVal.X * 0.25
			local neckRoll = -leanVal.Z * 0.3 - impactVal.Z * 0.2
			joints.neckMotor.Transform = joints.neckMotor.Transform
				* CFrame.Angles(neckPitch, neckRoll, 0)
		end
	end
end

local function ensureSteppedConnected()
	if steppedConn ~= nil or not RunService:IsClient() then
		return
	end
	steppedConn = RunService.Stepped:Connect(function(_stepTime: number, dt: number)
		local snapshot: { RigSession } = {}
		for _, session in pairs(activeSessions) do
			table.insert(snapshot, session)
		end
		for _, session in ipairs(snapshot) do
			stepSession(session, dt)
		end
	end)
end

function ProceduralRigController.Attach(character: Model, config: Types.ProceduralRigConfig?): boolean
	if not RunService:IsClient() then
		return false
	end
	if character == nil or not character:IsDescendantOf(game) then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or hrp == nil or not hrp:IsA("BasePart") or humanoid.Health <= 0 then
		return false
	end

	ProceduralRigController.Detach(character)

	local cfg: Types.ProceduralRigConfig = config or {}
	local leanSpring = SpringSolver.NewVector3(
		Vector3.zero,
		cfg.leanFrequency or 3.2,
		cfg.leanDampingRatio or 0.78
	)
	local impactSpring = SpringSolver.NewVector3(
		Vector3.zero,
		cfg.impulseFrequency or 4.5,
		cfg.impulseDampingRatio or 0.58
	)

	local session: RigSession = {
		character = character,
		humanoid = humanoid,
		hrp = hrp,
		joints = resolveRigJoints(character, hrp),
		config = cfg,
		leanSpring = leanSpring,
		impactSpring = impactSpring,
		breathPhase = 0,
		prevVelY = hrp.AssemblyLinearVelocity.Y,
		connections = {},
		detached = false,
	}

	table.insert(
		session.connections,
		humanoid.StateChanged:Connect(function(_oldState: Enum.HumanoidStateType, newState: Enum.HumanoidStateType)
			if session.detached or session.config.landingSpringEnabled == false then
				return
			end
			if newState == Enum.HumanoidStateType.Jumping then
				local jumpScale = session.config.jumpImpulseScale or 1
				session.impactSpring:Impulse(Vector3.new(
					math.rad(7.5) * jumpScale,
					0.16 * jumpScale,
					0
				))
			elseif newState == Enum.HumanoidStateType.Landed then
				local landScale = session.config.landingImpulseScale or 1
				local speedFactor = math.clamp(math.abs(session.prevVelY) / 38, 0.4, 1.5)
				session.impactSpring:Impulse(Vector3.new(
					-math.rad(13) * speedFactor * landScale,
					-0.36 * speedFactor * landScale,
					0
				))
			end
		end)
	)

	table.insert(
		session.connections,
		humanoid.Died:Connect(function()
			disconnectSession(session)
		end)
	)

	table.insert(
		session.connections,
		character.AncestryChanged:Connect(function(_child: Instance, parent: Instance?)
			if parent == nil then
				disconnectSession(session)
			end
		end)
	)

	activeSessions[character] = session
	ensureSteppedConnected()
	return true
end

function ProceduralRigController.Detach(character: Model)
	local session = activeSessions[character]
	if session ~= nil then
		disconnectSession(session)
	end
end

function ProceduralRigController.Impulse(character: Model, impulse: Vector3)
	local session = activeSessions[character]
	if session ~= nil and not session.detached then
		session.impactSpring:Impulse(impulse)
	end
end

function ProceduralRigController.IsAttached(character: Model): boolean
	local session = activeSessions[character]
	return session ~= nil and not session.detached
end

return ProceduralRigController
