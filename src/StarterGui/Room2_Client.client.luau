--[[
	Room2_Client.luau (v3 — TUTORIAL, SCORE SCREEN, BUG FIX)
	LocalScript: StarterGui/Room2_Client
	
	Room 2 — Medication Administration (click objects in order)
	
	NEW:
	- Tutorial overlay before task starts
	- Per-room score screen after completion
	- Completion screen stays (bug fix)
	- Smoother transitions
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------------------
-- WAIT FOR NURSEWORLD ACTIVATION
--------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("NurseWorldRemotes")
if not remotes then
	print("[Room2_Client] Waiting for NurseWorld to activate...")
	while not ReplicatedStorage:FindFirstChild("NurseWorldRemotes") do
		task.wait(0.5)
	end
	remotes = ReplicatedStorage:FindFirstChild("NurseWorldRemotes")
end
print("[Room2_Client] NurseWorld active - initializing")
local Room2StartEvent = remotes:WaitForChild("Room2Start")
local Room2ClickEvent = remotes:WaitForChild("Room2Click")
local Room2FeedbackEvent = remotes:WaitForChild("Room2Feedback")
local Room2CompleteEvent = remotes:WaitForChild("Room2Complete")

local Room2Config = require(ReplicatedStorage:WaitForChild("NurseWorld"):WaitForChild("Room2_MedSafety"))
local config = Room2Config.GetConfig()

--------------------------------------------------------------
-- COLORS
--------------------------------------------------------------
local C = {
	bg = Color3.fromRGB(22, 27, 34),
	panelBg = Color3.fromRGB(30, 36, 46),
	accent = Color3.fromRGB(134, 239, 172),
	correct = Color3.fromRGB(74, 222, 128),
	wrong = Color3.fromRGB(248, 113, 113),
	highlight = Color3.fromRGB(134, 239, 172),
	highlightWrong = Color3.fromRGB(248, 113, 113),
	textPri = Color3.fromRGB(255, 255, 255),
	textSec = Color3.fromRGB(156, 163, 175),
	textMut = Color3.fromRGB(107, 114, 128),
	stepDone = Color3.fromRGB(74, 222, 128),
	stepPend = Color3.fromRGB(55, 65, 81),
	stepCur = Color3.fromRGB(134, 239, 172),
	warning = Color3.fromRGB(251, 191, 36),
}
local function mkC(p,r) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 8);c.Parent=p end
local function mkS(p,col,t) local s=Instance.new("UIStroke");s.Color=col or C.accent;s.Thickness=t or 1;s.Parent=p;return s end

--------------------------------------------------------------
-- SCREEN GUI
--------------------------------------------------------------
local sg = Instance.new("ScreenGui")
sg.Name = "Room2UI"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Enabled = false
sg.Parent = playerGui

--------------------------------------------------------------
-- TUTORIAL OVERLAY
--------------------------------------------------------------
local tutOverlay = Instance.new("Frame")
tutOverlay.Size = UDim2.new(1,0,1,0)
tutOverlay.BackgroundColor3 = Color3.new(0,0,0)
tutOverlay.BackgroundTransparency = 0.4
tutOverlay.Visible = false
tutOverlay.ZIndex = 20
tutOverlay.Parent = sg

local tutPanel = Instance.new("Frame")
tutPanel.Size = UDim2.new(0,700,0,400)
tutPanel.Position = UDim2.new(0.5,-350,0.5,-200)
tutPanel.BackgroundColor3 = C.panelBg
tutPanel.ZIndex = 21
tutPanel.Parent = tutOverlay
mkC(tutPanel, 14); mkS(tutPanel, C.accent, 3)

local tutTitle = Instance.new("TextLabel")
tutTitle.Size = UDim2.new(1,0,0,50)
tutTitle.Position = UDim2.new(0,0,0,28)
tutTitle.BackgroundTransparency = 1
tutTitle.Text = "MEDICATION ADMINISTRATION"
tutTitle.TextColor3 = C.accent
tutTitle.TextSize = 28
tutTitle.Font = Enum.Font.GothamBlack
tutTitle.ZIndex = 22
tutTitle.Parent = tutPanel

local tutBody = Instance.new("TextLabel")
tutBody.Size = UDim2.new(1,-60,0,180)
tutBody.Position = UDim2.new(0,30,0,90)
tutBody.BackgroundTransparency = 1
tutBody.Text = "Mr. Alvarez needs his pain medication.\n\nYou must follow the correct safety protocol by interacting with objects in the room in the RIGHT ORDER.\n\nWalk to each glowing object and press [E] to interact.\nWrong order = point deduction. 3 mistakes = fail."
tutBody.TextColor3 = C.textPri
tutBody.TextSize = 18
tutBody.Font = Enum.Font.Gotham
tutBody.TextWrapped = true
tutBody.TextXAlignment = Enum.TextXAlignment.Left
tutBody.TextYAlignment = Enum.TextYAlignment.Top
tutBody.ZIndex = 22
tutBody.Parent = tutPanel

local tutSteps = Instance.new("TextLabel")
tutSteps.Size = UDim2.new(1,-60,0,28)
tutSteps.Position = UDim2.new(0,30,0,280)
tutSteps.BackgroundTransparency = 1
tutSteps.Text = "5 steps: Sanitize → Verify → Check Order → Select Med → Administer"
tutSteps.TextColor3 = C.accent
tutSteps.TextSize = 16
tutSteps.Font = Enum.Font.Code
tutSteps.ZIndex = 22
tutSteps.Parent = tutPanel

local tutHint = Instance.new("TextLabel")
tutHint.Size = UDim2.new(0,240,0,50)
tutHint.Position = UDim2.new(0.5,-120,1,-70)
tutHint.BackgroundColor3 = C.accent
tutHint.Text = "  Press [E] to Begin"
tutHint.TextColor3 = C.bg
tutHint.TextSize = 18
tutHint.Font = Enum.Font.GothamBold
tutHint.TextXAlignment = Enum.TextXAlignment.Left
tutHint.ZIndex = 22
tutHint.Parent = tutPanel
mkC(tutHint, 8)

--------------------------------------------------------------
-- INSTRUCTION BAR
--------------------------------------------------------------
local instrBar = Instance.new("Frame")
instrBar.Size = UDim2.new(0,600,0,70)
instrBar.Position = UDim2.new(0.5,-300,0,20)
instrBar.BackgroundColor3 = C.panelBg
instrBar.BackgroundTransparency = 0.1
instrBar.Visible = false
instrBar.Parent = sg
mkC(instrBar, 10); mkS(instrBar, C.accent, 1)

local stepLbl = Instance.new("TextLabel")
stepLbl.Size = UDim2.new(1,-20,0,18)
stepLbl.Position = UDim2.new(0,10,0,8)
stepLbl.BackgroundTransparency = 1
stepLbl.Text = "// STEP 1 OF 5"
stepLbl.TextColor3 = C.accent
stepLbl.TextSize = 11
stepLbl.Font = Enum.Font.Code
stepLbl.TextXAlignment = Enum.TextXAlignment.Left
stepLbl.Parent = instrBar

local instrText = Instance.new("TextLabel")
instrText.Size = UDim2.new(1,-20,0,28)
instrText.Position = UDim2.new(0,10,0,30)
instrText.BackgroundTransparency = 1
instrText.Text = ""
instrText.TextColor3 = C.textPri
instrText.TextSize = 15
instrText.Font = Enum.Font.GothamMedium
instrText.TextXAlignment = Enum.TextXAlignment.Left
instrText.Parent = instrBar

-- Nav hint (bigger, white text)
local navHint = Instance.new("TextLabel")
navHint.Size = UDim2.new(0,500,0,40)
navHint.Position = UDim2.new(0.5,-250,1,-55)
navHint.BackgroundColor3 = C.panelBg
navHint.BackgroundTransparency = 0.15
navHint.Text = "  Walk to the glowing object and click to interact"
navHint.TextColor3 = C.textPri
navHint.TextSize = 16
navHint.Font = Enum.Font.Code
navHint.TextXAlignment = Enum.TextXAlignment.Left
navHint.Parent = sg
mkC(navHint, 10)

-- Step tracker (bigger)
local stepTracker = Instance.new("Frame")
stepTracker.Size = UDim2.new(0,500,0,65)
stepTracker.Position = UDim2.new(0.5,-250,1,-110)
stepTracker.BackgroundColor3 = C.panelBg
stepTracker.BackgroundTransparency = 0.1
stepTracker.Parent = sg
mkC(stepTracker, 12)

local tLayout = Instance.new("UIListLayout")
tLayout.FillDirection = Enum.FillDirection.Horizontal
tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tLayout.Padding = UDim.new(0,14)
tLayout.Parent = stepTracker

local stepDots = {}
for i, step in config.steps do
	local df = Instance.new("Frame"); df.Size = UDim2.new(0,75,0,50); df.BackgroundTransparency = 1; df.Parent = stepTracker
	local d = Instance.new("Frame"); d.Name = "D"; d.Size = UDim2.new(0,38,0,38); d.Position = UDim2.new(0.5,-19,0,0); d.BackgroundColor3 = (i==1) and C.stepCur or C.stepPend; d.Parent = df; mkC(d,999)
	local ic = Instance.new("TextLabel"); ic.Size = UDim2.new(1,0,1,0); ic.BackgroundTransparency = 1; ic.Text = step.icon; ic.TextSize = 18; ic.Parent = d
	stepDots[i] = d
end

-- Feedback popup (doubled size)
local fbPopup = Instance.new("Frame")
fbPopup.Size = UDim2.new(0,700,0,100)
fbPopup.Position = UDim2.new(0.5,-350,0.35,0)
fbPopup.BackgroundColor3 = C.panelBg
fbPopup.Visible = false
fbPopup.ZIndex = 5
fbPopup.Parent = sg
mkC(fbPopup, 12)

local fbText = Instance.new("TextLabel")
fbText.Size = UDim2.new(1,-30,1,0)
fbText.Position = UDim2.new(0,15,0,0)
fbText.BackgroundTransparency = 1
fbText.Text = ""
fbText.TextColor3 = C.textPri
fbText.TextSize = 18
fbText.Font = Enum.Font.GothamMedium
fbText.TextWrapped = true
fbText.TextXAlignment = Enum.TextXAlignment.Left
fbText.ZIndex = 6
fbText.Parent = fbPopup

-- Mistake counter
local mistakeF = Instance.new("Frame")
mistakeF.Size = UDim2.new(0,140,0,36)
mistakeF.Position = UDim2.new(1,-160,0,20)
mistakeF.BackgroundColor3 = C.panelBg
mistakeF.BackgroundTransparency = 0.1
mistakeF.Parent = sg
mkC(mistakeF, 8)

local mistakeLbl = Instance.new("TextLabel")
mistakeLbl.Size = UDim2.new(1,-10,1,0)
mistakeLbl.Position = UDim2.new(0,10,0,0)
mistakeLbl.BackgroundTransparency = 1
mistakeLbl.Text = "Mistakes: 0 / 3"
mistakeLbl.TextColor3 = C.textSec
mistakeLbl.TextSize = 12
mistakeLbl.Font = Enum.Font.GothamMedium
mistakeLbl.TextXAlignment = Enum.TextXAlignment.Left
mistakeLbl.Parent = mistakeF

--------------------------------------------------------------
-- ROOM SCORE SCREEN (shown after completing Room 2)
--------------------------------------------------------------
local scoreScreen = Instance.new("Frame")
scoreScreen.Name = "Room2Score"
scoreScreen.Size = UDim2.new(1,0,1,0)
scoreScreen.BackgroundColor3 = C.bg
scoreScreen.BackgroundTransparency = 0.1
scoreScreen.Visible = false
scoreScreen.ZIndex = 25
scoreScreen.Parent = sg

local scorePanel = Instance.new("Frame")
scorePanel.Size = UDim2.new(0,600,0,450)
scorePanel.Position = UDim2.new(0.5,-300,0.5,-225)
scorePanel.BackgroundColor3 = C.panelBg
scorePanel.ZIndex = 26
scorePanel.Parent = scoreScreen
mkC(scorePanel, 16); mkS(scorePanel, C.accent, 3)

local scLabel = Instance.new("TextLabel")
scLabel.Size = UDim2.new(1,0,0,20)
scLabel.Position = UDim2.new(0,0,0,28)
scLabel.BackgroundTransparency = 1
scLabel.Text = "// MEDICATION ADMINISTRATION COMPLETE"
scLabel.TextColor3 = C.accent
scLabel.TextSize = 14
scLabel.Font = Enum.Font.Code
scLabel.ZIndex = 27
scLabel.Parent = scorePanel

local scTitle = Instance.new("TextLabel")
scTitle.Size = UDim2.new(1,0,0,40)
scTitle.Position = UDim2.new(0,0,0,55)
scTitle.BackgroundTransparency = 1
scTitle.Text = "Room 2 Results"
scTitle.TextColor3 = C.textPri
scTitle.TextSize = 32
scTitle.Font = Enum.Font.GothamBlack
scTitle.ZIndex = 27
scTitle.Parent = scorePanel

local scCircle = Instance.new("Frame")
scCircle.Size = UDim2.new(0,110,0,110)
scCircle.Position = UDim2.new(0.5,-55,0,110)
scCircle.BackgroundColor3 = C.bg
scCircle.ZIndex = 27
scCircle.Parent = scorePanel
mkC(scCircle, 55)
local scCircleStroke = mkS(scCircle, C.accent, 4)

local scVal = Instance.new("TextLabel")
scVal.Size = UDim2.new(1,0,0.6,0)
scVal.Position = UDim2.new(0,0,0.1,0)
scVal.BackgroundTransparency = 1
scVal.Text = "100"
scVal.TextColor3 = C.accent
scVal.TextSize = 38
scVal.Font = Enum.Font.GothamBlack
scVal.ZIndex = 28
scVal.Parent = scCircle

local scPts = Instance.new("TextLabel")
scPts.Size = UDim2.new(1,0,0.3,0)
scPts.Position = UDim2.new(0,0,0.6,0)
scPts.BackgroundTransparency = 1
scPts.Text = "PTS"
scPts.TextColor3 = C.textPri
scPts.TextSize = 12
scPts.Font = Enum.Font.Code
scPts.ZIndex = 28
scPts.Parent = scCircle

local scMsg = Instance.new("TextLabel")
scMsg.Size = UDim2.new(1,-60,0,70)
scMsg.Position = UDim2.new(0,30,0,240)
scMsg.BackgroundTransparency = 1
scMsg.Text = ""
scMsg.TextColor3 = C.textPri
scMsg.TextSize = 16
scMsg.Font = Enum.Font.Gotham
scMsg.TextWrapped = true
scMsg.ZIndex = 27
scMsg.Parent = scorePanel

local scMistakes = Instance.new("TextLabel")
scMistakes.Size = UDim2.new(1,0,0,24)
scMistakes.Position = UDim2.new(0,0,0,320)
scMistakes.BackgroundTransparency = 1
scMistakes.Text = ""
scMistakes.TextColor3 = C.textPri
scMistakes.TextSize = 14
scMistakes.Font = Enum.Font.Code
scMistakes.ZIndex = 27
scMistakes.Parent = scorePanel

local scHint = Instance.new("TextLabel")
scHint.Size = UDim2.new(0,260,0,50)
scHint.Position = UDim2.new(0.5,-130,0,370)
scHint.BackgroundColor3 = C.accent
scHint.Text = "  [E] Continue to Room 3"
scHint.TextColor3 = C.bg
scHint.TextSize = 18
scHint.Font = Enum.Font.GothamBold
scHint.TextXAlignment = Enum.TextXAlignment.Left
scHint.ZIndex = 27
scHint.Parent = scorePanel
mkC(scHint, 8)

--------------------------------------------------------------
-- STATE
--------------------------------------------------------------
local phase = "IDLE" -- IDLE, TUTORIAL, ACTIVE, SCORE
local isActive = false
local currentStep = 1
local mistakes = 0
local clickableObjects = {}
local floatingLabels = {}
local currentHighlight = nil
local pulseConnection = nil
local roomScore = 100

--------------------------------------------------------------
-- FLOATING LABELS (bigger, more visible)
--------------------------------------------------------------
local function createLabel(part, text, isTarget)
	local ex = part:FindFirstChild("R2Lbl"); if ex then ex:Destroy() end
	local bb = Instance.new("BillboardGui"); bb.Name = "R2Lbl"
	bb.Size = UDim2.new(0,240,0,70); bb.StudsOffset = Vector3.new(0,5,0)
	bb.AlwaysOnTop = true; bb.MaxDistance = 50; bb.Parent = part

	local bg = Instance.new("Frame"); bg.Size = UDim2.new(1,0,0,40)
	bg.BackgroundColor3 = isTarget and C.accent or C.panelBg
	bg.BackgroundTransparency = isTarget and 0 or 0.2; bg.Parent = bb; mkC(bg,8)
	local tx = Instance.new("TextLabel"); tx.Size = UDim2.new(1,0,1,0); tx.BackgroundTransparency = 1
	tx.Text = text; tx.TextColor3 = isTarget and C.bg or C.textPri; tx.TextSize = 16; tx.Font = Enum.Font.GothamBold; tx.Parent = bg
	local ar = Instance.new("TextLabel"); ar.Size = UDim2.new(1,0,0,22); ar.Position = UDim2.new(0,0,0,42)
	ar.BackgroundTransparency = 1; ar.Text = "V"; ar.TextColor3 = isTarget and C.accent or C.textPri; ar.TextSize = 20; ar.Font = Enum.Font.GothamBold; ar.Parent = bb
	floatingLabels[part.Name] = bb
end
local function removeLabel(p) local l = p:FindFirstChild("R2Lbl"); if l then l:Destroy() end; floatingLabels[p.Name] = nil end
local function removeAllLabels() for _,p in clickableObjects do removeLabel(p) end end

--------------------------------------------------------------
-- HIGHLIGHTS
--------------------------------------------------------------
local function addHL(part, color)
	local ex = part:FindFirstChild("R2HL"); if ex then ex:Destroy() end
	local h = Instance.new("Highlight"); h.Name = "R2HL"
	h.FillColor = color or C.highlight; h.FillTransparency = 0.3
	h.OutlineColor = color or C.highlight; h.OutlineTransparency = 0
	if part.Parent and part.Parent:IsA("Model") and not part.Parent.Name:find("PatientBed") then h.Adornee = part.Parent else h.Adornee = part end
	h.Parent = part
	return h
end
local function removeHL(p) local h = p:FindFirstChild("R2HL"); if h then h:Destroy() end; if p.Parent and p.Parent:IsA("Model") then local h2 = p.Parent:FindFirstChild("R2HL"); if h2 then h2:Destroy() end end end
local function removeAllHL() for _,p in clickableObjects do removeHL(p) end; if pulseConnection then pulseConnection:Disconnect(); pulseConnection = nil end end

local function highlightCurrent()
	removeAllHL(); removeAllLabels()
	local step = config.steps[currentStep]; if not step then return end
	local part = clickableObjects[step.objectName]; if not part then return end
	currentHighlight = addHL(part, C.highlight)
	createLabel(part, step.label .. " [Click]", true)
	local exL = part:FindFirstChild("R2Light"); if exL then exL:Destroy() end
	local light = Instance.new("PointLight"); light.Name = "R2Light"; light.Color = C.highlight; light.Brightness = 2; light.Range = 10; light.Parent = part
	local pt = 0
	pulseConnection = RunService.Heartbeat:Connect(function(dt)
		pt = pt+dt
		if currentHighlight and currentHighlight.Parent then currentHighlight.FillTransparency = 0.2+0.2*math.sin(pt*4) end
		if light and light.Parent then light.Brightness = 1.5+1*math.sin(pt*4) end
	end)
end

--------------------------------------------------------------
-- FEEDBACK
--------------------------------------------------------------
local function showFb(text, ok)
	local ex = fbPopup:FindFirstChildWhichIsA("UIStroke"); if ex then ex:Destroy() end
	mkS(fbPopup, ok and C.accent or C.wrong, 2)
	fbText.Text = text; fbText.TextColor3 = C.textPri -- Always white text
	fbPopup.Visible = true
	task.delay(2.5, function() fbPopup.Visible = false end)
end

--------------------------------------------------------------
-- UI UPDATE
--------------------------------------------------------------
local function updateUI()
	local step = config.steps[currentStep]
	if step then stepLbl.Text = "// STEP "..currentStep.." OF "..#config.steps; instrText.Text = step.instruction end
	mistakeLbl.Text = "Mistakes: "..mistakes.." / "..config.maxMistakes
	if mistakes >= 2 then mistakeLbl.TextColor3 = C.wrong else mistakeLbl.TextColor3 = C.textSec end
	for i, d in stepDots do
		if i < currentStep then d.BackgroundColor3 = C.stepDone
		elseif i == currentStep then d.BackgroundColor3 = C.stepCur
		else d.BackgroundColor3 = C.stepPend end
	end
end

--------------------------------------------------------------
-- SHOW ROOM SCORE
--------------------------------------------------------------
local function showRoomScore()
	phase = "SCORE"
	instrBar.Visible = false; navHint.Visible = false; stepTracker.Visible = false; mistakeF.Visible = false

	roomScore = math.max(0, 100 - (mistakes * config.pointsPerMistake))
	scVal.Text = tostring(roomScore)
	if roomScore >= 67 then scCircleStroke.Color = C.correct; scVal.TextColor3 = C.correct
	elseif roomScore >= 34 then scCircleStroke.Color = C.warning; scVal.TextColor3 = C.warning
	else scCircleStroke.Color = C.wrong; scVal.TextColor3 = C.wrong end

	scMistakes.Text = "Mistakes: "..mistakes.." / "..config.maxMistakes
	if mistakes == 0 then scMsg.Text = config.resultGood
	else scMsg.Text = config.resultBad end

	scoreScreen.Visible = true
end

--------------------------------------------------------------
-- INTERACTION
--------------------------------------------------------------
local function interact(objName)
	if not isActive then return end
	local step = config.steps[currentStep]; if not step then return end

	if objName == step.objectName then
		showFb(step.correctFeedback, true)
		local part = clickableObjects[objName]
		if part then
			removeHL(part); removeLabel(part)
			local l = part:FindFirstChild("R2Light"); if l then l:Destroy() end
			local flash = addHL(part, C.correct)
			task.delay(0.8, function() if flash and flash.Parent then flash:Destroy() end end)
		end
		currentStep = currentStep + 1
		if currentStep > #config.steps then
			isActive = false; removeAllHL(); removeAllLabels()
			-- Show room score FIRST, then tell server
			task.delay(1.5, function()
				showRoomScore()
			end)
		else
			updateUI()
			task.delay(1, function() highlightCurrent() end)
		end
		Room2ClickEvent:FireServer("CORRECT", currentStep - 1)
	else
		mistakes = mistakes + 1
		showFb(step.wrongClickFeedback, false)
		local part = clickableObjects[objName]
		if part then
			local wh = addHL(part, C.highlightWrong)
			task.delay(0.8, function() if wh and wh.Parent then wh:Destroy() end; highlightCurrent() end)
		end
		updateUI()
		Room2ClickEvent:FireServer("WRONG", objName, mistakes)
		if mistakes >= config.maxMistakes then
			isActive = false; removeAllHL(); removeAllLabels()
			task.delay(1.5, function() showRoomScore() end)
			Room2ClickEvent:FireServer("FAILED", mistakes)
		end
	end
end

--------------------------------------------------------------
-- CLICK DETECTORS
--------------------------------------------------------------
local function setupClicks(bed)
	for _, step in config.steps do
		local part = bed:FindFirstChild(step.objectName, true)
		if part then
			clickableObjects[step.objectName] = part
			local det = part:FindFirstChild("ClickDetector")
			if not det then det = Instance.new("ClickDetector"); det.MaxActivationDistance = 15; det.Parent = part end
			det.MouseClick:Connect(function() interact(step.objectName) end)
		else
			warn("[Room2] NOT FOUND: "..step.objectName)
		end
	end
end

--------------------------------------------------------------
-- KEYBOARD
--------------------------------------------------------------
UserInputService.InputBegan:Connect(function(inp, gp)
	if gp then return end
	local k = inp.KeyCode
	if not (k == Enum.KeyCode.E or k == Enum.KeyCode.Return) then return end

	if phase == "TUTORIAL" then
		-- Dismiss tutorial, start the task
		tutOverlay.Visible = false
		phase = "ACTIVE"
		isActive = true
		instrBar.Visible = true; navHint.Visible = true; stepTracker.Visible = true; mistakeF.Visible = true
		updateUI()
		task.delay(0.5, function() highlightCurrent() end)

	elseif phase == "ACTIVE" and isActive then
		-- E to interact with current step object
		local step = config.steps[currentStep]; if not step then return end
		local part = clickableObjects[step.objectName]; if not part then return end
		local char = player.Character; if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
		local targetPos = part.Position
		if part:IsA("Model") then local p = part.PrimaryPart or part:FindFirstChildWhichIsA("BasePart"); if p then targetPos = p.Position end end
		if (root.Position - targetPos).Magnitude <= 15 then
			interact(step.objectName)
		else
			showFb("Get closer to the "..step.label.."!", false)
		end

	elseif phase == "SCORE" then
		-- Dismiss score screen, tell server we're done
		scoreScreen.Visible = false
		sg.Enabled = false
		phase = "IDLE"
		Room2ClickEvent:FireServer("COMPLETE", mistakes)
	end
end)

--------------------------------------------------------------
-- EVENTS
--------------------------------------------------------------
Room2StartEvent.OnClientEvent:Connect(function()
	local bed = workspace:FindFirstChild("NurseWorld")
	bed = bed and bed:FindFirstChild("PatientBeds")
	bed = bed and bed:FindFirstChild("PatientBed_02")
	if not bed then warn("[Room2] PatientBed_02 not found!"); return end

	currentStep = 1; mistakes = 0; isActive = false; clickableObjects = {}; floatingLabels = {}; roomScore = 100
	setupClicks(bed)

	-- Show tutorial first
	sg.Enabled = true
	phase = "TUTORIAL"
	tutOverlay.Visible = true
	instrBar.Visible = false; navHint.Visible = false; stepTracker.Visible = false; mistakeF.Visible = false
	scoreScreen.Visible = false
end)

Room2FeedbackEvent.OnClientEvent:Connect(function(ok, msg) showFb(msg, ok) end)

Room2CompleteEvent.OnClientEvent:Connect(function()
	isActive = false; removeAllHL(); removeAllLabels()
	sg.Enabled = false; phase = "IDLE"
end)

--------------------------------------------------------------
-- TEARDOWN (NurseWorld ended — normal completion OR skip)
--------------------------------------------------------------
local r2TornDown = false
local function teardownRoom2()
	if r2TornDown then return end
	r2TornDown = true
	print("[Room2_Client] Tearing down")
	isActive = false
	phase = "IDLE"
	pcall(removeAllHL)
	pcall(removeAllLabels)
	-- Remove leftover point lights on interactable parts
	for _, p in pairs(clickableObjects) do
		if p then
			local l = p:FindFirstChild("R2Light")
			if l then pcall(function() l:Destroy() end) end
		end
	end
	pcall(function() sg:Destroy() end)
end

task.spawn(function()
	local nurseActive = ReplicatedStorage:FindFirstChild("NurseWorldActive")
	while not nurseActive do
		task.wait(0.2)
		nurseActive = ReplicatedStorage:FindFirstChild("NurseWorldActive")
	end
	while not nurseActive.Value do task.wait(0.2) end
	nurseActive:GetPropertyChangedSignal("Value"):Connect(function()
		if not nurseActive.Value then teardownRoom2() end
	end)
end)

task.spawn(function()
	local stopRemote = remotes:FindFirstChild("StopNurseWorld") or remotes:WaitForChild("StopNurseWorld", 10)
	if stopRemote then
		stopRemote.OnClientEvent:Connect(teardownRoom2)
	end
end)

print("[Room2_Client] v3 — tutorial, score screen, smoother flow.")
