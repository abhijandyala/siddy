--[[
	ChefWorldServer.luau  (v10 — REMOTE-BASED ACTIVATION)
	Script: ServerScriptService/ChefWorldServer

	STUDIO SETUP:
	  1. StarterPlayer → Character → set Rig Type to R6
	  2. workspace.ChefWorld.Kitchen.Stations must have:
	     Fridge, PrepStation, Stove, ServingCounter (Parts, Anchored, CanCollide false)

	v10 Changes:
	  + Uses RemoteEvent for client to signal activation (fixes replication issue)
	  + Creates remotes IMMEDIATELY so client scripts can find them
	  + Auto-starts tutorial when client signals activation
	  + Fires WorldCompleted event when all orders are done
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[ChefWorld] v10 Server script starting...")

--------------------------------------------------------------
-- REMOTES  (created IMMEDIATELY so client WaitForChild succeeds)
--------------------------------------------------------------
local folder = ReplicatedStorage:FindFirstChild("ChefWorldRemotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "ChefWorldRemotes"
	folder.Parent = ReplicatedStorage
end

local function mkR(n)
	local existing = folder:FindFirstChild(n)
	if existing then return existing end
	local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = folder; return r
end

local ShowTutorial    = mkR("ShowTutorial")
local StartOrder      = mkR("StartOrder")
local NextTask        = mkR("NextTask")
local PlayCinematic   = mkR("PlayCinematic")
local CinematicDone   = mkR("CinematicDone")
local WrongStation    = mkR("WrongStation")
local TaskFailed      = mkR("TaskFailed")
local OrderDone       = mkR("OrderDone")
local ShowResults     = mkR("ShowResults")
local PlayerReady     = mkR("PlayerReady")
local TicketDismissed = mkR("TicketDismissed")
local OrderTimedOut   = mkR("OrderTimedOut")
local ActivateChefWorld = mkR("ActivateChefWorld")  -- PlaySequence fires this when player enters
local RequestUIReady  = mkR("RequestUIReady")       -- Server fires this to tell client to respond
local ChefUIReady     = mkR("ChefUIReady")          -- ChefWorldUI fires this in response

print("[ChefWorld] Remote events created immediately!")
print("[ChefWorld] Waiting for client to activate via ActivateChefWorld remote...")

-- Track which players have been activated
local activatedPlayers = {}

--------------------------------------------------------------
-- INITIALIZATION (runs immediately, doesn't wait for anything)
--------------------------------------------------------------
print("[ChefWorld] Initializing ChefWorld game systems...")

--------------------------------------------------------------
-- R6 CHECK
--------------------------------------------------------------
Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function(c)
		local h = c:WaitForChild("Humanoid", 5)
		if h and h.RigType == Enum.HumanoidRigType.R15 then
			warn("[VOCA] " .. p.Name .. " is R15 — set StarterPlayer Rig to R6!")
		end
	end)
end)

--------------------------------------------------------------
-- ORDER DATA
--------------------------------------------------------------
local ORDERS = {
	{
		dishName="Spaghetti Bolognese", timeLimit=70, isRush=false,
		ingredientLabels={"Dry Pasta","San Marzano Tomatoes","White Onion"},
		ingredientColors={{r=235,g=205,b=80},{r=192,g=48,b=35},{r=222,g=188,b=140}},
		steps={
			{station="Fridge",         label="Collect pasta & tomatoes", prompt="🧊  Go to the Fridge",         icon="🧊", isCook=false},
			{station="PrepStation",    label="Chop onion & garlic",      prompt="🔪  Head to Prep Station",     icon="🔪", isCook=false},
			{station="Stove",          label="Simmer the bolognese",     prompt="🔥  Cook at the Stove",        icon="🔥", isCook=true, cookTime=10},
			{station="ServingCounter", label="Plate and serve",          prompt="🍽   Plate at Serving Counter", icon="🍽",  isCook=false},
		},
	},
	{
		dishName="Grilled Chicken & Veg", timeLimit=60, isRush=false,
		ingredientLabels={"Chicken Breast","Bell Peppers","Lemon"},
		ingredientColors={{r=235,g=195,b=128},{r=72,g=175,b=72},{r=250,g=224,b=55}},
		steps={
			{station="Fridge",         label="Grab chicken & veg",   prompt="🧊  Go to the Fridge",          icon="🧊", isCook=false},
			{station="Stove",          label="Sear the chicken",     prompt="🔥  Sear at the Stove",         icon="🔥", isCook=true, cookTime=12},
			{station="PrepStation",    label="Slice & season",       prompt="🔪  Slice at Prep Station",     icon="🔪", isCook=false},
			{station="ServingCounter", label="Build the plate",      prompt="🍽   Plate at Serving Counter", icon="🍽",  isCook=false},
		},
	},
	{
		dishName="French Onion Soup", timeLimit=55, isRush=true,
		ingredientLabels={"Beef Broth","Caramelized Onions","Gruyère"},
		ingredientColors={{r=205,g=158,b=68},{r=148,g=98,b=48},{r=232,g=222,b=192}},
		steps={
			{station="Fridge",         label="Grab broth & onions",     prompt="⚡ RUSH — 🧊 Fridge first!",  icon="🧊", isCook=false},
			{station="Stove",          label="Caramelize & simmer",     prompt="⚡ RUSH — 🔥 Stove now!",     icon="🔥", isCook=true, cookTime=14},
			{station="PrepStation",    label="Ladle & top with cheese", prompt="⚡ 🔪 Prep — ladle & top!",   icon="🔪", isCook=false},
			{station="ServingCounter", label="Serve immediately",       prompt="⚡ 🍽  SERVE IT NOW!",         icon="🍽",  isCook=false},
		},
	},
}

local function getRating(s)
	if     s >= 90 then return {stars=3, rating="Head Chef",     message="Flawless service. Every order came out perfect and on time. The kitchen ran like a well-oiled machine under your command."}
	elseif s >= 60 then return {stars=2, rating="Line Cook",     message="Solid shift. A few fumbles but the kitchen stayed afloat. Keep your station awareness sharp and you'll run this kitchen."}
	elseif s >= 30 then return {stars=1, rating="Kitchen Helper", message="Rough start. Culinary work demands precision under pressure. Study your station flow and you'll get there."}
	else                return {stars=0, rating="Trainee",        message="The kitchen was in the weeds tonight. Study the pipeline carefully and try again next shift."} end
end

--------------------------------------------------------------
-- PROMPTS
--------------------------------------------------------------
local prompts = {}
local function setPromptsEnabled(on)
	for _, pp in pairs(prompts) do
		if pp and pp.Parent then pp.Enabled = on end
	end
end

--------------------------------------------------------------
-- STATE
--------------------------------------------------------------
local state = {}
local function newState()
	return {
		orderIdx=0, stepIdx=0, score=100,
		waitingCinema=false, waitingTicket=false,
		timerThread=nil, ticketTimer=nil,
		orderScores={0,0,0},
		waitingStart=false, started=false,
	}
end

local startNextOrder  -- forward declare

local function cancelAll(st)
	if st.timerThread then pcall(function() task.cancel(st.timerThread) end); st.timerThread = nil end
	if st.ticketTimer then pcall(function() task.cancel(st.ticketTimer) end); st.ticketTimer = nil end
end

local function advanceStep(plr, st)
	local order = ORDERS[st.orderIdx]; if not order then return end
	st.stepIdx = st.stepIdx + 1
	if st.stepIdx > #order.steps then
		cancelAll(st)
		st.orderScores[st.orderIdx] = st.score
		OrderDone:FireClient(plr, st.orderIdx, st.score, "Served on time! ✓")
		task.wait(3.2)
		if state[plr] == st then task.spawn(function() startNextOrder(plr, st) end) end
	else
		local step = order.steps[st.stepIdx]
		NextTask:FireClient(plr, st.stepIdx, step.prompt, step.icon)
	end
end

local function startOrderTimer(plr, st, order, custom)
	if st.timerThread then pcall(function() task.cancel(st.timerThread) end); st.timerThread = nil end
	st.timerThread = task.delay(custom or order.timeLimit, function()
		if not state[plr] or state[plr] ~= st then return end
		if st.waitingCinema then
			task.wait(9)
			if not state[plr] or state[plr] ~= st or st.waitingCinema then return end
		end
		st.score = math.max(0, st.score - 33)
		st.orderScores[st.orderIdx] = st.score
		TaskFailed:FireClient(plr, st.orderIdx, st.score, 33, ORDERS[st.orderIdx].dishName)
		task.wait(4.0)
		if state[plr] == st then task.spawn(function() startNextOrder(plr, st) end) end
	end)
end

local function onTicketDismissed(plr)
	local st = state[plr]; if not st or not st.waitingTicket then return end
	st.waitingTicket = false
	if st.ticketTimer then pcall(function() task.cancel(st.ticketTimer) end); st.ticketTimer = nil end
	local order = ORDERS[st.orderIdx]; if not order then return end
	local step  = order.steps[st.stepIdx]; if not step then return end
	NextTask:FireClient(plr, st.stepIdx, step.prompt, step.icon)
	startOrderTimer(plr, st, order)
end
TicketDismissed.OnServerEvent:Connect(onTicketDismissed)

startNextOrder = function(plr, st)
	local ok, err = pcall(function()
		cancelAll(st)
		st.orderIdx = st.orderIdx + 1
		if st.orderIdx > #ORDERS then
			-- Calculate average score from all orders
			local totalScore = 0
			local orderCount = 0
			for _, score in pairs(st.orderScores) do
				totalScore = totalScore + score
				orderCount = orderCount + 1
			end
			local avgScore = orderCount > 0 and math.floor(totalScore / orderCount) or 0
			
			local r = getRating(avgScore)
			ShowResults:FireClient(plr, {
				finalScore  = avgScore,
				stars       = r.stars,
				rating      = r.rating,
				message     = r.message,
				orderScores = st.orderScores,
			})
			
			-- Fire WorldCompleted event for PlaySequence to know ChefWorld is done
			print("[ChefWorld] " .. plr.Name .. " completed ChefWorld! Avg Score: " .. avgScore)
			local completionEvent = ReplicatedStorage:FindFirstChild("WorldCompleted")
			if completionEvent and completionEvent:IsA("BindableEvent") then
				completionEvent:Fire(plr, "ChefWorld", {
					finalScore = avgScore,
					stars = r.stars,
					rating = r.rating,
					orderScores = st.orderScores,
				})
			end
			return
		end
		local order      = ORDERS[st.orderIdx]
		st.stepIdx       = 1
		st.waitingTicket = true
		st.waitingCinema = false
		StartOrder:FireClient(plr, {
			orderNum         = st.orderIdx,
			totalOrders      = #ORDERS,
			dishName         = order.dishName,
			steps            = order.steps,
			timeLimit        = order.timeLimit,
			isRush           = order.isRush,
			ingredientLabels = order.ingredientLabels,
			ingredientColors = order.ingredientColors,
		})
		-- 15s backstop: auto-dismiss if player ignores ticket
		st.ticketTimer = task.delay(15, function()
			if state[plr] == st and st.waitingTicket then
				onTicketDismissed(plr)
			end
		end)
	end)
	if not ok then warn("[ChefWorld] startNextOrder error:", err) end
end

--------------------------------------------------------------
-- STATION INTERACTION
--------------------------------------------------------------
local function onStation(plr, name)
	local st = state[plr]
	if not st or not st.started or st.waitingCinema then return end
	
	-- If player is at a station while ticket is showing, auto-dismiss ticket
	if st.waitingTicket then
		onTicketDismissed(plr)
	end
	
	local order = ORDERS[st.orderIdx]; if not order then return end
	local step  = order.steps[st.stepIdx]; if not step then return end
	if name == step.station then
		st.waitingCinema = true
		setPromptsEnabled(false)
		if step.isCook and st.timerThread then
			pcall(function() task.cancel(st.timerThread) end); st.timerThread = nil
		end
		PlayCinematic:FireClient(plr, {
			station          = name,
			stepIdx          = st.stepIdx,
			dishName         = order.dishName,
			isCook           = step.isCook,
			cookTime         = step.cookTime,
			ingredientLabels = order.ingredientLabels,
			ingredientColors = order.ingredientColors,
			isRush           = order.isRush,
		})
	else
		st.score = math.max(0, st.score - 5)
		WrongStation:FireClient(plr, st.score)
	end
end

CinematicDone.OnServerEvent:Connect(function(plr)
	local st = state[plr]; if not st or not st.waitingCinema then return end
	st.waitingCinema = false
	setPromptsEnabled(true)
	local order = ORDERS[st.orderIdx]
	if order then
		local step = order.steps[st.stepIdx]
		if step and step.isCook then
			startOrderTimer(plr, st, order, math.max(20, order.timeLimit * 0.4))
		end
	end
	advanceStep(plr, st)
end)

-- Handle order timeout (client timer ran out)
OrderTimedOut.OnServerEvent:Connect(function(plr)
	local st = state[plr]; if not st or not st.started then return end
	print("[ChefWorld] Order timed out for", plr.Name, "order", st.orderIdx)
	
	cancelAll(st)
	st.waitingCinema = false
	setPromptsEnabled(true)
	
	-- Record 0 for this order
	st.orderScores[st.orderIdx] = 0
	
	-- Move to next order
	task.spawn(function() startNextOrder(plr, st) end)
end)

PlayerReady.OnServerEvent:Connect(function(plr, action)
	local st = state[plr]; if not st then return end
	if action == "START" and st.waitingStart and not st.started then
		st.started      = true
		st.waitingStart = false
		st.orderIdx     = 0
		st.stepIdx      = 0
		task.spawn(function() startNextOrder(plr, st) end)
	elseif action == "COMPLETE" then
		cancelAll(st)
		state[plr] = newState()
	end
end)

--------------------------------------------------------------
-- AUTO-START — starts tutorial automatically for a player
-- No trigger needed - starts when player enters ChefWorld
--------------------------------------------------------------
local function autoStartForPlayer(plr)
	print("[ChefWorld] autoStartForPlayer called for:", plr.Name)
	
	-- Wait for client UI to fully initialize
	-- The client needs time to: load script, wait for flag, connect handlers
	print("[ChefWorld] Waiting 3 seconds for client UI to be ready...")
	task.wait(3.0)
	
	local st = state[plr]
	print("[ChefWorld] Player state check - st:", st ~= nil, "started:", st and st.started, "waitingStart:", st and st.waitingStart)
	
	if st and not st.started and not st.waitingStart then
		st.waitingStart = true
		print("[ChefWorld] >>> FIRING ShowTutorial to:", plr.Name)
		ShowTutorial:FireClient(plr)
		print("[ChefWorld] ShowTutorial fired successfully!")
	else
		print("[ChefWorld] Did not fire ShowTutorial - conditions not met")
	end
end

--------------------------------------------------------------
-- STATION PROMPTS — also uses WaitForChild
--------------------------------------------------------------
local function setupPrompts()
	local cw  = workspace:WaitForChild("ChefWorld", 30); if not cw then return end
	local kit = cw:WaitForChild("Kitchen", 10); if not kit then return end
	local sf  = kit:WaitForChild("Stations", 10)
	if not sf then warn("[ChefWorld] Stations folder missing"); return end

	for _, name in ipairs({"Fridge","PrepStation","Stove","ServingCounter"}) do
		local p = sf:WaitForChild(name, 10)
		if not p then warn("[ChefWorld] Missing station: " .. name); continue end

		local ex = p:FindFirstChildOfClass("ProximityPrompt")
		if ex then ex:Destroy() end

		local pp               = Instance.new("ProximityPrompt")
		pp.ActionText          = "Use"
		pp.ObjectText          = name
		pp.KeyboardKeyCode     = Enum.KeyCode.E
		pp.HoldDuration        = 0
		pp.MaxActivationDistance = 9
		pp.Enabled             = true
		pp.Parent              = p
		prompts[name]          = pp

		pp.Triggered:Connect(function(plr2) onStation(plr2, name) end)
		print("[ChefWorld] Station ready:", name)
	end

	print("[ChefWorld] All 4 stations online.")
end

--------------------------------------------------------------
-- PLAYER LIFECYCLE
-- Tutorial starts ONLY when client fires ActivateChefWorld
--------------------------------------------------------------
local function initPlayer(plr)
	state[plr] = newState()
	
	-- Handle existing character (Studio mode or script reload)
	if plr.Character then
		local h = plr.Character:FindFirstChild("Humanoid")
		if h and h.RigType == Enum.HumanoidRigType.R15 then
			warn("[VOCA] " .. plr.Name .. " is R15 — set StarterPlayer Rig to R6!")
		end
	end
	
	-- Reset state on respawn (but don't re-start tutorial)
	plr.CharacterAdded:Connect(function()
		local oldState = state[plr]
		if oldState and not oldState.started then
			state[plr] = newState()
		end
	end)
end

Players.PlayerAdded:Connect(initPlayer)
Players.PlayerRemoving:Connect(function(plr)
	if state[plr] then cancelAll(state[plr]) end
	state[plr] = nil
	activatedPlayers[plr] = nil
end)

-- Handle players already in server (Studio Play mode)
for _, plr in Players:GetPlayers() do initPlayer(plr) end

--------------------------------------------------------------
-- CLIENT ACTIVATION HANDLER
-- Client fires ActivateChefWorld when player enters ChefWorld
--------------------------------------------------------------
-- Track players who need tutorial started
local pendingTutorial = {}

ActivateChefWorld.OnServerEvent:Connect(function(plr)
	print("[ChefWorld] ActivateChefWorld received from:", plr.Name)
	
	-- Prevent double-activation
	if activatedPlayers[plr] then
		print("[ChefWorld] Player already activated, ignoring")
		return
	end
	activatedPlayers[plr] = true
	pendingTutorial[plr] = true
	
	-- Make sure player has state
	if not state[plr] then
		initPlayer(plr)
	end
	
	-- Tell the client UI to respond with ChefUIReady
	print("[ChefWorld] Sending RequestUIReady to:", plr.Name)
	RequestUIReady:FireClient(plr)
	
	-- Timeout fallback: if client doesn't respond within 5 seconds, start anyway
	task.delay(5, function()
		if pendingTutorial[plr] and plr and plr.Parent then
			print("[ChefWorld] Timeout waiting for ChefUIReady - starting tutorial anyway for:", plr.Name)
			pendingTutorial[plr] = nil
			autoStartForPlayer(plr)
		end
	end)
end)

-- Wait for client UI to signal it's ready before sending ShowTutorial
ChefUIReady.OnServerEvent:Connect(function(plr)
	print("[ChefWorld] ChefUIReady received from:", plr.Name)
	
	if not pendingTutorial[plr] then
		print("[ChefWorld] No pending tutorial for this player")
		return
	end
	pendingTutorial[plr] = nil
	
	-- Small delay to ensure everything is settled
	task.delay(0.3, function()
		if plr and plr.Parent then
			print("[ChefWorld] Starting tutorial for:", plr.Name)
			autoStartForPlayer(plr)
		end
	end)
end)

-- Setup station prompts
task.spawn(setupPrompts)

print("[ChefWorld] v10 Server ready - waiting for client activation.")
