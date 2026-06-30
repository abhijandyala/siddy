--[[
	PilotUI.luau  (v4 — DETAILED TASK SYSTEM, debugged)
	ModuleScript: required by PilotUIEntry.client.luau

	Restored detailed version:
	  1. Pre-Flight  — click checklist items in order
	  2. Startup     — aim crosshair + click glowing systems in sequence
	  3. In-Flight   — physical throttle to V1, takeoff, 7s cruise
	  4. Landing     — descend, scenario QTE, flare timing window, touchdown

	Bug fixes vs the old paste:
	  - Throttle + both yokes anchor to the plane BODY (no drift, no compounding)
	  - Camera ownership (Scriptable) held through the whole flow
	  - Normalized 0-100 per-task scoring
]]

local TweenService      = game:GetService("TweenService")
local Players           = game:GetService("Players")
local UIS               = game:GetService("UserInputService")
local RS                = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")
local SoundService      = game:GetService("SoundService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = workspace.CurrentCamera

-- Shared state (must exist before mouse/camera helpers)
local M = {}
M.cursorUnlocked = false
M.userCursorUnlocked = false
M.headLookActive = false
M.activeModal = nil

-- FBLA integration flags. The pilot game is one career segment inside a larger
-- world sequence (PlaySequence), so it must be able to stop cleanly.
M.active = true    -- gates the per-frame loops + input + remote handlers while Aviation runs
M.aborted = false  -- set by teardown so any in-flight task/cinematic coroutine bails out
M.finished = false -- set when the player presses CONTINUE on the flight debrief
M._conns = {}      -- persistent connections, disconnected on teardown

--------------------------------------------------------------
-- PLAYER ALWAYS LOCKED
--------------------------------------------------------------
local function lockPlayer()
	local char = player.Character; if not char then return end
	local h = char:FindFirstChildOfClass("Humanoid")
	if h then h.WalkSpeed = 0; h.JumpPower = 0; h.JumpHeight = 0 end
end
lockPlayer()
player.CharacterAdded:Connect(function(char)
	if not M.active then return end
	task.wait(0.1)
	if not M.active then return end
	local h = char:WaitForChild("Humanoid", 5)
	if h then h.WalkSpeed = 0; h.JumpPower = 0; h.JumpHeight = 0 end
end)

local function lockFP()
	player.CameraMaxZoomDistance = 0.5
end
lockFP()
player.CharacterAdded:Connect(function() if not M.active then return end; task.wait(0.15); if M.active then lockFP() end end)

local function wantsMouseUnlocked()
	if M.userCursorUnlocked then return true end
	if M.cursorUnlocked then return true end
	if M.activeModal and M.activeModal.Visible then return true end
	if M.tutOv and M.tutOv.Visible then return true end
	return false
end

local function applyMouseLock()
	if not M.active then
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
		return
	end
	if wantsMouseUnlocked() then
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 128
	else
		UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		UIS.MouseIconEnabled = false
	end
end

local function showMouse()
	M.cursorUnlocked = true
	applyMouseLock()
	task.defer(applyMouseLock)
end
local function hideMouse()
	M.cursorUnlocked = false
	applyMouseLock()
end
hideMouse()

UIS.InputBegan:Connect(function(inp, gp)
	if gp or not M.active then return end
	if inp.KeyCode == Enum.KeyCode.J then
		M.userCursorUnlocked = not M.userCursorUnlocked
		applyMouseLock()
	end
end)

RS:BindToRenderStep("PilotMouseLock", Enum.RenderPriority.Last.Value, applyMouseLock)
M._conns.hb = RS.Heartbeat:Connect(applyMouseLock)

-- Stop Roblox PlayerModule from re-locking the mouse over our UI
task.defer(function()
	local ps = player:WaitForChild("PlayerScripts", 15)
	local mmc = ps and ps:FindFirstChild("PlayerModule") and ps.PlayerModule:FindFirstChild("CameraModule")
	local mlc = mmc and mmc:FindFirstChild("MouseLockController")
	if mlc then
		local ok, ctrl = pcall(require, mlc)
		if ok and type(ctrl) == "table" and ctrl.Disable then
			ctrl:Disable()
		end
	end
end)

--------------------------------------------------------------
-- SOUND DESIGN   (placeholder rbxassetid:// — swap freely)
-- All playback is pcall-guarded so a moderated/removed asset
-- can never break gameplay.
--------------------------------------------------------------
local SFX = {
	click     = "rbxassetid://6042053626",  -- soft UI click
	switch    = "rbxassetid://6042583626",  -- toggle / switch flip
	success   = "rbxassetid://9117052730",  -- positive chime
	error     = "rbxassetid://9118827633",  -- error buzz
	whoosh    = "rbxassetid://9125402735",  -- transition whoosh
	rumble    = "rbxassetid://9116485263",  -- takeoff rumble
	touchdown = "rbxassetid://9116485263",  -- tyre touchdown
	klaxon    = "rbxassetid://9046447684",  -- emergency alarm
	sting     = "rbxassetid://1843082208",  -- triumphant sting
}
local MUSIC = {
	ambient = "rbxassetid://1837879082",    -- calm ambient bed
	tense   = "rbxassetid://1842053169",    -- tense emergency cue
	wind    = "rbxassetid://9112643319",    -- in-flight wind/engine loop
}

local sndFolder = SoundService:FindFirstChild("PilotSounds")
if not sndFolder then sndFolder = Instance.new("Folder"); sndFolder.Name="PilotSounds"; sndFolder.Parent=SoundService end

local function playSfx(name, vol, pitch)
	local id = SFX[name]; if not id then return end
	pcall(function()
		local s=Instance.new("Sound"); s.SoundId=id; s.Volume=vol or 0.5
		s.PlaybackSpeed=pitch or 1; s.Parent=sndFolder
		s.Ended:Connect(function() s:Destroy() end)
		s:Play()
		task.delay(9, function() if s and s.Parent then s:Destroy() end end)
	end)
end

local musicSound = Instance.new("Sound"); musicSound.Name="PilotMusic"; musicSound.Looped=true; musicSound.Volume=0; musicSound.Parent=sndFolder
local ambSound   = Instance.new("Sound"); ambSound.Name="PilotAmbience"; ambSound.Looped=true; ambSound.Volume=0; ambSound.Parent=sndFolder

local function playMusic(name, targetVol)
	local id = MUSIC[name]; if not id then return end
	pcall(function()
		if musicSound.SoundId ~= id then musicSound.SoundId=id end
		if not musicSound.IsPlaying then musicSound:Play() end
		TweenService:Create(musicSound,TweenInfo.new(1.2),{Volume=targetVol or 0.22}):Play()
	end)
end
local function stopMusic() pcall(function() TweenService:Create(musicSound,TweenInfo.new(1.0),{Volume=0}):Play() end) end
local function playAmbience(name, targetVol)
	local id = MUSIC[name]; if not id then return end
	pcall(function()
		if ambSound.SoundId ~= id then ambSound.SoundId=id end
		if not ambSound.IsPlaying then ambSound:Play() end
		TweenService:Create(ambSound,TweenInfo.new(1.4),{Volume=targetVol or 0.18}):Play()
	end)
end
local function stopAmbience() pcall(function() TweenService:Create(ambSound,TweenInfo.new(0.9),{Volume=0}):Play() end) end

--------------------------------------------------------------
-- REMOTES
--------------------------------------------------------------
local folder = ReplicatedStorage:WaitForChild("PilotRemotes", 30)
assert(folder, "[PilotUI] PilotRemotes not found!")
local ShowTutorial   = folder:WaitForChild("ShowTutorial",   10)
local PlayerReady    = folder:WaitForChild("PlayerReady",    10)
local ClientReady    = folder:WaitForChild("ClientReady",    10)
local StartCinematic = folder:WaitForChild("StartCinematic", 10)
local CinematicDone  = folder:WaitForChild("CinematicDone",  10)
local StartTask      = folder:WaitForChild("StartTask",      10)
local TaskComplete   = folder:WaitForChild("TaskComplete",   10)
local ScoreUpdate    = folder:WaitForChild("ScoreUpdate",    10)
local ShowResults    = folder:WaitForChild("ShowResults",    10)

-- Shared module table (single source for mutable pilot UI state)
M.tutWaiting = false
M.gameFlowStarted = false
M.taskFlowActive = false
M.taskRunning = false
M.lastTaskIdx = 0
M.activeModal = nil
M.totalScore = 0
M.planeModel = nil
M.planeBodyAnchor = nil
M.planeTracking = false
M.planeHomeCF = nil
M.headLookActive = false
M.cockpitBaseCF = CFrame.new()
M.headYaw = 0
M.headPitch = 0
M.smoothYaw = 0
M.smoothPitch = 0
M.idleT = 0
M.locThr = nil
M.popThr = nil

--------------------------------------------------------------
-- PALETTE
--------------------------------------------------------------
-- Seamless glass UI palette (Career Exploration style): dark translucent
-- panels, thin light-blue borders, white titles, light gray action buttons.
local C = {
	bg      = Color3.fromRGB(12,  16,  26),
	panel   = Color3.fromRGB(16,  22,  36),
	border  = Color3.fromRGB(88,  138, 182),
	accent  = Color3.fromRGB(96,  152, 198),
	text    = Color3.fromRGB(248, 250, 252),
	textMut = Color3.fromRGB(168, 180, 198),
	textSec = Color3.fromRGB(198, 206, 218),
	btn     = Color3.fromRGB(228, 232, 238),
	btnText = Color3.fromRGB(20,  30,  48),
	warn    = Color3.fromRGB(222, 174, 78),
	danger  = Color3.fromRGB(208, 96,  82),
	success = Color3.fromRGB(112, 184, 142),
	amber   = Color3.fromRGB(216, 162, 70),
	gold    = Color3.fromRGB(206, 178, 104),
	paper   = Color3.fromRGB(16,  22,  36),
	ink     = Color3.fromRGB(248, 250, 252),
}
local PANEL_TRANS = 0.18   -- how see-through glass panels are
local GLASS_R     = 10     -- corner radius for main panels/buttons

local function mkC(p,r) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 6);c.Parent=p;return c end
local function mkS(p,col,t) local s=Instance.new("UIStroke");s.Color=col or C.border;s.Thickness=t or 1;s.Parent=p;return s end
local function mkPad(p,t,r,b,l)
	local u=Instance.new("UIPadding");u.PaddingTop=UDim.new(0,t or 0);u.PaddingRight=UDim.new(0,r or t or 0)
	u.PaddingBottom=UDim.new(0,b or t or 0);u.PaddingLeft=UDim.new(0,l or r or t or 0);u.Parent=p;return u
end
local function mkL(p,gap,dir) local l=Instance.new("UIListLayout");l.Padding=UDim.new(0,gap or 6);l.FillDirection=dir or Enum.FillDirection.Vertical;l.SortOrder=Enum.SortOrder.LayoutOrder;l.Parent=p;return l end
local function mkLbl(par,txt,sz,fnt,col,xa,zi)
	local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Text=txt or ""
	l.TextSize=sz or 14;l.Font=fnt or Enum.Font.Gotham;l.TextColor3=col or C.text
	l.TextXAlignment=xa or Enum.TextXAlignment.Center;l.ZIndex=zi or 10;l.Parent=par;return l
end

-- Glass panel styling: translucent dark fill + thin accent border. No drop shadows.
local function mkGlass(frame, trans)
	frame.BackgroundColor3 = C.panel
	frame.BackgroundTransparency = trans or PANEL_TRANS
	mkC(frame, GLASS_R)
	local s = mkS(frame, C.border, 1)
	s.Transparency = 0.15
	return frame
end

local function mkMenuBtn(parent, txt, size, pos, zi)
	local b = Instance.new("TextButton")
	b.Size = size; b.Position = pos
	b.BackgroundColor3 = C.btn; b.AutoButtonColor = true
	b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 15
	b.TextColor3 = C.btnText; b.ZIndex = zi or 20; b.Parent = parent
	mkC(b, GLASS_R)
	return b
end

local function mkBtn(parent, txt, bg, fg, size, pos)
	local b = Instance.new("TextButton")
	b.Size = size; b.Position = pos
	b.BackgroundColor3 = bg or C.btn; b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 12
	b.TextColor3 = fg or C.btnText; b.AutoButtonColor = true; b.ZIndex = 27; b.Parent = parent
	mkC(b, 8)
	b.MouseButton1Click:Connect(function() playSfx("click", 0.4) end)
	return b
end

local function mkShadow() end   -- intentionally unused (seamless = no drop shadows)
local function mkGradient() end   -- intentionally unused (seamless = flat glass)

--------------------------------------------------------------
-- SCREEN GUI
--------------------------------------------------------------
local sg = Instance.new("ScreenGui")
sg.Name="PilotUI"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.Parent=playerGui

--------------------------------------------------------------
-- HUD LAYOUT  (fixed zones — panels must not overlap)
--------------------------------------------------------------
local PAD = 12
local SAFE_TOP = 72
local TASK_W, TASK_H = 200, 172
local SCORE_W, SCORE_H = 96, 44
local ALT_W, ALT_H = 96, 44
local SCEN_W, SCEN_H = 420, 40
local SUB_W, SUB_H = 520, 36
local SPD_W, SPD_H = 180, 56
local BOTTOM_PAD = 14
local GAP = 10
local SCEN_Y = SAFE_TOP + SCORE_H + GAP + 6
local THR_X = PAD + TASK_W + GAP
local THR_Y = SAFE_TOP + TASK_H + GAP
local HUD_MSG_Y = SAFE_TOP + TASK_H + GAP
local LOC_Y = -(54 + 12)  -- card height + gap; anchored just above the bottom letterbox bar (1-LBH)
local SUB_Y = -(BOTTOM_PAD + SUB_H)
local SPD_Y = -(BOTTOM_PAD + SUB_H + GAP + SPD_H)
local SUB_RESERVE = BOTTOM_PAD + SUB_H + GAP + 8
local POP_Y = SCEN_Y + SCEN_H + 14

local function layoutModalPanel(panel)
	local cam = workspace.CurrentCamera
	local vpY = (cam and cam.ViewportSize.Y) or 768
	local pw = panel.Size.X.Offset
	local ph = panel.Size.Y.Offset
	local topMin = SAFE_TOP + TASK_H + GAP
	local maxPh = vpY - topMin - SUB_RESERVE
	if maxPh < 280 then maxPh = math.max(220, vpY - topMin - SUB_RESERVE) end
	if ph > maxPh then
		ph = math.max(280, maxPh)
		panel.Size = UDim2.new(0, pw, 0, ph)
	end
	local topMax = vpY - ph - SUB_RESERVE
	local centered = (vpY - ph) * 0.5
	local top = math.min(math.max(centered, topMin), math.max(topMin, topMax))
	return top - vpY
end

--------------------------------------------------------------
-- LABEL KILLER  (hides any stray "Label" text floating in the world)
--------------------------------------------------------------
-- Any GUI text element whose Text is the default "Label" (or blank) is a
-- leftover placeholder. Our own UI never uses "Label", so this is safe.
local function killTextObj(d)
	if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
		if d.Text == "Label" or d.Text == "" then
			d.Text = ""
			d.Visible = false
			d.TextTransparency = 1
			d.TextStrokeTransparency = 1
			-- If it lives in a BillboardGui/SurfaceGui, disable the whole adornment.
			local gui = d:FindFirstAncestorWhichIsA("BillboardGui") or d:FindFirstAncestorWhichIsA("SurfaceGui")
			if gui then gui.Enabled = false end
		end
	end
end

-- Strict version for PlayerGui: ONLY the exact default "Label" (never blank),
-- and never touch our own UI (sg), whose labels legitimately start blank.
local function killGuiLabel(d)
	if d == sg or d:IsDescendantOf(sg) then return end
	if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text == "Label" then
		d.Text = ""
		d.Visible = false
		d.TextTransparency = 1
	end
end

-- Disable any leftover ScreenGui (e.g. an old "PilotUI" duplicate from
-- StarterGui) that isn't ours. This is what produces the floating "Label".
local function purgeLeftoverGuis()
	for _,g in ipairs(playerGui:GetChildren()) do
		if g ~= sg and g:IsA("LayerCollector") then
			local kill = (g.Name == "PilotUI")
			if not kill then
				for _,d in ipairs(g:GetDescendants()) do
					if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text == "Label" then
						kill = true; break
					end
				end
			end
			if kill then g.Enabled = false end
		end
	end
end

local function killDefaultLabels()
	if not M.active then return end
	for _,d in ipairs(workspace:GetDescendants()) do
		killTextObj(d)
	end
	for _,d in ipairs(playerGui:GetDescendants()) do
		killGuiLabel(d)
	end
	purgeLeftoverGuis()
end

-- Run several times to catch labels that stream in late.
for _,delaySec in ipairs({0, 0.25, 0.5, 1, 2, 4}) do
	task.delay(delaySec, killDefaultLabels)
end
-- Stored in M._conns and gated on M.active so they STOP the moment Aviation is
-- torn down. Otherwise these would keep firing through Chef/Nurse/Cyber and could
-- hide other worlds' text/GUIs (a skipped/finished world must not run scripts).
M._conns.wsLabels = workspace.DescendantAdded:Connect(function(d)
	if not M.active then return end
	killTextObj(d)
	for _,c in ipairs(d:GetDescendants()) do killTextObj(c) end
end)
M._conns.pgChild = playerGui.ChildAdded:Connect(function()
	if not M.active then return end
	task.wait(0.05)
	if not M.active then return end
	purgeLeftoverGuis()
end)
M._conns.pgDesc = playerGui.DescendantAdded:Connect(function(d)
	if not M.active then return end
	killGuiLabel(d)
	for _,c in ipairs(d:GetDescendants()) do killGuiLabel(c) end
end)

--------------------------------------------------------------
-- POST-FX
--------------------------------------------------------------
local cc    = Instance.new("ColorCorrectionEffect"); cc.Name="PilotCC"; cc.Parent=Lighting
local bloom = Instance.new("BloomEffect"); bloom.Name="PilotBloom"; bloom.Intensity=0.1; bloom.Size=24; bloom.Threshold=0.92; bloom.Parent=Lighting
local function setGrade(tint,bri,sat,dur) TweenService:Create(cc,TweenInfo.new(dur or 0.4),{TintColor=tint or Color3.new(1,1,1),Brightness=bri or 0,Saturation=sat or 0}):Play() end

-- One-time cinematic environment: calm, cool daylight + gentle aerial depth.
-- Tuned soft (not blown-out) — additive/non-destructive, and setGrade keeps
-- tweening cc/bloom on top for per-scene grades.
local function setupEnvironment()
	pcall(function()
		Lighting.Brightness             = 1.5
		Lighting.ExposureCompensation   = -0.05
		Lighting.OutdoorAmbient         = Color3.fromRGB(120, 138, 165)
		Lighting.Ambient                = Color3.fromRGB(58, 68, 86)
		Lighting.ClockTime              = 15.2
		Lighting.GeographicLatitude     = 41
		Lighting.EnvironmentDiffuseScale  = 0.75
		Lighting.EnvironmentSpecularScale = 0.6
		Lighting.GlobalShadows          = true
	end)
	pcall(function() Lighting.Technology = Enum.Technology.Future end)

	-- baseline post-FX: a faint cool tint, low contrast (setGrade animates on top per scene)
	cc.TintColor = Color3.fromRGB(232, 240, 255)
	cc.Brightness = 0.0; cc.Contrast = 0.03; cc.Saturation = -0.02
	bloom.Intensity = 0.12; bloom.Size = 24; bloom.Threshold = 1.2

	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atm=Instance.new("Atmosphere")
		atm.Density=0.22; atm.Offset=0.05
		atm.Color=Color3.fromRGB(190, 205, 230)
		atm.Decay=Color3.fromRGB(92, 118, 158)
		atm.Glare=0.05; atm.Haze=0.8
		atm.Parent=Lighting
	end
	if not Lighting:FindFirstChild("PilotSunRays") then
		local sr=Instance.new("SunRaysEffect"); sr.Name="PilotSunRays"
		sr.Intensity=0.04; sr.Spread=0.4; sr.Parent=Lighting
	end
	if not Lighting:FindFirstChild("PilotDOF") then
		local dof=Instance.new("DepthOfFieldEffect"); dof.Name="PilotDOF"
		dof.FarIntensity=0.12; dof.FocusDistance=60; dof.InFocusRadius=140; dof.NearIntensity=0
		dof.Parent=Lighting
	end
end
setupEnvironment()

-- Soft world blur behind modal overlays (Career Exploration seamless look)
local uiBlur = Lighting:FindFirstChild("PilotUIBlur")
if not uiBlur then
	uiBlur = Instance.new("BlurEffect"); uiBlur.Name = "PilotUIBlur"; uiBlur.Size = 0; uiBlur.Parent = Lighting
end
local function blurIn(sz) TweenService:Create(uiBlur, TweenInfo.new(0.45), {Size = sz or 22}):Play() end
local function blurOut() TweenService:Create(uiBlur, TweenInfo.new(0.45), {Size = 0}):Play() end

--------------------------------------------------------------
-- VIGNETTE  (max 0.09)
--------------------------------------------------------------
local vig=Instance.new("ImageLabel"); vig.Size=UDim2.new(1,0,1,0); vig.BackgroundTransparency=1
vig.Image="rbxassetid://1316045217"; vig.ImageColor3=Color3.new(0,0,0); vig.ImageTransparency=1; vig.ZIndex=8; vig.Parent=sg
local function vigIn(a) TweenService:Create(vig,TweenInfo.new(0.45),{ImageTransparency=1-math.min(a or 0.09,0.09)}):Play() end
local function vigOut() TweenService:Create(vig,TweenInfo.new(0.45),{ImageTransparency=1}):Play() end

--------------------------------------------------------------
-- LETTERBOX
--------------------------------------------------------------
local lbT=Instance.new("Frame"); lbT.Size=UDim2.new(1,0,0,0); lbT.BackgroundColor3=Color3.new(0,0,0); lbT.BorderSizePixel=0; lbT.ZIndex=50; lbT.Parent=sg
local lbB=Instance.new("Frame"); lbB.Size=UDim2.new(1,0,0,0); lbB.Position=UDim2.new(0,0,1,0); lbB.BackgroundColor3=Color3.new(0,0,0); lbB.BorderSizePixel=0; lbB.ZIndex=50; lbB.Parent=sg
local LBH=0.07
local function lbIn(sp) local ti=TweenInfo.new(sp or 0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out);TweenService:Create(lbT,ti,{Size=UDim2.new(1,0,LBH,0)}):Play();TweenService:Create(lbB,ti,{Size=UDim2.new(1,0,LBH,0),Position=UDim2.new(0,0,1-LBH,0)}):Play() end
local function lbOut(sp) local ti=TweenInfo.new(sp or 0.35);TweenService:Create(lbT,ti,{Size=UDim2.new(1,0,0,0)}):Play();TweenService:Create(lbB,ti,{Size=UDim2.new(1,0,0,0),Position=UDim2.new(0,0,1,0)}):Play() end

--------------------------------------------------------------
-- BLACK FADE
--------------------------------------------------------------
local blackF=Instance.new("Frame"); blackF.Size=UDim2.new(1,0,1,0); blackF.BackgroundColor3=Color3.new(0,0,0); blackF.BackgroundTransparency=1; blackF.ZIndex=68; blackF.Visible=false; blackF.Parent=sg
local function fadeToBlack(dur) blackF.BackgroundTransparency=1;blackF.Visible=true;TweenService:Create(blackF,TweenInfo.new(dur or 0.5),{BackgroundTransparency=0}):Play();task.wait((dur or 0.5)+0.06) end
local function fadeFromBlack(dur) blackF.BackgroundTransparency=0;blackF.Visible=true;TweenService:Create(blackF,TweenInfo.new(dur or 0.5),{BackgroundTransparency=1}):Play();task.wait((dur or 0.5)+0.06);blackF.Visible=false end

--------------------------------------------------------------
-- WHITE CUT
--------------------------------------------------------------
local cutF=Instance.new("Frame"); cutF.Size=UDim2.new(1,0,1,0); cutF.BackgroundColor3=Color3.new(1,1,1); cutF.BackgroundTransparency=1; cutF.ZIndex=66; cutF.Parent=sg
local function gtaCut() cutF.BackgroundTransparency=0;TweenService:Create(cutF,TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=1}):Play();task.wait(0.05) end

