--[[
	NurseUI.luau (v5 — IMPROVED UX)
	LocalScript: StarterGui/NurseWorldUI
	
	Room 1 — Nurse's Office
	
	CHANGES v5:
	- Guidance text at top of screen
	- Bigger tutorial popup, white text
	- File card centered first, slides left on review
	- Mouse + keyboard support
	- No auto-selection, SUBMIT button
	- Green hint text, hover effects
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

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
-- Whoosh/swoosh sounds for file animations
createSound("whooshIn", 126075276165126, 0.4)       -- Whoosh in
createSound("whooshOut", 139731037802687, 0.3)      -- Reverse whoosh out  
createSound("paperSlide", 9117189040, 0.35)         -- Paper slide (play for 1 sec)

-- UI feedback sounds
createSound("correctAnswer", 72697499666151, 0.4)   -- Correct answer chime
createSound("wrongAnswer", 14428739841, 0.35)       -- Wrong answer buzz

-- Background music (calm medical/hospital ambiance) - 50% volume
createSound("bgMusicMedical", 140139016996389, 0.06, true)  -- Looped background music (reduced)

--------------------------------------------------------------
-- WAIT FOR NURSEWORLD ACTIVATION
--------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("NurseWorldRemotes")
if not remotes then
	print("[NurseWorldUI] Waiting for NurseWorld to activate...")
	while not ReplicatedStorage:FindFirstChild("NurseWorldRemotes") do
		task.wait(0.5)
	end
	remotes = ReplicatedStorage:FindFirstChild("NurseWorldRemotes")
end

print("[NurseWorldUI] NurseWorld active - initializing UI")
local StartScenarioEvent = remotes:WaitForChild("StartScenario")
local ShowTaskEvent = remotes:WaitForChild("ShowTask")
local ChoiceMadeEvent = remotes:WaitForChild("ChoiceMade")
local ShowFeedbackEvent = remotes:WaitForChild("ShowFeedback")
local UpdateScoreEvent = remotes:WaitForChild("UpdateScore")
local ShowResultsEvent = remotes:WaitForChild("ShowResults")
local ScenarioCompleteEvent = remotes:WaitForChild("ScenarioComplete")

--------------------------------------------------------------
-- COLORS
--------------------------------------------------------------
local C = {
	bg = Color3.fromRGB(22, 27, 34),
	panelBg = Color3.fromRGB(30, 36, 46),
	panelBorder = Color3.fromRGB(55, 65, 81),
	accent = Color3.fromRGB(134, 239, 172),
	correct = Color3.fromRGB(74, 222, 128),
	wrong = Color3.fromRGB(248, 113, 113),
	warning = Color3.fromRGB(251, 191, 36),
	textPri = Color3.fromRGB(255, 255, 255),
	textSec = Color3.fromRGB(200, 205, 215),
	textMut = Color3.fromRGB(140, 150, 165),
	btnDef = Color3.fromRGB(40, 48, 62),
	btnSel = Color3.fromRGB(45, 60, 50),
	btnHover = Color3.fromRGB(50, 58, 72),
	fileBg = Color3.fromRGB(245, 240, 230),
	fileText = Color3.fromRGB(30, 30, 30),
	fileBorder = Color3.fromRGB(180, 170, 155),
	vitals = Color3.fromRGB(167, 139, 250),
}
local function mkC(p,r) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 8);c.Parent=p end
local function mkS(p,col,t) local s=Instance.new("UIStroke");s.Color=col or C.panelBorder;s.Thickness=t or 1;s.Parent=p;return s end
local function mkP(p,px) local pd=Instance.new("UIPadding");pd.PaddingTop=UDim.new(0,px);pd.PaddingBottom=UDim.new(0,px);pd.PaddingLeft=UDim.new(0,px);pd.PaddingRight=UDim.new(0,px);pd.Parent=p end

--------------------------------------------------------------
-- STATE
--------------------------------------------------------------
local panel = "NONE"
local selIdx = 0 -- 0 = nothing selected
local choiceCnt = 3
local inputOn = false
local bedModel = nil
local isSeated = false
local firstStart = true
local fileIsLeft = false -- track if file has slid left

--------------------------------------------------------------
-- SCREEN GUI
--------------------------------------------------------------
local sg = Instance.new("ScreenGui")
sg.Name = "NurseWorldUI"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Parent = playerGui

-- Blur overlay
local blur = Instance.new("Frame")
blur.Size = UDim2.new(1,0,1,0)
blur.BackgroundColor3 = Color3.new(0,0,0)
blur.BackgroundTransparency = 1
blur.Visible = false
blur.ZIndex = 1
blur.Parent = sg

--------------------------------------------------------------
-- GUIDANCE TEXT (top of screen)
--------------------------------------------------------------
local guideFrame = Instance.new("Frame")
guideFrame.Size = UDim2.new(0, 500, 0, 50)
guideFrame.Position = UDim2.new(0.5, -250, 0, 25)
guideFrame.BackgroundColor3 = C.panelBg
guideFrame.BackgroundTransparency = 0.15
guideFrame.Visible = false
guideFrame.ZIndex = 25
guideFrame.Parent = sg
mkC(guideFrame, 10)
mkS(guideFrame, C.accent, 2)

local guideText = Instance.new("TextLabel")
guideText.Size = UDim2.new(1, -20, 1, 0)
guideText.Position = UDim2.new(0, 10, 0, 0)
guideText.BackgroundTransparency = 1
guideText.Text = "Look for the Office room (labels are above the doors)"
guideText.TextColor3 = C.textPri
guideText.TextSize = 18
guideText.Font = Enum.Font.GothamMedium
guideText.ZIndex = 26
guideText.Parent = guideFrame

-- Nav hint (bottom) - now green
local navHint = Instance.new("TextLabel")
navHint.Size = UDim2.new(0,400,0,35)
navHint.Position = UDim2.new(0.5,-200,1,-50)
navHint.BackgroundColor3 = C.panelBg
navHint.BackgroundTransparency = 0.15
navHint.Text = ""
navHint.TextColor3 = C.accent
navHint.TextSize = 14
navHint.Font = Enum.Font.Code
navHint.Visible = false
navHint.ZIndex = 20
navHint.Parent = sg
mkC(navHint, 8)

--------------------------------------------------------------
-- FILE CARD (starts centered, can slide left) - BIGGER
--------------------------------------------------------------
local fileCard = Instance.new("Frame")
fileCard.Size = UDim2.new(0,520,0,600)
fileCard.Position = UDim2.new(0.5,-260,1,50) -- starts below screen
fileCard.BackgroundColor3 = C.fileBg
fileCard.Visible = false
fileCard.ZIndex = 5
fileCard.Parent = sg
mkC(fileCard,6); mkS(fileCard,C.fileBorder,2)

-- File tab
local fTab = Instance.new("Frame")
fTab.Size = UDim2.new(0,200,0,36)
fTab.Position = UDim2.new(0,22,0,-36)
fTab.BackgroundColor3 = C.fileBg
fTab.ZIndex = 6
fTab.Parent = fileCard
mkC(fTab,6)

local fTabTxt = Instance.new("TextLabel")
fTabTxt.Size = UDim2.new(1,0,1,0)
fTabTxt.BackgroundTransparency = 1
fTabTxt.Text = "PATIENT FILE #1"
fTabTxt.TextColor3 = C.fileText
fTabTxt.TextSize = 15
fTabTxt.Font = Enum.Font.GothamBold
fTabTxt.ZIndex = 7
fTabTxt.Parent = fTab

local fContent = Instance.new("Frame")
fContent.Size = UDim2.new(1,-44,1,-55)
fContent.Position = UDim2.new(0,22,0,28)
fContent.BackgroundTransparency = 1
fContent.ZIndex = 6
fContent.Parent = fileCard

local fName = Instance.new("TextLabel")
fName.Size = UDim2.new(1,0,0,38)
fName.BackgroundTransparency = 1
fName.Text = ""
fName.TextColor3 = C.fileText
fName.TextSize = 26
fName.Font = Enum.Font.GothamBlack
fName.TextXAlignment = Enum.TextXAlignment.Left
fName.ZIndex = 7
fName.Parent = fContent

local fDiv = Instance.new("Frame")
fDiv.Size = UDim2.new(1,0,0,1)
fDiv.Position = UDim2.new(0,0,0,44)
fDiv.BackgroundColor3 = C.fileBorder
fDiv.ZIndex = 7
fDiv.Parent = fContent

local fInfoLbl = Instance.new("TextLabel")
fInfoLbl.Size = UDim2.new(1,0,0,18)
fInfoLbl.Position = UDim2.new(0,0,0,54)
fInfoLbl.BackgroundTransparency = 1
fInfoLbl.Text = "PATIENT INFORMATION"
fInfoLbl.TextColor3 = C.textMut
fInfoLbl.TextSize = 10
fInfoLbl.Font = Enum.Font.GothamBold
fInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
fInfoLbl.ZIndex = 7
fInfoLbl.Parent = fContent

local fBrief = Instance.new("TextLabel")
fBrief.Size = UDim2.new(1,0,0,130)
fBrief.Position = UDim2.new(0,0,0,76)
fBrief.BackgroundTransparency = 1
fBrief.Text = ""
fBrief.TextColor3 = C.fileText
fBrief.TextSize = 15
fBrief.Font = Enum.Font.Gotham
fBrief.TextXAlignment = Enum.TextXAlignment.Left
fBrief.TextYAlignment = Enum.TextYAlignment.Top
fBrief.TextWrapped = true
fBrief.ZIndex = 7
fBrief.Parent = fContent

local fVitLbl = Instance.new("TextLabel")
fVitLbl.Size = UDim2.new(1,0,0,18)
fVitLbl.Position = UDim2.new(0,0,0,215)
fVitLbl.BackgroundTransparency = 1
fVitLbl.Text = "VITAL SIGNS"
fVitLbl.TextColor3 = C.vitals
fVitLbl.TextSize = 12
fVitLbl.Font = Enum.Font.GothamBold
fVitLbl.TextXAlignment = Enum.TextXAlignment.Left
fVitLbl.ZIndex = 7
fVitLbl.Parent = fContent

local fVitals = Instance.new("Frame")
fVitals.Size = UDim2.new(1,0,0,180)
fVitals.Position = UDim2.new(0,0,0,238)
fVitals.BackgroundTransparency = 1
fVitals.ZIndex = 7
fVitals.Parent = fContent

local vLayout = Instance.new("UIListLayout")
vLayout.Padding = UDim.new(0,5)
vLayout.Parent = fVitals

local fNum = Instance.new("TextLabel")
fNum.Size = UDim2.new(1,0,0,22)
fNum.Position = UDim2.new(0,0,1,-40)
fNum.BackgroundTransparency = 1
fNum.Text = "File 1 of 3"
fNum.TextColor3 = C.textMut
fNum.TextSize = 14
fNum.Font = Enum.Font.Code
fNum.ZIndex = 7
fNum.Parent = fContent

-- Review button (supports click)
local fHint = Instance.new("TextButton")
fHint.Size = UDim2.new(0,250,0,42)
fHint.Position = UDim2.new(0,0,1,-20)
fHint.BackgroundColor3 = C.accent
fHint.Text = "  Press [E] or Click to Review"
fHint.TextColor3 = C.bg
fHint.TextSize = 14
fHint.Font = Enum.Font.GothamBold
fHint.TextXAlignment = Enum.TextXAlignment.Left
fHint.ZIndex = 8
fHint.AutoButtonColor = false
fHint.Parent = fileCard
mkC(fHint, 8)

--------------------------------------------------------------
-- QUESTION SIDEBAR (bigger, right side)
--------------------------------------------------------------
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0,480,0,520)
sidebar.Position = UDim2.new(1,10,0.5,-260) -- off screen right
sidebar.BackgroundColor3 = C.panelBg
sidebar.Visible = false
sidebar.ZIndex = 5
sidebar.Parent = sg
mkC(sidebar,12); mkS(sidebar,C.accent,2); mkP(sidebar,26)

