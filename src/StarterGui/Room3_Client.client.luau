--[[
	Room3_Client.luau (v3 — CINEMATIC + TIMERS)
	LocalScript: StarterGui/Room3_Client
	
	Room 3 — Code Blue Emergency
	
	FEATURES:
	- Vitals on BillboardGui on HeartMonitor
	- Physical Code Blue button (glows, press E)
	- CPR rhythm with SPACEBAR
	- Defib with E key
	- TIMERS on urgent phases
	- CINEMATIC DEATH: Camera locks on patient, spirit rises 5-6s, then fail screen
	- Higher camera viewpoint
	- All keyboard driven
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

--------------------------------------------------------------
-- WAIT FOR NURSEWORLD ACTIVATION
--------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("NurseWorldRemotes")
if not remotes then
	print("[Room3_Client] Waiting for NurseWorld to activate...")
	while not ReplicatedStorage:FindFirstChild("NurseWorldRemotes") do
		task.wait(0.5)
	end
	remotes = ReplicatedStorage:FindFirstChild("NurseWorldRemotes")
end
print("[Room3_Client] NurseWorld active - initializing")
local Room3StartEvent = remotes:WaitForChild("Room3Start")
local Room3ActionEvent = remotes:WaitForChild("Room3Action")
local Room3CompleteEvent = remotes:WaitForChild("Room3Complete")

--------------------------------------------------------------
-- COLORS
--------------------------------------------------------------
local C = {
	bg = Color3.fromRGB(22, 27, 34),
	panelBg = Color3.fromRGB(30, 36, 46),
	accent = Color3.fromRGB(134, 239, 172),
	correct = Color3.fromRGB(74, 222, 128),
	wrong = Color3.fromRGB(248, 113, 113),
	emergency = Color3.fromRGB(220, 38, 38),
	hGreen = Color3.fromRGB(74, 222, 128),
	hYellow = Color3.fromRGB(251, 191, 36),
	hRed = Color3.fromRGB(248, 113, 113),
	flatline = Color3.fromRGB(248, 113, 113),
	textPri = Color3.fromRGB(255, 255, 255),
	textSec = Color3.fromRGB(156, 163, 175),
	textMut = Color3.fromRGB(107, 114, 128),
	cprPerf = Color3.fromRGB(74, 222, 128),
	cprGood = Color3.fromRGB(251, 191, 36),
	cprMiss = Color3.fromRGB(248, 113, 113),
	deathBg = Color3.fromRGB(5, 5, 8),
}

--------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------
local function mkCorner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c end
local function mkStroke(p, col, t) local s = Instance.new("UIStroke"); s.Color = col or C.accent; s.Thickness = t or 1; s.Parent = p; return s end

--------------------------------------------------------------
-- SCREEN GUI
--------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Room3UI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Enabled = false
screenGui.Parent = playerGui

--------------------------------------------------------------
-- INSTRUCTION BAR (top center)
--------------------------------------------------------------
local instrBar = Instance.new("Frame")
instrBar.Size = UDim2.new(0, 620, 0, 56)
instrBar.Position = UDim2.new(0.5, -310, 0, 20)
instrBar.BackgroundColor3 = C.panelBg
instrBar.BackgroundTransparency = 0.1
instrBar.Visible = false
instrBar.Parent = screenGui
mkCorner(instrBar, 10)
local instrStroke = mkStroke(instrBar, C.accent, 1)

local phaseLabel = Instance.new("TextLabel")
phaseLabel.Size = UDim2.new(0.7, -10, 0, 16)
phaseLabel.Position = UDim2.new(0, 12, 0, 6)
phaseLabel.BackgroundTransparency = 1
phaseLabel.Text = "// MONITORING"
phaseLabel.TextColor3 = C.accent
phaseLabel.TextSize = 11
phaseLabel.Font = Enum.Font.Code
phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
phaseLabel.Parent = instrBar

local instrText = Instance.new("TextLabel")
instrText.Size = UDim2.new(0.7, -10, 0, 24)
instrText.Position = UDim2.new(0, 12, 0, 26)
instrText.BackgroundTransparency = 1
instrText.Text = ""
instrText.TextColor3 = C.textPri
instrText.TextSize = 15
instrText.Font = Enum.Font.GothamMedium
instrText.TextXAlignment = Enum.TextXAlignment.Left
instrText.Parent = instrBar

--------------------------------------------------------------
-- TIMER DISPLAY (right side of instruction bar)
--------------------------------------------------------------
local timerFrame = Instance.new("Frame")
timerFrame.Size = UDim2.new(0, 80, 0, 44)
timerFrame.Position = UDim2.new(1, -92, 0, 6)
timerFrame.BackgroundColor3 = C.bg
timerFrame.Visible = false
timerFrame.Parent = instrBar
mkCorner(timerFrame, 8)

local timerValue = Instance.new("TextLabel")
timerValue.Size = UDim2.new(1, 0, 0.65, 0)
timerValue.BackgroundTransparency = 1
timerValue.Text = "8"
timerValue.TextColor3 = C.textPri
timerValue.TextSize = 24
timerValue.Font = Enum.Font.GothamBlack
timerValue.Parent = timerFrame

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, 0, 0.3, 0)
timerLabel.Position = UDim2.new(0, 0, 0.65, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "SEC"
timerLabel.TextColor3 = C.textMut
timerLabel.TextSize = 9
timerLabel.Font = Enum.Font.Code
timerLabel.Parent = timerFrame

--------------------------------------------------------------
-- CPR UI
--------------------------------------------------------------
local cprFrame = Instance.new("Frame")
cprFrame.Size = UDim2.new(0, 400, 0, 330)
cprFrame.Position = UDim2.new(0.5, -200, 0.5, -165)
cprFrame.BackgroundColor3 = C.panelBg
cprFrame.BackgroundTransparency = 0.05
cprFrame.Visible = false
cprFrame.Parent = screenGui
mkCorner(cprFrame, 12)
mkStroke(cprFrame, C.emergency, 2)

local cprTitle = Instance.new("TextLabel")
cprTitle.Size = UDim2.new(1, 0, 0, 28)
cprTitle.Position = UDim2.new(0, 0, 0, 10)
cprTitle.BackgroundTransparency = 1
cprTitle.Text = "PERFORM CPR"
cprTitle.TextColor3 = C.emergency
cprTitle.TextSize = 18
cprTitle.Font = Enum.Font.GothamBlack
cprTitle.Parent = cprFrame

local cprSub = Instance.new("TextLabel")
cprSub.Size = UDim2.new(1, 0, 0, 18)
cprSub.Position = UDim2.new(0, 0, 0, 36)
cprSub.BackgroundTransparency = 1
cprSub.Text = "LEFT CLICK when the circle hits the ring"
cprSub.TextColor3 = C.textPri
cprSub.TextSize = 12
cprSub.Font = Enum.Font.Gotham
cprSub.Parent = cprFrame

-- Rhythm container
local rhythmCont = Instance.new("Frame")
rhythmCont.Size = UDim2.new(0, 180, 0, 180)
rhythmCont.Position = UDim2.new(0.5, -90, 0, 60)
rhythmCont.BackgroundTransparency = 1
rhythmCont.Parent = cprFrame

local targetRing = Instance.new("Frame")
targetRing.Size = UDim2.new(0, 110, 0, 110)
targetRing.Position = UDim2.new(0.5, -55, 0.5, -55)
targetRing.BackgroundTransparency = 1
targetRing.Parent = rhythmCont
local targetStroke = mkStroke(targetRing, C.accent, 3)
mkCorner(targetRing, 999)

local pulseCircle = Instance.new("Frame")
pulseCircle.Size = UDim2.new(0, 170, 0, 170)
pulseCircle.Position = UDim2.new(0.5, -85, 0.5, -85)
pulseCircle.BackgroundTransparency = 1
pulseCircle.Parent = rhythmCont
local pulseStroke = mkStroke(pulseCircle, C.textPri, 3)
mkCorner(pulseCircle, 999)

local hitFb = Instance.new("TextLabel")
hitFb.Size = UDim2.new(1, 0, 0, 28)
hitFb.Position = UDim2.new(0, 0, 0, 250)
hitFb.BackgroundTransparency = 1
hitFb.Text = ""
hitFb.TextSize = 22
hitFb.Font = Enum.Font.GothamBold
hitFb.Parent = cprFrame

local compCount = Instance.new("TextLabel")
compCount.Size = UDim2.new(1, 0, 0, 18)
compCount.Position = UDim2.new(0, 0, 0, 278)
compCount.BackgroundTransparency = 1
compCount.Text = "0 / 15"
compCount.TextColor3 = C.textSec
compCount.TextSize = 13
compCount.Font = Enum.Font.GothamMedium
compCount.Parent = cprFrame

local cprProgBg = Instance.new("Frame")
cprProgBg.Size = UDim2.new(0.8, 0, 0, 6)
cprProgBg.Position = UDim2.new(0.1, 0, 0, 302)
cprProgBg.BackgroundColor3 = C.bg
cprProgBg.Parent = cprFrame
mkCorner(cprProgBg, 999)

local cprProgFill = Instance.new("Frame")
cprProgFill.Size = UDim2.new(0, 0, 1, 0)
cprProgFill.BackgroundColor3 = C.accent
cprProgFill.Parent = cprProgBg
mkCorner(cprProgFill, 999)

--------------------------------------------------------------
-- DEFIBRILLATOR UI
--------------------------------------------------------------
local defibFrame = Instance.new("Frame")
defibFrame.Size = UDim2.new(0, 450, 0, 200)
defibFrame.Position = UDim2.new(0.5, -225, 0.5, -100)
defibFrame.BackgroundColor3 = C.panelBg
defibFrame.Visible = false
defibFrame.Parent = screenGui
mkCorner(defibFrame, 12)
mkStroke(defibFrame, C.emergency, 2)

local defibTitle = Instance.new("TextLabel")
defibTitle.Size = UDim2.new(1, 0, 0, 30)
defibTitle.Position = UDim2.new(0, 0, 0, 10)
defibTitle.BackgroundTransparency = 1
defibTitle.Text = "DEFIBRILLATOR"
defibTitle.TextColor3 = C.emergency
defibTitle.TextSize = 20
defibTitle.Font = Enum.Font.GothamBlack
defibTitle.Parent = defibFrame

local defibInstr = Instance.new("TextLabel")
defibInstr.Size = UDim2.new(1, -20, 0, 22)
defibInstr.Position = UDim2.new(0, 10, 0, 42)
defibInstr.BackgroundTransparency = 1
defibInstr.Text = ""
defibInstr.TextColor3 = C.textSec
defibInstr.TextSize = 14
defibInstr.Font = Enum.Font.GothamMedium
defibInstr.Parent = defibFrame

local shockBarBg = Instance.new("Frame")
shockBarBg.Size = UDim2.new(0.85, 0, 0, 30)
shockBarBg.Position = UDim2.new(0.075, 0, 0, 78)
shockBarBg.BackgroundColor3 = C.bg
shockBarBg.Visible = false
shockBarBg.Parent = defibFrame
mkCorner(shockBarBg, 4)

local greenZone = Instance.new("Frame")
greenZone.Size = UDim2.new(0.3, 0, 1, 0)
greenZone.Position = UDim2.new(0.35, 0, 0, 0)
greenZone.BackgroundColor3 = C.correct
greenZone.BackgroundTransparency = 0.5
greenZone.Parent = shockBarBg
mkCorner(greenZone, 2)

local shockInd = Instance.new("Frame")
shockInd.Size = UDim2.new(0, 6, 1, 4)
shockInd.Position = UDim2.new(0, 0, 0, -2)
shockInd.BackgroundColor3 = C.textPri
shockInd.Parent = shockBarBg
mkCorner(shockInd, 2)

local defibStatus = Instance.new("TextLabel")
defibStatus.Size = UDim2.new(1, -20, 0, 28)
defibStatus.Position = UDim2.new(0, 10, 0, 118)
defibStatus.BackgroundTransparency = 1
defibStatus.Text = ""
defibStatus.TextColor3 = C.textSec
defibStatus.TextSize = 14
defibStatus.Font = Enum.Font.GothamBold
defibStatus.Parent = defibFrame

local defibHint = Instance.new("TextLabel")
defibHint.Size = UDim2.new(1, 0, 0, 24)
defibHint.Position = UDim2.new(0, 0, 1, -30)
defibHint.BackgroundTransparency = 1
defibHint.Text = "[E]"
defibHint.TextColor3 = C.textMut
defibHint.TextSize = 12
defibHint.Font = Enum.Font.Code
defibHint.Parent = defibFrame

--------------------------------------------------------------
-- OUTCOME OVERLAY
--------------------------------------------------------------
local outcomeOv = Instance.new("Frame")
outcomeOv.Size = UDim2.new(1, 0, 1, 0)
outcomeOv.BackgroundColor3 = C.bg
outcomeOv.BackgroundTransparency = 1
outcomeOv.Visible = false
outcomeOv.ZIndex = 10
outcomeOv.Parent = screenGui

local outcTitle = Instance.new("TextLabel")
outcTitle.Size = UDim2.new(1, 0, 0, 60)
outcTitle.Position = UDim2.new(0, 0, 0.35, 0)
outcTitle.BackgroundTransparency = 1
outcTitle.Text = ""
outcTitle.TextSize = 40
outcTitle.Font = Enum.Font.GothamBlack
outcTitle.ZIndex = 11
outcTitle.Parent = outcomeOv

local outcMsg = Instance.new("TextLabel")
outcMsg.Size = UDim2.new(0.6, 0, 0, 80)
outcMsg.Position = UDim2.new(0.2, 0, 0.35, 70)
outcMsg.BackgroundTransparency = 1
outcMsg.Text = ""
outcMsg.TextColor3 = C.textSec
outcMsg.TextSize = 16
outcMsg.Font = Enum.Font.Gotham
outcMsg.TextWrapped = true
outcMsg.ZIndex = 11
outcMsg.Parent = outcomeOv

local outcScore = Instance.new("TextLabel")
outcScore.Size = UDim2.new(1, 0, 0, 36)
outcScore.Position = UDim2.new(0, 0, 0.35, 160)
outcScore.BackgroundTransparency = 1
outcScore.Text = ""
outcScore.TextSize = 24
outcScore.Font = Enum.Font.GothamBold
outcScore.ZIndex = 11
outcScore.Parent = outcomeOv

local outcHint = Instance.new("TextLabel")
outcHint.Size = UDim2.new(0, 220, 0, 40)
outcHint.Position = UDim2.new(0.5, -110, 0.35, 210)
outcHint.BackgroundColor3 = C.accent
outcHint.Text = "  Press [E] to Continue"
outcHint.TextColor3 = C.bg
outcHint.TextSize = 14
outcHint.Font = Enum.Font.GothamBold
outcHint.TextXAlignment = Enum.TextXAlignment.Left
outcHint.ZIndex = 11
outcHint.Parent = outcomeOv
mkCorner(outcHint, 8)

--------------------------------------------------------------
-- STATE
--------------------------------------------------------------
local phase = "IDLE"
local totalScore = 0
local cprGoodHits = 0
local cprTargetHits = 15
local beatInterval = 60 / 110
local lastBeatTime = 0
local pulsePhase = 0
local renderConn = nil
local shockBarPos = 0
local shockBarDir = 1
local bedModel = nil
local monitorBB = nil
local clearDone = false
local shockDone = false
local codeCalled = false

-- Timer
local timerConn = nil

--------------------------------------------------------------
-- TIMER SYSTEM
--------------------------------------------------------------
local function startTimer(seconds, color, onExpire)
	timerFrame.Visible = true
	timerValue.Text = tostring(seconds)
	timerValue.TextColor3 = color or C.textPri

	if timerConn then timerConn:Disconnect() end

	local remaining = seconds
	local lastTick = tick()

	timerConn = RunService.Heartbeat:Connect(function()
		local now = tick()
		remaining = remaining - (now - lastTick)
		lastTick = now

		local display = math.ceil(remaining)
		if display < 0 then display = 0 end
		timerValue.Text = tostring(display)

		-- Color changes
		if remaining <= 3 then
			timerValue.TextColor3 = C.wrong
		elseif remaining <= 5 then
			timerValue.TextColor3 = C.hYellow
		end

		if remaining <= 0 then
			timerConn:Disconnect()
			timerConn = nil
			timerFrame.Visible = false
			if onExpire then onExpire() end
		end
	end)
end

local function stopTimer()
	if timerConn then timerConn:Disconnect(); timerConn = nil end
	timerFrame.Visible = false
end

--------------------------------------------------------------
-- INSTRUCTION HELPER
--------------------------------------------------------------
local function showInstr(phaseText, text, color)
	phaseLabel.Text = "// " .. phaseText
	phaseLabel.TextColor3 = color or C.accent
	instrText.Text = text
	instrBar.Visible = true
	instrStroke.Color = color or C.accent
end

local function hideInstr()
	instrBar.Visible = false
	stopTimer()
end

--------------------------------------------------------------
-- MONITOR VITALS (BillboardGui on HeartMonitor)
--------------------------------------------------------------
local function createMonitor()
	if not bedModel then return end
	local mon = bedModel:FindFirstChild("HeartMonitor", true)
	if not mon then warn("[Room3] HeartMonitor not found!"); return end

	local monPart = mon
	if mon:IsA("Model") then monPart = mon.PrimaryPart or mon:FindFirstChildWhichIsA("BasePart") end
	if not monPart then return end

	local existing = monPart:FindFirstChild("VitalsDisplay")
	if existing then existing:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name = "VitalsDisplay"
	bb.Size = UDim2.new(0, 220, 0, 140)
	bb.StudsOffset = Vector3.new(0, 0, -0.5)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 20
	bb.LightInfluence = 0
	bb.Parent = monPart

	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(8, 12, 8)
	bg.Parent = bb
	mkCorner(bg, 4)

	local hrVal = Instance.new("TextLabel")
	hrVal.Name = "HRValue"
	hrVal.Size = UDim2.new(0.6, 0, 0, 50)
	hrVal.Position = UDim2.new(0.35, 0, 0, 8)
	hrVal.BackgroundTransparency = 1
	hrVal.Text = "78"
	hrVal.TextColor3 = C.hGreen
	hrVal.TextSize = 40
	hrVal.Font = Enum.Font.Code
	hrVal.Parent = bg

	local bpmLbl = Instance.new("TextLabel")
	bpmLbl.Size = UDim2.new(0.3, 0, 0, 14)
	bpmLbl.Position = UDim2.new(0.35, 0, 0, 56)
	bpmLbl.BackgroundTransparency = 1
	bpmLbl.Text = "BPM"
	bpmLbl.TextColor3 = C.textMut
	bpmLbl.TextSize = 10
	bpmLbl.Font = Enum.Font.Code
	bpmLbl.Parent = bg

	local heart = Instance.new("TextLabel")
	heart.Name = "Heart"
	heart.Size = UDim2.new(0, 30, 0, 30)
	heart.Position = UDim2.new(0, 10, 0, 15)
	heart.BackgroundTransparency = 1
	heart.Text = "♥"
	heart.TextColor3 = C.hGreen
	heart.TextSize = 24
	heart.Font = Enum.Font.GothamBold
	heart.Parent = bg

	local stat = Instance.new("TextLabel")
	stat.Name = "Status"
	stat.Size = UDim2.new(1, -10, 0, 14)
	stat.Position = UDim2.new(0, 5, 0, 76)
	stat.BackgroundTransparency = 1
	stat.Text = "Normal Sinus Rhythm"
	stat.TextColor3 = C.hGreen
	stat.TextSize = 9
	stat.Font = Enum.Font.Code
	stat.TextXAlignment = Enum.TextXAlignment.Left
	stat.Parent = bg

	local vitals = { {"BP", "118/76", C.hGreen}, {"Temp", "101.2F", C.hYellow}, {"O2", "96%", C.hGreen} }
	for i, v in vitals do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 13)
		row.Position = UDim2.new(0, 5, 0, 94 + (i-1)*14)
		row.BackgroundTransparency = 1
		row.Parent = bg

		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(0.3, 0, 1, 0)
		l.BackgroundTransparency = 1
		l.Text = v[1]
		l.TextColor3 = C.textMut
		l.TextSize = 9
		l.Font = Enum.Font.Code
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Parent = row

		local val = Instance.new("TextLabel")
		val.Size = UDim2.new(0.7, 0, 1, 0)
		val.Position = UDim2.new(0.3, 0, 0, 0)
		val.BackgroundTransparency = 1
		val.Text = v[2]
		val.TextColor3 = v[3]
		val.TextSize = 9
		val.Font = Enum.Font.Code
		val.TextXAlignment = Enum.TextXAlignment.Left
		val.Parent = row
	end

	monitorBB = bb
end

local function updateMonitor(bpm, color)
	if not monitorBB then return end
	local bg = monitorBB:FindFirstChild("Bg")
	if not bg then return end
	local hrVal = bg:FindFirstChild("HRValue")
	local heart = bg:FindFirstChild("Heart")
	local stat = bg:FindFirstChild("Status")
	if hrVal then hrVal.Text = bpm > 0 and tostring(bpm) or "---"; hrVal.TextColor3 = color end
	if heart then
		heart.TextColor3 = color
		if bpm > 0 then
			TweenService:Create(heart, TweenInfo.new(0.1), {TextSize = 30}):Play()
			task.delay(0.1, function()
				if heart.Parent then TweenService:Create(heart, TweenInfo.new(0.3), {TextSize = 24}):Play() end
			end)
		end
	end
	if stat then
		if bpm == 0 then stat.Text = "!! FLATLINE !!"; stat.TextColor3 = C.flatline
		elseif bpm < 60 then stat.Text = "!! BRADYCARDIA !!"; stat.TextColor3 = C.hYellow
		else stat.Text = "Normal Sinus Rhythm"; stat.TextColor3 = C.hGreen end
	end
end

local function destroyMonitor()
	if monitorBB then monitorBB:Destroy(); monitorBB = nil end
end

--------------------------------------------------------------
-- CODE BLUE BUTTON GLOW
--------------------------------------------------------------
local cbHighlight, cbLight, cbBillboard, cbPulseConn

local function glowCodeBlue()
	if not bedModel then return end
	local btn = bedModel:FindFirstChild("CodeBlueButton", true)
	if not btn then warn("[Room3] CodeBlueButton not found!"); return end
	local btnPart = btn:IsA("Model") and (btn.PrimaryPart or btn:FindFirstChildWhichIsA("BasePart")) or btn
	if not btnPart then return end

	cbHighlight = Instance.new("Highlight")
	cbHighlight.FillColor = C.emergency; cbHighlight.FillTransparency = 0.2
	cbHighlight.OutlineColor = C.emergency; cbHighlight.OutlineTransparency = 0
	cbHighlight.Parent = btnPart

	cbLight = Instance.new("PointLight")
	cbLight.Color = C.emergency; cbLight.Brightness = 3; cbLight.Range = 15
	cbLight.Parent = btnPart

	cbBillboard = Instance.new("BillboardGui")
	cbBillboard.Size = UDim2.new(0, 200, 0, 55)
	cbBillboard.StudsOffset = Vector3.new(0, 3, 0)
	cbBillboard.AlwaysOnTop = true; cbBillboard.MaxDistance = 40
	cbBillboard.Parent = btnPart

	local lbg = Instance.new("Frame")
	lbg.Size = UDim2.new(1, 0, 0, 30)
	lbg.BackgroundColor3 = C.emergency
	lbg.Parent = cbBillboard
	mkCorner(lbg, 6)

	local ltx = Instance.new("TextLabel")
	ltx.Size = UDim2.new(1, 0, 1, 0)
	ltx.BackgroundTransparency = 1
	ltx.Text = "CODE BLUE [E]"
	ltx.TextColor3 = C.textPri
	ltx.TextSize = 14
	ltx.Font = Enum.Font.GothamBold
	ltx.Parent = lbg

	local arr = Instance.new("TextLabel")
	arr.Size = UDim2.new(1, 0, 0, 20)
	arr.Position = UDim2.new(0, 0, 0, 32)
	arr.BackgroundTransparency = 1
	arr.Text = "V"
	arr.TextColor3 = C.emergency
	arr.TextSize = 18
	arr.Font = Enum.Font.GothamBold
	arr.Parent = cbBillboard

	local pt = 0
	cbPulseConn = RunService.Heartbeat:Connect(function(dt)
		pt = pt + dt
		if cbHighlight and cbHighlight.Parent then cbHighlight.FillTransparency = 0.1 + 0.3 * math.sin(pt * 5) end
		if cbLight and cbLight.Parent then cbLight.Brightness = 2 + 2 * math.sin(pt * 5) end
	end)
end

local function stopCodeBlue()
	if cbHighlight then cbHighlight:Destroy(); cbHighlight = nil end
	if cbLight then cbLight:Destroy(); cbLight = nil end
	if cbBillboard then cbBillboard:Destroy(); cbBillboard = nil end
	if cbPulseConn then cbPulseConn:Disconnect(); cbPulseConn = nil end
end

--------------------------------------------------------------
-- SPIRIT SYSTEM
--------------------------------------------------------------
local function hideSpirit()
	if not bedModel then return end
	local spirit = bedModel:FindFirstChild("PatientSpirit", true)
	if not spirit then return end
	for _, p in spirit:GetDescendants() do
		if p:IsA("BasePart") then p.Transparency = 1; p.CanCollide = false end
	end
end

-- Fade to black overlay (used during death cinematic)
local fadeToBlack = Instance.new("Frame")
fadeToBlack.Name = "FadeToBlack"
fadeToBlack.Size = UDim2.new(1, 0, 1, 0)
fadeToBlack.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fadeToBlack.BackgroundTransparency = 1
fadeToBlack.Visible = false
fadeToBlack.ZIndex = 9
fadeToBlack.Parent = screenGui

local function playSpiritCinematic(callback)
	if not bedModel then if callback then callback() end return end
	local spirit = bedModel:FindFirstChild("PatientSpirit", true)
	local patient = bedModel:FindFirstChild("Patient", true)

	if not spirit then
		warn("[Room3] PatientSpirit not found for death cinematic")
		if callback then callback() end
		return
	end

	-- Find spirit primary part
	local spiritPrimary = nil
	if spirit:IsA("Model") then
		spiritPrimary = spirit.PrimaryPart or spirit:FindFirstChildWhichIsA("BasePart")
	elseif spirit:IsA("BasePart") then
		spiritPrimary = spirit
	end

	if not spiritPrimary then
		if callback then callback() end
		return
	end

	-- Find patient position
	local patientPos = spiritPrimary.Position
	if patient then
		if patient:IsA("Model") then
			local pp = patient.PrimaryPart or patient:FindFirstChildWhichIsA("BasePart")
			if pp then patientPos = pp.Position end
		elseif patient:IsA("BasePart") then
			patientPos = patient.Position
		end
	end

	-- USE PLAYER'S CURRENT POSITION as camera start (they're inside the room)
	local character = player.Character
	local camStartPos = patientPos + Vector3.new(3, 3, 3) -- fallback

	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			-- Camera at player's head height, looking at patient
			camStartPos = root.Position + Vector3.new(0, 2, 0)
		end
	end

	-- LOCK CAMERA — position at player's location looking at patient
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(camStartPos, patientPos)

	-- Make spirit ghostly (semi-transparent, slight glow)
	for _, p in spirit:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 0.35
			-- Slight white tint for ghostly look
			p.Color = Color3.fromRGB(
				math.min(255, p.Color.R * 255 * 0.5 + 128),
				math.min(255, p.Color.G * 255 * 0.5 + 128),
				math.min(255, p.Color.B * 255 * 0.5 + 128)
			)
		end
	end

	-- Add a soft glow to the spirit
	local spiritLight = Instance.new("PointLight")
	spiritLight.Name = "SpiritGlow"
	spiritLight.Color = Color3.fromRGB(200, 220, 255) -- cold blue-white
	spiritLight.Brightness = 1.5
	spiritLight.Range = 12
	spiritLight.Parent = spiritPrimary

	-- Spirit rises slowly — 50 studs up (well out of the room/ceiling)
	local spiritStartPos = spiritPrimary.Position
	local spiritEndPos = spiritStartPos + Vector3.new(0, 50, 0)
	local riseDuration = 6.0

	TweenService:Create(spiritPrimary, TweenInfo.new(riseDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(spiritEndPos)
	}):Play()

	-- Spirit fades out as it rises
	for _, p in spirit:GetDescendants() do
		if p:IsA("BasePart") then
			TweenService:Create(p, TweenInfo.new(riseDuration), { Transparency = 1 }):Play()
		end
	end

	-- Spirit glow fades
	TweenService:Create(spiritLight, TweenInfo.new(riseDuration), { Brightness = 0 }):Play()

	-- Camera slowly pans UP following the spirit from the player's position
	-- Camera stays in place but tilts upward
	local camEndLookAt = spiritStartPos + Vector3.new(0, 25, 0)

	TweenService:Create(camera, TweenInfo.new(riseDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(camStartPos + Vector3.new(0, 1, 0), camEndLookAt)
	}):Play()

	-- FADE TO BLACK gradually during the rise
	-- Start fading at 2 seconds, fully black by 5.5 seconds
	fadeToBlack.BackgroundTransparency = 1
	fadeToBlack.Visible = true

	task.delay(1.5, function()
		-- Start the fade
		TweenService:Create(fadeToBlack, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 0
		}):Play()
	end)

	-- After the full cinematic, callback
	task.delay(riseDuration, function()
		-- Clean up spirit glow
		if spiritLight and spiritLight.Parent then spiritLight:Destroy() end

		if callback then callback() end
	end)
