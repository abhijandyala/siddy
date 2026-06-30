-- GameState.luau
-- Shared state module used by all client scripts
-- Tracks game flow (menu → play → careers) and scoring

local GameState = {}

-- Game flow state
GameState.Started = false
GameState.GameStartedEvent = Instance.new("BindableEvent")

-- Cooperative skip flag.
-- PlaySequence sets this true when the player skips the current world; long-running
-- minigame/world loops poll it so they can bail out early instead of running in the
-- background. PlaySequence clears it at the start of every world.
GameState.SkipRequested = false

-- Scoring: each career stores per-activity scores out of 100 (Aviation has 4 tasks).
GameState.Scores = {
	Aviation = { 0, 0, 0, 0 },
	Cyber = { 0, 0, 0 },
	Chef = { 0, 0, 0 },
	Hospital = { 0, 0, 0 },
}

-- Call this when the player clicks Play
function GameState:StartGame()
	self.Started = true
	self.GameStartedEvent:Fire()
end

-- Request a skip of the current world (called by PlaySequence's skip button)
function GameState:RequestSkip()
	self.SkipRequested = true
end

-- Clear the skip flag (called by PlaySequence at the start of each world)
function GameState:ClearSkip()
	self.SkipRequested = false
end

-- True while the current world is being skipped
function GameState:IsSkipping()
	return self.SkipRequested == true
end

-- Set a puzzle score (career key, activity index, score 0-100)
function GameState:SetScore(career, puzzleIndex, score)
	local slots = self.Scores[career]
	if slots and puzzleIndex >= 1 and puzzleIndex <= #slots then
		slots[puzzleIndex] = math.clamp(score, 0, 100)
	end
end

-- Get the average score for one career
function GameState:GetCareerAverage(career)
	local slots = self.Scores[career]
	if not slots or #slots == 0 then return 0 end
	local total = 0
	for _, s in ipairs(slots) do
		total = total + s
	end
	return math.floor(total / #slots)
end

-- Get the final score (average of the three scored careers).
-- Aviation is a cinematic showcase world (no scored minigames), so it is not counted here.
function GameState:GetFinalScore()
	local cyberAvg = self:GetCareerAverage("Cyber")
	local chefAvg = self:GetCareerAverage("Chef")
	local hospitalAvg = self:GetCareerAverage("Hospital")
	return math.floor((cyberAvg + chefAvg + hospitalAvg) / 3)
end

return GameState
