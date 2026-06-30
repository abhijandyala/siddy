-- MenuBackground.client.luau
-- Locks the main menu to the in-world EndRoom camera and adds light cinematic
-- grading behind the button UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")
local GameState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameState"))

-- Kick off streaming for the EndRoom the instant this script loads, before
-- we wait for the character so those extra frames are not wasted.
task.defer(function()
	local endRoom = workspace:FindFirstChild("EndRoom")
	local earlyPos = endRoom and (pcall(function() return endRoom:GetPivot() end) and endRoom:GetPivot().Position) or nil
	if earlyPos then
		pcall(function() player:RequestStreamingAround(earlyPos) end)
	end
end)

local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("Humanoid")
local humanoid = character:FindFirstChildOfClass("Humanoid")
local hrp = character:FindFirstChild("HumanoidRootPart")
local originalHrpAnchored = hrp and hrp.Anchored or false
local originalWalkSpeed = humanoid and humanoid.WalkSpeed or 16
local originalJumpPower = humanoid and humanoid.JumpPower or 50
local originalJumpHeight = humanoid and humanoid.JumpHeight or 7.2

for _, gui in ipairs(playerGui:GetChildren()) do
	if gui:IsA("ScreenGui") and (
		gui.Name == "CinematicFade"
		or gui.Name == "CinematicFadeOut"
		or gui.Name == "MenuFade"
		or gui.Name == "MenuDarkOverlay"
		or gui.Name == "MenuVignette"
		or gui.Name == "MenuBackground"
	) then
		gui:Destroy()
	end
end

camera.CameraType = Enum.CameraType.Scriptable

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MenuBackground"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 0
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local function addOverlay(name, color, transparency, zIndex)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex
	frame.Parent = screenGui
	return frame
end

local tint = addOverlay("EndRoomTint", Color3.fromRGB(5, 8, 16), 0.30, 1)

local bottomShade = Instance.new("Frame")
bottomShade.Name = "BottomButtonShade"
bottomShade.Size = UDim2.fromScale(1, 0.34)
bottomShade.Position = UDim2.fromScale(0, 0.66)
bottomShade.BackgroundColor3 = Color3.new(0, 0, 0)
bottomShade.BackgroundTransparency = 0
bottomShade.BorderSizePixel = 0
bottomShade.ZIndex = 2
bottomShade.Parent = screenGui

local bottomGradient = Instance.new("UIGradient")
bottomGradient.Rotation = -90
bottomGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.08),
	NumberSequenceKeypoint.new(0.65, 0.42),
	NumberSequenceKeypoint.new(1, 1),
})
bottomGradient.Parent = bottomShade

local topShade = Instance.new("Frame")
topShade.Name = "TopTitleShade"
topShade.Size = UDim2.fromScale(1, 0.28)
topShade.BackgroundColor3 = Color3.new(0, 0, 0)
topShade.BackgroundTransparency = 0
topShade.BorderSizePixel = 0
topShade.ZIndex = 2
topShade.Parent = screenGui

local topGradient = Instance.new("UIGradient")
topGradient.Rotation = 90
topGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.14),
	NumberSequenceKeypoint.new(0.6, 0.62),
	NumberSequenceKeypoint.new(1, 1),
})
topGradient.Parent = topShade

local function addVignette(name, size, pos, rotation)
	local edge = Instance.new("Frame")
	edge.Name = name
	edge.Size = size
	edge.Position = pos
	edge.BackgroundColor3 = Color3.new(0, 0, 0)
	edge.BorderSizePixel = 0
	edge.ZIndex = 3
	edge.Parent = screenGui

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.55, 0.68),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = edge
end

addVignette("LeftVignette", UDim2.fromScale(0.24, 1), UDim2.fromScale(0, 0), 0)
addVignette("RightVignette", UDim2.fromScale(0.24, 1), UDim2.fromScale(0.76, 0), 180)

local function findEndRoom()
	return workspace:FindFirstChild("EndRoom")
end

local function findEndRoomCam()
	local endRoom = findEndRoom()
	local camPos = endRoom and endRoom:FindFirstChild("CamPos", true)
	if camPos and camPos:IsA("BasePart") then
		return camPos
	end
	return nil
end

local camPos = findEndRoomCam()
if not camPos then
	warn("[MenuBackground] workspace.EndRoom.CamPos was not found; using current camera CFrame")
end

local function pivotPosition(instance)
	if not instance then return nil end
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") or instance:IsA("Folder") then
		local ok, pivot = pcall(function()
			return instance:GetPivot()
		end)
		if ok then
			return pivot.Position
		end
	end
	return nil
end

local function getEndRoomStreamPosition()
	local endRoom = findEndRoom()
	local pedestals = endRoom and endRoom:FindFirstChild("Pedestals", true)
	if pedestals then
		local sum = Vector3.zero
		local count = 0
		for _, child in ipairs(pedestals:GetChildren()) do
			local pos = pivotPosition(child)
			if pos then
				sum += pos
				count += 1
			end
		end
		if count > 0 then
			return sum / count
		end
	end
	return pivotPosition(endRoom) or (camPos and camPos.Position) or camera.CFrame.Position
