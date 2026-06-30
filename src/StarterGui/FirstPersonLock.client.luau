--[[
	FirstPersonLock.luau
	LocalScript: StarterGui/FirstPersonLock
	
	Realistic first person for NurseWorld ONLY.
	Waits for NurseWorldActive flag before enabling.
	All UI is navigated with arrow keys + Enter.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--------------------------------------------------------------
-- WAIT FOR NURSEWORLD ACTIVATION
--------------------------------------------------------------
-- Don't run until NurseWorldActive flag is set to true by PlaySequence
print("[FirstPersonLock] Waiting for NurseWorld to activate...")

local nurseActive = ReplicatedStorage:FindFirstChild("NurseWorldActive")

-- Wait for the flag to exist
while not nurseActive do
	task.wait(0.5)
	nurseActive = ReplicatedStorage:FindFirstChild("NurseWorldActive")
end

-- Wait for the flag to be true (NurseWorld has started)
while not nurseActive.Value do
	task.wait(0.2)
end

print("[FirstPersonLock] NurseWorld active - enabling first person lock")

--------------------------------------------------------------
-- FIRST PERSON LOCK (only now that NurseWorld is active)
--------------------------------------------------------------
player.CameraMinZoomDistance = 0.5
player.CameraMaxZoomDistance = 0.5

--------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------
local TARGET_FOV = 65
local BOB_SPEED = 8
local BOB_AMOUNT_Y = 0.4
local BOB_AMOUNT_X = 0.2
local bobTime = 0

--------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------
local function getHumanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local showParts = {
	["LeftUpperArm"] = true, ["LeftLowerArm"] = true, ["LeftHand"] = true,
	["RightUpperArm"] = true, ["RightLowerArm"] = true, ["RightHand"] = true,
	["Left Arm"] = true, ["Right Arm"] = true,
}

--------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------
local renderConn
local respawnConn

renderConn = RunService.RenderStepped:Connect(function(dt)
	-- FOV
	if camera.FieldOfView ~= TARGET_FOV then
		camera.FieldOfView = TARGET_FOV
	end

	-- Arms visible
	local character = player.Character
	if character then
		for _, part in character:GetChildren() do
			if part:IsA("BasePart") and showParts[part.Name] then
				part.LocalTransparencyModifier = 0
			end
		end
	end

	-- Head bob
	local humanoid = getHumanoid()
	if humanoid then
		local moveSpeed = humanoid.MoveDirection.Magnitude
		local onGround = humanoid.FloorMaterial ~= Enum.Material.Air

		if moveSpeed > 0.1 and onGround then
			bobTime = bobTime + dt * BOB_SPEED
			local bobY = math.sin(bobTime) * BOB_AMOUNT_Y * dt
			local bobX = math.cos(bobTime * 0.5) * BOB_AMOUNT_X * dt
			camera.CFrame = camera.CFrame * CFrame.new(bobX, bobY, 0)
		else
			bobTime = 0
		end
	end
end)

--------------------------------------------------------------
-- RESPAWN
--------------------------------------------------------------
respawnConn = player.CharacterAdded:Connect(function()
	task.delay(0.5, function()
		if not nurseActive.Value then return end
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
	end)
end)

--------------------------------------------------------------
-- TEARDOWN (when NurseWorld ends — normal completion OR skip)
-- Without this the first-person lock would keep forcing FOV 65 and a
-- locked zoom into the next world (Cybersecurity).
--------------------------------------------------------------
local tornDown = false
local function teardown()
	if tornDown then return end
	tornDown = true
	print("[FirstPersonLock] Tearing down first-person lock")
	if renderConn then renderConn:Disconnect(); renderConn = nil end
	if respawnConn then respawnConn:Disconnect(); respawnConn = nil end
	pcall(function()
		camera.FieldOfView = 70
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 128
	end)
end

nurseActive:GetPropertyChangedSignal("Value"):Connect(function()
	if not nurseActive.Value then
		teardown()
	end
end)

-- Also respond to the explicit stop remote fired on skip
task.spawn(function()
	local remotes = ReplicatedStorage:FindFirstChild("NurseWorldRemotes")
	if not remotes then return end
	local stopRemote = remotes:FindFirstChild("StopNurseWorld")
	if stopRemote then
		stopRemote.OnClientEvent:Connect(teardown)
	end
end)

print("[FirstPersonLock] Realistic first person initialized — FOV 65, head bob, arms visible.")
