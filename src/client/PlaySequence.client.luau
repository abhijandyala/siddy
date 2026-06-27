-- PlaySequence.client.luau
-- Handles the post-Play flow:
--   1. 15-second forced tutorial (3 image slides, 5s each)
--   2. Camera transition to Camera_LabIntro in the Cybersecurity ComputerRoom
--   3. Fade from black to reveal the lab

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- RESET CAMERA SETTINGS to prevent interference from other scripts
-- This ensures the cybersecurity section camera works correctly
player.CameraMinZoomDistance = 0.5
player.CameraMaxZoomDistance = 128
camera.FieldOfView = 70 -- Default FOV
print("PlaySequence: Camera settings reset for cybersecurity section")

-- ============================================
-- SKIP BUTTON (bottom left, changes color per world)
-- ============================================
local UserInputService = game:GetService("UserInputService")

-- World colors
local WORLD_COLORS = {
	Cyber = Color3.fromRGB(60, 140, 255),    -- Blue
	Medical = Color3.fromRGB(74, 222, 128),   -- Green
	Chef = Color3.fromRGB(251, 146, 60),      -- Orange (not used, skip hidden in chef)
}

-- Current world tracking
local currentWorld = "Cyber"
local skipTriggered = false
local skipButtonVisible = false

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

-- ============================================
-- CREATE TUTORIAL GUI LAYER
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

-- Dark navy blue background for the tutorial
local tutorialBg = Instance.new("Frame")
tutorialBg.Name = "Background"
tutorialBg.Size = UDim2.new(1, 0, 1, 0)
tutorialBg.BackgroundColor3 = Color3.fromRGB(5, 10, 25)
tutorialBg.BackgroundTransparency = 0
tutorialBg.BorderSizePixel = 0
tutorialBg.Parent = tutorialGui

-- ============================================
-- BUILD TUTORIAL SLIDE CARDS (code-generated UI)
-- ============================================

local CARD_COLOR = Color3.fromRGB(12, 20, 45)  -- Match menu panel color
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)

local slideCards = {}

for i, data in ipairs(TUTORIAL_SLIDES) do
	-- Card container (dark navy rounded rectangle, centered)
	local card = Instance.new("Frame")
	card.Name = "SlideCard_" .. i
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Size = UDim2.new(0.55, 0, 0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0.45, 0)
	card.BackgroundColor3 = CARD_COLOR
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = tutorialBg

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 28)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "CardStroke"
	cardStroke.Color = Color3.fromRGB(60, 140, 255)  -- Electric blue
	cardStroke.Transparency = 1  -- Starts invisible, fades in with card
	cardStroke.Thickness = 2
	cardStroke.Parent = card

	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingTop = UDim.new(0, 28)
	cardPadding.PaddingBottom = UDim.new(0, 28)
	cardPadding.PaddingLeft = UDim.new(0, 36)
	cardPadding.PaddingRight = UDim.new(0, 36)
	cardPadding.Parent = card

	-- Title label
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = data.title
	title.TextColor3 = TEXT_COLOR
	title.TextSize = 32
	title.Font = Enum.Font.Code
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextTransparency = 1
	title.TextWrapped = true
	title.Parent = card

	-- Body label
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 1, -60)
	body.Position = UDim2.new(0, 0, 0, 60)
	body.BackgroundTransparency = 1
	body.Text = data.body
	body.TextColor3 = TEXT_COLOR
	body.TextSize = 22
	body.Font = Enum.Font.Code
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextTransparency = 1
	body.TextWrapped = true
	body.LineHeight = 1.4
	body.Parent = card

	slideCards[i] = { card = card, title = title, body = body, stroke = cardStroke }
end

