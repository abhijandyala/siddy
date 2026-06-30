--[[
	ChefWorldUI.luau (v14 - REMOTE-BASED ACTIVATION)
	LocalScript in StarterGui
	
	Works with ChefWorldServer v10
	- Waits for ChefWorldRemotes folder (created immediately by server)
	- Tutorial is triggered by ShowTutorial remote event
	- First-person camera lock
	- Order ticket system
	- Station cinematics (Fridge, Prep, Stove, Serve)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local GameSettings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameSettings"))

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

print("[ChefUI] v14 Script starting - waiting for remotes...")

--------------------------------------------------------------
-- SOUND EFFECTS SYSTEM
--------------------------------------------------------------
local sounds = {}

local function createSound(name, soundId, volume, looped)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. soundId
	sound.Volume = volume or 0.5
	sound.Looped = looped or false
	sound.Parent = SoundService
	sounds[name] = sound
	return sound
end

local function playSound(name, pitch)
	local sound = sounds[name]
	if sound then
		if pitch then
			sound.PlaybackSpeed = pitch
		end
		sound:Play()
	end
end

local function stopSound(name)
	local sound = sounds[name]
	if sound then
		sound:Stop()
	end
end

local function fadeOutSound(name, duration)
	local sound = sounds[name]
	if sound and sound.Playing then
		local startVolume = sound.Volume
		local fadeTime = duration or 1
		task.spawn(function()
			for i = 1, 20 do
				sound.Volume = startVolume * (1 - i/20)
				task.wait(fadeTime / 20)
			end
			sound:Stop()
			sound.Volume = startVolume
		end)
	end
end

-- Create sound effects (user-provided asset IDs)
-- Fridge sounds
createSound("fridgeOpen", 73830484780236, 0.6)   -- Door creak open
createSound("fridgeClose", 9118126474, 0.5)      -- Door close

-- Prep station sounds  
createSound("chop", 131719763951049, 0.6)        -- Chopping sound

-- Stove sounds
createSound("sizzle", 117218568841824, 0.5)      -- Sizzling
createSound("flameBurst", 79475957308532, 0.4)   -- Flame ignite

-- UI sounds
createSound("success", 72697499666151, 0.4)      -- Task complete
createSound("orderUp", 97420568353360, 0.5)      -- Order ready

-- Background music (light, upbeat kitchen music)
createSound("bgMusic", 138524894251708, 0.15, true)  -- Looped background music

--------------------------------------------------------------
-- WAIT FOR REMOTES (server creates them immediately)
--------------------------------------------------------------
local remotesFolder = ReplicatedStorage:WaitForChild("ChefWorldRemotes", 30)
if not remotesFolder then
	warn("[ChefUI] ChefWorldRemotes not found after 30 seconds - server may not be running")
	return
end

print("[ChefUI] ChefWorldRemotes found - initializing UI systems...")

--------------------------------------------------------------
-- FIRST PERSON LOCK (only runs when ChefWorld tutorial starts)
--------------------------------------------------------------
local chefWorldStarted = false

local function lockFirstPerson()
	plr.CameraMode = Enum.CameraMode.LockFirstPerson
	plr.CameraMinZoomDistance = 0.5
	plr.CameraMaxZoomDistance = 0.5
end

-- Connect for respawns, but only lock if ChefWorld has started
plr.CharacterAdded:Connect(function()
	if chefWorldStarted then
		task.wait(0.1)
		lockFirstPerson()
	end
end)

--------------------------------------------------------------
-- MOUSE CONTROL
--------------------------------------------------------------
local function showMouse()
	UIS.MouseIconEnabled = true
	UIS.MouseBehavior = Enum.MouseBehavior.Default
end

local function hideMouse()
	UIS.MouseIconEnabled = false
	UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
end

-- Don't hide mouse immediately - wait for ChefWorld to actually start

--------------------------------------------------------------
-- CHARACTER MOVEMENT LOCK (for popups and cinematics)
--------------------------------------------------------------
local isCharacterLocked = false
local savedWalkSpeed = 16
local savedJumpPower = 50

local function lockCharacter()
	if isCharacterLocked then return end
	isCharacterLocked = true
	
	local char = plr.Character
	if char then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			savedWalkSpeed = humanoid.WalkSpeed
			savedJumpPower = humanoid.JumpPower
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		end
	end
end

local function unlockCharacter()
	if not isCharacterLocked then return end
	isCharacterLocked = false
	
	local char = plr.Character
	if char then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = savedWalkSpeed
			humanoid.JumpPower = savedJumpPower
		end
	end
end

--------------------------------------------------------------
-- GET REMOTE EVENTS (already waited for folder above)
--------------------------------------------------------------
local ShowTutorial = remotesFolder:WaitForChild("ShowTutorial", 5)
local StartOrder = remotesFolder:WaitForChild("StartOrder", 5)
local NextTask = remotesFolder:WaitForChild("NextTask", 5)
local PlayCinematic = remotesFolder:WaitForChild("PlayCinematic", 5)
local CinematicDone = remotesFolder:WaitForChild("CinematicDone", 5)
local WrongStation = remotesFolder:WaitForChild("WrongStation", 5)
local TaskFailed = remotesFolder:WaitForChild("TaskFailed", 5)
local OrderDone = remotesFolder:WaitForChild("OrderDone", 5)
local ShowResults = remotesFolder:WaitForChild("ShowResults", 5)
local PlayerReady = remotesFolder:WaitForChild("PlayerReady", 5)
local TicketDismissed = remotesFolder:WaitForChild("TicketDismissed", 5)
local OrderTimedOut = remotesFolder:WaitForChild("OrderTimedOut", 5)
local RequestUIReady = remotesFolder:WaitForChild("RequestUIReady", 5)
local ChefUIReady = remotesFolder:WaitForChild("ChefUIReady", 5)
local StopChefWorld = remotesFolder:WaitForChild("StopChefWorld", 5)

print("[ChefUI] All remotes connected!")

--------------------------------------------------------------
-- CREATE SCREEN GUI
--------------------------------------------------------------
local sg = Instance.new("ScreenGui")
sg.Name = "ChefWorldUI"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = playerGui

--------------------------------------------------------------
-- COLOR PALETTE
--------------------------------------------------------------
local C = {
	bg = Color3.fromRGB(18, 22, 28),
	panel = Color3.fromRGB(28, 32, 40),
	panel2 = Color3.fromRGB(35, 40, 50),
	accent = Color3.fromRGB(251, 146, 60),
	success = Color3.fromRGB(68, 218, 118),
	warning = Color3.fromRGB(251, 191, 36),
	error = Color3.fromRGB(245, 100, 100),
	white = Color3.fromRGB(255, 255, 255),
	textSec = Color3.fromRGB(180, 190, 205),
	textMut = Color3.fromRGB(130, 140, 155),
	border = Color3.fromRGB(50, 55, 65),
	ticket = Color3.fromRGB(252, 248, 236),
	ticketText = Color3.fromRGB(0, 0, 0),
	ticketRed = Color3.fromRGB(180, 40, 40),
}

--------------------------------------------------------------
-- UI HELPERS
--------------------------------------------------------------
local function mkCorner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = obj
	return c
end

local function mkStroke(obj, col, t)
	local s = Instance.new("UIStroke")
	s.Color = col or C.border
	s.Thickness = t or 1
	s.Parent = obj
	return s
end

local function mkLabel(parent, text, size, font, color, align, z)
	local lbl = Instance.new("TextLabel")
	lbl.Text = text or ""
	lbl.TextSize = size or 14
	lbl.Font = font or Enum.Font.Gotham
	lbl.TextColor3 = color or C.white
	lbl.TextXAlignment = align or Enum.TextXAlignment.Center
	lbl.BackgroundTransparency = 1
	lbl.ZIndex = z or 10
	lbl.Parent = parent
	return lbl
end

--------------------------------------------------------------
-- GAME STATE
--------------------------------------------------------------
local gameState = {
	inGame = false,
	currentOrder = nil,
	currentStep = 1,
	score = 100,
	ticketVisible = false,
}

--------------------------------------------------------------
-- SCORE DISPLAY (top right)
--------------------------------------------------------------
local scoreFrame = Instance.new("Frame")
scoreFrame.Size = UDim2.new(0, 110, 0, 52)
scoreFrame.Position = UDim2.new(1, -126, 0, 20)
scoreFrame.BackgroundColor3 = C.panel
scoreFrame.Visible = false
scoreFrame.ZIndex = 20
scoreFrame.Parent = sg
mkCorner(scoreFrame, 8)
mkStroke(scoreFrame, C.accent, 2)

local scoreTitle = mkLabel(scoreFrame, "SCORE", 10, Enum.Font.GothamBold, C.textMut, Enum.TextXAlignment.Center, 21)
scoreTitle.Size = UDim2.new(1, 0, 0, 16)
scoreTitle.Position = UDim2.new(0, 0, 0, 6)

local scoreValue = mkLabel(scoreFrame, "100", 22, Enum.Font.GothamBlack, C.accent, Enum.TextXAlignment.Center, 21)
scoreValue.Size = UDim2.new(1, 0, 0, 28)
scoreValue.Position = UDim2.new(0, 0, 0, 20)

local function updateScoreDisplay(newScore)
	gameState.score = newScore
	if GameSettings.hardMode then
		scoreValue.Text = "●●●"
		scoreValue.TextColor3 = C.textMut
	else
		scoreValue.Text = tostring(newScore)
		if newScore >= 70 then
			scoreValue.TextColor3 = C.success
		elseif newScore >= 40 then
			scoreValue.TextColor3 = C.warning
		else
			scoreValue.TextColor3 = C.error
		end
		task.delay(0.5, function()
			scoreValue.TextColor3 = C.accent
		end)
	end
end

--------------------------------------------------------------
-- TASK PROMPT (bottom center)
--------------------------------------------------------------
local taskFrame = Instance.new("Frame")
taskFrame.Size = UDim2.new(0, 460, 0, 52)
taskFrame.Position = UDim2.new(0.5, -230, 1, -80)
taskFrame.BackgroundColor3 = C.panel
taskFrame.Visible = false
taskFrame.ZIndex = 20
taskFrame.Parent = sg
mkCorner(taskFrame, 10)
mkStroke(taskFrame, C.accent, 2)

local taskIcon = Instance.new("Frame")
taskIcon.Size = UDim2.new(0, 36, 1, 0)
taskIcon.BackgroundColor3 = C.accent
taskIcon.ZIndex = 21
taskIcon.Parent = taskFrame
mkCorner(taskIcon, 10)

local taskIconText = mkLabel(taskIcon, "→", 18, Enum.Font.GothamBlack, C.bg, Enum.TextXAlignment.Center, 22)
taskIconText.Size = UDim2.new(1, 0, 1, 0)

local taskText = mkLabel(taskFrame, "", 14, Enum.Font.GothamBold, C.white, Enum.TextXAlignment.Left, 21)
taskText.Size = UDim2.new(1, -50, 1, 0)
taskText.Position = UDim2.new(0, 44, 0, 0)

local function showTaskPrompt(icon, text)
	taskIconText.Text = icon or "→"
	taskText.Text = text or ""
	taskFrame.Visible = true
end

local function hideTaskPrompt()
	taskFrame.Visible = false
end

--------------------------------------------------------------
-- TUTORIAL OVERLAY
--------------------------------------------------------------
local tutorialOverlay = Instance.new("Frame")
tutorialOverlay.Size = UDim2.new(1, 0, 1, 0)
tutorialOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
tutorialOverlay.BackgroundTransparency = 0.5
tutorialOverlay.Visible = false
tutorialOverlay.ZIndex = 100
tutorialOverlay.Parent = sg

local tutorialPanel = Instance.new("Frame")
tutorialPanel.Size = UDim2.new(0, 620, 0, 440)
tutorialPanel.Position = UDim2.new(0.5, -310, 0.5, -220)
tutorialPanel.BackgroundColor3 = C.panel
tutorialPanel.ZIndex = 101
tutorialPanel.Parent = tutorialOverlay
mkCorner(tutorialPanel, 12)
mkStroke(tutorialPanel, C.accent, 2)

local tutTitle = mkLabel(tutorialPanel, "KITCHEN BRIEFING", 26, Enum.Font.GothamBlack, C.accent, Enum.TextXAlignment.Center, 102)
tutTitle.Size = UDim2.new(1, 0, 0, 36)
tutTitle.Position = UDim2.new(0, 0, 0, 28)

local tutBody = mkLabel(tutorialPanel, [[Three orders are coming in!

STATIONS:
  🧊 FRIDGE - Collect ingredients
  🔪 PREP - Chop and prepare  
  🔥 STOVE - Cook your dish
  🍽️ SERVE - Plate and deliver

CONTROLS:
  [E] - Interact with stations
  [T] - View/hide order ticket

Walk to each station when prompted.
Press [E] when ready to start!]], 16, Enum.Font.Gotham, C.white, Enum.TextXAlignment.Left, 102)
tutBody.Size = UDim2.new(1, -56, 0, 260)
tutBody.Position = UDim2.new(0, 28, 0, 76)
tutBody.TextYAlignment = Enum.TextYAlignment.Top
tutBody.TextWrapped = true

local tutButton = Instance.new("TextButton")
tutButton.Size = UDim2.new(0, 220, 0, 48)
tutButton.Position = UDim2.new(0.5, -110, 1, -75)
tutButton.BackgroundColor3 = C.accent
tutButton.Font = Enum.Font.GothamBold
tutButton.Text = "[E] START COOKING"
tutButton.TextSize = 15
tutButton.TextColor3 = C.bg
tutButton.ZIndex = 102
tutButton.Parent = tutorialPanel
mkCorner(tutButton, 8)

--------------------------------------------------------------
-- ORDER TICKET (Larger size for better visibility)
--------------------------------------------------------------
local ticketFrame = Instance.new("Frame")
ticketFrame.Size = UDim2.new(0, 420, 0, 540)
ticketFrame.Position = UDim2.new(0.5, -210, 0.5, -270)
ticketFrame.BackgroundColor3 = C.ticket
ticketFrame.Visible = false
ticketFrame.ZIndex = 80
ticketFrame.Parent = sg
mkCorner(ticketFrame, 10)
mkStroke(ticketFrame, C.ticketRed, 3)

local ticketHeader = Instance.new("Frame")
ticketHeader.Size = UDim2.new(1, 0, 0, 54)
ticketHeader.BackgroundColor3 = C.ticketRed
ticketHeader.ZIndex = 81
ticketHeader.Parent = ticketFrame
mkCorner(ticketHeader, 10)

local ticketHeaderSquare = Instance.new("Frame")
ticketHeaderSquare.Size = UDim2.new(1, 0, 0, 12)
ticketHeaderSquare.Position = UDim2.new(0, 0, 1, -12)
ticketHeaderSquare.BackgroundColor3 = C.ticketRed
ticketHeaderSquare.ZIndex = 81
ticketHeaderSquare.Parent = ticketHeader

local ticketTitle = mkLabel(ticketHeader, "ORDER #1", 18, Enum.Font.GothamBlack, C.white, Enum.TextXAlignment.Center, 82)
ticketTitle.Size = UDim2.new(1, 0, 1, 0)

local ticketDish = mkLabel(ticketFrame, "Spaghetti Bolognese", 24, Enum.Font.GothamBlack, C.ticketText, Enum.TextXAlignment.Center, 81)
ticketDish.Size = UDim2.new(1, 0, 0, 36)
ticketDish.Position = UDim2.new(0, 0, 0, 70)

local ticketIngTitle = mkLabel(ticketFrame, "INGREDIENTS", 14, Enum.Font.GothamBold, C.ticketRed, Enum.TextXAlignment.Left, 81)
ticketIngTitle.Size = UDim2.new(1, -40, 0, 20)
ticketIngTitle.Position = UDim2.new(0, 20, 0, 120)

local ticketIngredients = mkLabel(ticketFrame, "", 16, Enum.Font.Gotham, C.ticketText, Enum.TextXAlignment.Left, 81)
ticketIngredients.Size = UDim2.new(1, -40, 0, 100)
ticketIngredients.Position = UDim2.new(0, 20, 0, 145)
ticketIngredients.TextYAlignment = Enum.TextYAlignment.Top
ticketIngredients.TextWrapped = true

local ticketStepsTitle = mkLabel(ticketFrame, "STEPS", 14, Enum.Font.GothamBold, C.ticketRed, Enum.TextXAlignment.Left, 81)
ticketStepsTitle.Size = UDim2.new(1, -40, 0, 20)
ticketStepsTitle.Position = UDim2.new(0, 20, 0, 260)

local ticketSteps = mkLabel(ticketFrame, "", 16, Enum.Font.Gotham, C.ticketText, Enum.TextXAlignment.Left, 81)
ticketSteps.Size = UDim2.new(1, -40, 0, 160)
ticketSteps.Position = UDim2.new(0, 20, 0, 285)
ticketSteps.TextYAlignment = Enum.TextYAlignment.Top
ticketSteps.TextWrapped = true

local ticketClose = Instance.new("TextButton")
ticketClose.Size = UDim2.new(0, 140, 0, 40)
ticketClose.Position = UDim2.new(0.5, -70, 1, -55)
ticketClose.BackgroundColor3 = Color3.fromRGB(100, 80, 60)
ticketClose.Font = Enum.Font.GothamBold
ticketClose.Text = "[T] Close"
ticketClose.TextSize = 16
ticketClose.TextColor3 = C.ticket
ticketClose.ZIndex = 82
ticketClose.Parent = ticketFrame
mkCorner(ticketClose, 8)

-- Mini ticket (top left when minimized)
local ticketMini = Instance.new("TextButton")
ticketMini.Size = UDim2.new(0, 160, 0, 40)
ticketMini.Position = UDim2.new(0, 16, 0, 70)
ticketMini.BackgroundColor3 = Color3.fromRGB(40, 35, 30)
ticketMini.Font = Enum.Font.GothamBold
ticketMini.Text = "📋 [T] View Ticket"
ticketMini.TextSize = 16
ticketMini.TextColor3 = Color3.fromRGB(255, 255, 255)
ticketMini.Visible = false
ticketMini.ZIndex = 30
ticketMini.Parent = sg
mkCorner(ticketMini, 8)

-- Persistent ticket hint (bottom of screen)
local ticketHint = Instance.new("Frame")
ticketHint.Size = UDim2.new(0, 220, 0, 36)
ticketHint.Position = UDim2.new(0.5, -110, 1, -160)
ticketHint.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
ticketHint.BackgroundTransparency = 0.3
ticketHint.Visible = false
ticketHint.ZIndex = 25
ticketHint.Parent = sg
mkCorner(ticketHint, 8)

local ticketHintText = Instance.new("TextLabel")
ticketHintText.Size = UDim2.new(1, 0, 1, 0)
ticketHintText.BackgroundTransparency = 1
ticketHintText.Text = "Press [T] to open ticket"
ticketHintText.TextColor3 = Color3.fromRGB(255, 220, 150)
ticketHintText.TextSize = 16
ticketHintText.Font = Enum.Font.GothamBold
ticketHintText.ZIndex = 26
ticketHintText.Parent = ticketHint

local function showTicket(expanded)
	if expanded then
		ticketMini.Visible = false
		gameState.ticketVisible = true
		lockCharacter()
		showMouse()
		
		-- Animate in from right
		ticketFrame.Position = UDim2.new(1, 50, 0.5, -270)
		ticketFrame.Visible = true
		TweenService:Create(ticketFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, -210, 0.5, -270)
		}):Play()
	else
		gameState.ticketVisible = false
		
		-- Animate out to right
		TweenService:Create(ticketFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 50, 0.5, -270)
		}):Play()
		
		task.delay(0.26, function()
			ticketFrame.Visible = false
			ticketMini.Visible = gameState.inGame
		end)
		
		if gameState.inGame and not tutorialOverlay.Visible then
			unlockCharacter()
			hideMouse()
		end
	end
