-- MenuCameraFlythrough.client.luau
-- Loops through career environment cameras for the menu background
-- Order: Cyber → Chef → Hospital (3 seconds each, 9 second loop)
-- Starts immediately on the main menu — no intro cinematic, no black fade.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameState"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

print("=== MenuCameraFlythrough loaded ===")

-- Wait for character to load before starting the menu camera
local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("Humanoid")
print("MenuCameraFlythrough: Character loaded!")

-- CONFIGURATION
local CAMERA_DURATION = 3.0  -- 3 seconds per camera

-- Camera paths (start and end positions/orientations)
local CAMERA_PATHS = {
	{
		name = "Cyber",
		startPos = Vector3.new(-8710.846, 5531.035, 3769.769),
		endPos = Vector3.new(-8697.853, 5531.035, 3769.725),
		startRot = Vector3.new(0, 180, 0),  -- Rotated 180 to face correct direction
		endRot = Vector3.new(0, 180, 0),
	},
	{
		name = "Chef",
		startPos = Vector3.new(-9174.128, 5532.671, 3823.259),
		endPos = Vector3.new(-9168.85, 5530.014, 3817.981),
		startRot = Vector3.new(0, 300, 0),
		endRot = Vector3.new(0, 300, 0),
	},
	{
		name = "Hospital",
		startPos = Vector3.new(-9082.659, 5534.524, 3428.443),
		endPos = Vector3.new(-9074.172, 5534.524, 3439.771),
		startRot = Vector3.new(0, 220, 0),   -- Start facing 220 degrees
		endRot = Vector3.new(0, 270 - 53.159, 0),  -- End at 216.841
	},
}

-- Helper: Create CFrame from position and rotation (degrees)
local function createCFrame(pos, rot)
	return CFrame.new(pos) * CFrame.Angles(
		math.rad(rot.X),
		math.rad(rot.Y),
		math.rad(rot.Z)
	)
end

-- Helper: Animate camera between two CFrames
-- Returns true if stopped early (game started), false if completed normally
local function animateCamera(startCF, endCF, duration)
	local startTime = tick()

	while tick() - startTime < duration do
		if GameState.Started then return true end

		local elapsed = tick() - startTime
		local progress = elapsed / duration

		-- Lerp between start and end
		local currentCF = startCF:Lerp(endCF, progress)

		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = currentCF
		camera.Focus = currentCF * CFrame.new(0, 0, -10)

		RunService.RenderStepped:Wait()
	end

	-- Ensure we end exactly at the end position (only if game hasn't started)
	if not GameState.Started then
		camera.CFrame = endCF
		camera.Focus = endCF * CFrame.new(0, 0, -10)
	end
	return false
end

-- Set up the blurred / darkened / vignette menu backdrop (shown immediately)
local function setupMenuEffects()
	-- Blur for the dreamy menu background
	local existingBlur = Lighting:FindFirstChild("MenuBlur")
	if existingBlur then existingBlur:Destroy() end

	local blurEffect = Instance.new("BlurEffect")
	blurEffect.Name = "MenuBlur"
	blurEffect.Size = 16
	blurEffect.Parent = Lighting

	-- Navy blue dark overlay
	local existingOverlay = playerGui:FindFirstChild("MenuDarkOverlay")
	if existingOverlay then existingOverlay:Destroy() end

	local overlayGui = Instance.new("ScreenGui")
	overlayGui.Name = "MenuDarkOverlay"
	overlayGui.IgnoreGuiInset = true
	overlayGui.DisplayOrder = 50
	overlayGui.Parent = playerGui

	local overlay = Instance.new("Frame")
	overlay.Name = "DarkOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(5, 10, 30)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Parent = overlayGui

	-- Vignette around the edges
	local existingVignette = playerGui:FindFirstChild("MenuVignette")
	if existingVignette then existingVignette:Destroy() end

	local vignetteGui = Instance.new("ScreenGui")
	vignetteGui.Name = "MenuVignette"
	vignetteGui.IgnoreGuiInset = true
	vignetteGui.DisplayOrder = 100
	vignetteGui.Parent = playerGui

	local function addVignetteEdge(size, position, rotation)
		local frame = Instance.new("Frame")
		frame.Size = size
		frame.Position = position
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.Parent = vignetteGui

		local gradient = Instance.new("UIGradient")
		gradient.Rotation = rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
	end

	addVignetteEdge(UDim2.new(1, 0, 0.4, 0), UDim2.new(0, 0, 0, 0), 90)    -- top
	addVignetteEdge(UDim2.new(1, 0, 0.4, 0), UDim2.new(0, 0, 0.6, 0), -90) -- bottom
	addVignetteEdge(UDim2.new(0.3, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0)     -- left
	addVignetteEdge(UDim2.new(0.3, 0, 1, 0), UDim2.new(0.7, 0, 0, 0), 180) -- right

	print("MenuCameraFlythrough: Menu background effects ready")
end

-- Main menu camera loop
local function startMenuFlythrough()
	print("MenuCameraFlythrough: Starting menu background immediately")

	-- Remove any leftover fade screens (no black fade now — menu shows instantly)
	for _, gui in pairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and (gui.Name == "CinematicFade" or gui.Name == "CinematicFadeOut" or gui.Name == "MenuFade") then
			gui:Destroy()
		end
	end

	setupMenuEffects()

	-- Infinite loop through cameras
	while true do
		if GameState.Started then break end
		for _, camPath in ipairs(CAMERA_PATHS) do
			if GameState.Started then break end
			print("MenuCameraFlythrough: " .. camPath.name .. " camera")

			local startCF = createCFrame(camPath.startPos, camPath.startRot)
			local endCF = createCFrame(camPath.endPos, camPath.endRot)

			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = startCF
			camera.Focus = startCF * CFrame.new(0, 0, -10)

			local stopped = animateCamera(startCF, endCF, CAMERA_DURATION)
			if stopped then break end
		end

		if GameState.Started then break end
		print("MenuCameraFlythrough: Loop complete, restarting...")
	end

	-- Cleanup when game starts (all behind the black screen)
	if GameState.Started then
		print("MenuCameraFlythrough: Game started, cleaning up menu effects...")

		local blur = Lighting:FindFirstChild("MenuBlur")
		if blur then blur:Destroy() end

		local overlay = playerGui:FindFirstChild("MenuDarkOverlay")
		if overlay then overlay:Destroy() end

		local vignette = playerGui:FindFirstChild("MenuVignette")
		if vignette then vignette:Destroy() end

		print("MenuCameraFlythrough: Menu effects cleaned up")
	end
end

-- Start the menu background immediately (no intro cinematic to wait for)
startMenuFlythrough()