print("PlaySequence: Built " .. #slideCards .. " tutorial slide cards")

-- Slide counter text ("1 / 3")
local slideCounter = Instance.new("TextLabel")
slideCounter.Name = "SlideCounter"
slideCounter.AnchorPoint = Vector2.new(0.5, 0)
slideCounter.Size = UDim2.new(0, 80, 0, 28)
slideCounter.Position = UDim2.new(0.5, 0, 0.88, 0)
slideCounter.BackgroundTransparency = 1
slideCounter.TextColor3 = Color3.fromRGB(100, 160, 220)  -- Light blue
slideCounter.TextSize = 16
slideCounter.Font = Enum.Font.GothamMedium
slideCounter.Text = ""
slideCounter.TextTransparency = 1
slideCounter.Parent = tutorialBg

-- Progress bar background
local progressBg = Instance.new("Frame")
progressBg.Name = "ProgressBarBg"
progressBg.AnchorPoint = Vector2.new(0.5, 0)
progressBg.Size = UDim2.new(0.5, 0, 0, 4)
progressBg.Position = UDim2.new(0.5, 0, 0.93, 0)
progressBg.BackgroundColor3 = Color3.fromRGB(20, 30, 60)  -- Dark blue track
progressBg.BorderSizePixel = 0
progressBg.Parent = tutorialBg

local progressCornerBg = Instance.new("UICorner")
progressCornerBg.CornerRadius = UDim.new(0, 2)
progressCornerBg.Parent = progressBg

-- Progress bar fill
local progressFill = Instance.new("Frame")
progressFill.Name = "Fill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(60, 140, 255)  -- Electric blue fill
progressFill.BackgroundTransparency = 0
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBg

local progressCornerFill = Instance.new("UICorner")
progressCornerFill.CornerRadius = UDim.new(0, 2)
progressCornerFill.Parent = progressFill

-- ============================================
-- SKIP BUTTON (bottom right, clean minimal style)
-- ============================================

local tutorialSkipped = false

local skipButton = Instance.new("TextButton")
skipButton.Name = "SkipButton"
skipButton.AnchorPoint = Vector2.new(1, 1)
skipButton.Size = UDim2.new(0, 100, 0, 36)
skipButton.Position = UDim2.new(0.95, 0, 0.95, 0)
skipButton.BackgroundColor3 = Color3.fromRGB(20, 40, 80)  -- Dark blue
skipButton.BackgroundTransparency = 1
skipButton.BorderSizePixel = 0
skipButton.Text = "SKIP"
skipButton.TextColor3 = Color3.fromRGB(150, 200, 255)  -- Light blue text
skipButton.TextSize = 14
skipButton.Font = Enum.Font.GothamMedium
skipButton.TextTransparency = 1
skipButton.AutoButtonColor = false  -- We handle hover ourselves
skipButton.Parent = tutorialBg

local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0, 8)
skipCorner.Parent = skipButton

local skipStroke = Instance.new("UIStroke")
skipStroke.Color = Color3.fromRGB(60, 140, 255)  -- Electric blue border
skipStroke.Transparency = 1
skipStroke.Thickness = 1.5
skipStroke.Parent = skipButton

-- Skip button hover animations
skipButton.MouseEnter:Connect(function()
	if tutorialSkipped then return end
	TweenService:Create(skipButton,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundColor3 = Color3.fromRGB(40, 80, 160), BackgroundTransparency = 0.3}
	):Play()
	TweenService:Create(skipStroke,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0.2}
	):Play()
end)

skipButton.MouseLeave:Connect(function()
	if tutorialSkipped then return end
	TweenService:Create(skipButton,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundColor3 = Color3.fromRGB(20, 40, 80), BackgroundTransparency = 0.7}
	):Play()
	TweenService:Create(skipStroke,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0.5}
	):Play()
end)

-- Fade skip button in smoothly over 1 second
task.spawn(function()
	task.wait(1.0)
	if tutorialSkipped then return end
	TweenService:Create(skipButton,
		TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextTransparency = 0, BackgroundTransparency = 0.7}
	):Play()
	TweenService:Create(skipStroke,
		TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Transparency = 0.5}
	):Play()
end)