end

local function updateTicket(data)
	ticketTitle.Text = "ORDER #" .. data.orderNum .. " of " .. data.totalOrders
	ticketDish.Text = data.dishName
	
	local ingText = ""
	for i, label in ipairs(data.ingredientLabels or {}) do
		ingText = ingText .. "• " .. label .. "\n"
	end
	ticketIngredients.Text = ingText
	
	local stepsText = ""
	for i, step in ipairs(data.steps or {}) do
		local marker = i < gameState.currentStep and "✓" or (i == gameState.currentStep and "›" or "·")
		stepsText = stepsText .. marker .. " " .. step.label .. "\n"
	end
	ticketSteps.Text = stepsText
end

ticketClose.MouseButton1Click:Connect(function()
	showTicket(false)
end)

ticketMini.MouseButton1Click:Connect(function()
	showTicket(true)
end)

--------------------------------------------------------------
-- WRONG STATION FLASH
--------------------------------------------------------------
local wrongFlash = Instance.new("Frame")
wrongFlash.Size = UDim2.new(0, 300, 0, 48)
wrongFlash.Position = UDim2.new(0.5, -150, 0.5, -24)
wrongFlash.BackgroundColor3 = Color3.fromRGB(60, 15, 15)
wrongFlash.BackgroundTransparency = 1
wrongFlash.Visible = false
wrongFlash.ZIndex = 90
wrongFlash.Parent = sg
mkCorner(wrongFlash, 10)
mkStroke(wrongFlash, C.error, 2)

