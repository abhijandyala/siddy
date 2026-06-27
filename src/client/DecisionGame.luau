-- DecisionGame.luau
-- Mini-game #3 for Cybersecurity career
-- Player picks a scenario, reads the situation, makes a choice → outcome + score

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameState"))

local DecisionGame = {}

local SCENARIOS = {
	{
		id = "download",
		cardTitle = "Suspicious Download",
		cardDesc = "A friend sends you a mystery link...",
		situation = "Your friend messages you a link saying \"Check out this free game! It's amazing!\" but the URL looks weird: fr33-gamez.download.xyz",
		choices = {
			{
				text = "Download it right away — my friend sent it!",
				score = 0,
				outcome = "BAD MOVE!",
				detail = "The file contained malware that stole your passwords and personal data. Your friend's account was actually hacked — they never sent that link.",
				color = "wrong",
			},
			{
				text = "Message my friend on a different app to verify they sent it",
				score = 100,
				outcome = "PERFECT DECISION!",
				detail = "Your friend confirmed they never sent that link — their account was hacked! You avoided a dangerous malware attack by verifying first.",
				color = "perfect",
			},
			{
				text = "Google the website name to check if it's safe",
				score = 50,
				outcome = "DECENT CALL",
				detail = "You found some warnings about the site online. Good instinct to research, but the safest move is always to verify directly with the person who sent it.",
				color = "partial",
			},
		},
	},
	{
		id = "wifi",
		cardTitle = "Public WiFi Trap",
		cardDesc = "Free WiFi at a coffee shop — should you connect?",
		situation = "You're at a coffee shop and need to log into your school account to submit homework. There's a free WiFi network called \"CoffeeShop_FREE\" with no password required.",
		choices = {
			{
				text = "Connect to the WiFi and log in — it's just homework",
				score = 0,
				outcome = "BAD MOVE!",
				detail = "A hacker on the same network intercepted your login. They now have your school username and password. Open WiFi with no password means anyone can see your data!",
				color = "wrong",
			},
			{
				text = "Use my phone's mobile data instead",
				score = 100,
				outcome = "PERFECT DECISION!",
				detail = "Mobile data is encrypted and much safer than open WiFi. Your login stayed private and your homework was submitted securely!",
				color = "perfect",
			},
			{
				text = "Connect but don't log into anything important",
				score = 50,
				outcome = "DECENT CALL",
				detail = "Browsing without logging in is safer, but hackers can still track what sites you visit. The best option is to avoid open WiFi entirely for anything sensitive.",
				color = "partial",
			},
		},
	},
}

local COLORS = {
	bg = Color3.fromRGB(10, 10, 35),
	card = Color3.fromRGB(20, 30, 80),
	cardHover = Color3.fromRGB(30, 45, 110),
	choiceBtn = Color3.fromRGB(25, 40, 100),
	choiceBtnHover = Color3.fromRGB(35, 55, 135),
	accent = Color3.fromRGB(60, 120, 255),
	accentGlow = Color3.fromRGB(80, 150, 255),
	perfect = Color3.fromRGB(30, 180, 80),
	partial = Color3.fromRGB(220, 160, 30),
	wrong = Color3.fromRGB(200, 50, 50),
	text = Color3.fromRGB(255, 255, 255),
	textDim = Color3.fromRGB(160, 170, 200),
	textMuted = Color3.fromRGB(100, 110, 140),
}

local OUTCOME_COLORS = {
	perfect = COLORS.perfect,
	partial = COLORS.partial,
	wrong = COLORS.wrong,
}

-- ============================================
-- UI FACTORY HELPERS
-- ============================================

local function createLabel(props)
	local label = Instance.new("TextLabel")
	label.Name = props.name or "Label"
	label.Size = props.size or UDim2.new(1, 0, 0, 24)
	label.Position = props.position or UDim2.new(0, 0, 0, 0)
	label.AnchorPoint = props.anchorPoint or Vector2.new(0, 0)
	label.BackgroundTransparency = 1
	label.Text = props.text or ""
	label.TextColor3 = props.textColor or COLORS.text
	label.TextSize = props.textSize or 16
	label.Font = props.font or Enum.Font.GothamMedium
	label.TextXAlignment = props.xAlign or Enum.TextXAlignment.Center
	label.TextYAlignment = props.yAlign or Enum.TextYAlignment.Center
	label.TextWrapped = props.wrapped or false
	label.LineHeight = props.lineHeight or 1
	label.TextTransparency = 1
	label.Parent = props.parent
	return label
end