end

local function restoreCamera()
	camera.CameraType = Enum.CameraType.Custom
end

--------------------------------------------------------------
-- CAMERA HEIGHT
--------------------------------------------------------------
local function setCameraHigher()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.CameraOffset = Vector3.new(0, 2, 0) end
end

local function resetCameraHeight()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.CameraOffset = Vector3.new(0, 0, 0) end
end

--------------------------------------------------------------
-- FORWARD DECLARATIONS
--------------------------------------------------------------
local runCalmPhase, runDeteriorationPhase, runCallCodePhase
local runCPRPhase, finishCPR, runDefibPhase, runShockPhase, runOutcome

--------------------------------------------------------------
-- PHASE 0: CALM (4 sec)
--------------------------------------------------------------
runCalmPhase = function()
	phase = "CALM"
	showInstr("MONITORING", "Observe Ms. Chen's vitals on the monitor...", C.accent)
	updateMonitor(78, C.hGreen)

	local start = tick()
	local interval = 60/78
	local lastP = 0

	local conn
	conn = RunService.Heartbeat:Connect(function()
		local el = tick() - start
		if el - lastP >= interval then lastP = el; updateMonitor(78, C.hGreen) end
		if el >= 4 then conn:Disconnect(); runDeteriorationPhase() end
	end)
