-- CinematicCamera.client.luau
-- DISABLED: Game starts directly on the main menu — no intro/wake-up cinematic.

print("CinematicCamera: Disabled — game starts on main menu")
do return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

-- CONFIGURATION
local FADE_IN_DURATION = 1.0      -- 1 second fade in through sleeping animation
local CAMERA1_DURATION = 0.8      -- First camera (intro/side view)
local CAMERA2_DURATION = 5.0      -- Second camera (desk closeup)
local FADE_OUT_DURATION = 2.0     -- 2 second fade to black before menu (dream transition)
local SHAKE_START_TIME = 0.5      -- When shake starts (during fall)
local SHAKE_MAIN_DURATION = 0.6   -- Main shake duration (same as chair)
local SHAKE_FADE_DURATION = 0.5   -- Extra fade-out time
local SHAKE_INTENSITY = 0.35      -- Match chair shake intensity
local SHAKE_ROTATION = 4.0        -- Match chair shake rotation
local SHAKE_FREQUENCY = 30        -- Match chair shake frequency

print("CinematicCamera: Script started!")

-- ============================================
-- CREATE SINGLE FADE SCREEN (used for both fade-in and fade-out)
-- ============================================

local fadeGui = Instance.new("ScreenGui")
fadeGui.Name = "CinematicFade"
fadeGui.IgnoreGuiInset = true
fadeGui.DisplayOrder = 999  -- On top of everything
fadeGui.Parent = playerGui

local fadeFrame = Instance.new("Frame")
fadeFrame.Name = "FadeFrame"
fadeFrame.Size = UDim2.new(1, 0, 1, 0)
fadeFrame.Position = UDim2.new(0, 0, 0, 0)
fadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)  -- Black
fadeFrame.BackgroundTransparency = 0  -- Fully opaque (black screen)
fadeFrame.BorderSizePixel = 0
fadeFrame.Parent = fadeGui

print("CinematicCamera: Black screen created")

-- Wait for character to load
print("CinematicCamera: Waiting for character to load...")
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
print("CinematicCamera: Character loaded!")

task.wait(0.1)

-- Find camera markers using direct path (efficient) with streaming wait
local introMarker = nil
local closeupMarker = nil

-- Try direct path first (most efficient)
local function tryDirectPath()
	local envs = workspace:FindFirstChild("Environments")
	if envs then
		local classroom = envs:FindFirstChild("Classroom")
		if classroom then
			local classroomModel = classroom:FindFirstChild("Classroom")
			if classroomModel then
				introMarker = classroomModel:FindFirstChild("CameraMarker_Intro")
				closeupMarker = classroomModel:FindFirstChild("CameraMarker_DeskCloseup")
			end
		end
	end
	return introMarker ~= nil
end

-- Wait for markers with timeout (using efficient path lookup)
local maxWait = 10
local waited = 0
while not tryDirectPath() and waited < maxWait do
	task.wait(0.5)
	waited = waited + 0.5
	print("CinematicCamera: Waiting for markers to load... (" .. waited .. "s)")
end

if not introMarker then
	warn("CinematicCamera: Could not find CameraMarker_Intro after " .. maxWait .. " seconds!")
	-- Clean up fade GUI completely and let the game continue
	fadeGui:Destroy()
	return
end

print("CinematicCamera: Found CameraMarker_Intro at " .. introMarker:GetFullName())

local baseCFrame = introMarker.CFrame

-- Function to calculate shake offset
local function getShakeOffset(elapsed, intensity, rotation)
	local oscillation = math.sin(elapsed * SHAKE_FREQUENCY)
	local oscillation2 = math.cos(elapsed * SHAKE_FREQUENCY * 1.3)
	
	local offsetX = intensity * oscillation
	local offsetY = intensity * 0.5 * oscillation2
	local offsetZ = intensity * 0.3 * oscillation
	
	local rotX = math.rad(rotation * 0.3 * oscillation)
	local rotZ = math.rad(rotation * oscillation2 * 0.5)
	
	return CFrame.new(offsetX, offsetY, offsetZ) * CFrame.Angles(rotX, 0, rotZ)
