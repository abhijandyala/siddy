-- ChefNPCAnimations.server.luau
-- Plays custom animations for Chef environment NPCs during menu flythrough
-- Animations sync with the 3-second Chef camera view and restart each loop
-- Also supports on-demand playback via RemoteEvent for chef job sequence

-- DISABLED: This script was interfering with ChefWorld game
-- The NPC animations were running during gameplay which is not needed
print("=== ChefNPCAnimations DISABLED - not needed for ChefWorld game ===")
do return end  -- Early exit - script will not run

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("=== ChefNPCAnimations server script loaded ===")

-- Create RemoteEvent for client to request animation playback
local playChefNPCAnimsEvent = Instance.new("RemoteEvent")
playChefNPCAnimsEvent.Name = "PlayChefNPCAnimations"
playChefNPCAnimsEvent.Parent = ReplicatedStorage

-- Animation IDs (from user's uploaded animations)
local ANIMATIONS = {
	{
		npcName = "Customer",
		animationId = "rbxassetid://121217627082015",  -- CustomerStockAnimation
	},
	{
		npcName = "McDonaldsWorkerCahsier",
		animationId = "rbxassetid://106394146510183",  -- McDonaldsCashierNPCAnimation
	},
	{
		npcName = "McdonaldsCook_Display_only",
		animationId = "rbxassetid://135391000807181",  -- McDonaldsStockerAnimation
	},
}

-- Timing configuration (must match MenuCameraFlythrough.client.luau EXACTLY)
local CINEMATIC_END_TIME = 6.0   -- When cinematic ends and menu starts
local CAMERA_DURATION = 3.0      -- Each camera shows for 3 seconds
local LOOP_DURATION = 9.0        -- Full loop: Cyber(3) + Chef(3) + Hospital(3)

-- Chef camera starts AFTER Cyber (3 seconds into menu)
-- First Chef camera time from game start: 6.2 + 3.0 = 9.2s
local FIRST_CHEF_TIME = CINEMATIC_END_TIME + CAMERA_DURATION  -- 9.2s

-- Track loaded animations
local loadedAnimations = {}
local animationTracks = {}

-- Find Chef environment
local function findChefEnvironment()
	local environments = workspace:FindFirstChild("Environments")
	if not environments then
		warn("ChefNPCAnimations: Could not find Environments folder!")
		return nil
	end
	
	local chef = environments:FindFirstChild("Chef")
	if not chef then
		warn("ChefNPCAnimations: Could not find Chef environment!")
		return nil
	end
	
	return chef
end

-- Find NPC and its animator (searches recursively)
local function findNPCAnimator(chefEnv, npcName)
	-- First try direct child
	local npc = chefEnv:FindFirstChild(npcName)
	
	-- If not found, search all descendants
	if not npc then
		for _, desc in pairs(chefEnv:GetDescendants()) do
			if desc.Name == npcName then
				npc = desc
				print("ChefNPCAnimations: Found " .. npcName .. " as descendant")
				break
			end
		end
	end
	
	-- Still not found? Try case-insensitive and partial match
	if not npc then
		local lowerName = string.lower(npcName)
		for _, desc in pairs(chefEnv:GetDescendants()) do
			if string.lower(desc.Name) == lowerName then
				npc = desc
				print("ChefNPCAnimations: Found " .. desc.Name .. " (case-insensitive match for " .. npcName .. ")")
				break
			end
		end
	end
	
	if not npc then
		warn("ChefNPCAnimations: Could not find NPC: " .. npcName)
		-- List all children for debugging
		print("ChefNPCAnimations: Available children in Chef environment:")
		for _, child in pairs(chefEnv:GetChildren()) do
			print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
		end
		return nil, nil
	end
	
	print("ChefNPCAnimations: Found NPC: " .. npc.Name)
	
	-- Find Humanoid (search in descendants too)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = npc:FindFirstChildWhichIsA("Humanoid", true)  -- Recursive search
	end
	
	if not humanoid then
		warn("ChefNPCAnimations: No Humanoid found in " .. npcName)
		-- List children for debugging
		print("ChefNPCAnimations: Children of " .. npcName .. ":")
		for _, child in pairs(npc:GetChildren()) do
			print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
		end
		return nil, nil
	end
	
	print("ChefNPCAnimations: Found Humanoid in " .. npc.Name)
	
	-- Find or create Animator
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
		print("ChefNPCAnimations: Created Animator for " .. npcName)
	end
	
	return npc, animator
end

-- Load all animations
local function loadAnimations()
	local chefEnv = findChefEnvironment()
	if not chefEnv then return false end
	
	print("ChefNPCAnimations: Loading animations...")
	print("ChefNPCAnimations: Chef environment children:")
	for _, child in pairs(chefEnv:GetChildren()) do
		print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
	end
	
	for _, animData in ipairs(ANIMATIONS) do
		print("ChefNPCAnimations: --- Loading animation for " .. animData.npcName .. " ---")
		print("ChefNPCAnimations: Animation ID: " .. animData.animationId)
		
		local npc, animator = findNPCAnimator(chefEnv, animData.npcName)
		
		if animator then
			-- Create animation instance
			local animation = Instance.new("Animation")
			animation.AnimationId = animData.animationId
			
			-- Load the animation track
			print("ChefNPCAnimations: Loading animation track...")
			local success, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			
			if not success then
				warn("ChefNPCAnimations: Failed to load animation: " .. tostring(track))
			else
				-- Wait for animation to load
				local waited = 0
				while track.Length == 0 and waited < 5 do
					task.wait(0.1)
					waited = waited + 0.1
				end
				
				if track.Length > 0 then
					-- Configure track
					track.Looped = false  -- We'll manually restart for sync
					track.Priority = Enum.AnimationPriority.Action4
					
					animationTracks[animData.npcName] = track
					print("ChefNPCAnimations: SUCCESS - Loaded animation for " .. animData.npcName .. " (Length: " .. track.Length .. "s)")
				else
					warn("ChefNPCAnimations: Animation track has zero length for " .. animData.npcName .. " (waited " .. waited .. "s)")
				end
			end
		else
			warn("ChefNPCAnimations: No animator found for " .. animData.npcName .. " - skipping")
		end
	end
	
	return true
end

-- Play all Chef NPC animations
local function playAllAnimations()
	print("ChefNPCAnimations: >>> Playing all Chef NPC animations <<<")
	
	for npcName, track in pairs(animationTracks) do
		-- Stop first (in case it was playing)
		track:Stop(0)
		-- Reset to beginning
		track.TimePosition = 0
		-- Play from start
		track:Play(0)
		print("ChefNPCAnimations: Playing animation for " .. npcName)
	end
end

-- Stop all Chef NPC animations
local function stopAllAnimations()
	for npcName, track in pairs(animationTracks) do
		track:Stop(0.2)  -- Small fade out
	end
end

-- Main animation loop - uses absolute timing from game start
local function startAnimationLoop(gameStartTime)
	print("ChefNPCAnimations: Starting animation sync loop (game started at " .. gameStartTime .. ")")
	
	-- Calculate when first Chef camera starts
	local nextChefTime = FIRST_CHEF_TIME
	
	-- Infinite loop to sync with menu camera
	while true do
		-- Calculate how long to wait until next Chef camera
		local currentTime = tick() - gameStartTime
		local waitTime = nextChefTime - currentTime
		
		if waitTime > 0 then
			print("ChefNPCAnimations: Waiting " .. string.format("%.2f", waitTime) .. "s until Chef camera (at " .. string.format("%.2f", nextChefTime) .. "s)")
			task.wait(waitTime)
		end
		
		-- Chef camera is now active - play animations!
		print("ChefNPCAnimations: >>> CHEF CAMERA NOW - Playing animations! <<<")
		playAllAnimations()
		
		-- Next Chef camera is one full loop later (9 seconds)
		nextChefTime = nextChefTime + LOOP_DURATION
		
		-- Wait a bit before checking again (Chef camera lasts 3 seconds)
		task.wait(CAMERA_DURATION)
		
		print("ChefNPCAnimations: Chef camera done, next at " .. string.format("%.2f", nextChefTime) .. "s")
	end
end

-- Track game start time
local GAME_START_TIME = tick()
print("ChefNPCAnimations: Game start time recorded: " .. GAME_START_TIME)

-- Initialize - load animations immediately, then start loop with precise timing
local function initialize()
	print("ChefNPCAnimations: Initializing...")
	
	-- Load all animations immediately (no extra wait)
	local success = loadAnimations()
	
	if success and next(animationTracks) then
		local animCount = 0
		for _ in pairs(animationTracks) do animCount = animCount + 1 end
		print("ChefNPCAnimations: " .. animCount .. " animations loaded, starting sync loop...")
		startAnimationLoop(GAME_START_TIME)
	else
		warn("ChefNPCAnimations: Failed to load animations!")
	end
end

-- Listen for client requests to play chef NPC animations (for chef job sequence)
playChefNPCAnimsEvent.OnServerEvent:Connect(function(player)
	print("ChefNPCAnimations: Received request from " .. player.Name .. " to play animations")
	playAllAnimations()
end)

-- Start initialization
initialize()
