-- RemoveSpawnProtection.server.luau
-- Removes the ForceField (spawn protection) immediately when players spawn

local Players = game:GetService("Players")

local function onCharacterAdded(character)
	-- Remove any existing ForceField immediately
	local forceField = character:FindFirstChildOfClass("ForceField")
	if forceField then
		forceField:Destroy()
	end
	
	-- Also watch for ForceField being added (in case it spawns slightly delayed)
	character.ChildAdded:Connect(function(child)
		if child:IsA("ForceField") then
			child:Destroy()
		end
	end)
end

local function onPlayerAdded(player)
	-- Handle current character
	if player.Character then
		onCharacterAdded(player.Character)
	end
	
	-- Handle future respawns
	player.CharacterAdded:Connect(onCharacterAdded)
end

-- Connect for all current and future players
for _, player in pairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

print("RemoveSpawnProtection: Spawn protection disabled")
