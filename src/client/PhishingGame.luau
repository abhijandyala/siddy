-- PhishingGame.luau
-- Mini-game #2 for Cybersecurity career
-- "Is this email Safe or Phishing?" - 3 rounds, 5 seconds each, scored out of 100

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameState"))

local PhishingGame = {}

local ROUND_TIME = 5
local NUM_ROUNDS = 3

local ROUNDS = {
	{
		sender = "Amaz0n-Support@mail.net",
		subject = "URGENT: Your account will be deleted in 24 hours!",
		body = "Click here immediately to verify your identity or lose access forever! Act now before it's too late!",
		isPhishing = true,
	},
	{
		sender = "teacher@school.edu",
		subject = "Homework Reminder",
		body = "Don't forget to turn in your essay by Friday. Let me know if you have any questions.",
		isPhishing = false,
	},
	{
		sender = "free-r0bux@prizes.com",
		subject = "You won 10,000 Robux!",
		body = "Enter your password below to claim your free prize right now! This offer expires today!",
		isPhishing = true,
	},
}

local COLORS = {
	bg = Color3.fromRGB(10, 10, 35),
	card = Color3.fromRGB(20, 30, 80),
	emailBg = Color3.fromRGB(12, 18, 50),
	safeBtn = Color3.fromRGB(30, 50, 120),
	safeBtnHover = Color3.fromRGB(40, 70, 160),
	phishBtn = Color3.fromRGB(70, 30, 100),
	phishBtnHover = Color3.fromRGB(100, 40, 140),
	accent = Color3.fromRGB(60, 120, 255),
	correct = Color3.fromRGB(30, 160, 70),
	wrong = Color3.fromRGB(180, 40, 40),
	text = Color3.fromRGB(255, 255, 255),
	textDim = Color3.fromRGB(160, 170, 200),
	senderColor = Color3.fromRGB(100, 160, 255),
	subjectColor = Color3.fromRGB(220, 220, 240),
	timerBg = Color3.fromRGB(15, 20, 50),
	timerFill = Color3.fromRGB(60, 120, 255),
}

