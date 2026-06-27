-- ScreenVideoManager.luau
-- Plays video on all Screen parts by cycling in batches of 2
-- (Roblox allows at most 2 simultaneous videos).
-- Each batch plays for PLAY_SECONDS from the 6s mark,
-- then pauses (frozen frame) to free a slot for the next batch.

local Players = game:GetService("Players")

local ScreenVideoManager = {}
local activeRunId = 0
local sessionStart = 0

local VIDEO_ASSET_ID = "rbxassetid://134038033367163"
local MAX_SIMULTANEOUS = 2
local SEEK_TARGET = 6
local PLAY_SECONDS = 1
local MAX_LOAD_WAIT = 8

local function log(msg)
	local t = tick() - sessionStart
	print(string.format("[VIDEO %.2fs] %s", t, msg))
end

local function logWarn(msg)
	local t = tick() - sessionStart
	warn(string.format("[VIDEO %.2fs] %s", t, msg))
end

local function detectBestFace(part: BasePart): Enum.NormalId
	local size = part.Size
	if size.Z <= size.X and size.Z <= size.Y then
		return Enum.NormalId.Back
	elseif size.X <= size.Y and size.X <= size.Z then
		return Enum.NormalId.Left
	end
	return Enum.NormalId.Top
end

local function clearScreenDecals(screen: BasePart, computerName: string)
	local cleared = 0
	for _, child in pairs(screen:GetChildren()) do
		if child:IsA("Decal") or child:IsA("Texture") or child:IsA("SurfaceGui") then
			log(computerName .. ": Clearing existing " .. child.ClassName .. " '" .. child.Name .. "'")
			child:Destroy()
			cleared += 1
		end
	end
	if cleared > 0 then
		log(computerName .. ": Cleared " .. cleared .. " existing decals/GUIs from screen")
	end
end

local function waitForVideoLoad(videoFrame, idx)
	if videoFrame.IsLoaded then
		log("Video #" .. idx .. " already loaded")
	else
		log("Video #" .. idx .. " waiting to load...")

		local loaded = false
		local conn = videoFrame:GetPropertyChangedSignal("IsLoaded"):Connect(function()
			if videoFrame.IsLoaded then loaded = true end
		end)

		if videoFrame.IsLoaded then
			conn:Disconnect()
		else
			local waited = 0
			while not loaded and waited < MAX_LOAD_WAIT do
				task.wait(0.2)
				waited += 0.2
			end
			conn:Disconnect()

			if not videoFrame.IsLoaded then
				logWarn("Video #" .. idx .. " FAILED to load after " .. string.format("%.1f", waited) .. "s")
				return false
			end
		end
	end

	-- Wait for TimeLength to become valid (can lag behind IsLoaded)
	local lengthWait = 0
	while videoFrame.TimeLength <= 0 and lengthWait < 1 do
		task.wait(0.05)
		lengthWait += 0.05
	end

	log("Video #" .. idx .. " ready | Length=" .. string.format("%.1f", videoFrame.TimeLength) .. "s")
	return true
end

local function seekAndVerify(vf, target, name)
	local length = vf.TimeLength
	local originalTarget = target

	if length > 0 and target >= length then
		logWarn(name .. ": Video only " .. string.format("%.1f", length) .. "s, can't seek to " .. target .. "s. Clamping.")
		target = math.max(0, length - PLAY_SECONDS - 0.5)
	end

	local beforeSeek = vf.TimePosition
	vf.TimePosition = target
	task.wait(0.05)

	local afterSeek = vf.TimePosition

	if math.abs(afterSeek - target) > 1 then
		log(name .. ": Seek retry (was " .. string.format("%.2f", afterSeek) .. ", wanted " .. string.format("%.2f", target) .. ")")
		vf.TimePosition = target
		task.wait(0.05)
		afterSeek = vf.TimePosition
	end

	log(name .. ": Seek complete | Before=" .. string.format("%.2f", beforeSeek) .. "s -> After=" .. string.format("%.2f", afterSeek) .. "s (target=" .. string.format("%.2f", target) .. ")")

	return afterSeek
end

