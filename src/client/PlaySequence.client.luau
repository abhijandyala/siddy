-- PlaySequence.client.luau
-- Main game flow (after the player presses Play on the menu):
--   1. Instructions  (tutorial slides)
--   2. Aviation      (pilot world)
--   3. Chef
--   4. Nurse
--   5. Cyber         (final career)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")

local GameState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameState"))
local HackingBackground = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HackingBackground"))
local PasswordGame = require(script.Parent:WaitForChild("PasswordGame"))
local PhishingGame = require(script.Parent:WaitForChild("PhishingGame"))
local DecisionGame = require(script.Parent:WaitForChild("DecisionGame"))
local ScreenVideoManager = require(script.Parent:WaitForChild("ScreenVideoManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

print("=== PlaySequence loaded ===")

-- Hide Studio-made TutorialOverview immediately (we build our own in code)
local _tutOverlay = playerGui:FindFirstChild("TutorialOverview")
if _tutOverlay then
	_tutOverlay.Enabled = false
end

-- ============================================
-- CONFIGURATION
-- ============================================

local TUTORIAL_SLIDES = {
	{
		title = "Welcome player to Career Exploration!",
		body = "- You have fell asleep in school\n\n- To wake back up, you must complete all the jobs",
	},
	{
		title = "Rules",
		body = "- You will have to complete 3 puzzles per job\n\n- Each job will be graded out of x/100 points, then will be averaged at the end",
	},
	{
		title = "Good Luck!",
		body = "- If you can't finish the jobs and get a good score, you will be asleep forever!\n\n- Good luck chosen one",
	},
}

local SLIDE_DURATION = 5.0       -- Each slide shows for 5 seconds (15s total)
local SLIDE_FADE_TIME = 0.4      -- Fade in/out time for each slide
local LAB_REVEAL_DURATION = 1.0  -- Fade from black to reveal the lab

-- MC_cybersecurity animations
local RUNNING_INTRO_ANIM_ID = "rbxassetid://77313617388489" -- RunningIntoLabIntro
local TRANSITION_ANIM_ID = "rbxassetid://88044541232819" -- Plays right after running
local STANDING_STILL_ANIM_ID = "rbxassetid://91819686731627" -- StandingStillAnimation
local WALKING_TO_COMPUTER_ANIM_ID = "rbxassetid://121098232047165" -- WalkingToComputernewnew (1s, plays in first-person)

-- MC_chef animations
local WALKING_ANI_CHEF_ID = "rbxassetid://78240223263120" -- WalkingAniChef

-- ============================================
-- HELPER: FREEZE ANIMATION ON LAST FRAME
-- ============================================
-- DO NOT MOVE OR EDIT THIS FUNCTION - it is reused throughout the script

local function freezeOnLastFrame(track)
	if not track or track.Length <= 0 then return end
	
	local freezeTime = track.Length - 0.05
	while track.TimePosition < freezeTime do
		task.wait(0.05)
	end
	
	track:AdjustSpeed(0)
	track.TimePosition = track.Length - 0.01
	print("PlaySequence: Animation frozen on last frame! (Length: " .. track.Length .. "s)")
	
	task.spawn(function()
		while true do
			task.wait(0.1)
			track:AdjustSpeed(0)
			track.TimePosition = track.Length - 0.01
		end
	end)
end

-- ============================================
-- WAIT FOR GAME TO START
-- ============================================

if GameState.Started then
	print("PlaySequence: Game already started")
else
	print("PlaySequence: Waiting for game to start...")
	GameState.GameStartedEvent.Event:Wait()
end

print("PlaySequence: Game started! Beginning tutorial sequence...")

local UserInputService = game:GetService("UserInputService")

-- RESET CAMERA SETTINGS to prevent interference from other scripts
-- This ensures the cybersecurity section camera works correctly
player.CameraMinZoomDistance = 0.5
player.CameraMaxZoomDistance = 128
camera.FieldOfView = 70 -- Default FOV
-- Switch to Scriptable so Roblox's built-in first-person camera module cannot
-- re-lock the cursor during the tutorial slides. MenuBackground.cleanup() sets
-- CameraType = Custom when the game starts, which (if StarterPlayer or a prior
-- world left the zoom at 0.5) puts the player in first-person and locks the
-- cursor invisibly behind the overlay. Scriptable disables that entirely.
camera.CameraType = Enum.CameraType.Scriptable
UserInputService.MouseBehavior = Enum.MouseBehavior.Default
UserInputService.MouseIconEnabled = true
print("PlaySequence: Camera settings reset for cybersecurity section")

-- ============================================
-- SKIP BUTTON (bottom left, changes color per world)
-- ============================================

-- World colors
local WORLD_COLORS = {
	Aviation = Color3.fromRGB(56, 160, 235),  -- Sky blue
	Cyber = Color3.fromRGB(60, 140, 255),    -- Blue
	Medical = Color3.fromRGB(74, 222, 128),   -- Green
	Chef = Color3.fromRGB(251, 146, 60),      -- Orange
}

-- Current world tracking
local currentWorld = "Cyber"
local skipTriggered = false
local skipButtonVisible = false

-- Final per-career averages, captured at the end of each world (0 if skipped).
-- Used by the end-screen "aptitude reveal" to pick the player's best-fit career.
local finalScores = { Aviation = 0, Chef = 0, Nurse = 0, Cyber = 0 }

-- Create skip button GUI
local skipGui = Instance.new("ScreenGui")
skipGui.Name = "SkipButtonGui"
skipGui.IgnoreGuiInset = true
skipGui.DisplayOrder = 999
skipGui.Parent = playerGui

local skipButton = Instance.new("TextButton")
skipButton.Name = "SkipButton"
skipButton.AnchorPoint = Vector2.new(0, 1)
skipButton.Size = UDim2.new(0, 120, 0, 40)
skipButton.Position = UDim2.new(0, 20, 1, -20)
skipButton.BackgroundColor3 = WORLD_COLORS.Cyber
skipButton.BackgroundTransparency = 0.2
skipButton.BorderSizePixel = 0
skipButton.Text = "SKIP [X]"
skipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
skipButton.TextSize = 16
skipButton.Font = Enum.Font.GothamBold
skipButton.Visible = false
skipButton.AutoButtonColor = false
skipButton.Parent = skipGui

local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0, 8)
skipCorner.Parent = skipButton

local skipStroke = Instance.new("UIStroke")
skipStroke.Color = WORLD_COLORS.Cyber
skipStroke.Thickness = 2
skipStroke.Transparency = 0.3
skipStroke.Parent = skipButton

-- Fade overlay for skip transitions
local skipFadeGui = Instance.new("ScreenGui")
skipFadeGui.Name = "SkipFadeGui"
skipFadeGui.IgnoreGuiInset = true
skipFadeGui.DisplayOrder = 1000
skipFadeGui.Parent = playerGui

local skipFadeFrame = Instance.new("Frame")
skipFadeFrame.Size = UDim2.new(1, 0, 1, 0)
skipFadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
skipFadeFrame.BackgroundTransparency = 1
skipFadeFrame.BorderSizePixel = 0
skipFadeFrame.Visible = false
skipFadeFrame.Parent = skipFadeGui

-- Function to update skip button color based on world
local function updateSkipButtonColor(world)
	currentWorld = world
	local color = WORLD_COLORS[world] or WORLD_COLORS.Cyber
	skipButton.BackgroundColor3 = color
	skipStroke.Color = color
end

-- Function to show/hide skip button
local function setSkipButtonVisible(visible)
	skipButtonVisible = visible
	if visible then
		skipButton.Visible = true
		TweenService:Create(skipButton, TweenInfo.new(0.3), {BackgroundTransparency = 0.2}):Play()
	else
		TweenService:Create(skipButton, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
		task.delay(0.3, function()
			if not skipButtonVisible then
				skipButton.Visible = false
			end
		end)
	end
end

-- Hover effects
skipButton.MouseEnter:Connect(function()
	if not skipTriggered then
		TweenService:Create(skipButton, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
		TweenService:Create(skipStroke, TweenInfo.new(0.15), {Transparency = 0}):Play()
	end
end)

skipButton.MouseLeave:Connect(function()
	if not skipTriggered then
		TweenService:Create(skipButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
		TweenService:Create(skipStroke, TweenInfo.new(0.15), {Transparency = 0.3}):Play()
	end
end)

-- Function to perform skip with fade (waits for fade to complete)
local function performSkip()
	if skipTriggered then return end
	skipTriggered = true
	-- Cooperative skip: tells minigame/world loops (cyber + aviation modules) to bail out
	GameState:RequestSkip()
	
	print("PlaySequence: Skip triggered for world: " .. currentWorld)
	
	-- Hide skip button immediately
	setSkipButtonVisible(false)
	
	-- Fade to black and WAIT for it to complete
	skipFadeFrame.Visible = true
	skipFadeFrame.BackgroundTransparency = 1
	local fadeTween = TweenService:Create(skipFadeFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 0
	})
	fadeTween:Play()
	fadeTween.Completed:Wait()
	print("PlaySequence: Skip fade to black complete")
end

-- Click handler
skipButton.MouseButton1Click:Connect(function()
	performSkip()
end)

-- Keyboard handler for [X] key (stored so we can disconnect it later)
local skipKeyboardConnection = nil
skipKeyboardConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.X and skipButtonVisible and not skipTriggered then
		performSkip()
	end
end)

-- Function to disable skip functionality entirely (for Chef World)
local function disableSkipButton()
	setSkipButtonVisible(false)
	if skipKeyboardConnection then
		skipKeyboardConnection:Disconnect()
		skipKeyboardConnection = nil
	end
	skipButton:Destroy()
	print("PlaySequence: Skip button disabled for final world")
end

-- Function to clean up all ChefWorld UI and sounds
local function cleanupChefWorld(fadeMusic)
	local SoundService = game:GetService("SoundService")
	
	-- Stop/fade Chef sounds
	for _, sound in pairs(SoundService:GetChildren()) do
		if sound:IsA("Sound") then
			if fadeMusic and sound.Name == "bgMusic" and sound.Playing then
				task.spawn(function()
					local startVol = sound.Volume
					for i = 1, 10 do
						sound.Volume = startVol * (1 - i/10)
						task.wait(0.05)
					end
					sound:Stop()
				end)
			else
				sound:Stop()
			end
		end
	end
	
	-- Destroy all Chef-related UIs
	for _, child in pairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and string.find(child.Name, "Chef") then
			child:Destroy()
			print("PlaySequence: Destroyed " .. child.Name)
		end
	end

	-- Ensure camera is restored to classic third-person after ChefWorld ends.
	-- ChefWorldUI locks first-person during gameplay; we override it here so
	-- subsequent worlds and screens always start in the correct camera mode.
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 128
	pcall(function()
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end)
end

-- ============================================
-- SHARED WORLD TRANSITION SYSTEM (used by every world for a consistent theme)
-- ============================================

-- Single black overlay reused for every world transition (starts invisible)
local worldFadeGui = Instance.new("ScreenGui")
worldFadeGui.Name = "WorldTransitionFade"
worldFadeGui.IgnoreGuiInset = true
worldFadeGui.DisplayOrder = 900
worldFadeGui.Parent = playerGui

local worldFadeFrame = Instance.new("Frame")
worldFadeFrame.Size = UDim2.new(1, 0, 1, 0)
worldFadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
worldFadeFrame.BackgroundTransparency = 1
worldFadeFrame.BorderSizePixel = 0
worldFadeFrame.Parent = worldFadeGui

-- Shared completion event so server worlds (Chef/Nurse) can report back
local worldCompleted = ReplicatedStorage:FindFirstChild("WorldCompleted")
if not worldCompleted then
	worldCompleted = Instance.new("BindableEvent")
	worldCompleted.Name = "WorldCompleted"
	worldCompleted.Parent = ReplicatedStorage
	print("PlaySequence: Created WorldCompleted BindableEvent")
end

-- Reset the skip state at the start of each world so multiple worlds can be skipped
local function resetSkipForWorld(world)
	skipTriggered = false
	GameState:ClearSkip()
	updateSkipButtonColor(world)
end

-- Remove any leftover transition / fade GUIs from earlier stages (idempotent)
local function clearLeftoverFades()
	for _, g in pairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and (g.Name == "TutorialOverlay" or g.Name == "PlayTransitionBlack"
			or g.Name == "CinematicFade" or g.Name == "CinematicFadeOut" or g.Name == "MenuFade") then
			g:Destroy()
		end
	end
end

-- Fade the screen to solid black and show a career title card (consistent for all worlds)
local function beginWorldTransition(titleText, subtitleText, accentColor)
	accentColor = accentColor or Color3.fromRGB(255, 255, 255)

	-- Cover the screen with black
	worldFadeGui.DisplayOrder = 900
	worldFadeFrame.Visible = true
	TweenService:Create(worldFadeFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{BackgroundTransparency = 0}
	):Play()
	task.wait(0.5)

	-- Now that black covers everything, remove old fade overlays and the skip fade
	clearLeftoverFades()
	if skipFadeFrame and skipFadeFrame.Parent then
		skipFadeFrame.Visible = false
		skipFadeFrame.BackgroundTransparency = 1
	end

	-- Title card
	local tcGui = Instance.new("ScreenGui")
	tcGui.Name = "CareerTitleCard"
	tcGui.IgnoreGuiInset = true
	tcGui.DisplayOrder = 910
	tcGui.Parent = playerGui

	local tcBg = Instance.new("Frame")
	tcBg.Size = UDim2.new(1, 0, 1, 0)
	tcBg.BackgroundTransparency = 1
	tcBg.BorderSizePixel = 0
	tcBg.Parent = tcGui

	local tcTitle = Instance.new("TextLabel")
	tcTitle.Size = UDim2.new(1, 0, 0, 80)
	tcTitle.Position = UDim2.new(0, 0, 0.35, 0)
	tcTitle.BackgroundTransparency = 1
	tcTitle.Text = titleText
	tcTitle.TextColor3 = accentColor
	tcTitle.TextSize = 48
	tcTitle.Font = Enum.Font.GothamBold
	tcTitle.TextTransparency = 1
	tcTitle.Parent = tcBg

	local tcSubtitle = Instance.new("TextLabel")
	tcSubtitle.Size = UDim2.new(1, 0, 0, 40)
	tcSubtitle.Position = UDim2.new(0, 0, 0.45, 0)
	tcSubtitle.BackgroundTransparency = 1
	tcSubtitle.Text = subtitleText or ""
	tcSubtitle.TextColor3 = Color3.fromRGB(156, 163, 175)
	tcSubtitle.TextSize = 24
	tcSubtitle.Font = Enum.Font.GothamMedium
	tcSubtitle.TextTransparency = 1
	tcSubtitle.TextWrapped = true
	tcSubtitle.Parent = tcBg

	TweenService:Create(tcTitle, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	TweenService:Create(tcSubtitle, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	task.wait(2.5)
	TweenService:Create(tcTitle, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
	TweenService:Create(tcSubtitle, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
	task.wait(0.5)
	tcGui:Destroy()
end

-- Fade from black to reveal the current world
local function revealWorld(duration)
	duration = duration or 1.0
	worldFadeFrame.Visible = true
	TweenService:Create(worldFadeFrame,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 1}
	):Play()
	task.wait(duration)
end

-- Instantly cover the screen in black (used to hand off cleanly between worlds)
local function coverBlack()
	worldFadeFrame.Visible = true
	worldFadeFrame.BackgroundTransparency = 0
end

-- ============================================
-- WORLD TELEPORT (shared across all careers)
-- Place an Anchored part named "WorldSpawn" inside each world folder in Studio.
-- Fallback names are tried if WorldSpawn is missing (see WORLD_EXTRA_SPAWN_NAMES).
-- ============================================

local WORLD_EXTRA_SPAWN_NAMES = {
	Aviation = { "PilotSpawn", "PilotSpawnLocation", "Trigger", "PilotSeat" },
	Chef = { "chefspawnlocation", "ChefSpawnLocation", "chefSpawnLocation", "ChefSpawn", "chefspawn" },
	Medical = { "NurseSpawn", "NurseSpawnLocation", "SpawnLocation" },
	Cyber = { "CyberSpawn", "LabSpawn", "Camera_LabIntro" },
}

local function findWorldFolder(worldKey)
	if worldKey == "Cyber" then
		local env = workspace:FindFirstChild("Environments")
		local cyber = env and env:FindFirstChild("Cybersecurity")
		if cyber then return cyber end
		return workspace:FindFirstChild("Cybersecurity")
	end
	if worldKey == "Aviation" then
		return workspace:FindFirstChild("PilotWorld")
			or workspace:FindFirstChild("AviationWorld")
			or workspace:FindFirstChild("PilotWorld", true)
			or workspace:FindFirstChild("AviationWorld", true)
	end
	if worldKey == "Chef" then
		return workspace:FindFirstChild("ChefWorld")
	end
	if worldKey == "Medical" then
		return workspace:FindFirstChild("NurseWorld")
	end
	return nil
end

local function spawnObjectToCFrame(obj)
	if obj:IsA("BasePart") then
		return obj.CFrame + Vector3.new(0, 3, 0)
	elseif obj:IsA("Attachment") then
		return obj.WorldCFrame
	elseif obj:IsA("Model") then
		return obj:GetPivot() + Vector3.new(0, 3, 0)
	end
	return nil
end

local function findWorldSpawn(worldKey)
	local folder = findWorldFolder(worldKey)
	if not folder then return nil, nil end

	local names = { "WorldSpawn", "CareerSpawn", "PlayerSpawn", "SpawnLocation" }
	for _, n in ipairs(WORLD_EXTRA_SPAWN_NAMES[worldKey] or {}) do
		table.insert(names, n)
	end

	for _, n in ipairs(names) do
		local found = folder:FindFirstChild(n, true)
		if found and (found:IsA("BasePart") or found:IsA("Model") or found:IsA("Attachment")) then
			return found, folder
		end
	end

	-- Legacy: Chef spawn markers placed directly under Workspace
	if worldKey == "Chef" then
		for _, n in ipairs(WORLD_EXTRA_SPAWN_NAMES.Chef) do
			local found = workspace:FindFirstChild(n)
			if found and (found:IsA("BasePart") or found:IsA("Model")) then
				return found, folder
			end
		end
	end

	return nil, folder
end

local function snapCharacterToFloor(character, cf)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local origin = cf.Position + Vector3.new(0, 3, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -400, 0), params)
	if result then
		return CFrame.new(result.Position + Vector3.new(0, 4, 0)) * (cf - cf.Position)
	end
	return cf
end

local function teleportPlayerToWorld(worldKey)
	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not hrp then
		warn("PlaySequence: teleportPlayerToWorld - HumanoidRootPart not found for " .. worldKey)
		return false
	end

	local spawnObj, folder = findWorldSpawn(worldKey)
	local cf = spawnObj and spawnObjectToCFrame(spawnObj)

	if not cf and folder then
		if folder:IsA("Model") then
			cf = folder:GetPivot() + Vector3.new(0, 10, 0)
		elseif folder:IsA("BasePart") then
			cf = folder.CFrame + Vector3.new(0, 10, 0)
		else
			local firstPart = folder:FindFirstChildWhichIsA("BasePart", true)
			if firstPart then
				cf = firstPart.CFrame + Vector3.new(0, 10, 0)
			end
		end
		warn("PlaySequence: No spawn marker in " .. folder:GetFullName() .. " — using world origin (add a WorldSpawn part)")
	end

	-- Aviation-specific fallback: try the PlaneModel when PilotWorld has no BaseParts.
	-- PlaneModel is a separate top-level Model in the workspace and typically has geometry.
	if not cf and worldKey == "Aviation" then
		local planeModel = workspace:FindFirstChild("PlaneModel")
		if planeModel and planeModel:IsA("Model") then
			cf = planeModel:GetPivot() + Vector3.new(0, 5, 0)
			print("PlaySequence: Aviation teleport — using PlaneModel pivot as fallback spawn")
		elseif planeModel then
			local planePart = planeModel:FindFirstChildWhichIsA("BasePart", true)
			if planePart then
				cf = planePart.CFrame + Vector3.new(0, 5, 0)
				print("PlaySequence: Aviation teleport — using PlaneModel part as fallback spawn")
			end
		end
		-- Last resort: any part with a cockpit/seat/tarmac name anywhere in workspace
		if not cf then
			for _, fallbackName in ipairs({"CP_Tarmac", "CP_Cockpit", "PilotSeat", "PilotSpawn"}) do
				local part = workspace:FindFirstChild(fallbackName, true)
				if part and (part:IsA("BasePart") or part:IsA("Model") or part:IsA("Attachment")) then
					cf = spawnObjectToCFrame(part)
					if cf then
						print("PlaySequence: Aviation teleport — using '" .. fallbackName .. "' as fallback spawn")
						break
					end
				end
			end
		end
	end

	if not cf then
		warn("PlaySequence: Could not resolve teleport for " .. worldKey .. " — player will stay at current position")
		return false
	end

	cf = snapCharacterToFloor(character, cf)

	hrp.Anchored = false
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.CFrame = cf

	if humanoid then
		humanoid.Sit = false
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 7.2
	end

	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 128
	camera.FieldOfView = 70

	if spawnObj then
		print("PlaySequence: Teleported to " .. worldKey .. " via " .. spawnObj:GetFullName())
	else
		print("PlaySequence: Teleported to " .. worldKey .. " at " .. tostring(cf.Position))
	end
	return true
end

-- START CONTINUOUS LIGHT FLICKER (runs throughout the entire sequence)
task.spawn(function()
	local flickerPart = workspace:FindFirstChild("ComputerScienceLightFlicker")
	
	if not flickerPart then
		-- Search descendants
		for _, desc in pairs(workspace:GetDescendants()) do
			if desc.Name == "ComputerScienceLightFlicker" then
				flickerPart = desc
				break
			end
		end
	end
	
	if flickerPart then
		print("PlaySequence: Found ComputerScienceLightFlicker! Starting continuous flicker...")
		
		-- Store original parent so we can restore it
		local originalParent = flickerPart.Parent
		
		-- Find all Light objects inside the flicker part
		local lights = {}
		for _, desc in pairs(flickerPart:GetDescendants()) do
			if desc:IsA("Light") then
				table.insert(lights, desc)
			end
		end
		
		-- If the part itself is a light block, we'll toggle the lights inside
		-- If no lights found, we'll toggle the part visibility via Parent
		if #lights > 0 then
			print("PlaySequence: Found " .. #lights .. " Light objects inside, toggling Enabled...")
			
			-- Continuous flicker loop
			while flickerPart and flickerPart.Parent do
				-- OFF
				for _, light in ipairs(lights) do
					light.Enabled = false
				end
				task.wait(0.03 + math.random() * 0.08)
				
				-- ON
				for _, light in ipairs(lights) do
					light.Enabled = true
				end
				task.wait(0.05 + math.random() * 0.15)
			end
		else
			print("PlaySequence: No Light objects found, toggling part Parent...")
			
			-- Continuous flicker by reparenting
			while originalParent and originalParent.Parent do
				-- Disappear (remove from parent)
				flickerPart.Parent = nil
				task.wait(0.03 + math.random() * 0.08)
				
				-- Reappear
				flickerPart.Parent = originalParent
				task.wait(0.05 + math.random() * 0.15)
			end
		end
	else
		warn("PlaySequence: ComputerScienceLightFlicker not found in workspace!")
	end
end)

-- Brief pause so MenuController's black screen is fully solid
-- and MenuCameraFlythrough has time to clean up effects
task.wait(0.3)

-- MenuBackground.client.luau's RenderStepped cleanup fires on the frame after
-- GameState.Started, which sets CameraType back to Custom. We re-assert here
-- (after the wait above has given it time to fire) so the tutorial screen does
-- not inadvertently lock the cursor into first-person.
camera.CameraType = Enum.CameraType.Scriptable
UserInputService.MouseBehavior = Enum.MouseBehavior.Default
UserInputService.MouseIconEnabled = true
player.CameraMaxZoomDistance = 128

-- ============================================
-- INSTRUCTIONS (tutorial slides)
-- ============================================

-- Find the existing black screen from MenuController
local transitionGui = playerGui:FindFirstChild("PlayTransitionBlack")

-- Safety fallback: create our own black screen if needed
if not transitionGui then
	transitionGui = Instance.new("ScreenGui")
	transitionGui.Name = "PlayTransitionBlack"
	transitionGui.IgnoreGuiInset = true
	transitionGui.DisplayOrder = 500
	transitionGui.Parent = playerGui

	local fallbackBlack = Instance.new("Frame")
	fallbackBlack.Name = "BlackFrame"
	fallbackBlack.Size = UDim2.new(1, 0, 1, 0)
	fallbackBlack.BackgroundColor3 = Color3.new(0, 0, 0)
	fallbackBlack.BackgroundTransparency = 0
	fallbackBlack.BorderSizePixel = 0
	fallbackBlack.Parent = transitionGui
end

-- Create the tutorial overlay on top of the black screen
local tutorialGui = Instance.new("ScreenGui")
tutorialGui.Name = "TutorialOverlay"
tutorialGui.IgnoreGuiInset = true
tutorialGui.DisplayOrder = 600
tutorialGui.Parent = playerGui

-- ── PALETTE  (matches MenuGuiCreator exactly) ─────────────────────
local TC = {
	bg       = Color3.fromRGB(6,  9,  20),
	panel    = Color3.fromRGB(8,  12, 24),
	panelSft = Color3.fromRGB(14, 20, 36),
	stroke   = Color3.fromRGB(145, 178, 220),
	ink      = Color3.fromRGB(245, 248, 255),
	muted    = Color3.fromRGB(184, 196, 218),
	aviation = Color3.fromRGB(108, 195, 255),
	chef     = Color3.fromRGB(255, 224, 139),
	nurse    = Color3.fromRGB(174, 255, 178),
	cyber    = Color3.fromRGB(236, 168, 255),
	button   = Color3.fromRGB(238, 242, 248),
	btnText  = Color3.fromRGB(16,  24, 38),
}
-- Each slide gets its own career accent colour
local SLIDE_ACCENTS = { TC.aviation, TC.chef, TC.nurse }

local function tcCorner(p, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 16); c.Parent = p; return c
end
local function tcStroke(p, col, thick, alpha)
	local s = Instance.new("UIStroke")
	s.Color = col or TC.stroke; s.Thickness = thick or 1.5; s.Transparency = alpha or 0.42
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode    = Enum.LineJoinMode.Bevel
	s.Parent = p; return s
end

-- Full-screen deep-navy background with a subtle diagonal gradient
local tutorialBg = Instance.new("Frame")
tutorialBg.Name = "Background"
tutorialBg.Size = UDim2.new(1, 0, 1, 0)
tutorialBg.BackgroundColor3 = TC.bg
tutorialBg.BackgroundTransparency = 0
tutorialBg.BorderSizePixel = 0
tutorialBg.Parent = tutorialGui

local bgGrad = Instance.new("UIGradient")
bgGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 16, 34)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(4,  6,  14)),
})
bgGrad.Rotation = 135
bgGrad.Parent = tutorialBg

-- ── VOCA WORDMARK + CAREER ACCENT BAR (top of screen) ────────────
local headerFrame = Instance.new("Frame")
headerFrame.Name = "Header"
headerFrame.Size = UDim2.new(1, 0, 0, 86)
headerFrame.BackgroundTransparency = 1
headerFrame.BorderSizePixel = 0
headerFrame.Parent = tutorialBg

local vocaLabel = Instance.new("TextLabel")
vocaLabel.Size = UDim2.new(1, 0, 0, 58)
vocaLabel.Position = UDim2.new(0, 0, 0, 12)
vocaLabel.BackgroundTransparency = 1
vocaLabel.RichText = true
vocaLabel.Text = 'V<font color="rgb(190,160,220)">O</font>CA'
vocaLabel.TextColor3 = TC.ink
vocaLabel.TextSize = 46
vocaLabel.Font = Enum.Font.GothamBlack
vocaLabel.TextXAlignment = Enum.TextXAlignment.Center
vocaLabel.Parent = headerFrame

local vocaGlow = Instance.new("UIStroke")
vocaGlow.Color = Color3.fromRGB(180, 218, 255)
vocaGlow.Thickness = 1.2
vocaGlow.Transparency = 0.55
vocaGlow.LineJoinMode = Enum.LineJoinMode.Bevel
vocaGlow.Parent = vocaLabel

-- Four career-color pills (aviation / chef / nurse / cyber)
local accentRowFrame = Instance.new("Frame")
accentRowFrame.Name = "AccentRow"
accentRowFrame.Size = UDim2.new(0, 208, 0, 4)
accentRowFrame.Position = UDim2.new(0.5, -104, 0, 72)
accentRowFrame.BackgroundTransparency = 1
accentRowFrame.BorderSizePixel = 0
accentRowFrame.Parent = headerFrame

local accentLayout = Instance.new("UIListLayout")
accentLayout.FillDirection = Enum.FillDirection.Horizontal
accentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
accentLayout.Padding = UDim.new(0, 8)
accentLayout.Parent = accentRowFrame

for _, col in ipairs({ TC.aviation, TC.chef, TC.nurse, TC.cyber }) do
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 40, 0, 4)
	bar.BackgroundColor3 = col
	bar.BorderSizePixel = 0
	bar.Parent = accentRowFrame
	tcCorner(bar, 999)
