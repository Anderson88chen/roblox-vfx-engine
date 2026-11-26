--!strict

local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)

local SplineCameraRunner = {}

local RENDER_STEP_NAME = "CinemaEngine_SplineCamera"
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value
local MIN_FOV = 15
local MAX_FOV = 115

export type CameraRunnerHandle = {
	Stop: (self: CameraRunnerHandle) -> (),
	IsActive: (self: CameraRunnerHandle) -> boolean,
}

local function applyEasing(alpha: number, easingName: Types.EasingName?, directionName: Types.EasingDirectionName?): number
	local t = math.clamp(alpha, 0, 1)
	local style: Types.EasingName = easingName or "Sine"
	local dir: Types.EasingDirectionName = directionName or "InOut"

	if style == "Linear" then
		return t
	end

	local function easeIn(u: number): number
		if style == "Sine" then
			return 1 - math.cos((u * math.pi) / 2)
		elseif style == "Quad" then
			return u * u
		elseif style == "Cubic" then
			return u * u * u
		elseif style == "Expo" then
			return if u <= 0 then 0 else math.pow(2, 10 * u - 10)
		elseif style == "Back" then
			local c1 = 1.70158
			local c3 = c1 + 1
			return c3 * u * u * u - c1 * u * u
		end
		return u
	end

	local function easeOut(u: number): number
		if style == "Sine" then
			return math.sin((u * math.pi) / 2)
		elseif style == "Quad" then
			return 1 - (1 - u) * (1 - u)
		elseif style == "Cubic" then
			local inv = 1 - u
			return 1 - inv * inv * inv
		elseif style == "Expo" then
			return if u >= 1 then 1 else 1 - math.pow(2, -10 * u)
		elseif style == "Back" then
			local c1 = 1.70158
			local c3 = c1 + 1
			local shifted = u - 1
			return 1 + c3 * shifted * shifted * shifted + c1 * shifted * shifted
		end
		return u
	end

	if dir == "In" then
		return easeIn(t)
	elseif dir == "Out" then
		return easeOut(t)
	end

	-- InOut
	if style == "Sine" then
		return -(math.cos(math.pi * t) - 1) / 2
	elseif style == "Quad" then
		if t < 0.5 then
			return 2 * t * t
		end
		return 1 - math.pow(-2 * t + 2, 2) / 2
	elseif style == "Cubic" then
		if t < 0.5 then
			return 4 * t * t * t
		end
		return 1 - math.pow(-2 * t + 2, 3) / 2
	elseif style == "Expo" then
		if t <= 0 then
			return 0
		elseif t >= 1 then
			return 1
		elseif t < 0.5 then
			return math.pow(2, 20 * t - 10) / 2
		end
		return (2 - math.pow(2, -20 * t + 10)) / 2
	elseif style == "Back" then
		local c1 = 1.70158
		local c2 = c1 * 1.525
		if t < 0.5 then
			return (math.pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
		end
		return (math.pow(2 * t - 2, 2) * ((c2 + 1) * (2 * t - 2) + c2) + 2) / 2
	end

	return t
end

local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: number): Vector3
	local u2 = u * u
	local u3 = u2 * u
	return 0.5 * (
		(2 * p1)
		+ (-p0 + p2) * u
		+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2
		+ (-p0 + 3 * p1 - 3 * p2 + p3) * u3
	)
end

local function getSubjectRootCFrame(subject: Model?): CFrame?
	if subject == nil or not subject:IsDescendantOf(game) then
		return nil
	end
	local hrp = subject:FindFirstChild("HumanoidRootPart")
	if hrp ~= nil and hrp:IsA("BasePart") then
		return hrp.CFrame
	end
	if subject.PrimaryPart ~= nil then
		return subject.PrimaryPart.CFrame
	end
	return subject:GetPivot()
end

local function resolveKeyframePoints(
	kf: Types.CameraKeyframe,
	trackDefaultRelative: boolean,
	rootCFrame: CFrame
): (Vector3, Vector3)
	local isRelative = if kf.relativeToSubject ~= nil
		then kf.relativeToSubject
		elseif kf.subjectOffset ~= nil or kf.lookAtOffset ~= nil then true
		else trackDefaultRelative

	local worldPos: Vector3
	if kf.subjectOffset ~= nil then
		worldPos = rootCFrame:PointToWorldSpace(kf.subjectOffset)
	elseif kf.position ~= nil then
		worldPos = if isRelative then rootCFrame:PointToWorldSpace(kf.position) else kf.position
	else
		worldPos = rootCFrame:PointToWorldSpace(Vector3.new(0, 3, 8))
	end

	local worldLookAt: Vector3
	if kf.lookAtOffset ~= nil then
		worldLookAt = rootCFrame:PointToWorldSpace(kf.lookAtOffset)
	elseif kf.lookAt ~= nil then
		worldLookAt = if isRelative then rootCFrame:PointToWorldSpace(kf.lookAt) else kf.lookAt
	else
		worldLookAt = rootCFrame:PointToWorldSpace(Vector3.new(0, 1.5, 0))
	end

	return worldPos, worldLookAt
end

