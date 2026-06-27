-- MenuCameraFlythrough.client.luau
-- Loops through career environment cameras for the menu background
-- Order: Cyber → Chef → Hospital (3 seconds each, 9 second loop)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameState"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

print("=== MenuCameraFlythrough loaded ===")

-- Wait for character to load first (matches CinematicCamera's timing)
local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("Humanoid")
print("MenuCameraFlythrough: Character loaded!")

-- CONFIGURATION
local CAMERA_DURATION = 3.0  -- 3 seconds per camera
local FADE_DURATION = 1.0    -- 1 second fade in from black (dream transition)

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

-- Wait for cinematic intro to complete
-- Cinematic timing: wait(0.1) + Camera 1 (0.8s) + Camera 2 (5.0s) = 5.9s
-- Match exactly to avoid any gap or hold on black screen
local CINEMATIC_END_TIME = 5.9  -- Exact match to CinematicCamera timing

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
		
		-- Smooth easing
		local smoothProgress = progress
		
		-- Lerp between start and end
		local currentCF = startCF:Lerp(endCF, smoothProgress)
		
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

-- Main menu flythrough function
local function startMenuFlythrough()
	print("MenuCameraFlythrough: Starting menu flythrough!")
	
	-- STEP 1: Create a FRESH black screen FIRST (ensures continuous black coverage)
	local fadeGui = Instance.new("ScreenGui")
	fadeGui.Name = "MenuFade"
	fadeGui.IgnoreGuiInset = true
	fadeGui.DisplayOrder = 1000
	fadeGui.Parent = playerGui
	
	local fadeFrame = Instance.new("Frame")
	fadeFrame.Name = "FadeFrame"
	fadeFrame.Size = UDim2.new(1, 0, 1, 0)
	fadeFrame.Position = UDim2.new(0, 0, 0, 0)
	fadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)  -- Black
	fadeFrame.BackgroundTransparency = 0  -- Start fully black
	fadeFrame.BorderSizePixel = 0
	fadeFrame.Parent = fadeGui
	
	print("MenuCameraFlythrough: Fresh black screen created")
	
	-- STEP 2: Now safely destroy old fade GUIs (new one is already covering the screen)
	for _, gui in pairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui ~= fadeGui and (gui.Name == "CinematicFade" or gui.Name == "CinematicFadeOut") then
			print("MenuCameraFlythrough: Destroying " .. gui.Name)
			gui:Destroy()
		end
	end
	
	-- No wait here - proceed immediately to minimize black screen hold time
	
	local isFirstLoop = true
	
	-- Infinite loop through cameras
	while true do
		if GameState.Started then break end
		for i, camPath in ipairs(CAMERA_PATHS) do
			if GameState.Started then break end
			print("MenuCameraFlythrough: " .. camPath.name .. " camera")
			
			-- Create start and end CFrames
			local startCF = createCFrame(camPath.startPos, camPath.startRot)
			local endCF = createCFrame(camPath.endPos, camPath.endRot)
			
			-- First camera on first loop: fade from black to Cyber (camera moves during fade!)
			if isFirstLoop and i == 1 then
				-- Position camera while screen is black
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = startCF
				camera.Focus = startCF * CFrame.new(0, 0, -10)
				
				-- ADD EFFECTS BEFORE FADE (so they're visible immediately)
				
				-- Add BlurEffect for dreamy look
				local existingBlur = Lighting:FindFirstChild("MenuBlur")
				if existingBlur then existingBlur:Destroy() end
				
				local blurEffect = Instance.new("BlurEffect")
				blurEffect.Name = "MenuBlur"
				blurEffect.Size = 16  -- Blur intensity (balanced for quality)
				blurEffect.Parent = Lighting
				print("MenuCameraFlythrough: Blur effect added (Size = 16)")
				
				-- Add dark overlay to darken the blurred background
				local existingOverlay = playerGui:FindFirstChild("MenuDarkOverlay")
				if existingOverlay then existingOverlay:Destroy() end
				
				local overlayGui = Instance.new("ScreenGui")
				overlayGui.Name = "MenuDarkOverlay"
				overlayGui.IgnoreGuiInset = true
				overlayGui.DisplayOrder = 50  -- Below vignette but above camera
				overlayGui.Parent = playerGui
				
				local overlay = Instance.new("Frame")
				overlay.Name = "DarkOverlay"
				overlay.Size = UDim2.new(1, 0, 1, 0)
				overlay.Position = UDim2.new(0, 0, 0, 0)
				overlay.BackgroundColor3 = Color3.fromRGB(5, 10, 30)
				overlay.BackgroundTransparency = 0.35  -- 35% navy blue overlay
				overlay.BorderSizePixel = 0
				overlay.Parent = overlayGui
				print("MenuCameraFlythrough: Navy blue overlay added (35% opacity)")
				
				-- Create STRONGER vignette using gradient frames
				local existingVignette = playerGui:FindFirstChild("MenuVignette")
				if existingVignette then existingVignette:Destroy() end
				
				local vignetteGui = Instance.new("ScreenGui")
				vignetteGui.Name = "MenuVignette"
				vignetteGui.IgnoreGuiInset = true
				vignetteGui.DisplayOrder = 100
				vignetteGui.Parent = playerGui
				
				-- Top vignette gradient (LARGER and DARKER)
				local topVignette = Instance.new("Frame")
				topVignette.Size = UDim2.new(1, 0, 0.4, 0)  -- 40% of screen
				topVignette.Position = UDim2.new(0, 0, 0, 0)
				topVignette.BackgroundColor3 = Color3.new(0, 0, 0)
				topVignette.BorderSizePixel = 0
				topVignette.Parent = vignetteGui
				local topGradient = Instance.new("UIGradient")
				topGradient.Rotation = 90
				topGradient.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),    -- Solid black at edge
					NumberSequenceKeypoint.new(0.5, 0.5),
					NumberSequenceKeypoint.new(1, 1)     -- Transparent in middle
				})
				topGradient.Parent = topVignette
				
				-- Bottom vignette gradient (LARGER and DARKER)
				local bottomVignette = Instance.new("Frame")
				bottomVignette.Size = UDim2.new(1, 0, 0.4, 0)  -- 40% of screen
				bottomVignette.Position = UDim2.new(0, 0, 0.6, 0)
				bottomVignette.BackgroundColor3 = Color3.new(0, 0, 0)
				bottomVignette.BorderSizePixel = 0
				bottomVignette.Parent = vignetteGui
				local bottomGradient = Instance.new("UIGradient")
				bottomGradient.Rotation = -90
				bottomGradient.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),    -- Solid black at edge
					NumberSequenceKeypoint.new(0.5, 0.5),
					NumberSequenceKeypoint.new(1, 1)     -- Transparent in middle
				})
				bottomGradient.Parent = bottomVignette
				
				-- Left vignette gradient (LARGER and DARKER)
				local leftVignette = Instance.new("Frame")
				leftVignette.Size = UDim2.new(0.3, 0, 1, 0)  -- 30% of screen width
				leftVignette.Position = UDim2.new(0, 0, 0, 0)
				leftVignette.BackgroundColor3 = Color3.new(0, 0, 0)
				leftVignette.BorderSizePixel = 0
				leftVignette.Parent = vignetteGui
				local leftGradient = Instance.new("UIGradient")
				leftGradient.Rotation = 0
				leftGradient.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),    -- Solid black at edge
					NumberSequenceKeypoint.new(0.5, 0.5),
					NumberSequenceKeypoint.new(1, 1)     -- Transparent in middle
				})
				leftGradient.Parent = leftVignette
				
				-- Right vignette gradient (LARGER and DARKER)
				local rightVignette = Instance.new("Frame")
				rightVignette.Size = UDim2.new(0.3, 0, 1, 0)  -- 30% of screen width
				rightVignette.Position = UDim2.new(0.7, 0, 0, 0)
				rightVignette.BackgroundColor3 = Color3.new(0, 0, 0)
				rightVignette.BorderSizePixel = 0
				rightVignette.Parent = vignetteGui
				local rightGradient = Instance.new("UIGradient")
				rightGradient.Rotation = 180
				rightGradient.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),    -- Solid black at edge
					NumberSequenceKeypoint.new(0.5, 0.5),
					NumberSequenceKeypoint.new(1, 1)     -- Transparent in middle
				})
				rightGradient.Parent = rightVignette
				
				print("MenuCameraFlythrough: Strong vignette effect added")
				
				-- Start fade immediately - no wait to avoid black screen hold
				print("MenuCameraFlythrough: Starting 1 second FADE + camera movement...")
				
				-- Start the fade (runs in background)
				local fadeFromBlack = TweenService:Create(
					fadeFrame,
					TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
					{BackgroundTransparency = 1}
				)
				fadeFromBlack:Play()
				
				-- Camera moves during fade (full 3 seconds)
				local stopped = animateCamera(startCF, endCF, CAMERA_DURATION)
				
				-- Destroy the fade GUI after camera movement done
				fadeGui:Destroy()
				
				isFirstLoop = false
				if stopped then break end
			else
				-- Normal camera movement
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = startCF
				camera.Focus = startCF * CFrame.new(0, 0, -10)
				local stopped = animateCamera(startCF, endCF, CAMERA_DURATION)
				if stopped then break end
			end
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

-- Wait for the cinematic to finish before starting menu flythrough
print("MenuCameraFlythrough: Waiting for cinematic to complete...")
task.wait(CINEMATIC_END_TIME)

-- Start the menu flythrough
startMenuFlythrough()