end

--------------------------------------------------------------
-- PHASE 1: DETERIORATION (5 sec)
--------------------------------------------------------------
runDeteriorationPhase = function()
	phase = "DETERIORATION"
	showInstr("WARNING", "Heart rate is dropping!", C.hYellow)

	local seq = {
		{0, 72, C.hYellow}, {1, 65, C.hYellow}, {2, 55, C.hRed},
		{3, 40, C.hRed}, {4, 20, C.flatline}, {5, 0, C.flatline},
	}

	for _, e in seq do
		task.delay(e[1], function()
			if phase ~= "DETERIORATION" then return end
			updateMonitor(e[2], e[3])
			if e[2] == 0 then
				showInstr("EMERGENCY", "FLATLINE — Find the Code Blue button on the wall!", C.emergency)
			elseif e[2] <= 40 then
				showInstr("CRITICAL", "Heart rate critical!", C.hRed)
			end
		end)
	end

	task.delay(6, function()
		if phase == "DETERIORATION" then runCallCodePhase() end
	end)
end

--------------------------------------------------------------
-- PHASE 2: CALL CODE (physical button, 10 sec timer)
--------------------------------------------------------------
runCallCodePhase = function()
	phase = "CALL_CODE"
	showInstr("CODE BLUE", "Run to the glowing RED button and press [E]!", C.emergency)
	glowCodeBlue()

	startTimer(10, C.emergency, function()
		-- Timeout
		if phase == "CALL_CODE" and not codeCalled then
			codeCalled = true
			stopCodeBlue()
			showInstr("CODE BLUE", "Too slow! Code team delayed...", C.wrong)
			task.delay(2, function() hideInstr(); runCPRPhase() end)
		end
	end)