local qHead = Instance.new("TextLabel")
qHead.Size = UDim2.new(1,0,0,20)
qHead.BackgroundTransparency = 1
qHead.Text = "// QUESTION"
qHead.TextColor3 = C.accent
qHead.TextSize = 14
qHead.Font = Enum.Font.Code
qHead.TextXAlignment = Enum.TextXAlignment.Left
qHead.ZIndex = 6
qHead.Parent = sidebar

local qText = Instance.new("TextLabel")
qText.Size = UDim2.new(1,0,0,85)
qText.Position = UDim2.new(0,0,0,28)
qText.BackgroundTransparency = 1
qText.Text = ""
qText.TextColor3 = C.textPri
qText.TextSize = 17
qText.Font = Enum.Font.GothamMedium
qText.TextXAlignment = Enum.TextXAlignment.Left
qText.TextYAlignment = Enum.TextYAlignment.Top
qText.TextWrapped = true
qText.ZIndex = 6
qText.Parent = sidebar

local chFrame = Instance.new("Frame")
chFrame.Size = UDim2.new(1,0,0,290)
chFrame.Position = UDim2.new(0,0,0,120)
chFrame.BackgroundTransparency = 1
chFrame.ZIndex = 6
chFrame.Parent = sidebar

local chLayout = Instance.new("UIListLayout")
chLayout.Padding = UDim.new(0,12)
chLayout.Parent = chFrame

