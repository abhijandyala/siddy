-- MCAnimationController.server.luau
-- Animation starts INSTANTLY at game start
-- MC becomes visible when animation is at the right point
-- Fall and freeze are timed to match animation ending

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- DISABLED: No intro MC wake-up animation — game starts on the main menu.
print("=== MCAnimationController DISABLED — game starts on main menu ===")
do return end

print("=== MCAnimationController START ===")

-- Track when script starts (game start)
local GAME_START_TIME = tick()

-- CONFIGURATION
local FALLING_ANIMATION_ID = "rbxassetid://87696447889114"  -- NewFallingAnimationLonger (1.0s)
local SLEEPING_ANIMATION_ID = "rbxassetid://128410304289406"  -- Sleeping_AnimationSleepy
local FALL_TIME = 0.4  -- How long the fall takes
local CAMERA2_START_TIME = 0.8  -- Camera 2 starts 0.2s earlier

-- SYNC CHECK: if Studio doesn't print these exact IDs, Rojo did NOT sync this file.
print(">>> SYNC CHECK v2 — Falling ID: " .. FALLING_ANIMATION_ID)
print(">>> SYNC CHECK v2 — Sleeping ID: " .. SLEEPING_ANIMATION_ID)

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

-- ============================================
-- PROCEDURAL SLEEPING POSE (no uploaded animation needed)
-- Fallback used when the sleeping animation asset is missing/invalid.
-- Slumps the MC forward as if asleep at the desk by rotating joints directly.
-- All angles are in degrees and TUNABLE — tweak these if the pose looks off.
-- ============================================
local POSE_TORSO_LEAN  = 50   -- how far the upper body slumps forward onto the desk
local POSE_HEAD_TILT   = 30   -- how far the head droops down
local POSE_ARM_FORWARD = 70   -- how far the arms reach forward/down onto the desk (set 0 to disable)

local function findJoint(name)
	for _, d in pairs(mc:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == name then
			return d
		end
	end
	return nil
end

local function applySleepingPose()
	-- Stop anything that would fight our manual pose
	local animateScript = mc:FindFirstChild("Animate")
	if animateScript then
		animateScript.Disabled = true
	end
	for _, t in pairs(animator:GetPlayingAnimationTracks()) do
		t:Stop(0)
	end

	local isR15 = mc:FindFirstChild("UpperTorso") ~= nil
	local poseTargets = {}

	local function pose(name, angles)
		local joint = findJoint(name)
		if joint then
			poseTargets[joint] = joint.C0 * angles
		end
	end

	if isR15 then
		pose("Waist", CFrame.Angles(math.rad(POSE_TORSO_LEAN), 0, 0))
		pose("Neck", CFrame.Angles(math.rad(POSE_HEAD_TILT), 0, 0))
		pose("LeftShoulder", CFrame.Angles(math.rad(POSE_ARM_FORWARD), 0, 0))
		pose("RightShoulder", CFrame.Angles(math.rad(POSE_ARM_FORWARD), 0, 0))
	else
		pose("RootJoint", CFrame.Angles(math.rad(POSE_TORSO_LEAN), 0, 0))
		pose("Neck", CFrame.Angles(math.rad(POSE_HEAD_TILT), 0, 0))
		pose("Left Shoulder", CFrame.Angles(math.rad(POSE_ARM_FORWARD), 0, 0))
		pose("Right Shoulder", CFrame.Angles(math.rad(POSE_ARM_FORWARD), 0, 0))
	end

	-- Apply and HOLD the pose (re-assert every frame so nothing overrides it)
	RunService.Heartbeat:Connect(function()
		for joint, targetC0 in pairs(poseTargets) do
			joint.C0 = targetC0
		end
	end)

	print("  Procedural sleeping pose applied (" .. (isR15 and "R15" or "R6") .. ") — tune POSE_* constants if it looks off")
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

-- Wait for BOTH animations to load in parallel, with a short timeout.
-- A short timeout matters: if an animation can't load (e.g. not owned by this
-- account), we must NOT stall here — otherwise the MC appears after the intro
-- cinematic has already ended. Successful loads exit this loop early.
local LOAD_TIMEOUT = 2.0
local loadWaited = 0
while (track.Length == 0 or sleepingTrack.Length == 0) and loadWaited < LOAD_TIMEOUT do
	task.wait(0.1)
	loadWaited = loadWaited + 0.1
end

local fallingLoaded = track.Length > 0
local sleepingLoaded = sleepingTrack.Length > 0

if fallingLoaded then
	print("  Falling animation loaded! Length: " .. track.Length .. "s")
else
	warn("WARNING: Falling animation (" .. FALLING_ANIMATION_ID .. ") didn't load.")
	warn("  >>> MC will still appear and fall, just without the falling pose.")
	warn("  >>> This usually means the animation isn't owned by this game's account/group.")
	warn("  >>> Re-upload it under your account and update FALLING_ANIMATION_ID.")
end

if sleepingLoaded then
	print("  Sleeping animation loaded! Length: " .. sleepingTrack.Length .. "s")
else
	warn("WARNING: Sleeping animation (" .. SLEEPING_ANIMATION_ID .. ") didn't load — MC will sit without the sleeping pose.")
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

-- Fall ends when animation ends (fallback to 1.0s if the animation didn't load)
local FALL_END_TIME = fallingLoaded and track.Length or 1.0
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
if fallingLoaded then
	track:Play()
	print("  Animation PLAYING from time 0!")
end

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
local sleepingStarted = false

if fallingLoaded then
	local frozenPosition = track.TimePosition  -- Save the position we froze at
	track:AdjustSpeed(0)
	print("  >>> FROZEN IMMEDIATELY at TimePosition: " .. string.format("%.3f", frozenPosition) .. " / " .. track.Length)

	-- Keep falling animation frozen at current position until sleeping animation starts
	task.spawn(function()
		while not sleepingStarted do
			task.wait(0.05)
			track:AdjustSpeed(0)
			track.TimePosition = frozenPosition  -- Keep at same position
		end
	end)
end

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
if fallingLoaded then
	track:Stop(0)  -- Instant stop
end

-- Configure and play sleeping animation IMMEDIATELY (only if it loaded)
if sleepingLoaded then
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
else
	-- No valid sleeping animation — pose him asleep in code instead.
	print("Step 9b: No sleeping animation — applying procedural sleeping pose.")
	applySleepingPose()
end

print("=== MCAnimationController COMPLETE ===")