end

--------------------------------------------------------------
-- PHASE 3: CPR (spacebar, 25 sec timer)
--------------------------------------------------------------
runCPRPhase = function()
	phase = "CPR"
	cprGoodHits = 0

	showInstr("CPR", "LEFT CLICK in rhythm — match the circle to the ring!", C.emergency)
	cprFrame.Visible = true
	compCount.Text = "0 / " .. cprTargetHits
	cprProgFill.Size = UDim2.new(0, 0, 1, 0)
	hitFb.Text = ""

	local start = tick()
	lastBeatTime = start
	pulsePhase = 0

	startTimer(25, C.hYellow)

	renderConn = RunService.RenderStepped:Connect(function()
		if phase ~= "CPR" then return end
		local el = tick() - start
		if el >= 25 or cprGoodHits >= cprTargetHits then
			renderConn:Disconnect(); renderConn = nil
			stopTimer(); finishCPR(); return
		end

		pulsePhase = ((tick() - lastBeatTime) % beatInterval) / beatInterval
		local sz = 170 - 60 * pulsePhase
		pulseCircle.Size = UDim2.new(0, sz, 0, sz)
		pulseCircle.Position = UDim2.new(0.5, -sz/2, 0.5, -sz/2)

		local dist = math.abs(sz - 110)
		if dist < 8 then pulseStroke.Color = C.cprPerf
		elseif dist < 20 then pulseStroke.Color = C.cprGood
		else pulseStroke.Color = C.textSec end
	end)
