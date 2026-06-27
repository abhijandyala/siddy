-- AnchorMCCybersecurity.server.luau
-- Runs IMMEDIATELY at game start to anchor MC_cybersecurity_1
-- Prevents physics from shifting the character before PlaySequence runs

local TARGET_NAME = "MC_cybersecurity_1"

-- Find MC_cybersecurity_1 as fast as possible
local function findAndAnchor()
	-- Try direct path first (fastest)
	local environments = workspace:FindFirstChild("Environments")
	if environments then
		local cyber = environments:FindFirstChild("Cybersecurity")
		if cyber then
			local computerRoom = cyber:FindFirstChild("ComputerRoom")
			if computerRoom then
				local mc = computerRoom:FindFirstChild(TARGET_NAME)
				if mc then
					local hrp = mc:FindFirstChild("HumanoidRootPart")
					if hrp then
						-- Store original position
						local originalCFrame = hrp.CFrame
						print("[AnchorMC] Found " .. TARGET_NAME .. " at Y=" .. string.format("%.3f", originalCFrame.Position.Y))
						
						-- Anchor immediately
						hrp.Anchored = true
						
						-- Set Humanoid state to prevent physics interference
						local humanoid = mc:FindFirstChildOfClass("Humanoid")
						if humanoid then
							humanoid:ChangeState(Enum.HumanoidStateType.Physics)
						end
						
						-- Restore position (in case it shifted during this frame)
						task.defer(function()
							hrp.CFrame = originalCFrame
							print("[AnchorMC] " .. TARGET_NAME .. " anchored and position locked at Y=" .. string.format("%.3f", hrp.Position.Y))
						end)
						
						return true
					end
				end
			end
		end
	end
	
	-- Fallback: search all descendants
	for _, desc in pairs(workspace:GetDescendants()) do
		if desc.Name == TARGET_NAME and desc:IsA("Model") then
			local hrp = desc:FindFirstChild("HumanoidRootPart")
			if hrp then
				local originalCFrame = hrp.CFrame
				print("[AnchorMC] Found " .. TARGET_NAME .. " (fallback) at Y=" .. string.format("%.3f", originalCFrame.Position.Y))
				
				hrp.Anchored = true
				
				local humanoid = desc:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:ChangeState(Enum.HumanoidStateType.Physics)
				end
				
				task.defer(function()
					hrp.CFrame = originalCFrame
					print("[AnchorMC] " .. TARGET_NAME .. " anchored (fallback) at Y=" .. string.format("%.3f", hrp.Position.Y))
				end)
				
				return true
			end
		end
	end
	
	return false
end

-- Run immediately
if not findAndAnchor() then
	warn("[AnchorMC] " .. TARGET_NAME .. " not found!")
end