local chFrames, chStrokes, chLetters, chButtons = {}, {}, {}, {}
for i = 1, 3 do
	local btn = Instance.new("TextButton")
	btn.Name = "Choice"..i
	btn.Size = UDim2.new(1,0,0,85)
	btn.BackgroundColor3 = C.btnDef
	btn.LayoutOrder = i
	btn.ZIndex = 6
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = chFrame
	mkC(btn,10)
	local st = mkS(btn,C.panelBorder,2)
	chStrokes[i] = st

	local let = Instance.new("TextLabel")
	let.Size = UDim2.new(0,38,0,38)
	let.Position = UDim2.new(0,12,0.5,-19)
	let.BackgroundColor3 = C.panelBorder
	let.Text = string.char(64+i)
	let.TextColor3 = C.textPri
	let.TextSize = 16
	let.Font = Enum.Font.GothamBold
	let.ZIndex = 7
	let.Parent = btn
	mkC(let,10)
	chLetters[i] = let

	local ct = Instance.new("TextLabel")
	ct.Name = "T"
	ct.Size = UDim2.new(1,-75,1,-14)
	ct.Position = UDim2.new(0,60,0,7)
	ct.BackgroundTransparency = 1
	ct.Text = ""
	ct.TextColor3 = C.textPri
	ct.TextSize = 15
	ct.Font = Enum.Font.Gotham
	ct.TextXAlignment = Enum.TextXAlignment.Left
	ct.TextWrapped = true
	ct.ZIndex = 7
	ct.Parent = btn

	local ar = Instance.new("TextLabel")
	ar.Name = "A"
	ar.Size = UDim2.new(0,18,1,0)
	ar.Position = UDim2.new(1,-26,0,0)
	ar.BackgroundTransparency = 1
	ar.Text = ""
	ar.TextColor3 = C.accent
	ar.TextSize = 18
	ar.Font = Enum.Font.GothamBold
	ar.ZIndex = 7
	ar.Parent = btn

	chFrames[i] = btn
	chButtons[i] = btn
end

-- Hint text (green)
local sHint = Instance.new("TextLabel")
sHint.Size = UDim2.new(1,0,0,24)
sHint.Position = UDim2.new(0,0,1,-75)
sHint.BackgroundTransparency = 1
sHint.Text = "[W/S] Navigate    [E] or Click to Select"
sHint.TextColor3 = C.accent
sHint.TextSize = 14
sHint.Font = Enum.Font.Code
sHint.ZIndex = 6
sHint.Parent = sidebar

-- SUBMIT button (hidden until answer selected)
local submitBtn = Instance.new("TextButton")
submitBtn.Size = UDim2.new(0,200,0,48)
submitBtn.Position = UDim2.new(0.5,-100,1,-50)
submitBtn.BackgroundColor3 = C.accent
submitBtn.Text = "  SUBMIT"
submitBtn.TextColor3 = C.bg
submitBtn.TextSize = 16
submitBtn.Font = Enum.Font.GothamBold
submitBtn.TextXAlignment = Enum.TextXAlignment.Center
submitBtn.Visible = false
submitBtn.ZIndex = 7
submitBtn.AutoButtonColor = false
submitBtn.Parent = sidebar
mkC(submitBtn, 8)

--------------------------------------------------------------
-- FEEDBACK PANEL
--------------------------------------------------------------
local fbPanel = Instance.new("Frame")
fbPanel.Size = UDim2.new(0,420,0,220)
fbPanel.Position = UDim2.new(1,10,0.5,-110)
fbPanel.BackgroundColor3 = C.panelBg
fbPanel.Visible = false
fbPanel.ZIndex = 8
fbPanel.Parent = sg
mkC(fbPanel,12); mkP(fbPanel,22)

local fbIcon = Instance.new("TextLabel")
fbIcon.Size = UDim2.new(0,36,0,36)
fbIcon.BackgroundTransparency = 1
fbIcon.Text = ""
fbIcon.TextSize = 28
fbIcon.Font = Enum.Font.GothamBold
fbIcon.ZIndex = 9
fbIcon.Parent = fbPanel

local fbTitle = Instance.new("TextLabel")
fbTitle.Size = UDim2.new(1,-50,0,30)
fbTitle.Position = UDim2.new(0,44,0,2)
fbTitle.BackgroundTransparency = 1
fbTitle.Text = ""
fbTitle.TextSize = 18
fbTitle.Font = Enum.Font.GothamBold
fbTitle.TextXAlignment = Enum.TextXAlignment.Left
fbTitle.ZIndex = 9
fbTitle.Parent = fbPanel

local fbText = Instance.new("TextLabel")
fbText.Size = UDim2.new(1,0,0,100)
fbText.Position = UDim2.new(0,0,0,44)
fbText.BackgroundTransparency = 1
fbText.Text = ""
fbText.TextColor3 = C.textSec
fbText.TextSize = 14
fbText.Font = Enum.Font.Gotham
fbText.TextXAlignment = Enum.TextXAlignment.Left
fbText.TextYAlignment = Enum.TextYAlignment.Top
fbText.TextWrapped = true
fbText.ZIndex = 9
fbText.Parent = fbPanel

local fbHint = Instance.new("TextButton")
fbHint.Size = UDim2.new(0,160,0,36)
fbHint.Position = UDim2.new(1,-160,1,-48)
fbHint.BackgroundColor3 = C.accent
fbHint.Text = "  [E] Continue"
fbHint.TextColor3 = C.bg
fbHint.TextSize = 14
fbHint.Font = Enum.Font.GothamBold
fbHint.TextXAlignment = Enum.TextXAlignment.Left
fbHint.ZIndex = 9
fbHint.AutoButtonColor = false
fbHint.Parent = fbPanel
mkC(fbHint,8)

--------------------------------------------------------------
-- SCORE (top right)
--------------------------------------------------------------
local scoreF = Instance.new("Frame")
scoreF.Size = UDim2.new(0,150,0,52)
scoreF.Position = UDim2.new(1,-170,0,20)
scoreF.BackgroundColor3 = C.panelBg
scoreF.BackgroundTransparency = 0.1
scoreF.Visible = false
scoreF.ZIndex = 10
scoreF.Parent = sg
mkC(scoreF,10); mkS(scoreF,C.accent,2)