end

finishCPR = function()
	cprFrame.Visible = false
	local acc = cprGoodHits / cprTargetHits
	local cprScore = math.floor(55 * math.clamp(acc, 0, 1))
	totalScore = totalScore + cprScore

	if acc >= 0.8 then
		showInstr("CPR COMPLETE", "Effective! " .. cprGoodHits .. "/" .. cprTargetHits .. " compressions", C.correct)
	else
		showInstr("CPR COMPLETE", "Partial. " .. cprGoodHits .. "/" .. cprTargetHits .. " compressions", C.hYellow)
	end
	task.delay(2.5, function() hideInstr(); runDefibPhase() end)
end

--------------------------------------------------------------
-- PHASE 4: DEFIB CLEAR (E key, 5 sec timer)
--------------------------------------------------------------
runDefibPhase = function()
	phase = "DEFIB_CLEAR"
	showInstr("DEFIBRILLATOR", "Press [E] to CLEAR the patient!", C.emergency)
	defibFrame.Visible = true
	defibInstr.Text = "Press [E] to CLEAR the patient"
	defibStatus.Text = "Waiting for clear..."
	defibHint.Text = "[E] Clear"
	shockBarBg.Visible = false

	startTimer(5, C.emergency, function()
		if phase == "DEFIB_CLEAR" and not clearDone then
			clearDone = true
			defibStatus.Text = "Too slow to clear!"; defibStatus.TextColor3 = C.wrong
			task.delay(1.5, function() runShockPhase() end)
		end
	end)
