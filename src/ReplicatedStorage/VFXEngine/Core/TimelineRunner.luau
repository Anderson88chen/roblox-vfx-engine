--!strict

local TweenService = game:GetService("TweenService")

local Types = require(script.Parent.Types)

local TimelineRunner = {}

local function collectTargets(registry: Types.InstanceRegistry, step: Types.TimelineStep): { Instance }
	local targets: { Instance } = {}
	local seen: { [Instance]: boolean } = {}

	if step.targetId ~= nil then
		local byIdInst = registry.byId[step.targetId]
		if byIdInst ~= nil and not seen[byIdInst] then
			seen[byIdInst] = true
			table.insert(targets, byIdInst)
		end
	end

	if step.targetTag ~= nil then
		local tagged = registry.byTag[step.targetTag]
		if tagged ~= nil then
			for _, inst in ipairs(tagged) do
				if not seen[inst] then
					seen[inst] = true
					table.insert(targets, inst)
				end
			end
		end
	end

	return targets
end

local function setInstanceEnabled(inst: Instance, enabled: boolean)
	if inst:IsA("ParticleEmitter") then
		inst.Enabled = enabled
	elseif inst:IsA("Beam") then
		inst.Enabled = enabled
	elseif inst:IsA("Trail") then
		if enabled then
			inst:Clear()
		end
		inst.Enabled = enabled
	elseif inst:IsA("PointLight") then
		inst.Enabled = enabled
	end
end

