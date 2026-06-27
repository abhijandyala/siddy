-- MCAnimationController.server.luau
-- Animation starts INSTANTLY at game start
-- MC becomes visible when animation is at the right point
-- Fall and freeze are timed to match animation ending

local TweenService = game:GetService("TweenService")

print("=== MCAnimationController START ===")

-- Track when script starts (game start)
local GAME_START_TIME = tick()

-- CONFIGURATION
local FALLING_ANIMATION_ID = "rbxassetid://107489504282824"  -- NewFallingAnimationLonger (1.0s)
local SLEEPING_ANIMATION_ID = "rbxassetid://83042459456148"  -- Sleeping_AnimationSleepy
local FALL_TIME = 0.4  -- How long the fall takes
local CAMERA2_START_TIME = 0.8  -- Camera 2 starts 0.2s earlier

-- STEP 1: Find MC
print("Step 1: Finding MC...")

local students = workspace:WaitForChild("Students", 10)
if not students then
	warn("FAILED: No Students folder")
	return
end

local mc = students:WaitForChild("MC", 10)
if not mc then
	warn("FAILED: No MC in Students")
	return
end
print("  Found MC")

-- STEP 2: Find required parts
local hrp = mc:FindFirstChild("HumanoidRootPart")
local torso = mc:FindFirstChild("Torso")
local humanoid = mc:FindFirstChild("Humanoid")

if not humanoid then
	warn("FAILED: No Humanoid")
	return
end

local rootPart = hrp or torso
if not rootPart then
	warn("FAILED: No root part to move")
	return
end

-- STEP 3: HIDE MC immediately
print("Step 2: Hiding MC...")
for _, child in pairs(mc:GetDescendants()) do
	if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
		child.Transparency = 1
	elseif child:IsA("Decal") then
		child.Transparency = 1
	end
end
print("  MC is HIDDEN")

-- STEP 4: Setup Animator
local animator = humanoid:FindFirstChildOfClass("Animator")
if not animator then
	animator = Instance.new("Animator")
	animator.Parent = humanoid
end

-- STEP 5: Load animations
print("Step 3: Loading animations...")

-- Falling animation
local fallingAnim = Instance.new("Animation")
fallingAnim.AnimationId = FALLING_ANIMATION_ID
local track = animator:LoadAnimation(fallingAnim)

-- Sleeping animation
local sleepingAnim = Instance.new("Animation")
sleepingAnim.AnimationId = SLEEPING_ANIMATION_ID
local sleepingTrack = animator:LoadAnimation(sleepingAnim)

-- Wait for falling animation to load
local waited = 0
while track.Length == 0 and waited < 5 do
	task.wait(0.1)
	waited = waited + 0.1
end

if track.Length == 0 then
	warn("FAILED: Falling animation didn't load!")
	return
end

print("  Falling animation loaded! Length: " .. track.Length .. "s")

-- Wait for sleeping animation to load
waited = 0
while sleepingTrack.Length == 0 and waited < 5 do
	task.wait(0.1)
	waited = waited + 0.1
end

if sleepingTrack.Length == 0 then
	warn("WARNING: Sleeping animation didn't load, will skip")
else
	print("  Sleeping animation loaded! Length: " .. sleepingTrack.Length .. "s")
end

-- STEP 6: Setup fall positions
local START_Y = 5534.752
local END_Y = 5526.944

local currentPos = rootPart.CFrame.Position
local endCFrame = rootPart.CFrame
local startCFrame = CFrame.new(currentPos.X, START_Y, currentPos.Z) * endCFrame.Rotation
local endCFrameFinal = CFrame.new(currentPos.X, END_Y, currentPos.Z) * endCFrame.Rotation

-- Move MC to start position
rootPart.CFrame = startCFrame
print("  MC at start position Y: " .. START_Y)

-- STEP 7: Configure animation
track.Looped = false
track.Priority = Enum.AnimationPriority.Action4

-- ============================================
-- CALCULATE TIMING - SIMPLIFIED
-- Fall should END exactly when animation ENDS
-- ============================================

-- Fall ends when animation ends
local FALL_END_TIME = track.Length  -- e.g., 1.0s
local FALL_START_TIME = FALL_END_TIME - FALL_TIME  -- e.g., 1.0 - 0.4 = 0.6s