--------------------------------------------------------------
-- FLASH (for feedback)
--------------------------------------------------------------
local flashF=Instance.new("Frame"); flashF.Size=UDim2.new(1,0,1,0); flashF.BackgroundColor3=Color3.new(1,1,1); flashF.BackgroundTransparency=1; flashF.ZIndex=64; flashF.Parent=sg
local function flash(col,amt,dur) flashF.BackgroundColor3=col or Color3.new(1,1,1);flashF.BackgroundTransparency=1-(amt or 0.4);TweenService:Create(flashF,TweenInfo.new(dur or 0.3),{BackgroundTransparency=1}):Play() end

--------------------------------------------------------------
-- GTA LOCATION CARD
--------------------------------------------------------------
local locCard=Instance.new("Frame"); locCard.Size=UDim2.new(0,440,0,54); locCard.Position=UDim2.new(0,-450,1-LBH,LOC_Y); locCard.BackgroundTransparency=1; locCard.Visible=false; locCard.ZIndex=55; locCard.Parent=sg
local locBar=Instance.new("Frame"); locBar.Size=UDim2.new(0,0,0,2); locBar.BackgroundColor3=C.accent; locBar.BorderSizePixel=0; locBar.ZIndex=56; locBar.Parent=locCard
local locName=mkLbl(locCard,"",20,Enum.Font.GothamBold,C.text,Enum.TextXAlignment.Left,56); locName.Size=UDim2.new(1,0,0,26); locName.Position=UDim2.new(0,0,0,6)
local locSub=mkLbl(locCard,"",11,Enum.Font.GothamMedium,C.accent,Enum.TextXAlignment.Left,56); locSub.Size=UDim2.new(1,0,0,15); locSub.Position=UDim2.new(0,0,0,34)
local function showLocCard(name,sub,hold)
	if M.locThr then pcall(task.cancel,M.locThr) end
	locName.Text=name;locSub.Text=sub or "";locName.TextTransparency=0;locSub.TextTransparency=0
	locBar.Size=UDim2.new(0,0,0,2);locCard.Position=UDim2.new(0,-450,1-LBH,LOC_Y);locCard.Visible=true
	TweenService:Create(locCard,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.new(0,PAD,1-LBH,LOC_Y)}):Play()
	TweenService:Create(locBar,TweenInfo.new(0.55),{Size=UDim2.new(1,0,0,2)}):Play()
	M.locThr=task.spawn(function()
		task.wait(hold or 1.6)
		TweenService:Create(locName,TweenInfo.new(0.3),{TextTransparency=1}):Play()
		TweenService:Create(locSub,TweenInfo.new(0.3),{TextTransparency=1}):Play()
		TweenService:Create(locBar,TweenInfo.new(0.3),{Size=UDim2.new(0,0,0,2)}):Play()
		task.wait(0.35);locCard.Visible=false
	end)