local function createCard(props)
	local card = Instance.new("Frame")
	card.Name = props.name or "Card"
	card.Size = props.size or UDim2.new(0.5, 0, 0.5, 0)
	card.Position = props.position or UDim2.new(0.5, 0, 0.5, 0)
	card.AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = props.color or COLORS.card
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.Parent = props.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, props.cornerRadius or 20)
	corner.Parent = card

	if props.padding then
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, props.padding)
		pad.PaddingBottom = UDim.new(0, props.padding)
		pad.PaddingLeft = UDim.new(0, props.padding)
		pad.PaddingRight = UDim.new(0, props.padding)
		pad.Parent = card
	end

	local stroke = nil
	if props.stroke then
		stroke = Instance.new("UIStroke")
		stroke.Color = props.strokeColor or COLORS.accent
		stroke.Transparency = props.strokeTransparency or 0.7
		stroke.Thickness = props.strokeThickness or 2
		stroke.Parent = card
	end

	return card, stroke
end

local function fadeElements(elements, targetTransparency, duration)
	for _, el in ipairs(elements) do
		if el:IsA("TextLabel") or el:IsA("TextButton") then
			if el:IsA("TextButton") then
				TweenService:Create(el, TweenInfo.new(duration), {BackgroundTransparency = targetTransparency}):Play()
			end
			TweenService:Create(el, TweenInfo.new(duration), {TextTransparency = targetTransparency}):Play()
		elseif el:IsA("Frame") then
			TweenService:Create(el, TweenInfo.new(duration), {BackgroundTransparency = targetTransparency}):Play()
		elseif el:IsA("UIStroke") then
			TweenService:Create(el, TweenInfo.new(duration), {Transparency = targetTransparency == 0 and 0.7 or 1}):Play()
		end
	end
end

-- ============================================
-- PHASE 1: SCENARIO SELECTION
-- ============================================

