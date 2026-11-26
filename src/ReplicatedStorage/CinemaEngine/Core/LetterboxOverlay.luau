--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)

local LetterboxOverlay = {}

local GUI_NAME = "__CinemaEngine_LetterboxGui"

export type OverlayHandle = {
	Update: (self: OverlayHandle, elapsed: number, totalDuration: number) -> (),
	Close: (self: OverlayHandle, fadeOutDuration: number?) -> (),
	Destroy: (self: OverlayHandle) -> (),
}

local function smoothstep(alpha: number): number
	local t = math.clamp(alpha, 0, 1)
	return t * t * (3 - 2 * t)
end

local function resolveCueEnd(cue: Types.SubtitleCue, nextCue: Types.SubtitleCue?, totalDuration: number): number
	if cue.endTime ~= nil then
		return cue.endTime
	end
	if cue.duration ~= nil then
		return cue.startTime + math.max(0.05, cue.duration)
	end
	if nextCue ~= nil then
		return nextCue.startTime
	end
	return totalDuration
end

function LetterboxOverlay.New(
	letterboxSpec: Types.LetterboxTrackSpec?,
	subtitles: { Types.SubtitleCue }?
): OverlayHandle
	local destroyed = false
	local closing = false
	local closeConn: RBXScriptConnection? = nil

	local screenGui: ScreenGui? = nil
	local topBar: Frame? = nil
	local bottomBar: Frame? = nil
	local titleLabel: TextLabel? = nil
	local headingLabel: TextLabel? = nil
	local subtitleLabel: TextLabel? = nil

	local spec: Types.LetterboxTrackSpec = letterboxSpec or {}
	local barsEnabled = spec.enabled ~= false
	local targetRatio = math.clamp(spec.barRatio or 0.115, 0, 0.35)
	local barColor = spec.color or Color3.new(0, 0, 0)
	local fadeInDuration = math.max(0, spec.fadeInDuration or 0.35)
	local fadeOutDuration = math.max(0, spec.fadeOutDuration or 0.35)
	local titleDuration = math.max(0.5, spec.titleDuration or 2.4)
	local currentBarRatio = 0

	local sortedCues: { Types.SubtitleCue } = {}
	if subtitles ~= nil and #subtitles > 0 then
		sortedCues = table.clone(subtitles)
		table.sort(sortedCues, function(a, b)
			return a.startTime < b.startTime
		end)
	end

	local function buildGui()
		if not RunService:IsClient() then
			return
		end
		local localPlayer = Players.LocalPlayer
		if localPlayer == nil then
			return
		end
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui") or localPlayer:WaitForChild("PlayerGui", 5)
		if playerGui == nil then
			return
		end

		-- Clean up any leftover overlay from previous interrupted runs
		local existing = playerGui:FindFirstChild(GUI_NAME)
		if existing ~= nil then
			existing:Destroy()
		end

		local gui = Instance.new("ScreenGui")
		gui.Name = GUI_NAME
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 50
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

		local top = Instance.new("Frame")
		top.Name = "TopBar"
		top.BorderSizePixel = 0
		top.BackgroundColor3 = barColor
		top.Position = UDim2.fromScale(0, 0)
		top.Size = UDim2.fromScale(1, 0)
		top.Visible = barsEnabled
		top.Parent = gui

		local bottom = Instance.new("Frame")
		bottom.Name = "BottomBar"
		bottom.BorderSizePixel = 0
		bottom.BackgroundColor3 = barColor
		bottom.AnchorPoint = Vector2.new(0, 1)
		bottom.Position = UDim2.fromScale(0, 1)
		bottom.Size = UDim2.fromScale(1, 0)
		bottom.Visible = barsEnabled
		bottom.Parent = gui

		if spec.subtitleHeading ~= nil and spec.subtitleHeading ~= "" then
			local heading = Instance.new("TextLabel")
			heading.Name = "CutsceneHeading"
			heading.BackgroundTransparency = 1
			heading.AnchorPoint = Vector2.new(0.5, 0)
			heading.Position = UDim2.new(0.5, 0, targetRatio + 0.03, 0)
			heading.Size = UDim2.new(0.8, 0, 0, 24)
			heading.Font = Enum.Font.GothamMedium
			heading.Text = spec.subtitleHeading
			heading.TextColor3 = Color3.fromRGB(205, 225, 255)
			heading.TextSize = 15
			heading.TextTransparency = 1
			heading.TextStrokeTransparency = 1
			heading.TextStrokeColor3 = Color3.new(0, 0, 0)
			heading.Parent = gui
			headingLabel = heading
		end

		if spec.title ~= nil and spec.title ~= "" then
			local title = Instance.new("TextLabel")
			title.Name = "CutsceneTitle"
			title.BackgroundTransparency = 1
			title.AnchorPoint = Vector2.new(0.5, 0)
			title.Position = UDim2.new(0.5, 0, targetRatio + 0.06, 0)
			title.Size = UDim2.new(0.85, 0, 0, 44)
			title.Font = Enum.Font.GothamBold
			title.Text = spec.title
			title.TextColor3 = Color3.new(1, 1, 1)
			title.TextSize = 30
			title.TextTransparency = 1
			title.TextStrokeTransparency = 1
			title.TextStrokeColor3 = Color3.new(0, 0, 0)

			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(0, 0, 0)
			stroke.Thickness = 1.6
			stroke.Transparency = 1
			stroke.Parent = title

			title.Parent = gui
			titleLabel = title
		end

		local sub = Instance.new("TextLabel")
		sub.Name = "SubtitleText"
		sub.BackgroundTransparency = 1
		sub.AnchorPoint = Vector2.new(0.5, 0.5)
		sub.Position = UDim2.new(0.5, 0, 1 - math.max(targetRatio * 0.5, 0.06), 0)
		sub.Size = UDim2.new(0.84, 0, 0, 56)
		sub.Font = Enum.Font.GothamMedium
		sub.Text = ""
		sub.TextWrapped = true
		sub.TextColor3 = Color3.new(1, 1, 1)
		sub.TextSize = 22
		sub.TextTransparency = 1
		sub.TextStrokeTransparency = 1
		sub.TextStrokeColor3 = Color3.new(0, 0, 0)
		sub.ZIndex = 5

		local subStroke = Instance.new("UIStroke")
		subStroke.Color = Color3.new(0, 0, 0)
		subStroke.Thickness = 1.5
		subStroke.Transparency = 1
		subStroke.Parent = sub

		sub.Parent = gui

		gui.Parent = playerGui
		screenGui = gui
		topBar = top
		bottomBar = bottom
		subtitleLabel = sub
	end

	buildGui()

	local function applyBarRatio(ratio: number)
		currentBarRatio = ratio
		if topBar ~= nil then
			topBar.Size = UDim2.fromScale(1, ratio)
		end
		if bottomBar ~= nil then
			bottomBar.Size = UDim2.fromScale(1, ratio)
		end
	end

	local function setTextAlpha(label: TextLabel?, alpha: number)
		if label == nil then
			return
		end
		local clamped = math.clamp(alpha, 0, 1)
		local transparency = 1 - clamped
		label.TextTransparency = transparency
		label.TextStrokeTransparency = 1 - clamped * 0.75
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke ~= nil then
			stroke.Transparency = 1 - clamped * 0.85
		end
	end

	local handle: OverlayHandle

	local function destroyImmediate()
		if destroyed then
			return
		end
		destroyed = true
		if closeConn ~= nil then
			closeConn:Disconnect()
			closeConn = nil
		end
		if screenGui ~= nil then
			screenGui:Destroy()
			screenGui = nil
		end
		topBar = nil
		bottomBar = nil
		titleLabel = nil
		headingLabel = nil
		subtitleLabel = nil
	end

	handle = {
		Update = function(_self: OverlayHandle, elapsed: number, totalDuration: number)
			if destroyed or closing or screenGui == nil then
				return
			end

			if barsEnabled then
				local barAlpha = 1
				if fadeInDuration > 0 and elapsed < fadeInDuration then
					barAlpha = smoothstep(elapsed / fadeInDuration)
				elseif fadeOutDuration > 0 and totalDuration > fadeOutDuration and elapsed > (totalDuration - fadeOutDuration) then
					barAlpha = smoothstep((totalDuration - elapsed) / fadeOutDuration)
				end
				applyBarRatio(targetRatio * barAlpha)
			end

			local titleAlpha = 0
			if titleLabel ~= nil or headingLabel ~= nil then
				local tFadeIn = math.min(0.4, titleDuration * 0.25)
				local tFadeOut = math.min(0.5, titleDuration * 0.3)
				if elapsed >= 0 and elapsed <= titleDuration then
					if tFadeIn > 0 and elapsed < tFadeIn then
						titleAlpha = smoothstep(elapsed / tFadeIn)
					elseif tFadeOut > 0 and elapsed > (titleDuration - tFadeOut) then
						titleAlpha = smoothstep((titleDuration - elapsed) / tFadeOut)
					else
						titleAlpha = 1
					end
				end
				setTextAlpha(titleLabel, titleAlpha)
				setTextAlpha(headingLabel, titleAlpha)
			end

			if subtitleLabel ~= nil then
				local activeCue: Types.SubtitleCue? = nil
				local activeEnd = 0
				for i, cue in ipairs(sortedCues) do
					local nextCue = sortedCues[i + 1]
					local endTime = resolveCueEnd(cue, nextCue, totalDuration)
					if elapsed >= cue.startTime and elapsed <= endTime then
						activeCue = cue
						activeEnd = endTime
						break
					end
				end

				if activeCue ~= nil then
					local displayText = if activeCue.speaker ~= nil and activeCue.speaker ~= ""
						then string.format("%s: %s", activeCue.speaker, activeCue.text)
						else activeCue.text
					subtitleLabel.Text = displayText
					subtitleLabel.TextColor3 = activeCue.color or Color3.new(1, 1, 1)

					local cIn = math.max(0, activeCue.fadeIn or 0.16)
					local cOut = math.max(0, activeCue.fadeOut or 0.18)
					local cueElapsed = elapsed - activeCue.startTime
					local cueRemain = activeEnd - elapsed
					local subAlpha = 1
					if cIn > 0 and cueElapsed < cIn then
						subAlpha = math.min(subAlpha, smoothstep(cueElapsed / cIn))
					end
					if cOut > 0 and cueRemain < cOut then
						subAlpha = math.min(subAlpha, smoothstep(cueRemain / cOut))
					end
					setTextAlpha(subtitleLabel, subAlpha)
				else
					subtitleLabel.Text = ""
					setTextAlpha(subtitleLabel, 0)
				end
			end
		end,

		Close = function(_self: OverlayHandle, overrideFadeOut: number?)
			if destroyed or closing then
				return
			end
			closing = true
			local dur = if overrideFadeOut ~= nil then math.max(0, overrideFadeOut) else fadeOutDuration
			if dur <= 0 or screenGui == nil then
				destroyImmediate()
				return
			end

			local startRatio = currentBarRatio
			local startTitleAlpha = if titleLabel ~= nil then (1 - titleLabel.TextTransparency) else 0
			local startSubAlpha = if subtitleLabel ~= nil then (1 - subtitleLabel.TextTransparency) else 0
			local closeElapsed = 0

			closeConn = RunService.Heartbeat:Connect(function(dt: number)
				if destroyed then
					return
				end
				closeElapsed += math.min(dt, 0.1)
				local alpha = math.clamp(closeElapsed / dur, 0, 1)
				local inv = 1 - smoothstep(alpha)
				applyBarRatio(startRatio * inv)
				setTextAlpha(titleLabel, startTitleAlpha * inv)
				setTextAlpha(headingLabel, startTitleAlpha * inv)
				setTextAlpha(subtitleLabel, startSubAlpha * inv)

				if alpha >= 1 then
					destroyImmediate()
				end
			end)
		end,

		Destroy = function(_self: OverlayHandle)
			destroyImmediate()
		end,
	}

	return handle
end

return LetterboxOverlay
