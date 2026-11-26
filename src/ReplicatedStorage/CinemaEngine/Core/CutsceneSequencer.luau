--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)
local SplineCameraRunner = require(script.Parent.SplineCameraRunner)
local LetterboxOverlay = require(script.Parent.LetterboxOverlay)
local ProceduralRigController = require(script.Parent.ProceduralRigController)

local CutsceneSequencer = {}

type ActiveCutscene = {
	preset: Types.CutscenePreset,
	duration: number,
	startTime: number,
	elapsed: number,
	stopped: boolean,
	cameraRunner: SplineCameraRunner.CameraRunnerHandle?,
	overlay: LetterboxOverlay.OverlayHandle?,
	heartbeatConn: RBXScriptConnection?,
	connections: { RBXScriptConnection },
	onCompleted: ((completedNormally: boolean) -> ())?,
}

local activeCutscene: ActiveCutscene? = nil

local function safeGetEngine(engineName: string): any?
	local mod = ReplicatedStorage:FindFirstChild(engineName)
	if mod == nil or not mod:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(function()
		return require(mod :: any)
	end)
	if not ok or type(result) ~= "table" then
		return nil
	end
	return result
end

local function getSubjectCFrame(subject: Model?): CFrame?
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

local function dispatchEventStep(
	step: Types.EngineEventStep,
	subject: Model?,
	target: Model?,
	scale: number,
	intensity: number,
	forceReload: boolean,
	elapsed: number
)
	local action = step.action
	local baseCFrame = getSubjectCFrame(subject)
	local eventCFrame = baseCFrame
	if baseCFrame ~= nil and step.offset ~= nil then
		eventCFrame = baseCFrame * CFrame.new(step.offset)
	elseif eventCFrame == nil and workspace.CurrentCamera ~= nil then
		eventCFrame = workspace.CurrentCamera.CFrame
	end
	local eventPos = if eventCFrame ~= nil then eventCFrame.Position else nil

	if action == "VFXMount" then
		if subject == nil or step.presetName == nil then
			return
		end
		local vfxEngine = safeGetEngine("VFXEngine")
		if vfxEngine ~= nil and type(vfxEngine.Mount) == "function" then
			pcall(vfxEngine.Mount, subject, step.presetName, {
				scale = scale * (step.scale or 1),
				autoplay = true,
				forceReload = if step.forceReload ~= nil then step.forceReload else forceReload,
			})
		end
	elseif action == "VFXUnmount" then
		if subject == nil then
			return
		end
		local vfxEngine = safeGetEngine("VFXEngine")
		if vfxEngine ~= nil and type(vfxEngine.Unmount) == "function" then
			pcall(vfxEngine.Unmount, subject)
		end
	elseif action == "VFXReplay" then
		if subject == nil then
			return
		end
		local vfxEngine = safeGetEngine("VFXEngine")
		if vfxEngine ~= nil and type(vfxEngine.GetActive) == "function" then
			pcall(function()
				local handle = vfxEngine.GetActive(subject)
				if handle ~= nil and handle.timeline ~= nil and type(handle.timeline.Replay) == "function" then
					handle.timeline:Replay()
				end
			end)
		end
	elseif action == "JuicePlay" then
		if step.presetName == nil then
			return
		end
		local juiceEngine = safeGetEngine("JuiceEngine")
		if juiceEngine ~= nil and type(juiceEngine.Play) == "function" then
			local ctx: { [string]: any } = {
				position = eventPos,
				cframe = eventCFrame,
				intensity = intensity * (step.intensity or 1),
				scale = scale * (step.scale or 1),
				forceReload = if step.forceReload ~= nil then step.forceReload else forceReload,
			}
			if step.spatialOnly ~= true then
				ctx.attacker = subject
				ctx.target = target or subject
				ctx.targetCharacter = subject
			end
			pcall(juiceEngine.Play, step.presetName, ctx)
		end
	elseif action == "AtmosApply" then
		if step.presetName == nil then
			return
		end
		local atmosEngine = safeGetEngine("AtmosEngine")
		if atmosEngine ~= nil and type(atmosEngine.Apply) == "function" then
			pcall(atmosEngine.Apply, step.presetName, {
				duration = step.duration or 0.8,
				forceReload = if step.forceReload ~= nil then step.forceReload else forceReload,
			})
		end
	elseif action == "AtmosReset" then
		local atmosEngine = safeGetEngine("AtmosEngine")
		if atmosEngine ~= nil and type(atmosEngine.Reset) == "function" then
			pcall(atmosEngine.Reset, step.duration or 0.8)
		end
	elseif action == "RigImpulse" then
		if subject ~= nil and step.impulse ~= nil then
			ProceduralRigController.Impulse(subject, step.impulse)
		end
	elseif action == "Callback" then
		if step.callback ~= nil then
			local ctx: Types.EngineEventContext = {
				character = subject,
				target = target,
				origin = eventPos,
				cframe = eventCFrame,
				elapsed = elapsed,
			}
			pcall(step.callback, ctx)
		end
	end
end