-- Skip button click handler
skipButton.MouseButton1Click:Connect(function()
	if tutorialSkipped then return end
	tutorialSkipped = true
	print("PlaySequence: Tutorial skipped!")
	
	-- Fade out the skip button immediately
	TweenService:Create(skipButton,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{TextTransparency = 1, BackgroundTransparency = 1}
	):Play()
	TweenService:Create(skipStroke,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Transparency = 1}
	):Play()
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
	if slide.stroke then
		slide.stroke.Transparency = 1
	end
	-- Reset card size/position for next entrance
	slide.card.Size = UDim2.new(0.55, 0, 0.5, 0)
	slide.card.Position = UDim2.new(0.5, 0, 0.45, 0)
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
	
	-- Reset everything invisible and set initial transform
	slide.card.BackgroundTransparency = 1
	slide.title.TextTransparency = 1
	slide.body.TextTransparency = 1
	if slide.stroke then
		slide.stroke.Transparency = 1
	end
	
	-- Start card slightly smaller and offset up for entrance animation
	slide.card.Size = UDim2.new(0.52, 0, 0.47, 0)
	slide.card.Position = UDim2.new(0.5, 0, 0.43, 0)
	
	-- Start title offset to the left for slide-in
	local originalTitlePos = slide.title.Position
	slide.title.Position = UDim2.new(originalTitlePos.X.Scale - 0.05, originalTitlePos.X.Offset - 20, originalTitlePos.Y.Scale, originalTitlePos.Y.Offset)
	
	slide.card.Visible = true
	
	-- 1) Card scales up and slides into position with bounce
	local CARD_ENTRANCE = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(slide.card, CARD_ENTRANCE, {
		Size = UDim2.new(0.55, 0, 0.5, 0),
		Position = UDim2.new(0.5, 0, 0.45, 0),
		BackgroundTransparency = 0
	}):Play()
	if slide.stroke then
		TweenService:Create(slide.stroke, FADE_IN, {Transparency = 0.4}):Play()
	end
	
	-- 2) Title slides in from left after short delay
	task.delay(0.15, function()
		if tutorialSkipped then return end
		TweenService:Create(slide.title, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = originalTitlePos,
			TextTransparency = 0
		}):Play()
	end)
	
	-- 3) Body text fades in after title
	task.delay(0.4, function()
		if tutorialSkipped then return end
		TweenService:Create(slide.body, FADE_IN, {TextTransparency = 0}):Play()
	end)
	
	-- 4) Border pulse animation while card is visible
	if slide.stroke then
		task.spawn(function()
			task.wait(0.5)  -- Wait for card to fully appear
			while slide.card.Visible and not tutorialSkipped do
				TweenService:Create(slide.stroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Transparency = 0.6
				}):Play()
				task.wait(1.2)
				if not slide.card.Visible or tutorialSkipped then break end
				TweenService:Create(slide.stroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Transparency = 0.3
				}):Play()
				task.wait(1.2)
			end
		end)
	end
	
	-- Counter + progress bar
	slideCounter.Text = slideIndex .. " / " .. totalSlides
	TweenService:Create(slideCounter, FADE_IN, {TextTransparency = 0.3}):Play()
	
	local startProgress = (slideIndex - 1) / totalSlides
	local endProgress = slideIndex / totalSlides
	progressFill.Size = UDim2.new(startProgress, 0, 1, 0)
	
	local progressTween = TweenService:Create(
		progressFill,
		TweenInfo.new(SLIDE_DURATION, Enum.EasingStyle.Linear),
		{Size = UDim2.new(endProgress, 0, 1, 0)}
	)
	progressTween:Play()
	
	-- Hold for the slide duration (minus fade out time at end)
	local skipped = waitInterruptible(SLIDE_DURATION - 0.4)
	
	if skipped then
		progressTween:Cancel()
		hideSlide(slide)
		return
	end
	
	-- Fade everything out together
	TweenService:Create(slide.card, FADE_OUT, {BackgroundTransparency = 1}):Play()
	TweenService:Create(slide.title, FADE_OUT, {TextTransparency = 1}):Play()
	TweenService:Create(slide.body, FADE_OUT, {TextTransparency = 1}):Play()
	TweenService:Create(slideCounter, FADE_OUT, {TextTransparency = 1}):Play()
	if slide.stroke then
		TweenService:Create(slide.stroke, FADE_OUT, {Transparency = 1}):Play()
	end
	
	local fadeSkipped = waitInterruptible(0.4)
	if fadeSkipped then
		hideSlide(slide)
		return
	end
	
	hideSlide(slide)