local scoreLbl = Instance.new("TextLabel")
scoreLbl.Size = UDim2.new(1,0,0.4,0)
scoreLbl.Position = UDim2.new(0,0,0,6)
scoreLbl.BackgroundTransparency = 1
scoreLbl.Text = "SCORE"
scoreLbl.TextColor3 = C.textSec
scoreLbl.TextSize = 10
scoreLbl.Font = Enum.Font.GothamBold
scoreLbl.ZIndex = 11
scoreLbl.Parent = scoreF

local scoreVal = Instance.new("TextLabel")
scoreVal.Size = UDim2.new(1,0,0.55,0)
scoreVal.Position = UDim2.new(0,0,0.4,0)
scoreVal.BackgroundTransparency = 1
scoreVal.Text = "100"
scoreVal.TextColor3 = C.accent
scoreVal.TextSize = 26
scoreVal.Font = Enum.Font.GothamBlack
scoreVal.ZIndex = 11
scoreVal.Parent = scoreF

--------------------------------------------------------------
-- RESULTS
--------------------------------------------------------------
local resScreen = Instance.new("Frame")
resScreen.Name = "ResultsScreen"
resScreen.Size = UDim2.new(1,0,1,0)
resScreen.BackgroundColor3 = C.bg
resScreen.Visible = false
resScreen.ZIndex = 15
resScreen.Parent = sg

local resInner = Instance.new("Frame")
resInner.Size = UDim2.new(0,520,0,420)
resInner.Position = UDim2.new(0.5,-260,0.5,-210)
resInner.BackgroundColor3 = C.panelBg
resInner.ZIndex = 16
resInner.Parent = resScreen
mkC(resInner,16); mkS(resInner,C.accent,2); mkP(resInner,28)

local resLbl = Instance.new("TextLabel")
resLbl.Size = UDim2.new(1,0,0,16); resLbl.BackgroundTransparency = 1
resLbl.Text = "// FILE REVIEW COMPLETE"; resLbl.TextColor3 = C.accent
resLbl.TextSize = 12; resLbl.Font = Enum.Font.Code; resLbl.TextXAlignment = Enum.TextXAlignment.Left
resLbl.ZIndex = 17; resLbl.Parent = resInner

local resTitle = Instance.new("TextLabel")
resTitle.Size = UDim2.new(1,0,0,36); resTitle.Position = UDim2.new(0,0,0,26)
resTitle.BackgroundTransparency = 1; resTitle.Text = "Your Results"
resTitle.TextColor3 = C.textPri; resTitle.TextSize = 28; resTitle.Font = Enum.Font.GothamBlack
resTitle.TextXAlignment = Enum.TextXAlignment.Left; resTitle.ZIndex = 17; resTitle.Parent = resInner

local resCircle = Instance.new("Frame")
resCircle.Size = UDim2.new(0,100,0,100); resCircle.Position = UDim2.new(0.5,-50,0,80)
resCircle.BackgroundColor3 = C.bg; resCircle.ZIndex = 17; resCircle.Parent = resInner
mkC(resCircle,50); local resCircStroke = mkS(resCircle,C.accent,3)

local resScoreV = Instance.new("TextLabel")
resScoreV.Size = UDim2.new(1,0,1,0); resScoreV.BackgroundTransparency = 1
resScoreV.Text = "100"; resScoreV.TextColor3 = C.accent; resScoreV.TextSize = 32
resScoreV.Font = Enum.Font.GothamBlack; resScoreV.ZIndex = 18; resScoreV.Parent = resCircle

local resRating = Instance.new("TextLabel")
resRating.Size = UDim2.new(1,0,0,28); resRating.Position = UDim2.new(0,0,0,195)
resRating.BackgroundTransparency = 1; resRating.Text = ""; resRating.TextColor3 = C.warning
resRating.TextSize = 18; resRating.Font = Enum.Font.GothamBold; resRating.ZIndex = 17
resRating.Parent = resInner

local resMsg = Instance.new("TextLabel")
resMsg.Size = UDim2.new(1,0,0,70); resMsg.Position = UDim2.new(0,0,0,235)
resMsg.BackgroundTransparency = 1; resMsg.Text = ""; resMsg.TextColor3 = C.textSec
resMsg.TextSize = 14; resMsg.Font = Enum.Font.Gotham; resMsg.TextWrapped = true
resMsg.ZIndex = 17; resMsg.Parent = resInner

local resHint = Instance.new("TextButton")
resHint.Size = UDim2.new(0,240,0,44); resHint.Position = UDim2.new(0.5,-120,0,320)
resHint.BackgroundColor3 = C.accent; resHint.Text = "  Press [E] to Complete"
resHint.TextColor3 = C.bg; resHint.TextSize = 15; resHint.Font = Enum.Font.GothamBold
resHint.TextXAlignment = Enum.TextXAlignment.Left; resHint.ZIndex = 17; resHint.AutoButtonColor = false
resHint.Parent = resInner
mkC(resHint,10)

--------------------------------------------------------------
-- CHAIR GLOW
--------------------------------------------------------------
local chHL, chBB, chPC
local function glowChair()
	if not bedModel then 
		print("[NurseUI] glowChair: No bedModel found")
		return 
	end
	
	local ch = bedModel:FindFirstChild("OfficeChair",true)
	if not ch then 
		print("[NurseUI] glowChair: No OfficeChair found in bedModel")
		return 
	end
	
	print("[NurseUI] glowChair: Found chair - " .. ch.Name .. " (IsA: " .. ch.ClassName .. ")")
	
	-- Get a part for the BillboardGui position
	local cp = ch:IsA("Model") and (ch.PrimaryPart or ch:FindFirstChildWhichIsA("BasePart")) or ch
	if not cp then 
		print("[NurseUI] glowChair: Could not find a part for billboard")
		return 
	end

	-- Highlight should be parented to the MODEL (or the part if it's a BasePart)
	-- This will make the entire chair glow green
	chHL = Instance.new("Highlight")
	chHL.FillColor = C.accent
	chHL.FillTransparency = 0.4
	chHL.OutlineColor = C.accent
	chHL.OutlineTransparency = 0
	chHL.DepthMode = Enum.HighlightDepthMode.Occluded -- Show even when occluded
	
	-- Parent to the chair model/part directly
	if ch:IsA("Model") then
		chHL.Adornee = ch
		chHL.Parent = ch
	else
		chHL.Parent = ch
	end
	print("[NurseUI] glowChair: Highlight created and parented to " .. ch.Name)

	chBB = Instance.new("BillboardGui")
	chBB.Size = UDim2.new(0,180,0,50)
	chBB.StudsOffset = Vector3.new(0,4,0)
	chBB.AlwaysOnTop = true
	chBB.MaxDistance = 25
	chBB.Parent = cp

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1,0,0,30)
	bg.BackgroundColor3 = C.accent
	bg.Parent = chBB
	mkC(bg,8)
	
	local tx = Instance.new("TextLabel")
	tx.Size = UDim2.new(1,0,1,0)
	tx.BackgroundTransparency = 1
	tx.Text = "Sit Down [E]"
	tx.TextColor3 = C.bg
	tx.TextSize = 14
	tx.Font = Enum.Font.GothamBold
	tx.Parent = bg
	
	local ar = Instance.new("TextLabel")
	ar.Size = UDim2.new(1,0,0,18)
	ar.Position = UDim2.new(0,0,0,32)
	ar.BackgroundTransparency = 1
	ar.Text = "V"
	ar.TextColor3 = C.accent
	ar.TextSize = 16
	ar.Font = Enum.Font.GothamBold
	ar.Parent = chBB

	-- Pulsing animation for the highlight
	local pt = 0
	chPC = RunService.Heartbeat:Connect(function(dt)
		pt = pt + dt
		if chHL and chHL.Parent then 
			chHL.FillTransparency = 0.2 + 0.3 * math.sin(pt * 4) 
		end
	end)
	
	print("[NurseUI] glowChair: Animation started")
