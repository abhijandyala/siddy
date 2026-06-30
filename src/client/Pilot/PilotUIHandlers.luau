-- Pilot remote handlers + results (split to avoid Luau register limit)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameState"))
local M = require(script.Parent:WaitForChild("PilotUIBase"))


--------------------------------------------------------------
-- RESULTS SCREEN
--------------------------------------------------------------
local resScr=Instance.new("Frame"); resScr.Size=UDim2.new(1,0,1,0); resScr.BackgroundColor3=Color3.new(0,0,0); resScr.BackgroundTransparency=0.55; resScr.Visible=false; resScr.ZIndex=42; resScr.Parent=M.sg
local resInner=Instance.new("Frame"); resInner.Size=UDim2.new(0,480,0,480); resInner.Position=UDim2.new(0.5,-240,0.5,-240); resInner.ZIndex=43; resInner.Parent=resScr; M.mkGlass(resInner, M.PANEL_TRANS)
local resTitleL=M.mkLbl(resInner,"Flight Debrief",22,Enum.Font.GothamBold,M.C.text,Enum.TextXAlignment.Center,45); resTitleL.Size=UDim2.new(1,-40,0,32); resTitleL.Position=UDim2.new(0,20,0,24)
local resScV=M.mkLbl(resInner,"0",52,Enum.Font.GothamBold,M.C.text,Enum.TextXAlignment.Center,45); resScV.Size=UDim2.new(1,0,0,58); resScV.Position=UDim2.new(0,0,0,68)
local resAvgL=M.mkLbl(resInner,"average score",11,Enum.Font.GothamMedium,M.C.textMut,Enum.TextXAlignment.Center,45); resAvgL.Size=UDim2.new(1,0,0,16); resAvgL.Position=UDim2.new(0,0,0,126)
local resRat=M.mkLbl(resInner,"",16,Enum.Font.GothamBold,M.C.warn,Enum.TextXAlignment.Center,44); resRat.Size=UDim2.new(1,0,0,22); resRat.Position=UDim2.new(0,0,0,148)
local resMsg=M.mkLbl(resInner,"",11,Enum.Font.GothamMedium,M.C.textMut,Enum.TextXAlignment.Center,44); resMsg.Size=UDim2.new(1,-48,0,36); resMsg.Position=UDim2.new(0,24,0,172); resMsg.TextWrapped=true

local resBrk=Instance.new("Frame"); resBrk.Size=UDim2.new(1,-40,0,100); resBrk.Position=UDim2.new(0,20,0,218); resBrk.BackgroundTransparency=1; resBrk.ZIndex=44; resBrk.Parent=resInner
local rBL=Instance.new("UIListLayout"); rBL.FillDirection=Enum.FillDirection.Horizontal; rBL.Padding=UDim.new(0,8); rBL.SortOrder=Enum.SortOrder.LayoutOrder; rBL.HorizontalAlignment=Enum.HorizontalAlignment.Center; rBL.Parent=resBrk
local CARD_NAMES={"Pre-Flight","Startup","In-Flight","Landing"}
local resCards={}
for i=1,4 do
	local card=Instance.new("Frame"); card.Size=UDim2.new(0,100,1,0); card.BackgroundColor3=M.C.bg; card.BackgroundTransparency=0.45; card.LayoutOrder=i; card.ZIndex=45; card.Parent=resBrk; M.mkC(card,8)
	local cName=M.mkLbl(card,CARD_NAMES[i],8,Enum.Font.GothamMedium,M.C.textMut,Enum.TextXAlignment.Center,46); cName.Size=UDim2.new(1,0,0,14); cName.Position=UDim2.new(0,0,0,10)
	local cGrade=M.mkLbl(card,"-",22,Enum.Font.GothamBold,M.C.textMut,Enum.TextXAlignment.Center,46); cGrade.Size=UDim2.new(1,0,0,28); cGrade.Position=UDim2.new(0,0,0,28)
	local cScore=M.mkLbl(card,"-",10,Enum.Font.GothamMedium,M.C.textSec,Enum.TextXAlignment.Center,46); cScore.Size=UDim2.new(1,0,0,14); cScore.Position=UDim2.new(0,0,0,58)
	local cBonus=M.mkLbl(card,"",9,Enum.Font.GothamMedium,M.C.accent,Enum.TextXAlignment.Center,46); cBonus.Size=UDim2.new(1,0,0,20); cBonus.Position=UDim2.new(0,0,0,74); cBonus.TextWrapped=true
	resCards[i]={card=card,grade=cGrade,score=cScore,bonus=cBonus}