end

--------------------------------------------------------------
-- SUBTITLE
--------------------------------------------------------------
local subF=Instance.new("Frame"); subF.Size=UDim2.new(0,SUB_W,0,SUB_H); subF.Position=UDim2.new(0.5,-SUB_W/2,1,SUB_Y); subF.BackgroundColor3=C.panel; subF.BackgroundTransparency=0.35; subF.Visible=false; subF.ZIndex=16; subF.Parent=sg; mkC(subF,8); mkS(subF,C.border,1).Transparency=0.3
local subL=mkLbl(subF,"",13,Enum.Font.GothamMedium,C.text,Enum.TextXAlignment.Center,17); subL.Size=UDim2.new(1,0,1,0)
local function layoutSubPosition()
	subF.Position = UDim2.new(0.5, -SUB_W / 2, 1, SUB_Y)
end
local function showSub(t)
	if M.activeModal and M.activeModal.Visible then return end
	subL.Text=t; subF.Visible=true; subL.TextTransparency=0
	layoutSubPosition()
end
local function hideSub() TweenService:Create(subL,TweenInfo.new(0.28),{TextTransparency=1}):Play();task.delay(0.3,function() subF.Visible=false end) end

--------------------------------------------------------------
-- SCORE DISPLAY (top-right)
--------------------------------------------------------------
local scoreF=Instance.new("Frame"); scoreF.Size=UDim2.new(0,SCORE_W,0,SCORE_H); scoreF.Position=UDim2.new(1,-(SCORE_W+PAD),0,SAFE_TOP); scoreF.Visible=false; scoreF.ZIndex=12; scoreF.Parent=sg; mkGlass(scoreF,0.32)
local scoreCap=mkLbl(scoreF,"SCORE",9,Enum.Font.GothamMedium,C.textMut,Enum.TextXAlignment.Center,13); scoreCap.Size=UDim2.new(1,0,0,14); scoreCap.Position=UDim2.new(0,0,0,6)
local scoreV=mkLbl(scoreF,"0",22,Enum.Font.GothamBold,C.text,Enum.TextXAlignment.Center,13); scoreV.Size=UDim2.new(1,0,0,28); scoreV.Position=UDim2.new(0,0,0,18)

