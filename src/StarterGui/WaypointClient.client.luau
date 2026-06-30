--[[
	WaypointClient.luau
	LocalScript: StarterGui/WaypointClient
	
	Shows the player which room to go to next:
	- Floating arrow above the active room's DoorMarker
	- Glowing floor path leading to that room
	- Room purpose labels above each door
	- Hides waypoints for completed rooms
	
	Listens to NurseWorldRemotes/UpdateWaypoint event from server.
	
	WORKSPACE REQUIRED:
	  PatientBed_01/DoorMarker (Part above doorway)
	  PatientBed_02/DoorMarker
	  PatientBed_03/DoorMarker
	  NurseWorld/FloorMarkers/ (Folder)
	    Floor_R1_1, Floor_R1_2, Floor_R1_3
	    Floor_R2_1, Floor_R2_2, Floor_R2_3
	    Floor_R3_1, Floor_R3_2, Floor_R3_3
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

--------------------------------------------------------------
-- COLORS
--------------------------------------------------------------
local accentColor = Color3.fromRGB(134, 239, 172) -- green
local dimColor = Color3.fromRGB(55, 65, 81)
local completedColor = Color3.fromRGB(74, 222, 128)
local lockedColor = Color3.fromRGB(80, 80, 90)
local floorGlowColor = Color3.fromRGB(134, 239, 172)

--------------------------------------------------------------
-- ROOM CONFIG
--------------------------------------------------------------
local roomNames = { "Office", "Medication Room", "ICU" }
local roomSubtitles = { "File Review", "Safety Protocol", "Emergency Response" }
local bedNames = { "PatientBed_01", "PatientBed_02", "PatientBed_03" }
local floorPrefixes = { "Floor_R1_", "Floor_R2_", "Floor_R3_" }

--------------------------------------------------------------
-- STATE
--------------------------------------------------------------
local activeRoom = 1
local completedRooms = {}
local doorArrows = {} -- { [roomIndex] = BillboardGui }
local doorLabels = {} -- { [roomIndex] = BillboardGui }
local floorGlows = {} -- { [roomIndex] = { Part } }
local floorLights = {} -- { [roomIndex] = { PointLight } }
local pulseConnection = nil
local pulseTime = 0

--------------------------------------------------------------
-- FIND WORKSPACE OBJECTS
--------------------------------------------------------------
local function getNurseWorld()
	return workspace:FindFirstChild("NurseWorld")
end

local function getBed(index)
	local nw = getNurseWorld()
	local beds = nw and nw:FindFirstChild("PatientBeds")
	return beds and beds:FindFirstChild(bedNames[index])
end

local function getDoorMarker(index)
	local bed = getBed(index)
	return bed and bed:FindFirstChild("DoorMarker", true)
end

local function getFloorMarkers(index)
	local nw = getNurseWorld()
	local folder = nw and nw:FindFirstChild("FloorMarkers")
	if not folder then return {} end

	local markers = {}
	local prefix = floorPrefixes[index]
	for j = 1, 10 do -- support up to 10 markers per room
		local marker = folder:FindFirstChild(prefix .. j)
		if marker then
			table.insert(markers, marker)
		end
	end
	return markers
end

--------------------------------------------------------------
-- CREATE DOOR LABEL (room purpose name above each door)
--------------------------------------------------------------
local function createDoorLabel(roomIndex)
	local doorMarker = getDoorMarker(roomIndex)
	if not doorMarker then return end

	-- Remove existing
	local existing = doorMarker:FindFirstChild("RoomLabel")
	if existing then existing:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name = "RoomLabel"
	bb.Size = UDim2.new(0, 200, 0, 55)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 60
	bb.Parent = doorMarker

	-- Room name background
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 0, 28)
	bg.BackgroundColor3 = lockedColor
	bg.BackgroundTransparency = 0.2
	bg.Parent = bb

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 6)
	bgCorner.Parent = bg

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = roomNames[roomIndex]
	nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	nameLabel.TextSize = 13
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = bg

	-- Subtitle
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.Size = UDim2.new(1, 0, 0, 16)
	sub.Position = UDim2.new(0, 0, 0, 30)
	sub.BackgroundTransparency = 1
	sub.Text = roomSubtitles[roomIndex]
	sub.TextColor3 = Color3.fromRGB(140, 140, 150)
	sub.TextSize = 10
	sub.Font = Enum.Font.Gotham
	sub.Parent = bb

	doorLabels[roomIndex] = bb