function ScreenVideoManager.Setup(computerRoom: Instance)
	sessionStart = tick()
	local allVideos = {}

	if not computerRoom then
		logWarn("No container provided")
		return allVideos
	end

	log("=== SETUP START ===")

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local container = Instance.new("ScreenGui")
	container.Name = "ScreenVideoContainer"
	container.ResetOnSpawn = false
	container.Parent = playerGui

	local screenCount = 0
	
	-- Helper function to setup a single computer screen
	local function setupComputer(computerName: string)
		log("--- Setting up " .. computerName .. " ---")
		local computer = computerRoom:FindFirstChild(computerName)
		if not computer then
			logWarn(computerName .. ": NOT FOUND in ComputerRoom!")
			log("Available children: " .. table.concat(
				(function()
					local names = {}
					for _, c in pairs(computerRoom:GetChildren()) do
						table.insert(names, c.Name)
					end
					return names
				end)(), ", "
			))
			return nil
		end
		
		log(computerName .. ": Found! Searching for Screen part...")
		
		-- Search all descendants for a Screen part
		local screen = nil
		local allParts = {}
		for _, desc in pairs(computer:GetDescendants()) do
			if desc:IsA("BasePart") then
				table.insert(allParts, desc.Name)
			end
			if desc.Name == "Screen" and desc:IsA("BasePart") then
				screen = desc
				log(computerName .. ": Found Screen at " .. desc:GetFullName())
				break
			end
		end
		
		if not screen then
			logWarn(computerName .. ": No Screen BasePart found!")
			log(computerName .. ": Available BaseParts: " .. table.concat(allParts, ", "))
			return nil
		end
		
		-- Don't clear decals - just add our SurfaceGui on top
		-- clearScreenDecals(screen, computerName)
		
		screenCount += 1
		local face = detectBestFace(screen)
		log(computerName .. ": Screen size=" .. tostring(screen.Size) .. " | Best face=" .. tostring(face))

		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "ScreenVideo_" .. computerName
		surfaceGui.Adornee = screen
		surfaceGui.Face = face
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surfaceGui.PixelsPerStud = 50
		surfaceGui.AlwaysOnTop = false
		surfaceGui.LightInfluence = 0
		surfaceGui.Brightness = 1
		surfaceGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		surfaceGui.Parent = container

		local videoFrame = Instance.new("VideoFrame")
		videoFrame.Name = "Video_" .. computerName
		videoFrame.Size = UDim2.new(1, 0, 1, 0)
		videoFrame.BackgroundColor3 = Color3.new(0, 0, 0)
		videoFrame.BorderSizePixel = 0
		videoFrame.Video = VIDEO_ASSET_ID
		videoFrame.Looped = false
		videoFrame.Volume = 0
		videoFrame.Parent = surfaceGui

		log(computerName .. ": VideoFrame created | Adornee=" .. screen:GetFullName())
		return videoFrame
	end
	
	-- PRIORITY ORDER: computers 1-4 first, then 5-8
	log("=== Setting up PRIORITY screens (computer1-4) ===")
	for i = 1, 4 do
		local vf = setupComputer("computer" .. i)
		if vf then
			table.insert(allVideos, vf)
		end
	end
	
	log("=== Setting up SECONDARY screens (computer5-8) ===")
	for i = 5, 8 do
		local vf = setupComputer("computer" .. i)
		if vf then
			table.insert(allVideos, vf)
		end
	end
	
	log("=== TOTAL: " .. #allVideos .. " screens configured ===")

	log("Found " .. #allVideos .. " screens (computer1-8), starting async pre-load...")

	-- Pre-load videos asynchronously (don't block)
	task.spawn(function()
		for idx, vf in ipairs(allVideos) do
			waitForVideoLoad(vf, idx)
		end
		log("All videos pre-loaded!")
	end)

	log("=== SETUP COMPLETE === " .. #allVideos .. " screens created (loading in background)")
	return allVideos
end

function ScreenVideoManager.PlayAll(allVideos, delaySeconds)
	if #allVideos == 0 then return end

	activeRunId += 1
	local myRunId = activeRunId

	log("=== PLAYALL START === RunID=" .. myRunId .. " | " .. #allVideos .. " screens" .. (delaySeconds and (" | delay=" .. delaySeconds .. "s") or ""))

	task.spawn(function()
		-- Cancellable delay before starting playback
		if delaySeconds and delaySeconds > 0 then
			log("Waiting " .. delaySeconds .. "s before starting video sequence...")
			task.wait(delaySeconds)
			if activeRunId ~= myRunId then
				log("Run cancelled during initial delay")
				return
			end
		end

		local batchNum = 0
		local i = 1
		while i <= #allVideos and activeRunId == myRunId do
			batchNum += 1
			local batch = {}
			for j = i, math.min(i + MAX_SIMULTANEOUS - 1, #allVideos) do
				table.insert(batch, allVideos[j])
			end

			-- Build batch info string
			local batchNames = {}
			for _, vf in ipairs(batch) do
				table.insert(batchNames, vf.Name)
			end
			log("╔══════════════════════════════════════════════════════════════")
			log("║ BATCH #" .. batchNum .. ": " .. table.concat(batchNames, ", "))
			log("╚══════════════════════════════════════════════════════════════")

			-- Quick load check for this batch (wait up to 2s if not loaded yet)
			for _, vf in ipairs(batch) do
				local name = vf.Name
				if not vf.IsLoaded then
					log(name .. ": Waiting for video to load...")
					local waited = 0
					while not vf.IsLoaded and waited < 2 do
						task.wait(0.1)
						waited += 0.1
					end
					if vf.IsLoaded then
						log(name .. ": Loaded after " .. string.format("%.1f", waited) .. "s")
					else
						logWarn(name .. ": STILL NOT LOADED after 2s wait!")
					end
				else
					log(name .. ": Already loaded")
				end
			end

			-- Start playback
			for _, vf in ipairs(batch) do
				local name = vf.Name
				log(name .. ": Calling Play()...")
				vf:Play()
				log(name .. ": Play() done | IsLoaded=" .. tostring(vf.IsLoaded) .. " | Playing=" .. tostring(vf.Playing) .. " | TimePos=" .. string.format("%.2f", vf.TimePosition) .. " | TimeLength=" .. string.format("%.1f", vf.TimeLength))
			end

			-- Let the player initialize
			log("Waiting 0.15s for player init...")
			task.wait(0.15)
			if activeRunId ~= myRunId then
				log("Run cancelled during init wait")
				break
			end

			-- Check state after init
			for _, vf in ipairs(batch) do
				local name = vf.Name
				log(name .. ": After init | Playing=" .. tostring(vf.Playing) .. " | TimePos=" .. string.format("%.2f", vf.TimePosition))
			end

			-- Seek to SEEK_TARGET
			log("Seeking all to " .. SEEK_TARGET .. "s...")
			for _, vf in ipairs(batch) do
				local name = vf.Name
				seekAndVerify(vf, SEEK_TARGET, name)
			end

			-- Record start time for this batch's visible playback
			local playStartTime = tick()
			for _, vf in ipairs(batch) do
				local name = vf.Name
				log(name .. ": >>> PLAYING NOW <<< | TimePos=" .. string.format("%.2f", vf.TimePosition) .. " | Playing=" .. tostring(vf.Playing))
			end

			-- Wait for visible playback
			log("Playing for " .. PLAY_SECONDS .. " seconds...")
			task.wait(PLAY_SECONDS)

			local actualPlayTime = tick() - playStartTime
			if activeRunId ~= myRunId then
				log("Run cancelled during playback")
				break
			end

			-- Freeze this batch
			log("Freezing batch #" .. batchNum .. "...")
			for _, vf in ipairs(batch) do
				local name = vf.Name
				local endPos = vf.TimePosition
				vf:Pause()
				log(name .. ": FROZEN at " .. string.format("%.2f", endPos) .. "s | Played for " .. string.format("%.2f", actualPlayTime) .. "s")
			end
			log("Batch #" .. batchNum .. " complete, moving to next...")

			i = i + MAX_SIMULTANEOUS
		end

		if activeRunId == myRunId then
			log("=== PLAYALL COMPLETE === All " .. #allVideos .. " screens done!")
		end
	end)
end

function ScreenVideoManager.StopAll(allVideos)
	log("=== STOPALL called ===")
	activeRunId += 1
	for _, vf in ipairs(allVideos) do
		vf:Pause()
	end
end

return ScreenVideoManager