end

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
	
	-- Hide all slide cards immediately
	for _, slide in pairs(slideCards) do
		hideSlide(slide)
	end
	
	-- Fade out counter and progress bar
	local fadeDuration = 0.5
	
	TweenService:Create(slideCounter,
		TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{TextTransparency = 1}
	):Play()
	TweenService:Create(progressBg,
		TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{BackgroundTransparency = 1}
	):Play()
	TweenService:Create(progressFill,
		TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{BackgroundTransparency = 1}
	):Play()
	
	task.wait(fadeDuration)
	print("PlaySequence: Tutorial fade-out complete!")
else
	print("PlaySequence: Tutorial complete! (15 seconds elapsed)")
end

-- ============================================
-- TRANSITION TO CYBERSECURITY LAB
-- ============================================

-- Clean up tutorial overlay (black transition screen stays)
tutorialGui:Destroy()

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

local blackFrame = transitionGui:FindFirstChild("BlackFrame")
	or transitionGui:FindFirstChildOfClass("Frame")

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
	
	-- CYBERSECURITY ROLE INTRO (2 seconds each)
	-- Show skip button for cybersecurity (blue)
	updateSkipButtonColor("Cyber")
	setSkipButtonVisible(true)
	skipTriggered = false
	
	showTitleCard("CYBERSECURITY SPECIALIST", "You have been assigned to the school's IT Security Division.", 2)
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
		print("PlaySequence: Cybersecurity skipped - proceeding to Chef")
		hackingBg:Cleanup()
		-- Keep screen black - the next section (Chef) will handle the fade out after teleport
		-- skipFadeFrame stays black, worldFadeFrame will be used for Chef section
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

-- ============================================
-- CHEF WORLD TRANSITION (Orange theme) - Second career
-- ============================================

print("PlaySequence: Starting Chef job transition...")

-- Reset skip state for Chef section (orange, can skip to Medical)
skipTriggered = false
updateSkipButtonColor("Chef")
setSkipButtonVisible(true)

-- Create fade GUI for transitions - ensure solid black first
local worldFadeGui = Instance.new("ScreenGui")
worldFadeGui.Name = "WorldTransitionFade"
worldFadeGui.IgnoreGuiInset = true
worldFadeGui.DisplayOrder = 900
worldFadeGui.Parent = playerGui

local worldFadeFrame = Instance.new("Frame")
worldFadeFrame.Size = UDim2.new(1, 0, 1, 0)
worldFadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
worldFadeFrame.BackgroundTransparency = 0
worldFadeFrame.BorderSizePixel = 0
worldFadeFrame.Parent = worldFadeGui

-- Now that worldFadeFrame is ready and solid black, hide skipFadeFrame
if skipFadeFrame and skipFadeFrame.Parent then
	skipFadeFrame.Visible = false
end

-- Small delay to ensure black screen is visible
task.wait(0.1)

-- TITLE CARD: Chef Specialist
print("PlaySequence: Showing Chef title card...")

local chefTitleGui1 = Instance.new("ScreenGui")
chefTitleGui1.Name = "ChefTitleCard1"
chefTitleGui1.IgnoreGuiInset = true
chefTitleGui1.DisplayOrder = 910
chefTitleGui1.Parent = playerGui

local chefTitleBg1 = Instance.new("Frame")
chefTitleBg1.Size = UDim2.new(1, 0, 1, 0)
chefTitleBg1.BackgroundTransparency = 1
chefTitleBg1.BorderSizePixel = 0
chefTitleBg1.Parent = chefTitleGui1

