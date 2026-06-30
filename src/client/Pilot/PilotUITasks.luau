-- Pilot task flows (split to avoid Luau register limit)
local M = require(script.Parent:WaitForChild("PilotUIBase"))

function M.stopFlightMotion()
	if M.flightMotionConn then
		M.flightMotionConn:Disconnect()
		M.flightMotionConn = nil
	end
end

--------------------------------------------------------------
-- GTA INTRO CINEMATIC
--------------------------------------------------------------
local function playIntroCinematic()
	local ok, err = pcall(function()
		if M.aborted then return end
		-- Hide the avatar for all exterior + cockpit-entry shots.
		-- showLocalCharacter was called in StartCinematic to reset any hidden state,
		-- but the player shouldn't be visible during the cinematic camera sequence.
		pcall(M.hideLocalCharacter)
		M.takeCam(); M.lbIn(0.32); M.vigIn(0.08)
		M.setGrade(Color3.fromRGB(210,225,255),0.04,0.08,0.3)

		-- Probe whether the camera-point parts exist in this Studio place.
		-- getCP returns nil when a named part cannot be found anywhere in the workspace.
		-- With Roblox content streaming the parts may arrive a moment after the cinematic
		-- starts (the teleport that happened just before is what triggers the stream).
		-- Retry for up to ~4 seconds so the full cinematic fires once they load in.
		local cpTarmac
		do
			local waited = 0
			repeat
				cpTarmac = M.getCP("CP_Tarmac")
				if not cpTarmac then task.wait(0.25); waited = waited + 0.25 end
			until cpTarmac or waited >= 4 or M.aborted
		end
		local cpTerminal = M.getCP("CP_Terminal")
		local cpRunway   = M.getCP("CP_Runway")
		local cpExterior = M.getCP("CP_PlaneExterior")
		local cpCockpit  = M.getCP("CP_Cockpit")

		if cpTarmac then
			-- Full GTA-style 4-shot airport cinematic (camera points exist in Studio)
			M.fadeFromBlack(0.9)

			M.camera.CFrame = cpTarmac; task.wait(0.18)
			M.showLocCard("JOHN F. KENNEDY INTERNATIONAL","New York, USA  -  Gate 14",1.8); task.wait(2.2)

			M.gtaCut(); M.setGrade(Color3.fromRGB(226,234,248),0.01,0.02,0.18)
			if cpTerminal then M.camera.CFrame = cpTerminal end
			M.showLocCard("TERMINAL 4  -  DEPARTURE LEVEL","VOCA Airlines  -  Boarding now",1.0); task.wait(1.3)

			M.gtaCut(); M.setGrade(Color3.fromRGB(215,230,255),0.05,0.10,0.18)
			if cpRunway then M.camera.CFrame = cpRunway end
			M.showLocCard("RUNWAY 31L","Cleared for departure  -  Wind 270 / 12kts",1.0); task.wait(1.3)

			M.gtaCut(); M.setGrade(Color3.fromRGB(205,218,255),0.03,0.06,0.18)
			if cpExterior then M.camera.CFrame = cpExterior end
			M.showLocCard("BOEING 787  -  FLIGHT VA-001","All pre-flight checks complete",1.2); task.wait(1.6)
		else
			-- Camera points not yet placed in Studio — show a boarding title card instead
			-- so the game still flows cleanly without the broken 4-identical-shot glitch.
			-- To restore the full cinematic: add BasePart markers named CP_Tarmac,
			-- CP_Terminal, CP_Runway, CP_PlaneExterior, CP_Cockpit inside
			-- workspace > PilotWorld > CameraPoints (or directly inside PilotWorld).
			warn("[PilotUI] Camera point parts not found (CP_Tarmac etc.) — skipping exterior cinematic. Add them to PilotWorld/CameraPoints in Studio for the full 4-shot sequence.")
			M.fadeFromBlack(0.6)
			M.showLocCard("VOCA Airlines  —  Flight VA-001","Welcome aboard, Captain. Preparing for departure.",2.2)
			task.wait(2.5)
		end
		if M.aborted then return end

		-- Cockpit entry sequence (same whether or not exterior shots played)
		local char=M.player.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
		local seatPart=M.getPWPart("PilotSeat"); local hum=char and char:FindFirstChildOfClass("Humanoid")
		if hrp and seatPart then hrp.CFrame=CFrame.new(seatPart.Position+Vector3.new(0,3,0)) end
		if hum then hum.WalkSpeed=0;hum.JumpPower=0;hum.Sit=true end
		M.showSub("Entering the cockpit...")
		M.setGrade(Color3.fromRGB(195,212,255),0.02,0.04,0.5)
		if cpCockpit then M.camera.CFrame = cpCockpit end
		task.wait(0.6)
		M.hideSub(); task.wait(0.3)

		M.fadeToBlack(0.65)
		if M.aborted then return end
		local char2=M.player.Character; local hrp2=char2 and char2:FindFirstChild("HumanoidRootPart")
		local cockpitCF = cpCockpit or M.camera.CFrame
		if hrp2 then hrp2.CFrame=cockpitCF*CFrame.new(0,-1.5,0) end
		M.setGrade(Color3.fromRGB(224,236,255),0.02,0.0,0.5)
		M.TweenService:Create(M.bloom,TweenInfo.new(0.5),{Intensity=0.12,Threshold=1.15}):Play()
		if M.aborted then return end
		M.lbOut(0.01); M.vigOut(); M.releaseCam()
		M.camera.CFrame=cockpitCF
		M.setupPlaneTracking()
		M.planeTracking = true
		M.activateHeadLook(cockpitCF)
		task.wait(0.35)

		M.fadeFromBlack(0.95)
		task.wait(0.4)
		M.showSub("Welcome aboard, Captain. Your flight plan is ready.")
		task.wait(2.6); M.hideSub(); task.wait(0.3)
	end)
	if not ok then
		warn("[PilotUI] Cinematic error:", err)
	end

	if M.aborted then return end
	M.enterGameplayCockpit()
	M.showPreTaskHUD()
	M.activeModal = nil
	M.showSub("Preparing pre-flight checklist...")
	M.CinematicDone:FireServer()

	if not M.cinematicRetryArmed then
		M.cinematicRetryArmed = true
		task.delay(4, function()
			if M.aborted then return end
			if not M.taskFlowActive then
				warn("[PilotUI] M.StartTask delayed — retrying M.CinematicDone")
				M.CinematicDone:FireServer()
			end
		end)
	end
end

--------------------------------------------------------------
-- TASK HELPERS (shared UI primitives)
--------------------------------------------------------------
local function makePanel(w,h,bgCol,zi)
	local f=Instance.new("Frame"); f.Size=UDim2.new(0,w,0,h)
	f.Position=UDim2.new(0.5,-w/2,1,h+10)
	f.BackgroundColor3=bgCol or M.C.panel; f.ZIndex=zi or 22; f.Visible=false
	f.ClipsDescendants=true; f.Parent=M.sg; M.mkC(f,10)
	return f
end