local function runSelectionPhase(bg)
	local chooseTitle = createLabel({
		name = "ChooseTitle", parent = bg,
		size = UDim2.new(0.6, 0, 0, 36),
		position = UDim2.new(0.5, 0, 0.1, 0),
		anchorPoint = Vector2.new(0.5, 0),
		text = "CHOOSE YOUR CHALLENGE",
		textColor = COLORS.accent, textSize = 28,
		font = Enum.Font.GothamBold,
	})

	local chooseSubtitle = createLabel({
		name = "ChooseSubtitle", parent = bg,
		size = UDim2.new(0.6, 0, 0, 24),
		position = UDim2.new(0.5, 0, 0.17, 0),
		anchorPoint = Vector2.new(0.5, 0),
		text = "Pick a scenario — your choice determines the outcome!",
		textColor = COLORS.textDim, textSize = 16,
	})

	local cardsContainer = Instance.new("Frame")
	cardsContainer.Name = "Cards"
	cardsContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	cardsContainer.Size = UDim2.new(0.7, 0, 0.5, 0)
	cardsContainer.Position = UDim2.new(0.5, 0, 0.52, 0)
	cardsContainer.BackgroundTransparency = 1
	cardsContainer.Parent = bg

	local cardsLayout = Instance.new("UIListLayout")
	cardsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardsLayout.FillDirection = Enum.FillDirection.Horizontal
	cardsLayout.Padding = UDim.new(0, 24)
	cardsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	cardsLayout.Parent = cardsContainer

	local selectedScenario = nil
	local scenarioCards = {}

	for i, scenario in ipairs(SCENARIOS) do
		local sCard = Instance.new("TextButton")
		sCard.Name = "ScenarioCard_" .. i
		sCard.Size = UDim2.new(0.46, 0, 0.85, 0)
		sCard.LayoutOrder = i
		sCard.BackgroundColor3 = COLORS.card
		sCard.BorderSizePixel = 0
		sCard.Text = ""
		sCard.AutoButtonColor = false
		sCard.BackgroundTransparency = 1
		sCard.Parent = cardsContainer

		local sCorner = Instance.new("UICorner")
		sCorner.CornerRadius = UDim.new(0, 20)
		sCorner.Parent = sCard

		local sStroke = Instance.new("UIStroke")
		sStroke.Color = COLORS.accent
		sStroke.Transparency = 0.7
		sStroke.Thickness = 2
		sStroke.Parent = sCard

		local sPadding = Instance.new("UIPadding")
		sPadding.PaddingTop = UDim.new(0, 28)
		sPadding.PaddingBottom = UDim.new(0, 28)
		sPadding.PaddingLeft = UDim.new(0, 28)
		sPadding.PaddingRight = UDim.new(0, 28)
		sPadding.Parent = sCard

		local sNumber = createLabel({
			name = "Number", parent = sCard,
			size = UDim2.new(0, 40, 0, 40),
			text = tostring(i),
			textColor = COLORS.accent, textSize = 22,
			font = Enum.Font.GothamBold,
		})
		sNumber.BackgroundColor3 = COLORS.accent
		sNumber.BackgroundTransparency = 0.8
		local sNumCorner = Instance.new("UICorner")
		sNumCorner.CornerRadius = UDim.new(0, 10)
		sNumCorner.Parent = sNumber

		local sTitle = createLabel({
			name = "Title", parent = sCard,
			size = UDim2.new(1, 0, 0, 34),
			position = UDim2.new(0, 0, 0, 52),
			text = scenario.cardTitle,
			textSize = 24, font = Enum.Font.GothamBold,
			xAlign = Enum.TextXAlignment.Left, wrapped = true,
		})

		local sDesc = createLabel({
			name = "Desc", parent = sCard,
			size = UDim2.new(1, 0, 0, 40),
			position = UDim2.new(0, 0, 0, 92),
			text = scenario.cardDesc,
			textColor = COLORS.textDim, textSize = 16,
			xAlign = Enum.TextXAlignment.Left, wrapped = true,
		})

		local sHint = createLabel({
			name = "Hint", parent = sCard,
			anchorPoint = Vector2.new(0.5, 1),
			size = UDim2.new(1, 0, 0, 20),
			position = UDim2.new(0.5, 0, 1, 0),
			text = "CLICK TO PLAY",
			textColor = COLORS.accent, textSize = 13,
			font = Enum.Font.GothamBold,
		})

		sCard.MouseEnter:Connect(function()
			if selectedScenario then return end
			TweenService:Create(sCard, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.cardHover}):Play()
			TweenService:Create(sStroke, TweenInfo.new(0.2), {Transparency = 0.2, Color = COLORS.accentGlow}):Play()
		end)
		sCard.MouseLeave:Connect(function()
			if selectedScenario then return end
			TweenService:Create(sCard, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.card}):Play()
			TweenService:Create(sStroke, TweenInfo.new(0.2), {Transparency = 0.7, Color = COLORS.accent}):Play()
		end)
		sCard.MouseButton1Click:Connect(function()
			if selectedScenario then return end
			selectedScenario = scenario
		end)

		scenarioCards[i] = {
			card = sCard, stroke = sStroke, number = sNumber,
			title = sTitle, desc = sDesc, hint = sHint,
		}
	end

	-- Staggered fade in
	TweenService:Create(chooseTitle, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
	task.wait(0.2)
	TweenService:Create(chooseSubtitle, TweenInfo.new(0.4), {TextTransparency = 0}):Play()

	for i, sc in ipairs(scenarioCards) do
		task.delay(0.3 + (i * 0.15), function()
			TweenService:Create(sc.card, TweenInfo.new(0.4), {BackgroundTransparency = 0}):Play()
			TweenService:Create(sc.stroke, TweenInfo.new(0.4), {Transparency = 0.7}):Play()
			TweenService:Create(sc.number, TweenInfo.new(0.4), {TextTransparency = 0, BackgroundTransparency = 0.8}):Play()
			TweenService:Create(sc.title, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
			TweenService:Create(sc.desc, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
			TweenService:Create(sc.hint, TweenInfo.new(0.4), {TextTransparency = 0.3}):Play()
		end)
	end

	while not selectedScenario do
		task.wait(0.05)
	end

	-- Fade out
	TweenService:Create(chooseTitle, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
	TweenService:Create(chooseSubtitle, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
	for _, sc in ipairs(scenarioCards) do
		TweenService:Create(sc.card, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
		TweenService:Create(sc.stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
		TweenService:Create(sc.number, TweenInfo.new(0.3), {TextTransparency = 1, BackgroundTransparency = 1}):Play()
		TweenService:Create(sc.title, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		TweenService:Create(sc.desc, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		TweenService:Create(sc.hint, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
	end
	task.wait(0.4)

	chooseTitle:Destroy()
	chooseSubtitle:Destroy()
	cardsContainer:Destroy()

	return selectedScenario
end

-- ============================================
-- PHASE 2: SCENARIO CHOICES
-- ============================================

local function runChoicePhase(bg, scenario)
	local scenCard, _ = createCard({
		name = "ScenarioCard", parent = bg,
		size = UDim2.new(0.58, 0, 0.75, 0),
		position = UDim2.new(0.5, 0, 0.48, 0),
		cornerRadius = 24, padding = 28,
	})
	-- Override asymmetric padding
	local existingPad = scenCard:FindFirstChildOfClass("UIPadding")
	if existingPad then
		existingPad.PaddingLeft = UDim.new(0, 32)
		existingPad.PaddingRight = UDim.new(0, 32)
	end

	local scenTitle = createLabel({
		name = "Title", parent = scenCard,
		size = UDim2.new(1, 0, 0, 28),
		text = scenario.cardTitle,
		textColor = COLORS.accent, textSize = 20,
		font = Enum.Font.GothamBold,
		xAlign = Enum.TextXAlignment.Left,
	})

	local sitLabel = createLabel({
		name = "Situation", parent = scenCard,
		size = UDim2.new(1, 0, 0, 60),
		position = UDim2.new(0, 0, 0, 38),
		text = scenario.situation,
		textSize = 17, font = Enum.Font.Gotham,
		xAlign = Enum.TextXAlignment.Left,
		yAlign = Enum.TextYAlignment.Top,
		wrapped = true, lineHeight = 1.35,
	})

	local whatLabel = createLabel({
		name = "WhatDo", parent = scenCard,
		size = UDim2.new(1, 0, 0, 26),
		position = UDim2.new(0, 0, 0, 108),
		text = "What do you do?",
		textColor = COLORS.accentGlow, textSize = 18,
		font = Enum.Font.GothamBold,
		xAlign = Enum.TextXAlignment.Left,
	})

	local choiceBtnContainer = Instance.new("Frame")
	choiceBtnContainer.Name = "Choices"
	choiceBtnContainer.Size = UDim2.new(1, 0, 0.48, 0)
	choiceBtnContainer.Position = UDim2.new(0, 0, 0, 144)
	choiceBtnContainer.BackgroundTransparency = 1
	choiceBtnContainer.Parent = scenCard

	local choiceLayout = Instance.new("UIListLayout")
	choiceLayout.SortOrder = Enum.SortOrder.LayoutOrder
	choiceLayout.Padding = UDim.new(0, 10)
	choiceLayout.FillDirection = Enum.FillDirection.Vertical
	choiceLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	choiceLayout.Parent = choiceBtnContainer

	local playerChoice = nil
	local choiceButtons = {}

	for i, choice in ipairs(scenario.choices) do
		local cBtn = Instance.new("TextButton")
		cBtn.Name = "Choice_" .. i
		cBtn.Size = UDim2.new(1, 0, 0, 48)
		cBtn.LayoutOrder = i
		cBtn.BackgroundColor3 = COLORS.choiceBtn
		cBtn.BorderSizePixel = 0
		cBtn.Text = ""
		cBtn.AutoButtonColor = false
		cBtn.BackgroundTransparency = 1
		cBtn.Parent = choiceBtnContainer

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 12)
		cCorner.Parent = cBtn

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = COLORS.accent
		cStroke.Transparency = 1
		cStroke.Thickness = 1.5
		cStroke.Parent = cBtn

		local cLabel = createLabel({
			name = "Label", parent = cBtn,
			size = UDim2.new(1, -24, 1, 0),
			position = UDim2.new(0, 12, 0, 0),
			text = choice.text,
			textSize = 15, xAlign = Enum.TextXAlignment.Left,
			wrapped = true,
		})

		cBtn.MouseEnter:Connect(function()
			if playerChoice then return end
			TweenService:Create(cBtn, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.choiceBtnHover}):Play()
			TweenService:Create(cStroke, TweenInfo.new(0.15), {Transparency = 0.3}):Play()
		end)
		cBtn.MouseLeave:Connect(function()
			if playerChoice then return end
			TweenService:Create(cBtn, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.choiceBtn}):Play()
			TweenService:Create(cStroke, TweenInfo.new(0.15), {Transparency = 0.7}):Play()
		end)
		cBtn.MouseButton1Click:Connect(function()
			if playerChoice then return end
			playerChoice = choice
		end)

		choiceButtons[i] = { btn = cBtn, stroke = cStroke, label = cLabel, data = choice }
	end

	-- Staggered fade in
	TweenService:Create(scenCard, TweenInfo.new(0.4), {BackgroundTransparency = 0}):Play()
	task.wait(0.2)
	TweenService:Create(scenTitle, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
	task.wait(0.15)
	TweenService:Create(sitLabel, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	task.wait(0.4)
	TweenService:Create(whatLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()

	for i, cb in ipairs(choiceButtons) do
		task.delay(0.1 * i, function()
			TweenService:Create(cb.btn, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
			TweenService:Create(cb.stroke, TweenInfo.new(0.3), {Transparency = 0.7}):Play()
			TweenService:Create(cb.label, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
		end)
	end

	while not playerChoice do
		task.wait(0.05)
	end

	-- Highlight chosen, dim others
	for _, cb in ipairs(choiceButtons) do
		local outcomeColor = OUTCOME_COLORS[cb.data.color] or COLORS.accent
		if cb.data == playerChoice then
			TweenService:Create(cb.btn, TweenInfo.new(0.3), {BackgroundColor3 = outcomeColor}):Play()
			cb.stroke.Color = outcomeColor
			cb.stroke.Transparency = 0
		else
			TweenService:Create(cb.btn, TweenInfo.new(0.3), {BackgroundTransparency = 0.7}):Play()
			TweenService:Create(cb.label, TweenInfo.new(0.3), {TextTransparency = 0.6}):Play()
		end
	end

	task.wait(1)

	-- Fade out
	fadeElements({scenTitle, sitLabel, whatLabel}, 1, 0.3)
	for _, cb in ipairs(choiceButtons) do
		TweenService:Create(cb.btn, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
		TweenService:Create(cb.stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
		TweenService:Create(cb.label, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
	end
	task.wait(0.4)

	choiceBtnContainer:Destroy()
	scenTitle.Visible = false
	sitLabel.Visible = false
	whatLabel.Visible = false

	return playerChoice, scenCard
end

-- ============================================
-- PHASE 3: OUTCOME DISPLAY
-- ============================================

local function runOutcomePhase(scenCard, choice)
	local outcomeColor = OUTCOME_COLORS[choice.color] or COLORS.accent
	local finalScore = choice.score

	local outcomeTitle = createLabel({
		name = "OutcomeTitle", parent = scenCard,
		anchorPoint = Vector2.new(0.5, 0),
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.new(0.5, 0, 0.08, 0),
		text = choice.outcome,
		textColor = outcomeColor, textSize = 32,
		font = Enum.Font.GothamBold,
	})

	local outcomeDetail = createLabel({
		name = "OutcomeDetail", parent = scenCard,
		anchorPoint = Vector2.new(0.5, 0),
		size = UDim2.new(0.9, 0, 0, 80),
		position = UDim2.new(0.5, 0, 0.28, 0),
		text = choice.detail,
		textSize = 17, font = Enum.Font.Gotham,
		wrapped = true, lineHeight = 1.4,
	})

	local outcomeScore = createLabel({
		name = "OutcomeScore", parent = scenCard,
		anchorPoint = Vector2.new(0.5, 0),
		size = UDim2.new(1, 0, 0, 50),
		position = UDim2.new(0.5, 0, 0.58, 0),
		text = finalScore .. " / 100",
		textColor = outcomeColor, textSize = 44,
		font = Enum.Font.GothamBold,
	})

	local gradeText
	if finalScore == 100 then
		gradeText = "You made the safest choice possible!"
	elseif finalScore == 50 then
		gradeText = "Not bad, but there was a better option."
	else
		gradeText = "This is how cyber attacks happen. Stay alert!"
	end

	local outcomeGrade = createLabel({
		name = "OutcomeGrade", parent = scenCard,
		anchorPoint = Vector2.new(0.5, 0),
		size = UDim2.new(1, 0, 0, 24),
		position = UDim2.new(0.5, 0, 0.72, 0),
		text = gradeText,
		textColor = COLORS.textDim, textSize = 15,
	})

	-- Staggered fade in
	TweenService:Create(outcomeTitle, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	task.wait(0.4)
	TweenService:Create(outcomeDetail, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	task.wait(0.5)
	TweenService:Create(outcomeScore, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
	task.wait(0.3)
	TweenService:Create(outcomeGrade, TweenInfo.new(0.4), {TextTransparency = 0}):Play()

	GameState:SetScore("Cyber", 3, finalScore)

	task.wait(3.5)

	-- Fade out card + labels
	TweenService:Create(scenCard, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
	fadeElements({outcomeTitle, outcomeDetail, outcomeScore, outcomeGrade}, 1, 0.4)
	task.wait(0.5)

	return finalScore
end

-- ============================================
-- MAIN PLAY ORCHESTRATOR
-- ============================================

function DecisionGame.Play()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DecisionGame"
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

	local selectedScenario = runSelectionPhase(bg)
	print("DecisionGame: Player chose: " .. selectedScenario.cardTitle)

	local playerChoice, scenCard = runChoicePhase(bg, selectedScenario)
	print("DecisionGame: Player chose: " .. playerChoice.text)

	local finalScore = runOutcomePhase(scenCard, playerChoice)

	gui:Destroy()
	print("DecisionGame: Complete! Score: " .. finalScore .. "/100")
	return finalScore
end

return DecisionGame