print("  TIMING DEBUG:")
print("    Animation length: " .. track.Length .. "s")
print("    Fall duration: " .. FALL_TIME .. "s")
print("    Fall starts at: " .. FALL_START_TIME .. "s (animation time)")
print("    Fall ends at: " .. FALL_END_TIME .. "s (animation time)")
print("    >>> Fall should end EXACTLY when animation ends!")


-- ============================================
-- START ANIMATION IMMEDIATELY
-- ============================================
print("Step 4: Starting animation NOW (game start)...")
track:Play()
print("  Animation PLAYING from time 0!")

-- Wait until it's time for fall to start
-- MC becomes visible AND fall starts at the same moment
print("Step 5: Waiting " .. FALL_START_TIME .. "s until fall starts...")
task.wait(FALL_START_TIME)

-- Animation has been playing, now show MC (animation already in motion)
print("Step 6: Showing MC and starting fall!")

-- Show MC
for _, child in pairs(mc:GetDescendants()) do
	if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
		child.Transparency = 0
	elseif child:IsA("Decal") then
		child.Transparency = 0
	end
end
print("  MC is now VISIBLE (animation at TimePosition: " .. string.format("%.2f", track.TimePosition) .. ")")

-- Do the fall
local fallDistance = START_Y - END_Y
local fallSteps = 30
local stepTime = FALL_TIME / fallSteps

for i = 1, fallSteps do
	local progress = i / fallSteps
	local easedProgress = progress * progress
	local newY = START_Y - (fallDistance * easedProgress)
	local currentPos = rootPart.CFrame.Position
	
	rootPart.CFrame = CFrame.new(currentPos.X, newY, currentPos.Z) * endCFrame.Rotation
	
	task.wait(stepTime)
end

-- Final position
rootPart.CFrame = endCFrameFinal
print("  Fall complete!")

-- IMMEDIATELY freeze animation at current position when fall ends
-- Don't wait for animation to reach near-end - freeze NOW
local currentAnimPos = track.TimePosition
track:AdjustSpeed(0)
print("  >>> FROZEN IMMEDIATELY at TimePosition: " .. string.format("%.3f", currentAnimPos) .. " / " .. track.Length)

-- Use the actual game start time we tracked

-- Keep falling animation frozen at current position until sleeping animation starts
local sleepingStarted = false
local frozenPosition = track.TimePosition  -- Save the position we froze at

task.spawn(function()
	while not sleepingStarted do
		task.wait(0.05)
		track:AdjustSpeed(0)
		track.TimePosition = frozenPosition  -- Keep at same position
	end
end)

print("  Falling animation frozen, waiting for camera 2...")

-- ============================================
-- SLEEPING ANIMATION (starts EXACTLY when camera 2 begins)
-- Since camera CUTS, we can do instant switch - no fade needed!
-- ============================================

-- Wait until EXACTLY when camera 2 starts
local elapsedSinceStart = tick() - GAME_START_TIME
local waitForCamera2 = CAMERA2_START_TIME - elapsedSinceStart

if waitForCamera2 > 0 then
	print("  Waiting " .. string.format("%.2f", waitForCamera2) .. "s for camera 2...")
	task.wait(waitForCamera2)
end

print("Step 9: Camera 2 NOW - INSTANT switch to sleeping animation!")

-- Stop the freeze loop
sleepingStarted = true

-- INSTANT SWITCH: Stop falling, start sleeping at same moment
-- No fade - the camera cut hides the transition!
track:Stop(0)  -- Instant stop

-- Configure and play sleeping animation IMMEDIATELY
sleepingTrack.Looped = false
sleepingTrack.Priority = Enum.AnimationPriority.Action4
sleepingTrack:Play(0)  -- Instant start, no fade

print("  Sleeping animation PLAYING! (3.5s, plays once)")

-- Freeze on last frame after animation completes
task.spawn(function()
	-- Wait for animation to nearly finish
	local freezeTime = sleepingTrack.Length - 0.05
	
	-- Monitor and freeze before it ends
	while sleepingTrack.TimePosition < freezeTime do
		task.wait(0.05)
	end
	
	-- Freeze on last frame
	sleepingTrack:AdjustSpeed(0)
	sleepingTrack.TimePosition = sleepingTrack.Length - 0.01
	print("  Sleeping animation frozen on last frame!")
	
	-- Keep it frozen indefinitely
	while true do
		task.wait(0.1)
		sleepingTrack:AdjustSpeed(0)
		sleepingTrack.TimePosition = sleepingTrack.Length - 0.01
	end
end)

print("=== MCAnimationController COMPLETE ===")