end

-- ============================================
-- CINEMATIC SEQUENCE WITH SHAKE
-- ============================================

print("CinematicCamera: >>> STARTING CINEMATIC <<<")

-- Start the fade-in immediately (1 second)
print("CinematicCamera: Starting fade-in over " .. FADE_IN_DURATION .. "s...")

local fadeInTween = TweenService:Create(
	fadeFrame,
	TweenInfo.new(FADE_IN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{BackgroundTransparency = 1}  -- Fade to transparent
)
fadeInTween:Play()

-- Wait for fade-in to complete (don't destroy, keep for later fade-out)
fadeInTween.Completed:Connect(function()
	print("CinematicCamera: Fade-in COMPLETE!")
end)

local startTime = tick()

-- ============================================
-- CAMERA 1: Intro/Side View (with shake)
-- ============================================
print("CinematicCamera: Camera 1 - Intro view for " .. CAMERA1_DURATION .. "s")

while tick() - startTime < CAMERA1_DURATION do
	local elapsed = tick() - startTime
	
	-- Force camera to Scriptable
	camera.CameraType = Enum.CameraType.Scriptable
	
	-- Calculate camera position (base + possible shake)
	local finalCFrame = baseCFrame
	
	-- Check if we should be shaking
	if elapsed >= SHAKE_START_TIME then
		local shakeElapsed = elapsed - SHAKE_START_TIME
		local totalShakeDuration = SHAKE_MAIN_DURATION + SHAKE_FADE_DURATION
		
		if shakeElapsed < totalShakeDuration then
			-- Calculate intensity multiplier
			local intensityMult = 1.0
			
			if shakeElapsed < SHAKE_MAIN_DURATION then
				-- Main shake phase - full intensity with slight fade
				local progress = shakeElapsed / SHAKE_MAIN_DURATION
				intensityMult = 1.0 - (progress * 0.3)  -- Fade to 70%
			else
				-- Fade out phase - go from 70% to 0%
				local fadeElapsed = shakeElapsed - SHAKE_MAIN_DURATION
				local fadeProgress = fadeElapsed / SHAKE_FADE_DURATION
				intensityMult = 0.7 * (1.0 - fadeProgress)  -- 70% down to 0%
			end
			
			-- Apply shake
			local currentIntensity = SHAKE_INTENSITY * intensityMult
			local currentRotation = SHAKE_ROTATION * intensityMult
			
			local shakeOffset = getShakeOffset(shakeElapsed, currentIntensity, currentRotation)
			finalCFrame = baseCFrame * shakeOffset
		end
	end
	
	-- Set camera
	camera.CFrame = finalCFrame
	camera.Focus = finalCFrame * CFrame.new(0, 0, -10)
	
	RunService.RenderStepped:Wait()
end

local camera1EndTime = tick() - startTime
print("CinematicCamera: Camera 1 complete! (ended at " .. string.format("%.2f", camera1EndTime) .. "s)")

-- ============================================
-- CAMERA 2: Desk Closeup View (with movement + continuous shake)
-- ============================================
print("CinematicCamera: >>> SWITCHING TO CAMERA 2 NOW <<< (at " .. string.format("%.2f", tick() - startTime) .. "s)")
print("CinematicCamera: Camera 2 - Desk closeup with movement for " .. CAMERA2_DURATION .. "s")

-- Camera 2 movement path (start and end positions/orientations)
local CAM2_START_POS = Vector3.new(-9248.412, 5527.922, 3637.672)
local CAM2_START_ROT = Vector3.new(0, 0, 0)  -- Orientation in degrees

local CAM2_END_POS = Vector3.new(-9248.412, 5527.778, 3636.067)
local CAM2_END_ROT = Vector3.new(-17.872, 0, 0)  -- Orientation in degrees

-- Create CFrames from positions and orientations
local cam2StartCFrame = CFrame.new(CAM2_START_POS) * CFrame.Angles(
	math.rad(CAM2_START_ROT.X),
	math.rad(CAM2_START_ROT.Y),
	math.rad(CAM2_START_ROT.Z)
)

local cam2EndCFrame = CFrame.new(CAM2_END_POS) * CFrame.Angles(
	math.rad(CAM2_END_ROT.X),
	math.rad(CAM2_END_ROT.Y),
	math.rad(CAM2_END_ROT.Z)
)

-- Camera 2 with continuous movement + fade at the end
local camera2StartTime = tick()
local fadeOutStarted = false

print("CinematicCamera: Camera 2 for " .. CAMERA2_DURATION .. "s with " .. FADE_OUT_DURATION .. "s fade at end")

while tick() - camera2StartTime < CAMERA2_DURATION do
	local elapsed = tick() - startTime
	local cam2Elapsed = tick() - camera2StartTime
	
	-- Camera keeps moving the entire time
	local moveProgress = cam2Elapsed / CAMERA2_DURATION
	local smoothProgress = moveProgress * moveProgress * moveProgress * moveProgress
	local movingCFrame = cam2StartCFrame:Lerp(cam2EndCFrame, smoothProgress)
	
	camera.CameraType = Enum.CameraType.Scriptable
	local finalCFrame = movingCFrame
	
	-- Apply shake if needed
	if elapsed >= SHAKE_START_TIME then
		local shakeElapsed = elapsed - SHAKE_START_TIME
		local totalShakeDuration = SHAKE_MAIN_DURATION + SHAKE_FADE_DURATION
		
		if shakeElapsed < totalShakeDuration then
			local intensityMult = 1.0
			if shakeElapsed < SHAKE_MAIN_DURATION then
				local progress = shakeElapsed / SHAKE_MAIN_DURATION
				intensityMult = 1.0 - (progress * 0.3)
			else
				local fadeElapsed = shakeElapsed - SHAKE_MAIN_DURATION
				local fadeProgress = fadeElapsed / SHAKE_FADE_DURATION
				intensityMult = 0.7 * (1.0 - fadeProgress)
			end
			
			local currentIntensity = SHAKE_INTENSITY * intensityMult
			local currentRotation = SHAKE_ROTATION * intensityMult
			local shakeOffset = getShakeOffset(shakeElapsed, currentIntensity, currentRotation)
			finalCFrame = movingCFrame * shakeOffset
		end
	end
	
	camera.CFrame = finalCFrame
	camera.Focus = finalCFrame * CFrame.new(0, 0, -10)
	
	-- Start fade when we have FADE_OUT_DURATION seconds left (camera keeps moving!)
	local timeRemaining = CAMERA2_DURATION - cam2Elapsed
	if timeRemaining <= FADE_OUT_DURATION and not fadeOutStarted then
		fadeOutStarted = true
		print("CinematicCamera: Starting 2 second FADE OUT (camera keeps moving)...")
		
		local fadeOutTween = TweenService:Create(
			fadeFrame,
			TweenInfo.new(FADE_OUT_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
			{BackgroundTransparency = 0}
		)
		fadeOutTween:Play()
	end
	
	RunService.RenderStepped:Wait()
end

print("CinematicCamera: Camera 2 complete!")

-- Ensure screen is fully black
fadeFrame.BackgroundTransparency = 0
print("CinematicCamera: Screen is black, ready for menu handoff")

-- Rename the GUI so MenuCameraFlythrough can find it
fadeGui.Name = "CinematicFadeOut"
fadeFrame.Name = "FadeOutFrame"

print("CinematicCamera: >>> CINEMATIC INTRO COMPLETE - MENU STARTING <<<")