end

local function hideLocalCharacter()
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 1
		end
	end
end

local function showLocalCharacter()
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 0
		end
	end
end

-- Use CamPos as the streaming anchor if available (it's inside the Persistent
-- EndRoom so it loads immediately and gives us the exact room position).
local streamPosition = (camPos and camPos.Position)
	or getEndRoomStreamPosition()

hideLocalCharacter()
if humanoid then
	humanoid.WalkSpeed  = 0
	humanoid.JumpPower  = 0
	humanoid.JumpHeight = 0
end
if hrp then
	hrp.Anchored = true
	-- Place the character AT the room (not underground) so StreamingEnabled
	-- loads the full area including Stage Light descendants right away.
	if streamPosition then
		hrp.CFrame = CFrame.new(streamPosition + Vector3.new(0, 2, 0))
	end
end
if streamPosition then
	pcall(function() player:RequestStreamingAround(streamPosition) end)
end

local CAREER_LIGHT_COLORS = {
	aviation = Color3.fromRGB(105, 195, 255),
	chef = Color3.fromRGB(255, 220, 128),
	nurse = Color3.fromRGB(150, 255, 145),
	cyber = Color3.fromRGB(235, 150, 255),
}

local function careerColorFor(instance)
	local cursor = instance
	while cursor do
		local lowerName = string.lower(cursor.Name)
		for career, color in pairs(CAREER_LIGHT_COLORS) do
			if string.find(lowerName, career) then
				return color
			end
		end
		cursor = cursor.Parent
	end
	return Color3.fromRGB(210, 230, 255)
end

local function boostLight(light)
	light.Enabled    = true
	light.Color      = careerColorFor(light)
	light.Brightness = 8
	if light:IsA("PointLight") then
		light.Range = 50
	elseif light:IsA("SpotLight") then
		light.Range = 50
		light.Angle = 80
	end
end

local function enableAllPedestalLights()
	local endRoom  = workspace:FindFirstChild("EndRoom")
	local pedestals = endRoom and endRoom:FindFirstChild("Pedestals", true)
	if not pedestals then return end

	for _, d in ipairs(pedestals:GetDescendants()) do
		if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			boostLight(d)
		elseif d:IsA("Beam") or d:IsA("ParticleEmitter") then
			d.Enabled = true
		end
	end
end

-- Run once immediately for parts already present.
enableAllPedestalLights()

-- DescendantAdded listener: the moment any Light arrives inside Pedestals,
-- enable and boost it instantly — no waiting for a polling interval.
task.spawn(function()
	local endRoom = workspace:FindFirstChild("EndRoom")
		or workspace:WaitForChild("EndRoom", 20)
	if not endRoom then
		warn("[MenuBackground] EndRoom never found — stage lights unavailable")
		return
	end
	local pedestals = endRoom:FindFirstChild("Pedestals", true)
		or (function()
			local ok, f = pcall(function()
				return endRoom:WaitForChild("Pedestals", 15)
			end)
			return ok and f or nil
		end)()
	if not pedestals then
		warn("[MenuBackground] Pedestals folder not found inside EndRoom")
		return
	end
	print("[MenuBackground] Pedestals folder found — watching for light instances")

	-- Scan again now that we have a guaranteed reference.
	enableAllPedestalLights()

	-- Listen for anything that streams in after this point.
	local conn = pedestals.DescendantAdded:Connect(function(d)
		if GameState.Started then return end
		if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			boostLight(d)
			print("[MenuBackground] Stage light enabled:", d:GetFullName())
		elseif d:IsA("Beam") or d:IsA("ParticleEmitter") then
			d.Enabled = true
		end
	end)

	-- Also keep a slow retry in case a light arrives Enabled=false via server replication.
	local start = os.clock()
	while not GameState.Started and os.clock() - start < 30 do
		task.wait(1)
		if camPos then
			pcall(function() player:RequestStreamingAround(camPos.Position) end)
		end
		enableAllPedestalLights()
	end
	conn:Disconnect()
end)

local function cleanup(conn)
	if conn then
		conn:Disconnect()
	end
	if screenGui and screenGui.Parent then
		screenGui:Destroy()
	end
	showLocalCharacter()
	if humanoid then
		humanoid.WalkSpeed = originalWalkSpeed
		humanoid.JumpPower = originalJumpPower
		humanoid.JumpHeight = originalJumpHeight
	end
	if hrp then
		hrp.Anchored = originalHrpAnchored
	end
	camera.CameraType = Enum.CameraType.Custom
end

local elapsed = 0
local conn
conn = RunService.RenderStepped:Connect(function(dt)
	if GameState.Started then
		cleanup(conn)
		return
	end

	elapsed += dt
	if camPos and camPos.Parent then
		local drift = CFrame.new(
			math.sin(elapsed * 0.18) * 0.05,
			math.cos(elapsed * 0.22) * 0.035,
			0
		)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = camPos.CFrame * drift
		camera.Focus = camera.CFrame * CFrame.new(0, 0, -24)
	end

	tint.BackgroundTransparency = 0.30 + math.sin(elapsed * 0.45) * 0.025
end)