end

--------------------------------------------------------------
-- CREATE/UPDATE FLOATING ARROW (above active room door)
--------------------------------------------------------------
local function createArrow(roomIndex)
	local doorMarker = getDoorMarker(roomIndex)
	if not doorMarker then return end

	-- Remove any existing arrows
	for _, arrow in doorArrows do
		if arrow and arrow.Parent then arrow:Destroy() end
	end
	doorArrows = {}

	local bb = Instance.new("BillboardGui")
	bb.Name = "WaypointArrow"
	bb.Size = UDim2.new(0, 120, 0, 80)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 100
	bb.Parent = doorMarker

	-- Arrow pointing down
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Size = UDim2.new(1, 0, 0, 40)
	arrow.Position = UDim2.new(0, 0, 1, -40)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▼"
	arrow.TextColor3 = accentColor
	arrow.TextSize = 30
	arrow.Font = Enum.Font.GothamBold
	arrow.Parent = bb

	-- "Go here" text
	local goText = Instance.new("TextLabel")
	goText.Size = UDim2.new(1, 0, 0, 22)
	goText.BackgroundTransparency = 1
	goText.Text = "► " .. roomNames[roomIndex]
	goText.TextColor3 = accentColor
	goText.TextSize = 14
	goText.Font = Enum.Font.GothamBold
	goText.Parent = bb

	doorArrows[roomIndex] = bb
end

local function removeAllArrows()
	for _, arrow in doorArrows do
		if arrow and arrow.Parent then arrow:Destroy() end
	end
	doorArrows = {}
end

--------------------------------------------------------------
-- FLOOR GLOW
--------------------------------------------------------------
local function activateFloorPath(roomIndex)
	-- Deactivate all floor paths first
	deactivateAllFloorPaths()

	local markers = getFloorMarkers(roomIndex)
	floorGlows[roomIndex] = markers
	floorLights[roomIndex] = {}

	for _, marker in markers do
		-- Make the floor marker VERY visible
		marker.Color = floorGlowColor
		marker.Material = Enum.Material.Neon
		marker.Transparency = 0.2 -- much more opaque
		marker.Size = Vector3.new(marker.Size.X, 0.3, marker.Size.Z) -- slightly thicker

		-- Add a bright point light
		local existing = marker:FindFirstChild("FloorLight")
		if existing then existing:Destroy() end

		local light = Instance.new("PointLight")
		light.Name = "FloorLight"
		light.Color = floorGlowColor
		light.Brightness = 2
		light.Range = 12
		light.Parent = marker

		-- Add a highlight for extra visibility
		local existingHL = marker:FindFirstChild("FloorHL")
		if existingHL then existingHL:Destroy() end

		local highlight = Instance.new("Highlight")
		highlight.Name = "FloorHL"
		highlight.FillColor = floorGlowColor
		highlight.FillTransparency = 0.3
		highlight.OutlineColor = floorGlowColor
		highlight.OutlineTransparency = 0.5
		highlight.Parent = marker

		table.insert(floorLights[roomIndex], light)
	end
end

function deactivateAllFloorPaths()
	for roomIdx, markers in floorGlows do
		for _, marker in markers do
			marker.Transparency = 1
			marker.Material = Enum.Material.SmoothPlastic
			local light = marker:FindFirstChild("FloorLight")
			if light then light:Destroy() end
			local hl = marker:FindFirstChild("FloorHL")
			if hl then hl:Destroy() end
		end
	end
	floorGlows = {}
	floorLights = {}