local wrongText = mkLabel(wrongFlash, "✗ Wrong station! -5 pts", 14, Enum.Font.GothamBold, C.error, Enum.TextXAlignment.Center, 91)
wrongText.Size = UDim2.new(1, 0, 1, 0)

local function showWrongStation()
	wrongFlash.Visible = true
	wrongFlash.BackgroundTransparency = 0.1
	TweenService:Create(wrongFlash, TweenInfo.new(1.5), {BackgroundTransparency = 1}):Play()
	task.delay(1.6, function()
		wrongFlash.Visible = false
	end)
end

--------------------------------------------------------------
-- ORDER COMPLETE BANNER
--------------------------------------------------------------
local orderBanner = Instance.new("Frame")
orderBanner.Size = UDim2.new(0, 380, 0, 64)
orderBanner.Position = UDim2.new(0.5, -190, 0.5, -32)
orderBanner.BackgroundColor3 = Color3.fromRGB(20, 50, 30)
orderBanner.BackgroundTransparency = 1
orderBanner.Visible = false
orderBanner.ZIndex = 92
orderBanner.Parent = sg
mkCorner(orderBanner, 12)
mkStroke(orderBanner, C.success, 2)

local orderBannerText = mkLabel(orderBanner, "✓ Order Complete!", 20, Enum.Font.GothamBlack, C.success, Enum.TextXAlignment.Center, 93)
orderBannerText.Size = UDim2.new(1, 0, 1, 0)

--------------------------------------------------------------
-- RESULTS SCREEN
--------------------------------------------------------------
local resultsOverlay = Instance.new("Frame")
resultsOverlay.Size = UDim2.new(1, 0, 1, 0)
resultsOverlay.BackgroundColor3 = C.bg
resultsOverlay.Visible = false
resultsOverlay.ZIndex = 110
resultsOverlay.Parent = sg

local resultsPanel = Instance.new("Frame")
resultsPanel.Size = UDim2.new(0, 480, 0, 420)
resultsPanel.Position = UDim2.new(0.5, -240, 0.5, -210)
resultsPanel.BackgroundColor3 = C.panel
resultsPanel.ZIndex = 111
resultsPanel.Parent = resultsOverlay
mkCorner(resultsPanel, 12)
mkStroke(resultsPanel, C.accent, 2)

local resultsTitle = mkLabel(resultsPanel, "SHIFT COMPLETE", 10, Enum.Font.GothamBold, C.accent, Enum.TextXAlignment.Center, 112)
resultsTitle.Size = UDim2.new(1, 0, 0, 16)
resultsTitle.Position = UDim2.new(0, 0, 0, 24)

local resultsHeading = mkLabel(resultsPanel, "Your Results", 24, Enum.Font.GothamBlack, C.white, Enum.TextXAlignment.Center, 112)
resultsHeading.Size = UDim2.new(1, 0, 0, 32)
resultsHeading.Position = UDim2.new(0, 0, 0, 44)

local resultsScoreCircle = Instance.new("Frame")
resultsScoreCircle.Size = UDim2.new(0, 100, 0, 100)
resultsScoreCircle.Position = UDim2.new(0.5, -50, 0, 96)
resultsScoreCircle.BackgroundColor3 = C.bg
resultsScoreCircle.ZIndex = 112
resultsScoreCircle.Parent = resultsPanel
mkCorner(resultsScoreCircle, 50)
mkStroke(resultsScoreCircle, C.accent, 3)

local resultsScoreNum = mkLabel(resultsScoreCircle, "85", 28, Enum.Font.GothamBlack, C.accent, Enum.TextXAlignment.Center, 113)
resultsScoreNum.Size = UDim2.new(1, 0, 1, 0)

local resultsRank = mkLabel(resultsPanel, "Head Chef", 18, Enum.Font.GothamBold, C.warning, Enum.TextXAlignment.Center, 112)
resultsRank.Size = UDim2.new(1, 0, 0, 24)
resultsRank.Position = UDim2.new(0, 0, 0, 210)

local resultsMessage = mkLabel(resultsPanel, "", 13, Enum.Font.Gotham, C.textSec, Enum.TextXAlignment.Center, 112)
resultsMessage.Size = UDim2.new(1, -48, 0, 40)
resultsMessage.Position = UDim2.new(0, 24, 0, 240)
resultsMessage.TextWrapped = true

local resultsStats = mkLabel(resultsPanel, "", 14, Enum.Font.GothamBold, C.white, Enum.TextXAlignment.Center, 112)
resultsStats.Size = UDim2.new(1, -48, 0, 80)
resultsStats.Position = UDim2.new(0, 24, 0, 290)
resultsStats.TextWrapped = true

local resultsContinue = Instance.new("TextButton")
resultsContinue.Size = UDim2.new(0, 180, 0, 44)
resultsContinue.Position = UDim2.new(0.5, -90, 1, -70)
resultsContinue.BackgroundColor3 = C.accent
resultsContinue.Font = Enum.Font.GothamBold
resultsContinue.Text = "[E] Continue"
resultsContinue.TextSize = 15
resultsContinue.TextColor3 = C.bg
resultsContinue.ZIndex = 112
resultsContinue.Parent = resultsPanel
mkCorner(resultsContinue, 8)

--------------------------------------------------------------
-- CINEMATIC OVERLAY (for station interactions)
--------------------------------------------------------------
local cinematicOverlay = Instance.new("Frame")
cinematicOverlay.Size = UDim2.new(1, 0, 1, 0)
cinematicOverlay.BackgroundTransparency = 1
cinematicOverlay.Visible = false
cinematicOverlay.ZIndex = 70
cinematicOverlay.Parent = sg

-- Letterbox bars
local letterboxTop = Instance.new("Frame")
letterboxTop.Size = UDim2.new(1, 0, 0, 0)
letterboxTop.BackgroundColor3 = Color3.new(0, 0, 0)
letterboxTop.ZIndex = 71
letterboxTop.Parent = cinematicOverlay

local letterboxBottom = Instance.new("Frame")
letterboxBottom.Size = UDim2.new(1, 0, 0, 0)
letterboxBottom.Position = UDim2.new(0, 0, 1, 0)
letterboxBottom.AnchorPoint = Vector2.new(0, 1)
letterboxBottom.BackgroundColor3 = Color3.new(0, 0, 0)
letterboxBottom.ZIndex = 71
letterboxBottom.Parent = cinematicOverlay

