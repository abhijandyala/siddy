-- ChairShake.client.luau
-- DISABLED: No intro chair shake — game starts on main menu.

print("ChairShake: Disabled — game starts on main menu")
do return end

local RunService = game:GetService("RunService")

-- Configuration
local DELAY_BEFORE_SHAKE = 1.0   -- Wait before shaking starts (when MC lands)
local SHAKE_DURATION = 0.6       -- Total shake time
local SHAKE_INTENSITY = 0.35     -- Max movement in studs (more intense)
local SHAKE_ROTATION = 4.0       -- Max rotation in degrees (more tilting)
local SHAKE_FREQUENCY = 30       -- Oscillations per second (faster shake)

-- Find the ClassroomChairDesk model in workspace
local function findChairDesk()
	-- Direct search in workspace (based on your hierarchy)
	local chairDesk = workspace:FindFirstChild("ClassroomChairDesk")
	if chairDesk then return chairDesk end
	
	-- Search in Environments if it exists
	local environments = workspace:FindFirstChild("Environments")
	if environments then
		for _, child in pairs(environments:GetDescendants()) do
			if child.Name == "ClassroomChairDesk" and child:IsA("Model") then
				return child
			end
		end
	end
	
	return nil
end

-- Smooth shake using PivotTo (moves entire model together)
local function shakeModel(model)
	if not model or not model:IsA("Model") then
		warn("ChairShake: Invalid model!")
		return
	end
	
	-- Store original pivot position
	local originalPivot = model:GetPivot()
	
	print("ChairShake: Starting smooth shake animation...")
	
	local startTime = tick()
	local connection
	
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		
		if elapsed >= SHAKE_DURATION then
			-- Shake complete - return to original position
			model:PivotTo(originalPivot)
			connection:Disconnect()
			print("ChairShake: Shake complete!")
			return
		end
		
		-- Calculate shake progress (0 to 1)
		local progress = elapsed / SHAKE_DURATION
		
		-- Diminishing intensity (starts strong, fades out)
		local fadeMultiplier = 1 - (progress * progress) -- Quadratic fade
		
		-- Sine wave oscillation for smooth back-and-forth
		local oscillation = math.sin(elapsed * SHAKE_FREQUENCY)
		
		-- Calculate offsets
		local offsetX = SHAKE_INTENSITY * oscillation * fadeMultiplier
		local offsetZ = SHAKE_INTENSITY * 0.3 * math.cos(elapsed * SHAKE_FREQUENCY * 1.3) * fadeMultiplier
		
		-- Rotation shake (subtle tilt)
		local rotX = math.rad(SHAKE_ROTATION * 0.3 * oscillation * fadeMultiplier)
		local rotZ = math.rad(SHAKE_ROTATION * oscillation * fadeMultiplier)
		
		-- Apply shake offset to original position
		local shakeCFrame = originalPivot 
			* CFrame.new(offsetX, 0, offsetZ) 
			* CFrame.Angles(rotX, 0, rotZ)
		
		model:PivotTo(shakeCFrame)
	end)
	
	-- Wait for shake to complete
	task.wait(SHAKE_DURATION + 0.05)
end

-- Main execution
local function runShakeSequence()
	print("ChairShake: Script loaded. Waiting " .. DELAY_BEFORE_SHAKE .. "s before shake...")
	task.wait(DELAY_BEFORE_SHAKE)
	
	local chairDesk = findChairDesk()
	if chairDesk then
		print("ChairShake: Found '" .. chairDesk.Name .. "' - shaking now!")
		shakeModel(chairDesk)
	else
		warn("ChairShake: Could not find 'ClassroomChairDesk' in workspace!")
		warn("ChairShake: Make sure the model exists and is named exactly 'ClassroomChairDesk'")
	end
end

-- Run the shake sequence
runShakeSequence()
