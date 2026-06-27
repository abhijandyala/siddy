--[[
	SoundController.luau
	Module: ReplicatedStorage/NurseWorld/SoundController
	
	Manages all audio cues for the Nursing world.
	- Correct/wrong answer sounds
	- Ambient hospital sounds
	- UI interaction sounds
	- Emergency alarm for Code Blue scenario
	- Heart monitor beeping
	
	Setup Required:
		- Folder: ReplicatedStorage/NurseWorld/Sounds
		- Contains Sound instances with the IDs below
		  (or replace IDs with your own assets)
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundController = {}

-- Sound configuration
-- Replace these asset IDs with your own sounds or use Roblox library sounds
local SoundConfig = {
	-- UI Sounds
	correct = {
		id = "rbxassetid://6895079853",  -- positive chime
		volume = 0.5,
		playbackSpeed = 1.0,
	},
	wrong = {
		id = "rbxassetid://6895079981",  -- error buzz
		volume = 0.5,
		playbackSpeed = 1.0,
	},
	buttonClick = {
		id = "rbxassetid://6895079648",  -- soft click
		volume = 0.3,
		playbackSpeed = 1.2,
	},
	transition = {
		id = "rbxassetid://6895079727",  -- whoosh
		volume = 0.4,
		playbackSpeed = 1.0,
	},
	scenarioStart = {
		id = "rbxassetid://6895079790",  -- notification tone
		volume = 0.5,
		playbackSpeed = 1.0,
	},

	-- Ambient Sounds
	hospitalAmbient = {
		id = "rbxassetid://1838115390",  -- ambient hum
		volume = 0.15,
		playbackSpeed = 1.0,
		looped = true,
	},
	heartMonitor = {
		id = "rbxassetid://145362835",   -- beeping
		volume = 0.2,
		playbackSpeed = 1.0,
		looped = true,
	},

	-- Emergency Sounds
	codeBlueAlarm = {
		id = "rbxassetid://282124379",   -- alarm
		volume = 0.6,
		playbackSpeed = 1.0,
		looped = true,
	},
	flatline = {
		id = "rbxassetid://4841673576",  -- flatline tone
		volume = 0.4,
		playbackSpeed = 1.0,
		looped = true,
	},

	-- Results
	resultsGood = {
		id = "rbxassetid://5765933065",  -- success fanfare
		volume = 0.5,
		playbackSpeed = 1.0,
	},
	resultsBad = {
		id = "rbxassetid://5765933300",  -- somber tone
		volume = 0.4,
		playbackSpeed = 1.0,
	},
}

-- Internal state
local _sounds = {} -- { [name] = Sound instance }
local _soundGroup = nil

-- Initialize sound system
function SoundController.Init()
	-- Create a SoundGroup for volume control
	_soundGroup = Instance.new("SoundGroup")
	_soundGroup.Name = "NurseWorldSounds"
	_soundGroup.Volume = 1.0
	_soundGroup.Parent = SoundService

	-- Pre-create all Sound instances
	for name, config in SoundConfig do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = config.id
		sound.Volume = config.volume or 0.5
		sound.PlaybackSpeed = config.playbackSpeed or 1.0
		sound.Looped = config.looped or false
		sound.SoundGroup = _soundGroup
		sound.Parent = SoundService

		_sounds[name] = sound
	end

	print("[SoundController] Initialized " .. tostring(#_sounds) .. " sounds.")
end

-- Play a sound by name
function SoundController.Play(name: string)
	local sound = _sounds[name]
	if not sound then
		warn("[SoundController] Sound not found: " .. name)
		return
	end

	-- For non-looped sounds, stop and replay
	if not sound.Looped then
		sound:Stop()
	end

	sound:Play()
end

-- Stop a sound by name
function SoundController.Stop(name: string, fadeOut: boolean?)
	local sound = _sounds[name]
	if not sound then return end

	if fadeOut then
		-- Fade out over 0.5 seconds
		local originalVolume = sound.Volume
		local tween = TweenService:Create(sound, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {
			Volume = 0
		})
		tween:Play()
		tween.Completed:Connect(function()
			sound:Stop()
			sound.Volume = originalVolume
		end)
	else
		sound:Stop()
	end
end

-- Stop all sounds
function SoundController.StopAll(fadeOut: boolean?)
	for name, _ in _sounds do
		SoundController.Stop(name, fadeOut)
	end
end

-- Play correct answer sound
function SoundController.PlayCorrect()
	SoundController.Play("correct")
end

-- Play wrong answer sound
function SoundController.PlayWrong()
	SoundController.Play("wrong")
end

-- Play button click
function SoundController.PlayClick()
	SoundController.Play("buttonClick")
end

-- Start hospital ambient
function SoundController.StartAmbient()
	SoundController.Play("hospitalAmbient")
	SoundController.Play("heartMonitor")
end

-- Stop hospital ambient
function SoundController.StopAmbient()
	SoundController.Stop("hospitalAmbient", true)
	SoundController.Stop("heartMonitor", true)
end

-- Start Code Blue emergency sounds
function SoundController.StartEmergency()
	SoundController.Stop("heartMonitor")
	SoundController.Play("codeBlueAlarm")
	SoundController.Play("flatline")
end

-- Stop emergency sounds
function SoundController.StopEmergency()
	SoundController.Stop("codeBlueAlarm", true)
	SoundController.Stop("flatline", true)
	SoundController.Play("heartMonitor") -- restore normal beeping
end

-- Play results sound based on score
function SoundController.PlayResults(score: number)
	if score >= 67 then
		SoundController.Play("resultsGood")
	else
		SoundController.Play("resultsBad")
	end
end

-- Set master volume (0-1)
function SoundController.SetVolume(volume: number)
	if _soundGroup then
		_soundGroup.Volume = math.clamp(volume, 0, 1)
	end
end

-- Cleanup
function SoundController.Cleanup()
	SoundController.StopAll()
	if _soundGroup then
		_soundGroup:Destroy()
	end
	for _, sound in _sounds do
		sound:Destroy()
	end
	_sounds = {}
end

return SoundController
c