-- Subtitle
local subtitleFrame = Instance.new("Frame")
subtitleFrame.Size = UDim2.new(0, 500, 0, 36)
subtitleFrame.Position = UDim2.new(0.5, -250, 1, -100)
subtitleFrame.BackgroundColor3 = Color3.new(0, 0, 0)
subtitleFrame.BackgroundTransparency = 0.3
subtitleFrame.Visible = false
subtitleFrame.ZIndex = 72
subtitleFrame.Parent = cinematicOverlay
mkCorner(subtitleFrame, 6)

local subtitleText = mkLabel(subtitleFrame, "", 14, Enum.Font.GothamMedium, C.white, Enum.TextXAlignment.Center, 73)
subtitleText.Size = UDim2.new(1, 0, 1, 0)

-- Action prompt
local actionFrame = Instance.new("Frame")
actionFrame.Size = UDim2.new(0, 240, 0, 48)
actionFrame.Position = UDim2.new(0.5, -120, 1, -160)
actionFrame.BackgroundColor3 = C.panel
actionFrame.Visible = false
actionFrame.ZIndex = 72
actionFrame.Parent = cinematicOverlay
mkCorner(actionFrame, 10)
mkStroke(actionFrame, C.accent, 2)

local actionKey = Instance.new("Frame")
actionKey.Size = UDim2.new(0, 40, 1, 0)
actionKey.BackgroundColor3 = C.accent
actionKey.ZIndex = 73
actionKey.Parent = actionFrame
mkCorner(actionKey, 10)

local actionKeyText = mkLabel(actionKey, "E", 18, Enum.Font.GothamBlack, C.bg, Enum.TextXAlignment.Center, 74)
actionKeyText.Size = UDim2.new(1, 0, 1, 0)

local actionText = mkLabel(actionFrame, "", 13, Enum.Font.GothamBold, C.white, Enum.TextXAlignment.Left, 73)
actionText.Size = UDim2.new(1, -50, 1, 0)
actionText.Position = UDim2.new(0, 46, 0, 0)

-- Timer display (top center during cinematics)
local timerFrame = Instance.new("Frame")
timerFrame.Size = UDim2.new(0, 120, 0, 50)
timerFrame.Position = UDim2.new(0.5, -60, 0, 80)
timerFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
timerFrame.BackgroundTransparency = 0.3
timerFrame.Visible = false
timerFrame.ZIndex = 75
timerFrame.Parent = sg
mkCorner(timerFrame, 10)

local timerText = mkLabel(timerFrame, "55", 28, Enum.Font.GothamBlack, C.white, Enum.TextXAlignment.Center, 76)
timerText.Size = UDim2.new(1, 0, 1, 0)

-- Red warning flash overlay
local redFlash = Instance.new("Frame")
redFlash.Size = UDim2.new(1, 0, 1, 0)
redFlash.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
redFlash.BackgroundTransparency = 1
redFlash.Visible = false
redFlash.ZIndex = 90
redFlash.Parent = sg

-- Failure overlay
local failureOverlay = Instance.new("Frame")
failureOverlay.Size = UDim2.new(1, 0, 1, 0)
failureOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
failureOverlay.BackgroundTransparency = 1
failureOverlay.Visible = false
failureOverlay.ZIndex = 200
failureOverlay.Parent = sg

local failureTitle = mkLabel(failureOverlay, "ORDER FAILED", 36, Enum.Font.GothamBlack, C.error, Enum.TextXAlignment.Center, 201)
failureTitle.Size = UDim2.new(1, 0, 0, 50)
failureTitle.Position = UDim2.new(0, 0, 0.4, 0)
failureTitle.TextTransparency = 1

local failureMessage = mkLabel(failureOverlay, "You were unable to complete this ticket in time.", 18, Enum.Font.GothamMedium, C.white, Enum.TextXAlignment.Center, 201)
failureMessage.Size = UDim2.new(1, 0, 0, 30)
failureMessage.Position = UDim2.new(0, 0, 0.5, 0)
failureMessage.TextTransparency = 1

local failureScore = mkLabel(failureOverlay, "0 / 100", 48, Enum.Font.GothamBlack, C.error, Enum.TextXAlignment.Center, 201)
failureScore.Size = UDim2.new(1, 0, 0, 60)
failureScore.Position = UDim2.new(0, 0, 0.55, 20)
failureScore.TextTransparency = 1

local function showSubtitle(text)
	subtitleText.Text = text
	subtitleFrame.Visible = true
end

local function hideSubtitle()
	subtitleFrame.Visible = false
end

local function showAction(text)
	actionText.Text = text
	actionFrame.Visible = true
end

local function hideAction()
	actionFrame.Visible = false
end

-- Timer system for cinematics
local cinematicTimerThread = nil
local CINEMATIC_TIME_LIMIT = 55
local orderTimerActive = false
local cinematicEnding = false

-- Forward declarations
local exitCinematic

local function stopCinematicTimer()
	if cinematicTimerThread then
		pcall(function()
			task.cancel(cinematicTimerThread)
		end)
		cinematicTimerThread = nil
	end
	orderTimerActive = false
	timerFrame.Visible = false
	redFlash.Visible = false
	redFlash.BackgroundTransparency = 1
end

local function showFailureScreen()
	-- Prevent race condition if cinematic just finished
	if cinematicEnding then return end
	cinematicEnding = true
	
	cinematicTimedOut = true
	awaitingE = false
	stopCinematicTimer()
	
	hideSubtitle()
	hideAction()
	
	-- Fade to black
	failureOverlay.Visible = true
	failureOverlay.BackgroundTransparency = 1
	failureTitle.TextTransparency = 1
	failureMessage.TextTransparency = 1
	failureScore.TextTransparency = 1
	
	TweenService:Create(failureOverlay, TweenInfo.new(1), {BackgroundTransparency = 0}):Play()
	task.wait(0.5)
	TweenService:Create(failureTitle, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	task.wait(0.3)
	TweenService:Create(failureMessage, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	task.wait(0.3)
	TweenService:Create(failureScore, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	task.wait(3)
	
	-- Fade out and notify server
	TweenService:Create(failureOverlay, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
	TweenService:Create(failureTitle, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
	TweenService:Create(failureMessage, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
	TweenService:Create(failureScore, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
	task.wait(0.6)
	failureOverlay.Visible = false
	
	-- Reset and notify server to move to next order
	cinematicTimedOut = false
	cinematicEnding = false
	exitCinematic()
	if OrderTimedOut then
		OrderTimedOut:FireServer()
	else
		CinematicDone:FireServer()
	end
end

local function flashRed(intensity, duration)
	redFlash.Visible = true
	redFlash.BackgroundTransparency = 1 - intensity
	TweenService:Create(redFlash, TweenInfo.new(duration), {BackgroundTransparency = 1}):Play()
end

local function startCinematicTimer()
	-- Don't restart if timer is already running (persists across stations)
	if orderTimerActive then return end
	
	orderTimerActive = true
	cinematicTimedOut = false
	timerFrame.Visible = true
	timerText.TextColor3 = C.white
	
	cinematicTimerThread = task.spawn(function()
		local timeRemaining = CINEMATIC_TIME_LIMIT
		
		while timeRemaining > 0 and not cinematicTimedOut do
			timerText.Text = tostring(timeRemaining)
			
			-- Warning phase: slow red flashes when under 10 seconds
			if timeRemaining <= 10 and timeRemaining > 3 then
				timerText.TextColor3 = C.error
				if timeRemaining % 2 == 0 then
					flashRed(0.3, 0.8)
				end
			end
			
			-- Final countdown: flash at 3, 2, 1
			if timeRemaining == 3 or timeRemaining == 2 or timeRemaining == 1 then
				timerText.TextColor3 = C.error
				flashRed(0.5, 0.4)
			end
			
			task.wait(1)
			timeRemaining = timeRemaining - 1
		end
		
		-- Time's up!
		if not cinematicTimedOut then
			showFailureScreen()
		end
	end)
end

local function enterCinematic()
	-- Start every cinematic with a clean ending flag. Otherwise a stale `true`
	-- left over from a previous cinematic/order (e.g. the serve cinematic of the
	-- prior order, which NextTask never resets before the next order) makes the
	-- end guard bail early -- skipping exitCinematic() + CinematicDone() and
	-- stranding the player with the cinematic camera while the server waits
	-- forever. This runs once at the start, before any timeout for this cinematic
	-- could fire, so it never clobbers the timeout-failure path.
	cinematicEnding = false

	cinematicOverlay.Visible = true
	TweenService:Create(letterboxTop, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0.07, 0)}):Play()
	TweenService:Create(letterboxBottom, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0.07, 0)}):Play()
	
	-- Lock character movement and enable mouse cursor
	lockCharacter()
	showMouse()
	
	-- Start order timer (persists across all stations)
	startCinematicTimer()
end

exitCinematic = function()
	-- Timer keeps running across stations (stopped when order completes)
	
	TweenService:Create(letterboxTop, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 0)}):Play()
	TweenService:Create(letterboxBottom, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 0)}):Play()
	hideSubtitle()
	hideAction()
	task.delay(0.35, function()
		cinematicOverlay.Visible = false
	end)
	
	-- Only re-lock first-person if the game is still actively in progress.
	-- When resultsOverlay is visible, ChefWorld is over and PlaySequence owns
	-- the camera — do NOT lock it back to first-person here.
	if not resultsOverlay.Visible then
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Custom
		plr.CameraMode = Enum.CameraMode.LockFirstPerson
		plr.CameraMinZoomDistance = 0.5
		plr.CameraMaxZoomDistance = 0.5
		unlockCharacter()
		hideMouse()
	end