end
local function stopGlow()
	if chHL then chHL:Destroy(); chHL = nil end
	if chBB then chBB:Destroy(); chBB = nil end
	if chPC then chPC:Disconnect(); chPC = nil end
end

--------------------------------------------------------------
-- CINEMATICS
--------------------------------------------------------------
local function hideCharacter()
	local char = player.Character
	if not char then return end
	
	-- Hide all BaseParts (body parts, accessories, etc.)
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 1
		elseif p:IsA("Decal") or p:IsA("Texture") then
			p.Transparency = 1
		end
	end
	
	-- Hide the humanoid's name/health display
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function showCharacter()
	local char = player.Character
	if not char then return end
	
	-- Show all BaseParts
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 0
		elseif p:IsA("Decal") or p:IsA("Texture") then
			p.Transparency = 0
		end
	end
	
	-- Restore humanoid's name/health display
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
end

local function sitDown(cb)
	if not bedModel then if cb then cb() end return end
	local sp = bedModel:FindFirstChild("SitPosition",true)
	local desk = bedModel:FindFirstChild("Desk",true)
	local target
	if sp then target = sp.CFrame
	elseif desk then
		local dp = desk:IsA("Model") and (desk.PrimaryPart or desk:FindFirstChildWhichIsA("BasePart")) or desk
		if dp then target = CFrame.new(dp.Position+Vector3.new(0,3,-2), dp.Position) end
	end
	if not target then if cb then cb() end return end

	camera.CameraType = Enum.CameraType.Scriptable
	local tw = TweenService:Create(camera, TweenInfo.new(2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {CFrame = target})
	tw:Play()
	
	-- Hide the character completely when sitting
	hideCharacter()
	
	tw.Completed:Connect(function() if cb then cb() end end)
end

local function standUp(cb)
	camera.CameraType = Enum.CameraType.Scriptable
	local tw = TweenService:Create(camera, TweenInfo.new(2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		CFrame = camera.CFrame * CFrame.new(0,1.5,-1)
	})
	tw:Play()
	tw.Completed:Connect(function()
		camera.CameraType = Enum.CameraType.Custom
		-- Show the character again when standing up
		showCharacter()
		if cb then cb() end
	end)
end

--------------------------------------------------------------
-- FILE HELPERS
--------------------------------------------------------------
local function populateVitals(vitals)
	for _,c in fVitals:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	if not vitals then return end
	local order = {"heartRate","bloodPressure","temperature","respiration","oxygenSat"}
	local labels = {heartRate="HR",bloodPressure="BP",temperature="Temp",respiration="Resp",oxygenSat="O2"}
	for i,k in order do
		local v = vitals[k]
		if v then
			local r = Instance.new("Frame"); r.Size = UDim2.new(1,0,0,22); r.BackgroundTransparency = 1; r.LayoutOrder = i; r.ZIndex = 8; r.Parent = fVitals
			local l = Instance.new("TextLabel"); l.Size = UDim2.new(0.2,0,1,0); l.BackgroundTransparency = 1; l.Text = labels[k]; l.TextColor3 = C.textMut; l.TextSize = 12; l.Font = Enum.Font.Code; l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 8; l.Parent = r
			local vl = Instance.new("TextLabel"); vl.Size = UDim2.new(0.8,0,1,0); vl.Position = UDim2.new(0.2,0,0,0); vl.BackgroundTransparency = 1; vl.Text = v; vl.TextColor3 = C.fileText; vl.TextSize = 12; vl.Font = Enum.Font.Gotham; vl.TextXAlignment = Enum.TextXAlignment.Left; vl.TextWrapped = true; vl.ZIndex = 8; vl.Parent = r
			if string.find(v:lower(),"elevated") or string.find(v:lower(),"high") or string.find(v:lower(),"low") then vl.TextColor3 = Color3.fromRGB(180,100,30) end
		end
	end
end

local function showFile(data)
	fTabTxt.Text = "PATIENT FILE #" .. (data.fileIndex or 1)
	fName.Text = data.patientName or "Patient"
	fBrief.Text = data.briefing or ""
	fNum.Text = "File " .. (data.fileIndex or 1) .. " of " .. (data.totalFiles or 3)
	populateVitals(data.vitals)

	-- Start CENTERED (not left)
	fileIsLeft = false
	fileCard.Position = UDim2.new(0.5,-260,1,50)
	fileCard.Visible = true
	
	-- Play whoosh sound for file appearing
	playSound("whooshIn")
	
	TweenService:Create(fileCard, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5,-260,0.5,-300) -- centered
	}):Play()

	-- Hide guidance when file shows
	guideFrame.Visible = false

	blur.Visible = true
	TweenService:Create(blur, TweenInfo.new(0.5), {BackgroundTransparency = 0.4}):Play()

	navHint.Text = "  [E] or Click to Review"
	navHint.Visible = true
	panel = "FILE"
	inputOn = true
end

local function slideFileLeft()
	if fileIsLeft then return end
	fileIsLeft = true
	
	-- Play paper slide sound (stop after 1 second)
	playSound("paperSlide")
	task.delay(1, function()
		stopSound("paperSlide")
	end)
	
	-- Less extreme slide - more to center (0.15 instead of 0.08)
	TweenService:Create(fileCard, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.15,0,0.5,-300)
	}):Play()
end