end

--------------------------------------------------------------
-- PHASE 4B: DEFIB SHOCK (E key, timing bar, 8 sec timer)
--------------------------------------------------------------
runShockPhase = function()
	phase = "DEFIB_SHOCK"
	showInstr("DEFIBRILLATOR", "Press [E] when indicator is in the GREEN zone!", C.emergency)
	defibInstr.Text = "Press [E] to SHOCK in the green zone!"
	defibStatus.Text = "Time your shock carefully..."
	defibStatus.TextColor3 = C.textSec
	defibHint.Text = "[E] Shock"
	shockBarBg.Visible = true
	shockBarPos = 0; shockBarDir = 1

	startTimer(8, C.emergency, function()
		if phase == "DEFIB_SHOCK" and not shockDone then
			shockDone = true
			defibStatus.Text = "Failed to shock in time."; defibStatus.TextColor3 = C.wrong
			task.delay(2, function() defibFrame.Visible = false; hideInstr(); runOutcome() end)
		end
	end)

	local shockConn
	shockConn = RunService.RenderStepped:Connect(function(dt)
		if phase ~= "DEFIB_SHOCK" or shockDone then
			shockConn:Disconnect()
			return
		end
		shockBarPos = shockBarPos + dt * 2.0 * shockBarDir
		if shockBarPos >= 1 then shockBarPos = 1; shockBarDir = -1
		elseif shockBarPos <= 0 then shockBarPos = 0; shockBarDir = 1 end
		shockInd.Position = UDim2.new(shockBarPos, -3, 0, -2)
	end)
end

--------------------------------------------------------------
-- PHASE 5: OUTCOME
--------------------------------------------------------------
runOutcome = function()
	phase = "OUTCOME"
	hideInstr(); cprFrame.Visible = false; defibFrame.Visible = false; stopTimer()

	local passed = totalScore >= 50

	if passed then
		-- SUCCESS
		outcomeOv.BackgroundColor3 = C.bg
		outcomeOv.Visible = true
		TweenService:Create(outcomeOv, TweenInfo.new(1.5), {BackgroundTransparency = 0.15}):Play()
		outcTitle.Text = "PATIENT STABILIZED"; outcTitle.TextColor3 = C.correct
		outcMsg.Text = "Ms. Chen's heartbeat has returned. Your quick response, effective CPR, and proper defibrillation saved her life."
		outcScore.Text = "Score: " .. totalScore .. " / 100"; outcScore.TextColor3 = C.correct
		outcHint.Visible = true

		task.delay(1, function() updateMonitor(72, C.hGreen) end)
		Room3ActionEvent:FireServer("OUTCOME", totalScore, true)
	else
		-- FAILURE — CINEMATIC DEATH SCENE
		-- Hide all UI first
		outcomeOv.Visible = false
		outcHint.Visible = false
		instrBar.Visible = false

		-- Play the spirit cinematic (camera locks, spirit rises, screen fades black)
		playSpiritCinematic(function()
			-- Screen is now black from the fade
			-- Show the fail screen ON TOP of the black
			fadeToBlack.Visible = true
			fadeToBlack.BackgroundTransparency = 0

			outcomeOv.BackgroundColor3 = C.deathBg
			outcomeOv.BackgroundTransparency = 0
			outcomeOv.Visible = true

			-- Fade in the text over the black screen
			outcTitle.Text = ""; outcMsg.Text = ""; outcScore.Text = ""
			outcHint.Visible = false

			-- Slight delay then reveal text dramatically
			task.delay(0.8, function()
				outcTitle.Text = "PATIENT LOST"
				outcTitle.TextColor3 = C.wrong
			end)

			task.delay(1.8, function()
				outcMsg.Text = "Despite your efforts, Ms. Chen could not be resuscitated. Every second and every compression counts in a Code Blue."
			end)

			task.delay(2.8, function()
				outcScore.Text = "Score: " .. totalScore .. " / 100"
				outcScore.TextColor3 = C.wrong
			end)

			task.delay(3.8, function()
				outcHint.Visible = true
			end)

			Room3ActionEvent:FireServer("OUTCOME", totalScore, false)
		end)
	end
end

--------------------------------------------------------------
-- TUTORIAL OVERLAY (Room 3)
--------------------------------------------------------------
local tutOverlay3 = Instance.new("Frame")
tutOverlay3.Size = UDim2.new(1,0,1,0)
tutOverlay3.BackgroundColor3 = Color3.new(0,0,0)
tutOverlay3.BackgroundTransparency = 0.4
tutOverlay3.Visible = false; tutOverlay3.ZIndex = 20; tutOverlay3.Parent = screenGui