end
local resTotalL=M.mkLbl(resInner,"Total: 0 pts",14,Enum.Font.GothamMedium,M.C.textSec,Enum.TextXAlignment.Center,45); resTotalL.Size=UDim2.new(1,0,0,20); resTotalL.Position=UDim2.new(0,0,0,332)
local resHint=M.mkMenuBtn(resInner, "CONTINUE", UDim2.new(0,280,0,48), UDim2.new(0.5,-140,1,-68), 45)

--------------------------------------------------------------
-- REMOTE HANDLERS
--------------------------------------------------------------
M.ShowTutorial.OnClientEvent:Connect(function()
	if not M.active then return end
	M.showTutorialUI()
end)

local function beginGame()
	if not M.tutWaiting or not M.tutOv.Visible then return end
	M.tutWaiting=false
	M.gameFlowStarted=true
	M.btnPulse:Pause()
	M.playSfx("click",0.6)
	M.PlayerReady:FireServer("START")
end
M.tutBtn.MouseButton1Click:Connect(beginGame)

M.StartCinematic.OnClientEvent:Connect(function()
	if not M.active then return end
	M.tutWaiting=false
	M.gameFlowStarted=true
	M.btnPulse:Pause()
	M.blurOut()
	M.playSfx("whoosh",0.5)
	M.playMusic("ambient",0.18)
	M.TweenService:Create(M.tutOv,TweenInfo.new(0.3),{BackgroundTransparency=1}):Play()
	M.TweenService:Create(M.tutP,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(0.5,-300,0.35,-230)}):Play()
	task.delay(0.32,function() M.tutOv.Visible=false end)
	M.hideMouse(); task.wait(0.1)
	M.cinematicThread = task.spawn(M.playIntroCinematic)
end)

M.StartTask.OnClientEvent:Connect(function(data)
	if not M.active then return end
	-- Strictly one task at a time, in order. Ignore any StartTask that arrives
	-- while a task is running, or that is not the next task forward. This makes
	-- the client immune to a duplicate/rogue server firing a second StartTask stream.
	if M.taskRunning then return end
	if M.activeTaskIdx == data.taskIdx then return end  -- ignore duplicate StartTask for the same task
	if type(data.taskIdx) == "number" and data.taskIdx <= M.lastTaskIdx then return end
	M.taskRunning = true
	M.activeTaskIdx = data.taskIdx
	M.lastTaskIdx = data.taskIdx
	M.taskFlowActive=true
	M.activeModal = nil
	M.setTaskActive(data.taskIdx)
	M.showTaskPanel()
	M.scoreF.Visible=true
	M.refreshHudLayout()
	M.hideSub()
	if data.taskId == "preflight" then
		M.enterTaskMode()
	end
	M.taskThread = task.spawn(function()
		if     data.taskId=="preflight" then M.runPreFlight(data.scenario)
		elseif data.taskId=="startup"   then M.runStartup(data.scenario)
		elseif data.taskId=="inflight"  then M.runInFlight(data.scenario)
		elseif data.taskId=="landing"   then M.runLanding(data.scenario)
		end
		if M.activeTaskIdx == data.taskIdx then M.activeTaskIdx = nil end
		M.taskRunning = false
	end)
end)

M.ScoreUpdate.OnClientEvent:Connect(function(newTotal,taskScore,taskIdx)
	if not M.active then return end
	M.totalScore=newTotal
	M.scoreV.Text=tostring(newTotal)
	M.TweenService:Create(M.scoreV,TweenInfo.new(0.15),{TextColor3=M.C.success}):Play()
	task.delay(0.8,function() M.TweenService:Create(M.scoreV,TweenInfo.new(0.3),{TextColor3=M.C.text}):Play() end)
end)