end

-- ── BUILD SLIDE CARDS ─────────────────────────────────────────────
local slideCards = {}

for i, data in ipairs(TUTORIAL_SLIDES) do
	local accent = SLIDE_ACCENTS[i] or TC.aviation

	-- Glass panel (matches MenuGuiCreator panel style exactly)
	local card = Instance.new("Frame")
	card.Name = "SlideCard_" .. i
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Size = UDim2.new(0.56, 0, 0.50, 0)
	card.Position = UDim2.new(0.5, 0, 0.53, 0)
	card.BackgroundColor3 = TC.panel
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = tutorialBg
	tcCorner(card, 22)

	local cardStroke = tcStroke(card, accent, 1.5, 1)  -- starts invisible
	cardStroke.Name = "CardStroke"

	-- Subtle inner gradient (glass depth)
	local cardGrad = Instance.new("UIGradient")
	cardGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 22, 44)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(8,  12, 24)),
	})
	cardGrad.Rotation = 135
	cardGrad.Parent = card

	local cardPad = Instance.new("UIPadding")
	cardPad.PaddingTop    = UDim.new(0, 32)
	cardPad.PaddingBottom = UDim.new(0, 28)
	cardPad.PaddingLeft   = UDim.new(0, 36)
	cardPad.PaddingRight  = UDim.new(0, 36)
	cardPad.Parent = card

	-- Title — accent-tinted so each slide has its own colour identity
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = data.title
	title.TextColor3 = accent          -- accent colour per slide instead of plain white
	title.TextSize = 24
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextTransparency = 1
	title.TextWrapped = true
	title.ZIndex = 2
	title.Parent = card

	-- Thin divider line below the title
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Position = UDim2.new(0, 0, 0, 44)
	divider.BackgroundColor3 = accent
	divider.BackgroundTransparency = 1
	divider.BorderSizePixel = 0
	divider.ZIndex = 2
	divider.Parent = card

	-- Body text (GothamMedium, muted — near-white for readability)
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 1, -54)
	body.Position = UDim2.new(0, 0, 0, 54)
	body.BackgroundTransparency = 1
	body.Text = data.body
	body.TextColor3 = TC.muted
	body.TextSize = 19
	body.Font = Enum.Font.GothamMedium
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextTransparency = 1
	body.TextWrapped = true
	body.LineHeight = 1.55
	body.ZIndex = 2
	body.Parent = card

	slideCards[i] = {
		card = card, title = title, body = body, stroke = cardStroke,
		divider = divider,
	}
end

print("PlaySequence: Built " .. #slideCards .. " tutorial slide cards")

-- ── SLIDE COUNTER (pill badge) ────────────────────────────────────
local counterPill = Instance.new("Frame")
counterPill.Name = "SlideCounterPill"
counterPill.AnchorPoint = Vector2.new(0.5, 0)
counterPill.Size = UDim2.new(0, 72, 0, 26)
counterPill.Position = UDim2.new(0.5, 0, 0.88, 0)
counterPill.BackgroundColor3 = TC.panelSft
counterPill.BackgroundTransparency = 0.35
counterPill.BorderSizePixel = 0
counterPill.Parent = tutorialBg
tcCorner(counterPill, 999)
tcStroke(counterPill, TC.stroke, 1, 0.62)

local slideCounter = Instance.new("TextLabel")
slideCounter.Name = "SlideCounter"
slideCounter.Size = UDim2.new(1, 0, 1, 0)
slideCounter.BackgroundTransparency = 1
slideCounter.TextColor3 = TC.muted
slideCounter.TextSize = 13
slideCounter.Font = Enum.Font.GothamMedium
slideCounter.Text = ""
slideCounter.TextTransparency = 1
slideCounter.TextXAlignment = Enum.TextXAlignment.Center
slideCounter.Parent = counterPill

-- ── PROGRESS BAR ─────────────────────────────────────────────────
local progressBg = Instance.new("Frame")
progressBg.Name = "ProgressBarBg"
progressBg.AnchorPoint = Vector2.new(0.5, 0)
progressBg.Size = UDim2.new(0.42, 0, 0, 5)
progressBg.Position = UDim2.new(0.5, 0, 0.93, 0)
progressBg.BackgroundColor3 = Color3.fromRGB(16, 22, 44)
progressBg.BorderSizePixel = 0
progressBg.Parent = tutorialBg
tcCorner(progressBg, 999)

local progressFill = Instance.new("Frame")
progressFill.Name = "Fill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = TC.aviation
progressFill.BackgroundTransparency = 0
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBg
tcCorner(progressFill, 999)

-- Gradient shimmer on the fill
local fillGrad = Instance.new("UIGradient")
fillGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, TC.aviation),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 225, 255)),
})
fillGrad.Parent = progressFill

-- ── SKIP BUTTON (menu button style) ──────────────────────────────
local tutorialSkipped = false

local skipButton = Instance.new("TextButton")
skipButton.Name = "SkipButton"
skipButton.AnchorPoint = Vector2.new(1, 1)
skipButton.Size = UDim2.new(0, 110, 0, 42)
skipButton.Position = UDim2.new(0.97, 0, 0.96, 0)
skipButton.BackgroundColor3 = TC.button
skipButton.BackgroundTransparency = 1
skipButton.BorderSizePixel = 0
skipButton.Text = "SKIP"
skipButton.TextColor3 = TC.btnText
skipButton.TextSize = 15
skipButton.Font = Enum.Font.GothamBold
skipButton.TextTransparency = 1
skipButton.AutoButtonColor = false
skipButton.Parent = tutorialBg
tcCorner(skipButton, 12)

-- White-to-light gradient (matches menu buttons)
local skipBtnGrad = Instance.new("UIGradient")
skipBtnGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 220, 232)),
})
skipBtnGrad.Rotation = 90
skipBtnGrad.Parent = skipButton

local skipStroke = tcStroke(skipButton, TC.aviation, 1.4, 1)

skipButton.MouseEnter:Connect(function()
	if tutorialSkipped then return end
	TweenService:Create(skipButton, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
	TweenService:Create(skipStroke,  TweenInfo.new(0.15), {Transparency = 0.18}):Play()
end)
skipButton.MouseLeave:Connect(function()
	if tutorialSkipped then return end
	TweenService:Create(skipButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.06}):Play()
	TweenService:Create(skipStroke,  TweenInfo.new(0.15), {Transparency = 0.42}):Play()
end)

-- Fade the skip button in smoothly after 1 second
task.spawn(function()
	task.wait(1.0)
	if tutorialSkipped then return end
	TweenService:Create(skipButton,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextTransparency = 0, BackgroundTransparency = 0.06}):Play()
	TweenService:Create(skipStroke,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0.42}):Play()
end)

-- Skip button click handler
skipButton.MouseButton1Click:Connect(function()
	if tutorialSkipped then return end
	tutorialSkipped = true
	print("PlaySequence: Tutorial skipped!")
	TweenService:Create(skipButton,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{TextTransparency = 1, BackgroundTransparency = 1}):Play()
	TweenService:Create(skipStroke,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Transparency = 1}):Play()
end)

-- ============================================
-- TUTORIAL SLIDE PLAYBACK
-- ============================================

local totalSlides = #TUTORIAL_SLIDES
local totalDuration = totalSlides * SLIDE_DURATION

-- Interruptible wait: polls every 0.05s, breaks early if skipped
local function waitInterruptible(duration)
	local startTime = tick()
	while tick() - startTime < duration do
		if tutorialSkipped then return true end
		task.wait(0.05)
	end
	return false
end

local FADE_IN = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function hideSlide(slide)
	slide.card.BackgroundTransparency = 1
	slide.title.TextTransparency = 1
	slide.body.TextTransparency = 1
	if slide.stroke  then slide.stroke.Transparency             = 1 end
	if slide.divider then slide.divider.BackgroundTransparency  = 1 end
	-- Reset card size/position for next entrance
	slide.card.Size     = UDim2.new(0.56, 0, 0.50, 0)
	slide.card.Position = UDim2.new(0.5, 0, 0.53, 0)
	-- Reset title position
	slide.title.Position = UDim2.new(0, 0, 0, 0)
	slide.card.Visible = false
end

local function showSlide(slideIndex)
	if tutorialSkipped then return end
	print("PlaySequence: Showing slide " .. slideIndex .. " / " .. totalSlides)

	local slide = slideCards[slideIndex]
	if not slide then
		waitInterruptible(SLIDE_DURATION)
		return
	end

	-- Reset all elements invisible before entrance
	slide.card.BackgroundTransparency = 1
	slide.title.TextTransparency = 1
	slide.body.TextTransparency = 1
	if slide.stroke  then slide.stroke.Transparency             = 1 end
	if slide.divider then slide.divider.BackgroundTransparency  = 1 end

	-- Card starts slightly smaller and higher for the bounce-in
	slide.card.Size     = UDim2.new(0.53, 0, 0.47, 0)
	slide.card.Position = UDim2.new(0.5, 0, 0.50, 0)

	-- Title starts offset left for its slide-in
	local originalTitlePos = slide.title.Position
	slide.title.Position = UDim2.new(
		originalTitlePos.X.Scale - 0.04, originalTitlePos.X.Offset - 18,
		originalTitlePos.Y.Scale, originalTitlePos.Y.Offset)

	slide.card.Visible = true

	-- 1) Card bounces up to its resting size/position and fades in
	local CARD_ENTRANCE = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(slide.card, CARD_ENTRANCE, {
		Size     = UDim2.new(0.56, 0, 0.50, 0),
		Position = UDim2.new(0.5, 0, 0.53, 0),
		BackgroundTransparency = 0.10,
	}):Play()
	if slide.stroke then TweenService:Create(slide.stroke, FADE_IN, {Transparency = 0.35}):Play() end

	-- 2) Accent divider reveals right as card settles
	task.delay(0.10, function()
		if tutorialSkipped then return end
		if slide.divider then
			TweenService:Create(slide.divider, TweenInfo.new(0.35), {BackgroundTransparency = 0.45}):Play()
		end
	end)

	-- 3) Title slides in from left
	task.delay(0.18, function()
		if tutorialSkipped then return end
		TweenService:Create(slide.title,
			TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Position = originalTitlePos, TextTransparency = 0}):Play()
	end)

	-- 4) Body fades in after title settles
	task.delay(0.42, function()
		if tutorialSkipped then return end
		TweenService:Create(slide.body, FADE_IN, {TextTransparency = 0}):Play()
	end)

	-- 5) Gentle stroke pulse while card is visible
	if slide.stroke then
		task.spawn(function()
			task.wait(0.55)
			while slide.card.Visible and not tutorialSkipped do
				TweenService:Create(slide.stroke,
					TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{Transparency = 0.62}):Play()
				task.wait(1.4)
				if not slide.card.Visible or tutorialSkipped then break end
				TweenService:Create(slide.stroke,
					TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{Transparency = 0.28}):Play()
				task.wait(1.4)
			end
		end)
	end

	-- Counter pill + progress bar
	slideCounter.Text = slideIndex .. " / " .. totalSlides
	TweenService:Create(slideCounter, FADE_IN, {TextTransparency = 0.25}):Play()

	local startProgress = (slideIndex - 1) / totalSlides
	local endProgress   = slideIndex / totalSlides
	progressFill.Size   = UDim2.new(startProgress, 0, 1, 0)

	local progressTween = TweenService:Create(
		progressFill,
		TweenInfo.new(SLIDE_DURATION, Enum.EasingStyle.Linear),
		{Size = UDim2.new(endProgress, 0, 1, 0)})
	progressTween:Play()

	-- Hold for the slide duration (minus the fade-out)
	local skipped = waitInterruptible(SLIDE_DURATION - 0.4)

	if skipped then
		progressTween:Cancel()
		hideSlide(slide)
		return
	end

	-- Fade everything out together
	local fadeTargets = {
		{slide.card,   {BackgroundTransparency = 1}},
		{slide.title,  {TextTransparency = 1}},
		{slide.body,   {TextTransparency = 1}},
		{slideCounter, {TextTransparency = 1}},
	}
	if slide.stroke  then table.insert(fadeTargets, {slide.stroke,  {Transparency = 1}}) end
	if slide.divider then table.insert(fadeTargets, {slide.divider, {BackgroundTransparency = 1}}) end

	for _, t in ipairs(fadeTargets) do
		TweenService:Create(t[1], FADE_OUT, t[2]):Play()
	end

	local fadeSkipped = waitInterruptible(0.4)
	if fadeSkipped then
		hideSlide(slide)
		return
	end

	hideSlide(slide)
end

-- Ensure the cursor is free for the slide buttons/SKIP interaction.
-- The full-screen tutorialBg covers the world, so Scriptable camera is safe here.
camera.CameraType = Enum.CameraType.Scriptable
UserInputService.MouseBehavior = Enum.MouseBehavior.Default
UserInputService.MouseIconEnabled = true

-- Play all tutorial slides
for i = 1, #TUTORIAL_SLIDES do
	showSlide(i)
	if tutorialSkipped then break end
end

-- ============================================
-- TUTORIAL EXIT (clean fade if skipped, instant if finished)
-- ============================================

