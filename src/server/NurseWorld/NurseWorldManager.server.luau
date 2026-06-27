--[[
	NurseWorldManager_v2.luau (FIXED)
	Script: ServerScriptService/NurseWorld/NurseWorldManager
	
	Main orchestrator for the Nursing world.
	Room 1: Question-based triage
	Room 2: Click objects in correct order
	Room 3: Code Blue emergency
	
	IMPORTANT: Waits for a player to enter NurseWorld before initializing
	to avoid interfering with the intro/cybersecurity sections.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

--------------------------------------------------------------
-- WAIT FOR PLAYER TO ENTER NURSEWORLD
--------------------------------------------------------------
-- Don't initialize until a player is actually in the NurseWorld area
-- This prevents the first-person lock and UI from activating during intro

local function waitForNurseWorldEntry()
	print("[NurseWorldManager] Waiting for player to enter NurseWorld...")
	
	-- Get NurseWorld spawn location
	local nurseWorld = workspace:WaitForChild("NurseWorld", 60)
	if not nurseWorld then
		warn("[NurseWorldManager] NurseWorld not found in workspace after 60s!")
		return false
	end
	
	local spawnLocation = nurseWorld:FindFirstChild("SpawnLocation")
	if not spawnLocation then
		-- Try finding it in PatientBeds
		local beds = nurseWorld:FindFirstChild("PatientBeds")
		if beds then
			local bed1 = beds:FindFirstChild("PatientBed_01")
			if bed1 then
				spawnLocation = bed1:FindFirstChild("SpawnLocation") or bed1
			end
		end
	end
	
	if not spawnLocation then
		warn("[NurseWorldManager] No SpawnLocation found, using NurseWorld origin")
		spawnLocation = nurseWorld
	end
	
	local spawnPos = spawnLocation:IsA("BasePart") and spawnLocation.Position 
		or (spawnLocation:IsA("Model") and spawnLocation:GetPivot().Position)
		or Vector3.new(0, 0, 0)
	
	-- Wait for any player to be within 50 studs of NurseWorld spawn
	while true do
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local distance = (hrp.Position - spawnPos).Magnitude
					if distance < 100 then
						print("[NurseWorldManager] Player", player.Name, "entered NurseWorld area!")
						return true
					end
				end
			end
		end
		task.wait(0.5)
	end
end

-- Wait before initializing
if not waitForNurseWorldEntry() then
	return -- Exit script if NurseWorld doesn't exist
end

print("[NurseWorldManager] Initializing NurseWorld systems...")

-- Load modules (only after player enters)
local NurseModules = ReplicatedStorage:WaitForChild("NurseWorld")
local Room1Config = require(NurseModules:WaitForChild("Room1_Triage"))
local Room2Config = require(NurseModules:WaitForChild("Room2_MedSafety"))
local Room3Config = require(NurseModules:WaitForChild("Room3_CodeBlue"))
local ScoreManagerModule = require(NurseModules:WaitForChild("ScoreManager"))

--------------------------------------------------------------
-- REMOTE EVENTS (created only after player enters NurseWorld)
--------------------------------------------------------------
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "NurseWorldRemotes"
remotesFolder.Parent = ReplicatedStorage

local function createRemote(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

-- Room 1 remotes
local R1_StartScenario = createRemote("StartScenario")
local R1_ShowTask = createRemote("ShowTask")
local R1_ShowFeedback = createRemote("ShowFeedback")

-- Room 2 remotes
local R2_Start = createRemote("Room2Start")
local R2_Click = createRemote("Room2Click")
local R2_Feedback = createRemote("Room2Feedback")
local R2_Complete = createRemote("Room2Complete")

-- Room 3 remotes
local R3_Start = createRemote("Room3Start")
local R3_Action = createRemote("Room3Action")
local R3_Complete = createRemote("Room3Complete")

-- Shared remotes
local ChoiceMadeEvent = createRemote("ChoiceMade")
local UpdateScoreEvent = createRemote("UpdateScore")
local ShowResultsEvent = createRemote("ShowResults")
local ScenarioCompleteEvent = createRemote("ScenarioComplete")
local UpdateProgressEvent = createRemote("UpdateProgress")
local UpdateWaypointEvent = createRemote("UpdateWaypoint")

print("[NurseWorldManager] Remote events created - NurseWorld is now active!")

--------------------------------------------------------------
-- PLAYER STATE
--------------------------------------------------------------
local playerStates = {}

local function initPlayerState(player: Player)
	playerStates[player] = {
		scoreManager = ScoreManagerModule.new(),
		currentRoom = 0,
		currentTask = 0,
		phase = "IDLE",
		completedRooms = {},
		roomScores = { 0, 0, 0 },
		-- Track actual per-room scores (each room starts at 100, deductions are per-room)
		room1Score = 100,
		room2Score = 100,
		room3Score = 100,
		room1Deductions = 0,
		room2Mistakes = 0,
	}
end

local function getState(player: Player)
	return playerStates[player]
end

--------------------------------------------------------------
-- FORWARD DECLARATIONS (fixes "attempt to call nil" errors)
--------------------------------------------------------------
local startRoom1
local startRoom2
local startRoom3
local sendRoom1Task
local showFinalResults
local unlockNextRoom

--------------------------------------------------------------
-- ROOM 1: OFFICE FILE REVIEW (3 files, 1 question each)
--------------------------------------------------------------
startRoom1 = function(player: Player)
	local state = getState(player)
	if not state then return end

	local roomConfig = Room1Config.GetConfig()
	state.currentTask = 0 -- tracks which file we're on (1, 2, 3)

	-- Send start signal — client will show chair glow
	R1_StartScenario:FireClient(player, {
		id = roomConfig.id,
		title = roomConfig.title,
		fileCount = Room1Config.GetFileCount(),
	}, 1, 3)

	UpdateScoreEvent:FireClient(player, state.scoreManager:GetScore())
end

sendRoom1Task = function(player: Player)
	local state = getState(player)
	if not state then return end

	state.currentTask += 1
	local fileIndex = state.currentTask
	local totalFiles = Room1Config.GetFileCount()

	if fileIndex > totalFiles then
		-- All files done
		state.scoreManager:EndScenario("TRIAGE_01")
		state.roomScores[1] = state.scoreManager:GetScore()
		unlockNextRoom(player, 1)
		return
	end

	local file = Room1Config.GetFile(fileIndex)
	if not file then return end

	-- Send file data (patient info) and the question separately
	-- First send the file info for the file card
	R1_StartScenario:FireClient(player, {
		id = "FILE_" .. fileIndex,
		title = "Patient File #" .. fileIndex,
		patientName = file.patientName,
		briefing = file.briefing,
		vitals = file.vitals,
		fileIndex = fileIndex,
		totalFiles = totalFiles,
		isFile = true, -- flag so client knows this is a file, not initial start
	}, fileIndex, totalFiles)
end

--------------------------------------------------------------
-- ROOM 2: CLICK ORDER
--------------------------------------------------------------
startRoom2 = function(player: Player)
	local state = getState(player)
	if not state then return end
	R2_Start:FireClient(player)
	UpdateScoreEvent:FireClient(player, state.scoreManager:GetScore())
end

--------------------------------------------------------------
-- ROOM 3: CODE BLUE
--------------------------------------------------------------
startRoom3 = function(player: Player)
	local state = getState(player)
	if not state then return end
	R3_Start:FireClient(player)
	UpdateScoreEvent:FireClient(player, state.scoreManager:GetScore())
end

--------------------------------------------------------------
-- FINAL RESULTS
--------------------------------------------------------------
showFinalResults = function(player: Player)
	local state = getState(player)
	if not state then return end

	state.phase = "RESULTS"

	local summary = state.scoreManager:GetSummary()
	
	-- Add per-room scores to the summary
	summary.room1Score = state.room1Score
	summary.room2Score = state.room2Score
	summary.room3Score = state.room3Score
	summary.averageScore = math.floor((state.room1Score + state.room2Score + state.room3Score) / 3)
	
	ShowResultsEvent:FireClient(player, summary)

	print("[NurseWorldManager] " .. player.Name .. " completed Nursing World! Score: " .. summary.finalScore)
	print("[NurseWorldManager] Per-room scores: Room1=" .. state.room1Score .. ", Room2=" .. state.room2Score .. ", Room3=" .. state.room3Score)

	local completionEvent = ReplicatedStorage:FindFirstChild("WorldCompleted")
	if completionEvent and completionEvent:IsA("BindableEvent") then
		completionEvent:Fire(player, "NurseWorld", summary)
	end
end

--------------------------------------------------------------
-- ROOM UNLOCK SYSTEM
--------------------------------------------------------------
unlockNextRoom = function(player: Player, completedRoom: number)
	local state = getState(player)
	if not state then return end

	state.completedRooms[completedRoom] = true
	state.phase = "IDLE"
	state.currentRoom = 0

	local nurseWorld = workspace:FindFirstChild("NurseWorld")
	local beds = nurseWorld and nurseWorld:FindFirstChild("PatientBeds")
	if not beds then return end

	local bedNames = { "PatientBed_01", "PatientBed_02", "PatientBed_03" }

	for i, bedName in bedNames do
		local bed = beds:FindFirstChild(bedName)
		if not bed then continue end

		local interactPoint = bed:FindFirstChild("InteractPoint") or bed:FindFirstChildWhichIsA("BasePart")
		if not interactPoint then continue end

		local prompt = interactPoint:FindFirstChild("PatientPrompt")
		if not prompt then continue end

		if state.completedRooms[i] then
			prompt.Enabled = false
		elseif i == 1 or state.completedRooms[i - 1] then
			prompt.Enabled = true
		else
			prompt.Enabled = false
		end
	end

	ScenarioCompleteEvent:FireClient(player, completedRoom)

	-- Update waypoints for next room
	local nextActive = nil
	for i = 1, 3 do
		if not state.completedRooms[i] then
			nextActive = i
			break
		end
	end
	UpdateWaypointEvent:FireClient(player, nextActive, state.completedRooms)

	if state.completedRooms[1] and state.completedRooms[2] and state.completedRooms[3] then
		showFinalResults(player)
	end
end

--------------------------------------------------------------
-- PROXIMITY / TRIGGER SYSTEM
--------------------------------------------------------------
local room1Triggered = {} -- { [Player] = true } prevents re-triggering

local function setupProximityPrompts()
	local nurseWorld = workspace:FindFirstChild("NurseWorld")
	if not nurseWorld then
		warn("[NurseWorldManager] Workspace/NurseWorld not found!")
		return
	end

	local beds = nurseWorld:FindFirstChild("PatientBeds")
	if not beds then
		warn("[NurseWorldManager] PatientBeds folder not found!")
		return
	end

	local bedNames = { "PatientBed_01", "PatientBed_02", "PatientBed_03" }
	local patientNames = { "Nurse's Office", "Mr. Alvarez", "Ms. Chen" }

	for i, bedName in bedNames do
		local bed = beds:FindFirstChild(bedName)
		if not bed then
			warn("[NurseWorldManager] " .. bedName .. " not found!")
			continue
		end

		local interactPoint = bed:FindFirstChild("InteractPoint")
		if not interactPoint then
			if bed:IsA("Model") then
				interactPoint = bed.PrimaryPart or bed:FindFirstChildWhichIsA("BasePart")
			else
				interactPoint = bed
			end
		end

		if not interactPoint then continue end

		local roomIndex = i

		if i == 1 then
			-- ROOM 1: Trigger zone — walking in auto-starts
			-- Make the InteractPoint a large invisible trigger zone
			interactPoint.Size = Vector3.new(12, 8, 12) -- large enough to cover doorway/entrance
			interactPoint.CanCollide = false
			interactPoint.Transparency = 1
			interactPoint.Anchored = true

			interactPoint.Touched:Connect(function(hit)
				local hitPlayer = Players:GetPlayerFromCharacter(hit.Parent)
				if not hitPlayer then return end
				if room1Triggered[hitPlayer] then return end

				local state = getState(hitPlayer)
				if not state or state.phase ~= "IDLE" then return end
				if state.completedRooms[1] then return end

				room1Triggered[hitPlayer] = true
				state.currentRoom = 1
				state.phase = "ACTIVE"

				-- Disable other prompts
				for _, bn in bedNames do
					local b = beds:FindFirstChild(bn)
					if b then
						local ip = b:FindFirstChild("InteractPoint") or b:FindFirstChildWhichIsA("BasePart")
						if ip then
							local p = ip:FindFirstChild("PatientPrompt")
							if p then p.Enabled = false end
						end
					end
				end

				startRoom1(hitPlayer)
			end)
		else
			-- ROOMS 2 & 3: Keep proximity prompts
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "PatientPrompt"
			prompt.ActionText = "Enter"
			prompt.ObjectText = ({"Office", "Medication Room", "ICU"})[i]
			prompt.HoldDuration = 0.5
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Enabled = false -- locked until previous room is done
			prompt.Parent = interactPoint

			prompt.Triggered:Connect(function(triggerPlayer)
				local state = getState(triggerPlayer)
				if not state or state.phase ~= "IDLE" then return end

				if roomIndex > 1 and not state.completedRooms[roomIndex - 1] then
					return
				end

				if state.completedRooms[roomIndex] then return end

				state.currentRoom = roomIndex
				state.phase = "ACTIVE"

				for _, bn in bedNames do
					local b = beds:FindFirstChild(bn)
					if b then
						local ip = b:FindFirstChild("InteractPoint") or b:FindFirstChildWhichIsA("BasePart")
						if ip then
							local p = ip:FindFirstChild("PatientPrompt")
							if p then p.Enabled = false end
						end
					end
				end

				if roomIndex == 2 then
					startRoom2(triggerPlayer)
				elseif roomIndex == 3 then
					startRoom3(triggerPlayer)
				end
			end)
		end
	end
end

--------------------------------------------------------------
-- CLIENT EVENT HANDLERS
--------------------------------------------------------------

ChoiceMadeEvent.OnServerEvent:Connect(function(player, action, data)
	local state = getState(player)
	if not state then return end

	if action == "BEGIN" then
		-- Player sat down or pressed E on file — send first/next file
		if state.currentRoom == 1 then
			sendRoom1Task(player)
		end

	elseif action == "READY_FOR_QUESTION" then
		-- Player pressed E on file card, ready for the question
		if state.currentRoom == 1 then
			local fileIndex = state.currentTask
			local file = Room1Config.GetFile(fileIndex)
			if not file then return end

			-- Send the question for this file
			R1_ShowTask:FireClient(player, fileIndex, Room1Config.GetFileCount(), {
				prompt = file.question.prompt,
				choices = {
					{ text = file.question.choices[1].text },
					{ text = file.question.choices[2].text },
					{ text = file.question.choices[3].text },
				},
			})
		end

	elseif action == "CHOICE" and type(data) == "number" then
		if state.currentRoom == 1 then
			local fileIndex = state.currentTask
			local file = Room1Config.GetFile(fileIndex)
			if not file then return end

			local choice = file.question.choices[data]
			if not choice then return end

			state.scoreManager:RecordAnswer("TRIAGE_01", "file_" .. fileIndex, data, choice.isCorrect, choice.deduction)
			R1_ShowFeedback:FireClient(player, choice.isCorrect, choice.feedback, choice.deduction)
			UpdateScoreEvent:FireClient(player, state.scoreManager:GetScore())
			
			-- Track Room 1 deductions for per-room score
			if not choice.isCorrect then
				state.room1Deductions = state.room1Deductions + choice.deduction
				state.room1Score = math.max(0, 100 - state.room1Deductions)
			end
		end

	elseif action == "CONTINUE" then
		if state.currentRoom == 1 then
			-- After feedback, send next file
			sendRoom1Task(player)
		end

	elseif action == "COMPLETE" then
		print("[NurseWorldManager] " .. player.Name .. " acknowledged completion.")
	end
end)

R2_Click.OnServerEvent:Connect(function(player, action, data, extra)
	local state = getState(player)
	if not state or state.currentRoom ~= 2 then return end

	if action == "WRONG" then
		state.scoreManager:RecordAnswer("MEDSAFETY_02", "click_wrong", 0, false, 33)
		UpdateScoreEvent:FireClient(player, state.scoreManager:GetScore())
		-- Track Room 2 mistakes for per-room score
		state.room2Mistakes = state.room2Mistakes + 1
		state.room2Score = math.max(0, 100 - (state.room2Mistakes * 33))

	elseif action == "COMPLETE" then
		state.scoreManager:EndScenario("MEDSAFETY_02")
		state.roomScores[2] = state.scoreManager:GetScore()
		-- data is the final mistakes count from client
		if type(data) == "number" then
			state.room2Mistakes = data
			state.room2Score = math.max(0, 100 - (data * 33))
		end
		R2_Complete:FireClient(player)
		unlockNextRoom(player, 2)

	elseif action == "FAILED" then
		state.scoreManager:EndScenario("MEDSAFETY_02")
		state.roomScores[2] = state.scoreManager:GetScore()
		-- data is the final mistakes count from client
		if type(data) == "number" then
			state.room2Mistakes = data
			state.room2Score = math.max(0, 100 - (data * 33))
		end
		R2_Complete:FireClient(player)
		unlockNextRoom(player, 2)
	end
end)

R3_Action.OnServerEvent:Connect(function(player, action, score, passed)
	local state = getState(player)
	if not state or state.currentRoom ~= 3 then return end

	if action == "OUTCOME" then
		local room3Score = score or 0
		-- Store the actual Room 3 per-room score from the client
		state.room3Score = room3Score

		if room3Score >= 80 then
			-- Good, no deduction
		elseif room3Score >= 50 then
			state.scoreManager:RecordAnswer("CODEBLUE_03", "emergency", 0, false, 33)
		else
			state.scoreManager:RecordAnswer("CODEBLUE_03", "emergency_1", 0, false, 33)
			state.scoreManager:RecordAnswer("CODEBLUE_03", "emergency_2", 0, false, 33)
		end

		UpdateScoreEvent:FireClient(player, state.scoreManager:GetScore())

		if not passed then
			local nurseWorld = workspace:FindFirstChild("NurseWorld")
			local beds = nurseWorld and nurseWorld:FindFirstChild("PatientBeds")
			local bed3 = beds and beds:FindFirstChild("PatientBed_03")

			if bed3 then
				local spirit = bed3:FindFirstChild("PatientSpirit")
				if spirit then
					for _, part in spirit:GetDescendants() do
						if part:IsA("BasePart") then
							part.Transparency = 0.3
						end
					end

					local primaryPart = nil
					if spirit:IsA("Model") then
						primaryPart = spirit.PrimaryPart or spirit:FindFirstChildWhichIsA("BasePart")
					elseif spirit:IsA("BasePart") then
						primaryPart = spirit
					end

					if primaryPart then
						local endPos = primaryPart.Position + Vector3.new(0, 20, 0)
						TweenService:Create(primaryPart, TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
							CFrame = CFrame.new(endPos)
						}):Play()

						for _, part in spirit:GetDescendants() do
							if part:IsA("BasePart") then
								TweenService:Create(part, TweenInfo.new(4), { Transparency = 0.9 }):Play()
							end
						end
					end
				end
			end
		end

	elseif action == "CONTINUE" then
		state.scoreManager:EndScenario("CODEBLUE_03")
		state.roomScores[3] = state.scoreManager:GetScore()
		R3_Complete:FireClient(player)
		unlockNextRoom(player, 3)
	end
end)

--------------------------------------------------------------
-- PLAYER LIFECYCLE
--------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	initPlayerState(player)
	task.delay(1, function()
		UpdateScoreEvent:FireClient(player, 100)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playerStates[player] = nil
end)

for _, player in Players:GetPlayers() do
	initPlayerState(player)
end

--------------------------------------------------------------
-- INITIALIZE
--------------------------------------------------------------
setupProximityPrompts()
print("[NurseWorldManager] v2 initialized — 3 unique room mechanics.")

--------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------
local NurseWorldAPI = {}

function NurseWorldAPI.GetPlayerScore(player: Player): number?
	local state = getState(player)
	return state and state.scoreManager:GetScore()
end

function NurseWorldAPI.IsComplete(player: Player): boolean
	local state = getState(player)
	if not state then return false end
	return state.completedRooms[1] and state.completedRooms[2] and state.completedRooms[3]
end

function NurseWorldAPI.ResetPlayer(player: Player)
	initPlayerState(player)
	UpdateScoreEvent:FireClient(player, 100)
end

return NurseWorldAPI