local tutPanel3 = Instance.new("Frame")
tutPanel3.Size = UDim2.new(0,750,0,450)
tutPanel3.Position = UDim2.new(0.5,-375,0.5,-225)
tutPanel3.BackgroundColor3 = C.panelBg; tutPanel3.ZIndex = 21; tutPanel3.Parent = tutOverlay3
mkCorner(tutPanel3, 16); mkStroke(tutPanel3, C.emergency, 3)

local tutTitle3 = Instance.new("TextLabel")
tutTitle3.Size = UDim2.new(1,0,0,50); tutTitle3.Position = UDim2.new(0,0,0,30)
tutTitle3.BackgroundTransparency = 1; tutTitle3.Text = "CODE BLUE EMERGENCY"
tutTitle3.TextColor3 = C.emergency; tutTitle3.TextSize = 32; tutTitle3.Font = Enum.Font.GothamBlack
tutTitle3.ZIndex = 22; tutTitle3.Parent = tutPanel3

local tutBody3 = Instance.new("TextLabel")
tutBody3.Size = UDim2.new(1,-60,0,220); tutBody3.Position = UDim2.new(0,30,0,95)
tutBody3.BackgroundTransparency = 1
tutBody3.Text = "Ms. Chen has been stable, but you need to monitor her vitals.\n\nWatch the heart monitor carefully. If something goes wrong, you'll need to act FAST.\n\n[E] — Interact with objects / Confirm actions\n[LEFT CLICK] — CPR compressions\n\nEvery second counts. Stay alert."
tutBody3.TextColor3 = C.textPri; tutBody3.TextSize = 20; tutBody3.Font = Enum.Font.Gotham
tutBody3.TextWrapped = true; tutBody3.TextXAlignment = Enum.TextXAlignment.Left
tutBody3.TextYAlignment = Enum.TextYAlignment.Top; tutBody3.ZIndex = 22; tutBody3.Parent = tutPanel3

local tutHint3 = Instance.new("TextLabel")
tutHint3.Size = UDim2.new(0,240,0,50); tutHint3.Position = UDim2.new(0.5,-120,1,-75)
tutHint3.BackgroundColor3 = C.accent; tutHint3.Text = "  Press [E] to Begin"
tutHint3.TextColor3 = C.bg; tutHint3.TextSize = 18; tutHint3.Font = Enum.Font.GothamBold
tutHint3.TextXAlignment = Enum.TextXAlignment.Left; tutHint3.ZIndex = 22; tutHint3.Parent = tutPanel3
mkCorner(tutHint3, 8)

--------------------------------------------------------------
-- ROOM 3 SCORE SCREEN
--------------------------------------------------------------
local scoreScreen3 = Instance.new("Frame")
scoreScreen3.Size = UDim2.new(1,0,1,0)
scoreScreen3.BackgroundColor3 = C.bg; scoreScreen3.BackgroundTransparency = 0.1
scoreScreen3.Visible = false; scoreScreen3.ZIndex = 25; scoreScreen3.Parent = screenGui

local scPanel3 = Instance.new("Frame")
scPanel3.Size = UDim2.new(0,600,0,420); scPanel3.Position = UDim2.new(0.5,-300,0.5,-210)
scPanel3.BackgroundColor3 = C.panelBg; scPanel3.ZIndex = 26; scPanel3.Parent = scoreScreen3
mkCorner(scPanel3, 16); mkStroke(scPanel3, C.accent, 3)

local sc3Lbl = Instance.new("TextLabel")
sc3Lbl.Size = UDim2.new(1,0,0,20); sc3Lbl.Position = UDim2.new(0,0,0,28)
sc3Lbl.BackgroundTransparency = 1; sc3Lbl.Text = "// CODE BLUE COMPLETE"
sc3Lbl.TextColor3 = C.accent; sc3Lbl.TextSize = 14; sc3Lbl.Font = Enum.Font.Code; sc3Lbl.ZIndex = 27
sc3Lbl.Parent = scPanel3

local sc3Title = Instance.new("TextLabel")
sc3Title.Size = UDim2.new(1,0,0,40); sc3Title.Position = UDim2.new(0,0,0,55)
sc3Title.BackgroundTransparency = 1; sc3Title.Text = "Room 3 Results"
sc3Title.TextColor3 = C.textPri; sc3Title.TextSize = 32; sc3Title.Font = Enum.Font.GothamBlack
sc3Title.ZIndex = 27; sc3Title.Parent = scPanel3

local sc3Circle = Instance.new("Frame")
sc3Circle.Size = UDim2.new(0,110,0,110); sc3Circle.Position = UDim2.new(0.5,-55,0,110)
sc3Circle.BackgroundColor3 = C.bg; sc3Circle.ZIndex = 27; sc3Circle.Parent = scPanel3
mkCorner(sc3Circle, 55); local sc3CStroke = mkStroke(sc3Circle, C.accent, 4)

local sc3Val = Instance.new("TextLabel")
sc3Val.Size = UDim2.new(1,0,1,0); sc3Val.BackgroundTransparency = 1
sc3Val.Text = "0"; sc3Val.TextColor3 = C.accent; sc3Val.TextSize = 38
sc3Val.Font = Enum.Font.GothamBlack; sc3Val.ZIndex = 28; sc3Val.Parent = sc3Circle

local sc3Msg = Instance.new("TextLabel")
sc3Msg.Size = UDim2.new(1,-60,0,70); sc3Msg.Position = UDim2.new(0,30,0,240)
sc3Msg.BackgroundTransparency = 1; sc3Msg.Text = ""; sc3Msg.TextColor3 = C.textPri
sc3Msg.TextSize = 16; sc3Msg.Font = Enum.Font.Gotham; sc3Msg.TextWrapped = true
sc3Msg.ZIndex = 27; sc3Msg.Parent = scPanel3

local sc3Hint = Instance.new("TextLabel")
sc3Hint.Size = UDim2.new(0,240,0,50); sc3Hint.Position = UDim2.new(0.5,-120,0,340)
sc3Hint.BackgroundColor3 = C.accent; sc3Hint.Text = "  [E] Continue"
sc3Hint.TextColor3 = C.bg; sc3Hint.TextSize = 18; sc3Hint.Font = Enum.Font.GothamBold
sc3Hint.TextXAlignment = Enum.TextXAlignment.Left; sc3Hint.ZIndex = 27; sc3Hint.Parent = scPanel3
mkCorner(sc3Hint, 8)

local function showRoom3Score()
	sc3Val.Text = tostring(totalScore)
	if totalScore >= 67 then sc3CStroke.Color = C.correct; sc3Val.TextColor3 = C.correct
	elseif totalScore >= 34 then sc3CStroke.Color = C.hYellow; sc3Val.TextColor3 = C.hYellow
	else sc3CStroke.Color = C.wrong; sc3Val.TextColor3 = C.wrong end
	if totalScore >= 50 then sc3Msg.Text = "Strong emergency response. Your quick actions made the difference."
	else sc3Msg.Text = "Emergency protocols need work. Review BLS guidelines and try again." end
	scoreScreen3.Visible = true
	phase = "ROOM_SCORE"