local function hideFile(cb)
	-- Play whoosh out sound
	playSound("whooshOut")
	
	TweenService:Create(fileCard, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5,-260,1,50)
	}):Play()
	task.delay(0.6, function() 
		fileCard.Visible = false
		fileIsLeft = false
		if cb then cb() end 
	end)
end

local function showSidebar(taskData)
	-- Slide file left first
	slideFileLeft()
	task.wait(0.5) -- Match the tween duration
	
	qHead.Text = "// QUESTION"
	qText.Text = taskData.prompt
	choiceCnt = 0
	for i = 1, 3 do
		local ch = taskData.choices[i]
		if ch then 
			chFrames[i].Visible = true
			chFrames[i]:FindFirstChild("T").Text = ch.text
			choiceCnt = choiceCnt+1
		else 
			chFrames[i].Visible = false 
		end
	end
	
	-- NO auto-selection
	selIdx = 0
	submitBtn.Visible = false
	updateVisuals()
	
	sidebar.Position = UDim2.new(1,10,0.5,-260)
	sidebar.Visible = true
	TweenService:Create(sidebar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0.50,0,0.5,-260)}):Play()
	navHint.Text = "  [W/S] Navigate    [E] or Click to Select"
	panel = "QUESTION"
	inputOn = true
end

local function hideSidebar(cb)
	TweenService:Create(sidebar, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = UDim2.new(1,10,0.5,-260)}):Play()
	task.delay(0.4, function() sidebar.Visible = false; if cb then cb() end end)
end

--------------------------------------------------------------
-- CHOICE VISUALS (with hover support)
--------------------------------------------------------------
local hoveredIdx = 0

function updateVisuals()
	for i = 1, choiceCnt do
		local f = chFrames[i]; local st = chStrokes[i]; local let = chLetters[i]; local ar = f:FindFirstChild("A")
		if i == selIdx then
			-- Selected
			f.BackgroundColor3 = C.btnSel; st.Color = C.accent; st.Thickness = 2
			let.BackgroundColor3 = C.accent; let.TextColor3 = C.bg
			if ar then ar.Text = ">" end
		elseif i == hoveredIdx then
			-- Hovered but not selected
			f.BackgroundColor3 = C.btnHover; st.Color = C.textMut; st.Thickness = 1
			let.BackgroundColor3 = C.textMut; let.TextColor3 = C.textPri
			if ar then ar.Text = "" end
		else
			-- Default
			f.BackgroundColor3 = C.btnDef; st.Color = C.panelBorder; st.Thickness = 1
			let.BackgroundColor3 = C.panelBorder; let.TextColor3 = C.textPri
			if ar then ar.Text = "" end
		end
	end
	
	-- Show/hide submit button
	submitBtn.Visible = (selIdx > 0)
end

-- Hover effects for choices
for i, btn in chButtons do
	btn.MouseEnter:Connect(function()
		if panel == "QUESTION" then
			hoveredIdx = i
			updateVisuals()
		end
	end)
	btn.MouseLeave:Connect(function()
		if panel == "QUESTION" and hoveredIdx == i then
			hoveredIdx = 0
			updateVisuals()
		end
	end)
	btn.MouseButton1Click:Connect(function()
		if panel == "QUESTION" and inputOn then
			selIdx = i
			updateVisuals()
		end
	end)
end

--------------------------------------------------------------
-- TUTORIAL OVERLAY (DOUBLE SIZE, white text)
--------------------------------------------------------------
local tutOv1 = Instance.new("Frame")
tutOv1.Size = UDim2.new(1,0,1,0)
tutOv1.BackgroundColor3 = Color3.new(0,0,0)
tutOv1.BackgroundTransparency = 0.4
tutOv1.Visible = false; tutOv1.ZIndex = 20; tutOv1.Parent = sg

local tutPnl1 = Instance.new("Frame")
tutPnl1.Size = UDim2.new(0,800,0,480)
tutPnl1.Position = UDim2.new(0.5,-400,0.5,-240)
tutPnl1.BackgroundColor3 = C.panelBg; tutPnl1.ZIndex = 21; tutPnl1.Parent = tutOv1
mkC(tutPnl1, 18); mkS(tutPnl1, C.accent, 3)

local tutTtl1 = Instance.new("TextLabel")
tutTtl1.Size = UDim2.new(1,0,0,55); tutTtl1.Position = UDim2.new(0,0,0,35)
tutTtl1.BackgroundTransparency = 1; tutTtl1.Text = "PATIENT FILE REVIEW"
tutTtl1.TextColor3 = C.accent; tutTtl1.TextSize = 36; tutTtl1.Font = Enum.Font.GothamBlack
tutTtl1.ZIndex = 22; tutTtl1.Parent = tutPnl1

local tutBod1 = Instance.new("TextLabel")
tutBod1.Size = UDim2.new(1,-80,0,200); tutBod1.Position = UDim2.new(0,40,0,100)
tutBod1.BackgroundTransparency = 1
tutBod1.Text = "You're in the nurse's office. There are 3 patient files on the desk that need your clinical review.\n\nSit down at the desk, read each file carefully, and answer the clinical question for each patient.\n\nWalk to the glowing chair and press [E] to sit down."
tutBod1.TextColor3 = C.textPri; tutBod1.TextSize = 22; tutBod1.Font = Enum.Font.Gotham
tutBod1.TextWrapped = true; tutBod1.TextXAlignment = Enum.TextXAlignment.Left
tutBod1.TextYAlignment = Enum.TextYAlignment.Top; tutBod1.ZIndex = 22; tutBod1.Parent = tutPnl1

local tutCtrl1 = Instance.new("TextLabel")
tutCtrl1.Size = UDim2.new(1,-80,0,30); tutCtrl1.Position = UDim2.new(0,40,0,320)
tutCtrl1.BackgroundTransparency = 1; tutCtrl1.Text = "[W/S] Navigate choices    [E] Select / Confirm"
tutCtrl1.TextColor3 = C.accent; tutCtrl1.TextSize = 20; tutCtrl1.Font = Enum.Font.Code
tutCtrl1.ZIndex = 22; tutCtrl1.Parent = tutPnl1

local tutHnt1 = Instance.new("TextButton")
tutHnt1.Size = UDim2.new(0,280,0,60); tutHnt1.Position = UDim2.new(0.5,-140,1,-90)
tutHnt1.BackgroundColor3 = C.accent; tutHnt1.Text = "  Press [E] to Begin"
tutHnt1.TextColor3 = C.bg; tutHnt1.TextSize = 22; tutHnt1.Font = Enum.Font.GothamBold
tutHnt1.TextXAlignment = Enum.TextXAlignment.Left; tutHnt1.ZIndex = 22; tutHnt1.AutoButtonColor = false
tutHnt1.Parent = tutPnl1
mkC(tutHnt1, 10)

