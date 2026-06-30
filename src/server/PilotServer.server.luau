--[[
	PilotServer.luau  (v3 — FULL TASK SYSTEM)
	Script: ServerScriptService/PilotServer

	v3 — Full task flow:
	  Pre-Flight → Startup → In-Flight → Landing
	  Each task has 3 random scenarios
	  Per-task scoring, speed bonuses, results screen
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------------------
-- SINGLETON ENGINE GUARD
-- Neutralize a second copy of this module no matter how it is required
-- (the init.server.luau guard only catches copies that boot through it).
--------------------------------------------------------------
if _G.__PILOT_SERVER_ENGINE_BOOTED then
	warn("[PilotServer] Duplicate engine require BLOCKED - a second copy of the server exists in the place.")
	return {}
end
_G.__PILOT_SERVER_ENGINE_BOOTED = true

--------------------------------------------------------------
-- REMOTES
--------------------------------------------------------------
local function mkR(n)
	local folder = ReplicatedStorage:FindFirstChild("PilotRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PilotRemotes"
		folder.Parent = ReplicatedStorage
	end
	local r = folder:FindFirstChild(n)
	if r and r:IsA("RemoteEvent") then
		return r
	end
	r = Instance.new("RemoteEvent")
	r.Name = n
	r.Parent = folder
	return r
end

-- Cinematic flow (same as v2)
local ShowTutorial    = mkR("ShowTutorial")
local PlayerReady     = mkR("PlayerReady")
local ClientReady     = mkR("ClientReady")
local StartCinematic  = mkR("StartCinematic")
local CinematicDone   = mkR("CinematicDone")

-- Task flow (new v3)
local StartTask       = mkR("StartTask")       -- S→C: begin a task
local TaskComplete    = mkR("TaskComplete")    -- C→S: client finished a task
local ScoreUpdate     = mkR("ScoreUpdate")     -- S→C: live score push
local ShowResults     = mkR("ShowResults")     -- S→C: final results
local StopAviation    = mkR("StopAviation")    -- C→S: PlaySequence skips/ends the Aviation world

--------------------------------------------------------------
-- R6 ADVISORY
-- FBLA integration: the global movement lock was removed. Movement is only
-- locked by the client (PilotUIBase) while the Aviation world is actually
-- running, so the menu and the other career worlds are never affected.
--------------------------------------------------------------
Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function(c)
		local h = c:WaitForChild("Humanoid", 5)
		if h and h.RigType == Enum.HumanoidRigType.R15 then
			warn("[Pilot] " .. p.Name .. " is R15 — set Avatar Type to R6 for the cockpit pose.")
		end
	end)
end)

--------------------------------------------------------------
-- SCENARIOS
--------------------------------------------------------------
local SCENARIOS = {
	preflight = {
		{id="normal",  label="Standard Conditions",  icon="✓",  col={r=18,g=80,b=40},   bonusPts=0,  hasFault=false, hasWeather=false},
		{id="fault",   label="Fault Detected!",       icon="⚠",  col={r=90,g=45,b=10},   bonusPts=8,  hasFault=true,  hasWeather=false},
		{id="weather", label="Severe Weather Ahead",  icon="⛈",  col={r=30,g=40,b=90},   bonusPts=5,  hasFault=false, hasWeather=true},
	},
	startup = {
		{id="normal",  label="Clean Startup",         icon="✓",  col={r=18,g=80,b=40},   bonusPts=0,  hasSurge=false, hasStall=false},
		{id="surge",   label="Power Surge Warning!",  icon="⚡",  col={r=90,g=60,b=10},   bonusPts=8,  hasSurge=true,  hasStall=false},
		{id="stall",   label="Engine 2 Fault",        icon="🔴",  col={r=85,g=20,b=20},   bonusPts=10, hasSurge=false, hasStall=true},
	},
	inflight = {
		{id="normal",    label="Clear Skies",          icon="☀",  col={r=18,g=80,b=40},   bonusPts=0,  eventCount=2},
		{id="turbulence",label="Turbulence Warning",   icon="〰",  col={r=90,g=55,b=10},   bonusPts=8,  eventCount=3},
		{id="atc",       label="ATC Emergency Reroute",icon="📡",  col={r=30,g=40,b=90},   bonusPts=10, eventCount=3},
	},
	landing = {
		{id="normal",    label="Clear Approach",       icon="✓",  col={r=18,g=80,b=40},   bonusPts=0,  crosswind=false, emergency=false},
		{id="crosswind", label="Crosswind Landing",    icon="💨",  col={r=90,g=55,b=10},   bonusPts=8,  crosswind=true,  emergency=false},
		{id="emergency", label="Emergency Landing!",   icon="🔴",  col={r=85,g=20,b=20},   bonusPts=12, crosswind=false, emergency=true},
	},
}

local TASK_IDS = {"preflight", "startup", "inflight", "landing"}

local function rollScenario(taskId)
	local s = SCENARIOS[taskId]
	return s[math.random(#s)]
end

--------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------
local function scoreToGrade(s)
	-- Scores are normalized 0-100 per task
	if     s >= 95 then return "A+"
	elseif s >= 88 then return "A"
	elseif s >= 80 then return "B+"
	elseif s >= 70 then return "B"
	elseif s >= 55 then return "C"
	elseif s >= 40 then return "D"
	else                return "F" end
end

local TASK_LABEL = {"Pre-Flight", "Cockpit Startup", "In-Flight", "Landing"}

local function getRating(avg, anyFailed, weakIdx)
	local r
	if     avg >= 95 then r = {stars=3, rating="Captain",       message="Exceptional performance. Flawless execution on every system. This cockpit was in perfect hands from pushback to touchdown."}
	elseif avg >= 80 then r = {stars=3, rating="First Officer", message="Outstanding flight. You handled every situation with confidence. A few more hours and you'll have four stripes."}
	elseif avg >= 65 then r = {stars=2, rating="Flight Cadet",  message="Solid performance under pressure. You kept the aircraft safe. Work on your reaction time for the edge cases."}
	elseif avg >= 45 then r = {stars=2, rating="Student Pilot", message="The aircraft made it, but the margins were too tight. Review your checklists and practice those QTE windows."}
	elseif avg >= 25 then r = {stars=1, rating="Ground Crew",   message="Better suited to waving the batons right now. Study the procedures and try again — every pilot starts somewhere."}
	else                  r = {stars=0, rating="Passenger",     message="You did not demonstrate the skills required. A full review of all procedures is strongly recommended before the next flight."} end

	-- A failed section forfeits top honors, no matter how strong the average.
	if anyFailed then
		if r.stars >= 3 then
			r.stars = 2
			r.rating = "Flight Cadet"
		end
		local weak = TASK_LABEL[weakIdx] or "one section"
		r.message = "You failed the " .. weak .. " section — top honors are off the table until every stage is clean. " .. r.message
	end

	return r
end

--------------------------------------------------------------
-- STATE
--------------------------------------------------------------
local state = {}

local function newState()
	return {
		started       = false,
		stopped       = false,
		inCinematic   = false,
		awaitingComplete = false,
		taskIdx       = 0,
		totalScore    = 0,
		completedTasks = 0,
		taskResults   = {
			{score=0, grade="F", bonusPts=0, scenario="normal", failed=false, recorded=false},
			{score=0, grade="F", bonusPts=0, scenario="normal", failed=false, recorded=false},
			{score=0, grade="F", bonusPts=0, scenario="normal", failed=false, recorded=false},
			{score=0, grade="F", bonusPts=0, scenario="normal", failed=false, recorded=false},
		},
	}
end

local function fireNextTask(plr, st)
	if st.stopped then return end
	st.taskIdx = st.taskIdx + 1
	if st.taskIdx > #TASK_IDS then
		-- All done — compute debrief from the scores the client reported per task.
		local total, count = 0, 0
		local anyFailed = false
		local weakIdx = 1
		local weakest = 101
		for i = 1, #TASK_IDS do
			local tr = st.taskResults[i]
			if tr and tr.recorded then
				total = total + tr.score
				count = count + 1
				if tr.failed then anyFailed = true end
				if tr.score < weakest then
					weakest = tr.score
					weakIdx = i
				end
			end
		end
		local avg = (count > 0) and math.floor(total / count) or 0
		local r = getRating(avg, anyFailed, weakIdx)
		ShowResults:FireClient(plr, {
			avgScore    = avg,
			totalScore  = total,
			stars       = r.stars,
			rating      = r.rating,
			message     = r.message,
			taskResults = st.taskResults,
		})
		return
	end

	local taskId = TASK_IDS[st.taskIdx]
	local scen   = rollScenario(taskId)

	-- Small gap between tasks for head-look breather (shorter inflight → landing handoff)
	local gap = 2.2
	if st.taskIdx == 1 then
		gap = 0.5
	elseif taskId == "landing" and TASK_IDS[st.taskIdx - 1] == "inflight" then
		gap = 0.3
	end
	task.wait(gap)
	if st.stopped then return end

	st.awaitingComplete = true
	StartTask:FireClient(plr, {
		taskIdx  = st.taskIdx,
		taskId   = taskId,
		scenario = scen,
	})
end

--------------------------------------------------------------
-- REMOTE HANDLERS
--------------------------------------------------------------
local function offerTutorial(plr)
	local st = state[plr]
	if not st or st.started then return end
	ShowTutorial:FireClient(plr)
end

PlayerReady.OnServerEvent:Connect(function(plr, action)
	local st = state[plr]; if not st then return end
	if action == "START" and not st.started then
		st.started     = true
		st.inCinematic = true
		StartCinematic:FireClient(plr)
	end
end)

ClientReady.OnServerEvent:Connect(function(plr)
	local st = state[plr]
	if not st then
		state[plr] = newState()
		st = state[plr]
	end
	if not st.started then
		offerTutorial(plr)
	end
end)

CinematicDone.OnServerEvent:Connect(function(plr)
	local st = state[plr]; if not st then return end
	if not st.inCinematic then return end  -- already handled; ignore duplicate (retry / latency)
	st.inCinematic = false
	-- Begin task sequence
	task.spawn(function() fireNextTask(plr, st) end)
end)

TaskComplete.OnServerEvent:Connect(function(plr, data)
	local st = state[plr]; if not st or not st.started then return end

	-- Record into the slot the client reports (falls back to the current task).
	local idx = tonumber(data.taskIdx) or st.taskIdx
	if idx < 1 or idx > #TASK_IDS then return end
	if st.taskResults[idx].recorded then return end  -- already scored this section; ignore duplicate

	local earned = math.clamp(tonumber(data.score) or 0, 0, 100)
	local bonus  = math.clamp(tonumber(data.bonusPts) or 0, 0, 20)
	local scen   = data.scenarioId or "normal"

	st.taskResults[idx] = {
		score    = earned,
		grade    = scoreToGrade(earned),
		bonusPts = bonus,
		scenario = scen,
		failed   = data.failed or false,
		recorded = true,
	}

	-- Recompute totals from the recorded slots (no drifting accumulators).
	local total, count = 0, 0
	for i = 1, #TASK_IDS do
		if st.taskResults[i].recorded then
			total = total + st.taskResults[i].score
			count = count + 1
		end
	end
	st.totalScore     = total
	st.completedTasks = count

	ScoreUpdate:FireClient(plr, st.totalScore, earned, idx)

	-- Advance the flow only when the section we were waiting on just finished.
	if idx == st.taskIdx and st.awaitingComplete then
		st.awaitingComplete = false
		task.spawn(function() fireNextTask(plr, st) end)
	end
end)

--------------------------------------------------------------
-- TRIGGER REMOVED (FBLA)
-- Entry is driven by PlaySequence, not a world part. When the Aviation world
-- begins, PlaySequence boots the client UI which fires ClientReady, and the
-- handler above offers the tutorial. There is no proximity prompt / touch entry.
--------------------------------------------------------------

--------------------------------------------------------------
-- PLAYER LIFECYCLE
-- We only keep per-player state here. No movement lock and no auto-tutorial on
-- join; the flow is started by the client when the Aviation world runs.
--------------------------------------------------------------
local function initPlayer(plr)
	if not state[plr] then state[plr] = newState() end
end

Players.PlayerAdded:Connect(initPlayer)
Players.PlayerRemoving:Connect(function(plr) state[plr] = nil end)
for _, plr in Players:GetPlayers() do initPlayer(plr) end

--------------------------------------------------------------
-- STOP / SKIP
-- PlaySequence fires this when the player skips Aviation, or when the world
-- ends, so the task flow halts and nothing keeps running in the background
-- after the hand-off to the Chef world.
--------------------------------------------------------------
StopAviation.OnServerEvent:Connect(function(plr)
	local st = state[plr]; if not st then return end
	st.stopped          = true
	st.started          = false
	st.inCinematic      = false
	st.awaitingComplete = false
end)

return true

