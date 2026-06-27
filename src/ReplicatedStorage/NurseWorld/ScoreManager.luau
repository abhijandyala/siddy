--[[
	ScoreManager.luau
	Module: ReplicatedStorage/NurseWorld/ScoreManager
	
	Manages player scoring for the Nursing world.
	- Starts at 100 points
	- Deducts points for wrong answers (33 per wrong)
	- Tracks per-scenario and cumulative performance
	- Provides final evaluation rating
]]

local ScoreManager = {}
ScoreManager.__index = ScoreManager

-- Constants
local MAX_SCORE = 100
local DEDUCTION_PER_WRONG = 33
local RATINGS = {
	{ threshold = 100, label = "Perfect", stars = 3, message = "Flawless clinical judgment! You're ready for the floor." },
	{ threshold = 67, label = "Proficient", stars = 2, message = "Strong performance with room for growth. Review your missed decisions." },
	{ threshold = 34, label = "Needs Improvement", stars = 1, message = "Several critical errors. Patient safety depends on better clinical reasoning." },
	{ threshold = 0, label = "Critical Failure", stars = 0, message = "Too many errors in patient care. Extensive review and retraining required." },
}

function ScoreManager.new()
	local self = setmetatable({}, ScoreManager)

	self._currentScore = MAX_SCORE
	self._maxScore = MAX_SCORE
	self._wrongAnswers = 0
	self._correctAnswers = 0
	self._totalQuestions = 0
	self._scenarioResults = {} -- { scenarioId, score, wrong, correct }
	self._history = {} -- ordered list of { taskId, choiceIndex, wasCorrect, deduction }

	return self
end

-- Record an answer
function ScoreManager:RecordAnswer(scenarioId: string, taskId: string, choiceIndex: number, wasCorrect: boolean, deduction: number)
	self._totalQuestions += 1

	if wasCorrect then
		self._correctAnswers += 1
	else
		self._wrongAnswers += 1
		self._currentScore = math.max(0, self._currentScore - deduction)
	end

	table.insert(self._history, {
		scenarioId = scenarioId,
		taskId = taskId,
		choiceIndex = choiceIndex,
		wasCorrect = wasCorrect,
		deduction = deduction,
		scoreAfter = self._currentScore,
	})
end

-- Called at end of each scenario to snapshot results
function ScoreManager:EndScenario(scenarioId: string)
	local scenarioCorrect = 0
	local scenarioWrong = 0

	for _, entry in self._history do
		if entry.scenarioId == scenarioId then
			if entry.wasCorrect then
				scenarioCorrect += 1
			else
				scenarioWrong += 1
			end
		end
	end

	table.insert(self._scenarioResults, {
		scenarioId = scenarioId,
		correct = scenarioCorrect,
		wrong = scenarioWrong,
		totalTasks = scenarioCorrect + scenarioWrong,
	})
end

-- Get current score
function ScoreManager:GetScore(): number
	return self._currentScore
end

-- Get max possible score
function ScoreManager:GetMaxScore(): number
	return self._maxScore
end

-- Get score as percentage
function ScoreManager:GetScorePercent(): number
	return math.floor((self._currentScore / self._maxScore) * 100)
end

-- Get wrong answer count
function ScoreManager:GetWrongCount(): number
	return self._wrongAnswers
end

-- Get correct answer count
function ScoreManager:GetCorrectCount(): number
	return self._correctAnswers
end

-- Get total questions answered
function ScoreManager:GetTotalQuestions(): number
	return self._totalQuestions
end

-- Get the final rating based on score
function ScoreManager:GetRating(): { label: string, stars: number, message: string }
	for _, rating in RATINGS do
		if self._currentScore >= rating.threshold then
			return rating
		end
	end
	return RATINGS[#RATINGS] -- fallback to lowest
end

-- Get per-scenario results
function ScoreManager:GetScenarioResults()
	return self._scenarioResults
end

-- Get full answer history
function ScoreManager:GetHistory()
	return self._history
end

-- Get a summary table for the results screen
function ScoreManager:GetSummary()
	local rating = self:GetRating()
	return {
		finalScore = self._currentScore,
		maxScore = self._maxScore,
		percent = self:GetScorePercent(),
		correct = self._correctAnswers,
		wrong = self._wrongAnswers,
		total = self._totalQuestions,
		rating = rating.label,
		stars = rating.stars,
		message = rating.message,
		scenarios = self._scenarioResults,
		history = self._history,
	}
end

-- Reset everything (for replay)
function ScoreManager:Reset()
	self._currentScore = MAX_SCORE
	self._wrongAnswers = 0
	self._correctAnswers = 0
	self._totalQuestions = 0
	self._scenarioResults = {}
	self._history = {}
end

return ScoreManager
