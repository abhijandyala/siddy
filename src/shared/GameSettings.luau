-- GameSettings.luau
-- Single shared settings table for the entire client session.
-- Because Roblox caches ModuleScript results per client Lua VM, every
-- LocalScript that requires this module gets the SAME table, so setting a
-- value here is immediately visible to all other scripts.

local SoundService = game:GetService("SoundService")

----------------------------------------------------------------------
-- TRANSLATIONS
----------------------------------------------------------------------
local T = {
	en = {
		play       = "PLAY",
		tutorial   = "TUTORIAL",
		settings   = "SETTINGS",
		back       = "BACK",
		howToPlay  = "HOW TO PLAY",
		-- Tutorial cards
		controls       = "CONTROLS",
		controlsBody   = "WASD to move, mouse to look, E to interact, and follow each career's on-screen prompts.",
		careers        = "CAREER PATHS",
		careersBody    = "Aviation, Culinary Arts, Healthcare, and Cybersecurity each include hands-on tasks.",
		goal           = "GOAL",
		goalBody       = "Finish every station and build the highest career readiness score you can.",
		-- Settings rows
		volume         = "MASTER VOLUME",
		music          = "MUSIC VOLUME",
		hardMode       = "HARD MODE",
		hardModeDesc   = "Hides your score during gameplay until the final results screen.",
		language       = "LANGUAGE",
		textSize       = "TEXT SIZE",
		graphics       = "GRAPHICS",
		-- Settings option labels
		on = "ON", off = "OFF",
		small = "S", medium = "M", large = "L",
		high = "HIGH", low = "LOW",
	},
	es = {
		play       = "JUGAR",
		tutorial   = "TUTORIAL",
		settings   = "AJUSTES",
		back       = "ATRÁS",
		howToPlay  = "CÓMO JUGAR",
		controls       = "CONTROLES",
		controlsBody   = "WASD para moverse, ratón para mirar, E para interactuar.",
		careers        = "CARRERAS",
		careersBody    = "Aviación, Culinaria, Salud y Ciberseguridad — cada una con tareas prácticas.",
		goal           = "OBJETIVO",
		goalBody       = "Completa cada estación y consigue la puntuación más alta posible.",
		volume         = "VOLUMEN PRINCIPAL",
		music          = "VOLUMEN MUSICAL",
		hardMode       = "MODO DIFÍCIL",
		hardModeDesc   = "Oculta tu puntuación durante el juego hasta la pantalla de resultados.",
		language       = "IDIOMA",
		textSize       = "TAMAÑO DE TEXTO",
		graphics       = "GRÁFICOS",
		on = "SÍ", off = "NO",
		small = "P", medium = "M", large = "G",
		high = "ALTA", low = "BAJA",
	},
}

----------------------------------------------------------------------
-- VOLUME LEVELS
----------------------------------------------------------------------
local VOLUME_STEPS       = { 0, 0.25, 0.5, 0.75, 1.0 }
local VOLUME_STEP_LABELS = { "0%", "25%", "50%", "75%", "100%" }

local MUSIC_STEPS        = { 0, 0.25, 0.5, 0.75, 1.0 }
local MUSIC_STEP_LABELS  = { "0%", "25%", "50%", "75%", "100%" }

----------------------------------------------------------------------
-- MODULE
----------------------------------------------------------------------
local GameSettings = {}

-- Defaults
GameSettings.masterVolumeIdx  = 4       -- 75%
GameSettings.musicVolumeIdx   = 3       -- 50%
GameSettings.hardMode         = false
GameSettings.language         = "en"
GameSettings.textScale        = 1.0     -- 1 = normal
GameSettings.graphics         = "high"

GameSettings._listeners = {}

----------------------------------------------------------------------
-- TRANSLATION HELPER
----------------------------------------------------------------------
function GameSettings:t(key)
	local dict = T[self.language] or T.en
	return dict[key] or T.en[key] or key
end

----------------------------------------------------------------------
-- VOLUME HELPERS
----------------------------------------------------------------------
function GameSettings:getMasterVolumeLabel()
	return VOLUME_STEP_LABELS[self.masterVolumeIdx] or "75%"
end

function GameSettings:getMusicVolumeLabel()
	return MUSIC_STEP_LABELS[self.musicVolumeIdx] or "50%"
end

function GameSettings:stepMasterVolume(delta)
	local idx = math.clamp(self.masterVolumeIdx + delta, 1, #VOLUME_STEPS)
	self.masterVolumeIdx = idx
	pcall(function() SoundService.MasterVolume = VOLUME_STEPS[idx] end)
	self:_fire("masterVolumeIdx", idx)
end

function GameSettings:stepMusicVolume(delta)
	local idx = math.clamp(self.musicVolumeIdx + delta, 1, #MUSIC_STEPS)
	self.musicVolumeIdx = idx
	-- Attempt to set a dedicated ambient music sound group if one exists.
	pcall(function()
		local grp = SoundService:FindFirstChild("MusicGroup")
		if grp then grp.Volume = MUSIC_STEPS[idx] end
	end)
	self:_fire("musicVolumeIdx", idx)
end

----------------------------------------------------------------------
-- GENERIC SETTER + LISTENER
----------------------------------------------------------------------
function GameSettings:set(key, value)
	self[key] = value

	-- Side effects
	if key == "graphics" then
		pcall(function()
			local Lighting = game:GetService("Lighting")
			if value == "low" then
				Lighting.GlobalShadows = false
				pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)
			else
				Lighting.GlobalShadows = true
				pcall(function() Lighting.Technology = Enum.Technology.Future end)
			end
		end)
	end

	self:_fire(key, value)
end

function GameSettings:onChange(callback)
	table.insert(self._listeners, callback)
	-- Return a disconnect function
	return function()
		for i, c in ipairs(self._listeners) do
			if c == callback then table.remove(self._listeners, i); break end
		end
	end
end

function GameSettings:_fire(key, value)
	for _, cb in ipairs(self._listeners) do
		pcall(cb, key, value)
	end
end

----------------------------------------------------------------------
-- INITIALISE DEFAULTS
----------------------------------------------------------------------
pcall(function() SoundService.MasterVolume = VOLUME_STEPS[GameSettings.masterVolumeIdx] end)

return GameSettings