function TimelineRunner.New(
	preset: Types.AuraPreset,
	rig: Types.RigContext,
	registry: Types.InstanceRegistry,
	orbitController: Types.OrbitControllerHandle
): Types.TimelineHandle
	local config = preset.timeline
	local steps: { Types.TimelineStep } = if config ~= nil then config.steps else {}
	local isLoop = if config ~= nil then config.loop == true else false

	local maxStepTime = 0
	for _, step in ipairs(steps) do
		if step.time > maxStepTime then
			maxStepTime = step.time
		end
	end

	local loopDuration = if config ~= nil and config.loopDuration ~= nil and config.loopDuration > 0
		then config.loopDuration
		else math.max(0.1, maxStepTime + 0.1)

	-- Capture initial enabled state so Replay() cleanly restores t=0 defaults
	local initialEnabled: { [Instance]: boolean } = {}
	for _, inst in ipairs(registry.all) do
		if inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("PointLight") then
			initialEnabled[inst] = (inst :: any).Enabled == true
		end
	end

	local orbitGroups: { string } = { "default" }
	local seenGroup: { [string]: boolean } = { default = true }
	if preset.orbits ~= nil then
		for _, orbitSpec in ipairs(preset.orbits) do
			local grp = orbitSpec.group or "default"
			if not seenGroup[grp] then
				seenGroup[grp] = true
				table.insert(orbitGroups, grp)
			end
		end
	end

	local destroyed = false
	local generation = 0
	local activeThreads: { thread } = {}
	local activeTweens: { Tween } = {}

	local function cancelScheduledWork()
		generation += 1
		local currentThread = coroutine.running()

		for _, tween in ipairs(activeTweens) do
			pcall(function()
				tween:Cancel()
				tween:Destroy()
			end)
		end
		table.clear(activeTweens)

		for _, thread in ipairs(activeThreads) do
			if thread ~= currentThread then
				pcall(task.cancel, thread)
			end
		end
		table.clear(activeThreads)
	end

	local function executeStep(step: Types.TimelineStep)
		if destroyed then
			return
		end

		local action = step.action
		if action == "SetEnabled" then
			local enabled = step.enabled == true
			for _, target in ipairs(collectTargets(registry, step)) do
				setInstanceEnabled(target, enabled)
			end
		elseif action == "EmitBurst" then
			local count = math.max(0, math.floor((step.count or 1) + 0.5))
			if count > 0 then
				for _, target in ipairs(collectTargets(registry, step)) do
					if target:IsA("ParticleEmitter") then
						target:Emit(count)
					end
				end
			end
		elseif action == "TweenBeamWidth" then
			local dur = math.max(0.01, step.duration or 0.25)
			local style = step.easingStyle or Enum.EasingStyle.Quad
			local dir = step.easingDirection or Enum.EasingDirection.Out
			local tweenInfo = TweenInfo.new(dur, style, dir)

			for _, target in ipairs(collectTargets(registry, step)) do
				if target:IsA("Beam") then
					local goal: { [string]: number } = {}
					if step.width0 ~= nil then
						goal.Width0 = math.max(0, step.width0 * rig.scale)
					end
					if step.width1 ~= nil then
						goal.Width1 = math.max(0, step.width1 * rig.scale)
					end
					if next(goal) ~= nil then
						local tween = TweenService:Create(target, tweenInfo, goal)
						table.insert(activeTweens, tween)
						tween:Play()
					end
				end
			end
		elseif action == "FlashLight" then
			if step.targetId ~= nil then
				orbitController:TriggerLightFlash(step.targetId, step.peakBrightness, step.peakRange, step.duration)
			elseif step.targetTag ~= nil then
				for _, target in ipairs(collectTargets(registry, step)) do
					if target:IsA("PointLight") then
						local lightId = target:GetAttribute("VFXEngineId")
						if type(lightId) == "string" then
							orbitController:TriggerLightFlash(
								lightId,
								step.peakBrightness,
								step.peakRange,
								step.duration
							)
						end
					end
				end
			end
		elseif action == "SetOrbitSpeed" then
			local group = step.targetId or "default"
			local mult = if step.speedMultiplier ~= nil then step.speedMultiplier else 1
			orbitController:SetGroupSpeedMultiplier(group, mult)
		elseif action == "SetOrbitRadiusScale" then
			local group = step.targetId or "default"
			local mult = if step.radiusMultiplier ~= nil then step.radiusMultiplier else 1
			orbitController:SetGroupRadiusMultiplier(group, mult)
		end
	end

	local function runCycle(expectedGen: number)
		if destroyed or generation ~= expectedGen then
			return
		end

		for _, step in ipairs(steps) do
			if step.time <= 0 then
				executeStep(step)
			else
				local thread = task.delay(step.time, function()
					if destroyed or generation ~= expectedGen then
						return
					end
					executeStep(step)
				end)
				table.insert(activeThreads, thread)
			end
		end

		if isLoop then
			local loopThread = task.delay(loopDuration, function()
				if destroyed or generation ~= expectedGen then
					return
				end
				runCycle(expectedGen)
			end)
			table.insert(activeThreads, loopThread)
		end
	end

	local function resetDefaults()
		for inst, wasEnabled in pairs(initialEnabled) do
			if inst.Parent ~= nil then
				if inst:IsA("Trail") then
					inst:Clear()
				end
				setInstanceEnabled(inst, wasEnabled)
			end
		end

		for _, beamMeta in pairs(registry.beamMetaById) do
			if beamMeta.instance.Parent ~= nil then
				beamMeta.instance.Width0 = beamMeta.baseWidth0
				beamMeta.instance.Width1 = beamMeta.baseWidth1
			end
		end

		for _, grp in ipairs(orbitGroups) do
			orbitController:SetGroupSpeedMultiplier(grp, 1)
			orbitController:SetGroupRadiusMultiplier(grp, 1)
		end
	end

	local handle: Types.TimelineHandle = {
		Start = function(_self: Types.TimelineHandle)
			if destroyed then
				return
			end
			cancelScheduledWork()
			local currentGen = generation
			runCycle(currentGen)
		end,

		Replay = function(self: Types.TimelineHandle)
			if destroyed then
				return
			end
			cancelScheduledWork()
			resetDefaults()
			self:Start()
		end,

		Destroy = function(_self: Types.TimelineHandle)
			if destroyed then
				return
			end
			destroyed = true
			cancelScheduledWork()
			table.clear(initialEnabled)
		end,
	}

	return handle
end

return TimelineRunner