end

--------------------------------------------------------------
-- KEYBOARD INPUT
--------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	local key = input.KeyCode

	-- CODE BLUE BUTTON
	if phase == "CALL_CODE" and (key == Enum.KeyCode.E or key == Enum.KeyCode.Return) then
		if codeCalled then return end
		local char = player.Character
		if not char or not bedModel then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end

		local btn = bedModel:FindFirstChild("CodeBlueButton", true)
		if not btn then return end
		local btnPos = btn.Position
		if btn:IsA("Model") then
			local p = btn.PrimaryPart or btn:FindFirstChildWhichIsA("BasePart")
			if p then btnPos = p.Position end
		end

		if (root.Position - btnPos).Magnitude > 15 then
			showInstr("CODE BLUE", "Get CLOSER to the red button! [E]", C.emergency)
			return
		end

		codeCalled = true
		stopCodeBlue(); stopTimer()
		totalScore = totalScore + 15
		showInstr("CODE BLUE", "Code Blue called! Emergency team notified.", C.correct)
		task.delay(2, function() hideInstr(); runCPRPhase() end)

		-- CPR (removed - now using mouse click instead)

		-- DEFIB CLEAR
	elseif phase == "DEFIB_CLEAR" and (key == Enum.KeyCode.E or key == Enum.KeyCode.Return) then
		if clearDone then return end
		clearDone = true; stopTimer()
		totalScore = totalScore + 15
		defibStatus.Text = "Patient cleared!"; defibStatus.TextColor3 = C.correct
		showInstr("DEFIBRILLATOR", "Patient cleared! Preparing shock...", C.correct)
		task.delay(1.5, function() runShockPhase() end)

		-- DEFIB SHOCK
	elseif phase == "DEFIB_SHOCK" and (key == Enum.KeyCode.E or key == Enum.KeyCode.Return) then
		if shockDone then return end
		shockDone = true; stopTimer()

		local inGreen = shockBarPos >= 0.35 and shockBarPos <= 0.65
		if inGreen then
			totalScore = totalScore + 15
			defibStatus.Text = "SHOCK DELIVERED!"; defibStatus.TextColor3 = C.correct
			showInstr("DEFIBRILLATOR", "Shock delivered!", C.correct)
		else
			defibStatus.Text = "Shock mistimed..."; defibStatus.TextColor3 = C.wrong
			showInstr("DEFIBRILLATOR", "Shock mistimed — reduced effectiveness.", C.wrong)
		end

		shockBarBg.BackgroundColor3 = Color3.fromRGB(255, 255, 200)
		task.delay(0.15, function() shockBarBg.BackgroundColor3 = C.bg end)
		task.delay(2.5, function() defibFrame.Visible = false; hideInstr(); runOutcome() end)

		-- OUTCOME CONTINUE → show room score
	elseif phase == "OUTCOME" and (key == Enum.KeyCode.E or key == Enum.KeyCode.Return) then
		outcomeOv.Visible = false
		fadeToBlack.Visible = false
		fadeToBlack.BackgroundTransparency = 1
		restoreCamera()
		showRoom3Score()

		-- TUTORIAL: dismiss and start
	elseif phase == "TUTORIAL" and (key == Enum.KeyCode.E or key == Enum.KeyCode.Return) then
		tutOverlay3.Visible = false
		phase = "IDLE"
		task.delay(0.5, function() runCalmPhase() end)

		-- ROOM SCORE: dismiss and tell server
	elseif phase == "ROOM_SCORE" and (key == Enum.KeyCode.E or key == Enum.KeyCode.Return) then
		scoreScreen3.Visible = false
		screenGui.Enabled = false
		resetCameraHeight()
		Room3ActionEvent:FireServer("CONTINUE", totalScore)
	end
end)

--------------------------------------------------------------
-- MOUSE CLICK FOR CPR (left click instead of spacebar)
--------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	
	if phase == "CPR" and input.UserInputType == Enum.UserInputType.MouseButton1 then
		local sz = 170 - 60 * pulsePhase
		local dist = math.abs(sz - 110)

		if dist <= 8 then
			hitFb.Text = "PERFECT!"; hitFb.TextColor3 = C.cprPerf; cprGoodHits = cprGoodHits + 1
		elseif dist <= 20 then
			hitFb.Text = "GOOD"; hitFb.TextColor3 = C.cprGood; cprGoodHits = cprGoodHits + 1
		else
			hitFb.Text = "MISS"; hitFb.TextColor3 = C.cprMiss
		end

		lastBeatTime = tick(); pulsePhase = 0
		compCount.Text = cprGoodHits .. " / " .. cprTargetHits
		local prog = math.clamp(cprGoodHits / cprTargetHits, 0, 1)
		TweenService:Create(cprProgFill, TweenInfo.new(0.2), {Size = UDim2.new(prog, 0, 1, 0)}):Play()
		TweenService:Create(targetStroke, TweenInfo.new(0.1), {Thickness = 6}):Play()
		task.delay(0.15, function() TweenService:Create(targetStroke, TweenInfo.new(0.2), {Thickness = 3}):Play() end)
	end
end)

--------------------------------------------------------------
-- START / CLEANUP
--------------------------------------------------------------
Room3StartEvent.OnClientEvent:Connect(function()
	local nw = workspace:FindFirstChild("NurseWorld")
	local beds = nw and nw:FindFirstChild("PatientBeds")
	bedModel = beds and beds:FindFirstChild("PatientBed_03")

	phase = "TUTORIAL"; totalScore = 0; cprGoodHits = 0
	clearDone = false; shockDone = false; codeCalled = false

	hideSpirit(); setCameraHigher(); createMonitor()

	screenGui.Enabled = true
	cprFrame.Visible = false; defibFrame.Visible = false; outcomeOv.Visible = false
	scoreScreen3.Visible = false; fadeToBlack.Visible = false

	-- Show tutorial
	tutOverlay3.Visible = true
end)

Room3CompleteEvent.OnClientEvent:Connect(function()
	phase = "IDLE"; screenGui.Enabled = false
	hideInstr(); stopCodeBlue(); stopTimer(); destroyMonitor()
	fadeToBlack.Visible = false; fadeToBlack.BackgroundTransparency = 1
	scoreScreen3.Visible = false; tutOverlay3.Visible = false
	restoreCamera(); resetCameraHeight()
	if renderConn then renderConn:Disconnect(); renderConn = nil end
end)

print("[Room3_Client] Code Blue v4 — tutorial, room score, cinematic death, timers.")