-- Pop text (center screen)
local popL=Instance.new("TextLabel"); popL.Size=UDim2.new(0,520,0,58); popL.Position=UDim2.new(0.5,-260,0,POP_Y); popL.BackgroundTransparency=1; popL.Font=Enum.Font.GothamBold; popL.TextSize=34; popL.TextStrokeTransparency=0.5; popL.ZIndex=58; popL.Text=""; popL.TextTransparency=1; popL.Parent=sg
local function popText(t,col,sz)
	if M.popThr then pcall(task.cancel,M.popThr) end
	local full=sz or 36
	popL.Text=t;popL.TextColor3=col or C.text;popL.TextTransparency=0;popL.Position=UDim2.new(0.5,-260,0,POP_Y)
	popL.TextSize=math.floor(full*0.6)
	TweenService:Create(popL,TweenInfo.new(0.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{TextSize=full}):Play()
	M.popThr=task.spawn(function() task.wait(0.5);TweenService:Create(popL,TweenInfo.new(1.0,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=1,Position=UDim2.new(0.5,-260,0,POP_Y-50)}):Play();task.wait(1.1);popL.Text="" end)
end

--------------------------------------------------------------
-- SCENARIO BANNER
--------------------------------------------------------------
local scenBanner=Instance.new("Frame"); scenBanner.Size=UDim2.new(0,SCEN_W,0,SCEN_H); scenBanner.Position=UDim2.new(0.5,-SCEN_W/2,0,-SCEN_H-8); scenBanner.Visible=false; scenBanner.ZIndex=56; scenBanner.Parent=sg; mkGlass(scenBanner,0.28)
local scenTxt=mkLbl(scenBanner,"",13,Enum.Font.GothamMedium,C.text,Enum.TextXAlignment.Center,57); scenTxt.Size=UDim2.new(1,-24,1,0); scenTxt.Position=UDim2.new(0,12,0,0)
local function showScenBanner(icon,text,bgCol)
	scenTxt.Text=(icon and icon~="" and (icon.."   ") or "")..(text or "")
	playSfx("whoosh",0.35)
	scenBanner.Visible=true; scenBanner.Position=UDim2.new(0.5,-SCEN_W/2,0,-SCEN_H-8)
	TweenService:Create(scenBanner,TweenInfo.new(0.45,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.new(0.5,-SCEN_W/2,0,SCEN_Y)}):Play()
	task.delay(4,function() TweenService:Create(scenBanner,TweenInfo.new(0.35,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{Position=UDim2.new(0.5,-SCEN_W/2,0,-SCEN_H-8)}):Play();task.delay(0.35,function() scenBanner.Visible=false end) end)
end

--------------------------------------------------------------
-- CAMERA / HEAD-LOOK SYSTEM
--------------------------------------------------------------
local HEAD_YAW_MAX   = math.rad(85); local HEAD_PITCH_MAX = math.rad(65); local HEAD_PITCH_MIN = math.rad(-55)
local HEAD_LERP      = 0.10; local IDLE_SWAY = 0.0006; local COCKPIT_FOV = 78

M._conns.head = RS.RenderStepped:Connect(function(dt)
	if not M.headLookActive or M.aborted then return end
	local delta=UIS:GetMouseDelta()
	M.headYaw   = math.clamp(M.headYaw   - delta.X*0.0022, -M.HEAD_YAW_MAX,  M.HEAD_YAW_MAX)
	M.headPitch = math.clamp(M.headPitch - delta.Y*0.0018,  M.HEAD_PITCH_MIN, M.HEAD_PITCH_MAX)
	M.smoothYaw   = M.smoothYaw   + (M.headYaw   - M.smoothYaw)   * HEAD_LERP
	M.smoothPitch = M.smoothPitch + (M.headPitch - M.smoothPitch) * HEAD_LERP
	M.idleT = M.idleT + dt
	local swayX=math.sin(M.idleT*0.38)*IDLE_SWAY; local swayY=math.sin(M.idleT*0.55)*IDLE_SWAY*0.6
	camera.CFrame = M.cockpitBaseCF * CFrame.Angles(0,M.smoothYaw,0) * CFrame.Angles(M.smoothPitch+swayX,swayY,0)
	camera.FieldOfView = COCKPIT_FOV
end)

local function takeCam() camera.CameraType=Enum.CameraType.Scriptable; lockPlayer() end

local function releaseCam()
	camera.CameraType=Enum.CameraType.Scriptable
	camera.FieldOfView=COCKPIT_FOV; lockPlayer()
end

local function activateHeadLook(baseCF)
	M.cockpitBaseCF=baseCF; M.headYaw=0; M.headPitch=0; M.smoothYaw=0; M.smoothPitch=0
	M.headLookActive=true; hideMouse()
end

local function enterTaskMode()
	-- Lock camera softly to forward, show cursor
	M.headLookActive=false
	camera.CFrame=M.cockpitBaseCF  -- snap to center
	showMouse()
end

local function exitTaskMode()
	-- Resume head-look
	hideMouse()
	M.headLookActive=true
end

local function getCP(name)
	-- 1. Search PilotWorld/CameraPoints (original location)
	local pw=workspace:FindFirstChild("PilotWorld"); local cps=pw and pw:FindFirstChild("CameraPoints")
	local cp=cps and cps:FindFirstChild(name)
	-- 2. Search inside PlaneModel (CP_Cockpit dragged in there moves with plane)
	if not cp then
		local pm=workspace:FindFirstChild("PlaneModel")
		if pm then cp=pm:FindFirstChild(name,true) end
	end
	-- 3. Search entire workspace as last resort
	if not cp then cp=workspace:FindFirstChild(name,true) end
	if not cp then return camera.CFrame end
	return cp.CFrame
end

local function getPWPart(name)
	local pw=workspace:FindFirstChild("PilotWorld"); return pw and pw:FindFirstChild(name)
end

local function awaitE(timeout)
	local hit=false;local c
	c=UIS.InputBegan:Connect(function(inp,gp) if not gp and inp.KeyCode==Enum.KeyCode.E then hit=true end end)
	local t=0;while not hit and t<(timeout or 30) do t=t+task.wait(0.05) end;c:Disconnect();return hit
end

--------------------------------------------------------------
-- TASK PANEL  (top-left)
--------------------------------------------------------------
local taskPanel=Instance.new("Frame"); taskPanel.Size=UDim2.new(0,TASK_W,0,TASK_H); taskPanel.Position=UDim2.new(0,-(TASK_W+PAD),0,SAFE_TOP); taskPanel.Visible=false; taskPanel.ZIndex=12; taskPanel.Parent=sg; mkGlass(taskPanel,0.32)
local tpHdrL=mkLbl(taskPanel,"Flight Plan",14,Enum.Font.GothamBold,C.text,Enum.TextXAlignment.Left,14); tpHdrL.Size=UDim2.new(1,-24,0,22); tpHdrL.Position=UDim2.new(0,16,0,14)
local tpBody=Instance.new("Frame"); tpBody.Size=UDim2.new(1,-24,1,-48); tpBody.Position=UDim2.new(0,16,0,42); tpBody.BackgroundTransparency=1; tpBody.ZIndex=13; tpBody.Parent=taskPanel; mkL(tpBody,4)

local TASK_DEFS={"Pre-Flight Check","Cockpit Startup","In-Flight","Landing"}
local taskRows={}
for i,name in ipairs(TASK_DEFS) do
	local row=Instance.new("Frame");row.Size=UDim2.new(1,0,0,28);row.BackgroundTransparency=1;row.LayoutOrder=i;row.ZIndex=14;row.Parent=tpBody
	local lbl=mkLbl(row,name,12,Enum.Font.GothamMedium,C.textMut,Enum.TextXAlignment.Left,15);lbl.Size=UDim2.new(1,0,1,0)
	taskRows[i]={lbl=lbl}
end

local function setTaskActive(idx)
	for i,r in ipairs(taskRows) do
		if i<idx then r.lbl.TextColor3=C.textSec;r.lbl.Font=Enum.Font.GothamMedium;r.lbl.TextTransparency=0.55
		elseif i==idx then r.lbl.TextColor3=C.text;r.lbl.Font=Enum.Font.GothamBold;r.lbl.TextTransparency=0
		else r.lbl.TextColor3=C.textMut;r.lbl.Font=Enum.Font.GothamMedium;r.lbl.TextTransparency=0.35 end
	end
end

local function showTaskPanel()
	taskPanel.Visible=true;taskPanel.Position=UDim2.new(0,-(TASK_W+PAD),0,SAFE_TOP)
	TweenService:Create(taskPanel,TweenInfo.new(0.55,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.new(0,PAD,0,SAFE_TOP)}):Play()
end

--------------------------------------------------------------
-- TUTORIAL SCREEN
--------------------------------------------------------------
local tutOv=Instance.new("Frame"); tutOv.Size=UDim2.new(1,0,1,0); tutOv.BackgroundColor3=Color3.new(0,0,0); tutOv.BackgroundTransparency=0.55; tutOv.Visible=false; tutOv.ZIndex=38; tutOv.Parent=sg
local tutP=Instance.new("Frame"); tutP.Size=UDim2.new(0,420,0,440); tutP.Position=UDim2.new(0.5,-210,0.5,-220); tutP.ZIndex=39; tutP.Parent=tutOv; mkGlass(tutP, PANEL_TRANS)
local tutTitleL=mkLbl(tutP,"Career Quest",22,Enum.Font.GothamBold,C.text,Enum.TextXAlignment.Center,41); tutTitleL.Size=UDim2.new(1,-40,0,36); tutTitleL.Position=UDim2.new(0,20,0,28)
local tutSubL=mkLbl(tutP,"Pilot World  ·  Flight VA-001",12,Enum.Font.GothamMedium,C.textMut,Enum.TextXAlignment.Center,41); tutSubL.Size=UDim2.new(1,-40,0,18); tutSubL.Position=UDim2.new(0,20,0,66)
local tutTxt=mkLbl(tutP,"",12,Enum.Font.GothamMedium,C.textSec,Enum.TextXAlignment.Left,41); tutTxt.Size=UDim2.new(1,-48,0,200); tutTxt.Position=UDim2.new(0,24,0,100); tutTxt.TextWrapped=true; tutTxt.TextYAlignment=Enum.TextYAlignment.Top; tutTxt.LineHeight=1.15
tutTxt.Text="Welcome aboard, Captain.\n\nYou'll work through four stations — pre-flight, startup, in-flight, and landing — using the cockpit instruments directly.\n\nW / S throttle the engines. Click to interact. Press E to confirm."
local tutBtn=mkMenuBtn(tutP, "BEGIN FLIGHT", UDim2.new(0,280,0,48), UDim2.new(0.5,-140,1,-88), 41)
local tutHintL=mkLbl(tutP,"Press E to start",11,Enum.Font.GothamMedium,C.textMut,Enum.TextXAlignment.Center,41); tutHintL.Size=UDim2.new(1,-40,0,16); tutHintL.Position=UDim2.new(0,20,1,-28)
local btnPulse=TweenService:Create(tutBtn,TweenInfo.new(1.1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{BackgroundColor3=Color3.fromRGB(240,244,248)})
-- tutWaiting/gameFlowStarted/taskFlowActive live on M

local function showTutorialUI()
	showMouse()
	M.tutWaiting=true
	tutP.Position=UDim2.new(0.5,-210,0.58,-220); tutP.BackgroundTransparency=1
	tutOv.BackgroundTransparency=1; tutOv.Visible=true
	blurIn()
	TweenService:Create(tutOv,TweenInfo.new(0.4),{BackgroundTransparency=0.55}):Play()
	TweenService:Create(tutP,TweenInfo.new(0.5,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.new(0.5,-210,0.5,-220),BackgroundTransparency=PANEL_TRANS}):Play()
	task.delay(0.35,function() btnPulse:Play() end)
end

--------------------------------------------------------------
-- PLANE TRACKING SYSTEM
--------------------------------------------------------------

-- Speed overlay (motion blur vignette during takeoff)
local speedVig=Instance.new("ImageLabel"); speedVig.Size=UDim2.new(1,0,1,0); speedVig.BackgroundTransparency=1
speedVig.Image="rbxassetid://1316045217"; speedVig.ImageColor3=Color3.new(0,0,0); speedVig.ImageTransparency=1; speedVig.ZIndex=9; speedVig.Parent=sg
local function speedBlur(a) TweenService:Create(speedVig,TweenInfo.new(0.3),{ImageTransparency=1-math.min(a,0.22)}):Play() end
local function speedClear() TweenService:Create(speedVig,TweenInfo.new(0.6),{ImageTransparency=1}):Play() end

-- Altitude HUD
local altHud=Instance.new("Frame"); altHud.Size=UDim2.new(0,ALT_W,0,ALT_H); altHud.Position=UDim2.new(1,-(ALT_W+PAD),0,SAFE_TOP); altHud.Visible=false; altHud.ZIndex=12; altHud.Parent=sg; mkGlass(altHud,0.32)
local altCap=mkLbl(altHud,"ALTITUDE",9,Enum.Font.GothamMedium,C.textMut,Enum.TextXAlignment.Center,13); altCap.Size=UDim2.new(1,0,0,14); altCap.Position=UDim2.new(0,0,0,6)
local altVal=mkLbl(altHud,"0 ft",18,Enum.Font.GothamBold,C.text,Enum.TextXAlignment.Center,13); altVal.Size=UDim2.new(1,0,0,26); altVal.Position=UDim2.new(0,0,0,18)

local function refreshHudLayout()
	scoreF.Position = UDim2.new(1, -(SCORE_W + PAD), 0, SAFE_TOP)
	local altY = SAFE_TOP
	if scoreF.Visible then altY = SAFE_TOP + SCORE_H + GAP end
	altHud.Position = UDim2.new(1, -(ALT_W + PAD), 0, altY)
end

M._conns.cp = RS.RenderStepped:Connect(function()
	if not M.planeTracking or M.aborted then return end
	-- Prefer the CP_Cockpit INSIDE the plane so the camera follows the plane as it moves.
	local cp = M.planeModel and M.planeModel:FindFirstChild("CP_Cockpit", true)
	if not cp then
		local cpf = getPWPart("CameraPoints")
		cp = cpf and cpf:FindFirstChild("CP_Cockpit")
	end
	if cp then M.cockpitBaseCF = cp.CFrame end
end)

local function setupPlaneTracking()
	M.planeModel = workspace:FindFirstChild("PlaneModel")
		or workspace:FindFirstChild("Boeing - 787")
		or workspace:FindFirstChild("Plane")
	if not M.planeModel then warn("[Pilot] PlaneModel not found!"); return end

	M.planeBodyAnchor = M.planeModel:FindFirstChild("BodyAnchor", true)
	if not M.planeBodyAnchor or not M.planeBodyAnchor:IsA("BasePart") then
		for _,p in ipairs(M.planeModel:GetDescendants()) do
			if p:IsA("BasePart") and (p.Name=="Body" or p.Name=="BodyAnchor" or p.Name=="MainBody") then
				M.planeBodyAnchor=p; break
			end
		end
		if not M.planeBodyAnchor then
			for _,p in ipairs(M.planeModel:GetDescendants()) do
				if p:IsA("BasePart") then M.planeBodyAnchor=p; break end
			end
		end
	end

	if not M.planeBodyAnchor then warn("[Pilot] BodyAnchor not found!"); return end
	if not M.planeModel.PrimaryPart then M.planeModel.PrimaryPart = M.planeBodyAnchor end

	-- Capture the parked pose ONCE, before any takeoff motion. This is the exact
	-- on-the-runway pose we return to for landing (correct height + heading).
	if not M.planeHomeCF then M.planeHomeCF = M.planeModel:GetPivot() end

	M.planeTracking = true
end

local function enterGameplayCockpit()
	blurOut()
	blackF.Visible=false
	blackF.BackgroundTransparency=1
	lbOut(0.01)
	vigOut()
	local cockpitCF=getCP("CP_Cockpit")
	releaseCam()
	camera.CFrame=cockpitCF
	setupPlaneTracking()
	M.planeTracking=true
	activateHeadLook(cockpitCF)
end

local function showPreTaskHUD()
	setTaskActive(1)
	showTaskPanel()
	scoreF.Visible=true
	refreshHudLayout()
end

-- [E] QTE banner
local function showFlightEvent(title, detail, timeout)
	local ef=Instance.new("Frame"); ef.Size=UDim2.new(0,440,0,72); ef.Position=UDim2.new(0.5,-220,0,POP_Y+20); ef.BackgroundColor3=Color3.fromRGB(40,30,10); ef.ZIndex=30; ef.Parent=sg; mkC(ef,10); mkS(ef,C.warn,2)
	local t1=mkLbl(ef,title,15,Enum.Font.GothamBlack,C.warn,Enum.TextXAlignment.Center,31); t1.Size=UDim2.new(1,0,0,28); t1.Position=UDim2.new(0,0,0,6)
	local t2=mkLbl(ef,detail,10,Enum.Font.Code,C.textMut,Enum.TextXAlignment.Center,31); t2.Size=UDim2.new(1,0,0,16); t2.Position=UDim2.new(0,0,0,36)
	local tb=Instance.new("Frame"); tb.Size=UDim2.new(0.85,0,0,4); tb.Position=UDim2.new(0.075,0,1,-6); tb.BackgroundColor3=Color3.fromRGB(60,55,40); tb.ZIndex=31; tb.Parent=ef; mkC(tb,2)
	local tf=Instance.new("Frame"); tf.Size=UDim2.new(1,0,1,0); tf.BackgroundColor3=C.warn; tf.ZIndex=32; tf.Parent=tb; mkC(tf,2)
	TweenService:Create(tf,TweenInfo.new(timeout or 3,Enum.EasingStyle.Linear),{Size=UDim2.new(0,0,1,0)}):Play()
	flash(C.warn,0.28,0.22)
	local hit = awaitE(timeout or 3)
	TweenService:Create(ef,TweenInfo.new(0.2),{BackgroundTransparency=1}):Play()
	for _,ch in ipairs(ef:GetChildren()) do if ch:IsA("GuiObject") then TweenService:Create(ch,TweenInfo.new(0.2),{BackgroundTransparency=1}):Play() end end
	task.delay(0.25,function() ef:Destroy() end)
	return hit
end

-- Attach exports for task/handler modules
M.TweenService = TweenService
M.Players = Players
M.UIS = UIS
M.RS = RS
M.ReplicatedStorage = ReplicatedStorage
M.Lighting = Lighting
M.SoundService = SoundService
M.player = player
M.playerGui = playerGui
M.camera = camera
M.SFX = SFX
M.MUSIC = MUSIC
M.sndFolder = sndFolder
M.musicSound = musicSound
M.ambSound = ambSound
M.ShowTutorial = ShowTutorial
M.PlayerReady = PlayerReady
M.ClientReady = ClientReady
M.StartCinematic = StartCinematic
M.CinematicDone = CinematicDone
M.StartTask = StartTask
M.TaskComplete = TaskComplete
M.ScoreUpdate = ScoreUpdate
M.ShowResults = ShowResults
M.C = C
M.PANEL_TRANS = PANEL_TRANS
M.GLASS_R = GLASS_R
M.sg = sg
M.PAD = PAD
M.SAFE_TOP = SAFE_TOP
M.TASK_W = TASK_W
M.TASK_H = TASK_H
M.SCORE_W = SCORE_W
M.SCORE_H = SCORE_H
M.ALT_W = ALT_W
M.ALT_H = ALT_H
M.SCEN_W = SCEN_W
M.SCEN_H = SCEN_H
M.SUB_W = SUB_W
M.SUB_H = SUB_H
M.SPD_W = SPD_W
M.SPD_H = SPD_H
M.BOTTOM_PAD = BOTTOM_PAD
M.GAP = GAP
M.SCEN_Y = SCEN_Y
M.THR_X = THR_X
M.THR_Y = THR_Y
M.HUD_MSG_Y = HUD_MSG_Y
M.LOC_Y = LOC_Y
M.SUB_Y = SUB_Y
M.SPD_Y = SPD_Y
M.SUB_RESERVE = SUB_RESERVE
M.POP_Y = POP_Y
M.cc = cc
M.bloom = bloom
M.uiBlur = uiBlur
M.vig = vig
M.lbT = lbT
M.lbB = lbB
M.LBH = LBH
M.blackF = blackF
M.cutF = cutF
M.locCard = locCard
M.locBar = locBar
M.locName = locName
M.locSub = locSub
M.subF = subF
M.subL = subL
M.scoreF = scoreF
M.scoreCap = scoreCap
M.scoreV = scoreV
M.popL = popL
M.scenBanner = scenBanner
M.scenTxt = scenTxt
M.HEAD_YAW_MAX = HEAD_YAW_MAX
M.HEAD_PITCH_MAX = HEAD_PITCH_MAX
M.HEAD_PITCH_MIN = HEAD_PITCH_MIN
M.HEAD_LERP = HEAD_LERP
M.IDLE_SWAY = IDLE_SWAY
M.COCKPIT_FOV = COCKPIT_FOV
M.speedVig = speedVig
M.altHud = altHud
M.altCap = altCap
M.altVal = altVal
M.taskPanel = taskPanel
M.tpHdrL = tpHdrL
M.tpBody = tpBody
M.taskRows = taskRows
M.tutOv = tutOv
M.tutP = tutP
M.tutTitleL = tutTitleL
M.tutSubL = tutSubL
M.tutTxt = tutTxt
M.tutBtn = tutBtn
M.tutHintL = tutHintL
M.btnPulse = btnPulse
M.lockPlayer = lockPlayer
M.lockFP = lockFP
M.showMouse = showMouse
M.hideMouse = hideMouse
M.playSfx = playSfx
M.playMusic = playMusic
M.stopMusic = stopMusic
M.playAmbience = playAmbience
M.stopAmbience = stopAmbience
M.mkLbl = mkLbl
M.mkC = mkC
M.mkS = mkS
M.mkL = mkL
M.mkGlass = mkGlass
M.mkMenuBtn = mkMenuBtn
M.mkBtn = mkBtn
M.setGrade = setGrade
M.vigIn = vigIn
M.vigOut = vigOut
M.lbIn = lbIn
M.lbOut = lbOut
M.fadeToBlack = fadeToBlack
M.fadeFromBlack = fadeFromBlack
M.gtaCut = gtaCut
M.flash = flash
M.showLocCard = showLocCard
M.showSub = showSub
M.hideSub = hideSub
M.popText = popText
M.showScenBanner = showScenBanner
M.takeCam = takeCam
M.releaseCam = releaseCam
M.activateHeadLook = activateHeadLook
M.enterTaskMode = enterTaskMode
M.exitTaskMode = exitTaskMode
M.getCP = getCP
M.getPWPart = getPWPart
M.awaitE = awaitE
M.setTaskActive = setTaskActive
M.showTaskPanel = showTaskPanel
M.showTutorialUI = showTutorialUI
M.enterGameplayCockpit = enterGameplayCockpit
M.showPreTaskHUD = showPreTaskHUD
M.refreshHudLayout = refreshHudLayout
M.layoutModalPanel = layoutModalPanel
M.layoutSubPosition = layoutSubPosition
M.setupPlaneTracking = setupPlaneTracking
M.speedBlur = speedBlur
M.speedClear = speedClear
M.blurIn = blurIn
M.blurOut = blurOut
M.showFlightEvent = showFlightEvent

--------------------------------------------------------------
-- TEARDOWN (FBLA)
-- Fully stops the pilot game and restores normal third-person control so the
-- next career world (Chef) is unaffected. Safe to call more than once.
--------------------------------------------------------------
function M.teardown()
	M.active = false
	M.aborted = true
	M.headLookActive = false
	M.planeTracking = false
	M.taskRunning = false
	M.taskFlowActive = false
	M.activeTaskIdx = nil
	M.activeModal = nil

	-- FBLA: a skip can land while the intro cinematic or a task flow is parked in
	-- one of its many task.wait()s. Those coroutines would otherwise resume *after*
	-- teardown and re-seat the player in the cockpit / re-grab the camera seconds
	-- later. Cancel them outright so a skipped Aviation world stops instantly.
	for _, th in ipairs({ M.cinematicThread, M.taskThread }) do
		if th then pcall(task.cancel, th) end
	end
	M.cinematicThread = nil
	M.taskThread = nil

	pcall(function() RS:UnbindFromRenderStep("PilotMouseLock") end)
	if M.stopFlightMotion then pcall(M.stopFlightMotion) end
	for _, c in pairs(M._conns) do
		pcall(function() c:Disconnect() end)
	end
	M._conns = {}

	pcall(function() if M.stopMusic then M.stopMusic() end end)
	pcall(function() if M.stopAmbience then M.stopAmbience() end end)

	-- FBLA: the Aviation world adds post-FX to Lighting (blur behind modals, DOF,
	-- color grade, bloom, sun rays). If the world is skipped while any of these are
	-- active — e.g. on the tutorial screen, which calls blurIn() — they'd linger in
	-- Lighting and make the next world (Chef) permanently blurry. Remove them all.
	pcall(function()
		for _, name in ipairs({ "PilotUIBlur", "PilotDOF", "PilotCC", "PilotBloom", "PilotSunRays" }) do
			local fx = Lighting:FindFirstChild(name)
			if fx then fx:Destroy() end
		end
	end)

	pcall(function()
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			camera.CameraSubject = hum
			hum.WalkSpeed = 16
			hum.JumpPower = 50
			hum.JumpHeight = 7.2
			hum.Sit = false
		end
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 128
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
	end)

	pcall(function() if sg then sg:Destroy() end end)
end

return M