local function slideIn(panel,targetY,dur)
	panel.Visible=true
	M.TweenService:Create(panel,TweenInfo.new(dur or 0.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
		{Position=UDim2.new(0.5,-panel.AbsoluteSize.X/2,1,targetY)}):Play()
	task.wait((dur or 0.45)+0.05)
end

local function slideInBelowTask(panel,dur)
	M.activeModal = panel
	M.hideSub()
	M.showMouse()
	panel.Visible=true
	local yOff=M.layoutModalPanel(panel)
	M.TweenService:Create(panel,TweenInfo.new(dur or 0.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
		{Position=UDim2.new(0.5,-panel.AbsoluteSize.X/2,1,yOff)}):Play()
	task.wait((dur or 0.45)+0.05)
end

local function slideOut(panel,dur)
	local w=panel.AbsoluteSize.X
	M.TweenService:Create(panel,TweenInfo.new(dur or 0.32,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
		{Position=UDim2.new(0.5,-w/2,1,panel.AbsoluteSize.Y+20)}):Play()
	task.wait((dur or 0.32)+0.05); panel.Visible=false
	if M.activeModal == panel then M.activeModal = nil end
end

local function flashPenalty(pts)
	M.popText("-"..pts.." pts",M.C.danger,28)
	M.flash(M.C.danger,0.22,0.3)
	M.playSfx("error",0.45)
end
local function flashBonus(pts,label)
	M.popText("+"..pts.." "..(label or "pts"),M.C.success,28)
	M.flash(M.C.success,0.15,0.25)
	M.playSfx("success",0.5)
end

--------------------------------------------------------------
-- TASK 1 — PRE-FLIGHT CHECKLIST  (normalized 0-100)
--------------------------------------------------------------
local function runPreFlight(scen)
	M.enterTaskMode()
	local scenCol=Color3.fromRGB((scen.col or {r=18,g=80,b=40}).r,(scen.col or {r=18,g=80,b=40}).g,(scen.col or {r=18,g=80,b=40}).b)
	task.delay(0.3,function() M.showScenBanner(scen.icon or "OK",scen.label or "Pre-Flight",scenCol) end)

	-- shared accuracy accumulator
	local penalty = 0
	local function takePenalty(pts) penalty = penalty + pts; flashPenalty(pts) end

	--------------------------------------------------
	-- PANEL SHELL
	--------------------------------------------------
	local panel=makePanel(400,480,M.C.panel,22)
	M.mkGlass(panel, M.PANEL_TRANS)

	local phdrL=M.mkLbl(panel,"Pre-Flight Checklist",18,Enum.Font.GothamBold,M.C.text,Enum.TextXAlignment.Center,24); phdrL.Size=UDim2.new(1,-24,0,28); phdrL.Position=UDim2.new(0,12,0,14)

	local pbody=Instance.new("ScrollingFrame"); pbody.Size=UDim2.new(1,-24,1,-52); pbody.Position=UDim2.new(0,12,0,48)
	pbody.BackgroundTransparency=1; pbody.BorderSizePixel=0; pbody.ZIndex=23; pbody.ScrollBarThickness=4
	pbody.ScrollBarImageColor3=M.C.border; pbody.CanvasSize=UDim2.new(0,0,0,0)
	pbody.AutomaticCanvasSize=Enum.AutomaticSize.Y; pbody.ScrollingDirection=Enum.ScrollingDirection.Y; pbody.Parent=panel
	M.mkL(pbody,8)

	--------------------------------------------------
	-- ITEM DESCRIPTORS  (each a hands-on mini-interaction)
	--------------------------------------------------
	local function shuffled(t)
		local a={}; for _,v in ipairs(t) do table.insert(a,v) end
		for i=#a,2,-1 do local j=math.random(i); a[i],a[j]=a[j],a[i] end
		return a
	end

	local fuelFault = scen.hasFault == true

	local items = {
		{label="1. Seat & Harness",    detail="Slide the harness to LOCKED",     kind="toggle"},
		{label="2. Instruments Check", detail="Set altimeter into the green band", kind="dial"},
		{label="3. Fuel Levels",       detail="Verify the fuel quantity",         kind="verify",
			reading = fuelFault and "26,310 KG   (BELOW MIN)" or "42,000 KG   (FULL)",
			correct = fuelFault and "report" or "confirm"},
		{label="4. Engine Systems",    detail="Hold to prime the fuel pumps",     kind="hold"},
		{label="5. Communications",    detail="Tune the correct ATC frequency",   kind="choice",
			prompt="Ground clearance frequency?",
			options = shuffled({ {t="121.90  GND",ok=true}, {t="118.30  TWR",ok=false}, {t="124.25  APP",ok=false} })},
	}
	if scen.hasWeather then
		table.insert(items, {label="6. Weather Brief", detail="Crosswind 35kt, low visibility", kind="choice",
			prompt="Departure decision?",
			options = shuffled({ {t="Divert to alternate",ok=true}, {t="Continue as filed",ok=false} })})
	end

	--------------------------------------------------
	-- ROW CONSTRUCTION
	--------------------------------------------------
	local itemRows={}
	for i,it in ipairs(items) do
		local row=Instance.new("Frame"); row.Size=UDim2.new(1,-4,0,62); row.BackgroundColor3=M.C.bg
		row.BackgroundTransparency=0.1; row.LayoutOrder=i; row.ZIndex=24; row.ClipsDescendants=true; row.Parent=pbody; M.mkC(row,8)

		local chkBox=Instance.new("Frame"); chkBox.Size=UDim2.new(0,40,0,42); chkBox.Position=UDim2.new(0,8,0,10)
		chkBox.BackgroundColor3=M.C.border; chkBox.BackgroundTransparency=0; chkBox.ZIndex=25; chkBox.Parent=row; M.mkC(chkBox,8)
		local chkLbl=M.mkLbl(chkBox,"",16,Enum.Font.GothamBold,M.C.text,Enum.TextXAlignment.Center,26); chkLbl.Size=UDim2.new(1,0,1,0)

		local lblName=M.mkLbl(row,it.label,13,Enum.Font.GothamBold,M.C.text,Enum.TextXAlignment.Left,25); lblName.Size=UDim2.new(1,-62,0,22); lblName.Position=UDim2.new(0,56,0,8)
		lblName.TextStrokeColor3=Color3.new(0,0,0); lblName.TextStrokeTransparency=0.4
		local lblDet=M.mkLbl(row,it.detail,11,Enum.Font.GothamMedium,M.C.textSec,Enum.TextXAlignment.Left,25); lblDet.Size=UDim2.new(1,-62,0,16); lblDet.Position=UDim2.new(0,56,0,32)
		lblDet.TextStrokeColor3=Color3.new(0,0,0); lblDet.TextStrokeTransparency=0.35

		local expand=Instance.new("Frame"); expand.Size=UDim2.new(1,-24,0,0); expand.Position=UDim2.new(0,12,0,64)
		expand.BackgroundTransparency=1; expand.ZIndex=26; expand.Visible=false; expand.Parent=row

		itemRows[i]={row=row,chkBox=chkBox,chkLbl=chkLbl,name=lblName,det=lblDet,expand=expand,done=false}
	end

	--------------------------------------------------
	-- PER-KIND CONTROL BUILDERS  -> return content height
	--------------------------------------------------
	local function buildControl(it, ir, finish)
		local area = ir.expand
		local kind = it.kind

		if kind=="toggle" then
			local track=Instance.new("Frame"); track.Size=UDim2.new(0,150,0,34); track.Position=UDim2.new(0,0,0,8)
			track.BackgroundColor3=Color3.fromRGB(120,60,55); track.ZIndex=26; track.Parent=area; M.mkC(track,17)
			local stat=M.mkLbl(track,"UNLOCKED",11,Enum.Font.GothamBlack,Color3.new(1,1,1),Enum.TextXAlignment.Center,27); stat.Size=UDim2.new(1,-34,1,0); stat.Position=UDim2.new(0,34,0,0)
			local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,28,0,28); knob.Position=UDim2.new(0,3,0.5,-14); knob.BackgroundColor3=Color3.fromRGB(245,245,245); knob.ZIndex=28; knob.Parent=track; M.mkC(knob,14)
			local btn=M.mkBtn(area,"",Color3.fromRGB(0,0,0),nil,UDim2.new(0,150,0,34),UDim2.new(0,0,0,8)); btn.BackgroundTransparency=1; btn.AutoButtonColor=false
			btn.MouseButton1Click:Connect(function()
				if ir.done then return end
				M.TweenService:Create(knob,TweenInfo.new(0.25,Enum.EasingStyle.Back),{Position=UDim2.new(1,-31,0.5,-14)}):Play()
				M.TweenService:Create(track,TweenInfo.new(0.25),{BackgroundColor3=M.C.success}):Play()
				stat.Text="LOCKED"
				task.delay(0.28,function() finish(0) end)
			end)
			return 50

		elseif kind=="dial" then
			local bar=Instance.new("Frame"); bar.Size=UDim2.new(1,0,0,18); bar.Position=UDim2.new(0,0,0,4); bar.BackgroundColor3=Color3.fromRGB(60,55,50); bar.ZIndex=26; bar.Parent=area; M.mkC(bar,4)
			local zone=Instance.new("Frame"); zone.Size=UDim2.new(0.16,0,1,0); zone.Position=UDim2.new(0.42,0,0,0); zone.BackgroundColor3=M.C.success; zone.BackgroundTransparency=0.25; zone.ZIndex=26; zone.Parent=bar; M.mkC(zone,3)
			local needle=Instance.new("Frame"); needle.Size=UDim2.new(0,4,1,8); needle.Position=UDim2.new(0,-2,0,-4); needle.BackgroundColor3=M.C.danger; needle.ZIndex=28; needle.Parent=bar; M.mkC(needle,2)
			local pos = (math.random()<0.5) and (0.05+math.random()*0.18) or (0.78+math.random()*0.15)
			local function place()
				needle.Position=UDim2.new(pos,-2,0,-4)
				local inZone = pos>=0.42 and pos<=0.58
				needle.BackgroundColor3 = inZone and M.C.success or M.C.danger
			end
			place()
			local function nudge(d) pos=math.clamp(pos+d,0,1); M.TweenService:Create(needle,TweenInfo.new(0.08),{Position=UDim2.new(pos,-2,0,-4)}):Play()
				task.delay(0.08,function() needle.BackgroundColor3=(pos>=0.42 and pos<=0.58) and M.C.success or M.C.danger end) end
			M.mkBtn(area,"<",Color3.fromRGB(70,90,140),nil,UDim2.new(0,46,0,30),UDim2.new(0,0,0,30)).MouseButton1Click:Connect(function() if not ir.done then nudge(-0.06) end end)
			M.mkBtn(area,">",Color3.fromRGB(70,90,140),nil,UDim2.new(0,46,0,30),UDim2.new(1,-46,0,30)).MouseButton1Click:Connect(function() if not ir.done then nudge(0.06) end end)
			M.mkBtn(area,"CONFIRM",M.C.accent,nil,UDim2.new(0,150,0,30),UDim2.new(0.5,-75,0,30)).MouseButton1Click:Connect(function()
				if ir.done then return end
				if pos>=0.42 and pos<=0.58 then finish(0)
				else takePenalty(8); M.flash(M.C.danger,0.18,0.25) end
			end)
			return 66

		elseif kind=="verify" then
			local read=M.mkLbl(area,it.reading or "",13,Enum.Font.GothamBlack,(it.correct=="report") and M.C.danger or M.C.ink,Enum.TextXAlignment.Center,27)
			read.Size=UDim2.new(1,0,0,22); read.Position=UDim2.new(0,0,0,2)
			local function decide(choice)
				if ir.done then return end
				if choice==it.correct then finish(0)
				else takePenalty(18); M.flash(M.C.danger,0.22,0.3); finish(0) end
			end
			M.mkBtn(area,"CONFIRM OK",M.C.success,Color3.fromRGB(8,30,22),UDim2.new(0.5,-6,0,32),UDim2.new(0,0,0,30)).MouseButton1Click:Connect(function() decide("confirm") end)
			M.mkBtn(area,"REPORT FAULT",M.C.amber,Color3.fromRGB(40,28,0),UDim2.new(0.5,-6,0,32),UDim2.new(0.5,6,0,30)).MouseButton1Click:Connect(function() decide("report") end)
			return 68

		elseif kind=="hold" then
			local btn=M.mkBtn(area,"HOLD TO PRIME",Color3.fromRGB(70,90,140),nil,UDim2.new(1,0,0,40),UDim2.new(0,0,0,8))
			local fill=Instance.new("Frame"); fill.Size=UDim2.new(0,0,1,0); fill.BackgroundColor3=M.C.success; fill.BackgroundTransparency=0.35; fill.ZIndex=27; fill.Parent=btn; M.mkC(fill,6)
			local holding=false; local prog=0; local conn
			local function stop(reset)
				holding=false
				if conn then conn:Disconnect(); conn=nil end
				if reset and not ir.done and prog<1 then
					if prog>0.1 then takePenalty(5) end
					prog=0; M.TweenService:Create(fill,TweenInfo.new(0.2),{Size=UDim2.new(0,0,1,0)}):Play()
				end
			end
			btn.MouseButton1Down:Connect(function()
				if ir.done then return end
				holding=true
				conn=M.RS.Heartbeat:Connect(function(dt)
					if not holding then return end
					prog=math.clamp(prog+dt/1.5,0,1)
					fill.Size=UDim2.new(prog,0,1,0)
					if prog>=1 then holding=false; if conn then conn:Disconnect(); conn=nil end; btn.Text="PRIMED"; finish(0) end
				end)
			end)
			btn.MouseButton1Up:Connect(function() stop(true) end)
			btn.MouseLeave:Connect(function() if holding then stop(true) end end)
			return 56

		else -- choice
			local pr=M.mkLbl(area,it.prompt or "Select:",12,Enum.Font.GothamBold,M.C.text,Enum.TextXAlignment.Left,27); pr.Size=UDim2.new(1,0,0,18); pr.Position=UDim2.new(0,0,0,0)
			local y=22
			for _,opt in ipairs(it.options) do
				-- Light cream bg needs dark text (btnText = dark navy) — NOT M.C.ink (near-white)
				local b=M.mkBtn(area,opt.t,Color3.fromRGB(235,233,222),M.C.btnText,UDim2.new(1,0,0,32),UDim2.new(0,0,0,y))
				M.mkS(b,Color3.fromRGB(160,152,135),1)
				b.MouseButton1Click:Connect(function()
					if ir.done then return end
					if opt.ok then M.TweenService:Create(b,TweenInfo.new(0.15),{BackgroundColor3=M.C.success}):Play(); finish(0)
					else takePenalty(12); M.flash(M.C.danger,0.18,0.25)
						M.TweenService:Create(b,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(255,200,195)}):Play()
						b.Active=false; b.AutoButtonColor=false; b.TextTransparency=0.5
					end
				end)
				y=y+38
			end
			return y+4
		end
	end

	--------------------------------------------------
	-- DRIVER
	--------------------------------------------------
	local allDone=false
	local activeIdx=0

	local function collapse(idx)
		local ir=itemRows[idx]
		ir.done=true; ir.chkLbl.Text="OK"; ir.chkBox.BackgroundColor3=M.C.success
		ir.expand.Visible=false
		-- Light-green done bg — keep text dark so it stays readable
		ir.name.TextColor3 = M.C.bg
		ir.det.TextColor3  = Color3.fromRGB(20,60,30)
		M.TweenService:Create(ir.row,TweenInfo.new(0.22,Enum.EasingStyle.Quad),{Size=UDim2.new(1,-4,0,62),BackgroundColor3=Color3.fromRGB(224,244,228)}):Play()
		M.flash(M.C.success,0.08,0.16)
	end

	local function activate(idx)
		activeIdx=idx
		local ir=itemRows[idx]; local it=items[idx]
		-- Light-blue active bg — switch text to dark so it's legible
		ir.name.TextColor3 = M.C.bg
		ir.det.TextColor3  = M.C.btnText
		M.TweenService:Create(ir.row,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(220,234,255)}):Play()
		local finished=false
		local function finish(addPen)
			if finished then return end
			finished=true
			collapse(idx)
			if idx<#items then task.delay(0.18,function() activate(idx+1) end)
			else task.delay(0.2,function() allDone=true end) end
		end
		local h=buildControl(it,ir,finish)
		ir.expand.Size=UDim2.new(1,-24,0,h)
		ir.expand.Visible=true
		M.TweenService:Create(ir.row,TweenInfo.new(0.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(1,-4,0,72+h)}):Play()
		task.wait(0.05)
		-- bring active row into view inside the scroller
		local relY=ir.row.AbsolutePosition.Y - pbody.AbsolutePosition.Y + pbody.CanvasPosition.Y
		M.TweenService:Create(pbody,TweenInfo.new(0.25),{CanvasPosition=Vector2.new(0,math.max(0,relY-10))}):Play()
	end

	slideInBelowTask(panel,0.45)
	activate(1)

	local t=0; while not allDone and t<90 do t=t+task.wait(0.1) end; allDone=true
	for _,ir in ipairs(itemRows) do if not ir.done then ir.done=true; ir.chkLbl.Text="OK"; ir.chkBox.BackgroundColor3=M.C.success; ir.expand.Visible=false end end
	task.wait(0.4); slideOut(panel)

	M.activeModal = nil
	local elapsed = t
	local timePenalty = math.clamp(math.floor((elapsed-35)*0.5), 0, 15)
	local score=math.clamp(100 - penalty - timePenalty, 0, 100)
	M.popText("Pre-Flight Complete!",M.C.success,32); M.exitTaskMode(); task.wait(0.8)
	M.TaskComplete:FireServer({score=score, bonusPts=(scen.bonusPts or 0), scenarioId=scen.id, failed=(score<40), taskIdx=M.activeTaskIdx})