local chefTitle1 = Instance.new("TextLabel")
chefTitle1.Size = UDim2.new(1, 0, 0, 80)
chefTitle1.Position = UDim2.new(0, 0, 0.35, 0)
chefTitle1.BackgroundTransparency = 1
chefTitle1.Text = "CHEF SPECIALIST"
chefTitle1.TextColor3 = Color3.fromRGB(251, 146, 60) -- Orange accent
chefTitle1.TextSize = 48
chefTitle1.Font = Enum.Font.GothamBold
chefTitle1.TextTransparency = 1
chefTitle1.Parent = chefTitleBg1

local chefSubtitle1 = Instance.new("TextLabel")
chefSubtitle1.Size = UDim2.new(1, 0, 0, 40)
chefSubtitle1.Position = UDim2.new(0, 0, 0.45, 0)
chefSubtitle1.BackgroundTransparency = 1
chefSubtitle1.Text = "You have been assigned to the school's Culinary Division."
chefSubtitle1.TextColor3 = Color3.fromRGB(156, 163, 175)
chefSubtitle1.TextSize = 24
chefSubtitle1.Font = Enum.Font.GothamMedium
chefSubtitle1.TextTransparency = 1
chefSubtitle1.Parent = chefTitleBg1

-- Fade in title
TweenService:Create(chefTitle1, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
TweenService:Create(chefSubtitle1, TweenInfo.new(0.5), {TextTransparency = 0}):Play()

task.wait(2.5)

-- Fade out title
TweenService:Create(chefTitle1, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
TweenService:Create(chefSubtitle1, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
task.wait(0.5)

chefTitleGui1:Destroy()

-- Find ChefWorld SpawnLocation - check workspace first, then ChefWorld folder
local chefWorld1 = workspace:FindFirstChild("ChefWorld")
local chefSpawn1 = nil

-- First check workspace directly for "chefspawnlocation" (case variations)
chefSpawn1 = workspace:FindFirstChild("chefspawnlocation")
if not chefSpawn1 then
	chefSpawn1 = workspace:FindFirstChild("ChefSpawnLocation")
end
if not chefSpawn1 then
	chefSpawn1 = workspace:FindFirstChild("chefSpawnLocation")
end

-- Then check inside ChefWorld folder
if not chefSpawn1 and chefWorld1 then
	chefSpawn1 = chefWorld1:FindFirstChild("chefspawnlocation")
	if not chefSpawn1 then
		chefSpawn1 = chefWorld1:FindFirstChild("ChefSpawnLocation")
	end
	if not chefSpawn1 then
		chefSpawn1 = chefWorld1:FindFirstChild("SpawnLocation", true)
	end
	if not chefSpawn1 then
		chefSpawn1 = chefWorld1:FindFirstChild("Kitchen", true)
	end
end

if chefSpawn1 then
	print("PlaySequence: Found ChefWorld spawn at: " .. chefSpawn1:GetFullName())
else
	warn("PlaySequence: No spawn found for ChefWorld - using fallback position")
end

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

-- Ensure player character is loaded before teleporting
local playerCharacter1 = player.Character or player.CharacterAdded:Wait()
if not playerCharacter1 then
	warn("PlaySequence: Waiting for player character to load...")
	playerCharacter1 = player.CharacterAdded:Wait()
end

-- Calculate spawn position
local spawnCFrame1 = CFrame.new(0, 10, 0) -- Default fallback
if chefSpawn1 then
	if chefSpawn1:IsA("BasePart") then
		spawnCFrame1 = chefSpawn1.CFrame + Vector3.new(0, 3, 0)
	elseif chefSpawn1:IsA("Model") then
		spawnCFrame1 = chefSpawn1:GetPivot() + Vector3.new(0, 3, 0)
	end
elseif chefWorld1 then
	-- Fallback to ChefWorld origin with offset
	local chefOrigin = chefWorld1:IsA("Model") and chefWorld1:GetPivot() or CFrame.new(0, 0, 0)
	spawnCFrame1 = chefOrigin + Vector3.new(0, 10, 0)
end

-- Teleport player
local playerHRP1 = playerCharacter1:FindFirstChild("HumanoidRootPart")
if playerHRP1 then
	playerHRP1.CFrame = spawnCFrame1
	print("PlaySequence: Teleported player to ChefWorld position: " .. tostring(spawnCFrame1.Position))
else
	warn("PlaySequence: HumanoidRootPart not found!")
end

-- Set up camera to follow player
local playerHumanoid1 = playerCharacter1:FindFirstChildOfClass("Humanoid")
if playerHumanoid1 then
	camera.CameraSubject = playerHumanoid1
	camera.CameraType = Enum.CameraType.Custom
	
	-- Ensure player can move
	playerHumanoid1.WalkSpeed = 16
	playerHumanoid1.JumpPower = 50
end

-- Ensure player camera is set up correctly
player.CameraMinZoomDistance = 0.5
player.CameraMaxZoomDistance = 128

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
	print("PlaySequence: Chef skipped - transitioning to Medical")
	-- Keep skipFadeFrame black - we'll use worldFadeFrame for the next section
	-- Ensure worldFadeFrame is also solid black before continuing
	worldFadeFrame.BackgroundTransparency = 0
	-- Hide skipFadeFrame since worldFadeFrame will handle the fade out
	skipFadeFrame.Visible = false
	
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

-- Continue button
local chefContinueBtn1 = Instance.new("TextLabel")
chefContinueBtn1.Size = UDim2.new(0, 260, 0, 55)
chefContinueBtn1.Position = UDim2.new(0.5, -130, 0, 475)
chefContinueBtn1.BackgroundColor3 = Color3.fromRGB(251, 146, 60)
chefContinueBtn1.Text = "  Press [E] to Continue"
chefContinueBtn1.TextColor3 = Color3.fromRGB(25, 18, 15)
chefContinueBtn1.TextSize = 18
chefContinueBtn1.Font = Enum.Font.GothamBold
chefContinueBtn1.TextXAlignment = Enum.TextXAlignment.Left
chefContinueBtn1.Parent = chefPanel1

local contCorner1 = Instance.new("UICorner")
contCorner1.CornerRadius = UDim.new(0, 10)
contCorner1.Parent = chefContinueBtn1

print("PlaySequence: Showing ChefWorld results screen")

-- Wait for E key to continue
local chefDismissed1 = false
local chefInputConn1
chefInputConn1 = UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Return then
		if chefDismissed1 then return end
		chefDismissed1 = true
		chefInputConn1:Disconnect()
		
		-- Fade to black for seamless transition
		local fadeOut = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(chefResultsBg1, fadeOut, {BackgroundTransparency = 0, BackgroundColor3 = Color3.new(0, 0, 0)}):Play()
		
		for _, child in pairs(chefPanel1:GetDescendants()) do
			if child:IsA("TextLabel") then
				TweenService:Create(child, fadeOut, {TextTransparency = 1}):Play()
			elseif child:IsA("Frame") then
				TweenService:Create(child, fadeOut, {BackgroundTransparency = 1}):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, fadeOut, {Transparency = 1}):Play()
			end
		end
		TweenService:Create(chefPanel1, fadeOut, {BackgroundTransparency = 1}):Play()
		
		task.wait(0.8)
		chefResultsGui1:Destroy()
		print("PlaySequence: ChefWorld results dismissed")
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

-- ============================================
-- HEALTHCARE / NURSEWORLD TRANSITION (Green theme) - Third and FINAL career
-- ============================================
-- NOTE: Skip button is NOT available in Medical World (last level)

-- FINAL safety cleanup of any remaining Chef elements before Medical
cleanupChefWorld(false)
print("PlaySequence: Final Chef cleanup complete")

print("PlaySequence: Starting Healthcare job transition...")

-- Disable skip button entirely for Medical (last level)
disableSkipButton()

-- Hide skipFadeFrame if visible
if skipFadeFrame and skipFadeFrame.Parent then
	skipFadeFrame.Visible = false
end

-- Fade to black for seamless transition
TweenService:Create(worldFadeFrame,
	TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	{BackgroundTransparency = 0}
):Play()
task.wait(0.8)

-- TITLE CARD: Healthcare Specialist (Green theme)
print("PlaySequence: Showing Healthcare title card...")

local healthTitleGui2 = Instance.new("ScreenGui")
healthTitleGui2.Name = "HealthcareTitleCard2"
healthTitleGui2.IgnoreGuiInset = true
healthTitleGui2.DisplayOrder = 910
healthTitleGui2.Parent = playerGui

local healthTitleBg2 = Instance.new("Frame")
healthTitleBg2.Size = UDim2.new(1, 0, 1, 0)
healthTitleBg2.BackgroundTransparency = 1
healthTitleBg2.BorderSizePixel = 0
healthTitleBg2.Parent = healthTitleGui2

local healthTitle2 = Instance.new("TextLabel")
healthTitle2.Size = UDim2.new(1, 0, 0, 80)
healthTitle2.Position = UDim2.new(0, 0, 0.35, 0)
healthTitle2.BackgroundTransparency = 1
healthTitle2.Text = "HEALTHCARE SPECIALIST"
healthTitle2.TextColor3 = Color3.fromRGB(134, 239, 172) -- Green accent
healthTitle2.TextSize = 48
healthTitle2.Font = Enum.Font.GothamBold
healthTitle2.TextTransparency = 1
healthTitle2.Parent = healthTitleBg2

local healthSubtitle2 = Instance.new("TextLabel")
healthSubtitle2.Size = UDim2.new(1, 0, 0, 40)
healthSubtitle2.Position = UDim2.new(0, 0, 0.45, 0)
healthSubtitle2.BackgroundTransparency = 1
healthSubtitle2.Text = "You have been assigned to the school's Medical Division."
healthSubtitle2.TextColor3 = Color3.fromRGB(156, 163, 175)
healthSubtitle2.TextSize = 24
healthSubtitle2.Font = Enum.Font.GothamMedium
healthSubtitle2.TextTransparency = 1
healthSubtitle2.Parent = healthTitleBg2

-- Fade in title
TweenService:Create(healthTitle2, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
TweenService:Create(healthSubtitle2, TweenInfo.new(0.5), {TextTransparency = 0}):Play()

task.wait(2.5)

-- Fade out title
TweenService:Create(healthTitle2, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
TweenService:Create(healthSubtitle2, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
task.wait(0.5)

healthTitleGui2:Destroy()

-- Find NurseWorld SpawnLocation
local nurseWorld2 = workspace:FindFirstChild("NurseWorld")
local nurseSpawn2 = nil

if nurseWorld2 then
	-- Try direct child first
	nurseSpawn2 = nurseWorld2:FindFirstChild("SpawnLocation")
	
	-- If not found, search recursively
	if not nurseSpawn2 then
		nurseSpawn2 = nurseWorld2:FindFirstChild("SpawnLocation", true)
	end
	
	-- Try PatientBeds as fallback
	if not nurseSpawn2 then
		local beds = nurseWorld2:FindFirstChild("PatientBeds")
		if beds then
			local bed1 = beds:FindFirstChild("PatientBed_01")
			if bed1 then
				nurseSpawn2 = bed1:FindFirstChild("SpawnLocation") or bed1
			end
		end
	end
	
	if nurseSpawn2 then
		print("PlaySequence: Found NurseWorld spawn at: " .. nurseSpawn2:GetFullName())
	else
		warn("PlaySequence: No spawn found in NurseWorld - using NurseWorld origin")
	end
else
	warn("PlaySequence: NurseWorld not found in Workspace!")
end

-- Create NurseWorldActive flag so other scripts know NurseWorld is starting
local nurseActiveFlag2 = ReplicatedStorage:FindFirstChild("NurseWorldActive")
if not nurseActiveFlag2 then
	nurseActiveFlag2 = Instance.new("BoolValue")
	nurseActiveFlag2.Name = "NurseWorldActive"
	nurseActiveFlag2.Parent = ReplicatedStorage
end
nurseActiveFlag2.Value = true
print("PlaySequence: Set NurseWorldActive = true")

-- Ensure player character is loaded before teleporting
local playerCharacter2 = player.Character or player.CharacterAdded:Wait()
if not playerCharacter2 then
	warn("PlaySequence: Waiting for player character to load...")
	playerCharacter2 = player.CharacterAdded:Wait()
end

-- Calculate spawn position
local nurseSpawnCFrame2 = CFrame.new(0, 10, 0) -- Default fallback
if nurseSpawn2 then
	if nurseSpawn2:IsA("BasePart") then
		nurseSpawnCFrame2 = nurseSpawn2.CFrame + Vector3.new(0, 3, 0)
	elseif nurseSpawn2:IsA("Model") then
		nurseSpawnCFrame2 = nurseSpawn2:GetPivot() + Vector3.new(0, 3, 0)
	end
elseif nurseWorld2 then
	local nurseOrigin = nurseWorld2:IsA("Model") and nurseWorld2:GetPivot() or CFrame.new(0, 0, 0)
	nurseSpawnCFrame2 = nurseOrigin + Vector3.new(0, 10, 0)
end

-- Teleport player
local playerHRP2 = playerCharacter2:FindFirstChild("HumanoidRootPart")
if playerHRP2 then
	playerHRP2.CFrame = nurseSpawnCFrame2
	print("PlaySequence: Teleported player to NurseWorld at: " .. tostring(nurseSpawnCFrame2.Position))
else
	warn("PlaySequence: HumanoidRootPart not found!")
end

-- Set up camera to follow player
local playerHumanoid2 = playerCharacter2:FindFirstChildOfClass("Humanoid")
if playerHumanoid2 then
	camera.CameraSubject = playerHumanoid2
	camera.CameraType = Enum.CameraType.Custom
	playerHumanoid2.WalkSpeed = 16
	playerHumanoid2.JumpPower = 50
end

-- Camera settings for NurseWorld
player.CameraMinZoomDistance = 0.5
player.CameraMaxZoomDistance = 128

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
	
	-- Wait for NurseWorld to complete (with 10 minute timeout as safety)
	local nurseMaxWaitTime2 = 600 -- 10 minutes
	local nurseWaitStartTime2 = tick()
	while not nurseWorldComplete2 and (tick() - nurseWaitStartTime2) < nurseMaxWaitTime2 do
		task.wait(0.5)
	end
	
	if not nurseWorldComplete2 then
		warn("PlaySequence: NurseWorld timed out after 10 minutes - proceeding to end")
		nurseConnection2:Disconnect()
	end
else
	warn("PlaySequence: WorldCompleted BindableEvent not found - waiting 120 seconds as fallback...")
	task.wait(120)
end

print("PlaySequence: Healthcare section complete!")

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

-- Wait for E key to continue
local nurseDismissed2 = false
local nurseInputConn2
nurseInputConn2 = UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Return then
		if nurseDismissed2 then return end
		nurseDismissed2 = true
		nurseInputConn2:Disconnect()
		
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

-- ============================================
-- GAME COMPLETE
-- ============================================

-- Fade to black (game end)
TweenService:Create(worldFadeFrame,
	TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	{BackgroundTransparency = 0}
):Play()
task.wait(1.5)

-- Show "Game Complete" text
local gameCompleteLabel = Instance.new("TextLabel")
gameCompleteLabel.Size = UDim2.new(1, 0, 0, 60)
gameCompleteLabel.Position = UDim2.new(0, 0, 0.45, 0)
gameCompleteLabel.BackgroundTransparency = 1
gameCompleteLabel.Text = "CONGRATULATIONS - YOU HAVE AWAKENED"
gameCompleteLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
gameCompleteLabel.TextSize = 36
gameCompleteLabel.Font = Enum.Font.GothamBold
gameCompleteLabel.TextTransparency = 1
gameCompleteLabel.Parent = worldFadeGui

TweenService:Create(gameCompleteLabel, TweenInfo.new(1.0), {TextTransparency = 0}):Play()

print("=== PlaySequence complete - Game finished! ===")