end

--------------------------------------------------------------
-- UPDATE DOOR LABEL APPEARANCE
--------------------------------------------------------------
local function updateDoorLabelState(roomIndex, state)
	-- state: "active", "completed", "locked"
	local bb = doorLabels[roomIndex]
	if not bb then return end

	local bg = bb:FindFirstChildWhichIsA("Frame")
	local nameLabel = bg and bg:FindFirstChild("Name")
	local sub = bb:FindFirstChild("Sub")

	if state == "active" then
		if bg then bg.BackgroundColor3 = accentColor; bg.BackgroundTransparency = 0.1 end
		if nameLabel then nameLabel.TextColor3 = Color3.fromRGB(20, 20, 20) end
		if sub then sub.TextColor3 = accentColor end
	elseif state == "completed" then
		if bg then bg.BackgroundColor3 = completedColor; bg.BackgroundTransparency = 0.4 end
		if nameLabel then nameLabel.Text = "✓ " .. roomNames[roomIndex]; nameLabel.TextColor3 = completedColor end
		if sub then sub.Text = "Complete"; sub.TextColor3 = Color3.fromRGB(100, 180, 120) end
	elseif state == "locked" then
		if bg then bg.BackgroundColor3 = lockedColor; bg.BackgroundTransparency = 0.3 end
		if nameLabel then nameLabel.TextColor3 = Color3.fromRGB(150, 150, 160) end
		if sub then sub.TextColor3 = Color3.fromRGB(100, 100, 110) end
	end
end

--------------------------------------------------------------
-- PULSE ANIMATION
--------------------------------------------------------------
local function startPulse()
	if pulseConnection then return end
	pulseTime = 0

	pulseConnection = RunService.Heartbeat:Connect(function(dt)
		pulseTime = pulseTime + dt

		-- Pulse the active arrow
		for roomIdx, arrow in doorArrows do
			if arrow and arrow.Parent then
				local arrowLabel = arrow:FindFirstChild("Arrow")
				if arrowLabel then
					-- Bob up and down
					local bob = math.sin(pulseTime * 3) * 0.5
					arrow.StudsOffset = Vector3.new(0, 5 + bob, 0)
				end
			end
		end

		-- Pulse floor glow
		for roomIdx, lights in floorLights do
			for i, light in lights do
				if light and light.Parent then
					-- Wave effect across floor markers
					local wave = math.sin(pulseTime * 3 + i * 0.8) * 0.4
					light.Brightness = 0.6 + wave
					light.Parent.Transparency = 0.5 + wave * 0.3
				end
			end
		end
	end)
end

local function stopPulse()
	if pulseConnection then
		pulseConnection:Disconnect()
		pulseConnection = nil
	end
end

--------------------------------------------------------------
-- MAIN UPDATE FUNCTION
--------------------------------------------------------------
local function updateWaypoints(newActiveRoom, newCompletedRooms)
	activeRoom = newActiveRoom
	completedRooms = newCompletedRooms or completedRooms

	-- Update all door labels
	for i = 1, 3 do
		if completedRooms[i] then
			updateDoorLabelState(i, "completed")
		elseif i == activeRoom then
			updateDoorLabelState(i, "active")
		else
			updateDoorLabelState(i, "locked")
		end
	end

	-- Show arrow only for active room (if not in a task)
	removeAllArrows()
	if activeRoom and activeRoom >= 1 and activeRoom <= 3 and not completedRooms[activeRoom] then
		createArrow(activeRoom)
		activateFloorPath(activeRoom)
		startPulse()
	else
		deactivateAllFloorPaths()
		stopPulse()
	end
end

-- Hide everything (when player is inside a room doing a task)
local function hideWaypoints()
	removeAllArrows()
	deactivateAllFloorPaths()
	stopPulse()