end

--------------------------------------------------------------
-- TASK 2 — COCKPIT STARTUP  (normalized 0-100)
--------------------------------------------------------------
local function runStartup(scen)
	M.hideMouse()
	local scenCol=Color3.fromRGB((scen.col or {r=18,g=80,b=40}).r,(scen.col or {r=18,g=80,b=40}).g,(scen.col or {r=18,g=80,b=40}).b)
	task.delay(0.4,function() M.showScenBanner(scen.icon or "OK",scen.label or "Startup",scenCol) end)

	-- Widen head-look range + pull the viewpoint back so the whole overhead panel
	-- (including the upper/rear switches) is reachable with the center crosshair.
	local savedYawMax, savedPitchMax, savedPitchMin = M.HEAD_YAW_MAX, M.HEAD_PITCH_MAX, M.HEAD_PITCH_MIN
	local savedBaseCF = M.cockpitBaseCF
	M.HEAD_YAW_MAX   = math.rad(120)
	M.HEAD_PITCH_MAX = math.rad(92)
	M.HEAD_PITCH_MIN = math.rad(-72)
	M.cockpitBaseCF  = M.cockpitBaseCF * CFrame.new(0, 0, 1.4)
	M.headLookActive = true

	local xhair=Instance.new("Frame"); xhair.Size=UDim2.new(0,6,0,6); xhair.Position=UDim2.new(0.5,-3,0.5,-3); xhair.BackgroundColor3=M.C.text; xhair.BackgroundTransparency=0.2; xhair.ZIndex=60; xhair.Parent=M.sg; M.mkC(xhair,3)
	local xhairRing=Instance.new("Frame"); xhairRing.Size=UDim2.new(0,18,0,18); xhairRing.Position=UDim2.new(0.5,-9,0.5,-9); xhairRing.BackgroundTransparency=1; xhairRing.ZIndex=59; xhairRing.Parent=M.sg; M.mkS(xhairRing,M.C.text,1).Transparency=0.5; M.mkC(xhairRing,9)

	local hudF=Instance.new("Frame"); hudF.Size=UDim2.new(0,M.SUB_W,0,M.SUB_H); hudF.Position=UDim2.new(0.5,-M.SUB_W/2,1,M.SUB_Y); hudF.BackgroundColor3=M.C.panel; hudF.BackgroundTransparency=0.08; hudF.ZIndex=20; hudF.Parent=M.sg; M.mkC(hudF,8); M.mkS(hudF,M.C.amber,1.5)
	local hudL=M.mkLbl(hudF,"",12,Enum.Font.GothamBold,M.C.amber,Enum.TextXAlignment.Center,21); hudL.Size=UDim2.new(1,0,1,0)

	local SWITCH_SEQUENCE = {
		{name="firstswitch",  label="Battery",          col=M.C.accent},
		{name="secondswitch", label="APU Master",       col=M.C.accent},
		{name="thirdswitch",  label="Beacon",           col=M.C.accent},
		{name="fourthswitch", label="Anti-Ice",         col=M.C.amber},
		{name="fifthswitch",  label="Cockpit Displays", col=M.C.amber},
		{name="sixthswitch",  label="IRS Alignment",    col=M.C.success},
	}

	local switchesFolder = nil
	local pm = workspace:FindFirstChild("PlaneModel")
	if pm then
		local body = pm:FindFirstChild("Body")
		local dc   = body and body:FindFirstChild("DC_ASDLL")
		switchesFolder = dc and dc:FindFirstChild("Switches")
	end

	local spawnedParts = {}   -- hitboxes + fallback parts to clean up
	local switches = {}

	-- Find a hand-placed switch part anywhere in the world. Tries the Switches folder,
	-- then an exact recursive search, then a case-INSENSITIVE match so "FirstSwitch",
	-- "First Switch", etc. still resolve. Prints the result to the F9 console.
	local function findSwitchPart(name)
		if switchesFolder then
			local f = switchesFolder:FindFirstChild(name)
			if f then return f end
		end
		local exact = workspace:FindFirstChild(name, true)
		if exact then return exact end
		local target = string.lower((name:gsub("%s+", "")))
		for _, d in ipairs(workspace:GetDescendants()) do
			if (d:IsA("BasePart") or d:IsA("Model"))
				and string.lower((d.Name:gsub("%s+", ""))) == target then
				return d
			end
		end
		return nil
	end

	local foundCount = 0
	for i, sw in ipairs(SWITCH_SEQUENCE) do
		-- locate the REAL switch instance (Model or BasePart)
		local obj = findSwitchPart(sw.name)
		if obj then
			foundCount += 1
		else
			warn(("[Startup] %s -> NOT FOUND; drawing a fallback near the panel"):format(sw.name))
		end
		local isModel = false

		-- collect the real BaseParts so we can target the actual lever, not a bounding centre
		local parts = {}
		if obj and obj:IsA("Model") then
			isModel = true
			for _,p in ipairs(obj:GetDescendants()) do if p:IsA("BasePart") then table.insert(parts,p) end end
		elseif obj and obj:IsA("BasePart") then
			table.insert(parts,obj)
		end

		if not obj then
			-- fallback: small real part near the overhead panel (no giant orbs)
			local col2 = math.floor((i-1)/3); local row2 = (i-1) % 3
			local off  = CFrame.new(-0.45 + row2*0.45, 0.65 - col2*0.4, -0.55)
			local fb = Instance.new("Part")
			fb.Size=Vector3.new(0.28,0.12,0.28); fb.Anchored=true; fb.CanCollide=false; fb.CastShadow=false
			fb.Color=Color3.fromRGB(45,45,52); fb.Material=Enum.Material.SmoothPlastic
			fb.CFrame=M.cockpitBaseCF*off; fb.Parent=workspace
			table.insert(spawnedParts, fb)
			obj=fb; parts={fb}
		end

		-- pick the smallest part as the "lever" we glow/flip,
		-- and make every real part raycast-clickable
		local flipPart, smallest = parts[1], math.huge
		for _,p in ipairs(parts) do
			p.CanQuery = true
			p.Anchored = true   -- keep hand-placed parts from falling out of the cockpit
			local vol = p.Size.X*p.Size.Y*p.Size.Z
			if vol < smallest then smallest = vol; flipPart = p end
		end
		if not flipPart then continue end

		-- glow the ACTUAL part via Highlight (no proxy spheres). AlwaysOnTop so the glow
		-- shows through the cockpit panel even when the switch sits flush in the mesh
		-- (Occluded mode was hiding it behind the panel — found+clickable but invisible).
		local hl = Instance.new("Highlight")
		hl.Adornee=obj; hl.Enabled=false; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillColor=sw.col; hl.OutlineColor=Color3.fromRGB(255,255,255)
		hl.FillTransparency=0.35; hl.OutlineTransparency=0.0; hl.Parent=obj

		-- For the HITBOX, use the model's full bounding box so the clickable area
		-- covers the entire visible button face (not just one small sub-part).
		-- Position comes from the part closest to the bbox centre so we stay on
		-- the button face rather than floating in the air above it.
		local hbCF, hbSize
		if isModel and #parts > 1 then
			local bbCF, bbSz = obj:GetBoundingBox()
			local bbCenter = bbCF.Position
			local hbPart, closestDist = flipPart, math.huge
			for _,p in ipairs(parts) do
				local d = (p.Position - bbCenter).Magnitude
				if d < closestDist then closestDist = d; hbPart = p end
			end
			hbCF   = hbPart.CFrame
			hbSize = bbSz   -- full model extent → hitbox matches the whole button
		else
			hbCF   = flipPart.CFrame
			hbSize = flipPart.Size
		end
		local FLOOR = 1.0
		local PAD   = 1.6   -- scale factor: hitbox is 60% larger than the button geometry
		hbSize = Vector3.new(
			math.max(hbSize.X * PAD, FLOOR),
			math.max(hbSize.Y * PAD, FLOOR),
			math.max(hbSize.Z * PAD, FLOOR)
		)
		local hb = Instance.new("Part")
		hb.Transparency=1; hb.Anchored=true; hb.CanCollide=false; hb.CanQuery=true; hb.CastShadow=false
		hb.Size = hbSize
		hb.CFrame = hbCF; hb.Parent=workspace
		table.insert(spawnedParts, hb)

		local light=Instance.new("PointLight"); light.Color=sw.col; light.Brightness=0; light.Range=2.2; light.Parent=hb

		local n = #switches + 1
		local bg=Instance.new("BillboardGui"); bg.Adornee=hb; bg.Size=UDim2.new(0,120,0,22)
		-- keep the name right ON the switch (small fixed lift), not floating high above it
		bg.StudsOffset=Vector3.new(0, 0.3, 0); bg.AlwaysOnTop=true; bg.Enabled=false; bg.Parent=hb
		local lbl2=Instance.new("TextLabel"); lbl2.Size=UDim2.new(1,0,1,0); lbl2.BackgroundTransparency=1
		lbl2.Text=n..". "..sw.label; lbl2.Font=Enum.Font.GothamBold; lbl2.TextSize=12
		lbl2.TextColor3=Color3.fromRGB(225,225,225); lbl2.TextStrokeTransparency=0.3; lbl2.Parent=bg

		switches[n]={obj=obj, isModel=isModel, flipPart=flipPart, flipBase=flipPart.CFrame,
			hl=hl, light=light, hitbox=hb, bg=bg, lbl=lbl2, pulse=nil, lightPulse=nil,
			done=false, col=sw.col, label=sw.label}
	end

	print(("[Startup] %d/%d real switches found (rest are fallbacks)"):format(foundCount, #SWITCH_SEQUENCE))

	-- Clicks only ever hit the switch hitboxes (Include filter), so the active switch
	-- is reachable even when a cockpit part is in front of it, and nothing else is clickable.
	local hitParams = RaycastParams.new()
	hitParams.FilterType = Enum.RaycastFilterType.Include
	do
		local filterList = {}
		for _,s in ipairs(switches) do table.insert(filterList, s.hitbox) end
		hitParams.FilterDescendantsInstances = filterList
	end

	-- quick "flip" of just the actual lever part (not the whole model)
	local function flipSwitch(s)
		local fp = s.flipPart; if not fp then return end
		M.playSfx("switch",0.55)
		local p0   = s.flipBase
		local down = p0 * CFrame.Angles(math.rad(-22),0,0)
		local rest = p0 * CFrame.Angles(math.rad(-13),0,0)
		local cfv  = Instance.new("CFrameValue"); cfv.Value=p0
		local conn = cfv.Changed:Connect(function(v) pcall(function() fp.CFrame=v end) end)
		local t1=M.TweenService:Create(cfv,TweenInfo.new(0.09,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Value=down}); t1:Play(); t1.Completed:Wait()
		local t2=M.TweenService:Create(cfv,TweenInfo.new(0.14,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Value=rest}); t2:Play(); t2.Completed:Wait()
		conn:Disconnect(); cfv:Destroy()
	end

	-- Point the head-look straight at a switch so it's centered and clearly in view
	-- (smooth pan via the existing head-look smoothing; the player can still adjust).
	local function aimViewAt(part)
		if not part then return end
		local base = M.cockpitBaseCF
		local d = base:VectorToObjectSpace(part.Position - base.Position)
		if d.Magnitude < 1e-3 then return end
		M.headYaw   = math.clamp(math.atan2(-d.X, -d.Z), -M.HEAD_YAW_MAX, M.HEAD_YAW_MAX)
		M.headPitch = math.clamp(math.atan2(d.Y, math.sqrt(d.X*d.X + d.Z*d.Z)), M.HEAD_PITCH_MIN, M.HEAD_PITCH_MAX)
	end

	local function activateSwitch(idx)
		local s = switches[idx]
		s.hl.Enabled=true; s.bg.Enabled=true
		s.pulse = M.TweenService:Create(s.hl, TweenInfo.new(0.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true), {FillTransparency=0.08})
		s.pulse:Play()
		s.lightPulse = M.TweenService:Create(s.light, TweenInfo.new(0.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true), {Brightness=3.2})
		s.lightPulse:Play()
		s.lbl.TextColor3 = s.col
		hudL.Text = ">  "..idx.."/"..#switches.."  Aim at the glowing "..s.label.." switch"
		M.TweenService:Create(xhair,TweenInfo.new(0.2),{BackgroundColor3=s.col}):Play()
		aimViewAt(s.hitbox)   -- swing the view onto the switch so it's clearly visible
	end

	local function deactivateSwitch(idx)
		local s = switches[idx]
		if s.pulse then s.pulse:Cancel() end
		if s.lightPulse then s.lightPulse:Cancel() end
		task.spawn(function() flipSwitch(s) end)
		s.hl.FillColor=M.C.success; s.hl.OutlineColor=M.C.success; s.hl.FillTransparency=0.5
		s.light.Color=M.C.success
		M.TweenService:Create(s.light,TweenInfo.new(0.25),{Brightness=0.7}):Play()
		s.bg.Enabled=false
		task.delay(0.55,function() s.hl.Enabled=false end)
	end

	local currentIdx=1; local wrongClicks=0; local missedQTE=0; local done=false

	-- On-screen pointer that guides the eye to the active switch when it's off-centre.
	local ptr=M.mkLbl(M.sg,"▲",34,Enum.Font.GothamBlack,M.C.amber,Enum.TextXAlignment.Center,60)
	ptr.Size=UDim2.new(0,46,0,46); ptr.AnchorPoint=Vector2.new(0.5,0.5); ptr.Visible=false; ptr.TextStrokeTransparency=0.3
	local ptrConn=M.RS.RenderStepped:Connect(function()
		if M.aborted then return end
		local s = (not done) and switches[currentIdx] or nil
		if not s or s.done or not s.hitbox then ptr.Visible=false; return end
		local vp=M.camera.ViewportSize; local cx,cy=vp.X/2, vp.Y/2
		local sp=M.camera:WorldToViewportPoint(s.hitbox.Position)
		local onScreen = sp.Z>0
		local dx,dy
		if onScreen then dx=sp.X-cx; dy=sp.Y-cy else dx=cx-sp.X; dy=cy-sp.Y end
		local len=math.sqrt(dx*dx+dy*dy)
		if onScreen and len<70 then ptr.Visible=false; return end   -- already on the switch
		if len<1 then dx=0; dy=-1; len=1 end
		local ux,uy=dx/len, dy/len; local rad=120
		ptr.Position=UDim2.new(0, cx+ux*rad, 0, cy+uy*rad)
		ptr.Rotation=math.deg(math.atan2(dy,dx))+90
		ptr.TextColor3=s.col; ptr.Visible=true
	end)

	if #switches == 0 then
		hudL.Text = "Startup complete — systems online."
		M.showSub("All systems online. Proceeding...")
		task.wait(1.2)
		done = true
	else
		activateSwitch(1)
	end

	-- map a hit part back to a switch index (hitbox or any descendant of the real model)
	local function hitToSwitchIdx(hitPart)
		if not hitPart then return nil end
		for i, s in ipairs(switches) do
			if hitPart == s.hitbox then return i end
			if s.isModel then if hitPart:IsDescendantOf(s.obj) then return i end
			elseif hitPart == s.obj then return i end
		end
		return nil
	end

	local function castIdx(px, py)
		local unitRay = M.camera:ScreenPointToRay(px, py)
		local rr = workspace:Raycast(unitRay.Origin, unitRay.Direction * 80, hitParams)
		return rr and hitToSwitchIdx(rr.Instance) or nil
	end

	local clickConn = M.UIS.InputBegan:Connect(function(inp, gp)
		if gp or done or M.aborted then return end
		if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		local cx, cy = M.camera.ViewportSize.X/2, M.camera.ViewportSize.Y/2
		-- the crosshair must be ON the switch itself; no off-button tolerance
		local idx = castIdx(cx, cy)
		if not idx then return end
		local sw = switches[idx]
		if idx == currentIdx and not sw.done then
			sw.done=true; deactivateSwitch(idx)
			M.flash(M.C.success,0.10,0.15)
			M.TweenService:Create(xhair,TweenInfo.new(0.1),{BackgroundColor3=M.C.success}):Play()
			task.delay(0.22,function() M.TweenService:Create(xhair,TweenInfo.new(0.15),{BackgroundColor3=M.C.text}):Play() end)
			currentIdx=currentIdx+1
			if currentIdx>#switches then done=true; M.hideSub()
			else task.delay(0.12,function() if not done then activateSwitch(currentIdx) end end) end
		elseif not sw.done then
			wrongClicks=wrongClicks+1; flashPenalty(12)
			sw.hl.Enabled=true; local fc=sw.hl.FillColor
			sw.hl.FillColor=M.C.danger
			task.delay(0.5,function() if not sw.done then sw.hl.FillColor=fc; sw.hl.Enabled=false end end)
			M.flash(M.C.danger,0.20,0.18)
			M.showSub("Wrong! Aim at: "..switches[currentIdx].label)
		end
	end)

	if scen.hasSurge then task.spawn(function()
			while currentIdx<3 and not done do task.wait(0.1) end; if done then return end
			local hit=M.showFlightEvent("POWER SURGE DETECTED","Press [E] to stabilize!",2.5)
			if hit then flashBonus(8,"Surge handled!") else missedQTE=missedQTE+1 end
		end) end

	if scen.hasStall then task.spawn(function()
			while currentIdx<4 and not done do task.wait(0.1) end; if done then return end
			if switches[4] then switches[4].hl.Enabled=true; switches[4].hl.FillColor=M.C.danger end
			local hit=M.showFlightEvent("ENGINE FAULT DETECTED","Press [E] to override!",3.2)
			if hit then flashBonus(10,"Fault cleared!") else missedQTE=missedQTE+1 end
		end) end

	local t=0; while not done and t<60 do t=t+task.wait(0.05) end; done=true

	clickConn:Disconnect()
	if ptrConn then ptrConn:Disconnect() end
	pcall(function() ptr:Destroy() end)
	for _,s in ipairs(switches) do
		pcall(function() s.hl:Destroy() end)
		pcall(function() s.hitbox:Destroy() end)
	end
	for _,p in ipairs(spawnedParts) do pcall(function() p:Destroy() end) end
	xhair:Destroy(); xhairRing:Destroy(); hudF:Destroy(); M.hideSub()

	-- restore the normal head-look range + viewpoint for the next task
	M.HEAD_YAW_MAX, M.HEAD_PITCH_MAX, M.HEAD_PITCH_MIN = savedYawMax, savedPitchMax, savedPitchMin
	M.cockpitBaseCF = savedBaseCF

	local score=math.clamp(100 - wrongClicks*12 - missedQTE*20, 0, 100)
	M.popText("All Systems Online!",M.C.amber,34)
	task.wait(0.9)
	M.TaskComplete:FireServer({score=score, bonusPts=(scen.bonusPts or 0), scenarioId=scen.id, failed=(score<40), taskIdx=M.activeTaskIdx})
end

--------------------------------------------------------------
-- TASK 3 — IN-FLIGHT  (throttle to V1, takeoff, traffic pattern)
--------------------------------------------------------------
local function runInFlight(scen)
	M.hideMouse()
	local scenCol=Color3.fromRGB((scen.col or {r=18,g=80,b=40}).r,(scen.col or {r=18,g=80,b=40}).g,(scen.col or {r=18,g=80,b=40}).b)

	if not M.planeModel then M.setupPlaneTracking() end
	local body = M.planeBodyAnchor or (M.planeModel and M.planeModel.PrimaryPart)

	local throttle      = 0
	local speed         = 0
	local V1            = 145
	local airborne      = false
	local phase         = "ground"
	local phaseDone     = false

	-- Camera mode: first-person cockpit head-look <-> third-person external chase ([F]).
	local camMode = "first"
	local camHint = M.mkLbl(M.sg, "[F] CAM: Cockpit", 12, Enum.Font.GothamBold, M.C.textMut, Enum.TextXAlignment.Left, 60)
	camHint.Size = UDim2.new(0, 210, 0, 18)
	camHint.Position = UDim2.new(0, 18, 1, -46)
	camHint.AnchorPoint = Vector2.new(0, 1)
	camHint.TextStrokeTransparency = 0.4
	local function updateCamHint()
		camHint.Text = (camMode == "first") and "[F] CAM: Cockpit" or "[F] CAM: Chase"
		camHint.TextColor3 = (camMode == "first") and M.C.textMut or M.C.amber
	end

	-- Navigate a dot-separated path from planeModel
	local function navPath(path)
		local node = M.planeModel
		for part in path:gmatch("[^.]+") do
			if not node then return nil end
			node = node:FindFirstChild(part)
		end
		return node
	end
	local function collectParts(obj)
		if not obj then return {} end
		if obj:IsA("BasePart") then return {obj} end
		local list = {}
		for _,p in ipairs(obj:GetDescendants()) do
			if p:IsA("BasePart") then table.insert(list,p) end
		end
		return list
	end

	-- THROTTLE: anchor every part to the plane BODY (stable, no drift/compounding)
	local throttlesObj  = navPath("Parts.Other_Animations.Interior.Cockpit.Throttles")
	local throttleParts = collectParts(throttlesObj)
	local throttleRest  = {}
	if body then
		for _,p in ipairs(throttleParts) do
			throttleRest[p] = body.CFrame:ToObjectSpace(p.CFrame)
		end
	end
	if not throttlesObj then
		warn("[Pilot] Throttles not found at Parts.Other_Animations.Interior.Cockpit.Throttles")
	end

	-- YOKES: anchor each Model pivot to the plane BODY
	local function prepareYokeModel(m)
		if not m or not m:IsA("Model") then return nil end
		local handle = m:FindFirstChildWhichIsA("BasePart")
		if not handle then
			for _,p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then handle=p; break end end
		end
		if handle then m.PrimaryPart = handle end
		return m
	end
	local yokeLModel = prepareYokeModel(navPath("Body.DC_ASDLL.VirtualCockpit.yoke"))
	local yokeRModel = prepareYokeModel(navPath("Body.DC_ASDLL.VirtualCockpit.yokeright"))
	local yokeLRest  = (body and yokeLModel) and body.CFrame:ToObjectSpace(yokeLModel:GetPivot()) or nil
	local yokeRRest  = (body and yokeRModel) and body.CFrame:ToObjectSpace(yokeRModel:GetPivot()) or nil

	local THROTTLE_SLIDE = 0.22
	local function updatePhysThrottle(t)
		if not body then return end
		for _,p in ipairs(throttleParts) do
			local rest = throttleRest[p]
			if rest then
				local animOffset = CFrame.new(0,0,-THROTTLE_SLIDE*t) * CFrame.Angles(math.rad(-20)*t, 0, 0)
				p.CFrame = body.CFrame * rest * animOffset
			end
		end
	end

	local function updateYokes(pullBack, rollAngle)
		if not body then return end
		local pitch = math.rad(22) * math.clamp(pullBack or 0, -1, 1)
		local roll  = math.clamp(rollAngle or 0, -0.3, 0.3)
		local rot   = CFrame.Angles(pitch, 0, roll)
		if yokeLModel and yokeLRest then yokeLModel:PivotTo(body.CFrame * yokeLRest * rot) end
		if yokeRModel and yokeRRest then yokeRModel:PivotTo(body.CFrame * yokeRRest * rot) end
	end

	-- HUD: throttle bar
	local thrPanel=Instance.new("Frame"); thrPanel.Size=UDim2.new(0,54,0,204); thrPanel.Position=UDim2.new(0,M.THR_X,0,M.THR_Y); thrPanel.ZIndex=20; thrPanel.Parent=M.sg; M.mkGlass(thrPanel,0.35)
	local thrCap=M.mkLbl(thrPanel,"THR",9,Enum.Font.GothamMedium,M.C.textMut,Enum.TextXAlignment.Center,21); thrCap.Size=UDim2.new(1,0,0,13); thrCap.Position=UDim2.new(0,0,0,7)
	local thrTrack=Instance.new("Frame"); thrTrack.Size=UDim2.new(0,16,0,138); thrTrack.Position=UDim2.new(0.5,-8,0,22); thrTrack.BackgroundColor3=M.C.bg; thrTrack.BackgroundTransparency=0.4; thrTrack.ZIndex=21; thrTrack.Parent=thrPanel; M.mkC(thrTrack,4)
	local v1Notch=Instance.new("Frame"); v1Notch.Size=UDim2.new(1.8,0,0,2); v1Notch.Position=UDim2.new(-0.4,0,(1-V1/200),0); v1Notch.BackgroundColor3=M.C.warn; v1Notch.ZIndex=23; v1Notch.Parent=thrTrack
	local thrKnob=Instance.new("Frame"); thrKnob.Size=UDim2.new(1,6,0,22); thrKnob.Position=UDim2.new(0,-3,1,-22); thrKnob.BackgroundColor3=M.C.amber; thrKnob.ZIndex=22; thrKnob.Parent=thrTrack; M.mkC(thrKnob,4)
	local thrPctL=M.mkLbl(thrPanel,"0%",12,Enum.Font.GothamBold,M.C.text,Enum.TextXAlignment.Center,21); thrPctL.Size=UDim2.new(1,0,0,16); thrPctL.Position=UDim2.new(0,0,1,-40)
	local thrHint=M.mkLbl(thrPanel,"W +\nS -",8,Enum.Font.GothamMedium,M.C.textMut,Enum.TextXAlignment.Center,21); thrHint.Size=UDim2.new(1,0,0,24); thrHint.Position=UDim2.new(0,0,1,-24); thrHint.TextWrapped=true

	-- HUD: speed
	local spdPanel=Instance.new("Frame"); spdPanel.Size=UDim2.new(0,M.SPD_W,0,M.SPD_H); spdPanel.Position=UDim2.new(0.5,-M.SPD_W/2,1,M.SPD_Y); spdPanel.ZIndex=20; spdPanel.Parent=M.sg; M.mkGlass(spdPanel,0.35)
	local spdCap=M.mkLbl(spdPanel,"AIRSPEED",9,Enum.Font.GothamMedium,M.C.textMut,Enum.TextXAlignment.Left,21); spdCap.Size=UDim2.new(1,-20,0,12); spdCap.Position=UDim2.new(0,12,0,7)
	local spdNumL=M.mkLbl(spdPanel,"0 kts",20,Enum.Font.GothamBold,M.C.text,Enum.TextXAlignment.Left,21); spdNumL.Size=UDim2.new(1,-20,0,24); spdNumL.Position=UDim2.new(0,12,0,18)
	local spdBarBg=Instance.new("Frame"); spdBarBg.Size=UDim2.new(1,-24,0,6); spdBarBg.Position=UDim2.new(0,12,0,46); spdBarBg.BackgroundColor3=M.C.bg; spdBarBg.BackgroundTransparency=0.4; spdBarBg.ZIndex=21; spdBarBg.Parent=spdPanel; M.mkC(spdBarBg,3)
	local spdBarFill=Instance.new("Frame"); spdBarFill.Size=UDim2.new(0,0,1,0); spdBarFill.BackgroundColor3=M.C.accent; spdBarFill.ZIndex=22; spdBarFill.Parent=spdBarBg; M.mkC(spdBarFill,3)
	local v1SpdMk=Instance.new("Frame"); v1SpdMk.Size=UDim2.new(0,2,1,4); v1SpdMk.Position=UDim2.new(V1/200,-1,0,-2); v1SpdMk.BackgroundColor3=M.C.warn; v1SpdMk.ZIndex=23; v1SpdMk.Parent=spdBarBg

	M.altHud.Visible=true
	M.refreshHudLayout()
	local function setAlt(ft) M.altVal.Text=string.format("%d ft", math.max(0,math.floor(ft))) end
	setAlt(0)

	local TRACK_H=138; local KNOB_H=22
	local function updateHUD()
		local yOff = math.floor((1-throttle)*(TRACK_H-KNOB_H))
		thrKnob.Position = UDim2.new(0,-3,0,yOff)
		thrPctL.Text = math.floor(throttle*100).."%"
		thrKnob.BackgroundColor3 = (throttle>=V1/200) and M.C.warn or M.C.amber
		local sf=math.clamp(speed/200,0,1)
		spdBarFill.Size=UDim2.new(sf,0,1,0)
		spdNumL.Text=string.format("%.0f kts",speed)
		if speed>=V1 then spdNumL.TextColor3=M.C.warn; spdBarFill.BackgroundColor3=M.C.warn
		elseif speed>=100 then spdNumL.TextColor3=M.C.success; spdBarFill.BackgroundColor3=M.C.success
		else spdNumL.TextColor3=M.C.accent; spdBarFill.BackgroundColor3=M.C.accent end
		updatePhysThrottle(throttle)
		local yp = 0
		if phase == "roll" then yp = -0.15
		elseif phase == "rotate" then yp = 0.55
		elseif phase == "climb" or phase == "pattern_climb" then yp = 0.85
		elseif phase == "circle" then yp = 0.12
		elseif phase == "approach" then yp = 0.25
		end
		local yr = (phase == "circle") and curRoll or 0
		updateYokes(yp, yr)
	end

	local function getExtCamCF()
		if not M.planeModel then return M.camera.CFrame end
		local piv = M.planeModel:GetPivot()
		local camPos  = piv.Position + piv.LookVector*(-75) + Vector3.new(0,20,0)
		local lookAt  = piv.Position + piv.LookVector*30 + Vector3.new(0,5,0)
		return CFrame.lookAt(camPos, lookAt)
	end

	-- [F] toggles between the cockpit head-look and the external chase view. In chase
	-- mode we switch the base head-look loop OFF (M.headLookActive=false) so it stops
	-- writing the camera, and the chase loop below drives it instead.
	local camKeyConn = M.UIS.InputBegan:Connect(function(inp, gp)
		if gp or M.aborted or inp.KeyCode ~= Enum.KeyCode.F then return end
		camMode = (camMode == "first") and "third" or "first"
		M.headLookActive = (camMode == "first")
		updateCamHint()
	end)

	-- Chase-cam driver: smoothly lerps from wherever the camera is now toward the
	-- external view, so the first->third switch eases in instead of snapping.
	local camConn = M.RS.RenderStepped:Connect(function(dt)
		if camMode ~= "third" or M.aborted then return end
		M.headLookActive = false
		local target = getExtCamCF()
		M.camera.CFrame = M.camera.CFrame:Lerp(target, math.clamp(dt * 6, 0, 1))
	end)

	-- Keep cockpit tracking + head-look ON so the camera follows the plane during roll/climb
	M.planeTracking = true
	M.headLookActive = true

	------------------------------------------------------------------
	-- SMOOTH dt-BASED FLIGHT MODEL  (single source of all plane motion)
	-- On the runway the nose rotates up around the main gear; once airborne
	-- the plane follows its pitched nose vector for a natural liftoff arc.
	------------------------------------------------------------------
	local piv0    = (M.planeModel and M.planeModel:GetPivot()) or CFrame.new()
	local pos     = piv0.Position
	local groundY = pos.Y
	local fwdHoriz
	do
		local lv   = piv0.LookVector
		local flat = Vector3.new(lv.X, 0, lv.Z)
		fwdHoriz   = (flat.Magnitude > 1e-3) and flat.Unit or Vector3.new(0,0,-1)
	end
	local rotBase   = CFrame.lookAt(Vector3.new(), fwdHoriz).Rotation
	local pitchSign = ((rotBase * CFrame.Angles(math.rad(10),0,0)).LookVector.Y >= 0) and 1 or -1

	local curPitch     = 0      -- radians actually applied (smoothed)
	local pitchTarget  = 0      -- radians target
	local lifted       = false  -- true once the wheels leave the runway
	local ROTATE_PITCH = math.rad(11)
	local ROTATE_RATE  = math.rad(5.5)   -- nose-up over ~2 s
	local LIFTOFF_PITCH = math.rad(3.5) -- liftoff after nose is raised
	local GEAR_OFFSET  = 38              -- pivot-to-main-gear (studs)

	local function groundPitchYOffset(pitch)
		-- Rotate around the main gear: nose rises, tail stays low, no vertical jump
		return math.sin(pitch) * GEAR_OFFSET
	end

	local function pitchLerpRate()
		if phase == "rotate" or phase == "roll" then return 1.5 end
		return 2.2
	end

	local home    = M.planeHomeCF or piv0
	local homePos = home.Position
	-- Runway frame straight off the parked pose: RWY_FWD = takeoff/landing
	-- direction down the runway, RWY_RT = lateral (centerline-offset) axis.
	local RWY_FWD
	do
		local rlv = home.LookVector
		local flat = Vector3.new(rlv.X, 0, rlv.Z)
		RWY_FWD = (flat.Magnitude > 1e-3) and flat.Unit or Vector3.new(0,0,-1)
	end
	local RWY_RT = Vector3.new(RWY_FWD.Z, 0, -RWY_FWD.X)
	local PATTERN_AGL  = 130
	local patternY     = groundY + PATTERN_AGL
	local APPROACH_BACK = 220
	local CIRCLE_R     = APPROACH_BACK
	local CIRCLE_ARC   = math.rad(255)
	local curRoll      = 0
	local circleTheta  = 0
	local circleStartTheta = 0
	local circleJoined = false
	local circleDir    = -1   -- left-hand traffic pattern

	local function circleArcDone()
		local arc = (circleTheta - circleStartTheta) * circleDir
		while arc < 0 do arc = arc + math.pi * 2 end
		return arc >= CIRCLE_ARC
	end

	local function initCircleEntry()
		local approachFix = homePos - fwdHoriz * APPROACH_BACK
		local exitTheta = math.atan2(approachFix.X - homePos.X, approachFix.Z - homePos.Z)
		circleStartTheta = exitTheta - circleDir * CIRCLE_ARC
		circleTheta = circleStartTheta
		circleJoined = false
	end

	------------------------------------------------------------------
	-- PLAYER FREE-FLIGHT: WASD steering + fly-through rings
	------------------------------------------------------------------
	local MAX_BANK     = math.rad(28)   -- max bank angle from A/D
	local MAX_PITCH    = math.rad(14)   -- max nose up/down from W/S
	local TURN_RATE    = math.rad(34)   -- heading change per second at full bank
	local CRUISE_SPEED = 72             -- studs/sec while the player flies
	local RING_RADIUS  = 80             -- huge, can't-miss hoops
	local RING_HIT_PAD = 90             -- very forgiving scoring slop beyond the rim
	local RING_WATCHDOG = 16            -- auto-skip a ring after this long (forgiving)
	local LINEUP_FAF   = 240            -- studs BEHIND the threshold to settle on for final

	local rings      = {}
	local targetIdx  = 1
	local ringsHit   = 0
	local ringTimer  = 0
	local courseDone = false

	local ringPanel=Instance.new("Frame"); ringPanel.Size=UDim2.new(0,160,0,38); ringPanel.Position=UDim2.new(0.5,-80,0,72); ringPanel.ZIndex=20; ringPanel.Visible=false; ringPanel.Parent=M.sg; M.mkGlass(ringPanel,0.35)
	local ringLbl=M.mkLbl(ringPanel,"RINGS 0/0",14,Enum.Font.GothamBold,M.C.text,Enum.TextXAlignment.Center,21); ringLbl.Size=UDim2.new(1,0,1,0)
	local function updateRingHud() ringLbl.Text=string.format("RINGS  %d/%d", ringsHit, #rings) end

	-- On-screen arrow that points to the next ring to fly through
	local arrow=M.mkLbl(M.sg,"▲",50,Enum.Font.GothamBlack,M.C.gold,Enum.TextXAlignment.Center,60)
	arrow.Size=UDim2.new(0,64,0,64); arrow.AnchorPoint=Vector2.new(0.5,0.5); arrow.Visible=false
	arrow.TextStrokeTransparency=0.35
	local function updateArrow()
		local r=rings[targetIdx]
		if not r then arrow.Visible=false; return end
		local vp=M.camera.ViewportSize
		local cx,cy=vp.X/2, vp.Y/2
		local sp=M.camera:WorldToViewportPoint(r.center)
		local dx,dy
		if sp.Z>0 then dx=sp.X-cx; dy=sp.Y-cy else dx=cx-sp.X; dy=cy-sp.Y end
		local len=math.sqrt(dx*dx+dy*dy)
		if len<1 then dx=0; dy=-1; len=1 end
		local ux,uy=dx/len, dy/len
		local rad=150
		arrow.Position=UDim2.new(0, cx+ux*rad, 0, cy+uy*rad)
		arrow.Rotation=math.deg(math.atan2(dy,dx))+90   -- glyph points up at 0deg
		arrow.Visible=true
	end

	local function makeRing(center, faceDir, radius, color)
		local model=Instance.new("Model"); model.Name="PilotRing"
		local cf=CFrame.lookAt(center, center+faceDir)
		-- thick, bright neon hoop: enough segments + ball size that it reads as a solid
		-- glowing ring from far away, plus a translucent disc so it's obvious where to aim.
		local SEG=40
		local ball=14
		for i=1,SEG do
			local a=(i/SEG)*math.pi*2
			local p=Instance.new("Part")
			p.Shape=Enum.PartType.Ball; p.Size=Vector3.new(ball,ball,ball)
			p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CastShadow=false
			p.Material=Enum.Material.Neon; p.Color=color; p.Transparency=0
			p.CFrame=cf*CFrame.new(math.cos(a)*radius, math.sin(a)*radius, 0)
			p.Parent=model
		end
		-- faint glowing fill so the target is unmistakable when you look at it
		local disc=Instance.new("Part")
		disc.Shape=Enum.PartType.Cylinder; disc.Anchored=true; disc.CanCollide=false
		disc.CanQuery=false; disc.CastShadow=false
		disc.Material=Enum.Material.Neon; disc.Color=color; disc.Transparency=0.82
		disc.Size=Vector3.new(0.5, radius*2, radius*2)
		disc.CFrame=cf*CFrame.Angles(0, math.rad(90), 0)
		disc.Parent=model
		model.Parent=workspace
		return model
	end

	local function tintRing(r, col)
		if not r.model then return end
		for _,p in ipairs(r.model:GetChildren()) do
			if p:IsA("BasePart") then p.Color=col end
		end
	end

	local function fadeRing(r)
		local m=r.model; if not m then return end
		task.delay(0.35, function() pcall(function() m:Destroy() end) end)
	end

	local function buildRingCourse()
		-- Oval circuit laid out in runway coordinates: alongF runs down the runway
		-- (RWY_FWD), acrossRt is the lateral offset (RWY_RT). The loop bows out to
		-- one side, curves back, and rolls out onto the EXTENDED CENTERLINE behind
		-- the threshold so the last rings line you up dead-straight with the runway.
		-- {alongF, acrossRt, agl}
		local WP = {
			{ 340,   0, 112},   -- 1  ahead, settle into the pattern
			{ 470, 220, 118},   -- 2  turn out (crosswind leg)
			{ 430, 470, 122},   -- 3
			{ 120, 600, 120},   -- 4  downwind abeam (far side)
			{-280, 560, 112},   -- 5  downwind past the field
			{-620, 380, 102},   -- 6  base turn
			{-560,   0,  98},   -- 7  rolled onto the centerline (far final)
			{-420,   0,  90},   -- 8  final
			{-260,   0,  82},   -- 9  short final (last ring)
		}
		local loopN = 6   -- rings 1..loopN are the loop; the rest are the centerline final
		local centers={}
		for _,w in ipairs(WP) do
			local b = homePos + RWY_FWD*w[1] + RWY_RT*w[2]
			table.insert(centers, Vector3.new(b.X, groundY + w[3], b.Z))
		end

		-- Face each ring along the smooth path tangent (incoming + outgoing dir) so
		-- you always fly through it head-on; force the centerline final rings to point
		-- exactly down the runway.
		for i,c in ipairs(centers) do
			local inc = (i==1) and (c - pos) or (c - centers[i-1])
			local out = (i<#centers) and (centers[i+1] - c) or RWY_FWD
			inc = (inc.Magnitude>1e-3) and inc.Unit or RWY_FWD
			out = (out.Magnitude>1e-3) and out.Unit or RWY_FWD
			local fwd = inc + out
			fwd = (fwd.Magnitude>1e-3) and fwd.Unit or RWY_FWD
			if i >= #centers-2 then fwd = RWY_FWD end
			local col = (i<=loopN) and Color3.fromRGB(80,180,255) or Color3.fromRGB(120,220,140)
			local rad = (i==#centers) and (RING_RADIUS-6) or RING_RADIUS
			table.insert(rings, {center=c, fwd=fwd, radius=rad, armed=false, done=false, model=makeRing(c,fwd,rad,col)})
		end
	end

	local function cleanupRings()
		for _,r in ipairs(rings) do
			if r.model then pcall(function() r.model:Destroy() end) end
		end
	end

	-- Evaluate the current target ring once the plane crosses its plane (forgiving).
	local function evalRing(dt)
		local r=rings[targetIdx]
		if not r or r.done then return end
		ringTimer=ringTimer+dt
		local toPlane=pos - r.center
		local ahead=toPlane:Dot(r.fwd)
		if not r.armed then
			if ahead < -10 or ringTimer>2.0 then r.armed=true end
		end
		local function advance() r.done=true; fadeRing(r); targetIdx=targetIdx+1; ringTimer=0; updateRingHud(); if targetIdx>#rings then courseDone=true end end
		if r.armed and ahead>=0 then
			local radial=(toPlane - r.fwd*ahead).Magnitude
			if radial <= r.radius+RING_HIT_PAD then
				ringsHit=ringsHit+1; tintRing(r, Color3.fromRGB(70,235,130)); flashBonus(8, "Ring "..targetIdx)
			else
				tintRing(r, Color3.fromRGB(235,80,80)); flashPenalty(4)
			end
			advance()
		elseif ringTimer>RING_WATCHDOG then
			tintRing(r, Color3.fromRGB(235,80,80)); advance()
		end
	end

	local function setPhase(name)
		phase = name
		if name=="ground" or name=="roll" then pitchTarget=0;             lifted=false
		elseif name=="rotate"              then pitchTarget=0;             lifted=false
		elseif name=="climb"               then pitchTarget=math.rad(10);  lifted=true
		elseif name=="pattern_climb"       then pitchTarget=math.rad(6);   lifted=true
		elseif name=="circle"              then pitchTarget=math.rad(2);   lifted=true
		elseif name=="freeflight"          then pitchTarget=0;             lifted=true
		elseif name=="lineup"              then pitchTarget=math.rad(-2);  lifted=true
		elseif name=="approach"            then pitchTarget=math.rad(-3);  lifted=true
			local toHome = homePos - pos
			local flat = Vector3.new(toHome.X, 0, toHome.Z)
			if flat.Magnitude > 1e-3 then
				fwdHoriz = flat.Unit
				rotBase = CFrame.lookAt(Vector3.new(), fwdHoriz).Rotation
			end
		end
	end

	local function fwdSpeed()
		if phase=="ground" or phase=="roll" or phase=="rotate" then return speed*0.27
		elseif phase=="climb" then return math.max(speed*0.27, 36)
		elseif phase=="pattern_climb" or phase=="circle" or phase=="approach" then return 38
		else return 0 end
	end

	local flightConn
	flightConn = M.RS.Heartbeat:Connect(function(dt)
		if phase=="done" or not M.planeModel or M.aborted then return end
		dt = math.min(dt, 0.05)

		if phase == "rotate" then
			pitchTarget = math.min(ROTATE_PITCH, pitchTarget + ROTATE_RATE * dt)
			if not lifted and curPitch >= LIFTOFF_PITCH and speed >= V1 * 0.9 then
				lifted = true
			end
		end

		if phase ~= "freeflight" then
			curPitch = curPitch + (pitchTarget - curPitch) * math.clamp(dt * pitchLerpRate(), 0, 1)
		end
		local fs = fwdSpeed()
		local pitchedRot = rotBase * CFrame.Angles(pitchSign * curPitch, 0, 0)

		if phase == "pattern_climb" then
			pos = pos + pitchedRot.LookVector * (fs * dt)
			pos = Vector3.new(pos.X, math.min(patternY, pos.Y + 16 * dt), pos.Z)
			M.planeModel:PivotTo(CFrame.new(pos) * pitchedRot)
			setAlt(math.floor(math.max(0, pos.Y - groundY) * 2.4))
			if pos.Y >= patternY - 6 then
				initCircleEntry()
				setPhase("circle")
			end

		elseif phase == "circle" then
			local target = Vector3.new(
				homePos.X + CIRCLE_R * math.sin(circleTheta),
				patternY,
				homePos.Z + CIRCLE_R * math.cos(circleTheta))
			if not circleJoined then
				pos = pos:Lerp(target, math.clamp(dt * 1.4, 0, 1))
				if (pos - target).Magnitude < 14 then
					circleJoined = true
					pos = target
				end
			else
				circleTheta = circleTheta + circleDir * (fs / CIRCLE_R) * dt
				pos = Vector3.new(
					homePos.X + CIRCLE_R * math.sin(circleTheta),
					patternY,
					homePos.Z + CIRCLE_R * math.cos(circleTheta))
			end
			local tangent = Vector3.new(circleDir * math.cos(circleTheta), 0, -circleDir * math.sin(circleTheta))
			if tangent.Magnitude > 1e-3 then tangent = tangent.Unit end
			local bankTarget = math.rad(15) * circleDir
			curRoll = curRoll + (bankTarget - curRoll) * math.clamp(dt * 2.8, 0, 1)
			local levelPitch = math.rad(2)
			curPitch = curPitch + (levelPitch - curPitch) * math.clamp(dt * 2.5, 0, 1)
			local headingRot = CFrame.lookAt(Vector3.new(), tangent).Rotation
			M.planeModel:PivotTo(CFrame.new(pos) * headingRot * CFrame.Angles(pitchSign * curPitch, 0, curRoll))
			setAlt(math.floor(PATTERN_AGL * 2.4))
			updateYokes(0.12, curRoll / math.rad(15))
			if circleJoined and circleArcDone() then
				setPhase("approach")
			end

		elseif phase == "approach" then
			curRoll = curRoll + (0 - curRoll) * math.clamp(dt * 2.2, 0, 1)
			pos = pos + fwdHoriz * (fs * dt) + Vector3.new(0, -10 * dt, 0)
			M.planeModel:PivotTo(CFrame.new(pos) * rotBase * CFrame.Angles(pitchSign * curPitch, 0, curRoll))
			setAlt(math.floor(math.max(0, pos.Y - groundY) * 2.4))
			updateYokes(0.2, 0)

		elseif phase == "freeflight" then
			-- WASD steering: A/D bank & turn, W/S nose up/down. Throttle auto-cruises.
			local aDown=M.UIS:IsKeyDown(Enum.KeyCode.A)
			local dDown=M.UIS:IsKeyDown(Enum.KeyCode.D)
			local wDown=M.UIS:IsKeyDown(Enum.KeyCode.W)
			local sDown=M.UIS:IsKeyDown(Enum.KeyCode.S)
			local rollTgt=0
			if aDown and not dDown then rollTgt=MAX_BANK elseif dDown and not aDown then rollTgt=-MAX_BANK end
			local pitchInput=0
			if wDown and not sDown then pitchInput=MAX_PITCH elseif sDown and not wDown then pitchInput=-MAX_PITCH end
			curRoll  = curRoll  + (rollTgt    - curRoll ) * math.clamp(dt * 3.0, 0, 1)
			curPitch = curPitch + (pitchInput - curPitch) * math.clamp(dt * 2.6, 0, 1)
			-- bank induces a coordinated turn (A = left, D = right)
			local phi = TURN_RATE * (curRoll / MAX_BANK) * dt
			local nf = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), phi) * fwdHoriz
			fwdHoriz = Vector3.new(nf.X, 0, nf.Z)
			fwdHoriz = (fwdHoriz.Magnitude > 1e-3) and fwdHoriz.Unit or Vector3.new(0, 0, -1)
			rotBase = CFrame.lookAt(Vector3.new(), fwdHoriz).Rotation
			local moveDir = (rotBase * CFrame.Angles(pitchSign * curPitch, 0, 0)).LookVector
			pos = pos + moveDir * (CRUISE_SPEED * dt)
			pos = Vector3.new(pos.X, math.clamp(pos.Y, groundY + 45, groundY + 320), pos.Z)
			M.planeModel:PivotTo(CFrame.new(pos) * rotBase * CFrame.Angles(pitchSign * curPitch, 0, curRoll))
			setAlt(math.floor(math.max(0, pos.Y - groundY) * 2.4))
			updateYokes(curPitch / MAX_PITCH, curRoll)
			evalRing(dt)
			updateArrow()

		elseif phase == "lineup" then
			-- Slide onto the extended runway centerline and lock heading to the runway.
			-- Forward speed eases to zero at the final-approach fix (a fixed distance
			-- BEHIND the threshold) so landing always begins on a proper final and
			-- never starts past the runway. Heading is interpolated, never snapped.
			local lat = (pos - homePos):Dot(RWY_RT)
			local fwd = (pos - homePos):Dot(RWY_FWD)            -- < 0 while behind the threshold
			fwdHoriz = fwdHoriz:Lerp(RWY_FWD, math.clamp(dt * 1.3, 0, 1))
			fwdHoriz = Vector3.new(fwdHoriz.X, 0, fwdHoriz.Z)
			fwdHoriz = (fwdHoriz.Magnitude > 1e-3) and fwdHoriz.Unit or RWY_FWD
			rotBase = CFrame.lookAt(Vector3.new(), fwdHoriz).Rotation
			curRoll = curRoll + (0 - curRoll) * math.clamp(dt * 2.0, 0, 1)
			local toFAF = (-LINEUP_FAF) - fwd                   -- studs still to fly to the fix
			local spd = CRUISE_SPEED * math.clamp(toFAF / 120, 0, 1)
			local moveDir = (rotBase * CFrame.Angles(pitchSign * curPitch, 0, 0)).LookVector
			pos = pos + moveDir * (spd * dt) - RWY_RT * (lat * math.clamp(dt * 1.6, 0, 1))
			pos = Vector3.new(pos.X, math.max(pos.Y - 4 * dt, groundY + 72), pos.Z)
			M.planeModel:PivotTo(CFrame.new(pos) * rotBase * CFrame.Angles(pitchSign * curPitch, 0, curRoll))
			setAlt(math.floor(math.max(0, pos.Y - groundY) * 2.4))
			updateYokes(curPitch / MAX_PITCH, curRoll)

		elseif not lifted then
			local y = groundY + groundPitchYOffset(curPitch)
			pos = Vector3.new(pos.X, y, pos.Z) + fwdHoriz * (fs * dt)
			M.planeModel:PivotTo(CFrame.new(pos) * pitchedRot)

		else
			pos = pos + pitchedRot.LookVector * (fs * dt)
			M.planeModel:PivotTo(CFrame.new(pos) * pitchedRot)
		end
	end)
	M.flightMotionConn = flightConn

	M.showSub("[W] Push throttle forward - reach V1 ("..V1.." kts) to take off!")
	task.delay(0.6,function() M.showScenBanner(scen.icon or "OK", "Flight VA-001 - Takeoff Roll", scenCol) end)

	-- Ground throttle control + HUD only (no plane motion here)
	local controlConn
	controlConn = M.RS.Heartbeat:Connect(function(dt)
		if phaseDone or M.aborted then controlConn:Disconnect(); return end
		local wDown = M.UIS:IsKeyDown(Enum.KeyCode.W)
		local sDown = M.UIS:IsKeyDown(Enum.KeyCode.S)
		if wDown then throttle = math.min(1, throttle + 0.28*dt)
		elseif sDown then throttle = math.max(0, throttle - 0.20*dt)
		elseif not airborne and throttle > 0.10 then throttle = math.max(0.10, throttle - 0.07*dt) end
		local tgt = throttle * 200
		speed = speed + (tgt - speed) * (airborne and 0.012 or 0.045)
		updateHUD()
	end)

	-- Wait for the player to engage throttle
	local waitT=0
	while throttle < 0.35 and waitT < 90 do waitT=waitT+task.wait(0.1) end

	-- ROLL
	setPhase("roll")
	M.playAmbience("wind",0.16)
	M.playSfx("rumble",0.4,0.9)
	M.showSub("Rolling! Build speed to V1!")
	local rollT=0
	while speed < V1 and rollT < 60 do rollT=rollT+task.wait(0.08) end

	-- ROTATE -> CLIMB  (smooth, integrator-driven; nose rises then lifts off)
	setPhase("rotate")
	M.showSub("V1 - ROTATE! Nose up - positive rate!")
	M.flash(M.C.warn, 0.42, 0.28)
	M.playSfx("rumble",0.7,1.05)
	M.playAmbience("wind",0.22)
	task.wait(2.2)
	setPhase("climb")
	task.wait(1.8)

	-- PLAYER-CONTROLLED FREE FLIGHT: hand the controls over and fly through the rings
	if controlConn then controlConn:Disconnect() end
	airborne = true
	throttle = 0.78
	updatePhysThrottle(0.78)
	speed = 165
	spdNumL.Text = string.format("%.0f kts", speed); spdNumL.TextColor3 = M.C.success
	spdBarFill.Size = UDim2.new(math.clamp(speed/200, 0, 1), 0, 1, 0); spdBarFill.BackgroundColor3 = M.C.success
	thrPanel.Visible = false   -- throttle is automatic while the player flies

	buildRingCourse(); updateRingHud(); ringPanel.Visible = true
	setPhase("freeflight")
	M.playAmbience("wind", 0.2)
	M.showSub("You have control!  [W] climb   [S] dive   [A]/[D] turn  —  fly through the rings!")
	task.delay(0.6, function() M.showScenBanner(scen.icon or "OK", "Flight VA-001 - Free Flight", scenCol) end)

	-- Fly until every ring is cleared (forgiving), or a backstop timer expires
	local COURSE_TIMEOUT = 80
	local courseT = 0
	while not courseDone and courseT < COURSE_TIMEOUT do courseT = courseT + task.wait(0.1) end
	courseDone = true
	M.hideSub()
	M.popText(string.format("Course complete - %d/%d rings", ringsHit, #rings), (ringsHit >= #rings and M.C.gold or M.C.success), 34)
	ringPanel.Visible = false
	arrow.Visible = false
	cleanupRings()

	-- TURN FINAL: smoothly rotate toward the runway (no camera snap), then hand to landing
	setPhase("lineup")
	M.showSub("Turning final - lining up with the runway.")
	M.setGrade(Color3.fromRGB(218, 232, 255), 0.03, 0.0, 0.5)
	-- Wait until the plane is centered on the runway and pointed straight down it
	-- (interpolated, never snapped), with a backstop so it can never stall here.
	local lineupT = 0
	while lineupT < 6.0 do
		lineupT = lineupT + task.wait(0.05)
		local p = M.planeModel and M.planeModel:GetPivot()
		if p then
			local lv = p.LookVector
			local h = Vector3.new(lv.X, 0, lv.Z)
			h = (h.Magnitude > 1e-3) and h.Unit or RWY_FWD
			local latOff = math.abs((p.Position - homePos):Dot(RWY_RT))
			if lineupT > 1.0 and h:Dot(RWY_FWD) > 0.99 and latOff < 12 then break end
		end
	end
	M.hideSub()

	pcall(function() thrPanel:Destroy() end)
	pcall(function() spdPanel:Destroy() end)
	pcall(function() ringPanel:Destroy() end)
	pcall(function() arrow:Destroy() end)

	-- tear down the camera toggle and hand the Landing task a cockpit view
	if camKeyConn then camKeyConn:Disconnect() end
	if camConn then camConn:Disconnect() end
	pcall(function() camHint:Destroy() end)
	M.headLookActive = true

	phaseDone = true
	M.speedClear()

	local score = math.clamp(60 + math.floor(40 * ringsHit / math.max(1, #rings)), 0, 100)
	M.popText("On Final!", M.C.success, 32)
	task.wait(0.6)
	M.TaskComplete:FireServer({score=score, bonusPts=(scen.bonusPts or 0), scenarioId=scen.id, failed=false, taskIdx=M.activeTaskIdx})
end

--------------------------------------------------------------
-- TASK 4 — LANDING  (descend, scenario QTE, flare window)
--------------------------------------------------------------
local function runLanding(scen)
	M.hideMouse()
	M.stopFlightMotion()
	local scenCol=Color3.fromRGB((scen.col or {r=18,g=80,b=40}).r,(scen.col or {r=18,g=80,b=40}).g,(scen.col or {r=18,g=80,b=40}).b)

	------------------------------------------------------------------
	-- CONTINUOUS FINAL APPROACH  (picks up from the traffic pattern)
	-- No fade or position snap — the plane keeps flying from where
	-- the in-flight circle left off.
	------------------------------------------------------------------
	if not M.planeModel then M.setupPlaneTracking() end
	local home    = M.planeHomeCF or (M.planeModel and M.planeModel:GetPivot()) or CFrame.new()
	local homePos = home.Position
	-- Runway frame from the parked pose. Heading is LOCKED to RWY_FWD and the
	-- descent is pulled onto the centerline, so touchdown is always ON the runway.
	local RWY_FWD
	do
		local rlv = home.LookVector
		local rflat = Vector3.new(rlv.X, 0, rlv.Z)
		RWY_FWD = (rflat.Magnitude > 1e-3) and rflat.Unit or Vector3.new(0, 0, -1)
	end
	local RWY_RT = Vector3.new(RWY_FWD.Z, 0, -RWY_FWD.X)
	local piv     = M.planeModel:GetPivot()
	local pos     = piv.Position
	-- Start from the plane's actual heading and smoothly capture the runway heading
	-- in the descent loop, so the hand-off from free-flight never snaps.
	local lv      = piv.LookVector
	local lflat   = Vector3.new(lv.X, 0, lv.Z)
	local fwdHoriz  = (lflat.Magnitude > 1e-3) and lflat.Unit or RWY_FWD
	local rotBase   = CFrame.lookAt(Vector3.new(), fwdHoriz).Rotation
	local pitchSign = ((rotBase * CFrame.Angles(math.rad(10), 0, 0)).LookVector.Y >= 0) and 1 or -1

	local touchdownY = homePos.Y
	local startY     = pos.Y
	local H          = math.max(startY - touchdownY, 1)

	M.headLookActive = true
	M.planeTracking  = true

	task.delay(0.4, function() M.showScenBanner(scen.icon or "LAND", scen.label or "Landing", scenCol) end)

	local flarePts=0; local scenarioPts=0

	M.altHud.Visible=true
	M.refreshHudLayout()
	local function setAlt(ft) M.altVal.Text=string.format("%d ft",math.max(0,ft)) end

	local targetY   = startY
	local fwdSpd    = 34
	local fwdTarget = 34
	local flareBias = 0
	local rollBias  = 0
	local grounded  = false
	local curPitch, curRoll = 0, 0
	do
		local lookY = piv.LookVector.Y
		curPitch = math.clamp(math.asin(math.clamp(lookY, -1, 1)), math.rad(-7), math.rad(12))
		curRoll = math.clamp(math.asin(math.clamp(piv.RightVector.Y, -1, 1)), -0.3, 0.3)
	end
	local MAX_DESCENT = 45  -- studs/sec cap so it glides, never plummets

	local landConn
	landConn = M.RS.Heartbeat:Connect(function(dt)
		if not M.planeModel or M.aborted then return end
		dt = math.min(dt,0.05)
		fwdSpd = fwdSpd + (fwdTarget - fwdSpd)*math.clamp(dt*1.2,0,1)
		-- Smoothly capture, then hold, the runway heading (no snap at the hand-off).
		fwdHoriz = fwdHoriz:Lerp(RWY_FWD, math.clamp(dt*1.5,0,1))
		fwdHoriz = Vector3.new(fwdHoriz.X,0,fwdHoriz.Z)
		fwdHoriz = (fwdHoriz.Magnitude>1e-3) and fwdHoriz.Unit or RWY_FWD
		rotBase = CFrame.lookAt(Vector3.new(), fwdHoriz).Rotation
		local prevY = pos.Y
		if grounded then
			pos = Vector3.new(pos.X, touchdownY, pos.Z)
		else
			local dy = (targetY - pos.Y)*math.clamp(dt*0.9,0,1)
			dy = math.clamp(dy, -MAX_DESCENT*dt, MAX_DESCENT*dt)
			local ny = pos.Y + dy
			if ny <= touchdownY+0.05 then ny=touchdownY; grounded=true end
			pos = Vector3.new(pos.X, ny, pos.Z)
		end
		local vy = (pos.Y - prevY)/dt
		-- Fly down the runway and continuously pull onto the centerline so the
		-- touchdown and roll-out stay ON the runway (never drift into the grass).
		pos = pos + fwdHoriz*(fwdSpd*dt)
		local latOff = (pos - homePos):Dot(RWY_RT)
		pos = pos - RWY_RT*(latOff*math.clamp(dt*1.5,0,1))
		-- nose follows the glide path (shallow), plus a flare bias near the ground
		local pathPitch = math.clamp(math.atan2(vy, math.max(fwdSpd,1)), math.rad(-7), math.rad(12))
		local noseTarget = math.clamp(pathPitch + flareBias, math.rad(-7), math.rad(12))
		curPitch = curPitch + (noseTarget - curPitch)*math.clamp(dt*3,0,1)
		curRoll  = curRoll  + (rollBias   - curRoll )*math.clamp(dt*3,0,1)
		M.planeModel:PivotTo(CFrame.new(pos) * rotBase * CFrame.Angles(pitchSign*curPitch, 0, curRoll))
		local frac = math.clamp((pos.Y - touchdownY)/H, 0, 1)
		setAlt(math.floor(frac*3000))
	end)

	-- DESCENT  (continues the glide from the pattern)
	M.playAmbience("wind",0.18)
	M.showSub("Established on the glideslope - descending to the runway.")
	targetY = touchdownY + H * 0.55; fwdTarget = 34
	task.wait(3.5)
	M.showSub("Aligned with the centerline - stabilizing approach.")
	targetY = touchdownY + H*0.32; fwdTarget = 30
	task.wait(3.0)

	-- CROSSWIND
	if scen.crosswind then
		M.showSub("Crosswind - correct for drift!")
		rollBias = math.rad(6)
		local hit=M.showFlightEvent("CROSSWIND CORRECTION","Press [E] to correct bank angle",3)
		if hit then rollBias=0; scenarioPts=20; flashBonus(scen.bonusPts or 8,"Crosswind corrected!")
		else flashPenalty(10); M.popText("Drifting off centerline!",M.C.danger,26); rollBias=math.rad(3) end
	end

	-- EMERGENCY
	if scen.emergency then
		M.showSub("FLAP FAILURE - land without flaps!")
		M.flash(M.C.danger,0.45,0.4)
		local hit=M.showFlightEvent("FLAP SYSTEM FAILURE","Press [E] to use emergency procedure",3.5)
		if hit then scenarioPts=20; flashBonus(scen.bonusPts or 12,"Emergency proc. complete!") else flashPenalty(12) end
	end

	if not scen.crosswind and not scen.emergency then scenarioPts=20 end

	-- SHORT FINAL
	rollBias = 0
	M.showSub("200 ft - short final. Hold the centerline."); targetY = touchdownY + H*0.12; fwdTarget = 26
	task.wait(1.8)

	-- FLARE
	M.showSub("50 ft - FLARE NOW! Press [E]!")
	M.flash(M.C.warn,0.35,0.25)
	targetY = touchdownY + H*0.05; fwdTarget = 22
	local flareStart=tick()
	local flareHit=M.awaitE(2.5)
	local flareTime=tick()-flareStart
	if flareHit then
		flareBias = math.rad(7)  -- nose-up flare arrests the descent
		if flareTime>=0.4 and flareTime<=1.6 then flarePts=40; M.popText("PERFECT FLARE!",M.C.gold,38); M.flash(M.C.gold,0.25,0.3)
		elseif flareTime<0.4 then flarePts=25; M.popText("Early flare - firm landing",M.C.success,28)
		else flarePts=25; M.popText("Late flare - heavy landing",M.C.warn,28) end
	else
		flarePts=0; M.popText("NO FLARE - HARD LANDING!",M.C.danger,30); M.flash(M.C.danger,0.5,0.35)
		flareBias = math.rad(1)
	end

	-- TOUCHDOWN
	targetY = touchdownY; fwdTarget = flareHit and 20 or 24
	local tdT=0; while not grounded and tdT<3 do tdT=tdT+task.wait(0.05) end
	grounded=true; flareBias=0
	M.flash(Color3.fromRGB(200,200,200),0.15,0.25)
	M.playSfx("touchdown",0.7,0.9)
	M.playSfx("rumble",0.4,0.85)
	M.showSub("TOUCHDOWN! Applying brakes - spoilers deployed.")
	task.wait(0.8)

	-- ROLLOUT (decelerate forward to a stop)
	M.speedClear()
	M.stopAmbience()
	fwdTarget = 0
	local rollT=0; while fwdSpd>0.6 and rollT<6 do rollT=rollT+task.wait(0.05) end
	M.showSub("Reverse thrust - decelerating to taxi speed.")
	task.wait(1.8); M.hideSub()
	M.altHud.Visible=false
	M.refreshHudLayout()
	landConn:Disconnect()

	M.popText("LANDED!",M.C.success,44)
	M.flash(M.C.success,0.4,0.5)
	task.wait(1.2)

	-- Normalized score: completion (40) + flare (up to 40) + scenario QTE (up to 20)
	local score=math.clamp(40 + flarePts + scenarioPts, 0, 100)
	M.TaskComplete:FireServer({score=score, bonusPts=(scen.bonusPts or 0), scenarioId=scen.id, failed=(flarePts==0), taskIdx=M.activeTaskIdx})
end

M.playIntroCinematic = playIntroCinematic
M.runPreFlight = runPreFlight
M.runStartup = runStartup
M.runInFlight = runInFlight
M.runLanding = runLanding
return M