function SplineCameraRunner.Start(
	track: Types.CameraTrackSpec,
	subject: Model?,
	getElapsed: () -> number
): CameraRunnerHandle
	local stopped = false

	local keyframes = table.clone(track.keyframes or {})
	table.sort(keyframes, function(a, b)
		return a.time < b.time
	end)

	local camera = workspace.CurrentCamera
	if not RunService:IsClient() or camera == nil or #keyframes == 0 then
		stopped = true
		return {
			Stop = function() end,
			IsActive = function(): boolean
				return false
			end,
		}
	end

	-- Snapshot original camera state before taking Scriptable control
	local capturedCamera: Camera = camera
	local originalCameraType = capturedCamera.CameraType
	local originalCameraSubject = capturedCamera.CameraSubject
	local originalFieldOfView = capturedCamera.FieldOfView
	local originalCFrame = capturedCamera.CFrame

	local fallbackRootCFrame = getSubjectRootCFrame(subject) or originalCFrame
	local lockAtStart = track.lockSubjectAtStart == true
	local trackDefaultRelative = track.relativeToSubject == true
	local interpolation: Types.CameraInterpolation = track.interpolation or "CatmullRom"

	capturedCamera.CameraType = Enum.CameraType.Scriptable

	local function evaluateAt(elapsed: number)
		local activeCamera = workspace.CurrentCamera
		if activeCamera == nil then
			return
		end

		if activeCamera.CameraType ~= Enum.CameraType.Scriptable then
			activeCamera.CameraType = Enum.CameraType.Scriptable
		end

		local rootCFrame = if lockAtStart
			then fallbackRootCFrame
			else (getSubjectRootCFrame(subject) or fallbackRootCFrame)

		local pos: Vector3
		local lookAt: Vector3
		local fov: number
		local rollDeg: number

		if #keyframes == 1 or elapsed <= keyframes[1].time then
			local kf = keyframes[1]
			pos, lookAt = resolveKeyframePoints(kf, trackDefaultRelative, rootCFrame)
			fov = kf.fov or originalFieldOfView
			rollDeg = kf.rollDegrees or 0
		elseif elapsed >= keyframes[#keyframes].time then
			local kf = keyframes[#keyframes]
			pos, lookAt = resolveKeyframePoints(kf, trackDefaultRelative, rootCFrame)
			fov = kf.fov or originalFieldOfView
			rollDeg = kf.rollDegrees or 0
		else
			local segIdx = 1
			for i = 1, #keyframes - 1 do
				if elapsed >= keyframes[i].time and elapsed <= keyframes[i + 1].time then
					segIdx = i
					break
				end
			end

			local k1 = keyframes[segIdx]
			local k2 = keyframes[segIdx + 1]
			local span = math.max(1e-5, k2.time - k1.time)
			local rawAlpha = math.clamp((elapsed - k1.time) / span, 0, 1)
			local easingName = k2.easing or k1.easing
			local dirName = k2.direction or k1.direction
			local u = applyEasing(rawAlpha, easingName, dirName)

			local p1, l1 = resolveKeyframePoints(k1, trackDefaultRelative, rootCFrame)
			local p2, l2 = resolveKeyframePoints(k2, trackDefaultRelative, rootCFrame)

			if interpolation == "CatmullRom" then
				local p0: Vector3
				local l0: Vector3
				if segIdx > 1 then
					p0, l0 = resolveKeyframePoints(keyframes[segIdx - 1], trackDefaultRelative, rootCFrame)
				else
					p0 = p1 + (p1 - p2)
					l0 = l1 + (l1 - l2)
				end

				local p3: Vector3
				local l3: Vector3
				if segIdx + 2 <= #keyframes then
					p3, l3 = resolveKeyframePoints(keyframes[segIdx + 2], trackDefaultRelative, rootCFrame)
				else
					p3 = p2 + (p2 - p1)
					l3 = l2 + (l2 - l1)
				end

				pos = catmullRom(p0, p1, p2, p3, u)
				lookAt = catmullRom(l0, l1, l2, l3, u)
			else
				pos = p1:Lerp(p2, u)
				lookAt = l1:Lerp(l2, u)
			end

			local fov1 = k1.fov or originalFieldOfView
			local fov2 = k2.fov or fov1
			fov = fov1 + (fov2 - fov1) * u

			local roll1 = k1.rollDegrees or 0
			local roll2 = k2.rollDegrees or 0
			rollDeg = roll1 + (roll2 - roll1) * u
		end

		if (lookAt - pos).Magnitude < 1e-4 then
			lookAt = pos + rootCFrame.LookVector
		end

		local baseCFrame = CFrame.lookAt(pos, lookAt)
		if math.abs(rollDeg) > 1e-4 then
			baseCFrame = baseCFrame * CFrame.Angles(0, 0, math.rad(rollDeg))
		end

		activeCamera.CFrame = baseCFrame
		activeCamera.FieldOfView = math.clamp(fov, MIN_FOV, MAX_FOV)
	end

	-- Apply initial frame immediately
	evaluateAt(getElapsed())

	RunService:BindToRenderStep(RENDER_STEP_NAME, RENDER_PRIORITY, function(_dt: number)
		if stopped then
			return
		end
		evaluateAt(getElapsed())
	end)

	local handle: CameraRunnerHandle = {
		Stop = function(_self: CameraRunnerHandle)
			if stopped then
				return
			end
			stopped = true

			pcall(function()
				RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
			end)

			local restoreCam = workspace.CurrentCamera or capturedCamera
			if restoreCam ~= nil then
				restoreCam.FieldOfView = originalFieldOfView

				if originalCameraSubject ~= nil and originalCameraSubject:IsDescendantOf(game) then
					restoreCam.CameraSubject = originalCameraSubject
				elseif subject ~= nil and subject:IsDescendantOf(game) then
					local hum = subject:FindFirstChildOfClass("Humanoid")
					if hum ~= nil then
						restoreCam.CameraSubject = hum
					end
				end

				if originalCameraType == Enum.CameraType.Scriptable then
					restoreCam.CFrame = originalCFrame
				end

				restoreCam.CameraType = originalCameraType
			end
		end,

		IsActive = function(_self: CameraRunnerHandle): boolean
			return not stopped
		end,
	}

	return handle
end

return SplineCameraRunner