end

--------------------------------------------------------------
-- INITIALIZE
--------------------------------------------------------------
local function init()
	-- Wait for world to load
	task.delay(1, function()
		-- Create door labels for all 3 rooms
		for i = 1, 3 do
			createDoorLabel(i)
		end

		-- Start with Room 1 active
		updateWaypoints(1, {})
	end)
end

--------------------------------------------------------------
-- LISTEN FOR SERVER UPDATES
--------------------------------------------------------------
-- Wait for NurseWorld to activate before listening for events
local remotes = ReplicatedStorage:FindFirstChild("NurseWorldRemotes")
if not remotes then
	print("[WaypointClient] Waiting for NurseWorld to activate...")
	while not ReplicatedStorage:FindFirstChild("NurseWorldRemotes") do
		task.wait(0.5)
	end
	remotes = ReplicatedStorage:FindFirstChild("NurseWorldRemotes")
end
print("[WaypointClient] NurseWorld active - listening for events")

-- Listen for waypoint updates from server
local waypointEvent = remotes:FindFirstChild("UpdateWaypoint")
if waypointEvent then
	waypointEvent.OnClientEvent:Connect(function(newActiveRoom, newCompletedRooms)
		updateWaypoints(newActiveRoom, newCompletedRooms)
	end)
end

-- Listen for scenario start (hide waypoints when entering a room)
local startEvent = remotes:FindFirstChild("StartScenario")
if startEvent then
	startEvent.OnClientEvent:Connect(function()
		hideWaypoints()
	end)
end

local room2Start = remotes:FindFirstChild("Room2Start")
if room2Start then
	room2Start.OnClientEvent:Connect(function()
		hideWaypoints()
	end)
end

local room3Start = remotes:FindFirstChild("Room3Start")
if room3Start then
	room3Start.OnClientEvent:Connect(function()
		hideWaypoints()
	end)
end

-- Listen for scenario complete (show waypoints again for next room)
local completeEvent = remotes:FindFirstChild("ScenarioComplete")
if completeEvent then
	completeEvent.OnClientEvent:Connect(function(completedRoom)
		local newCompleted = {}
		for k, v in completedRooms do
			newCompleted[k] = v
		end
		newCompleted[completedRoom] = true

		-- Find next active room
		local nextActive = nil
		for i = 1, 3 do
			if not newCompleted[i] then
				nextActive = i
				break
			end
		end

		updateWaypoints(nextActive, newCompleted)
	end)
end

init()

--------------------------------------------------------------
-- TEARDOWN (NurseWorld ended — normal completion OR skip)
--------------------------------------------------------------
local wpTornDown = false
local function teardownWaypoints()
	if wpTornDown then return end
	wpTornDown = true
	print("[WaypointClient] Tearing down")
	pcall(hideWaypoints) -- removeAllArrows + deactivateAllFloorPaths + stopPulse
	for _, bb in pairs(doorLabels) do
		if bb then pcall(function() bb:Destroy() end) end
	end
	doorLabels = {}
end

task.spawn(function()
	local nurseActive = ReplicatedStorage:FindFirstChild("NurseWorldActive")
	while not nurseActive do
		task.wait(0.2)
		nurseActive = ReplicatedStorage:FindFirstChild("NurseWorldActive")
	end
	while not nurseActive.Value do task.wait(0.2) end
	nurseActive:GetPropertyChangedSignal("Value"):Connect(function()
		if not nurseActive.Value then teardownWaypoints() end
	end)
end)

task.spawn(function()
	local stopRemote = remotes:FindFirstChild("StopNurseWorld") or remotes:WaitForChild("StopNurseWorld", 10)
	if stopRemote then
		stopRemote.OnClientEvent:Connect(teardownWaypoints)
	end
end)

print("[WaypointClient] Room navigation system initialized — arrows, floor glow, room labels.")
