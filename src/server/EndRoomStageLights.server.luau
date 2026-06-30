-- EndRoomStageLights.server.luau
-- The server has all workspace parts immediately (no streaming on server).
-- We enable, boost, and color every light + Neon part inside EndRoom.Pedestals
-- here so those property values replicate to every client the moment they join.
-- No client-side streaming wait needed.

local CAREER_COLORS = {
	aviation = Color3.fromRGB(105, 195, 255),
	chef     = Color3.fromRGB(255, 215, 100),
	nurse    = Color3.fromRGB(140, 255, 145),
	cyber    = Color3.fromRGB(235, 145, 255),
}

local function careerColor(instance)
	local cursor = instance
	while cursor do
		local low = string.lower(cursor.Name)
		for career, col in pairs(CAREER_COLORS) do
			if string.find(low, career) then return col end
		end
		cursor = cursor.Parent
	end
	return Color3.fromRGB(210, 230, 255)
end

local function processEndRoom(endRoom)
	local lightsEnabled = 0
	local beamsEnabled  = 0

	-- Scan the WHOLE EndRoom (pedestals, wall lights, beams, particles).
	for _, d in ipairs(endRoom:GetDescendants()) do
		if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			d.Enabled    = true
			d.Color      = careerColor(d)
			d.Brightness = math.max(d.Brightness, 6)
			if d:IsA("PointLight") then
				d.Range = math.max(d.Range, 45)
			elseif d:IsA("SpotLight") then
				d.Range = math.max(d.Range, 45)
				d.Angle = math.max(d.Angle, 75)
			end
			lightsEnabled += 1
		elseif d:IsA("Beam") or d:IsA("ParticleEmitter") then
			d.Enabled = true
			beamsEnabled += 1
		end
	end

	print(string.format(
		"[EndRoomStageLights] Done — %d light(s) enabled, %d beam/particle(s) enabled.",
		lightsEnabled, beamsEnabled
	))
end

-- Try immediately (server always has the room).
local endRoom = workspace:FindFirstChild("EndRoom")
if endRoom then
	processEndRoom(endRoom)
else
	-- Fallback: wait in case the model is added after server start.
	task.spawn(function()
		local room = workspace:WaitForChild("EndRoom", 30)
		if room then
			processEndRoom(room)
		else
			warn("[EndRoomStageLights] EndRoom not found within 30 s.")
		end
	end)
end