end

--------------------------------------------------------------
-- 3D PART HELPERS
--------------------------------------------------------------

-- Cache references to real workspace parts (with WaitForChild for reliability)
local cachedFridgeDoor = nil
local cachedCuttingBoard = nil
local cachedStations = {}

local function cacheWorkspaceParts()
	local cw = workspace:WaitForChild("ChefWorld", 15)
	if cw then
		local kit = cw:WaitForChild("Kitchen", 10)
		if kit then
			local fridge = kit:WaitForChild("Fridge", 5)
			if fridge then
				local door = fridge:WaitForChild("FridgeDoor", 5)
				if door then
					cachedFridgeDoor = door
				end
				if fridge:IsA("BasePart") then
					cachedStations["Fridge"] = fridge
				else
					cachedStations["Fridge"] = fridge:FindFirstChildWhichIsA("BasePart")
				end
			end
			
			local board = kit:WaitForChild("Cutting Board", 5)
			if board then
				if board:IsA("BasePart") then
					cachedCuttingBoard = board
				elseif board:IsA("Model") then
					cachedCuttingBoard = board:FindFirstChildWhichIsA("BasePart") or board.PrimaryPart
				end
			end
			
			local stations = kit:FindFirstChild("Stations")
			if stations then
				for _, name in ipairs({"Fridge", "PrepStation", "Stove", "ServingCounter"}) do
					local st = stations:FindFirstChild(name)
					if st then
						if st:IsA("BasePart") then
							cachedStations[name] = st
						else
							cachedStations[name] = st:FindFirstChildWhichIsA("BasePart") or st.PrimaryPart
						end
					end
				end
			end
		end
	end
end
task.spawn(cacheWorkspaceParts)

-- Fallback listener for streamed parts
workspace.DescendantAdded:Connect(function(desc)
	if not cachedFridgeDoor and desc.Name == "FridgeDoor" then
		cachedFridgeDoor = desc
	elseif not cachedCuttingBoard and desc.Name == "Cutting Board" and desc:IsA("BasePart") then
		cachedCuttingBoard = desc
	end
end)

-- Create subtle floating labels above each station
local stationLabelsCreated = false
local function createStationLabels()
	if stationLabelsCreated then return end
	
	print("[ChefUI] Creating station labels...")
	
	local stationInfo = {
		{name = "Fridge", label = "1. FRIDGE", icon = "🧊"},
		{name = "PrepStation", label = "2. PREP", icon = "🔪"},
		{name = "Stove", label = "3. STOVE", icon = "🔥"},
		{name = "ServingCounter", label = "4. SERVE", icon = "🍽️"}
	}
	
	-- Re-cache stations now that we're actually in ChefWorld
	cacheWorkspaceParts()
	task.wait(0.5)
	
	-- Wait for stations to be cached
	local maxWait = 10
	local waited = 0
	while waited < maxWait do
		local allCached = true
		for _, info in ipairs(stationInfo) do
			if not cachedStations[info.name] then
				allCached = false
				break
			end
		end
		if allCached then break end
		task.wait(0.5)
		waited = waited + 0.5
	end
	
	local labelsCreatedCount = 0
	for _, info in ipairs(stationInfo) do
		local station = cachedStations[info.name]
		if not station then 
			warn("[ChefUI] Station not found for label: " .. info.name)
			continue 
		end
		
		-- Remove existing label if any
		local existingLabel = station:FindFirstChild(info.name .. "Label")
		if existingLabel then
			existingLabel:Destroy()
		end
		
		local billboard = Instance.new("BillboardGui")
		billboard.Name = info.name .. "Label"
		billboard.Size = UDim2.new(0, 120, 0, 40)
		billboard.StudsOffset = Vector3.new(0, 6, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 50
		billboard.Adornee = station
		billboard.Parent = station
		
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		frame.BackgroundTransparency = 0.4
		frame.BorderSizePixel = 0
		frame.Parent = billboard
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 200, 100)
		stroke.Thickness = 1.5
		stroke.Transparency = 0.5
		stroke.Parent = frame
		
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = info.label
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 16
		label.Font = Enum.Font.GothamBold
		label.TextStrokeTransparency = 0.7
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.Parent = frame
		
		labelsCreatedCount = labelsCreatedCount + 1
		print("[ChefUI] Created label for: " .. info.name)
	end
	
	stationLabelsCreated = true
	print("[ChefUI] Created " .. labelsCreatedCount .. " station labels")
end
-- Don't create labels at startup - they'll be created when ChefWorld is activated

local function getStation(name)
	if cachedStations[name] then
		return cachedStations[name]
	end
	-- Fallback: try to find in workspace if cache miss
	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc.Name == name and desc:IsA("BasePart") then
			cachedStations[name] = desc
			return desc
		end
	end
	return nil
end

local function makePart(cf, size, color, shape, transparency)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.CFrame = cf
	p.Size = size or Vector3.new(1, 1, 1)
	p.Color = color or Color3.fromRGB(200, 200, 200)
	p.Shape = shape or Enum.PartType.Block
	p.Transparency = transparency or 0
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = workspace
	return p
end

local function fadeOutPart(p, duration)
	TweenService:Create(p, TweenInfo.new(duration or 0.3), {Transparency = 1}):Play()
	task.delay((duration or 0.3) + 0.1, function()
		p:Destroy()
	end)
end

--------------------------------------------------------------
-- CINEMATIC HANDLERS
--------------------------------------------------------------
local awaitingE = false

local cinematicTimedOut = false

local function awaitE()
	awaitingE = true
	local hit = false
	local conn
	conn = UIS.InputBegan:Connect(function(inp, gp)
		if inp.KeyCode == Enum.KeyCode.E then
			hit = true
		end
	end)
	
	-- Use pcall-style cleanup to ensure connection is always disconnected
	local function cleanup()
		if conn and conn.Connected then
			conn:Disconnect()
		end
		awaitingE = false
	end
	
	while not hit and awaitingE and not cinematicTimedOut do
		task.wait(0.05)
	end
	
	cleanup()
	return hit and not cinematicTimedOut
end

--------------------------------------------------------------
-- FRIDGE CINEMATIC
--------------------------------------------------------------
local function playFridgeCinematic(data)
	enterCinematic()
	
	local station = getStation("Fridge")
	local pos = station and station.Position or Vector3.new(0, 3, 0)
	local parts = {}
	
	-- Set camera to fixed viewing position for fridge
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local camPos = pos + Vector3.new(2, 6, 4)
	local camTarget = pos + Vector3.new(0, 4, 0)
	TweenService:Create(cam, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		CFrame = CFrame.new(camPos, camTarget)
	}):Play()
	task.wait(0.4)
	
	-- Use cached FridgeDoor reference, with brief wait if not ready
	local fridgeDoor = cachedFridgeDoor
	if not fridgeDoor then
		task.wait(0.5)
		fridgeDoor = cachedFridgeDoor
	end
	
	-- Store original pivot for animation (works for both Model and Part)
	local originalPivot = fridgeDoor and fridgeDoor:GetPivot() or CFrame.new(pos)
	
	-- Get door bounding box size
	local doorSize = Vector3.new(2, 4, 0.2)
	if fridgeDoor then
		if fridgeDoor:IsA("Model") then
			local cf, size = fridgeDoor:GetBoundingBox()
			doorSize = size
		elseif fridgeDoor:IsA("BasePart") then
			doorSize = fridgeDoor.Size
		end
	end
	
	showSubtitle("Opening the fridge...")
	task.wait(0.3)
	
	-- Play fridge open sound
	playSound("fridgeOpen")
	
	-- Animate the real door open (swing on left edge hinge)
	if fridgeDoor and fridgeDoor.Parent then
		local hingeOffset = doorSize.X / 2
		local hingePos = originalPivot * CFrame.new(-hingeOffset, 0, 0)
		
		for i = 1, 20 do
			if not fridgeDoor or not fridgeDoor.Parent then break end
			local angle = (i / 20) * math.rad(80)
			local newCF = CFrame.new(hingePos.Position) * CFrame.Angles(0, -angle, 0) * CFrame.new(hingeOffset, 0, 0)
			fridgeDoor:PivotTo(newCF)
			task.wait(0.02)
		end
	end
	
	-- Create ingredient spheres in a horizontal row at the specified position
	local ingredients = {}
	local ingredientBasePos = Vector3.new(-4.2, 8.5, -22.931)
	local colors = data.ingredientColors or {{r=200,g=100,b=100}, {r=100,g=200,b=100}, {r=100,g=100,b=200}}
	for i = 1, 3 do
		local col = colors[i] or {r=150, g=150, b=150}
		local ing = makePart(
			CFrame.new(ingredientBasePos + Vector3.new((i-2) * 0.6, 0, 0)),
			Vector3.new(0.4, 0.35, 0.4),
			Color3.fromRGB(col.r, col.g, col.b),
			Enum.PartType.Ball
		)
		table.insert(ingredients, ing)
		table.insert(parts, ing)
	end
	
	showSubtitle("Collect the ingredients!")
	showAction("Grab ingredients")
	
	-- Wait for E and animate grabbing each ingredient
	for i, ing in ipairs(ingredients) do
		awaitE()
		if cinematicTimedOut then return end
		
		TweenService:Create(ing, TweenInfo.new(0.25), {
			CFrame = ing.CFrame + Vector3.new(0, -0.5, 0.5),
			Transparency = 1
		}):Play()
		showSubtitle("Got " .. (data.ingredientLabels and data.ingredientLabels[i] or "ingredient " .. i) .. "!")
		task.wait(0.3)
	end
	
	hideAction()
	showSubtitle("All ingredients collected!")
	playSound("success")
	
	-- Play fridge close sound
	playSound("fridgeClose")
	
	-- Close the real door back
	if fridgeDoor and fridgeDoor.Parent then
		local hingeOffset = doorSize.X / 2
		local hingePos = originalPivot * CFrame.new(-hingeOffset, 0, 0)
		
		for i = 20, 0, -2 do
			if not fridgeDoor or not fridgeDoor.Parent then break end
			local angle = (i / 20) * math.rad(80)
			local newCF = CFrame.new(hingePos.Position) * CFrame.Angles(0, -angle, 0) * CFrame.new(hingeOffset, 0, 0)
			fridgeDoor:PivotTo(newCF)
			task.wait(0.015)
		end
		
		-- Restore to exact original position
		if fridgeDoor and fridgeDoor.Parent then
			fridgeDoor:PivotTo(originalPivot)
		end
	end
	
	task.wait(0.4)
	
	-- Cleanup spawned parts only (ingredients)
	for _, p in ipairs(parts) do
		fadeOutPart(p, 0.2)
	end
	
	-- Prevent race condition with timer failure
	if cinematicEnding then return end
	cinematicEnding = true
	exitCinematic()
	CinematicDone:FireServer()
