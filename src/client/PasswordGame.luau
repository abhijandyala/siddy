-- PasswordGame.luau
-- Mini-game #1 for Cybersecurity career
-- "Pick the strongest password" - 3 rounds, 5 seconds each, scored out of 100

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameState"))

local PasswordGame = {}

local ROUND_TIME = 5
local NUM_ROUNDS = 3

local ROUNDS = {
	{
		prompt = "Which password is the STRONGEST?",
		options = {
			{ text = "password123", correct = false },
			{ text = "MyDog2024", correct = false },
			{ text = "k$9Fq!mZ2x", correct = true },
		},
	},
	{
		prompt = "Which password is the STRONGEST?",
		options = {
			{ text = "8#hLp@2qXr!", correct = true },
			{ text = "admin", correct = false },
			{ text = "Summer2025!", correct = false },
		},
	},
	{
		prompt = "Which password is the STRONGEST?",
		options = {
			{ text = "qwerty", correct = false },
			{ text = "Zk!9v&3mPw$", correct = true },
			{ text = "Baseball99", correct = false },
		},
	},
}

local COLORS = {
	bg = Color3.fromRGB(10, 10, 35),
	card = Color3.fromRGB(20, 30, 80),
	button = Color3.fromRGB(30, 50, 120),
	buttonHover = Color3.fromRGB(40, 65, 150),
	accent = Color3.fromRGB(60, 120, 255),
	correct = Color3.fromRGB(30, 160, 70),
	wrong = Color3.fromRGB(180, 40, 40),
	text = Color3.fromRGB(255, 255, 255),
	textDim = Color3.fromRGB(160, 170, 200),
	timerBg = Color3.fromRGB(15, 20, 50),
	timerFill = Color3.fromRGB(60, 120, 255),
}