M.ShowResults.OnClientEvent:Connect(function(s)
	if not M.active then return end
	if resScr.Visible then return end  -- already showing; ignore a duplicate/rogue server's results push
	-- A racing/duplicate server can fire results early. Only accept results once
	-- the final task (landing = idx 4) has actually finished running on this client.
	if M.taskRunning or (M.lastTaskIdx or 0) < 4 then return end
	M.taskRunning=false; M.activeTaskIdx=nil
	M.taskPanel.Visible=false; M.scoreF.Visible=false; M.hideSub()
	M.headLookActive=false
	M.stopAmbience(); M.stopMusic()
	task.wait(0.4)
	M.showMouse()

	local avg = s.avgScore or 0
	local total = s.totalScore or 0
	local starCount = s.stars or 0
	local taskResults = s.taskResults or {}

	for i = 1, #taskResults do
		local tr = taskResults[i]
		if tr and tr.recorded ~= false then
			GameState:SetScore("Aviation", i, tr.score or 0)
		end
	end

	local gradeCol
	if avg >= 88 then gradeCol = M.C.gold
	elseif avg >= 70 then gradeCol = M.C.success
	elseif avg >= 55 then gradeCol = M.C.warn
	else gradeCol = M.C.danger end
	resScV.TextColor3 = gradeCol
	resRat.TextColor3 = gradeCol

	local stars = string.rep("*", starCount) .. string.rep("-", math.max(0, 3 - starCount))
	resRat.Text = stars .. "  " .. (s.rating or "")
	resMsg.Text = s.message or ""

	local GRADE_COLS = {["A+"]=M.C.gold, A=M.C.gold, ["B+"]=M.C.success, B=M.C.success, C=M.C.warn, D=M.C.danger, F=M.C.danger}
	for i = 1, 4 do
		local rc = resCards[i]
		local tr = taskResults[i]
		local grade = (tr and tr.grade) or "-"
		local gc = GRADE_COLS[grade] or M.C.textMut
		rc.grade.Text = grade
		rc.grade.TextColor3 = gc
		rc.score.Text = tr and (tostring(tr.score or 0) .. " pts") or "-"
		rc.score.TextColor3 = gc
		if tr and (tr.bonusPts or 0) > 0 then
			rc.bonus.Text = "+" .. tr.bonusPts .. " scenario bonus"
		else
			rc.bonus.Text = ""
		end
		rc.card.BackgroundTransparency = 0.45
		rc.grade.TextTransparency = 1
		rc.score.TextTransparency = 1
		rc.bonus.TextTransparency = 1
	end

	resScV.Text = "0"
	resTotalL.Text = "Total: 0 pts"
	resScr.Visible = true
	resScr.BackgroundTransparency = 1
	resInner.Position = UDim2.new(0.5, -240, 0.5, -220)
	M.blurIn()
	M.TweenService:Create(resScr, TweenInfo.new(0.4), {BackgroundTransparency = 0.55}):Play()
	M.TweenService:Create(resInner, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, -240, 0.5, -240)}):Play()

	-- animated score count-up
	task.spawn(function()
		task.wait(0.4)
		M.playSfx("sting", 0.5)
		local steps = 24
		for i = 1, steps do
			resScV.Text = tostring(math.floor(avg * i / steps))
			task.wait(0.022)
		end
		resScV.Text = tostring(avg)
		for i = 1, steps do
			resTotalL.Text = "Total: " .. math.floor(total * i / steps) .. " pts"
			task.wait(0.012)
		end
		resTotalL.Text = "Total: " .. total .. " pts"
	end)

	-- staggered card reveal
	task.spawn(function()
		task.wait(0.55)
		for i=1,4 do
			local rc=resCards[i]
			M.TweenService:Create(rc.grade,TweenInfo.new(0.3),{TextTransparency=0}):Play()
			M.TweenService:Create(rc.score,TweenInfo.new(0.3),{TextTransparency=0}):Play()
			M.TweenService:Create(rc.bonus,TweenInfo.new(0.3),{TextTransparency=0}):Play()
			M.playSfx("click", 0.4, 1+0.06*i)
			task.wait(0.12)
		end
	end)
end)

local function closeResults()
	if not resScr.Visible then return end
	resScr.Visible=false
	M.taskRunning=false; M.activeTaskIdx=nil; M.lastTaskIdx=0
	M.blurOut()
	-- FBLA: pressing CONTINUE on the debrief ends the Aviation world. Signal
	-- PlaySequence, which tears the pilot UI down and moves on to the Chef world.
	M.finished = true
end

M.UIS.InputBegan:Connect(function(inp,gp)
	if gp or not M.active then return end
	if inp.KeyCode==Enum.KeyCode.E then
		beginGame()
		closeResults()
	end
end)
resHint.MouseButton1Click:Connect(closeResults)

task.spawn(function()
	M.ClientReady:FireServer()
	task.wait(3)
	if M.active and not M.gameFlowStarted and not M.tutOv.Visible then
		M.showTutorialUI()
	end
end)

return {}