end

--------------------------------------------------------------
-- PREP CINEMATIC
--------------------------------------------------------------
local function playPrepCinematic(data)
	enterCinematic()
	
	-- Use cached cutting board reference, with brief wait if not ready
	local cuttingBoard = cachedCuttingBoard
	if not cuttingBoard then
		task.wait(0.5)
		cuttingBoard = cachedCuttingBoard
	end
	
	-- Use the real cutting board position, or fallback to PrepStation
	local pos
	if cuttingBoard then
		pos = cuttingBoard.Position + Vector3.new(0, 0.1, 0)
	else
		local station = getStation("PrepStation")
		pos = station and station.Position or Vector3.new(0, 3, 0)
	end
	
	local parts = {}
	
	-- Zoom camera in on the cutting board
	local camera = workspace.CurrentCamera
	local originalCamType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	local targetCamPos = pos + Vector3.new(0, 1.5, 2.5)
	local targetCamCF = CFrame.new(targetCamPos, pos + Vector3.new(0, 0.3, 0))
	TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = targetCamCF
	}):Play()
	task.wait(0.4)
	
	-- Vegetable to chop (larger for visibility)
	local vegColor = Color3.fromRGB(240, 200, 150)
	if data.ingredientColors and data.ingredientColors[3] then
		local c = data.ingredientColors[3]
		vegColor = Color3.fromRGB(c.r, c.g, c.b)
	end
	local veg = makePart(CFrame.new(pos + Vector3.new(0, 0.25, 0)), Vector3.new(0.7, 0.4, 0.7), vegColor, Enum.PartType.Ball)
	table.insert(parts, veg)
	
	-- Knife (larger and positioned above the cutting board)
	local knifeBase = CFrame.new(pos + Vector3.new(0, 0.6, 0))
	local knifeUp = CFrame.new(pos + Vector3.new(0, 1.3, 0.05)) * CFrame.Angles(math.rad(-25), 0, 0)
	local blade = makePart(knifeBase, Vector3.new(1.0, 0.06, 0.25), Color3.fromRGB(210, 215, 220))
	blade.Material = Enum.Material.Metal
	table.insert(parts, blade)
	
	local knifeHandle = makePart(knifeBase * CFrame.new(0.6, 0, 0), Vector3.new(0.3, 0.07, 0.1), Color3.fromRGB(50, 35, 25))
	knifeHandle.Material = Enum.Material.Wood
	table.insert(parts, knifeHandle)
	
	-- Bowl for chopped pieces (larger)
	local bowl = makePart(CFrame.new(pos + Vector3.new(1.0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.2, 0.8, 0.8), Color3.fromRGB(60, 55, 50), Enum.PartType.Cylinder)
	table.insert(parts, bowl)
	
	showSubtitle("Time to chop the " .. (data.ingredientLabels and data.ingredientLabels[3] or "ingredients") .. "!")
	task.wait(0.4)
	
	-- Move knife to raised position
	blade.CFrame = knifeUp
	knifeHandle.CFrame = knifeUp * CFrame.new(0.6, 0, 0)
	
	local chopPieces = {}
	
	for i = 1, 5 do
		showAction("Chop! (" .. i .. "/5)")
		awaitE()
		if cinematicTimedOut then return end
		
		-- Play chop sound
		playSound("chop")
		
		-- Knife down animation
		TweenService:Create(blade, TweenInfo.new(0.08), {CFrame = knifeBase}):Play()
		TweenService:Create(knifeHandle, TweenInfo.new(0.08), {CFrame = knifeBase * CFrame.new(0.6, 0, 0)}):Play()
		task.wait(0.1)
		
		-- Create chopped piece flying to bowl (larger pieces)
		local piece = makePart(
			CFrame.new(pos + Vector3.new((math.random() - 0.5) * 0.4, 0.25, (math.random() - 0.5) * 0.3)),
			Vector3.new(0.15, 0.12, 0.15),
			vegColor,
			Enum.PartType.Ball
		)
		table.insert(chopPieces, piece)
		table.insert(parts, piece)
		
		TweenService:Create(piece, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
			CFrame = CFrame.new(pos + Vector3.new(1.0 + (math.random() - 0.5) * 0.2, 0.2, (math.random() - 0.5) * 0.2))
		}):Play()
		
		-- Shrink vegetable
		local newSize = 0.7 - (i * 0.12)
		TweenService:Create(veg, TweenInfo.new(0.1), {Size = Vector3.new(newSize, newSize * 0.6, newSize)}):Play()
		
		showSubtitle("Chop " .. i .. "!")
		
		-- Knife back up
		TweenService:Create(blade, TweenInfo.new(0.12, Enum.EasingStyle.Back), {CFrame = knifeUp}):Play()
		TweenService:Create(knifeHandle, TweenInfo.new(0.12, Enum.EasingStyle.Back), {CFrame = knifeUp * CFrame.new(0.6, 0, 0)}):Play()
		
		task.wait(0.15)
	end
	
	hideAction()
	showSubtitle("Prep complete! Perfectly chopped.")
	playSound("success")
	
	-- Final vegetable disappears
	fadeOutPart(veg, 0.2)
	task.wait(0.6)
	
	-- Cleanup
	for _, p in ipairs(parts) do
		if p ~= veg then
			fadeOutPart(p, 0.25)
		end
	end
	
	-- Prevent race condition with timer failure
	if cinematicEnding then return end
	cinematicEnding = true
	exitCinematic()
	CinematicDone:FireServer()
end

