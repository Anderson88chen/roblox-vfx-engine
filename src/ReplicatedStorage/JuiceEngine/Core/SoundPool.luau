--!strict

local SoundService = game:GetService("SoundService")

local Types = require(script.Parent.Types)

local SoundPool = {}

local FOLDER_2D_NAME = "__JuiceEngine_Sounds_2D"
local MAX_2D_POOL = 24
local MAX_3D_POOL = 24
local DEFAULT_MAX_CONCURRENT = 6

type ActiveEntry = {
	sound: Sound,
	attachment: Attachment?,
	group: string,
	generation: number,
	endedConn: RBXScriptConnection?,
	fallbackThread: thread?,
}

local rng = Random.new()
local folder2D: Folder? = nil
local free2DPool: { Sound } = {}
local free3DPool: { Attachment } = {}
local created2D = 0
local created3D = 0

local activeByGroup: { [string]: { ActiveEntry } } = {}
local activeEntries: { ActiveEntry } = {}
local pendingDelayedThreads: { thread } = {}
local generationCounter = 0

local function getFolder2D(): Folder
	if folder2D ~= nil and folder2D.Parent ~= nil then
		return folder2D
	end
	local existing = SoundService:FindFirstChild(FOLDER_2D_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		folder2D = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_2D_NAME
	folder.Parent = SoundService
	folder2D = folder
	return folder
end

local function sampleRange(spec: Types.RangeSpec?, defaultMin: number, defaultMax: number): number
	if spec == nil then
		if defaultMin == defaultMax then
			return defaultMin
		end
		return rng:NextNumber(defaultMin, defaultMax)
	end
	if type(spec) == "number" then
		return spec
	end
	if typeof(spec) == "NumberRange" then
		if spec.Min == spec.Max then
			return spec.Min
		end
		return rng:NextNumber(spec.Min, spec.Max)
	end
	if type(spec) == "table" then
		local tbl = spec :: any
		local minV = if type(tbl.min) == "number"
			then tbl.min
			elseif type(tbl[1]) == "number" then tbl[1]
			else defaultMin
		local maxV = if type(tbl.max) == "number"
			then tbl.max
			elseif type(tbl[2]) == "number" then tbl[2]
			else minV
		if maxV < minV then
			minV, maxV = maxV, minV
		end
		if minV == maxV then
			return minV
		end
		return rng:NextNumber(minV, maxV)
	end
	return defaultMin
end

local function releaseEntry(entry: ActiveEntry)
	entry.generation += 1

	if entry.endedConn ~= nil then
		entry.endedConn:Disconnect()
		entry.endedConn = nil
	end
	if entry.fallbackThread ~= nil then
		pcall(task.cancel, entry.fallbackThread)
		entry.fallbackThread = nil
	end

	local groupList = activeByGroup[entry.group]
	if groupList ~= nil then
		local gIdx = table.find(groupList, entry)
		if gIdx ~= nil then
			table.remove(groupList, gIdx)
		end
		if #groupList == 0 then
			activeByGroup[entry.group] = nil
		end
	end

	local aIdx = table.find(activeEntries, entry)
	if aIdx ~= nil then
		table.remove(activeEntries, aIdx)
	end

	pcall(function()
		entry.sound:Stop()
	end)

	if entry.attachment ~= nil then
		if entry.attachment.Parent ~= nil and #free3DPool < MAX_3D_POOL then
			if table.find(free3DPool, entry.attachment) == nil then
				table.insert(free3DPool, entry.attachment)
			end
		end
	else
		if entry.sound.Parent ~= nil and #free2DPool < MAX_2D_POOL then
			if table.find(free2DPool, entry.sound) == nil then
				table.insert(free2DPool, entry.sound)
			end
		end
	end
end

local function pruneAndEnforceGroupLimit(group: string, maxConcurrent: number)
	local groupList = activeByGroup[group]
	if groupList == nil then
		return
	end

	-- Prune sounds that already finished playing before enforcing the cap
	local i = 1
	while i <= #groupList do
		local entry = groupList[i]
		if not entry.sound.IsPlaying then
			releaseEntry(entry)
		else
			i += 1
		end
	end

	groupList = activeByGroup[group]
	while groupList ~= nil and #groupList >= maxConcurrent do
		local oldest = groupList[1]
		if oldest == nil then
			break
		end
		releaseEntry(oldest)
		groupList = activeByGroup[group]
	end
end

local function acquire2DSound(): Sound
	while #free2DPool > 0 do
		local s = table.remove(free2DPool)
		if s ~= nil and s.Parent ~= nil then
			return s
		end
		created2D = math.max(0, created2D - 1)
	end

	created2D += 1
	local sound = Instance.new("Sound")
	sound.Name = "JuiceSound2D_" .. tostring(created2D)
	sound.Parent = getFolder2D()
	return sound
end

local function acquire3DAttachment(): (Attachment, Sound)
	while #free3DPool > 0 do
		local att = table.remove(free3DPool)
		if att ~= nil and att.Parent ~= nil then
			local childSound = att:FindFirstChildOfClass("Sound")
			if childSound ~= nil then
				return att, childSound
			end
			local newSound = Instance.new("Sound")
			newSound.Name = "JuiceSound3D"
			newSound.Parent = att
			return att, newSound
		end
		created3D = math.max(0, created3D - 1)
	end

	created3D += 1
	local att = Instance.new("Attachment")
	att.Name = "__JuiceEngine_SoundAtt_" .. tostring(created3D)
	att.Parent = workspace.Terrain

	local sound = Instance.new("Sound")
	sound.Name = "JuiceSound3D"
	sound.Parent = att

	return att, sound
end

local function playImmediate(spec: Types.SoundSpec, position: Vector3?, intensity: number)
	if spec.soundId == "" then
		return
	end

	local group = spec.group or "default"
	local maxConcurrent = math.max(1, spec.maxConcurrent or DEFAULT_MAX_CONCURRENT)
	pruneAndEnforceGroupLimit(group, maxConcurrent)

	local useSpatial = if spec.spatial ~= nil then spec.spatial else (position ~= nil)
	local sound: Sound
	local attachment: Attachment? = nil

	if useSpatial and position ~= nil then
		local att, s = acquire3DAttachment()
		attachment = att
		sound = s
		att.WorldPosition = position
	else
		sound = acquire2DSound()
	end

	local baseVolume = spec.volume or 0.7
	local sampledVolume = sampleRange(spec.volumeRange, baseVolume, baseVolume)
	local finalVolume = math.clamp(sampledVolume * math.clamp(0.65 + 0.35 * intensity, 0.25, 1.8), 0, 3)
	local finalPitch = math.clamp(sampleRange(spec.pitchRange, 0.95, 1.05), 0.2, 4)

	generationCounter += 1
	local gen = generationCounter

	local okConfigure = pcall(function()
		sound:Stop()
		sound.SoundId = spec.soundId
		sound.Volume = finalVolume
		sound.PlaybackSpeed = finalPitch
		sound.Looped = false
		if attachment ~= nil then
			sound.RollOffMode = Enum.RollOffMode.InverseTapered
			sound.RollOffMinDistance = math.max(1, spec.rollOffMinDistance or 10)
			sound.RollOffMaxDistance = math.max(sound.RollOffMinDistance + 1, spec.rollOffMaxDistance or 85)
		end
	end)

	if not okConfigure then
		if attachment ~= nil and #free3DPool < MAX_3D_POOL then
			table.insert(free3DPool, attachment)
		elseif attachment == nil and #free2DPool < MAX_2D_POOL then
			table.insert(free2DPool, sound)
		end
		return
	end

	local entry: ActiveEntry = {
		sound = sound,
		attachment = attachment,
		group = group,
		generation = gen,
		endedConn = nil,
		fallbackThread = nil,
	}

	local groupList = activeByGroup[group]
	if groupList == nil then
		groupList = {}
		activeByGroup[group] = groupList
	end
	table.insert(groupList, entry)
	table.insert(activeEntries, entry)

	entry.endedConn = sound.Ended:Connect(function()
		if entry.generation == gen then
			releaseEntry(entry)
		end
	end)

	-- Safety timeout so unloaded/streamed assets never leak a pool slot
	entry.fallbackThread = task.delay(4.0, function()
		if entry.generation == gen then
			entry.fallbackThread = nil
			releaseEntry(entry)
		end
	end)

	local okPlay = pcall(function()
		sound:Play()
	end)
	if not okPlay and entry.generation == gen then
		releaseEntry(entry)
	end
end

function SoundPool.Play(spec: Types.SoundSpec, position: Vector3?, intensity: number?)
	local inten = math.max(0, intensity or 1)
	local delaySec = spec.delay or 0
	if delaySec > 0 then
		local threadRef: thread
		threadRef = task.delay(delaySec, function()
			local idx = table.find(pendingDelayedThreads, threadRef)
			if idx ~= nil then
				table.remove(pendingDelayedThreads, idx)
			end
			playImmediate(spec, position, inten)
		end)
		table.insert(pendingDelayedThreads, threadRef)
		return
	end

	playImmediate(spec, position, inten)
end

function SoundPool.PlayList(specs: { Types.SoundSpec }, position: Vector3?, intensity: number?)
	for _, spec in ipairs(specs) do
		SoundPool.Play(spec, position, intensity)
	end
end

function SoundPool.StopAll()
	for _, th in ipairs(pendingDelayedThreads) do
		pcall(task.cancel, th)
	end
	table.clear(pendingDelayedThreads)

	local snapshot = table.clone(activeEntries)
	for _, entry in ipairs(snapshot) do
		releaseEntry(entry)
	end
end

return SoundPool