--------------------------------------------------------------
-- MOUSE CLICK HANDLERS
--------------------------------------------------------------
fHint.MouseButton1Click:Connect(function()
	if panel == "FILE" and inputOn then
		inputOn = false; panel = "NONE"
		ChoiceMadeEvent:FireServer("READY_FOR_QUESTION")
	end
end)

submitBtn.MouseButton1Click:Connect(function()
	if panel == "QUESTION" and inputOn and selIdx > 0 then
		inputOn = false; hideSidebar(); panel = "NONE"
		ChoiceMadeEvent:FireServer("CHOICE", selIdx)
	end
end)

fbHint.MouseButton1Click:Connect(function()
	if panel == "FEEDBACK" and inputOn then
		inputOn = false; fbPanel.Visible = false
		hideFile(function()
			panel = "NONE"
			ChoiceMadeEvent:FireServer("CONTINUE")
		end)
	end
end)

resHint.MouseButton1Click:Connect(function()
	if panel == "RESULTS" and inputOn then
		inputOn = false; resScreen.Visible = false; panel = "NONE"
		ChoiceMadeEvent:FireServer("COMPLETE")
	end
end)

tutHnt1.MouseButton1Click:Connect(function()
	if panel == "TUTORIAL" then
		tutOv1.Visible = false
		guideFrame.Visible = false
		glowChair()
		panel = "CHAIR"
		inputOn = true
	end
end)

--------------------------------------------------------------
-- KEYBOARD
--------------------------------------------------------------
UserInputService.InputBegan:Connect(function(inp, gp)
	if gp or not inputOn then return end
	local k = inp.KeyCode

	if panel == "TUTORIAL" and (k == Enum.KeyCode.E or k == Enum.KeyCode.Return) then
		tutOv1.Visible = false
		guideFrame.Visible = false
		glowChair()
		panel = "CHAIR"
		inputOn = true

	elseif panel == "CHAIR" and (k == Enum.KeyCode.E or k == Enum.KeyCode.Return) then
		local char = player.Character
		if not char or not bedModel then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local ch = bedModel:FindFirstChild("OfficeChair",true)
		if not ch then return end
		local cp = ch:IsA("Model") and (ch.PrimaryPart or ch:FindFirstChildWhichIsA("BasePart")) or ch
		if not cp then return end
		if (root.Position - cp.Position).Magnitude > 12 then return end

		inputOn = false; stopGlow(); panel = "SITTING"
		sitDown(function()
			isSeated = true
			ChoiceMadeEvent:FireServer("BEGIN")
		end)

	elseif panel == "FILE" and (k == Enum.KeyCode.E or k == Enum.KeyCode.Return) then
		inputOn = false; panel = "NONE"
		ChoiceMadeEvent:FireServer("READY_FOR_QUESTION")

	elseif panel == "QUESTION" then
		if k == Enum.KeyCode.W or k == Enum.KeyCode.Up then
			-- W: move up, but if nothing selected, do nothing
			if selIdx > 1 then
				selIdx = selIdx - 1
				updateVisuals()
			end
		elseif k == Enum.KeyCode.S or k == Enum.KeyCode.Down then
			-- S: move down, if nothing selected start at 1
			if selIdx == 0 then
				selIdx = 1
			elseif selIdx < choiceCnt then
				selIdx = selIdx + 1
			end
			updateVisuals()
		elseif k == Enum.KeyCode.E or k == Enum.KeyCode.Return then
			-- E: submit if something is selected
			if selIdx > 0 then
				inputOn = false; hideSidebar(); panel = "NONE"
				ChoiceMadeEvent:FireServer("CHOICE", selIdx)
			end
		end

	elseif panel == "FEEDBACK" and (k == Enum.KeyCode.E or k == Enum.KeyCode.Return) then
		inputOn = false; fbPanel.Visible = false
		hideFile(function()
			panel = "NONE"
			ChoiceMadeEvent:FireServer("CONTINUE")
		end)

	elseif panel == "RESULTS" and (k == Enum.KeyCode.E or k == Enum.KeyCode.Return) then
		inputOn = false; resScreen.Visible = false; panel = "NONE"
		ChoiceMadeEvent:FireServer("COMPLETE")
	end
end)

--------------------------------------------------------------
-- SHOW GUIDANCE WHEN PLAYER IS TELEPORTED TO HOSPITAL
--------------------------------------------------------------
-- Wait for NurseWorldActive flag (set by PlaySequence when player is teleported)
task.spawn(function()
	local nurseActive = ReplicatedStorage:FindFirstChild("NurseWorldActive")
	
	-- Wait for the flag to exist
	while not nurseActive do
		task.wait(0.2)
		nurseActive = ReplicatedStorage:FindFirstChild("NurseWorldActive")
	end
	
	-- Wait for the flag to be true (player has been teleported)
	while not nurseActive.Value do
		task.wait(0.2)
	end
	
	-- Now show the guidance text
	guideFrame.Visible = true
	print("[NurseUI] Player teleported to hospital - showing guidance text")
end)

--------------------------------------------------------------
-- EVENTS
--------------------------------------------------------------
StartScenarioEvent.OnClientEvent:Connect(function(data, idx, total)
	local nw = workspace:FindFirstChild("NurseWorld")
	local beds = nw and nw:FindFirstChild("PatientBeds")
	bedModel = beds and beds:FindFirstChild("PatientBed_01")

	if data.isFile then
		showFile(data)
	else
		-- Tutorial popup appears - HIDE guidance text now
		guideFrame.Visible = false
		print("[NurseUI] Guidance hidden - tutorial popup showing")
		scoreF.Visible = true
		scoreVal.Text = "100"
		tutOv1.Visible = true
		panel = "TUTORIAL"
		inputOn = true
		
		-- Start background music
		playSound("bgMusicMedical")
	end
end)

ShowTaskEvent.OnClientEvent:Connect(function(taskIdx, totalTasks, taskData)
	showSidebar(taskData)
end)

