-- EndRoomPersistent.server.luau
-- The aptitude-reveal "EndRoom" sits far from every gameplay area. With
-- StreamingEnabled, its parts (CamPos, RevealSpot, RevealPlatform, pedestal toppers)
-- stream OUT on the client because the player never travels there. That is why the
-- end-screen camera could not find CamPos and framed empty space above the room.
--
-- Marking the EndRoom model "Persistent" keeps it fully replicated to every client
-- for the entire session, so the client always finds its parts (including CamPos).
-- This is a no-op if the place does not use streaming.

local ATTEMPT_TIMEOUT = 30

local function makePersistent(inst)
	if not inst then
		return false
	end
	if not inst:IsA("Model") then
		warn(
			"[EndRoomPersistent] Found 'EndRoom' but it is a "
				.. inst.ClassName
				.. ", not a Model — cannot mark it Persistent. "
				.. "Right-click it in Studio and 'Group' the contents into a Model so CamPos always loads, "
				.. "or set the model's ModelStreamingMode to Persistent manually."
		)
		return false
	end

	local ok, err = pcall(function()
		inst.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	if ok then
		print("[EndRoomPersistent] EndRoom marked Persistent — it will always load on every client.")
	else
		warn("[EndRoomPersistent] Could not set ModelStreamingMode on EndRoom: " .. tostring(err))
	end
	return ok
end

-- Try immediately, then keep watching in case it is added/streamed later.
if not makePersistent(workspace:FindFirstChild("EndRoom")) then
	task.spawn(function()
		local room = workspace:WaitForChild("EndRoom", ATTEMPT_TIMEOUT)
		if room then
			makePersistent(room)
		else
			warn("[EndRoomPersistent] No 'EndRoom' model found in Workspace within " .. ATTEMPT_TIMEOUT .. "s.")
		end
	end)
end