function PhishingGame.Play()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	local score = 0
	local answered = false
	
	-- Main ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "PhishingGame"
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
	card.Size = UDim2.new(0.58, 0, 0.75, 0)
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
	
	-- Round counter
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
	title.Text = "PHISHING DETECTOR"
	title.TextColor3 = COLORS.accent
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card
	
	-- Prompt
	local prompt = Instance.new("TextLabel")
	prompt.Name = "Prompt"
	prompt.Size = UDim2.new(1, 0, 0, 30)
	prompt.Position = UDim2.new(0, 0, 0, 36)
	prompt.BackgroundTransparency = 1
	prompt.Text = "Is this email safe or phishing?"
	prompt.TextColor3 = COLORS.text
	prompt.TextSize = 20
	prompt.Font = Enum.Font.GothamBold
	prompt.TextXAlignment = Enum.TextXAlignment.Left
	prompt.Parent = card
	
	-- Email container (looks like an inbox message)
	local emailFrame = Instance.new("Frame")
	emailFrame.Name = "Email"
	emailFrame.Size = UDim2.new(1, 0, 0.45, 0)
	emailFrame.Position = UDim2.new(0, 0, 0, 80)
	emailFrame.BackgroundColor3 = COLORS.emailBg
	emailFrame.BorderSizePixel = 0
	emailFrame.Parent = card
	
	local emailCorner = Instance.new("UICorner")
	emailCorner.CornerRadius = UDim.new(0, 14)
	emailCorner.Parent = emailFrame
	
	local emailStroke = Instance.new("UIStroke")
	emailStroke.Color = COLORS.accent
	emailStroke.Transparency = 0.75
	emailStroke.Thickness = 1
	emailStroke.Parent = emailFrame
	
	local emailPadding = Instance.new("UIPadding")
	emailPadding.PaddingTop = UDim.new(0, 16)
	emailPadding.PaddingBottom = UDim.new(0, 16)
	emailPadding.PaddingLeft = UDim.new(0, 20)
	emailPadding.PaddingRight = UDim.new(0, 20)
	emailPadding.Parent = emailFrame
	
	-- From label
	local fromLabel = Instance.new("TextLabel")
	fromLabel.Name = "From"
	fromLabel.Size = UDim2.new(1, 0, 0, 20)
	fromLabel.Position = UDim2.new(0, 0, 0, 0)
	fromLabel.BackgroundTransparency = 1
	fromLabel.RichText = true
	fromLabel.Text = ""
	fromLabel.TextColor3 = COLORS.text
	fromLabel.TextSize = 14
	fromLabel.Font = Enum.Font.GothamMedium
	fromLabel.TextXAlignment = Enum.TextXAlignment.Left
	fromLabel.Parent = emailFrame
	
	-- Subject label
	local subjectLabel = Instance.new("TextLabel")
	subjectLabel.Name = "Subject"
	subjectLabel.Size = UDim2.new(1, 0, 0, 26)
	subjectLabel.Position = UDim2.new(0, 0, 0, 26)
	subjectLabel.BackgroundTransparency = 1
	subjectLabel.Text = ""
	subjectLabel.TextColor3 = COLORS.subjectColor
	subjectLabel.TextSize = 18
	subjectLabel.Font = Enum.Font.GothamBold
	subjectLabel.TextXAlignment = Enum.TextXAlignment.Left
	subjectLabel.TextWrapped = true
	subjectLabel.Parent = emailFrame
	
	-- Separator line
	local separator = Instance.new("Frame")
	separator.Name = "Separator"
	separator.Size = UDim2.new(1, 0, 0, 1)
	separator.Position = UDim2.new(0, 0, 0, 58)
	separator.BackgroundColor3 = COLORS.accent
	separator.BackgroundTransparency = 0.7
	separator.BorderSizePixel = 0
	separator.Parent = emailFrame
	
	-- Body label
	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "Body"
	bodyLabel.Size = UDim2.new(1, 0, 1, -70)
	bodyLabel.Position = UDim2.new(0, 0, 0, 68)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Text = ""
	bodyLabel.TextColor3 = COLORS.textDim
	bodyLabel.TextSize = 15
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.TextWrapped = true
	bodyLabel.LineHeight = 1.3
	bodyLabel.Parent = emailFrame
	
	-- Buttons container (side by side)
	local btnContainer = Instance.new("Frame")
	btnContainer.Name = "Buttons"
	btnContainer.AnchorPoint = Vector2.new(0.5, 0)
	btnContainer.Size = UDim2.new(1, 0, 0, 52)
	btnContainer.Position = UDim2.new(0.5, 0, 0.78, 0)
	btnContainer.BackgroundTransparency = 1
	btnContainer.Parent = card
	
	local btnLayout = Instance.new("UIListLayout")
	btnLayout.SortOrder = Enum.SortOrder.LayoutOrder
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.Padding = UDim.new(0, 16)
	btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	btnLayout.Parent = btnContainer
	
	-- SAFE button
	local safeBtn = Instance.new("TextButton")
	safeBtn.Name = "SafeBtn"
	safeBtn.Size = UDim2.new(0.45, 0, 1, 0)
	safeBtn.LayoutOrder = 1
	safeBtn.BackgroundColor3 = COLORS.safeBtn
	safeBtn.BorderSizePixel = 0
	safeBtn.Text = "SAFE"
	safeBtn.TextColor3 = COLORS.text
	safeBtn.TextSize = 20
	safeBtn.Font = Enum.Font.GothamBold
	safeBtn.AutoButtonColor = false
	safeBtn.Parent = btnContainer
	
	local safeBtnCorner = Instance.new("UICorner")
	safeBtnCorner.CornerRadius = UDim.new(0, 12)
	safeBtnCorner.Parent = safeBtn
	
	local safeBtnStroke = Instance.new("UIStroke")
	safeBtnStroke.Color = COLORS.accent
	safeBtnStroke.Transparency = 0.6
	safeBtnStroke.Thickness = 1.5
	safeBtnStroke.Parent = safeBtn
	
	-- PHISHING button
	local phishBtn = Instance.new("TextButton")
	phishBtn.Name = "PhishBtn"
	phishBtn.Size = UDim2.new(0.45, 0, 1, 0)
	phishBtn.LayoutOrder = 2
	phishBtn.BackgroundColor3 = COLORS.phishBtn
	phishBtn.BorderSizePixel = 0
	phishBtn.Text = "PHISHING"
	phishBtn.TextColor3 = COLORS.text
	phishBtn.TextSize = 20
	phishBtn.Font = Enum.Font.GothamBold
	phishBtn.AutoButtonColor = false
	phishBtn.Parent = btnContainer
	
	local phishBtnCorner = Instance.new("UICorner")
	phishBtnCorner.CornerRadius = UDim.new(0, 12)
	phishBtnCorner.Parent = phishBtn
	
	local phishBtnStroke = Instance.new("UIStroke")
	phishBtnStroke.Color = Color3.fromRGB(140, 80, 200)
	phishBtnStroke.Transparency = 0.6
	phishBtnStroke.Thickness = 1.5
	phishBtnStroke.Parent = phishBtn
	
	-- Hover effects
	safeBtn.MouseEnter:Connect(function()
		if answered then return end
		TweenService:Create(safeBtn, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.safeBtnHover}):Play()
	end)
	safeBtn.MouseLeave:Connect(function()
		if answered then return end
		TweenService:Create(safeBtn, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.safeBtn}):Play()
	end)
	phishBtn.MouseEnter:Connect(function()
		if answered then return end
		TweenService:Create(phishBtn, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.phishBtnHover}):Play()
	end)
	phishBtn.MouseLeave:Connect(function()
		if answered then return end
		TweenService:Create(phishBtn, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.phishBtn}):Play()
	end)
	
	-- Timer bar
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
	
	-- Feedback label
	local feedback = Instance.new("TextLabel")
	feedback.Name = "Feedback"
	feedback.AnchorPoint = Vector2.new(0.5, 0)
	feedback.Size = UDim2.new(1, 0, 0, 30)
	feedback.Position = UDim2.new(0.5, 0, 0.9, 0)
	feedback.BackgroundTransparency = 1
	feedback.TextColor3 = COLORS.text
	feedback.TextSize = 20
	feedback.Font = Enum.Font.GothamBold
	feedback.Text = ""
	feedback.TextTransparency = 1
	feedback.Parent = card
	
	-- Background starts semi-transparent (to show hacking background)
	bg.BackgroundTransparency = 0.4
	card.BackgroundTransparency = 1
	title.TextTransparency = 1
	prompt.TextTransparency = 1
	roundLabel.TextTransparency = 1
	emailFrame.BackgroundTransparency = 1
	emailStroke.Transparency = 1
	safeBtn.BackgroundTransparency = 1
	safeBtn.TextTransparency = 1
	safeBtnStroke.Transparency = 1
	phishBtn.BackgroundTransparency = 1
	phishBtn.TextTransparency = 1
	phishBtnStroke.Transparency = 1
	fromLabel.TextTransparency = 1
	subjectLabel.TextTransparency = 1
	bodyLabel.TextTransparency = 1
	separator.BackgroundTransparency = 1
	
	-- Skip-aware bailout: tear down the GUI and return the score so far
	local function bail()
		if gui and gui.Parent then gui:Destroy() end
		return math.floor((score / NUM_ROUNDS) * 100)
	end
	
	TweenService:Create(card, TweenInfo.new(0.5), {BackgroundTransparency = 0}):Play()
	TweenService:Create(title, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	task.wait(0.5)
	if GameState.SkipRequested then return bail() end
	
	-- Track current round to prevent stale callbacks from affecting wrong rounds
	local currentRound = 0
	local colorTween = nil
	
	-- Play each round
	for roundIndex = 1, NUM_ROUNDS do
		if GameState.SkipRequested then break end
		local roundData = ROUNDS[roundIndex]
		answered = false
		currentRound = roundIndex
		
		-- Update email content
		roundLabel.Text = roundIndex .. " / " .. NUM_ROUNDS
		fromLabel.Text = '<font color="#64A0FF">From: </font>' .. roundData.sender
		subjectLabel.Text = roundData.subject
		bodyLabel.Text = roundData.body
		
		-- Reset button colors
		safeBtn.BackgroundColor3 = COLORS.safeBtn
		phishBtn.BackgroundColor3 = COLORS.phishBtn
		safeBtnStroke.Color = COLORS.accent
		phishBtnStroke.Color = Color3.fromRGB(140, 80, 200)
		
		-- Fade in round elements
		TweenService:Create(prompt, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
		TweenService:Create(roundLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
		TweenService:Create(emailFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
		TweenService:Create(emailStroke, TweenInfo.new(0.3), {Transparency = 0.75}):Play()
		TweenService:Create(separator, TweenInfo.new(0.3), {BackgroundTransparency = 0.7}):Play()
		
		task.delay(0.15, function()
			TweenService:Create(fromLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
			TweenService:Create(subjectLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
		end)
		task.delay(0.3, function()
			TweenService:Create(bodyLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
		end)
		task.delay(0.2, function()
			TweenService:Create(safeBtn, TweenInfo.new(0.3), {BackgroundTransparency = 0, TextTransparency = 0}):Play()
			TweenService:Create(safeBtnStroke, TweenInfo.new(0.3), {Transparency = 0.6}):Play()
			TweenService:Create(phishBtn, TweenInfo.new(0.3), {BackgroundTransparency = 0, TextTransparency = 0}):Play()
			TweenService:Create(phishBtnStroke, TweenInfo.new(0.3), {Transparency = 0.6}):Play()
		end)
		
		-- Cancel any existing color tween from previous round
		if colorTween then
			colorTween:Cancel()
			colorTween = nil
		end
		
		-- Reset timer: size AND color
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
		
		-- Handle answer
		local function handleAnswer(pickedPhishing)
			if answered then return end
			answered = true
			timerTween:Cancel()
			
			local correct = (pickedPhishing == roundData.isPhishing)
			
			if correct then
				score = score + 1
				feedback.Text = "CORRECT!"
				feedback.TextColor3 = COLORS.correct
				
				if pickedPhishing then
					phishBtn.BackgroundColor3 = COLORS.correct
					phishBtnStroke.Color = COLORS.correct
					phishBtnStroke.Transparency = 0
				else
					safeBtn.BackgroundColor3 = COLORS.correct
					safeBtnStroke.Color = COLORS.correct
					safeBtnStroke.Transparency = 0
				end
			else
				feedback.Text = "WRONG"
				feedback.TextColor3 = COLORS.wrong
				
				if pickedPhishing then
					phishBtn.BackgroundColor3 = COLORS.wrong
					phishBtnStroke.Color = COLORS.wrong
					phishBtnStroke.Transparency = 0
					safeBtn.BackgroundColor3 = COLORS.correct
					safeBtnStroke.Color = COLORS.correct
					safeBtnStroke.Transparency = 0
				else
					safeBtn.BackgroundColor3 = COLORS.wrong
					safeBtnStroke.Color = COLORS.wrong
					safeBtnStroke.Transparency = 0
					phishBtn.BackgroundColor3 = COLORS.correct
					phishBtnStroke.Color = COLORS.correct
					phishBtnStroke.Transparency = 0
				end
			end
			
			TweenService:Create(feedback, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
		end
		
		local safeConn = safeBtn.MouseButton1Click:Connect(function()
			handleAnswer(false)
		end)
		local phishConn = phishBtn.MouseButton1Click:Connect(function()
			handleAnswer(true)
		end)
		
		-- Wait for answer or timeout
		local waitStart = tick()
		while not answered and (tick() - waitStart) < ROUND_TIME do
			if GameState.SkipRequested then break end
			task.wait(0.05)
		end
		
		if GameState.SkipRequested then
			safeConn:Disconnect()
			phishConn:Disconnect()
			return bail()
		end
		
		if not answered then
			answered = true
			timerTween:Cancel()
			feedback.Text = "TIME'S UP!"
			feedback.TextColor3 = COLORS.wrong
			TweenService:Create(feedback, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
			
			if roundData.isPhishing then
				TweenService:Create(phishBtn, TweenInfo.new(0.3), {BackgroundColor3 = COLORS.correct}):Play()
				phishBtnStroke.Color = COLORS.correct
				phishBtnStroke.Transparency = 0
			else
				TweenService:Create(safeBtn, TweenInfo.new(0.3), {BackgroundColor3 = COLORS.correct}):Play()
				safeBtnStroke.Color = COLORS.correct
				safeBtnStroke.Transparency = 0
			end
		end
		
		safeConn:Disconnect()
		phishConn:Disconnect()
		
		-- Pause to show result
		task.wait(1.2)
		
		-- Fade out round elements
		TweenService:Create(feedback, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		TweenService:Create(prompt, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		TweenService:Create(emailFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
		TweenService:Create(emailStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
		TweenService:Create(fromLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		TweenService:Create(subjectLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		TweenService:Create(bodyLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		TweenService:Create(separator, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
		TweenService:Create(safeBtn, TweenInfo.new(0.3), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
		TweenService:Create(safeBtnStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
		TweenService:Create(phishBtn, TweenInfo.new(0.3), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
		TweenService:Create(phishBtnStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
		task.wait(0.4)
	end
	
	if GameState.SkipRequested then return bail() end
	
	-- ============================================
	-- SCORE SCREEN
	-- ============================================
	
	emailFrame.Visible = false
	prompt.Visible = false
	roundLabel.Visible = false
	timerBg.Visible = false
	feedback.Visible = false
	title.Visible = false
	btnContainer.Visible = false
	
	local finalScore = math.floor((score / NUM_ROUNDS) * 100)
	
	GameState:SetScore("Cyber", 2, finalScore)
	
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
		gradeText = "Perfect! You can spot any scam!"
	elseif finalScore >= 66 then
		gradeText = "Nice work! Stay alert online!"
	else
		gradeText = "Be careful with suspicious emails!"
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
	
	TweenService:Create(scoreTitle, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
	task.wait(0.3)
	TweenService:Create(scoreNumber, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	task.wait(0.3)
	TweenService:Create(scoreDetail, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
	TweenService:Create(gradeLabel, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
	
	task.wait(3)
	
	TweenService:Create(card, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
	TweenService:Create(scoreTitle, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
	TweenService:Create(scoreNumber, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
	TweenService:Create(scoreDetail, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
	TweenService:Create(gradeLabel, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
	task.wait(0.4)
	
	gui:Destroy()
	
	print("PhishingGame: Complete! Score: " .. finalScore .. "/100")
	return finalScore
end

return PhishingGame