function PasswordGame.Play()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	local score = 0
	local answered = false
	
	-- Main ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "PasswordGame"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 955  -- Above hacking background (950)
	gui.Parent = playerGui
	
	-- Full background (semi-transparent to show hacking background)
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = COLORS.bg
	bg.BackgroundTransparency = 0.4  -- Show hacking background through
	bg.BorderSizePixel = 0
	bg.Parent = gui
	
	-- Card container
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Size = UDim2.new(0.55, 0, 0.7, 0)
	card.Position = UDim2.new(0.5, 0, 0.48, 0)
	card.BackgroundColor3 = COLORS.card
	card.BackgroundTransparency = 0
	card.BorderSizePixel = 0
	card.Parent = bg
	
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 24)
	cardCorner.Parent = card
	
	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingTop = UDim.new(0, 24)
	cardPadding.PaddingBottom = UDim.new(0, 24)
	cardPadding.PaddingLeft = UDim.new(0, 32)
	cardPadding.PaddingRight = UDim.new(0, 32)
	cardPadding.Parent = card
	
	-- Round counter (top right of card)
	local roundLabel = Instance.new("TextLabel")
	roundLabel.Name = "RoundLabel"
	roundLabel.AnchorPoint = Vector2.new(1, 0)
	roundLabel.Size = UDim2.new(0, 80, 0, 24)
	roundLabel.Position = UDim2.new(1, 0, 0, 0)
	roundLabel.BackgroundTransparency = 1
	roundLabel.TextColor3 = COLORS.textDim
	roundLabel.TextSize = 14
	roundLabel.Font = Enum.Font.GothamMedium
	roundLabel.Text = ""
	roundLabel.TextXAlignment = Enum.TextXAlignment.Right
	roundLabel.Parent = card
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 32)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "PASSWORD SECURITY"
	title.TextColor3 = COLORS.accent
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card
	
	-- Prompt
	local prompt = Instance.new("TextLabel")
	prompt.Name = "Prompt"
	prompt.Size = UDim2.new(1, 0, 0, 40)
	prompt.Position = UDim2.new(0, 0, 0, 44)
	prompt.BackgroundTransparency = 1
	prompt.Text = ""
	prompt.TextColor3 = COLORS.text
	prompt.TextSize = 24
	prompt.Font = Enum.Font.GothamBold
	prompt.TextXAlignment = Enum.TextXAlignment.Left
	prompt.TextWrapped = true
	prompt.Parent = card
	
	-- Buttons container
	local buttonContainer = Instance.new("Frame")
	buttonContainer.Name = "Buttons"
	buttonContainer.Size = UDim2.new(1, 0, 0.55, 0)
	buttonContainer.Position = UDim2.new(0, 0, 0, 100)
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.Parent = card
	
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buttonLayout.Padding = UDim.new(0, 12)
	buttonLayout.FillDirection = Enum.FillDirection.Vertical
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.Parent = buttonContainer
	
	-- Timer bar (bottom of card)
	local timerBg = Instance.new("Frame")
	timerBg.Name = "TimerBg"
	timerBg.AnchorPoint = Vector2.new(0.5, 1)
	timerBg.Size = UDim2.new(1, 0, 0, 6)
	timerBg.Position = UDim2.new(0.5, 0, 1, 0)
	timerBg.BackgroundColor3 = COLORS.timerBg
	timerBg.BorderSizePixel = 0
	timerBg.Parent = card
	
	local timerCornerBg = Instance.new("UICorner")
	timerCornerBg.CornerRadius = UDim.new(0, 3)
	timerCornerBg.Parent = timerBg
	
	local timerFill = Instance.new("Frame")
	timerFill.Name = "Fill"
	timerFill.Size = UDim2.new(1, 0, 1, 0)
	timerFill.BackgroundColor3 = COLORS.timerFill
	timerFill.BorderSizePixel = 0
	timerFill.Parent = timerBg
	
	local timerCornerFill = Instance.new("UICorner")
	timerCornerFill.CornerRadius = UDim.new(0, 3)
	timerCornerFill.Parent = timerFill
	
	-- Feedback label (shows CORRECT / WRONG)
	local feedback = Instance.new("TextLabel")
	feedback.Name = "Feedback"
	feedback.AnchorPoint = Vector2.new(0.5, 0)
	feedback.Size = UDim2.new(1, 0, 0, 36)
	feedback.Position = UDim2.new(0.5, 0, 0.78, 0)
	feedback.BackgroundTransparency = 1
	feedback.TextColor3 = COLORS.text
	feedback.TextSize = 22
	feedback.Font = Enum.Font.GothamBold
	feedback.Text = ""
	feedback.TextTransparency = 1
	feedback.Parent = card
	
	-- Helper: create a password button
	local function createOptionButton(index, text, correct)
		local btn = Instance.new("TextButton")
		btn.Name = "Option_" .. index
		btn.Size = UDim2.new(1, 0, 0, 50)
		btn.LayoutOrder = index
		btn.BackgroundColor3 = COLORS.button
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = buttonContainer
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 12)
		btnCorner.Parent = btn
		
		local btnStroke = Instance.new("UIStroke")
		btnStroke.Color = COLORS.accent
		btnStroke.Transparency = 0.7
		btnStroke.Thickness = 1.5
		btnStroke.Parent = btn
		
		-- Password text (monospace)
		local passLabel = Instance.new("TextLabel")
		passLabel.Name = "PassText"
		passLabel.Size = UDim2.new(1, -24, 1, 0)
		passLabel.Position = UDim2.new(0, 12, 0, 0)
		passLabel.BackgroundTransparency = 1
		passLabel.Text = text
		passLabel.TextColor3 = COLORS.text
		passLabel.TextSize = 22
		passLabel.Font = Enum.Font.Code
		passLabel.TextXAlignment = Enum.TextXAlignment.Left
		passLabel.TextTransparency = 0
		passLabel.Parent = btn
		
		-- Hover effect
		btn.MouseEnter:Connect(function()
			if answered then return end
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.buttonHover}):Play()
			TweenService:Create(btnStroke, TweenInfo.new(0.15), {Transparency = 0.2}):Play()
		end)
		
		btn.MouseLeave:Connect(function()
			if answered then return end
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.button}):Play()
			TweenService:Create(btnStroke, TweenInfo.new(0.15), {Transparency = 0.7}):Play()
		end)
		
		return btn, correct
	end
	
	-- Background starts semi-transparent (to show hacking background)
	bg.BackgroundTransparency = 0.4
	card.BackgroundTransparency = 1
	title.TextTransparency = 1
	prompt.TextTransparency = 1
	roundLabel.TextTransparency = 1
	
	TweenService:Create(card, TweenInfo.new(0.5), {BackgroundTransparency = 0}):Play()
	TweenService:Create(title, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	task.wait(0.5)
	
	-- Track current round to prevent stale callbacks from affecting wrong rounds
	local currentRound = 0
	local colorTween = nil
	
	-- Play each round
	for roundIndex = 1, NUM_ROUNDS do
		local roundData = ROUNDS[roundIndex]
		answered = false
		currentRound = roundIndex
		
		-- Update UI
		roundLabel.Text = roundIndex .. " / " .. NUM_ROUNDS
		prompt.Text = roundData.prompt
		
		TweenService:Create(prompt, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
		TweenService:Create(roundLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
		
		-- Clear old buttons
		for _, child in pairs(buttonContainer:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		
		-- Create buttons for this round (fade them in with stagger)
		local buttons = {}
		for i, option in ipairs(roundData.options) do
			local btn, isCorrect = createOptionButton(i, option.text, option.correct)
			btn.BackgroundTransparency = 1
			btn:FindFirstChild("PassText").TextTransparency = 1
			btn:FindFirstChildOfClass("UIStroke").Transparency = 1
			
			task.delay(0.1 * i, function()
				TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
				TweenService:Create(btn:FindFirstChild("PassText"), TweenInfo.new(0.3), {TextTransparency = 0}):Play()
				TweenService:Create(btn:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.3), {Transparency = 0.7}):Play()
			end)
			
			table.insert(buttons, { btn = btn, correct = option.correct })
		end
		
		-- Cancel any existing color tween from previous round
		if colorTween then
			colorTween:Cancel()
			colorTween = nil
		end
		
		-- Reset timer: size AND color (use instant tween to cancel any in-flight color animations)
		timerFill.Size = UDim2.new(1, 0, 1, 0)
		timerFill.BackgroundColor3 = COLORS.timerFill
		
		local timerTween = TweenService:Create(timerFill,
			TweenInfo.new(ROUND_TIME, Enum.EasingStyle.Linear),
			{Size = UDim2.new(0, 0, 1, 0)}
		)
		timerTween:Play()
		
		-- Change timer color when low - only 1 second left (80% through)
		local thisRound = roundIndex
		task.delay(ROUND_TIME * 0.8, function()
			if not answered and currentRound == thisRound then
				colorTween = TweenService:Create(timerFill, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 60, 60)})
				colorTween:Play()
			end
		end)
		
		-- Connect button clicks
		local connections = {}
		for _, data in ipairs(buttons) do
			local conn = data.btn.MouseButton1Click:Connect(function()
				if answered then return end
				answered = true
				timerTween:Cancel()
				
				if data.correct then
					score = score + 1
					data.btn.BackgroundColor3 = COLORS.correct
					data.btn:FindFirstChildOfClass("UIStroke").Color = COLORS.correct
					data.btn:FindFirstChildOfClass("UIStroke").Transparency = 0
					feedback.Text = "CORRECT!"
					feedback.TextColor3 = COLORS.correct
				else
					data.btn.BackgroundColor3 = COLORS.wrong
					data.btn:FindFirstChildOfClass("UIStroke").Color = COLORS.wrong
					data.btn:FindFirstChildOfClass("UIStroke").Transparency = 0
					feedback.Text = "WRONG"
					feedback.TextColor3 = COLORS.wrong
					
					-- Highlight the correct answer
					for _, d in ipairs(buttons) do
						if d.correct then
							TweenService:Create(d.btn, TweenInfo.new(0.3), {BackgroundColor3 = COLORS.correct}):Play()
							d.btn:FindFirstChildOfClass("UIStroke").Color = COLORS.correct
							d.btn:FindFirstChildOfClass("UIStroke").Transparency = 0
						end
					end
				end
				
				TweenService:Create(feedback, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
			end)
			table.insert(connections, conn)
		end
		
		-- Wait for answer or timeout
		local waitStart = tick()
		while not answered and (tick() - waitStart) < ROUND_TIME do
			task.wait(0.05)
		end
		
		-- If timed out without answer
		if not answered then
			answered = true
			timerTween:Cancel()
			feedback.Text = "TIME'S UP!"
			feedback.TextColor3 = COLORS.wrong
			TweenService:Create(feedback, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
			
			for _, d in ipairs(buttons) do
				if d.correct then
					TweenService:Create(d.btn, TweenInfo.new(0.3), {BackgroundColor3 = COLORS.correct}):Play()
					d.btn:FindFirstChildOfClass("UIStroke").Color = COLORS.correct
					d.btn:FindFirstChildOfClass("UIStroke").Transparency = 0
				end
			end
		end
		
		-- Clean up connections
		for _, conn in pairs(connections) do
			conn:Disconnect()
		end
		
		-- Pause to show result
		task.wait(1.2)
		
		-- Fade out feedback + buttons
		TweenService:Create(feedback, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		TweenService:Create(prompt, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		for _, data in ipairs(buttons) do
			TweenService:Create(data.btn, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
			TweenService:Create(data.btn:FindFirstChild("PassText"), TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		end
		task.wait(0.4)
	end
	
	-- ============================================
	-- SCORE SCREEN
	-- ============================================
	
	-- Clear buttons
	for _, child in pairs(buttonContainer:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	
	-- Hide round elements
	prompt.Visible = false
	roundLabel.Visible = false
	timerBg.Visible = false
	feedback.Visible = false
	title.Visible = false
	
	-- Score value (0-100)
	local finalScore = math.floor((score / NUM_ROUNDS) * 100)
	
	-- Save to GameState (puzzle 1 for Cyber)
	GameState:SetScore("Cyber", 1, finalScore)
	
	-- Score display
	local scoreTitle = Instance.new("TextLabel")
	scoreTitle.Name = "ScoreTitle"
	scoreTitle.AnchorPoint = Vector2.new(0.5, 0)
	scoreTitle.Size = UDim2.new(1, 0, 0, 30)
	scoreTitle.Position = UDim2.new(0.5, 0, 0.1, 0)
	scoreTitle.BackgroundTransparency = 1
	scoreTitle.Text = "MINI-GAME COMPLETE"
	scoreTitle.TextColor3 = COLORS.accent
	scoreTitle.TextSize = 18
	scoreTitle.Font = Enum.Font.GothamBold
	scoreTitle.TextTransparency = 1
	scoreTitle.Parent = card
	
	local scoreNumber = Instance.new("TextLabel")
	scoreNumber.Name = "ScoreNumber"
	scoreNumber.AnchorPoint = Vector2.new(0.5, 0.5)
	scoreNumber.Size = UDim2.new(1, 0, 0, 80)
	scoreNumber.Position = UDim2.new(0.5, 0, 0.4, 0)
	scoreNumber.BackgroundTransparency = 1
	scoreNumber.Text = finalScore .. " / 100"
	scoreNumber.TextColor3 = COLORS.text
	scoreNumber.TextSize = 56
	scoreNumber.Font = Enum.Font.GothamBold
	scoreNumber.TextTransparency = 1
	scoreNumber.Parent = card
	
	local scoreDetail = Instance.new("TextLabel")
	scoreDetail.Name = "ScoreDetail"
	scoreDetail.AnchorPoint = Vector2.new(0.5, 0)
	scoreDetail.Size = UDim2.new(1, 0, 0, 24)
	scoreDetail.Position = UDim2.new(0.5, 0, 0.55, 0)
	scoreDetail.BackgroundTransparency = 1
	scoreDetail.Text = score .. " out of " .. NUM_ROUNDS .. " correct"
	scoreDetail.TextColor3 = COLORS.textDim
	scoreDetail.TextSize = 16
	scoreDetail.Font = Enum.Font.GothamMedium
	scoreDetail.TextTransparency = 1
	scoreDetail.Parent = card
	
	local gradeText = ""
	if finalScore == 100 then
		gradeText = "Perfect! You're a password pro!"
	elseif finalScore >= 66 then
		gradeText = "Good job! Keep learning!"
	else
		gradeText = "Study up on password security!"
	end
	
	local gradeLabel = Instance.new("TextLabel")
	gradeLabel.Name = "Grade"
	gradeLabel.AnchorPoint = Vector2.new(0.5, 0)
	gradeLabel.Size = UDim2.new(1, 0, 0, 24)
	gradeLabel.Position = UDim2.new(0.5, 0, 0.65, 0)
	gradeLabel.BackgroundTransparency = 1
	gradeLabel.Text = gradeText
	gradeLabel.TextColor3 = COLORS.accent
	gradeLabel.TextSize = 16
	gradeLabel.Font = Enum.Font.GothamMedium
	gradeLabel.TextTransparency = 1
	gradeLabel.Parent = card
	
	-- Fade in score screen
	TweenService:Create(scoreTitle, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
	task.wait(0.3)
	TweenService:Create(scoreNumber, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	task.wait(0.3)
	TweenService:Create(scoreDetail, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
	TweenService:Create(gradeLabel, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
	
	-- Hold the score screen
	task.wait(3)
	
	-- Fade out text/card only (keep background opaque so there's no flash)
	TweenService:Create(card, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
	TweenService:Create(scoreTitle, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
	TweenService:Create(scoreNumber, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
	TweenService:Create(scoreDetail, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
	TweenService:Create(gradeLabel, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
	task.wait(0.4)
	
	gui:Destroy()
	
	print("PasswordGame: Complete! Score: " .. finalScore .. "/100")
	return finalScore
end

return PasswordGame