if tutorialSkipped then
	print("PlaySequence: Fading out tutorial (skipped)...")

	for _, slide in pairs(slideCards) do
		hideSlide(slide)
	end

	local fadeDuration = 0.5
	local FO = TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(slideCounter,  FO, {TextTransparency = 1}):Play()
	TweenService:Create(counterPill,   FO, {BackgroundTransparency = 1}):Play()
	TweenService:Create(progressBg,    FO, {BackgroundTransparency = 1}):Play()
	TweenService:Create(progressFill,  FO, {BackgroundTransparency = 1}):Play()

	task.wait(fadeDuration)
	print("PlaySequence: Tutorial fade-out complete!")
else
	print("PlaySequence: Tutorial complete! (15 seconds elapsed)")
end

-- ============================================
-- CYBERSECURITY WORLD (Blue theme) - final career
-- ============================================
local function runCyberWorld()
	print("PlaySequence: Starting Cybersecurity finale...")

	resetSkipForWorld("Cyber")
	beginWorldTransition("CYBERSECURITY SPECIALIST", "You have been assigned to the school's IT Security Division.", WORLD_COLORS.Cyber)

	teleportPlayerToWorld("Cyber")

	-- Find Camera_LabIntro marker in the Cybersecurity ComputerRoom
	print("PlaySequence: Looking for Camera_LabIntro...")

local labIntroMarker = nil
local environments = workspace:FindFirstChild("Environments")

