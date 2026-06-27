-- GameState.luau
-- Shared state module used by all client scripts
-- Tracks game flow (menu → play → careers) and scoring

local GameState = {}

-- Game flow state
GameState.Started = false
GameState.GameStartedEvent = Instance.new("BindableEvent")

-- Scoring: 3 puzzles per career, each scored out of 100
GameState.Scores = {
	Cyber = { 0, 0, 0 },
	Chef = { 0, 0, 0 },
	Hospital = { 0, 0, 0 },
}

-- Call this when the player clicks Play
function GameState:StartGame()
	self.Started = true
	self.GameStartedEvent:Fire()
end

-- Set a puzzle score (career = "Cyber"/"Chef"/"Hospital", puzzleIndex = 1/2/3, score = 0-100)
function GameState:SetScore(career, puzzleIndex, score)
	if self.Scores[career] and puzzleIndex >= 1 and puzzleIndex <= 3 then
		self.Scores[career][puzzleIndex] = math.clamp(score, 0, 100)
	end
end

-- Get the average score for one career
function GameState:GetCareerAverage(career)
	if not self.Scores[career] then return 0 end
	local total = 0
	for _, s in ipairs(self.Scores[career]) do
		total = total + s
	end
	return math.floor(total / 3)
end

-- Get the final score (average of all three career averages)
function GameState:GetFinalScore()
	local cyberAvg = self:GetCareerAverage("Cyber")
	local chefAvg = self:GetCareerAverage("Chef")
	local hospitalAvg = self:GetCareerAverage("Hospital")
	return math.floor((cyberAvg + chefAvg + hospitalAvg) / 3)
end

return GameState