ShowFeedbackEvent.OnClientEvent:Connect(function(wasCorrect, feedbackStr, deduction)
	for _,c in fbPanel:GetChildren() do if c:IsA("UIStroke") then c:Destroy() end end
	if wasCorrect then
		-- Play correct answer sound
		playSound("correctAnswer")
		fbIcon.Text = "O"; fbIcon.TextColor3 = C.correct
		fbTitle.Text = "Correct!"; fbTitle.TextColor3 = C.correct
		mkS(fbPanel, C.correct, 2)
	else
		-- Play wrong answer sound
		playSound("wrongAnswer")
		fbIcon.Text = "X"; fbIcon.TextColor3 = C.wrong
		fbTitle.Text = "Incorrect (-"..deduction.." pts)"; fbTitle.TextColor3 = C.wrong
		mkS(fbPanel, C.wrong, 2)
	end
	fbText.Text = feedbackStr
	sidebar.Visible = false
	fbPanel.Position = UDim2.new(1,10,0.5,-110)
	fbPanel.Visible = true
	
	-- Play whoosh for feedback panel
	playSound("whooshIn", 1.1)
	
	TweenService:Create(fbPanel, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Position = UDim2.new(0.52,0,0.5,-110)}):Play()
	navHint.Text = "  [E] or Click to Continue"
	panel = "FEEDBACK"; inputOn = true
end)

UpdateScoreEvent.OnClientEvent:Connect(function(s)
	scoreVal.Text = tostring(s)
	if s >= 67 then scoreVal.TextColor3 = C.correct
	elseif s >= 34 then scoreVal.TextColor3 = C.warning
	else scoreVal.TextColor3 = C.wrong end
end)

ShowResultsEvent.OnClientEvent:Connect(function(summary)
	fileCard.Visible = false; sidebar.Visible = false; fbPanel.Visible = false
	blur.Visible = false; scoreF.Visible = false; navHint.Visible = false
	
	-- Fade out background music
	fadeOutSound("bgMusicMedical", 1.5)

	-- Bridge Nurse completion to PlaySequence (the client-side world orchestrator).
	-- NurseWorldManager fires a WorldCompleted BindableEvent on the server, but
	-- BindableEvents don't cross the server/client boundary, so PlaySequence
	-- (client) never receives the server's fire and would stay stuck waiting.
	-- Fire the client-side event here so it advances to the next world.
	local worldCompleted = ReplicatedStorage:FindFirstChild("WorldCompleted")
	if not worldCompleted then
		worldCompleted = Instance.new("BindableEvent")
		worldCompleted.Name = "WorldCompleted"
		worldCompleted.Parent = ReplicatedStorage
	end
	worldCompleted:Fire(player, "NurseWorld", summary)

	standUp(function()
		resScoreV.Text = tostring(summary.finalScore)
		if summary.finalScore >= 67 then resCircStroke.Color = C.correct; resScoreV.TextColor3 = C.correct
		elseif summary.finalScore >= 34 then resCircStroke.Color = C.warning; resScoreV.TextColor3 = C.warning
		else resCircStroke.Color = C.wrong; resScoreV.TextColor3 = C.wrong end
		local stars = string.rep("*",summary.stars)..string.rep("-",3-summary.stars)
		resRating.Text = stars.."  "..summary.rating
		resMsg.Text = summary.message
		resScreen.Visible = true; panel = "RESULTS"; inputOn = true
		navHint.Text = "  [E] or Click to Complete"; navHint.Visible = true
	end)
end)

ScenarioCompleteEvent.OnClientEvent:Connect(function(completedRoom)
	fileCard.Visible = false; sidebar.Visible = false; fbPanel.Visible = false
	blur.Visible = false; scoreF.Visible = false; navHint.Visible = false
	guideFrame.Visible = false
	
	-- Determine which guidance text to show based on which room just completed
	local function showNextRoomGuidance()
		if completedRoom == 1 then
			-- Room 1 (Office) completed - show guidance for Medication Room
			task.delay(1, function()
				guideText.Text = "Go to Medication Room (look at the label above the door)"
				guideFrame.Visible = true
			end)
		elseif completedRoom == 2 then
			-- Room 2 (Medication) completed - show guidance for ICU
			-- Note: Room2CompleteEvent also handles this, but we set it here for consistency
			task.delay(1, function()
				guideText.Text = "Go to ICU (look at the label above the door)"
				guideFrame.Visible = true
			end)
		end
		-- Room 3 completed = all done, don't show any navigation guidance
	end
	
	if isSeated then
		standUp(function() 
			isSeated = false
			showNextRoomGuidance()
		end)
	else
		showNextRoomGuidance()
	end
end)

-- Hide guidance when Room 2 starts
local Room2StartEvent = remotes:WaitForChild("Room2Start")
Room2StartEvent.OnClientEvent:Connect(function()
	guideFrame.Visible = false
end)

-- Listen for Room 2 complete to show guidance for ICU
local Room2CompleteEvent = remotes:WaitForChild("Room2Complete")
Room2CompleteEvent.OnClientEvent:Connect(function()
	task.delay(1, function()
		guideText.Text = "Go to ICU (look at the label above the door)"
		guideFrame.Visible = true
	end)
end)

-- Hide guidance when Room 3 starts
local Room3StartEvent = remotes:WaitForChild("Room3Start")
Room3StartEvent.OnClientEvent:Connect(function()
	guideFrame.Visible = false
end)

--------------------------------------------------------------
-- TEARDOWN (NurseWorld ended — normal completion OR skip)
-- Restores camera/character and destroys the UI so nothing lingers
-- into the next world.
--------------------------------------------------------------
local nurseUITornDown = false
local function teardownNurseUI()
	if nurseUITornDown then return end
	nurseUITornDown = true
	print("[NurseUI] Tearing down NurseWorld UI")

	inputOn = false
	pcall(stopGlow)

	-- Stop all sounds we created
	for _, s in pairs(sounds) do
		if s then pcall(function() s:Stop() end) end
	end

	-- Restore camera + character to normal
	pcall(function()
		camera.CameraType = Enum.CameraType.Custom
	end)
	pcall(showCharacter)

	-- Destroy the UI
	pcall(function() sg:Destroy() end)
end

task.spawn(function()
	local nurseActive = ReplicatedStorage:FindFirstChild("NurseWorldActive")
	while not nurseActive do
		task.wait(0.2)
		nurseActive = ReplicatedStorage:FindFirstChild("NurseWorldActive")
	end
	-- Only tear down once it has gone false AFTER having been active
	while not nurseActive.Value do task.wait(0.2) end
	nurseActive:GetPropertyChangedSignal("Value"):Connect(function()
		if not nurseActive.Value then
			teardownNurseUI()
		end
	end)
end)

task.spawn(function()
	local stopRemote = remotes:FindFirstChild("StopNurseWorld") or remotes:WaitForChild("StopNurseWorld", 10)
	if stopRemote then
		stopRemote.OnClientEvent:Connect(teardownNurseUI)
	end
end)

print("[NurseUI] Office file review UI v5 initialized — keyboard + mouse driven.")
return {}