-- Pre-load video on all computer screens (start loading early so they're ready by camera time)
local screenVideos = {}
if environments then
	local cyber = environments:FindFirstChild("Cybersecurity")
	if cyber then
		labIntroMarker = cyber:FindFirstChild("Camera_LabIntro")
		local computerRoom = cyber:FindFirstChild("ComputerRoom")
		if computerRoom then
			screenVideos = ScreenVideoManager.Setup(computerRoom)
			print("PlaySequence: Screen videos pre-loading in background...")
		end
	end
end

-- Fallback: search all descendants
if not labIntroMarker then
	for _, desc in pairs(workspace:GetDescendants()) do
		if desc.Name == "Camera_LabIntro" then
			labIntroMarker = desc
			print("PlaySequence: Found Camera_LabIntro via descendant search")
			break
		end
	end
end

-- ============================================
-- FIND MC_cybersecurity + LOAD ANIMATION
-- ============================================

print("PlaySequence: Setting up MC_cybersecurity animation...")

local mcCyber = nil

-- Try expected path: Environments > Cybersecurity > MC_cybersecurity
if environments then
	local cyber = environments:FindFirstChild("Cybersecurity")
	if cyber then
		mcCyber = cyber:FindFirstChild("MC_cybersecurity")
		if not mcCyber then
			local computerRoom = cyber:FindFirstChild("ComputerRoom")
			if computerRoom then
				mcCyber = computerRoom:FindFirstChild("MC_cybersecurity")
			end
		end
	end
end

-- Fallback: search all descendants
if not mcCyber then
	for _, desc in pairs(workspace:GetDescendants()) do
		if desc.Name == "MC_cybersecurity" then
			mcCyber = desc
			print("PlaySequence: Found MC_cybersecurity via descendant search")
			break
		end
	end
end

-- Find MC_cybersecurity_1 and hide it during the camera sequence
local mcFirstPerson = nil

if environments then
	local cyber = environments:FindFirstChild("Cybersecurity")
	if cyber then
		local computerRoom = cyber:FindFirstChild("ComputerRoom")
		if computerRoom then
			mcFirstPerson = computerRoom:FindFirstChild("MC_cybersecurity_1")
		end
		if not mcFirstPerson then
			mcFirstPerson = cyber:FindFirstChild("MC_cybersecurity_1")
		end
	end
end

if not mcFirstPerson then
	for _, desc in pairs(workspace:GetDescendants()) do
		if desc.Name == "MC_cybersecurity_1" then
			mcFirstPerson = desc
			break
		end
	end
end

-- Hide the entire R6 body so it doesn't appear during cameras
local function setMCVisibility(model, visible)
	if not model then return end
	local t = visible and 0 or 1
	for _, child in pairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Transparency = t
		elseif child:IsA("Decal") then
			child.Transparency = t
		end
	end
end

if mcFirstPerson then
	setMCVisibility(mcFirstPerson, false)
	print("PlaySequence: MC_cybersecurity_1 hidden for camera sequence")
	
	-- Server script AnchorMCCybersecurity.server.luau handles anchoring at game start
	-- Just verify it's anchored
	local hrp = mcFirstPerson:FindFirstChild("HumanoidRootPart")
	if hrp then
		print("[MC_POS] Current position: " .. string.format("%.3f, %.3f, %.3f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z) .. " | Anchored=" .. tostring(hrp.Anchored))
	end
end

-- Load animations (but don't play yet)
local runTrack = nil
local transitionTrack = nil
local standTrack = nil
local mcLookTarget = nil

if mcCyber then
	print("PlaySequence: Found MC_cybersecurity - loading animation...")
	
	-- Get a part to look at on the MC (Head or HumanoidRootPart)
	mcLookTarget = mcCyber:FindFirstChild("Head")
		or mcCyber:FindFirstChild("HumanoidRootPart")
		or mcCyber:FindFirstChild("Torso")
	
	local humanoid = mcCyber:FindFirstChildOfClass("Humanoid")
		or mcCyber:FindFirstChildWhichIsA("Humanoid", true)
	
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		
		local runAnim = Instance.new("Animation")
		runAnim.AnimationId = RUNNING_INTRO_ANIM_ID
		
		local success, track = pcall(function()
			return animator:LoadAnimation(runAnim)
		end)
		
		if success and track then
			local waited = 0
			while track.Length == 0 and waited < 3 do
				task.wait(0.1)
				waited = waited + 0.1
			end
			
			if track.Length > 0 then
				runTrack = track
				runTrack.Looped = false
				runTrack.Priority = Enum.AnimationPriority.Action4
				print("PlaySequence: Running animation loaded! (Length: " .. runTrack.Length .. "s)")
			else
				warn("PlaySequence: Running animation has zero length after waiting")
			end
		else
			warn("PlaySequence: Failed to load running animation - " .. tostring(track))
		end
		
		-- Load transition animation (plays right after running)
		local transAnim = Instance.new("Animation")
		transAnim.AnimationId = TRANSITION_ANIM_ID
		
		local transSuccess, tTrack = pcall(function()
			return animator:LoadAnimation(transAnim)
		end)
		
		if transSuccess and tTrack then
			local waited = 0
			while tTrack.Length == 0 and waited < 3 do
				task.wait(0.1)
				waited = waited + 0.1
			end
			
			if tTrack.Length > 0 then
				transitionTrack = tTrack
				transitionTrack.Looped = false
				transitionTrack.Priority = Enum.AnimationPriority.Action4
				print("PlaySequence: Transition animation loaded! (Length: " .. transitionTrack.Length .. "s)")
			end
		end
		
		-- Load StandingStillAnimation (plays after transition)
		local standAnim = Instance.new("Animation")
		standAnim.AnimationId = STANDING_STILL_ANIM_ID
		
		local standSuccess, sTrack = pcall(function()
			return animator:LoadAnimation(standAnim)
		end)
		
		if standSuccess and sTrack then
			local waited = 0
			while sTrack.Length == 0 and waited < 3 do
				task.wait(0.1)
				waited = waited + 0.1
			end
			
			if sTrack.Length > 0 then
				standTrack = sTrack
				standTrack.Looped = false
				standTrack.Priority = Enum.AnimationPriority.Action4
				print("PlaySequence: Standing animation loaded! (Length: " .. standTrack.Length .. "s)")
			end
		end
	else
		warn("PlaySequence: No Humanoid found in MC_cybersecurity")
	end
else
	warn("PlaySequence: MC_cybersecurity model not found!")
end

-- ============================================
-- DYNAMIC CAMERA KEYFRAMES (follows MC running)
-- ============================================
-- Camera moves through these positions while the animation plays
-- Rotation dynamically tracks the MC for a cinematic feel

local CAMERA_KEYFRAMES = {
	{ time = 0.00, pos = Vector3.new(-8742.122, 5528.292, 3822.969) },
	{ time = 0.27, pos = Vector3.new(-8748.87, 5528.178, 3825.603) },
	{ time = 0.53, pos = Vector3.new(-8744.795, 5528.257, 3825.614) },
	{ time = 0.80, pos = Vector3.new(-8738.419, 5528.856, 3825.63) },
}

local ANIM_CAMERA_DURATION = 0.80

-- Helper: interpolate camera position from keyframes at a given time
local function getKeyframePosition(t)
	-- Clamp to valid range
	if t <= CAMERA_KEYFRAMES[1].time then
		return CAMERA_KEYFRAMES[1].pos
	end
	if t >= CAMERA_KEYFRAMES[#CAMERA_KEYFRAMES].time then
		return CAMERA_KEYFRAMES[#CAMERA_KEYFRAMES].pos
	end
	
	-- Find which two keyframes we're between
	for i = 1, #CAMERA_KEYFRAMES - 1 do
		local kf1 = CAMERA_KEYFRAMES[i]
		local kf2 = CAMERA_KEYFRAMES[i + 1]
		
		if t >= kf1.time and t <= kf2.time then
			local segmentDuration = kf2.time - kf1.time
			local localProgress = (t - kf1.time) / segmentDuration
			-- Smooth interpolation within segment
			local smooth = localProgress * localProgress * (3 - 2 * localProgress)
			return kf1.pos:Lerp(kf2.pos, smooth)
		end
	end
	
	return CAMERA_KEYFRAMES[#CAMERA_KEYFRAMES].pos
end

-- Set camera to first keyframe position (while screen is still black)
camera.CameraType = Enum.CameraType.Scriptable
local firstPos = CAMERA_KEYFRAMES[1].pos
if labIntroMarker then
	camera.CFrame = CFrame.new(firstPos) * labIntroMarker.CFrame.Rotation
else
	camera.CFrame = CFrame.new(firstPos)
end

-- NOTE: Video playback starts later when Camera_three_lab begins

-- ============================================
-- START ANIMATION + FADE + CAMERA MOVEMENT (ALL TOGETHER)
-- ============================================

-- Play animation
if runTrack then
	runTrack:Play(0.1)
	print("PlaySequence: RunningIntoLabIntro playing!")
end

-- Swing "thedoor" open when the scene starts
-- Uses exact positions: Closed (0,0,0 rotation) -> Open (-8756.407, 5528.442, 3829.536 position, 0,-135,0 rotation)
task.spawn(function()
	print("[DOOR] Starting door animation...")
	local theDoor = nil
	
	-- Find "thedoor" in workspace
	if environments then
		local cyber = environments:FindFirstChild("Cybersecurity")
		if cyber then
			theDoor = cyber:FindFirstChild("thedoor", true)
		end
	end
	
	-- Fallback: search all descendants
	if not theDoor then
		for _, desc in pairs(workspace:GetDescendants()) do
			if desc.Name:lower() == "thedoor" then
				theDoor = desc
				break
			end
		end
	end
	
	if theDoor then
		print("[DOOR] Found: " .. theDoor:GetFullName())
		
		-- Define the exact open position (from user's screenshot)
		local OPEN_POSITION = Vector3.new(-8756.407, 5528.442, 3829.536)
		local OPEN_ORIENTATION = Vector3.new(0, -135, 0)
		
		-- Get the door part to animate
		local doorPart = nil
		if theDoor:IsA("Model") then
			doorPart = theDoor.PrimaryPart or theDoor:FindFirstChildWhichIsA("BasePart")
		elseif theDoor:IsA("BasePart") then
			doorPart = theDoor
		end
		
		if doorPart then
			-- Store closed state
			local closedCFrame = doorPart.CFrame
			local closedPosition = doorPart.Position
			local closedOrientation = doorPart.Orientation
			
			-- Calculate open CFrame from the exact position and orientation
			local openCFrame = CFrame.new(OPEN_POSITION) * CFrame.Angles(
				math.rad(OPEN_ORIENTATION.X),
				math.rad(OPEN_ORIENTATION.Y),
				math.rad(OPEN_ORIENTATION.Z)
			)
			
			print("[DOOR] Closed position: " .. tostring(closedPosition))
			print("[DOOR] Closed orientation: " .. tostring(closedOrientation))
			print("[DOOR] Open position: " .. tostring(OPEN_POSITION))
			print("[DOOR] Open orientation: " .. tostring(OPEN_ORIENTATION))
			
			-- Swing open fast (0.5 seconds)
			print("[DOOR] Swinging open...")
			local openTween = TweenService:Create(doorPart, 
				TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{CFrame = openCFrame}
			)
			openTween:Play()
			openTween.Completed:Wait()
			print("[DOOR] Door is open!")
			
			-- Wait 1 second
			task.wait(1)
			
			-- Swing closed fast (0.7 seconds)
			print("[DOOR] Swinging closed...")
			local closeTween = TweenService:Create(doorPart,
				TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{CFrame = closedCFrame}
			)
			closeTween:Play()
			closeTween.Completed:Wait()
			print("[DOOR] Door is closed!")
		else
			warn("[DOOR] No valid part found to animate")
		end
	else
		warn("[DOOR] thedoor NOT FOUND!")
		-- List all door-related objects for debugging
		for _, desc in pairs(workspace:GetDescendants()) do
			if desc.Name:lower():find("door") then
				print("[DOOR] Found: " .. desc.Name .. " at " .. desc:GetFullName())
			end
		end
	end
end)

-- Start fade from black (runs in background alongside camera movement)
print("PlaySequence: Revealing cybersecurity lab...")

-- Reveal by fading the shared world overlay (the old transition GUI may be gone by now)
TweenService:Create(
	worldFadeFrame,
	TweenInfo.new(LAB_REVEAL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{BackgroundTransparency = 1}
):Play()

local blackFrame = transitionGui and transitionGui.Parent and (transitionGui:FindFirstChild("BlackFrame")
	or transitionGui:FindFirstChildOfClass("Frame"))

if blackFrame then
	local fadeReveal = TweenService:Create(
		blackFrame,
		TweenInfo.new(LAB_REVEAL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 1}
	)
	fadeReveal:Play()
end

-- Create fade overlay for the camera switch (ready but invisible)
local switchFadeGui = Instance.new("ScreenGui")
switchFadeGui.Name = "CameraSwitchFade"
switchFadeGui.IgnoreGuiInset = true
switchFadeGui.DisplayOrder = 900
switchFadeGui.Parent = playerGui

local switchFadeFrame = Instance.new("Frame")
switchFadeFrame.Size = UDim2.new(1, 0, 1, 0)
switchFadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
switchFadeFrame.BackgroundTransparency = 1
switchFadeFrame.BorderSizePixel = 0
switchFadeFrame.Parent = switchFadeGui

local switchFadeStarted = false
local FADE_TO_BLACK_TIME = 0.15
local camSwitchTime = ANIM_CAMERA_DURATION - 0.1
local fadeStartTime = camSwitchTime - FADE_TO_BLACK_TIME

-- Animate camera through keyframes (camera keeps moving while fade happens)
local camStartTime = tick()

while tick() - camStartTime < camSwitchTime do
	local elapsed = tick() - camStartTime
	
	-- Start fade to black while camera is still moving
	if elapsed >= fadeStartTime and not switchFadeStarted then
		switchFadeStarted = true
		TweenService:Create(
			switchFadeFrame,
			TweenInfo.new(FADE_TO_BLACK_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{BackgroundTransparency = 0}
		):Play()
	end
	
	-- Get interpolated camera position from keyframes
	local camPos = getKeyframePosition(elapsed)
	
	-- Point camera at the MC dynamically
	if mcLookTarget and mcLookTarget:IsA("BasePart") then
		camera.CFrame = CFrame.lookAt(camPos, mcLookTarget.Position)
	elseif labIntroMarker then
		camera.CFrame = CFrame.new(camPos) * labIntroMarker.CFrame.Rotation
	else
		camera.CFrame = CFrame.new(camPos)
	end
	
	RunService.RenderStepped:Wait()
end

-- Ensure fade is fully black before switching
switchFadeFrame.BackgroundTransparency = 0

print("PlaySequence: Camera keyframe path complete - switching to Camera 2!")

-- Clean up the transition screen if still around
if transitionGui and transitionGui.Parent then
	transitionGui:Destroy()
end

-- Screen is black — switch animations now (runs in background, doesn't block camera)
if runTrack then
	runTrack:Stop(0)
end

local allAnimsDone = false
local animStartTime = tick()

task.spawn(function()
	local ok, err = pcall(function()
		-- Play transition animation right after running stops
		if transitionTrack then
			transitionTrack:Play(0)
			print("PlaySequence: Transition animation playing! (Length: " .. transitionTrack.Length .. "s)")
			transitionTrack.Stopped:Wait()
			print("PlaySequence: Transition animation finished!")
		end
		
		-- Then play standing animation
		if standTrack then
			standTrack:Play(0)
			print("PlaySequence: StandingStillAnimation playing")
			standTrack.Stopped:Wait()
			print("PlaySequence: StandingStillAnimation finished!")
		end
	end)
	
	if not ok then
		warn("PlaySequence: Animation error - " .. tostring(err))
	end
	
	allAnimsDone = true
end)

-- Find Camera_two_lab in Cybersecurity
local camTwoLab = nil

if environments then
	local cyber = environments:FindFirstChild("Cybersecurity")
	if cyber then
		camTwoLab = cyber:FindFirstChild("Camera_two_lab")
	end
end

-- Fallback: search descendants
if not camTwoLab then
	for _, desc in pairs(workspace:GetDescendants()) do
		if desc.Name == "Camera_two_lab" then
			camTwoLab = desc
			print("PlaySequence: Found Camera_two_lab via descendant search")
			break
		end
	end
end

-- Position camera at Camera_two_lab (hidden behind black)
if camTwoLab then
	print("PlaySequence: Found Camera_two_lab - positioning camera")
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = camTwoLab.CFrame
	camera.Focus = camTwoLab.CFrame * CFrame.new(0, 0, 0)
else
	warn("PlaySequence: Camera_two_lab not found!")
end

-- ============================================
-- SMOOTH ZOOM EFFECT (1.5 seconds) + FADE IN SIMULTANEOUSLY
-- ============================================

print("PlaySequence: Starting zoom + fade in together...")

local ZOOM_DURATION = 1.5
local FADE_IN_TIME = 0.15

-- Get the rotation from Camera_two_lab (keep the same rotation throughout zoom)
local camRotation = camTwoLab and camTwoLab.CFrame.Rotation or CFrame.new()

local zoomStartCF = CFrame.new(-8742.122, 5528.292, 3820.357) * camRotation
local zoomEndCF = CFrame.new(-8742.122, 5528.292, 3822.969) * camRotation

-- Set camera to zoom start
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = zoomStartCF

-- Start fade in (runs in background while zoom moves)
TweenService:Create(
	switchFadeFrame,
	TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{BackgroundTransparency = 1}
):Play()

local zoomStartTime = tick()

while tick() - zoomStartTime < ZOOM_DURATION do
	local elapsed = tick() - zoomStartTime
	local progress = elapsed / ZOOM_DURATION
	
	-- Smooth ease-out for a cinematic feel
	local smooth = 1 - math.pow(1 - progress, 3)
	
	camera.CFrame = zoomStartCF:Lerp(zoomEndCF, smooth)
	RunService.RenderStepped:Wait()
end

-- Lock at final position
camera.CFrame = zoomEndCF
camera.Focus = zoomEndCF * CFrame.new(0, 0, 0)

-- Clean up fade overlay
switchFadeGui:Destroy()

print("PlaySequence: Zoom complete!")

-- ============================================
-- CAMERA THREE TRANSITION (right after zoom finishes)
-- ============================================

-- Find Camera_three_lab in Cybersecurity
local camThreeLab = nil

if environments then
	local cyber = environments:FindFirstChild("Cybersecurity")
	if cyber then
		camThreeLab = cyber:FindFirstChild("Camera_three_lab")
	end
end

if not camThreeLab then
	for _, desc in pairs(workspace:GetDescendants()) do
		if desc.Name == "Camera_three_lab" then
			camThreeLab = desc
			print("PlaySequence: Found Camera_three_lab via descendant search")
			break
		end
	end
end

if camThreeLab then
	print("PlaySequence: Starting Camera_three_lab movement...")
	
	-- START VIDEO SEQUENCE when Camera_three_lab begins
	print("PlaySequence: Starting video sequence on computer screens...")
	ScreenVideoManager.PlayAll(screenVideos, 0)
	
	local camThreeRotation = camThreeLab.CFrame.Rotation
	local camThreeStart = CFrame.new(-8742.122, 5530.513, 3827.349) * camThreeRotation
	local camThreeEnd = CFrame.new(-8742.122, 5533.173, 3829.85) * camThreeRotation
	local CAM_THREE_DURATION = 2.0
	
	-- Fade to black before switching camera
	local camThreeFadeGui = Instance.new("ScreenGui")
	camThreeFadeGui.Name = "CamThreeFade"
	camThreeFadeGui.IgnoreGuiInset = true
	camThreeFadeGui.DisplayOrder = 900
	camThreeFadeGui.Parent = playerGui
	
	local camThreeFadeFrame = Instance.new("Frame")
	camThreeFadeFrame.Size = UDim2.new(1, 0, 1, 0)
	camThreeFadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	camThreeFadeFrame.BackgroundTransparency = 1
	camThreeFadeFrame.BorderSizePixel = 0
	camThreeFadeFrame.Parent = camThreeFadeGui
	
	-- Quick fade to black
	TweenService:Create(camThreeFadeFrame,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{BackgroundTransparency = 0}
	):Play()
	task.wait(0.15)
	
	-- Switch camera while screen is black
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = camThreeStart
	
	-- Fade back in
	TweenService:Create(camThreeFadeFrame,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 1}
	):Play()
	
	-- Smooth camera movement from start to end
	local camThreeStartTime = tick()
	
	while tick() - camThreeStartTime < CAM_THREE_DURATION do
		local elapsed = tick() - camThreeStartTime
		local progress = elapsed / CAM_THREE_DURATION
		local smooth = 1 - math.pow(1 - progress, 3)
		
		camera.CFrame = camThreeStart:Lerp(camThreeEnd, smooth)
		RunService.RenderStepped:Wait()
	end
	
	-- Lock at final position
	camera.CFrame = camThreeEnd
	camera.Focus = camThreeEnd * CFrame.new(0, 0, 0)
	
	-- Clean up
	camThreeFadeGui:Destroy()
	
	print("PlaySequence: Camera_three_lab movement complete!")
else
	warn("PlaySequence: Camera_three_lab not found!")
end

-- ============================================
-- SHOW MC_cybersecurity_1 + SWITCH TO FIRST-PERSON
-- ============================================

if mcFirstPerson then
	print("PlaySequence: Switching to first-person on MC_cybersecurity_1...")
	
	local mcHead = mcFirstPerson:FindFirstChild("Head")
	
	-- Pre-load WalkingToComputer animation BEFORE fading (so it doesn't add to black screen time)
	local walkTrack = nil
	local humanoid = mcFirstPerson:FindFirstChildOfClass("Humanoid")
		or mcFirstPerson:FindFirstChildWhichIsA("Humanoid", true)
	
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		
		local walkAnim = Instance.new("Animation")
		walkAnim.AnimationId = WALKING_TO_COMPUTER_ANIM_ID
		
		local ok, track = pcall(function()
			return animator:LoadAnimation(walkAnim)
		end)
		
		if ok and track then
			local waited = 0
			while track.Length == 0 and waited < 2 do
				task.wait(0.1)
				waited = waited + 0.1
			end
			if track.Length > 0 then
				walkTrack = track
				walkTrack.Looped = false
				walkTrack.Priority = Enum.AnimationPriority.Action4
				print("PlaySequence: WalkingToComputer loaded! (Length: " .. walkTrack.Length .. "s)")
			end
		end
	end
	
	-- Now fade to black (quick)
	local fpFadeGui = Instance.new("ScreenGui")
	fpFadeGui.Name = "FirstPersonFade"
	fpFadeGui.IgnoreGuiInset = true
	fpFadeGui.DisplayOrder = 900
	fpFadeGui.Parent = playerGui
	
	local fpFadeFrame = Instance.new("Frame")
	fpFadeFrame.Size = UDim2.new(1, 0, 1, 0)
	fpFadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	fpFadeFrame.BackgroundTransparency = 1
	fpFadeFrame.BorderSizePixel = 0
	fpFadeFrame.Parent = fpFadeGui
	
	TweenService:Create(fpFadeFrame,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{BackgroundTransparency = 0}
	):Play()
	task.wait(0.15)
	
	-- Show the full body first (it was hidden during the camera sequence)
	setMCVisibility(mcFirstPerson, true)
	
	-- Unanchor the MC and reset Humanoid state so animations work properly
	local mcHRP = mcFirstPerson:FindFirstChild("HumanoidRootPart")
	if mcHRP and mcHRP.Anchored then
		mcHRP.Anchored = false
		print("PlaySequence: Unanchored MC_cybersecurity_1 for walking animation")
	end
	
	-- Reset Humanoid state from Physics to normal (server sets it to Physics at game start)
	local mcHumanoid = mcFirstPerson:FindFirstChildOfClass("Humanoid")
	if mcHumanoid then
		mcHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		print("PlaySequence: Reset MC Humanoid state to normal")
	end
	
	-- Now hide only the head and accessories (so they don't block the camera)
	local mcHeadPart = mcFirstPerson:FindFirstChild("Head")
	if mcHeadPart then
		mcHeadPart.Transparency = 1
		for _, child in pairs(mcHeadPart:GetChildren()) do
			if child:IsA("Decal") then
				child.Transparency = 1
			end
		end
	end
	for _, child in pairs(mcFirstPerson:GetDescendants()) do
		if (child:IsA("Accessory") or child:IsA("Accoutrement")) then
			for _, part in pairs(child:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 1
				end
			end
		end
	end
	
	if mcHead then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.new(mcHead.Position + Vector3.new(0, 0.5, 0)) * mcHead.CFrame.Rotation
	end
	
	-- Lock camera to head
	local fpConnection = RunService.RenderStepped:Connect(function()
		if mcHead and mcHead.Parent then
			camera.CFrame = CFrame.new(mcHead.Position + Vector3.new(0, 0.5, 0)) * mcHead.CFrame.Rotation
		end
	end)
	
	-- Fade back in immediately
	TweenService:Create(fpFadeFrame,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 1}
	):Play()
	
	if walkTrack then
		walkTrack:Play(0)
		print("PlaySequence: WalkingToComputer playing in first-person!")
		
		-- Wait until ~0.7s in, then start fading to black
		task.wait(0.7)
		
		TweenService:Create(fpFadeFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{BackgroundTransparency = 0}
		):Play()
		
		-- Wait for the fade to finish (animation ends around the same time)
		task.wait(0.3)
	end
	
	print("PlaySequence: First-person walking sequence complete!")
	
	-- Disconnect camera follow
	fpConnection:Disconnect()
	
	-- Clean up the fade GUI (keep black screen)
	fpFadeFrame.BackgroundTransparency = 0
	
	-- Screen is black — show title card then launch games
	print("PlaySequence: Starting mini-games...")
	fpFadeGui:Destroy()
	
	-- Track time for results screen
	local gamesStartTime = tick()
	
	-- Initialize hacking background (managed by separate module)
	local hackingBg = HackingBackground.new()
	hackingBg:Initialize(playerGui, 950)
	
	-- Helper: show a title card on black screen (holdTime defaults to 1.3s)
	local function showTitleCard(titleText, descText, holdTime)
		holdTime = holdTime or 1.3
		
		local tcGui = Instance.new("ScreenGui")
		tcGui.Name = "TitleCard"
		tcGui.IgnoreGuiInset = true
		tcGui.DisplayOrder = 960
		tcGui.Parent = playerGui
		
		local tcBg = Instance.new("Frame")
		tcBg.Size = UDim2.new(1, 0, 1, 0)
		tcBg.BackgroundColor3 = Color3.fromRGB(8, 12, 28)
		tcBg.BackgroundTransparency = 0.4  -- Semi-transparent to show hacking background
		tcBg.BorderSizePixel = 0
		tcBg.Parent = tcGui
		
		local tcTitle = Instance.new("TextLabel")
		tcTitle.AnchorPoint = Vector2.new(0.5, 0.5)
		tcTitle.Size = UDim2.new(0.8, 0, 0, 60)
		tcTitle.Position = UDim2.new(0.5, 0, 0.42, 0)
		tcTitle.BackgroundTransparency = 1
		tcTitle.Text = titleText
		tcTitle.TextColor3 = Color3.fromRGB(60, 140, 255)
		tcTitle.TextSize = 42
		tcTitle.Font = Enum.Font.GothamBold
		tcTitle.TextTransparency = 1
		tcTitle.Parent = tcBg
		
		local tcDesc = Instance.new("TextLabel")
		tcDesc.AnchorPoint = Vector2.new(0.5, 0)
		tcDesc.Size = UDim2.new(0.7, 0, 0, 50)
		tcDesc.Position = UDim2.new(0.5, 0, 0.5, 0)
		tcDesc.BackgroundTransparency = 1
		tcDesc.Text = descText
		tcDesc.TextColor3 = Color3.fromRGB(160, 180, 220)
		tcDesc.TextSize = 22
		tcDesc.Font = Enum.Font.GothamMedium
		tcDesc.TextTransparency = 1
		tcDesc.TextWrapped = true
		tcDesc.Parent = tcBg
		
		-- Fade in
		TweenService:Create(tcTitle, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
		task.wait(0.2)
		TweenService:Create(tcDesc, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
		
		-- Hold (use custom duration)
		task.wait(holdTime)
		
		-- Fade out
		TweenService:Create(tcTitle, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
		TweenService:Create(tcDesc, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
		task.wait(0.3)
		
		tcGui:Destroy()
	end
	
	-- ============================================
	-- CYBERSECURITY SCORE TALLY (top-right, blue)
	-- ============================================
	local cyberScoreGui = Instance.new("ScreenGui")
	cyberScoreGui.Name = "CyberScoreTally"
	cyberScoreGui.IgnoreGuiInset = true
	cyberScoreGui.DisplayOrder = 999 -- High priority to show on top
	cyberScoreGui.Parent = playerGui
	
	local cyberScoreFrame = Instance.new("Frame")
	cyberScoreFrame.Size = UDim2.new(0, 150, 0, 52)
	cyberScoreFrame.Position = UDim2.new(1, -170, 0, 20)
	cyberScoreFrame.BackgroundColor3 = Color3.fromRGB(30, 36, 46)
	cyberScoreFrame.BackgroundTransparency = 0.1
	cyberScoreFrame.ZIndex = 100 -- High Z to be on top
	cyberScoreFrame.Parent = cyberScoreGui
	
	local cyberCorner = Instance.new("UICorner")
	cyberCorner.CornerRadius = UDim.new(0, 10)
	cyberCorner.Parent = cyberScoreFrame
	
	local cyberStroke = Instance.new("UIStroke")
	cyberStroke.Color = Color3.fromRGB(96, 165, 250) -- Blue accent
	cyberStroke.Thickness = 2
	cyberStroke.Parent = cyberScoreFrame
	
	local cyberScoreLbl = Instance.new("TextLabel")
	cyberScoreLbl.Size = UDim2.new(1, 0, 0.4, 0)
	cyberScoreLbl.Position = UDim2.new(0, 0, 0, 6)
	cyberScoreLbl.BackgroundTransparency = 1
	cyberScoreLbl.Text = "AVG SCORE"
	cyberScoreLbl.TextColor3 = Color3.fromRGB(200, 205, 215)
	cyberScoreLbl.TextSize = 10
	cyberScoreLbl.Font = Enum.Font.GothamBold
	cyberScoreLbl.ZIndex = 101
	cyberScoreLbl.Parent = cyberScoreFrame
	
	local cyberScoreVal = Instance.new("TextLabel")
	cyberScoreVal.Size = UDim2.new(1, 0, 0.55, 0)
	cyberScoreVal.Position = UDim2.new(0, 0, 0.4, 0)
	cyberScoreVal.BackgroundTransparency = 1
	cyberScoreVal.Text = "—"
	cyberScoreVal.TextColor3 = Color3.fromRGB(96, 165, 250) -- Blue
	cyberScoreVal.TextSize = 26
	cyberScoreVal.Font = Enum.Font.GothamBlack
	cyberScoreVal.ZIndex = 101
	cyberScoreVal.Parent = cyberScoreFrame
	
	-- Helper to update the score display
	local cyberScores = {}
	local function updateCyberScore(newScore)
		table.insert(cyberScores, newScore)
		local sum = 0
		for _, s in cyberScores do
			sum = sum + s
		end
		local avg = math.floor(sum / #cyberScores)
		cyberScoreVal.Text = tostring(avg)
		
		-- Color based on score
		if avg >= 67 then
			cyberScoreVal.TextColor3 = Color3.fromRGB(74, 222, 128) -- Green
		elseif avg >= 34 then
			cyberScoreVal.TextColor3 = Color3.fromRGB(251, 191, 36) -- Yellow
		else
			cyberScoreVal.TextColor3 = Color3.fromRGB(248, 113, 113) -- Red
		end
	end
	
	-- Show skip button for cybersecurity (blue) - the world can now be skipped
	updateSkipButtonColor("Cyber")
	setSkipButtonVisible(true)
	skipTriggered = false
	GameState:ClearSkip()
	
	showTitleCard("CRITICAL MISSION", "A cyber attack is imminent. Save the school before the entire network shuts down!", 2)
	
	-- PASSWORD GAME
	local passwordScore = 0
	local phishingScore = 0
	local decisionScore = 0
	
	if not skipTriggered then
		showTitleCard("PASSWORD GAME", "Pick the strongest password before time runs out!")
	end
	
	if not skipTriggered then
		passwordScore = PasswordGame.Play()
		print("PlaySequence: Password game finished with score: " .. tostring(passwordScore))
		updateCyberScore(passwordScore)
	end
	
	-- PHISHING GAME
	if not skipTriggered then
		showTitleCard("PHISHING DETECTOR", "Read each email and decide if it's safe or a scam!")
	end
	
	if not skipTriggered then
		phishingScore = PhishingGame.Play()
		print("PlaySequence: Phishing game finished with score: " .. tostring(phishingScore))
		updateCyberScore(phishingScore)
	end
	
	-- DECISION GAME
	if not skipTriggered then
		showTitleCard("DECISION GAME", "Choose a scenario and make the right call!")
	end
	
	if not skipTriggered then
		decisionScore = DecisionGame.Play()
		print("PlaySequence: Decision game finished with score: " .. tostring(decisionScore))
		updateCyberScore(decisionScore)
	end
	
	-- Hide skip button and score tally
	setSkipButtonVisible(false)
	cyberScoreGui:Destroy()
	
	-- Calculate final stats (even if skipped, for logging)
	local totalTime = tick() - gamesStartTime
	local cyberAvg = GameState:GetCareerAverage("Cyber")
	print("PlaySequence: Cybersecurity career average: " .. cyberAvg .. "/100")
	print("PlaySequence: Total time: " .. string.format("%.1f", totalTime) .. "s")
	
	-- Calculate rank based on meaningful thresholds
	local rank
	if cyberAvg >= 95 then
		rank = 10  -- Cyber Guardian
	elseif cyberAvg >= 90 then
		rank = 9   -- Master
	elseif cyberAvg >= 85 then
		rank = 8   -- Specialist
	elseif cyberAvg >= 80 then
		rank = 7   -- Expert
	elseif cyberAvg >= 75 then
		rank = 6   -- Senior Analyst
	elseif cyberAvg >= 65 then
		rank = 5   -- Analyst
	elseif cyberAvg >= 55 then
		rank = 4   -- Junior Analyst
	elseif cyberAvg >= 45 then
		rank = 3   -- Apprentice
	elseif cyberAvg >= 30 then
		rank = 2   -- Beginner
	else
		rank = 1   -- Novice
	end
	
	-- If skip was triggered, clean up and skip results screen
	if skipTriggered then
		print("PlaySequence: Cybersecurity skipped - proceeding to end")
		hackingBg:Cleanup()
		ScreenVideoManager.StopAll(screenVideos)
		-- Keep screen black for the handoff to Game Complete
		coverBlack()
		if skipFadeFrame and skipFadeFrame.Parent then
			skipFadeFrame.Visible = false
		end
	else
	-- ============================================
	-- RESULTS SCREEN (only if not skipped)
	-- ============================================
	local resultsGui = Instance.new("ScreenGui")
	resultsGui.Name = "ResultsScreen"
	resultsGui.IgnoreGuiInset = true
	resultsGui.DisplayOrder = 970
	resultsGui.Parent = playerGui
	
	-- Background (semi-transparent to show hacking background)
	local resultsBg = Instance.new("Frame")
	resultsBg.Size = UDim2.new(1, 0, 1, 0)
	resultsBg.BackgroundColor3 = Color3.fromRGB(8, 12, 28)
	resultsBg.BackgroundTransparency = 0.3
	resultsBg.BorderSizePixel = 0
	resultsBg.Parent = resultsGui
	
	-- Title
	local resultsTitle = Instance.new("TextLabel")
	resultsTitle.Size = UDim2.new(1, 0, 0, 60)
	resultsTitle.Position = UDim2.new(0, 0, 0.08, 0)
	resultsTitle.BackgroundTransparency = 1
	resultsTitle.Text = "CYBERSECURITY CHALLENGE COMPLETE"
	resultsTitle.TextColor3 = Color3.fromRGB(100, 180, 255)
	resultsTitle.TextSize = 36
	resultsTitle.Font = Enum.Font.GothamBold
	resultsTitle.TextTransparency = 1
	resultsTitle.Parent = resultsBg
	
	-- Container for game scores
	local scoresContainer = Instance.new("Frame")
	scoresContainer.Size = UDim2.new(0.8, 0, 0.35, 0)
	scoresContainer.Position = UDim2.new(0.1, 0, 0.2, 0)
	scoresContainer.BackgroundTransparency = 1
	scoresContainer.Parent = resultsBg
	
	local scoresLayout = Instance.new("UIListLayout")
	scoresLayout.FillDirection = Enum.FillDirection.Vertical
	scoresLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	scoresLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	scoresLayout.Padding = UDim.new(0, 15)
	scoresLayout.Parent = scoresContainer
	
	-- Helper to create score row
	local function createScoreRow(gameName, score, order)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 50)
		row.BackgroundColor3 = Color3.fromRGB(20, 40, 80)
		row.BackgroundTransparency = 0.3
		row.BorderSizePixel = 0
		row.LayoutOrder = order
		row.Parent = scoresContainer
		
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 10)
		rowCorner.Parent = row
		
		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = Color3.fromRGB(60, 120, 200)
		rowStroke.Thickness = 1
		rowStroke.Transparency = 0.5
		rowStroke.Parent = row
		
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
		nameLabel.Position = UDim2.new(0.05, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = gameName
		nameLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
		nameLabel.TextSize = 22
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTransparency = 1
		nameLabel.Parent = row
		
		local scoreLabel = Instance.new("TextLabel")
		scoreLabel.Size = UDim2.new(0.3, 0, 1, 0)
		scoreLabel.Position = UDim2.new(0.65, 0, 0, 0)
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.Text = tostring(score) .. "/100"
		scoreLabel.TextColor3 = score >= 70 and Color3.fromRGB(100, 255, 150) or score >= 40 and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(255, 100, 100)
		scoreLabel.TextSize = 24
		scoreLabel.Font = Enum.Font.GothamBold
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
		scoreLabel.TextTransparency = 1
		scoreLabel.Parent = row
		
		return nameLabel, scoreLabel
	end
	
	local pwName, pwScore = createScoreRow("Password Strength Checker", passwordScore or 0, 1)
	local phName, phScore = createScoreRow("Phishing Email Detector", phishingScore or 0, 2)
	local dcName, dcScore = createScoreRow("Decision Challenge", decisionScore or 0, 3)
	
	-- Divider line
	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0.6, 0, 0, 2)
	divider.Position = UDim2.new(0.2, 0, 0.58, 0)
	divider.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
	divider.BackgroundTransparency = 0.5
	divider.BorderSizePixel = 0
	divider.Parent = resultsBg
	
	-- Average Score (big)
	local avgLabel = Instance.new("TextLabel")
	avgLabel.Size = UDim2.new(1, 0, 0, 40)
	avgLabel.Position = UDim2.new(0, 0, 0.62, 0)
	avgLabel.BackgroundTransparency = 1
	avgLabel.Text = "AVERAGE SCORE"
	avgLabel.TextColor3 = Color3.fromRGB(150, 180, 220)
	avgLabel.TextSize = 20
	avgLabel.Font = Enum.Font.GothamMedium
	avgLabel.TextTransparency = 1
	avgLabel.Parent = resultsBg
	
	local avgValue = Instance.new("TextLabel")
	avgValue.Size = UDim2.new(1, 0, 0, 70)
	avgValue.Position = UDim2.new(0, 0, 0.67, 0)
	avgValue.BackgroundTransparency = 1
	avgValue.Text = tostring(cyberAvg) .. "/100"
	avgValue.TextColor3 = cyberAvg >= 70 and Color3.fromRGB(100, 255, 150) or cyberAvg >= 40 and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(255, 100, 100)
	avgValue.TextSize = 56
	avgValue.Font = Enum.Font.GothamBold
	avgValue.TextTransparency = 1
	avgValue.Parent = resultsBg
	
	-- Time taken
	local minutes = math.floor(totalTime / 60)
	local seconds = math.floor(totalTime % 60)
	local timeStr = minutes > 0 and string.format("%dm %ds", minutes, seconds) or string.format("%ds", seconds)
	
	local timeLabel = Instance.new("TextLabel")
	timeLabel.Size = UDim2.new(0.5, 0, 0, 30)
	timeLabel.Position = UDim2.new(0, 0, 0.78, 0)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Text = "Time: " .. timeStr
	timeLabel.TextColor3 = Color3.fromRGB(150, 180, 220)
	timeLabel.TextSize = 20
	timeLabel.Font = Enum.Font.GothamMedium
	timeLabel.TextTransparency = 1
	timeLabel.Parent = resultsBg
	
	-- Rank
	local rankLabel = Instance.new("TextLabel")
	rankLabel.Size = UDim2.new(0.5, 0, 0, 30)
	rankLabel.Position = UDim2.new(0.5, 0, 0.78, 0)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Text = "Rank: " .. rank .. "/10"
	rankLabel.TextColor3 = Color3.fromRGB(150, 180, 220)
	rankLabel.TextSize = 20
	rankLabel.Font = Enum.Font.GothamMedium
	rankLabel.TextTransparency = 1
	rankLabel.Parent = resultsBg
	
	-- Rank description
	local rankDescs = {
		[1] = "Novice",
		[2] = "Beginner",
		[3] = "Apprentice",
		[4] = "Junior Analyst",
		[5] = "Analyst",
		[6] = "Senior Analyst",
		[7] = "Expert",
		[8] = "Specialist",
		[9] = "Master",
		[10] = "Cyber Guardian"
	}
	
	local rankDescLabel = Instance.new("TextLabel")
	rankDescLabel.Size = UDim2.new(1, 0, 0, 35)
	rankDescLabel.Position = UDim2.new(0, 0, 0.84, 0)
	rankDescLabel.BackgroundTransparency = 1
	rankDescLabel.Text = '"' .. (rankDescs[rank] or "Analyst") .. '"'
	rankDescLabel.TextColor3 = Color3.fromRGB(100, 180, 255)
	rankDescLabel.TextSize = 28
	rankDescLabel.Font = Enum.Font.GothamBold
	rankDescLabel.TextTransparency = 1
	rankDescLabel.Parent = resultsBg
	
	-- Continue button
	local continueBtn = Instance.new("TextButton")
	continueBtn.Size = UDim2.new(0, 200, 0, 50)
	continueBtn.Position = UDim2.new(0.5, -100, 0.92, 0)
	continueBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 180)
	continueBtn.BorderSizePixel = 0
	continueBtn.Text = "CONTINUE"
	continueBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	continueBtn.TextSize = 20
	continueBtn.Font = Enum.Font.GothamBold
	continueBtn.TextTransparency = 1
	continueBtn.AutoButtonColor = true
	continueBtn.Parent = resultsBg
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = continueBtn
	
	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(80, 150, 220)
	btnStroke.Thickness = 2
	btnStroke.Transparency = 1
	btnStroke.Parent = continueBtn
	
	-- Animate in
	local fadeIn = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	TweenService:Create(resultsTitle, fadeIn, {TextTransparency = 0}):Play()
	
	task.delay(0.2, function()
		TweenService:Create(pwName, fadeIn, {TextTransparency = 0}):Play()
		TweenService:Create(pwScore, fadeIn, {TextTransparency = 0}):Play()
	end)
	task.delay(0.35, function()
		TweenService:Create(phName, fadeIn, {TextTransparency = 0}):Play()
		TweenService:Create(phScore, fadeIn, {TextTransparency = 0}):Play()
	end)
	task.delay(0.5, function()
		TweenService:Create(dcName, fadeIn, {TextTransparency = 0}):Play()
		TweenService:Create(dcScore, fadeIn, {TextTransparency = 0}):Play()
	end)
	task.delay(0.7, function()
		TweenService:Create(avgLabel, fadeIn, {TextTransparency = 0}):Play()
		TweenService:Create(avgValue, fadeIn, {TextTransparency = 0}):Play()
	end)
	task.delay(0.9, function()
		TweenService:Create(timeLabel, fadeIn, {TextTransparency = 0}):Play()
		TweenService:Create(rankLabel, fadeIn, {TextTransparency = 0}):Play()
		TweenService:Create(rankDescLabel, fadeIn, {TextTransparency = 0}):Play()
	end)
	task.delay(1.1, function()
		TweenService:Create(continueBtn, fadeIn, {TextTransparency = 0, BackgroundTransparency = 0}):Play()
		TweenService:Create(btnStroke, fadeIn, {Transparency = 0}):Play()
	end)
	
	-- Wait for continue button
	local continued = false
	continueBtn.MouseButton1Click:Connect(function()
		if continued then return end
		continued = true
		
		-- Fade to BLACK (not transparent) for seamless transition to next world
		local fadeOut = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		
		-- Fade content to transparent while keeping background going to black
		TweenService:Create(resultsBg, fadeOut, {BackgroundTransparency = 0, BackgroundColor3 = Color3.new(0, 0, 0)}):Play()
		hackingBg:FadeOut(0.8)
		
		for _, child in pairs(resultsBg:GetDescendants()) do
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				TweenService:Create(child, fadeOut, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
			elseif child:IsA("Frame") then
				TweenService:Create(child, fadeOut, {BackgroundTransparency = 1}):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, fadeOut, {Transparency = 1}):Play()
			end
		end
		
		task.wait(0.8)
		resultsGui:Destroy()
		hackingBg:Cleanup()
	end)
	
	-- Wait for user to continue
	while not continued do
		task.wait(0.1)
	end
	
	print("PlaySequence: Results screen closed")
	end -- end of "if not skipTriggered" (results screen)
	
	-- Re-anchor MC_cybersecurity_1 to prevent physics weirdness
	if mcFirstPerson then
		local mcHRP = mcFirstPerson:FindFirstChild("HumanoidRootPart")
		if mcHRP then
			mcHRP.Anchored = true
			print("PlaySequence: Re-anchored MC_cybersecurity_1")
		end
		
		local mcHumanoid = mcFirstPerson:FindFirstChildOfClass("Humanoid")
		if mcHumanoid then
			mcHumanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end
	end
else
	warn("PlaySequence: MC_cybersecurity_1 not found!")
end

	-- Ensure videos are stopped and the screen is black for Game Complete
	ScreenVideoManager.StopAll(screenVideos)
	coverBlack()

	-- Record the Cyber average for the end-screen aptitude reveal (0 if skipped).
	finalScores.Cyber = skipTriggered and 0 or GameState:GetCareerAverage("Cyber")
end -- end of runCyberWorld

-- ============================================
-- CHEF WORLD (Orange theme) - second career
-- ============================================
local function runChefWorld()
	print("PlaySequence: Starting Chef job transition...")

	resetSkipForWorld("Chef")
	beginWorldTransition("CHEF SPECIALIST", "You have been assigned to the school's Culinary Division.", WORLD_COLORS.Chef)
	setSkipButtonVisible(true)

	teleportPlayerToWorld("Chef")

-- Fire ActivateChefWorld RemoteEvent to tell server to start ChefWorld
-- (Client can't set BoolValue that server can read - must use RemoteEvent)
local chefRemotes = ReplicatedStorage:WaitForChild("ChefWorldRemotes", 10)
if chefRemotes then
	local activateRemote = chefRemotes:WaitForChild("ActivateChefWorld", 5)
	if activateRemote then
		print("PlaySequence: Firing ActivateChefWorld remote event")
		activateRemote:FireServer()
	else
		warn("PlaySequence: ActivateChefWorld remote not found!")
	end
else
	warn("PlaySequence: ChefWorldRemotes folder not found!")
end

-- Fade from black to reveal ChefWorld
TweenService:Create(worldFadeFrame,
	TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{BackgroundTransparency = 1}
):Play()
task.wait(1.0)

print("PlaySequence: ChefWorld revealed - waiting for player to complete all orders...")

-- Create WorldCompleted BindableEvent if it doesn't exist (for server scripts to fire)
local worldCompleted = ReplicatedStorage:FindFirstChild("WorldCompleted")
if not worldCompleted then
	worldCompleted = Instance.new("BindableEvent")
	worldCompleted.Name = "WorldCompleted"
	worldCompleted.Parent = ReplicatedStorage
	print("PlaySequence: Created WorldCompleted BindableEvent")
end

-- Listen for WorldCompleted event
local nurseWorldComplete = false
local nurseWorldSummary = nil -- Store the summary for results screen

-- Listen for ChefWorld completion
local chefWorldComplete1 = false
local chefWorldSummary1 = nil

if worldCompleted and worldCompleted:IsA("BindableEvent") then
	print("PlaySequence: Found WorldCompleted BindableEvent - listening for ChefWorld...")
	
	local connection
	connection = worldCompleted.Event:Connect(function(completedPlayer, worldName, summary)
		if completedPlayer == player and worldName == "ChefWorld" then
			print("PlaySequence: ChefWorld completed! Final score: " .. tostring(summary and summary.finalScore or "N/A"))
			chefWorldSummary1 = summary
			chefWorldComplete1 = true
			connection:Disconnect()
		end
	end)
	
	-- Wait for ChefWorld to complete (with 10 minute timeout as safety) OR skip
	local maxWaitTime = 600 -- 10 minutes
	local waitStartTime = tick()
	while not chefWorldComplete1 and not skipTriggered and (tick() - waitStartTime) < maxWaitTime do
		task.wait(0.5)
	end
	
	if skipTriggered then
		print("PlaySequence: ChefWorld skipped - proceeding to Medical")
		connection:Disconnect()
	elseif not chefWorldComplete1 then
		warn("PlaySequence: ChefWorld timed out after 10 minutes - proceeding to Medical")
		connection:Disconnect()
	end
else
	warn("PlaySequence: WorldCompleted BindableEvent not found - waiting 120 seconds as fallback...")
	task.wait(120)
end

print("PlaySequence: Chef section complete!")

-- Hide skip button before results
setSkipButtonVisible(false)

-- Handle skip - go directly to Medical without showing results
if skipTriggered then
	print("PlaySequence: Chef skipped - transitioning to next world")
	-- Tell the server to fully stop ChefWorld so nothing runs in the background
	local chefRemotesStop = ReplicatedStorage:FindFirstChild("ChefWorldRemotes")
	if chefRemotesStop then
		local deactivateRemote = chefRemotesStop:FindFirstChild("DeactivateChefWorld")
		if deactivateRemote then
			deactivateRemote:FireServer()
		end
	end
	-- Keep skipFadeFrame black - we'll use worldFadeFrame for the next section
	-- Ensure worldFadeFrame is also solid black before continuing
	worldFadeFrame.Visible = true
	worldFadeFrame.BackgroundTransparency = 0
	-- Hide skipFadeFrame since worldFadeFrame will handle the fade out
	if skipFadeFrame and skipFadeFrame.Parent then
		skipFadeFrame.Visible = false
	end
	
	-- Clean up Chef world (with music fade)
	cleanupChefWorld(true)
	print("PlaySequence: Cleaned up Chef world on skip")
else
-- ============================================
-- CHEFWORLD RESULTS SCREEN (orange culinary theme)
-- ============================================
local chefResultsGui1 = Instance.new("ScreenGui")
chefResultsGui1.Name = "ChefWorldResults1"
chefResultsGui1.IgnoreGuiInset = true
chefResultsGui1.DisplayOrder = 990
chefResultsGui1.Parent = playerGui

-- Background
local chefResultsBg1 = Instance.new("Frame")
chefResultsBg1.Size = UDim2.new(1, 0, 1, 0)
chefResultsBg1.BackgroundColor3 = Color3.fromRGB(20, 12, 8)
chefResultsBg1.BackgroundTransparency = 0.15
chefResultsBg1.Parent = chefResultsGui1

-- Main panel
local chefPanel1 = Instance.new("Frame")
chefPanel1.Size = UDim2.new(0, 650, 0, 550)
chefPanel1.Position = UDim2.new(0.5, -325, 0.5, -275)
chefPanel1.BackgroundColor3 = Color3.fromRGB(35, 28, 22)
chefPanel1.Parent = chefResultsGui1

local chefPanelCorner1 = Instance.new("UICorner")
chefPanelCorner1.CornerRadius = UDim.new(0, 18)
chefPanelCorner1.Parent = chefPanel1

local chefPanelStroke1 = Instance.new("UIStroke")
chefPanelStroke1.Color = Color3.fromRGB(251, 146, 60) -- Orange
chefPanelStroke1.Thickness = 3
chefPanelStroke1.Parent = chefPanel1

-- Header label
local chefHeaderLbl1 = Instance.new("TextLabel")
chefHeaderLbl1.Size = UDim2.new(1, 0, 0, 20)
chefHeaderLbl1.Position = UDim2.new(0, 0, 0, 25)
chefHeaderLbl1.BackgroundTransparency = 1
chefHeaderLbl1.Text = "// CHEF SPECIALIST COMPLETE"
chefHeaderLbl1.TextColor3 = Color3.fromRGB(251, 146, 60)
chefHeaderLbl1.TextSize = 14
chefHeaderLbl1.Font = Enum.Font.Code
chefHeaderLbl1.Parent = chefPanel1

-- Title
local chefResultTitle1 = Instance.new("TextLabel")
chefResultTitle1.Size = UDim2.new(1, 0, 0, 50)
chefResultTitle1.Position = UDim2.new(0, 0, 0, 55)
chefResultTitle1.BackgroundTransparency = 1
chefResultTitle1.Text = "Your Culinary Results"
chefResultTitle1.TextColor3 = Color3.fromRGB(255, 255, 255)
chefResultTitle1.TextSize = 36
chefResultTitle1.Font = Enum.Font.GothamBlack
chefResultTitle1.Parent = chefPanel1

-- Get actual scores from ChefWorld summary
local order1Score1 = 100
local order2Score1 = 100
local order3Score1 = 100
local chefAvg1 = 100

if chefWorldSummary1 then
	local orderScores = chefWorldSummary1.orderScores or {}
	order1Score1 = orderScores[1] or 100
	order2Score1 = orderScores[2] or 100
	order3Score1 = orderScores[3] or 100
	chefAvg1 = chefWorldSummary1.finalScore or math.floor((order1Score1 + order2Score1 + order3Score1) / 3)
	print("PlaySequence: Using actual ChefWorld scores - Order1: " .. order1Score1 .. ", Order2: " .. order2Score1 .. ", Order3: " .. order3Score1 .. ", Avg: " .. chefAvg1)
else
	print("PlaySequence: No ChefWorld summary available - using default scores")
	chefAvg1 = math.floor((order1Score1 + order2Score1 + order3Score1) / 3)
end

-- Score circle
local chefScoreCircle1 = Instance.new("Frame")
chefScoreCircle1.Size = UDim2.new(0, 130, 0, 130)
chefScoreCircle1.Position = UDim2.new(0.5, -65, 0, 120)
chefScoreCircle1.BackgroundColor3 = Color3.fromRGB(25, 18, 15)
chefScoreCircle1.Parent = chefPanel1

local chefScoreCorner1 = Instance.new("UICorner")
chefScoreCorner1.CornerRadius = UDim.new(0, 65)
chefScoreCorner1.Parent = chefScoreCircle1

-- Color based on average score
local chefAvgColor1
if chefAvg1 >= 70 then
	chefAvgColor1 = Color3.fromRGB(68, 218, 118) -- Green
elseif chefAvg1 >= 40 then
	chefAvgColor1 = Color3.fromRGB(251, 191, 36) -- Yellow
else
	chefAvgColor1 = Color3.fromRGB(245, 100, 100) -- Red
end

local chefScoreStroke1 = Instance.new("UIStroke")
chefScoreStroke1.Color = chefAvgColor1
chefScoreStroke1.Thickness = 5
chefScoreStroke1.Parent = chefScoreCircle1

local chefScoreVal1 = Instance.new("TextLabel")
chefScoreVal1.Size = UDim2.new(1, 0, 0.65, 0)
chefScoreVal1.Position = UDim2.new(0, 0, 0.1, 0)
chefScoreVal1.BackgroundTransparency = 1
chefScoreVal1.Text = tostring(chefAvg1)
chefScoreVal1.TextColor3 = chefAvgColor1
chefScoreVal1.TextSize = 48
chefScoreVal1.Font = Enum.Font.GothamBlack
chefScoreVal1.Parent = chefScoreCircle1

local chefScoreLbl1 = Instance.new("TextLabel")
chefScoreLbl1.Size = UDim2.new(1, 0, 0.25, 0)
chefScoreLbl1.Position = UDim2.new(0, 0, 0.65, 0)
chefScoreLbl1.BackgroundTransparency = 1
chefScoreLbl1.Text = "AVG SCORE"
chefScoreLbl1.TextColor3 = Color3.fromRGB(230, 220, 210)
chefScoreLbl1.TextSize = 12
chefScoreLbl1.Font = Enum.Font.Code
chefScoreLbl1.Parent = chefScoreCircle1

-- Order breakdown
local orderBreakdown1 = Instance.new("Frame")
orderBreakdown1.Size = UDim2.new(0, 500, 0, 120)
orderBreakdown1.Position = UDim2.new(0.5, -250, 0, 270)
orderBreakdown1.BackgroundTransparency = 1
orderBreakdown1.Parent = chefPanel1

local obLayout1 = Instance.new("UIListLayout")
obLayout1.FillDirection = Enum.FillDirection.Horizontal
obLayout1.HorizontalAlignment = Enum.HorizontalAlignment.Center
obLayout1.Padding = UDim.new(0, 30)
obLayout1.Parent = orderBreakdown1

local orderNames1 = {"Ticket 1", "Ticket 2", "Ticket 3"}
local orderScoresArr1 = {order1Score1, order2Score1, order3Score1}
local orderIcons1 = {"🍳", "🥘", "🍰"}

for i = 1, 3 do
	local orderFrame1 = Instance.new("Frame")
	orderFrame1.Size = UDim2.new(0, 140, 0, 110)
	orderFrame1.BackgroundColor3 = Color3.fromRGB(45, 35, 28)
	orderFrame1.Parent = orderBreakdown1
	
	local ofCorner1 = Instance.new("UICorner")
	ofCorner1.CornerRadius = UDim.new(0, 10)
	ofCorner1.Parent = orderFrame1
	
	local orderIcon1 = Instance.new("TextLabel")
	orderIcon1.Size = UDim2.new(1, 0, 0, 35)
	orderIcon1.Position = UDim2.new(0, 0, 0, 8)
	orderIcon1.BackgroundTransparency = 1
	orderIcon1.Text = orderIcons1[i]
	orderIcon1.TextSize = 28
	orderIcon1.Parent = orderFrame1
	
	local orderName1 = Instance.new("TextLabel")
	orderName1.Size = UDim2.new(1, 0, 0, 18)
	orderName1.Position = UDim2.new(0, 0, 0, 45)
	orderName1.BackgroundTransparency = 1
	orderName1.Text = orderNames1[i]
	orderName1.TextColor3 = Color3.fromRGB(200, 190, 180)
	orderName1.TextSize = 13
	orderName1.Font = Enum.Font.GothamMedium
	orderName1.Parent = orderFrame1
	
	local orderScore1 = Instance.new("TextLabel")
	orderScore1.Size = UDim2.new(1, 0, 0, 30)
	orderScore1.Position = UDim2.new(0, 0, 0, 70)
	orderScore1.BackgroundTransparency = 1
	orderScore1.Text = tostring(orderScoresArr1[i])
	if orderScoresArr1[i] >= 70 then
		orderScore1.TextColor3 = Color3.fromRGB(68, 218, 118)
	elseif orderScoresArr1[i] >= 40 then
		orderScore1.TextColor3 = Color3.fromRGB(251, 191, 36)
	else
		orderScore1.TextColor3 = Color3.fromRGB(245, 100, 100)
	end
	orderScore1.TextSize = 26
	orderScore1.Font = Enum.Font.GothamBold
	orderScore1.Parent = orderFrame1
end

-- Rating message
local chefRating1 = Instance.new("TextLabel")
chefRating1.Size = UDim2.new(1, -60, 0, 60)
chefRating1.Position = UDim2.new(0, 30, 0, 400)
chefRating1.BackgroundTransparency = 1
chefRating1.TextWrapped = true
if chefAvg1 >= 90 then
	chefRating1.Text = "Outstanding Head Chef! Your culinary skills are world-class. Every dish was perfection."
elseif chefAvg1 >= 70 then
	chefRating1.Text = "Great work, Line Cook! You handled the kitchen pressure well and served quality dishes."
elseif chefAvg1 >= 50 then
	chefRating1.Text = "Good effort! Keep practicing your station flow and timing to improve."
else
	chefRating1.Text = "The kitchen was rough tonight. Study the recipe flow and try again next shift!"
end
chefRating1.TextColor3 = Color3.fromRGB(230, 220, 210)
chefRating1.TextSize = 16
chefRating1.Font = Enum.Font.Gotham
chefRating1.Parent = chefPanel1

-- Continue button (clickable TextButton so mouse click always works)
local chefContinueBtn1 = Instance.new("TextButton")
chefContinueBtn1.Size = UDim2.new(0, 260, 0, 55)
chefContinueBtn1.Position = UDim2.new(0.5, -130, 0, 475)
chefContinueBtn1.BackgroundColor3 = Color3.fromRGB(251, 146, 60)
chefContinueBtn1.Text = "Continue →"
chefContinueBtn1.TextColor3 = Color3.fromRGB(25, 18, 15)
chefContinueBtn1.TextSize = 20
chefContinueBtn1.Font = Enum.Font.GothamBold
chefContinueBtn1.TextXAlignment = Enum.TextXAlignment.Center
chefContinueBtn1.AutoButtonColor = true
chefContinueBtn1.ZIndex = 3
chefContinueBtn1.Parent = chefPanel1

local contCorner1 = Instance.new("UICorner")
contCorner1.CornerRadius = UDim.new(0, 10)
contCorner1.Parent = chefContinueBtn1

print("PlaySequence: Showing ChefWorld results screen")

-- Helper: force camera and mouse out of first-person lock.
-- ChefWorldUI locks LockFirstPerson + zoom 0.5/0.5 during gameplay. We
-- override ALL of those here so the results panel is fully usable.
local function forceUnlockCamera()
	pcall(function()
		UserInputService.MouseBehavior   = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		player.CameraMode                = Enum.CameraMode.Classic
		player.CameraMinZoomDistance     = 0.5
		player.CameraMaxZoomDistance     = 128
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end)
end

forceUnlockCamera()

-- Continuously re-assert the unlock while results are showing.
-- This defeats any stray LockFirstPerson call that ChefWorldUI fires
-- asynchronously (e.g. exitCinematic, CharacterAdded respawn lock, etc.).
local chefDismissed1 = false
local chefCameraHoldConn = game:GetService("RunService").Heartbeat:Connect(function()
	if chefDismissed1 then return end
	if player.CameraMode == Enum.CameraMode.LockFirstPerson
		or player.CameraMaxZoomDistance < 10
		or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		forceUnlockCamera()
	end
end)

-- Emergency keyboard shortcut hint on the results panel.
local escHint = Instance.new("TextLabel")
escHint.Size            = UDim2.new(1, 0, 0, 20)
escHint.Position        = UDim2.new(0, 0, 1, -24)
escHint.BackgroundTransparency = 1
escHint.Text            = "Camera stuck? Press [~] to reset"
escHint.TextColor3      = Color3.fromRGB(180, 140, 100)
escHint.TextSize        = 13
escHint.Font            = Enum.Font.Gotham
escHint.TextXAlignment  = Enum.TextXAlignment.Center
escHint.ZIndex          = 3
escHint.Parent          = chefPanel1

-- Emergency shortcut: BackQuote/tilde forces a full camera unlock at any time.
local chefEscConn = UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.BackQuote then
		forceUnlockCamera()
		print("PlaySequence: Emergency camera unlock triggered (~ key)")
	end
end)

-- Shared dismiss function — triggered by button click OR E/Enter key
local function dismissChefResults()
	if chefDismissed1 then return end
	chefDismissed1 = true
	chefCameraHoldConn:Disconnect()
	chefEscConn:Disconnect()

	-- Fade to black for seamless transition
	local fadeOut = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(chefResultsBg1, fadeOut, {BackgroundTransparency = 0, BackgroundColor3 = Color3.new(0, 0, 0)}):Play()

	for _, child in pairs(chefPanel1:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			TweenService:Create(child, fadeOut, {TextTransparency = 1}):Play()
		end
		if child:IsA("Frame") then
			TweenService:Create(child, fadeOut, {BackgroundTransparency = 1}):Play()
		end
		if child:IsA("UIStroke") then
			TweenService:Create(child, fadeOut, {Transparency = 1}):Play()
		end
	end
	TweenService:Create(chefPanel1, fadeOut, {BackgroundTransparency = 1}):Play()

	task.wait(0.8)
	chefResultsGui1:Destroy()
	print("PlaySequence: ChefWorld results dismissed")
end

-- Primary: click the button
chefContinueBtn1.MouseButton1Click:Connect(dismissChefResults)

-- Backup: E or Enter key still works
local chefInputConn1
chefInputConn1 = UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Return then
		chefInputConn1:Disconnect()
		dismissChefResults()
	end
end)

-- Wait for dismissal
while not chefDismissed1 do
	task.wait(0.1)
end

-- Clean up all ChefWorld UI and sounds after results
cleanupChefWorld(false)
print("PlaySequence: Cleaned up Chef world after results")
end -- end of "if not skipTriggered" (ChefWorld results screen)

-- Record the Chef average for the end-screen aptitude reveal (0 if skipped /
-- no summary). chefWorldSummary1 is only set when the world actually completes.
if skipTriggered or not chefWorldSummary1 then
	finalScores.Chef = 0
else
	local os = chefWorldSummary1.orderScores or {}
	finalScores.Chef = chefWorldSummary1.finalScore
		or math.floor(((os[1] or 0) + (os[2] or 0) + (os[3] or 0)) / 3)
end
end -- end of runChefWorld

-- ============================================
-- NURSE / HEALTHCARE WORLD (Green theme) - third career
-- ============================================
local function runNurseWorld()
	print("PlaySequence: Starting Healthcare job transition...")

	-- Safety cleanup of any remaining Chef elements
	cleanupChefWorld(false)

	resetSkipForWorld("Medical")
	beginWorldTransition("HEALTHCARE SPECIALIST", "You have been assigned to the school's Medical Division.", WORLD_COLORS.Medical)
	setSkipButtonVisible(true)

	teleportPlayerToWorld("Medical")

-- Create NurseWorldActive flag so other scripts know NurseWorld is starting
local nurseActiveFlag2 = ReplicatedStorage:FindFirstChild("NurseWorldActive")
if not nurseActiveFlag2 then
	nurseActiveFlag2 = Instance.new("BoolValue")
	nurseActiveFlag2.Name = "NurseWorldActive"
	nurseActiveFlag2.Parent = ReplicatedStorage
end
nurseActiveFlag2.Value = true
print("PlaySequence: Set NurseWorldActive = true")

-- Fade from black to reveal NurseWorld
TweenService:Create(worldFadeFrame,
	TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{BackgroundTransparency = 1}
):Play()
task.wait(1.0)

print("PlaySequence: NurseWorld revealed - waiting for player to complete all rooms...")

-- Listen for WorldCompleted event (NurseWorld)
local nurseWorldComplete2 = false
local nurseWorldSummary2 = nil

if worldCompleted and worldCompleted:IsA("BindableEvent") then
	print("PlaySequence: Listening for NurseWorld completion...")
	
	local nurseConnection2
	nurseConnection2 = worldCompleted.Event:Connect(function(completedPlayer, worldName, summary)
		if completedPlayer == player and worldName == "NurseWorld" then
			print("PlaySequence: NurseWorld completed! Final score: " .. tostring(summary and summary.finalScore or "N/A"))
			nurseWorldSummary2 = summary
			nurseWorldComplete2 = true
			nurseConnection2:Disconnect()
		end
	end)
	
	-- Wait for NurseWorld to complete (with 10 minute timeout as safety) OR skip
	local nurseMaxWaitTime2 = 600 -- 10 minutes
	local nurseWaitStartTime2 = tick()
	while not nurseWorldComplete2 and not skipTriggered and (tick() - nurseWaitStartTime2) < nurseMaxWaitTime2 do
		task.wait(0.5)
	end
	
	if skipTriggered then
		print("PlaySequence: NurseWorld skipped - proceeding to Cyber")
		nurseConnection2:Disconnect()
	elseif not nurseWorldComplete2 then
		warn("PlaySequence: NurseWorld timed out after 10 minutes - proceeding to Cyber")
		nurseConnection2:Disconnect()
	end
else
	warn("PlaySequence: WorldCompleted BindableEvent not found - waiting up to 120 seconds as fallback...")
	local nurseFallbackStart2 = tick()
	while not skipTriggered and (tick() - nurseFallbackStart2) < 120 do
		task.wait(0.5)
	end
end

print("PlaySequence: Healthcare section complete!")

-- Hide skip button before results
setSkipButtonVisible(false)

-- Tell NurseWorld client/server scripts to stop
nurseActiveFlag2.Value = false

if skipTriggered then
	print("PlaySequence: Nurse skipped - tearing down NurseWorld")
	-- Stop the server-side NurseWorld so nothing keeps running in the background
	local nurseRemotesStop2 = ReplicatedStorage:FindFirstChild("NurseWorldRemotes")
	if nurseRemotesStop2 then
		local stopRemote2 = nurseRemotesStop2:FindFirstChild("StopNurseWorld")
		if stopRemote2 then
			stopRemote2:FireServer()
		end
	end
	-- Keep the screen black for the handoff to Cyber
	worldFadeFrame.Visible = true
	worldFadeFrame.BackgroundTransparency = 0
	if skipFadeFrame and skipFadeFrame.Parent then
		skipFadeFrame.Visible = false
	end
else
-- ============================================
-- NURSEWORLD RESULTS SCREEN (green medical theme)
-- ============================================
local nurseResultsGui2 = Instance.new("ScreenGui")
nurseResultsGui2.Name = "NurseWorldResults2"
nurseResultsGui2.IgnoreGuiInset = true
nurseResultsGui2.DisplayOrder = 990
nurseResultsGui2.Parent = playerGui

-- Background
local nurseResultsBg2 = Instance.new("Frame")
nurseResultsBg2.Size = UDim2.new(1, 0, 1, 0)
nurseResultsBg2.BackgroundColor3 = Color3.fromRGB(8, 20, 12)
nurseResultsBg2.BackgroundTransparency = 0.15
nurseResultsBg2.Parent = nurseResultsGui2

-- Main panel
local nursePanel2 = Instance.new("Frame")
nursePanel2.Size = UDim2.new(0, 650, 0, 550)
nursePanel2.Position = UDim2.new(0.5, -325, 0.5, -275)
nursePanel2.BackgroundColor3 = Color3.fromRGB(22, 35, 28)
nursePanel2.Parent = nurseResultsGui2

local nursePanelCorner2 = Instance.new("UICorner")
nursePanelCorner2.CornerRadius = UDim.new(0, 18)
nursePanelCorner2.Parent = nursePanel2

local nursePanelStroke2 = Instance.new("UIStroke")
nursePanelStroke2.Color = Color3.fromRGB(74, 222, 128) -- Green
nursePanelStroke2.Thickness = 3
nursePanelStroke2.Parent = nursePanel2

-- Header label
local nurseHeaderLbl2 = Instance.new("TextLabel")
nurseHeaderLbl2.Size = UDim2.new(1, 0, 0, 20)
nurseHeaderLbl2.Position = UDim2.new(0, 0, 0, 25)
nurseHeaderLbl2.BackgroundTransparency = 1
nurseHeaderLbl2.Text = "// HEALTHCARE SPECIALIST COMPLETE"
nurseHeaderLbl2.TextColor3 = Color3.fromRGB(74, 222, 128)
nurseHeaderLbl2.TextSize = 14
nurseHeaderLbl2.Font = Enum.Font.Code
nurseHeaderLbl2.Parent = nursePanel2

-- Title
local nurseResultTitle2 = Instance.new("TextLabel")
nurseResultTitle2.Size = UDim2.new(1, 0, 0, 50)
nurseResultTitle2.Position = UDim2.new(0, 0, 0, 55)
nurseResultTitle2.BackgroundTransparency = 1
nurseResultTitle2.Text = "Your Healthcare Results"
nurseResultTitle2.TextColor3 = Color3.fromRGB(255, 255, 255)
nurseResultTitle2.TextSize = 36
nurseResultTitle2.Font = Enum.Font.GothamBlack
nurseResultTitle2.Parent = nursePanel2

-- Get actual scores from NurseWorld summary
local room1Score2 = 100
local room2Score2 = 100
local room3Score2 = 100
local nurseAvg2 = 100

if nurseWorldSummary2 then
	room1Score2 = nurseWorldSummary2.room1Score or 100
	room2Score2 = nurseWorldSummary2.room2Score or 100
	room3Score2 = nurseWorldSummary2.room3Score or 100
	nurseAvg2 = nurseWorldSummary2.averageScore or math.floor((room1Score2 + room2Score2 + room3Score2) / 3)
	print("PlaySequence: Using actual NurseWorld scores - Room1: " .. room1Score2 .. ", Room2: " .. room2Score2 .. ", Room3: " .. room3Score2 .. ", Avg: " .. nurseAvg2)
else
	print("PlaySequence: No NurseWorld summary available - using default scores")
	nurseAvg2 = math.floor((room1Score2 + room2Score2 + room3Score2) / 3)
end

-- Score circle
local nurseScoreCircle2 = Instance.new("Frame")
nurseScoreCircle2.Size = UDim2.new(0, 130, 0, 130)
nurseScoreCircle2.Position = UDim2.new(0.5, -65, 0, 120)
nurseScoreCircle2.BackgroundColor3 = Color3.fromRGB(15, 25, 18)
nurseScoreCircle2.Parent = nursePanel2

local nurseScoreCorner2 = Instance.new("UICorner")
nurseScoreCorner2.CornerRadius = UDim.new(0, 65)
nurseScoreCorner2.Parent = nurseScoreCircle2

-- Color based on average score
local nurseAvgColor2
if nurseAvg2 >= 67 then
	nurseAvgColor2 = Color3.fromRGB(74, 222, 128) -- Green
elseif nurseAvg2 >= 34 then
	nurseAvgColor2 = Color3.fromRGB(251, 191, 36) -- Yellow
else
	nurseAvgColor2 = Color3.fromRGB(248, 113, 113) -- Red
end

local nurseScoreStroke2 = Instance.new("UIStroke")
nurseScoreStroke2.Color = nurseAvgColor2
nurseScoreStroke2.Thickness = 5
nurseScoreStroke2.Parent = nurseScoreCircle2

local nurseScoreVal2 = Instance.new("TextLabel")
nurseScoreVal2.Size = UDim2.new(1, 0, 0.65, 0)
nurseScoreVal2.Position = UDim2.new(0, 0, 0.1, 0)
nurseScoreVal2.BackgroundTransparency = 1
nurseScoreVal2.Text = tostring(nurseAvg2)
nurseScoreVal2.TextColor3 = nurseAvgColor2
nurseScoreVal2.TextSize = 48
nurseScoreVal2.Font = Enum.Font.GothamBlack
nurseScoreVal2.Parent = nurseScoreCircle2

local nurseScoreLbl2 = Instance.new("TextLabel")
nurseScoreLbl2.Size = UDim2.new(1, 0, 0.25, 0)
nurseScoreLbl2.Position = UDim2.new(0, 0, 0.65, 0)
nurseScoreLbl2.BackgroundTransparency = 1
nurseScoreLbl2.Text = "AVG SCORE"
nurseScoreLbl2.TextColor3 = Color3.fromRGB(200, 220, 210)
nurseScoreLbl2.TextSize = 12
nurseScoreLbl2.Font = Enum.Font.Code
nurseScoreLbl2.Parent = nurseScoreCircle2

-- Room breakdown
local roomBreakdown2 = Instance.new("Frame")
roomBreakdown2.Size = UDim2.new(0, 500, 0, 120)
roomBreakdown2.Position = UDim2.new(0.5, -250, 0, 270)
roomBreakdown2.BackgroundTransparency = 1
roomBreakdown2.Parent = nursePanel2

local rbLayout2 = Instance.new("UIListLayout")
rbLayout2.FillDirection = Enum.FillDirection.Horizontal
rbLayout2.HorizontalAlignment = Enum.HorizontalAlignment.Center
rbLayout2.Padding = UDim.new(0, 30)
rbLayout2.Parent = roomBreakdown2

local roomNames2 = {"Office", "Medication", "ICU"}
local roomScoresArr2 = {room1Score2, room2Score2, room3Score2}
local roomIcons2 = {"📋", "💊", "🏥"}

for i = 1, 3 do
	local roomFrame2 = Instance.new("Frame")
	roomFrame2.Size = UDim2.new(0, 140, 0, 110)
	roomFrame2.BackgroundColor3 = Color3.fromRGB(30, 45, 35)
	roomFrame2.Parent = roomBreakdown2
	
	local rfCorner2 = Instance.new("UICorner")
	rfCorner2.CornerRadius = UDim.new(0, 10)
	rfCorner2.Parent = roomFrame2
	
	local roomIcon2 = Instance.new("TextLabel")
	roomIcon2.Size = UDim2.new(1, 0, 0, 35)
	roomIcon2.Position = UDim2.new(0, 0, 0, 8)
	roomIcon2.BackgroundTransparency = 1
	roomIcon2.Text = roomIcons2[i]
	roomIcon2.TextSize = 28
	roomIcon2.Parent = roomFrame2
	
	local roomName2 = Instance.new("TextLabel")
	roomName2.Size = UDim2.new(1, 0, 0, 18)
	roomName2.Position = UDim2.new(0, 0, 0, 45)
	roomName2.BackgroundTransparency = 1
	roomName2.Text = roomNames2[i]
	roomName2.TextColor3 = Color3.fromRGB(180, 200, 190)
	roomName2.TextSize = 13
	roomName2.Font = Enum.Font.GothamMedium
	roomName2.Parent = roomFrame2
	
	local roomScore2 = Instance.new("TextLabel")
	roomScore2.Size = UDim2.new(1, 0, 0, 30)
	roomScore2.Position = UDim2.new(0, 0, 0, 70)
	roomScore2.BackgroundTransparency = 1
	roomScore2.Text = tostring(roomScoresArr2[i])
	if roomScoresArr2[i] >= 67 then
		roomScore2.TextColor3 = Color3.fromRGB(74, 222, 128)
	elseif roomScoresArr2[i] >= 34 then
		roomScore2.TextColor3 = Color3.fromRGB(251, 191, 36)
	else
		roomScore2.TextColor3 = Color3.fromRGB(248, 113, 113)
	end
	roomScore2.TextSize = 26
	roomScore2.Font = Enum.Font.GothamBold
	roomScore2.Parent = roomFrame2
end

-- Rating message
local nurseRating2 = Instance.new("TextLabel")
nurseRating2.Size = UDim2.new(1, -60, 0, 60)
nurseRating2.Position = UDim2.new(0, 30, 0, 400)
nurseRating2.BackgroundTransparency = 1
nurseRating2.TextWrapped = true
if nurseAvg2 >= 90 then
	nurseRating2.Text = "Outstanding Healthcare Specialist! Your clinical judgment and patient care are exemplary."
elseif nurseAvg2 >= 70 then
	nurseRating2.Text = "Great work! You showed strong medical knowledge and compassion for patients."
elseif nurseAvg2 >= 50 then
	nurseRating2.Text = "Good effort! Keep practicing your clinical skills and patient assessment."
else
	nurseRating2.Text = "Healthcare requires practice. Review protocols and try again!"
end
nurseRating2.TextColor3 = Color3.fromRGB(220, 230, 225)
nurseRating2.TextSize = 16
nurseRating2.Font = Enum.Font.Gotham
nurseRating2.Parent = nursePanel2

-- Continue button
local nurseContinueBtn2 = Instance.new("TextLabel")
nurseContinueBtn2.Size = UDim2.new(0, 260, 0, 55)
nurseContinueBtn2.Position = UDim2.new(0.5, -130, 0, 475)
nurseContinueBtn2.BackgroundColor3 = Color3.fromRGB(74, 222, 128)
nurseContinueBtn2.Text = "  Press [E] to Continue"
nurseContinueBtn2.TextColor3 = Color3.fromRGB(15, 25, 18)
nurseContinueBtn2.TextSize = 18
nurseContinueBtn2.Font = Enum.Font.GothamBold
nurseContinueBtn2.TextXAlignment = Enum.TextXAlignment.Left
nurseContinueBtn2.Parent = nursePanel2

local continueCorner2 = Instance.new("UICorner")
continueCorner2.CornerRadius = UDim.new(0, 10)
continueCorner2.Parent = nurseContinueBtn2

print("PlaySequence: Showing NurseWorld results screen")

-- Unlock cursor and camera for the results screen.
-- FirstPersonLock (NurseWorld) locks the mouse; override it here so players
-- can move the cursor freely over the results panel.
UserInputService.MouseBehavior = Enum.MouseBehavior.Default
UserInputService.MouseIconEnabled = true
player.CameraMode = Enum.CameraMode.Classic

-- Wait for E key to continue
local nurseDismissed2 = false
local nurseInputConn2
nurseInputConn2 = UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Return then
		if nurseDismissed2 then return end
		nurseDismissed2 = true
		nurseInputConn2:Disconnect()

		-- Cursor stays unlocked — Aviation (next world) has its own camera setup.

		-- Fade to black for seamless transition to Game Complete
		local fadeOut = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(nurseResultsBg2, fadeOut, {BackgroundTransparency = 0, BackgroundColor3 = Color3.new(0, 0, 0)}):Play()
		
		for _, child in pairs(nursePanel2:GetDescendants()) do
			if child:IsA("TextLabel") then
				TweenService:Create(child, fadeOut, {TextTransparency = 1}):Play()
			elseif child:IsA("Frame") then
				TweenService:Create(child, fadeOut, {BackgroundTransparency = 1}):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, fadeOut, {Transparency = 1}):Play()
			end
		end
		TweenService:Create(nursePanel2, fadeOut, {BackgroundTransparency = 1}):Play()
		
		task.wait(0.8)
		nurseResultsGui2:Destroy()
		print("PlaySequence: NurseWorld results dismissed")
	end
end)

-- Wait for dismissal
while not nurseDismissed2 do
	task.wait(0.1)
end
end -- end of "if not skipTriggered" (NurseWorld results screen)

-- Record the Nurse average for the end-screen aptitude reveal (0 if skipped /
-- no summary). nurseWorldSummary2 is only set when the world actually completes.
if skipTriggered or not nurseWorldSummary2 then
	finalScores.Nurse = 0
else
	local r1 = nurseWorldSummary2.room1Score or 0
	local r2 = nurseWorldSummary2.room2Score or 0
	local r3 = nurseWorldSummary2.room3Score or 0
	finalScores.Nurse = nurseWorldSummary2.averageScore or math.floor((r1 + r2 + r3) / 3)
end
end -- end of runNurseWorld

-- ============================================
-- AVIATION WORLD (Sky-blue theme) - first career
-- ============================================
local function runAviationWorld()
	print("PlaySequence: Starting Aviation (Pilot World)...")

	resetSkipForWorld("Aviation")
	beginWorldTransition("PILOT SPECIALIST", "You have been assigned to the school's Aviation Program.", WORLD_COLORS.Aviation)

	-- The airport (PilotWorld) and the aircraft (PlaneModel) live in Workspace and
	-- do not sync through Rojo, so resolve PilotWorld by name at runtime. If the
	-- airport is missing, don't strand the player in the void - just move on.
	local pilotWorld = workspace:FindFirstChild("PilotWorld") or workspace:FindFirstChild("PilotWorld", true)
	if not pilotWorld then
		warn("PlaySequence: PilotWorld not found in Workspace - skipping Aviation")
		coverBlack()
		if skipFadeFrame and skipFadeFrame.Parent then skipFadeFrame.Visible = false end
		return
	end

	-- Content streaming: PilotWorld's children (Trigger, DoorEntry, CameraPoints/CP_*)
	-- only arrive on the client once the player is near that area. We pre-warm them
	-- here with WaitForChild so the teleport and cinematic have the parts they need.
	-- Timeouts are generous; if streaming still hasn't delivered after this we fall
	-- back gracefully rather than crashing.
	task.spawn(function()
		-- Wait for the spawn trigger so teleportPlayerToWorld can find it
		pilotWorld:WaitForChild("Trigger", 12)
		-- Wait for camera point folder + at least one shot
		local cpFolder = pilotWorld:WaitForChild("CameraPoints", 12)
		if cpFolder then cpFolder:WaitForChild("CP_Tarmac", 8) end
	end)
	-- Give the WaitForChild requests a head-start before the teleport runs.
	-- The pilot-module load (WaitForChild("Pilot") below) takes a few seconds and
	-- acts as natural padding, so this small wait is usually free.
	task.wait(0.5)

	-- Boot the real pilot game. The server engine (PilotServer) is already running;
	-- requiring PilotUI connects the client UI and fires ClientReady, which makes the
	-- server offer the pilot tutorial. We grab PilotUIBase to drive/await completion.
	local pilotOK, pilotBase = pcall(function()
		local folder = script.Parent:WaitForChild("Pilot", 10)
		require(folder:WaitForChild("PilotUI"))          -- loader: boots Base + Tasks + Handlers
		return require(folder:WaitForChild("PilotUIBase"))
	end)
	if not pilotOK or type(pilotBase) ~= "table" then
		warn("PlaySequence: Failed to load pilot modules - skipping Aviation:", pilotBase)
		coverBlack()
		if skipFadeFrame and skipFadeFrame.Parent then skipFadeFrame.Visible = false end
		return
	end

	pilotBase.active = true
	pilotBase.aborted = false
	pilotBase.finished = false

	teleportPlayerToWorld("Aviation")

	-- Reveal the world so the pilot's tutorial / cinematic is visible, and let the
	-- player skip the whole world at any time with [X] or the skip button.
	setSkipButtonVisible(true)
	revealWorld(0.8)

	-- Wait until the player finishes the flight debrief (CONTINUE) or skips.
	while not pilotBase.finished and not skipTriggered do
		task.wait(0.1)
	end

	setSkipButtonVisible(false)

	-- Halt the server-side pilot flow no matter how we leave, and stop the client
	-- loops, so nothing from Aviation keeps running once we hand off to Chef.
	pilotBase.aborted = true
	local pilotRemotes = ReplicatedStorage:FindFirstChild("PilotRemotes")
	local stopRemote = pilotRemotes and pilotRemotes:FindFirstChild("StopAviation")
	if stopRemote then
		stopRemote:FireServer()
	end

	-- Cover the screen, then tear the pilot UI down behind black. (On a skip the
	-- skip overlay is already black; on a normal finish we fade to black first.)
	if not skipTriggered then
		worldFadeFrame.Visible = true
		TweenService:Create(worldFadeFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 0}):Play()
		task.wait(0.6)
	end
	worldFadeFrame.Visible = true
	worldFadeFrame.BackgroundTransparency = 0

	if pilotBase.teardown then
		pcall(pilotBase.teardown)
	end

	if skipTriggered then
		print("PlaySequence: Aviation skipped - proceeding to Chef")
	end
	if skipFadeFrame and skipFadeFrame.Parent then
		skipFadeFrame.Visible = false
	end
	coverBlack()

	-- Record the Aviation average for the end-screen aptitude reveal (0 if skipped).
	finalScores.Aviation = skipTriggered and 0 or GameState:GetCareerAverage("Aviation")
	print("PlaySequence: Aviation complete")
end

-- ============================================
-- MAIN GAME FLOW
-- Instructions (above) -> Aviation -> Chef -> Nurse -> Cyber
-- ============================================
runAviationWorld()
runChefWorld()
runNurseWorld()
runCyberWorld()

-- ============================================
-- GAME COMPLETE - APTITUDE REVEAL END SCREEN
-- A bright flash transitions into a 3D room (built in Studio as "EndRoom") where
-- a center platform sinks into the floor and rises carrying the pedestal of the
-- player's best-fit career, then the screen blurs into a "Try Again?" menu.
-- ============================================

-- Career display config -------------------------------------------------------
-- The order here is also the tie-break priority (earlier wins ties).
local CAREER_ORDER = { "Aviation", "Chef", "Nurse", "Cyber" }
local CAREER_DISPLAY = {
	Aviation = "PILOT",
	Chef = "CHEF",
	Nurse = "NURSE",
	Cyber = "CYBERSECURITY SPECIALIST",
}
local CAREER_TAGLINE = {
	Aviation = "Your future is in the skies.",
	Chef = "Your future is in the kitchen.",
	Nurse = "Your future is in healthcare.",
	Cyber = "Your future is in cyber defense.",
}
local CAREER_ACCENT = {
	Aviation = WORLD_COLORS.Aviation,
	Chef = WORLD_COLORS.Chef,
	Nurse = WORLD_COLORS.Medical,
	Cyber = WORLD_COLORS.Cyber,
}
-- Friendly world names used in the tie / all-skipped messages.
local CAREER_SHORT = {
	Aviation = "Aviation",
	Chef = "Chef",
	Nurse = "Nursing",
	Cyber = "Cybersecurity",
}

-- Analyze the four scores. Returns:
--   winnerKey  - the best career (first by CAREER_ORDER priority among ties)
--   bestScore  - the top score
--   tiedKeys   - every career sharing the top score (length >= 2 means a tie)
--   allZero    - true when nobody scored above 0 (e.g. all worlds skipped)
local function analyzeResults(scores)
	local bestScore = -1
	for _, key in ipairs(CAREER_ORDER) do
		local s = scores[key] or 0
		if s > bestScore then bestScore = s end
	end
	local tiedKeys = {}
	for _, key in ipairs(CAREER_ORDER) do
		if (scores[key] or 0) == bestScore then
			table.insert(tiedKeys, key)
		end
	end
	return tiedKeys[1], bestScore, tiedKeys, (bestScore <= 0)
end

-- Join career names into natural language: "A", "A and B", or "A, B, and C".
local function joinCareerNames(keys)
	local names = {}
	for _, k in ipairs(keys) do
		table.insert(names, CAREER_SHORT[k] or k)
	end
	if #names <= 1 then return names[1] or "" end
	if #names == 2 then return names[1] .. " and " .. names[2] end
	local last = table.remove(names)
	return table.concat(names, ", ") .. ", and " .. last
end

-- Smoothly interpolate a PVInstance's pivot (works for Models and BaseParts,
-- anchored or not - no welding needed).
local function tweenPivot(inst, goalCF, duration)
	local startCF = inst:GetPivot()
	local elapsed = 0
	while elapsed < duration do
		local dt = RunService.Heartbeat:Wait()
		elapsed = math.min(elapsed + dt, duration)
		local a = elapsed / duration
		a = a * a * (3 - 2 * a) -- smoothstep easing
		inst:PivotTo(startCF:Lerp(goalCF, a))
	end
	inst:PivotTo(goalCF)
end

-- Raise the platform and the cloned pedestal together in lockstep.
local function raiseTogether(platform, platFrom, platTo, pedestal, pedFrom, pedTo, duration)
	local elapsed = 0
	while elapsed < duration do
		local dt = RunService.Heartbeat:Wait()
		elapsed = math.min(elapsed + dt, duration)
		local a = elapsed / duration
		a = a * a * (3 - 2 * a)
		platform:PivotTo(platFrom:Lerp(platTo, a))
		pedestal:PivotTo(pedFrom:Lerp(pedTo, a))
	end
	platform:PivotTo(platTo)
	pedestal:PivotTo(pedTo)
end

-- World-space top-center point of a Model or BasePart.
local function topCenterOf(inst)
	local cf, size
	if inst:IsA("Model") then
		cf, size = inst:GetBoundingBox()
	else
		cf, size = inst.CFrame, inst.Size
	end
	return cf.Position + Vector3.new(0, size.Y / 2, 0)
end

-- Vertical distance from a model's pivot to the bottom of its bounding box, so we
-- can rest its base on a surface.
local function pivotToBottom(model)
	local cf, size = model:GetBoundingBox()
	return model:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
end

-- Fallback camera framing used when no usable CamPos marker exists. Stays INSIDE
-- the room at roughly eye level (a touch above the reveal target) and looks straight
-- at it — never floating above the box. The horizontal viewing direction is chosen
-- as the most "open" of the platform's four sides (the one whose camera spot is
-- farthest from any pedestal), so we don't sit on top of a decorative pedestal.
local function computeFallbackCam(pedFolder, platform, focusPos)
	-- Pedestal positions (for the openness test) + horizontal spread (for distance).
	local pedPositions = {}
	for _, ped in ipairs(pedFolder:GetChildren()) do
		if ped:IsA("Model") or ped:IsA("BasePart") then
			table.insert(pedPositions, ped:GetPivot().Position)
		end
	end

	local minV, maxV
	for _, d in ipairs(pedFolder:GetDescendants()) do
		if d:IsA("BasePart") then
			local lo = d.Position - d.Size * 0.5
			local hi = d.Position + d.Size * 0.5
			if not minV then
				minV, maxV = lo, hi
			else
				minV = Vector3.new(math.min(minV.X, lo.X), math.min(minV.Y, lo.Y), math.min(minV.Z, lo.Z))
				maxV = Vector3.new(math.max(maxV.X, hi.X), math.max(maxV.Y, hi.Y), math.max(maxV.Z, hi.Z))
			end
		end
	end

	local focus = focusPos
	if not focus then
		focus = minV and ((minV + maxV) * 0.5) or Vector3.zero
	end

	local horizRadius = 18
	if minV then
		horizRadius = math.max(maxV.X - minV.X, maxV.Z - minV.Z) * 0.5
	end
	-- Keep the pull-back modest so the camera stays inside a normal-sized room.
	local dist = math.clamp(horizRadius * 1.3 + 8, 14, 30)

	-- Candidate horizontal directions: the platform's own axes if we have it.
	local axes
	if platform and platform:IsA("BasePart") then
		local cf = platform.CFrame
		local f = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
		local r = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
		f = (f.Magnitude > 0.05) and f.Unit or Vector3.new(0, 0, 1)
		r = (r.Magnitude > 0.05) and r.Unit or Vector3.new(1, 0, 0)
		axes = { f, -f, r, -r }
	else
		axes = { Vector3.new(0, 0, 1), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) }
	end

	-- Pick the direction whose camera spot is farthest from any pedestal (most open).
	local bestDir, bestClear = axes[1], -1
	for _, dir in ipairs(axes) do
		local camP = focus + dir * dist
		local nearest = math.huge
		for _, pp in ipairs(pedPositions) do
			local flat = Vector3.new(pp.X - camP.X, 0, pp.Z - camP.Z).Magnitude
			if flat < nearest then nearest = flat end
		end
		if nearest > bestClear then
			bestClear, bestDir = nearest, dir
		end
	end

	local eye = focus + bestDir * dist + Vector3.new(0, 5, 0)
	return CFrame.lookAt(eye, focus)
end

-- Tolerant name matching for the Studio-built room: ignores case and any spaces,
-- underscores or hyphens, so "RevealPlatform", "reveal platform" and
-- "Reveal_Platform" all resolve. Searches the whole subtree.
local function normName(s)
	return (string.lower(s):gsub("[%s_%-]", ""))
end

local function resolveChild(root, ...)
	if not root then return nil end
	local candidates = { ... }
	-- 1. exact recursive match (fast path)
	for _, name in ipairs(candidates) do
		local hit = root:FindFirstChild(name, true)
		if hit then return hit end
	end
	-- 2. normalized match across the whole subtree (catches case/space/underscore typos)
	local wanted = {}
	for _, name in ipairs(candidates) do wanted[normName(name)] = true end
	for _, d in ipairs(root:GetDescendants()) do
		if wanted[normName(d.Name)] then return d end
	end
	return nil
end

-- Score how "complete" an EndRoom candidate is, so we can pick the right one when
-- the place contains more than one object named EndRoom (a leftover/duplicate that
-- is missing parts would otherwise win just by being first in child order).
local function roomScore(room)
	local s = 0
	if resolveChild(room, "Pedestals") then s += 1 end
	if resolveChild(room, "RevealPlatform", "Platform") then s += 1 end
	if resolveChild(room, "CamPos", "CameraPos") then s += 1 end
	if resolveChild(room, "RevealSpot", "RevealPoint") then s += 1 end
	return s
end

-- Find every Model/Folder named "EndRoom" anywhere in Workspace and return the most
-- complete one (plus the total candidate count for diagnostics).
local function findBestEndRoom()
	local best, bestScore, count = nil, -1, 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if (d:IsA("Model") or d:IsA("Folder")) and normName(d.Name) == "endroom" then
			count += 1
			local s = roomScore(d)
			if s > bestScore then best, bestScore = d, s end
		end
	end
	return best, count
end

-- Find the EndRoom (built in Studio). It does not sync through Rojo, so resolve
-- it by name at runtime. Lookups are tolerant of case/space/underscore differences,
-- and we pick the most complete EndRoom in case a partial duplicate exists.
local endRoom, endRoomCount = findBestEndRoom()
if endRoom then
	print("PlaySequence: Using EndRoom at " .. endRoom:GetFullName() .. " (" .. tostring(endRoomCount) .. " candidate(s) found)")
end
if endRoomCount and endRoomCount > 1 then
	warn("PlaySequence: Found " .. endRoomCount .. " objects named 'EndRoom' - using the most complete one. Delete the leftover/duplicate to avoid confusion.")
end
-- Resolve the parts inside the chosen room; if they live outside it (e.g. as
-- siblings in Workspace), fall back to a workspace-wide search by their unique name.
local camPos = resolveChild(endRoom, "CamPos", "CameraPos") or resolveChild(workspace, "CamPos")
local pedestalsFolder = resolveChild(endRoom, "Pedestals") or resolveChild(workspace, "Pedestals")
local revealPlatform = resolveChild(endRoom, "RevealPlatform", "Platform") or resolveChild(workspace, "RevealPlatform")

local winnerKey, winnerScore, tiedKeys, allZero = analyzeResults(finalScores)
local isTie = (#tiedKeys >= 2) and not allZero
print(string.format(
	"PlaySequence: Final scores - Aviation:%d Chef:%d Nurse:%d Cyber:%d  =>  Winner: %s (%d)%s",
	finalScores.Aviation, finalScores.Chef, finalScores.Nurse, finalScores.Cyber, winnerKey, winnerScore,
	allZero and "  [ALL SKIPPED]" or (isTie and ("  [TIE: " .. joinCareerNames(tiedKeys) .. "]") or "")
))

-- Per-piece diagnostics so a missing/misnamed instance is obvious in Output.
-- Only EndRoom + Pedestals are strictly required; RevealPlatform and CamPos are
-- optional (the reveal degrades gracefully without them).
if not endRoom then warn("PlaySequence: EndRoom not found in Workspace - using simple text ending") end
if endRoom and not pedestalsFolder then warn("PlaySequence: EndRoom has no 'Pedestals' folder - using simple text ending") end
if endRoom and not revealPlatform then warn("PlaySequence: EndRoom has no 'RevealPlatform' - the winning pedestal will rise on its own (check the part's exact name)") end
if endRoom and not camPos then warn("PlaySequence: EndRoom has no 'CamPos' part - computing a camera angle automatically (add a CamPos part for exact framing)") end

-- If something required/expected is missing, dump the chosen EndRoom's full path and
-- its child names so the real (possibly misspelled / wrong-room) names are visible.
if endRoom and (not pedestalsFolder or not revealPlatform or not camPos) then
	local names = {}
	for _, c in ipairs(endRoom:GetChildren()) do
		table.insert(names, c.Name .. " [" .. c.ClassName .. "]")
	end
	warn("PlaySequence: Using EndRoom at " .. endRoom:GetFullName() .. " | children = { " .. table.concat(names, ", ") .. " }")
end

-- The reveal needs the room and the pedestals folder. CamPos, RevealPlatform and
-- the winning pedestal are all resolved defensively below.
local hasRoom = endRoom ~= nil and pedestalsFolder ~= nil

if hasRoom then
	-- ========== 1. BRIGHT FLASH ==========
	-- Screen is currently solid black (cyber world ended with coverBlack). Brighten
	-- it to white ("shines bright"), then we set up the camera behind the flash.
	worldFadeGui.DisplayOrder = 960
	worldFadeFrame.Visible = true
	worldFadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	worldFadeFrame.BackgroundTransparency = 0
	TweenService:Create(worldFadeFrame,
		TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ BackgroundColor3 = Color3.new(1, 1, 1) }
	):Play()
	task.wait(0.7)

	-- ========== 2. STREAM IN THE ROOM, LOCK CHARACTER, PLACE CAMERA ==========
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	-- The EndRoom is far from where the player finishes (the cyber lab). With
	-- StreamingEnabled the room's BaseParts (CamPos/RevealSpot/RevealPlatform and the
	-- pedestal toppers) are NOT loaded on the client until the player is near it,
	-- which is why they resolved as "none" and the camera framed empty city/skybox.
	-- Move the character into the room and request streaming, then wait for the parts
	-- to load. (Safe no-op when streaming is off / parts are already present.)
	-- Derive the room position from the pedestal models, whose pivots replicate even
	-- when their parts are streamed out. Works whether EndRoom is a Model or Folder.
	local roomPos
	do
		if endRoom:IsA("Model") then
			local ok, cf = pcall(function() return endRoom:GetPivot() end)
			if ok then roomPos = cf.Position end
		end
		if not roomPos then
			local sum, n = Vector3.zero, 0
			for _, ped in ipairs(pedestalsFolder:GetChildren()) do
				if ped:IsA("Model") or ped:IsA("BasePart") then sum += ped:GetPivot().Position; n += 1 end
			end
			roomPos = (n > 0) and (sum / n) or Vector3.zero
		end
	end
	if hrp then
		hrp.CFrame = CFrame.new(roomPos + Vector3.new(0, 8, 0))
	end
	-- Point the camera at the room now (screen is white) so streaming, which follows
	-- the local player's character AND camera, loads this area.
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(roomPos + Vector3.new(0, 12, 34), roomPos)
	pcall(function()
		player:RequestStreamingAround(roomPos)
	end)
	local streamStart = os.clock()
	repeat
		camPos = camPos or resolveChild(endRoom, "CamPos", "CameraPos") or resolveChild(workspace, "CamPos")
		revealPlatform = revealPlatform or resolveChild(endRoom, "RevealPlatform", "Platform") or resolveChild(workspace, "RevealPlatform")
		-- Best case: CamPos loaded (EndRoom persistent) -> proceed instantly.
		if camPos then break end
		-- If the in-room parts are loaded but CamPos still isn't after a moment, it
		-- likely sits outside the stream radius or doesn't exist; stop waiting and use
		-- the auto-framed camera instead of stalling on a white screen.
		if revealPlatform and (os.clock() - streamStart) > 2.5 then break end
		task.wait(0.2)
	until (os.clock() - streamStart) > 5
	print(string.format("PlaySequence: After streaming - camPos=%s platform=%s",
		camPos and "found" or "none", revealPlatform and "found" or "none"))

	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end
	if hrp then
		hrp.Anchored = true
	end

	-- Where the reveal happens (the winning pedestal's resting spot). Resolved up
	-- front so the camera can AIM at it. Priority: RevealSpot > platform top >
	-- center of the pedestals.
	local revealSpot = resolveChild(endRoom, "RevealSpot", "RevealPoint") or resolveChild(workspace, "RevealSpot")
	local revealTarget
	if revealSpot then
		revealTarget = revealSpot.Position + Vector3.new(0, 3, 0)
	elseif revealPlatform then
		revealTarget = topCenterOf(revealPlatform) + Vector3.new(0, 3, 0)
	else
		local sum, n = Vector3.zero, 0
		for _, ped in ipairs(pedestalsFolder:GetChildren()) do
			if ped:IsA("Model") or ped:IsA("BasePart") then sum += ped:GetPivot().Position; n += 1 end
		end
		revealTarget = (n > 0 and (sum / n) or Vector3.zero) + Vector3.new(0, 3, 0)
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 60
	-- Always look at the reveal target. Use the hand-placed CamPos only for the
	-- vantage point (its orientation is ignored, so a mis-aimed CamPos can't make
	-- us stare at a wall). If CamPos is missing or sitting on top of the target,
	-- compute a sensible framing instead.
	if camPos and (camPos.Position - revealTarget).Magnitude > 2 then
		camera.CFrame = CFrame.lookAt(camPos.Position, revealTarget)
	else
		camera.CFrame = computeFallbackCam(pedestalsFolder, revealPlatform, revealTarget)
	end
	print(string.format(
		"PlaySequence: End camera pos=%s -> target=%s | camPos=%s | revealSpot=%s | platform=%s",
		tostring(camera.CFrame.Position), tostring(revealTarget),
		camPos and camPos:GetFullName() or "none",
		revealSpot and revealSpot:GetFullName() or "none",
		revealPlatform and revealPlatform:GetFullName() or "none"
	))
	task.wait(0.3)

	-- ========== 3. REVEAL THE ROOM (flash slowly returns to normal) ==========
	TweenService:Create(worldFadeFrame,
		TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	):Play()
	-- Gentle push-in for cinematic feel.
	TweenService:Create(camera, TweenInfo.new(3.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = 55 }):Play()
	task.wait(1.4)

	-- Intro caption while the player takes in the room.
	local endGui = Instance.new("ScreenGui")
	endGui.Name = "AptitudeRevealUI"
	endGui.IgnoreGuiInset = true
	endGui.DisplayOrder = 970
	endGui.ResetOnSpawn = false
	endGui.Parent = playerGui

	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.new(1, 0, 0, 50)
	caption.Position = UDim2.new(0, 0, 0.12, 0)
	caption.BackgroundTransparency = 1
	caption.Text = "ANALYZING YOUR APTITUDE..."
	caption.TextColor3 = Color3.fromRGB(235, 240, 255)
	caption.TextSize = 30
	caption.Font = Enum.Font.GothamBold
	caption.TextTransparency = 1
	caption.Parent = endGui
	TweenService:Create(caption, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()

	-- ========== 4. AUTO TRIGGER AFTER ~2s ==========
	task.wait(2.0)

	-- ========== 5. REVEAL ANIMATION ==========
	-- With a center platform: it sinks into the floor, then (for a single winner)
	-- rises carrying a clone of that career's pedestal, or rises empty for a tie /
	-- all-skipped run. Without a platform we still raise the winning pedestal from
	-- below, so the reveal works even if the platform part is missing/misnamed.
	local SINK_DEPTH = 16
	-- (revealSpot was resolved above, near the camera setup.)

	-- Platform motion (only if a platform exists): sink it first.
	local platStart, platDown, platTopRest
	if revealPlatform then
		platStart = revealPlatform:GetPivot()
		platDown = platStart * CFrame.new(0, -SINK_DEPTH, 0)
		-- Capture the resting top surface BEFORE sinking, so the no-marker fallback
		-- rests the pedestal at the correct height (not the sunken height).
		platTopRest = topCenterOf(revealPlatform)
		tweenPivot(revealPlatform, platDown, 0.9)
		task.wait(0.15)
	end

	local sourcePedestal = (not allZero and not isTie)
		and pedestalsFolder:FindFirstChild("Pedestal_" .. winnerKey) or nil
	if (not allZero and not isTie) and not sourcePedestal then
		warn("PlaySequence: Pedestal_" .. tostring(winnerKey) .. " not found in Pedestals - revealing without a crowned pedestal")
	end

	if sourcePedestal then
		-- Clone the winning pedestal below its rest spot and raise it into view.
		local clone = sourcePedestal:Clone()
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end

		-- Resting CFrame priority: RevealSpot marker > platform top surface > a spot
		-- in front of the camera as a last resort.
		local pedRestCF
		if revealSpot then
			pedRestCF = revealSpot.CFrame
		elseif platTopRest then
			clone:PivotTo(CFrame.new(platTopRest)) -- temp place to measure base offset
			local restY = platTopRest.Y + pivotToBottom(clone)
			pedRestCF = CFrame.new(platTopRest.X, restY, platTopRest.Z)
		else
			local camCF = camera.CFrame
			pedRestCF = CFrame.new(camCF.Position + camCF.LookVector * 18 - Vector3.new(0, 3, 0))
		end
		local pedDownCF = pedRestCF * CFrame.new(0, -SINK_DEPTH, 0)

		clone:PivotTo(pedDownCF)
		clone.Parent = endRoom

		if revealPlatform then
			-- Raise platform + pedestal together back to floor level.
			raiseTogether(revealPlatform, platDown, platStart, clone, pedDownCF, pedRestCF, 1.2)
		else
			-- No platform: raise the pedestal on its own.
			tweenPivot(clone, pedRestCF, 1.2)
		end
	else
		-- Tie or all-skipped: nothing to crown. Raise the empty platform back up (or
		-- just hold a beat if there is no platform). The result text explains why.
		if revealPlatform then
			task.wait(0.4)
			tweenPivot(revealPlatform, platStart, 1.2)
		else
			task.wait(0.8)
		end
	end

	-- ========== 6. RESULT TEXT ==========
	-- Accent: career color for a winner, warm gold for a tie, neutral for all-skipped.
	local accent
	if allZero then
		accent = Color3.fromRGB(225, 230, 240)
	elseif isTie then
		accent = Color3.fromRGB(250, 210, 120)
	else
		accent = CAREER_ACCENT[winnerKey] or Color3.fromRGB(235, 240, 255)
	end

	TweenService:Create(caption, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	task.wait(0.4)

	-- Headline (career name / tie / inconclusive).
	local headline = Instance.new("TextLabel")
	headline.Size = UDim2.new(1, -80, 0, 80)
	headline.Position = UDim2.new(0, 40, 0.12, 44)
	headline.BackgroundTransparency = 1
	headline.TextWrapped = true
	headline.TextColor3 = accent
	headline.Font = Enum.Font.GothamBlack
	headline.TextTransparency = 1
	headline.Parent = endGui

	-- Sub line (tagline + score / "play again" prompt).
	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -120, 0, 70)
	sub.Position = UDim2.new(0, 60, 0.12, 128)
	sub.BackgroundTransparency = 1
	sub.TextWrapped = true
	sub.TextColor3 = Color3.fromRGB(185, 195, 215)
	sub.Font = Enum.Font.GothamMedium
	sub.TextTransparency = 1
	sub.Parent = endGui

	if allZero then
		caption.Text = "INCONCLUSIVE"
		headline.Text = "We can't decide what career is best if you didn't do any of them!"
		headline.TextSize = 32
		sub.Text = "Play again and actually take on the careers to find your best fit."
		sub.TextSize = 20
	elseif isTie then
		caption.Text = "IT'S A TIE!"
		headline.Text = "You were tied between " .. joinCareerNames(tiedKeys) .. "!"
		headline.TextSize = 36
		sub.Text = "Play again to see exactly which career you would be better at!"
		sub.TextSize = 20
	else
		caption.Text = "YOU ARE MOST SUITED TO BE A"
		headline.Text = CAREER_DISPLAY[winnerKey] or winnerKey
		headline.TextSize = 52
		sub.Text = (CAREER_TAGLINE[winnerKey] or "") .. "   (" .. tostring(winnerScore) .. "/100)"
		sub.TextSize = 20
	end

	caption.TextSize = 24
	caption.TextColor3 = Color3.fromRGB(210, 218, 235)
	TweenService:Create(caption, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	TweenService:Create(headline, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
	task.delay(0.3, function()
		TweenService:Create(sub, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
	end)

	-- ========== 7. HOLD, THEN BLUR + "TRY AGAIN?" MENU ==========
	task.wait(4.0)

	local endBlur = Lighting:FindFirstChild("EndScreenBlur")
	if not endBlur then
		endBlur = Instance.new("BlurEffect")
		endBlur.Name = "EndScreenBlur"
		endBlur.Size = 0
		endBlur.Parent = Lighting
	end
	TweenService:Create(endBlur, TweenInfo.new(0.8), { Size = 24 }):Play()

	-- Fade the result text out so the menu is the focus.
	for _, lbl in ipairs({ caption, headline, sub }) do
		TweenService:Create(lbl, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
	end
	task.wait(0.6)

	-- Compute overall average from all four world scores
	local function scoreColor(s)
		if s >= 70 then return Color3.fromRGB(68, 218, 118)
		elseif s >= 40 then return Color3.fromRGB(251, 191, 36)
		elseif s > 0  then return Color3.fromRGB(245, 100, 100)
		else               return Color3.fromRGB(130, 140, 160) end
	end
	local worldOrder = { "Aviation", "Chef", "Nurse", "Cyber" }
	local worldLabel = { Aviation = "✈  Aviation", Chef = "🍳  Culinary", Nurse = "🏥  Healthcare", Cyber = "💻  Cybersecurity" }
	local playedCount, scoreSum = 0, 0
	for _, k in ipairs(worldOrder) do
		local s = finalScores[k] or 0
		if s > 0 then playedCount += 1; scoreSum += s end
	end
	local overallAvg = playedCount > 0 and math.floor(scoreSum / playedCount) or 0

	-- Menu panel — taller to fit score breakdown
	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 480, 0, 430)
	panel.Position = UDim2.new(0.5, -240, 0.5, -215)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
	panel.BackgroundTransparency = 1
	panel.Parent = endGui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 18)
	panelCorner.Parent = panel
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = accent
	panelStroke.Thickness = 2
	panelStroke.Transparency = 1
	panelStroke.Parent = panel

	local panelTitle = Instance.new("TextLabel")
	panelTitle.Size = UDim2.new(1, -40, 0, 40)
	panelTitle.Position = UDim2.new(0, 20, 0, 22)
	panelTitle.BackgroundTransparency = 1
	panelTitle.Text = allZero and "HOLD ON..." or (isTie and "SO CLOSE!" or "CONGRATULATIONS")
	panelTitle.TextColor3 = Color3.fromRGB(245, 248, 255)
	panelTitle.TextSize = 28
	panelTitle.Font = Enum.Font.GothamBlack
	panelTitle.TextTransparency = 1
	panelTitle.Parent = panel

	local panelSub = Instance.new("TextLabel")
	panelSub.Size = UDim2.new(1, -60, 0, 44)
	panelSub.Position = UDim2.new(0, 30, 0, 66)
	panelSub.BackgroundTransparency = 1
	panelSub.TextWrapped = true
	if allZero then
		panelSub.Text = "You skipped every career, so there's nothing to compare. Play again and give them a real shot!"
	elseif isTie then
		panelSub.Text = "It was a tie between " .. joinCareerNames(tiedKeys) .. ". Play again to break the tie!"
	else
		panelSub.Text = "You explored four careers and found your best fit: "
			.. (CAREER_DISPLAY[winnerKey] or winnerKey) .. "."
	end
	panelSub.TextColor3 = Color3.fromRGB(185, 195, 215)
	panelSub.TextSize = 16
	panelSub.Font = Enum.Font.GothamMedium
	panelSub.TextTransparency = 1
	panelSub.Parent = panel

	-- Divider line
	local divLine = Instance.new("Frame")
	divLine.Size = UDim2.new(1, -60, 0, 1)
	divLine.Position = UDim2.new(0, 30, 0, 118)
	divLine.BackgroundColor3 = Color3.fromRGB(60, 70, 100)
	divLine.BackgroundTransparency = 1
	divLine.BorderSizePixel = 0
	divLine.Parent = panel

	-- "FINAL SCORES" label
	local scoresHeader = Instance.new("TextLabel")
	scoresHeader.Size = UDim2.new(1, -60, 0, 20)
	scoresHeader.Position = UDim2.new(0, 30, 0, 128)
	scoresHeader.BackgroundTransparency = 1
	scoresHeader.Text = "FINAL SCORES"
	scoresHeader.TextColor3 = Color3.fromRGB(140, 155, 190)
	scoresHeader.TextSize = 11
	scoresHeader.Font = Enum.Font.Code
	scoresHeader.TextXAlignment = Enum.TextXAlignment.Left
	scoresHeader.TextTransparency = 1
	scoresHeader.Parent = panel

	-- One row per world
	local rowY = 154
	local scoreRows = {}
	for _, k in ipairs(worldOrder) do
		local s = finalScores[k] or 0
		local col = scoreColor(s)

		local rowBg = Instance.new("Frame")
		rowBg.Size = UDim2.new(1, -60, 0, 34)
		rowBg.Position = UDim2.new(0, 30, 0, rowY)
		rowBg.BackgroundColor3 = Color3.fromRGB(26, 32, 50)
		rowBg.BackgroundTransparency = 1
		rowBg.BorderSizePixel = 0
		rowBg.Parent = panel
		local rbCorner = Instance.new("UICorner")
		rbCorner.CornerRadius = UDim.new(0, 7)
		rbCorner.Parent = rowBg

		local rowName = Instance.new("TextLabel")
		rowName.Size = UDim2.new(0.6, 0, 1, 0)
		rowName.Position = UDim2.new(0, 12, 0, 0)
		rowName.BackgroundTransparency = 1
		rowName.Text = worldLabel[k]
		rowName.TextColor3 = Color3.fromRGB(210, 218, 235)
		rowName.TextSize = 14
		rowName.Font = Enum.Font.GothamMedium
		rowName.TextXAlignment = Enum.TextXAlignment.Left
		rowName.TextTransparency = 1
		rowName.Parent = rowBg

		local rowScore = Instance.new("TextLabel")
		rowScore.Size = UDim2.new(0.38, 0, 1, 0)
		rowScore.Position = UDim2.new(0.62, 0, 0, 0)
		rowScore.BackgroundTransparency = 1
		rowScore.Text = s > 0 and (tostring(s) .. " / 100") or "Skipped"
		rowScore.TextColor3 = col
		rowScore.TextSize = 14
		rowScore.Font = Enum.Font.GothamBold
		rowScore.TextXAlignment = Enum.TextXAlignment.Right
		rowScore.TextTransparency = 1
		rowScore.Parent = rowBg

		table.insert(scoreRows, {rowBg, rowName, rowScore})
		rowY = rowY + 40
	end

	-- Overall average bar
	local avgBar = Instance.new("Frame")
	avgBar.Size = UDim2.new(1, -60, 0, 40)
	avgBar.Position = UDim2.new(0, 30, 0, rowY + 4)
	avgBar.BackgroundColor3 = Color3.fromRGB(30, 38, 62)
	avgBar.BackgroundTransparency = 1
	avgBar.BorderSizePixel = 0
	avgBar.Parent = panel
	local abCorner = Instance.new("UICorner")
	abCorner.CornerRadius = UDim.new(0, 9)
	abCorner.Parent = avgBar
	local abStroke = Instance.new("UIStroke")
	abStroke.Color = scoreColor(overallAvg)
	abStroke.Thickness = 1.5
	abStroke.Transparency = 1
	abStroke.Parent = avgBar

	local avgLbl = Instance.new("TextLabel")
	avgLbl.Size = UDim2.new(0.6, 0, 1, 0)
	avgLbl.Position = UDim2.new(0, 12, 0, 0)
	avgLbl.BackgroundTransparency = 1
	avgLbl.Text = "OVERALL AVERAGE"
	avgLbl.TextColor3 = Color3.fromRGB(235, 242, 255)
	avgLbl.TextSize = 14
	avgLbl.Font = Enum.Font.GothamBold
	avgLbl.TextXAlignment = Enum.TextXAlignment.Left
	avgLbl.TextTransparency = 1
	avgLbl.Parent = avgBar

	local avgVal = Instance.new("TextLabel")
	avgVal.Size = UDim2.new(0.38, 0, 1, 0)
	avgVal.Position = UDim2.new(0.62, 0, 0, 0)
	avgVal.BackgroundTransparency = 1
	avgVal.Text = overallAvg > 0 and (tostring(overallAvg) .. " / 100") or "N/A"
	avgVal.TextColor3 = scoreColor(overallAvg)
	avgVal.TextSize = 16
	avgVal.Font = Enum.Font.GothamBlack
	avgVal.TextXAlignment = Enum.TextXAlignment.Right
	avgVal.TextTransparency = 1
	avgVal.Parent = avgBar

	local tryAgainBtn = Instance.new("TextButton")
	tryAgainBtn.Size = UDim2.new(0, 260, 0, 50)
	tryAgainBtn.Position = UDim2.new(0.5, -130, 1, -72)
	tryAgainBtn.BackgroundColor3 = accent
	tryAgainBtn.BackgroundTransparency = 1
	tryAgainBtn.Text = "TRY AGAIN"
	tryAgainBtn.TextColor3 = Color3.fromRGB(15, 18, 28)
	tryAgainBtn.TextSize = 22
	tryAgainBtn.Font = Enum.Font.GothamBold
	tryAgainBtn.TextTransparency = 1
	tryAgainBtn.AutoButtonColor = true
	tryAgainBtn.Parent = panel
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = tryAgainBtn

	-- Animate the menu in.
	TweenService:Create(panel, TweenInfo.new(0.5), { BackgroundTransparency = 0.05 }):Play()
	TweenService:Create(panelStroke, TweenInfo.new(0.5), { Transparency = 0 }):Play()
	TweenService:Create(panelTitle, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
	TweenService:Create(panelSub, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
	TweenService:Create(divLine, TweenInfo.new(0.5), { BackgroundTransparency = 0.4 }):Play()
	TweenService:Create(scoresHeader, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	for i, row in ipairs(scoreRows) do
		local delay = 0.08 * i
		task.delay(delay, function()
			TweenService:Create(row[1], TweenInfo.new(0.4), { BackgroundTransparency = 0.3 }):Play()
			TweenService:Create(row[2], TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
			TweenService:Create(row[3], TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
		end)
	end
	task.delay(0.35, function()
		TweenService:Create(avgBar, TweenInfo.new(0.4), { BackgroundTransparency = 0.2 }):Play()
		TweenService:Create(abStroke, TweenInfo.new(0.4), { Transparency = 0 }):Play()
		TweenService:Create(avgLbl, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
		TweenService:Create(avgVal, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	end)
	TweenService:Create(tryAgainBtn, TweenInfo.new(0.6), { TextTransparency = 0, BackgroundTransparency = 0 }):Play()

	local restarting = false
	tryAgainBtn.MouseButton1Click:Connect(function()
		if restarting then return end
		restarting = true
		tryAgainBtn.Text = "RESTARTING..."
		-- Reloading the place is the clean way to fully reset scores and worlds.
		local ok, err = pcall(function()
			TeleportService:Teleport(game.PlaceId, player)
		end)
		if not ok then
			warn("PlaySequence: Try Again teleport failed (expected in some Studio playtests): " .. tostring(err))
			tryAgainBtn.Text = "RESTART UNAVAILABLE IN STUDIO"
		end
	end)

	print("=== PlaySequence complete - Aptitude reveal shown! Winner: " .. winnerKey .. " ===")
else
	-- ========== FALLBACK: EndRoom not found - simple text ending ==========
	warn("PlaySequence: EndRoom (or its CamPos/Pedestals/RevealPlatform/winning pedestal) not found - using simple text ending")

	TweenService:Create(worldFadeFrame,
		TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0 }
	):Play()
	task.wait(1.5)

	local gameCompleteLabel = Instance.new("TextLabel")
	gameCompleteLabel.Size = UDim2.new(1, 0, 0, 60)
	gameCompleteLabel.Position = UDim2.new(0, 0, 0.4, 0)
	gameCompleteLabel.BackgroundTransparency = 1
	gameCompleteLabel.Text = "CONGRATULATIONS - YOU HAVE AWAKENED"
	gameCompleteLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	gameCompleteLabel.TextSize = 36
	gameCompleteLabel.Font = Enum.Font.GothamBold
	gameCompleteLabel.TextTransparency = 1
	gameCompleteLabel.Parent = worldFadeGui

	local fitLabel = Instance.new("TextLabel")
	fitLabel.Size = UDim2.new(1, -120, 0, 60)
	fitLabel.Position = UDim2.new(0, 60, 0.4, 70)
	fitLabel.BackgroundTransparency = 1
	fitLabel.TextWrapped = true
	if allZero then
		fitLabel.Text = "We can't decide what career is best if you didn't do any of them!"
		fitLabel.TextColor3 = Color3.fromRGB(225, 230, 240)
	elseif isTie then
		fitLabel.Text = "You were tied between " .. joinCareerNames(tiedKeys)
			.. "! Play again to see exactly which career you would be better at!"
		fitLabel.TextColor3 = Color3.fromRGB(250, 210, 120)
	else
		fitLabel.Text = "Your best-fit career: " .. (CAREER_DISPLAY[winnerKey] or winnerKey)
		fitLabel.TextColor3 = CAREER_ACCENT[winnerKey] or Color3.fromRGB(200, 210, 230)
	end
	fitLabel.TextSize = 24
	fitLabel.Font = Enum.Font.GothamMedium
	fitLabel.TextTransparency = 1
	fitLabel.Parent = worldFadeGui

	TweenService:Create(gameCompleteLabel, TweenInfo.new(1.0), { TextTransparency = 0 }):Play()
	TweenService:Create(fitLabel, TweenInfo.new(1.0), { TextTransparency = 0 }):Play()

	print("=== PlaySequence complete - Game finished! (no EndRoom) ===")
end