--------------------------------------------------------------
-- STOVE CINEMATIC
--------------------------------------------------------------
local function playStoveCinematic(data)
	enterCinematic()
	
	local station = getStation("Stove")
	local pos = station and station.Position or Vector3.new(0, 3, 0)
	local parts = {}
	
	-- Set camera to fixed viewing position for stove
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local camPos = pos + Vector3.new(1.5, 2, 2.5)
	local camTarget = pos + Vector3.new(0, 0.3, 0)
	TweenService:Create(cam, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		CFrame = CFrame.new(camPos, camTarget)
	}):Play()
	task.wait(0.4)
	
	-- Pan (cylinder for realistic shape)
	local pan = makePart(CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.12, 1.1, 1.1), Color3.fromRGB(55, 50, 48), Enum.PartType.Cylinder)
	pan.Material = Enum.Material.Metal
	table.insert(parts, pan)
	
	-- Pan inner (darker center)
	local panInner = makePart(CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.08, 0.95, 0.95), Color3.fromRGB(30, 28, 26), Enum.PartType.Cylinder)
	panInner.Material = Enum.Material.Metal
	table.insert(parts, panInner)
	
	-- Pan handle (longer and more realistic)
	local panHandle = makePart(CFrame.new(pos + Vector3.new(0.75, 0.1, 0)), Vector3.new(0.7, 0.05, 0.1), Color3.fromRGB(40, 35, 32))
	panHandle.Material = Enum.Material.Metal
	table.insert(parts, panHandle)
	
	-- Handle grip
	local handleGrip = makePart(CFrame.new(pos + Vector3.new(1.05, 0.1, 0)), Vector3.new(0.15, 0.07, 0.12), Color3.fromRGB(25, 22, 20))
	handleGrip.Material = Enum.Material.Plastic
	table.insert(parts, handleGrip)
	
	-- Burner (red glow)
	local burner = makePart(CFrame.new(pos + Vector3.new(0, -0.02, 0)) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.05, 0.7, 0.7), Color3.fromRGB(180, 60, 20), Enum.PartType.Cylinder)
	local burnerLight = Instance.new("PointLight")
	burnerLight.Color = Color3.fromRGB(255, 120, 40)
	burnerLight.Brightness = 1.5
	burnerLight.Range = 6
	burnerLight.Parent = burner
	table.insert(parts, burner)
	
	-- Fire effect
	local fireBase = makePart(CFrame.new(pos + Vector3.new(0, 0, 0)), Vector3.new(0.4, 0.05, 0.4), Color3.fromRGB(255, 100, 20), Enum.PartType.Block, 1)
	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(255, 120, 30)
	fire.SecondaryColor = Color3.fromRGB(200, 50, 10)
	fire.Heat = 4
	fire.Size = 1
	fire.Parent = fireBase
	table.insert(parts, fireBase)
	
	-- Food in pan
	local foodColor = Color3.fromRGB(180, 100, 60)
	if data.ingredientColors and data.ingredientColors[1] then
		local c = data.ingredientColors[1]
		foodColor = Color3.fromRGB(c.r, c.g, c.b)
	end
	local food = makePart(CFrame.new(pos + Vector3.new(0, 0.18, 0)), Vector3.new(0.6, 0.06, 0.6), foodColor)
	table.insert(parts, food)
	
	-- Steam
	local steamBase = makePart(CFrame.new(pos + Vector3.new(0, 0.5, 0)), Vector3.new(0.2, 0.1, 0.2), Color3.new(1, 1, 1), Enum.PartType.Block, 1)
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxassetid://133619570"
	steam.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1)})
	steam.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.4)})
	steam.Speed = NumberRange.new(1, 2)
	steam.Lifetime = NumberRange.new(1, 2)
	steam.Rate = 10
	steam.Parent = steamBase
	table.insert(parts, steamBase)
	
	local cookTime = data.cookTime or 8
	showSubtitle("Cooking " .. (data.dishName or "dish") .. "...")
	
	-- Play flame burst and start sizzle loop
	playSound("flameBurst")
	task.delay(0.3, function()
		playSound("sizzle")
	end)
	
	-- Wobble animation
	local panBase = pan.CFrame
	local handleBase = panHandle.CFrame
	local wobbling = true
	
	task.spawn(function()
		local t = 0
		while wobbling do
			t = t + 0.08
			local wobble = math.sin(t) * 0.03
			pan.CFrame = panBase * CFrame.Angles(0, 0, wobble)
			panHandle.CFrame = handleBase * CFrame.Angles(0, 0, wobble)
			task.wait(0.05)
		end
	end)
	
	-- Stir QTEs with counter
	for i = 1, 2 do
		task.wait(cookTime / 3)
		if cinematicTimedOut then wobbling = false; stopSound("sizzle"); return end
		showAction("Stir! (" .. i .. "/2)")
		awaitE()
		if cinematicTimedOut then wobbling = false; stopSound("sizzle"); return end
		
		-- Play sizzle sound on stir
		playSound("sizzle", 1.1)
		
		-- Quick stir animation
		for _ = 1, 3 do
			TweenService:Create(pan, TweenInfo.new(0.06), {CFrame = panBase * CFrame.Angles(0, 0, math.rad(8))}):Play()
			task.wait(0.06)
			TweenService:Create(pan, TweenInfo.new(0.06), {CFrame = panBase * CFrame.Angles(0, 0, math.rad(-8))}):Play()
			task.wait(0.06)
		end
		TweenService:Create(pan, TweenInfo.new(0.1), {CFrame = panBase}):Play()
		
		showSubtitle("Stirred " .. i .. "/2! Keep cooking...")
		hideAction()
	end
	
	wobbling = false
	task.wait(cookTime / 4)
	
	-- Stop sizzle sound
	fadeOutSound("sizzle", 0.5)
	
	-- Food changes color (more cooked)
	TweenService:Create(food, TweenInfo.new(0.5), {Color = Color3.fromRGB(
		math.floor(foodColor.R * 255 * 0.7),
		math.floor(foodColor.G * 255 * 0.65),
		math.floor(foodColor.B * 255 * 0.6)
	)}):Play()
	
	showSubtitle("Perfectly cooked! 🔥")
	playSound("success")
	
	-- Increase steam briefly
	steam.Rate = 25
	task.wait(0.5)
	steam.Rate = 0
	
	task.wait(0.5)
	
	-- Cleanup
	for _, p in ipairs(parts) do
		fadeOutPart(p, 0.25)
	end
	
	-- Prevent race condition with timer failure
	if cinematicEnding then return end
	cinematicEnding = true
	exitCinematic()
	CinematicDone:FireServer()
end

--------------------------------------------------------------
-- SERVE CINEMATIC
--------------------------------------------------------------
local function playServeCinematic(data)
	enterCinematic()
	
	local station = getStation("ServingCounter")
	local pos = station and station.Position or Vector3.new(0, 3, 0)
	local parts = {}
	
	-- Set camera to fixed viewing position for serving
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local camPos = pos + Vector3.new(0, 2, 3)
	local camTarget = pos + Vector3.new(0, 0.2, 0)
	TweenService:Create(cam, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		CFrame = CFrame.new(camPos, camTarget)
	}):Play()
	task.wait(0.4)
	
	-- White plate
	local plate = makePart(CFrame.new(pos + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.04, 1, 1), Color3.fromRGB(250, 250, 255), Enum.PartType.Cylinder)
	table.insert(parts, plate)
	
	-- Plate rim
	local rim = makePart(CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.03, 0.85, 0.85), Color3.fromRGB(245, 245, 250), Enum.PartType.Cylinder)
	table.insert(parts, rim)
	
	-- Subtle warm spotlight (reduced glow)
	local spotlight = makePart(CFrame.new(pos + Vector3.new(0, 3, 0)), Vector3.new(0.1, 0.1, 0.1), Color3.new(1, 1, 1), Enum.PartType.Ball, 1)
	local light = Instance.new("SpotLight")
	light.Color = Color3.fromRGB(255, 245, 230)
	light.Brightness = 0.35
	light.Range = 8
	light.Angle = 35
	light.Face = Enum.NormalId.Bottom
	light.Parent = spotlight
	table.insert(parts, spotlight)
	
	showSubtitle("Time to plate the " .. (data.dishName or "dish") .. "!")
	task.wait(0.5)
	
	-- Food components drop onto plate
	local foodPieces = {}
	local dropHeight = 1.5
	
	local colors = data.ingredientColors or {{r=180,g=100,b=60}, {r=100,g=180,b=80}, {r=220,g=180,b=100}}
	
	for i = 1, 3 do
		showAction("Place ingredient " .. i)
		awaitE()
		if cinematicTimedOut then return end
		
		local col = colors[i] or {r=150, g=150, b=150}
		local angle = (i - 1) * (math.pi * 2 / 3)
		local radius = 0.2
		local targetPos = pos + Vector3.new(math.cos(angle) * radius, 0.12, math.sin(angle) * radius)
		
		local piece = makePart(
			CFrame.new(pos + Vector3.new(math.cos(angle) * radius, dropHeight, math.sin(angle) * radius)),
			Vector3.new(0.25, 0.12, 0.25),
			Color3.fromRGB(col.r, col.g, col.b),
			Enum.PartType.Ball
		)
		table.insert(foodPieces, piece)
		table.insert(parts, piece)
		
		-- Animate drop with bounce
		TweenService:Create(piece, TweenInfo.new(0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(targetPos)
		}):Play()
		
		showSubtitle("Placed " .. (data.ingredientLabels and data.ingredientLabels[i] or "component " .. i) .. "!")
		task.wait(0.35)
	end
	
	hideAction()
	
	-- Garnish
	showSubtitle("Adding garnish...")
	task.wait(0.3)
	
	for i = 1, 5 do
		local gx = (math.random() - 0.5) * 0.5
		local gz = (math.random() - 0.5) * 0.5
		local garnish = makePart(
			CFrame.new(pos + Vector3.new(gx, dropHeight, gz)),
			Vector3.new(0.04, 0.04, 0.04),
			Color3.fromRGB(60, 180, 70),
			Enum.PartType.Ball
		)
		table.insert(parts, garnish)
		
		TweenService:Create(garnish, TweenInfo.new(0.25, Enum.EasingStyle.Bounce), {
			CFrame = CFrame.new(pos + Vector3.new(gx, 0.15, gz))
		}):Play()
		task.wait(0.08)
	end
	
	showSubtitle("Beautifully plated!")
	task.wait(0.5)
	if cinematicTimedOut then return end
	
	showAction("Serve the dish!")
	awaitE()
	if cinematicTimedOut then return end
	hideAction()
	
	-- Slide plate forward
	for _, p in ipairs(parts) do
		if p ~= spotlight then
			TweenService:Create(p, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
				CFrame = p.CFrame * CFrame.new(0, 0, -1)
			}):Play()
		end
	end
	
	showSubtitle("Order served! 🍽️")
	task.wait(0.8)
	
	-- Cleanup
	for _, p in ipairs(parts) do
		fadeOutPart(p, 0.3)
	end
	
	-- Prevent race condition with timer failure
	if cinematicEnding then return end
	cinematicEnding = true
	
	-- Stop timer since serve is the final station of an order
	stopCinematicTimer()
	
	exitCinematic()
	CinematicDone:FireServer()
end

