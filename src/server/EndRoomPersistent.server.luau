-- EndRoomPersistent.server.luau
-- The aptitude-reveal "EndRoom" sits far from every gameplay area. With
-- StreamingEnabled, its parts (CamPos, RevealSpot, RevealPlatform, pedestal toppers)
-- stream OUT on the client because the player never travels there.
--
-- Marking the EndRoom model AND every descendant Model as Persistent keeps the full
-- room — including Stage Light children and their PointLight/SpotLight descendants —
-- immediately present on every client with no proximity-based delay.
-- This is a no-op if the place does not use streaming.

local ATTEMPT_TIMEOUT = 30

local function setPersistent(model)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
end

local function makeAllPersistent(room)
	if not room then return false end

	if not room:IsA("Model") then
		warn(
			"[EndRoomPersistent] 'EndRoom' is a "
				.. room.ClassName
				.. ", not a Model — cannot mark it Persistent. "
				.. "Right-click it in Studio and Group into a Model."
		)
		return false
	end

	-- Mark the root EndRoom model.
	setPersistent(room)
	print("[EndRoomPersistent] EndRoom marked Persistent.")

	-- Mark every descendant Model (Pedestal groups, Stage Light models, etc.)
	-- so they stream in immediately rather than waiting for player proximity.
	local childCount = 0
	for _, descendant in ipairs(room:GetDescendants()) do
		if descendant:IsA("Model") then
			setPersistent(descendant)
			childCount += 1
		end
	end

	print(string.format(
		"[EndRoomPersistent] Marked %d descendant model(s) inside EndRoom as Persistent.",
		childCount
	))
	return true
end

-- Try immediately, then watch in case EndRoom is added later.
if not makeAllPersistent(workspace:FindFirstChild("EndRoom")) then
	task.spawn(function()
		local room = workspace:WaitForChild("EndRoom", ATTEMPT_TIMEOUT)
		if room then
			makeAllPersistent(room)
		else
			warn("[EndRoomPersistent] No 'EndRoom' model found in Workspace within "
				.. ATTEMPT_TIMEOUT .. "s.")
		end
	end)
end