local function finishSession(session: ActiveCutscene, completedNormally: boolean, subject: Model?)
	if session.stopped then
		return
	end
	session.stopped = true

	if activeCutscene == session then
		activeCutscene = nil
	end

	if session.heartbeatConn ~= nil then
		session.heartbeatConn:Disconnect()
		session.heartbeatConn = nil
	end

	for _, conn in ipairs(session.connections) do
		conn:Disconnect()
	end
	table.clear(session.connections)

	if session.cameraRunner ~= nil then
		session.cameraRunner:Stop()
		session.cameraRunner = nil
	end

	if session.overlay ~= nil then
		if completedNormally then
			local fadeDur = if session.preset.letterbox ~= nil and session.preset.letterbox.fadeOutDuration ~= nil
				then session.preset.letterbox.fadeOutDuration
				else 0.3
			session.overlay:Close(fadeDur)
		else
			session.overlay:Destroy()
		end
		session.overlay = nil
	end

	if session.preset.restoreAtmosOnEnd == true then
		local atmosEngine = safeGetEngine("AtmosEngine")
		if atmosEngine ~= nil and type(atmosEngine.Reset) == "function" then
			pcall(atmosEngine.Reset, session.preset.restoreAtmosDuration or 0.8)
		end
	end

	if session.preset.unmountVFXOnEnd == true and subject ~= nil then
		local vfxEngine = safeGetEngine("VFXEngine")
		if vfxEngine ~= nil and type(vfxEngine.Unmount) == "function" then
			pcall(vfxEngine.Unmount, subject)
		end
	end

	if session.onCompleted ~= nil then
		pcall(session.onCompleted, completedNormally)
	end
end

function CutsceneSequencer.Stop()
	if activeCutscene ~= nil then
		finishSession(activeCutscene, false, nil)
	end
end

function CutsceneSequencer.IsPlaying(): boolean
	return activeCutscene ~= nil and not activeCutscene.stopped
end

function CutsceneSequencer.Play(
	preset: Types.CutscenePreset,
	options: Types.CutscenePlayOptions?
): Types.CinemaHandle?
	if not RunService:IsClient() then
		warn("[CinemaEngine.PlayCutscene] Cutscenes must be played on the client.")
		return nil
	end

	CutsceneSequencer.Stop()

	local opts: Types.CutscenePlayOptions = options or {}
	local subject = opts.subject
	if subject == nil and Players.LocalPlayer ~= nil then
		subject = Players.LocalPlayer.Character
	end

	local target = opts.target
	local scale = math.max(0.05, if opts.scale ~= nil then opts.scale else 1)
	local intensity = math.max(0, if opts.intensity ~= nil then opts.intensity else 1)
	local forceReload = opts.forceReload == true
	local duration = math.max(0.05, preset.duration)

	local startTime = os.clock()
	local session: ActiveCutscene = {
		preset = preset,
		duration = duration,
		startTime = startTime,
		elapsed = 0,
		stopped = false,
		cameraRunner = nil,
		overlay = nil,
		heartbeatConn = nil,
		connections = {},
		onCompleted = opts.onCompleted,
	}
	activeCutscene = session

	local function getElapsed(): number
		return os.clock() - startTime
	end

	-- 1. Build Letterbox & Subtitle Overlay if configured
	local hasSubtitles = preset.subtitles ~= nil and #preset.subtitles > 0
	local hasLetterbox = preset.letterbox ~= nil and preset.letterbox.enabled ~= false
	if hasLetterbox or hasSubtitles then
		session.overlay = LetterboxOverlay.New(preset.letterbox, preset.subtitles)
		session.overlay:Update(0, duration)
	end

	-- 2. Start Spline Camera Runner
	if preset.camera ~= nil and #preset.camera.keyframes > 0 then
		session.cameraRunner = SplineCameraRunner.Start(preset.camera, subject, getElapsed)
	end

	-- 3. Sort Event Steps
	local sortedEvents: { Types.EngineEventStep } = {}
	if preset.events ~= nil and #preset.events > 0 then
		sortedEvents = table.clone(preset.events)
		table.sort(sortedEvents, function(a, b)
			return a.time < b.time
		end)
	end
	local nextEventIdx = 1

	local function flushEventsUpTo(currentElapsed: number)
		while nextEventIdx <= #sortedEvents do
			local step = sortedEvents[nextEventIdx]
			if step.time <= currentElapsed then
				nextEventIdx += 1
				dispatchEventStep(step, subject, target, scale, intensity, forceReload, currentElapsed)
			else
				break
			end
		end
	end

	-- Monitor subject removal or death to safely restore camera and UI
	if subject ~= nil then
		table.insert(
			session.connections,
			subject.AncestryChanged:Connect(function(_child: Instance, parent: Instance?)
				if parent == nil then
					finishSession(session, false, subject)
				end
			end)
		)
		local hum = subject:FindFirstChildOfClass("Humanoid")
		if hum ~= nil then
			table.insert(
				session.connections,
				hum.Died:Connect(function()
					finishSession(session, false, subject)
				end)
			)
		end
	end

	-- Trigger t = 0 events immediately
	flushEventsUpTo(0)

	session.heartbeatConn = RunService.Heartbeat:Connect(function()
		if session.stopped then
			return
		end
		local nowElapsed = getElapsed()
		session.elapsed = nowElapsed

		flushEventsUpTo(nowElapsed)

		if session.overlay ~= nil then
			session.overlay:Update(nowElapsed, duration)
		end

		if nowElapsed >= duration then
			finishSession(session, true, subject)
		end
	end)

	local handle: Types.CinemaHandle = {
		presetId = preset.meta.id,
		Stop = function(_self: Types.CinemaHandle)
			finishSession(session, false, subject)
		end,
		IsPlaying = function(_self: Types.CinemaHandle): boolean
			return not session.stopped
		end,
		GetElapsed = function(_self: Types.CinemaHandle): number
			if session.stopped then
				return session.elapsed
			end
			return math.min(duration, getElapsed())
		end,
		GetDuration = function(_self: Types.CinemaHandle): number
			return duration
		end,
	}

	return handle
end

return CutsceneSequencer
