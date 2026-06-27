--[[
	CameraController.luau
	Module: ReplicatedStorage/NurseWorld/CameraController
	
	Handles cinematic camera movements for the Nursing world.
	- Smooth transitions when approaching patient beds
	- Focus on patient during scenario briefing
	- Return to player camera after scenario
	- Intro cinematic pan across the hospital wing
	
	Usage (LocalScript):
		local CameraController = require(...)
		CameraController.FocusOnBed(bedPart, callback)
		CameraController.ReturnToPlayer()
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CameraController = {}

local camera = workspace.CurrentCamera
local player = Players.LocalPlayer

-- Configuration
local FOCUS_TWEEN_DURATION = 1.0
local RETURN_TWEEN_DURATION = 0.8
local FOCUS_OFFSET = Vector3.new(4, 3, 6) -- offset from bed when focusing
local FOCUS_FOV = 55 -- narrower FOV for cinematic feel
local DEFAULT_FOV = 70

-- State
local _originalCFrame = nil
local _originalCameraType = nil
local _isFocused = false

-- Focus camera on a specific part (patient bed)
function CameraController.FocusOnBed(targetPart: BasePart, callback: (() -> ())?)
	if _isFocused then return end
	_isFocused = true

	-- Save original camera state
	_originalCFrame = camera.CFrame
	_originalCameraType = camera.CameraType

	-- Calculate target camera position
	local targetPos = targetPart.Position + FOCUS_OFFSET
	local targetCFrame = CFrame.new(targetPos, targetPart.Position)

	-- Set camera to scriptable
	camera.CameraType = Enum.CameraType.Scriptable

	-- Tween camera position and FOV
	local tweenInfo = TweenInfo.new(FOCUS_TWEEN_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	local posTween = TweenService:Create(camera, tweenInfo, {
		CFrame = targetCFrame,
		FieldOfView = FOCUS_FOV,
	})

	posTween:Play()
	posTween.Completed:Connect(function()
		if callback then callback() end
	end)
end

-- Focus on a specific CFrame (for custom angles)
function CameraController.FocusOnCFrame(targetCFrame: CFrame, duration: number?, callback: (() -> ())?)
	if _isFocused then return end
	_isFocused = true

	_originalCFrame = camera.CFrame
	_originalCameraType = camera.CameraType

	camera.CameraType = Enum.CameraType.Scriptable

	local tweenInfo = TweenInfo.new(duration or FOCUS_TWEEN_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local tween = TweenService:Create(camera, tweenInfo, {
		CFrame = targetCFrame,
		FieldOfView = FOCUS_FOV,
	})

	tween:Play()
	tween.Completed:Connect(function()
		if callback then callback() end
	end)
end

-- Return camera to player control
function CameraController.ReturnToPlayer(callback: (() -> ())?)
	if not _isFocused then
		if callback then callback() end
		return
	end

	-- Tween back to current character position
	local character = player.Character
	if not character then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = DEFAULT_FOV
		_isFocused = false
		if callback then callback() end
		return
	end

	local head = character:FindFirstChild("Head")
	if not head then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = DEFAULT_FOV
		_isFocused = false
		if callback then callback() end
		return
	end

	local targetCFrame = CFrame.new(head.Position + Vector3.new(0, 2, 8), head.Position)

	local tweenInfo = TweenInfo.new(RETURN_TWEEN_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local tween = TweenService:Create(camera, tweenInfo, {
		CFrame = targetCFrame,
		FieldOfView = DEFAULT_FOV,
	})

	tween:Play()
	tween.Completed:Connect(function()
		camera.CameraType = Enum.CameraType.Custom
		_isFocused = false
		if callback then callback() end
	end)
end

-- Intro cinematic: pan across the hospital wing
function CameraController.PlayIntroCinematic(waypoints: { CFrame }, duration: number?, callback: (() -> ())?)
	if #waypoints < 2 then
		if callback then callback() end
		return
	end

	_originalCameraType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = waypoints[1]

	local totalDuration = duration or 4.0
	local segmentDuration = totalDuration / (#waypoints - 1)

	local currentWaypoint = 1

	local function tweenToNext()
		currentWaypoint += 1
		if currentWaypoint > #waypoints then
			-- Done with cinematic
			if callback then callback() end
			return
		end

		local tweenInfo = TweenInfo.new(segmentDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local tween = TweenService:Create(camera, tweenInfo, {
			CFrame = waypoints[currentWaypoint]
		})

		tween:Play()
		tween.Completed:Connect(tweenToNext)
	end

	tweenToNext()
end

-- Shake effect (for emergency scenario)
function CameraController.ShakeCamera(intensity: number?, duration: number?)
	local shakeIntensity = intensity or 0.3
	local shakeDuration = duration or 0.5
	local startTime = tick()

	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		if elapsed >= shakeDuration then
			connection:Disconnect()
			return
		end

		local decay = 1 - (elapsed / shakeDuration)
		local offsetX = (math.random() - 0.5) * 2 * shakeIntensity * decay
		local offsetY = (math.random() - 0.5) * 2 * shakeIntensity * decay

		camera.CFrame = camera.CFrame * CFrame.new(offsetX, offsetY, 0)
	end)
end

-- Check if camera is currently in cinematic mode
function CameraController.IsFocused(): boolean
	return _isFocused
end

return CameraController