--------------------------------------------------------------
-- REMOTE EVENT HANDLERS
--------------------------------------------------------------
ShowTutorial.OnClientEvent:Connect(function()
	print("[ChefUI] ShowTutorial received - starting ChefWorld!")
	chefWorldStarted = true
	gameState.inGame = true
	lockFirstPerson()  -- Lock to first person when ChefWorld starts
	tutorialOverlay.Visible = true
	lockCharacter()
	showMouse()
	
	-- Start background music
	playSound("bgMusic")
	
	-- Create station labels now that we're in ChefWorld
	task.spawn(createStationLabels)
end)

local function closeTutorial()
	tutorialOverlay.Visible = false
	unlockCharacter()
	hideMouse()
	PlayerReady:FireServer("START")
end

tutButton.MouseButton1Click:Connect(closeTutorial)

UIS.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.E and tutorialOverlay.Visible then
		closeTutorial()
	end
end)

StartOrder.OnClientEvent:Connect(function(data)
	print("[ChefUI] StartOrder received:", data.dishName)
	
	-- Reset timer for new order
	stopCinematicTimer()
	
	gameState.currentOrder = data
	gameState.currentStep = 1
	gameState.score = 100
	
	updateTicket(data)
	updateScoreDisplay(100)
	scoreFrame.Visible = true
	ticketHint.Visible = true
	showTicket(true)
	
	task.delay(3, function()
		if ticketFrame.Visible then
			showTicket(false)
			TicketDismissed:FireServer()
		end
	end)
end)

NextTask.OnClientEvent:Connect(function(stepIdx, prompt, icon)
	print("[ChefUI] NextTask:", stepIdx, prompt)
	cinematicEnding = false
	gameState.currentStep = stepIdx
	if gameState.currentOrder then
		updateTicket(gameState.currentOrder)
	end
	showTaskPrompt(icon, prompt)
end)

PlayCinematic.OnClientEvent:Connect(function(data)
	print("[ChefUI] PlayCinematic:", data.station)
	hideTaskPrompt()
	showTicket(false)
	
	if data.station == "Fridge" then
		playFridgeCinematic(data)
	elseif data.station == "PrepStation" then
		playPrepCinematic(data)
	elseif data.station == "Stove" then
		playStoveCinematic(data)
	elseif data.station == "ServingCounter" then
		playServeCinematic(data)
	else
		task.wait(1)
		if not cinematicEnding then
			CinematicDone:FireServer()
		end
	end
end)

WrongStation.OnClientEvent:Connect(function(newScore)
	print("[ChefUI] WrongStation, score:", newScore)
	showWrongStation()
	updateScoreDisplay(newScore)
end)

TaskFailed.OnClientEvent:Connect(function(orderIdx, newScore, penalty, dishName)
	print("[ChefUI] TaskFailed:", dishName)
	updateScoreDisplay(newScore)
	hideTaskPrompt()
end)

OrderDone.OnClientEvent:Connect(function(orderIdx, score, message)
	print("[ChefUI] OrderDone:", orderIdx, score)
	hideTaskPrompt()
	showTicket(false)
	
	orderBanner.Visible = true
	orderBanner.BackgroundTransparency = 0.1
	orderBannerText.Text = "✓ Order " .. orderIdx .. " Complete! (" .. score .. " pts)"
	
	task.delay(2.5, function()
		TweenService:Create(orderBanner, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
		task.delay(0.6, function()
			orderBanner.Visible = false
		end)
	end)
end)

ShowResults.OnClientEvent:Connect(function(data)
	print("[ChefUI] ShowResults:", data.finalScore)
	
	-- Stop background music
	fadeOutSound("bgMusic", 1.5)
	
	-- Play completion sound
	playSound("orderUp")
	
	-- Stop the order timer since order is complete
	stopCinematicTimer()
	cinematicEnding = false
	
	hideTaskPrompt()
	showTicket(false)
	ticketMini.Visible = false
	ticketHint.Visible = false
	scoreFrame.Visible = false
	
	-- Calculate average from order scores
	local orderScores = data.orderScores or {}
	local totalScore = 0
	local orderCount = 0
	for _, score in pairs(orderScores) do
		totalScore = totalScore + score
		orderCount = orderCount + 1
	end
	local avgScore = orderCount > 0 and math.floor(totalScore / orderCount) or 0
	
	resultsScoreNum.Text = tostring(avgScore)
	resultsRank.Text = "★★★ " .. data.rating
	resultsMessage.Text = data.message
	
	-- Build stats text showing individual order scores
	local statsText = ""
	for i = 1, 3 do
		local score = orderScores[i] or 0
		statsText = statsText .. "Ticket " .. i .. ": " .. score .. "/100"
		if i < 3 then statsText = statsText .. "  •  " end
	end
	resultsStats.Text = statsText
	
	if avgScore >= 70 then
		resultsScoreNum.TextColor3 = C.success
		resultsRank.TextColor3 = C.success
	elseif avgScore >= 40 then
		resultsScoreNum.TextColor3 = C.warning
		resultsRank.TextColor3 = C.warning
	else
		resultsScoreNum.TextColor3 = C.error
		resultsRank.TextColor3 = C.error
	end
	
	resultsOverlay.Visible = true
	lockCharacter()
	showMouse()
	
	-- Also unlock camera so mouse can move freely
	plr.CameraMode = Enum.CameraMode.Classic

	-- Tell PlaySequence (the client-side world orchestrator) that Chef is done so
	-- it can advance to the next world. ChefWorldServer fires a WorldCompleted
	-- BindableEvent, but BindableEvents do NOT cross the server/client boundary,
	-- so PlaySequence (client) never receives the server's fire and would stay
	-- stuck waiting. We bridge it here on the client, where it actually works.
	local worldCompleted = ReplicatedStorage:FindFirstChild("WorldCompleted")
	if not worldCompleted then
		worldCompleted = Instance.new("BindableEvent")
		worldCompleted.Name = "WorldCompleted"
		worldCompleted.Parent = ReplicatedStorage
	end
	worldCompleted:Fire(plr, "ChefWorld", {
		finalScore = avgScore,
		orderScores = orderScores,
		rating = data.rating,
		message = data.message,
	})
end)

local function onResultsContinue()
	resultsOverlay.Visible = false
	gameState.inGame = false
	unlockCharacter()
	showMouse()

	-- Do NOT re-lock first-person here. PlaySequence has already taken over
	-- camera control (it shows its own results overlay and sets CameraMode to
	-- Classic). Locking first-person again would override that and leave the
	-- camera stuck in first-person on PlaySequence's results/transition screen.
	PlayerReady:FireServer("COMPLETE")
end

resultsContinue.MouseButton1Click:Connect(onResultsContinue)

UIS.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.E and resultsOverlay.Visible then
		-- MouseButton1Click is a signal, not a function -- call the shared handler
		-- directly instead of trying to invoke the event (which errored before).
		onResultsContinue()
	end
end)

-- T key for ticket
UIS.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.T and gameState.inGame and not tutorialOverlay.Visible and not resultsOverlay.Visible then
		showTicket(not ticketFrame.Visible)
	end
end)

--------------------------------------------------------------
-- STARTUP COMPLETE - Wait for server to request UI ready signal
--------------------------------------------------------------
print("[ChefUI] v14 loaded - All handlers connected")
print("[ChefUI] Waiting for server RequestUIReady signal...")

-- When server asks if we're ready (after PlaySequence fires ActivateChefWorld),
-- respond with ChefUIReady
RequestUIReady.OnClientEvent:Connect(function()
	print("[ChefUI] RequestUIReady received from server - responding with ChefUIReady")
	ChefUIReady:FireServer()
end)

--------------------------------------------------------------
-- SKIP / TEARDOWN HANDLER
-- Fired by the server (StopChefWorld) when the player skips the Chef world.
-- Fully stops every running piece of ChefWorld so nothing plays in the background.
--------------------------------------------------------------
local chefTornDown = false
local function teardownChefWorld()
	if chefTornDown then return end
	chefTornDown = true
	print("[ChefUI] Tearing down ChefWorld (skip)")

	-- Break out of any in-progress cinematic / awaitE loops
	cinematicTimedOut = true
	cinematicEnding = true
	awaitingE = false

	-- Stop timers
	pcall(stopCinematicTimer)

	-- Stop all sounds (music + effects)
	for _, s in pairs(sounds) do
		if s then pcall(function() s:Stop() end) end
	end

	-- Unlock movement + restore mouse/camera to normal third-person
	chefWorldStarted = false
	gameState.inGame = false
	pcall(unlockCharacter)
	pcall(showMouse)
	pcall(function()
		plr.CameraMode = Enum.CameraMode.Classic
		plr.CameraMinZoomDistance = 0.5
		plr.CameraMaxZoomDistance = 128
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end)

	-- Destroy floating station labels we created in the workspace
	for _, station in pairs(cachedStations) do
		if station and station.Parent then
			for _, child in ipairs(station:GetChildren()) do
				if child:IsA("BillboardGui") and string.find(child.Name, "Label") then
					pcall(function() child:Destroy() end)
				end
			end
		end
	end

	-- Destroy the entire ChefWorld UI
	pcall(function() sg:Destroy() end)
end

StopChefWorld.OnClientEvent:Connect(teardownChefWorld)

print("[ChefUI] Ready to receive RequestUIReady from server")
