--!strict

local Types = require(script.Parent.Types)

local HitstopController = {}

type TargetState = {
	generation: number,
	trackOriginalSpeeds: { [AnimationTrack]: number },
	particleOriginalTimeScales: { [ParticleEmitter]: number },
	connections: { RBXScriptConnection },
	timerThread: thread?,
}

local activeTargets: { [Model]: TargetState } = {}

local function disconnectAll(connections: { RBXScriptConnection })
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	table.clear(connections)
end

local function restoreTargetState(model: Model, state: TargetState)
	if activeTargets[model] ~= state then
		return
	end
	activeTargets[model] = nil
	state.generation += 1

	if state.timerThread ~= nil then
		pcall(task.cancel, state.timerThread)
		state.timerThread = nil
	end

	disconnectAll(state.connections)

	for track, origSpeed in pairs(state.trackOriginalSpeeds) do
		pcall(function()
			track:AdjustSpeed(origSpeed)
		end)
	end
	table.clear(state.trackOriginalSpeeds)

	for emitter, origTimeScale in pairs(state.particleOriginalTimeScales) do
		if emitter.Parent ~= nil then
			pcall(function()
				emitter.TimeScale = origTimeScale
			end)
		end
	end
	table.clear(state.particleOriginalTimeScales)
end

local function bindSafetyListeners(model: Model, state: TargetState)
	if #state.connections > 0 then
		return
	end

	table.insert(
		state.connections,
		model.AncestryChanged:Connect(function(_child: Instance, parent: Instance?)
			if parent == nil then
				restoreTargetState(model, state)
			end
		end)
	)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		table.insert(
			state.connections,
			humanoid.Died:Connect(function()
				restoreTargetState(model, state)
			end)
		)
	end
end

local function applyToSingleModel(
	model: Model,
	duration: number,
	timeScale: number,
	affectAnimations: boolean,
	affectParticles: boolean
)
	if model == nil or not model:IsDescendantOf(game) then
		return
	end

	local state = activeTargets[model]
	if state == nil then
		state = {
			generation = 0,
			trackOriginalSpeeds = {},
			particleOriginalTimeScales = {},
			connections = {},
			timerThread = nil,
		}
		activeTargets[model] = state
	end

	state.generation += 1
	local gen = state.generation

	if state.timerThread ~= nil then
		pcall(task.cancel, state.timerThread)
		state.timerThread = nil
	end

	bindSafetyListeners(model, state)

	if affectAnimations then
		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("Animator") then
				for _, track in ipairs(desc:GetPlayingAnimationTracks()) do
					-- Preserve the pre-hitstop speed across overlapping hitstop triggers
					if state.trackOriginalSpeeds[track] == nil then
						state.trackOriginalSpeeds[track] = track.Speed
					end
					local origSpeed = state.trackOriginalSpeeds[track]
					pcall(function()
						track:AdjustSpeed(origSpeed * timeScale)
					end)
				end
			end
		end
	end

	if affectParticles then
		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("ParticleEmitter") then
				if state.particleOriginalTimeScales[desc] == nil then
					state.particleOriginalTimeScales[desc] = desc.TimeScale
				end
				local origTimeScale = state.particleOriginalTimeScales[desc]
				pcall(function()
					desc.TimeScale = origTimeScale * timeScale
				end)
			end
		end
	end

	state.timerThread = task.delay(duration, function()
		if state.generation == gen then
			state.timerThread = nil
			restoreTargetState(model, state)
		end
	end)
end

function HitstopController.Apply(targets: { Model }, spec: Types.HitstopSpec)
	local duration = math.max(0, spec.duration)
	if duration <= 0 then
		return
	end

	local timeScale = math.max(0, if spec.timeScale ~= nil then spec.timeScale else 0.02)
	local affectAnimations = if spec.affectAnimations ~= nil then spec.affectAnimations else true
	local affectParticles = if spec.affectParticles ~= nil then spec.affectParticles else true

	if not affectAnimations and not affectParticles then
		return
	end

	local seen: { [Model]: boolean } = {}
	for _, model in ipairs(targets) do
		if model ~= nil and not seen[model] then
			seen[model] = true
			applyToSingleModel(model, duration, timeScale, affectAnimations, affectParticles)
		end
	end
end

function HitstopController.RestoreTarget(model: Model)
	local state = activeTargets[model]
	if state ~= nil then
		restoreTargetState(model, state)
	end
end

function HitstopController.RestoreAll()
	local snapshot: { { model: Model, state: TargetState } } = {}
	for model, state in pairs(activeTargets) do
		table.insert(snapshot, { model = model, state = state })
	end
	for _, entry in ipairs(snapshot) do
		restoreTargetState(entry.model, entry.state)
	end
end

return HitstopController
