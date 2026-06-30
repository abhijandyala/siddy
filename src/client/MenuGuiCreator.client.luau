-- MenuGuiCreator.client.luau
-- Builds the VOCA title menu overlay. Background camera is handled by
-- MenuBackground.client.luau using workspace.EndRoom.CamPos.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")
local GS         = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameSettings"))

if playerGui:FindFirstChild("MenuGui") then
	print("MenuGuiCreator: MenuGui already exists, skipping creation")
	return
end

print("MenuGuiCreator: Creating EndRoom title menu...")

local COLORS = {
	ink = Color3.fromRGB(245, 248, 255),
	muted = Color3.fromRGB(184, 196, 218),
	panel = Color3.fromRGB(8, 12, 24),
	panelSoft = Color3.fromRGB(16, 22, 38),
	stroke = Color3.fromRGB(145, 178, 220),
	aviation = Color3.fromRGB(108, 195, 255),
	chef = Color3.fromRGB(255, 224, 139),
	nurse = Color3.fromRGB(174, 255, 178),
	cyber = Color3.fromRGB(236, 168, 255),
	button = Color3.fromRGB(238, 242, 248),
	buttonText = Color3.fromRGB(16, 24, 38),
}

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "CleanStroke"
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0.35
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Bevel
	stroke.Parent = parent
	return stroke
end

local function addPadding(parent, px)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, px)
	padding.PaddingRight = UDim.new(0, px)
	padding.PaddingBottom = UDim.new(0, px)
	padding.PaddingLeft = UDim.new(0, px)
	padding.Parent = parent
	return padding
end

local function createButton(name, text, parent, order, accent)
	local button = Instance.new("TextButton")
	button.Name = name
	button.LayoutOrder = order
	button.Size = UDim2.new(0, 210, 0, 56)
	button.BackgroundColor3 = COLORS.button
	button.BackgroundTransparency = 0.05
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = COLORS.buttonText
	button.TextSize = 17
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = false
	button.Parent = parent
	addCorner(button, 14)
	addStroke(button, accent, 1.4, 0.42)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 220, 232)),
	})
	gradient.Rotation = 90
	gradient.Parent = button

	return button
end

local function createPanel(name, title, height)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.new(0.88, 0, 0, height)
	frame.Position = UDim2.new(0.5, 0, 0.54, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = COLORS.panel
	frame.BackgroundTransparency = 0.18
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = nil
	addCorner(frame, 22)
	addStroke(frame, COLORS.stroke, 1.5, 0.45)
	addPadding(frame, 28)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 42)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = COLORS.ink
	titleLabel.TextSize = 32
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Parent = frame

	return frame
end

local menuGui = Instance.new("ScreenGui")
menuGui.Name = "MenuGui"
menuGui.ResetOnSpawn = false
menuGui.IgnoreGuiInset = true
menuGui.DisplayOrder = 200
menuGui.Parent = playerGui

local menuFrame = Instance.new("Frame")
menuFrame.Name = "MenuFrame"
menuFrame.Size = UDim2.fromScale(1, 1)
menuFrame.BackgroundTransparency = 1
menuFrame.BorderSizePixel = 0
menuFrame.Visible = true
menuFrame.Parent = menuGui

local titleGroup = Instance.new("Frame")
titleGroup.Name = "TitleGroup"
titleGroup.Size = UDim2.new(0, 760, 0, 150)
titleGroup.Position = UDim2.new(0.5, 0, 0.13, 0)
titleGroup.AnchorPoint = Vector2.new(0.5, 0.5)
titleGroup.BackgroundTransparency = 1
titleGroup.Parent = menuFrame

local title = Instance.new("TextLabel")
title.Name = "TitleLabel"
title.Size = UDim2.new(1, 0, 0, 82)
title.BackgroundTransparency = 1
title.RichText = true
title.Text = 'V<font color="rgb(190,160,220)">O</font>CA'
title.TextColor3 = COLORS.ink
title.TextSize = 76
title.Font = Enum.Font.GothamBlack
title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
title.TextStrokeTransparency = 0.62
title.Parent = titleGroup

local titleStroke = Instance.new("UIStroke")
titleStroke.Name = "TitleGlow"
titleStroke.Color = Color3.fromRGB(180, 218, 255)
titleStroke.Thickness = 1.4
titleStroke.Transparency = 0.52
titleStroke.LineJoinMode = Enum.LineJoinMode.Bevel
titleStroke.Parent = title

local subtitle = Instance.new("TextLabel")
subtitle.Name = "SubtitleLabel"
subtitle.Size = UDim2.new(1, 0, 0, 26)
subtitle.Position = UDim2.new(0, 0, 0, 82)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Computer Game & Simulation Programming"
subtitle.TextColor3 = COLORS.muted
subtitle.TextSize = 16
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextTransparency = 0.02
subtitle.Parent = titleGroup

local accentRow = Instance.new("Frame")
accentRow.Name = "CareerAccentRow"
accentRow.Size = UDim2.new(0, 250, 0, 4)
accentRow.Position = UDim2.new(0.5, 0, 0, 122)
accentRow.AnchorPoint = Vector2.new(0.5, 0)
accentRow.BackgroundTransparency = 1
accentRow.Parent = titleGroup

local accentLayout = Instance.new("UIListLayout")
accentLayout.FillDirection = Enum.FillDirection.Horizontal
accentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
accentLayout.Padding = UDim.new(0, 10)
accentLayout.Parent = accentRow

for index, color in ipairs({ COLORS.aviation, COLORS.chef, COLORS.nurse, COLORS.cyber }) do
	local bar = Instance.new("Frame")
	bar.Name = "Accent" .. index
	bar.Size = UDim2.new(0, 48, 0, 4)
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	bar.LayoutOrder = index
	bar.Parent = accentRow
	addCorner(bar, 999)
end

local buttonDock = Instance.new("Frame")
buttonDock.Name = "ButtonDock"
buttonDock.Size = UDim2.new(0, 720, 0, 92)
buttonDock.Position = UDim2.new(0.5, 0, 1, -78)
buttonDock.AnchorPoint = Vector2.new(0.5, 1)
buttonDock.BackgroundColor3 = Color3.fromRGB(5, 8, 16)
buttonDock.BackgroundTransparency = 0.18
buttonDock.BorderSizePixel = 0
buttonDock.Parent = menuFrame
addCorner(buttonDock, 24)
addStroke(buttonDock, Color3.fromRGB(150, 170, 205), 1.2, 0.62)
addPadding(buttonDock, 18)

local dockLayout = Instance.new("UIListLayout")
dockLayout.FillDirection = Enum.FillDirection.Horizontal
dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
dockLayout.SortOrder = Enum.SortOrder.LayoutOrder
dockLayout.Padding = UDim.new(0, 18)
dockLayout.Parent = buttonDock

local tutBtn = createButton("TutorialButton", GS:t("tutorial"), buttonDock, 1, COLORS.chef)
local playBtn = createButton("PlayButton",     GS:t("play"),     buttonDock, 2, COLORS.aviation)
local setBtn  = createButton("SettingsButton", GS:t("settings"), buttonDock, 3, COLORS.cyber)

local hint = Instance.new("TextLabel")
hint.Name = "HintLabel"
hint.Size = UDim2.new(1, 0, 0, 18)
hint.Position = UDim2.new(0, 0, 1, -22)
hint.BackgroundTransparency = 1
hint.Text = "Explore four careers. Complete challenges. Discover your path."
hint.TextColor3 = Color3.fromRGB(210, 220, 235)
hint.TextTransparency = 0.26
hint.TextSize = 13
hint.Font = Enum.Font.GothamMedium
hint.Parent = menuFrame

local tutorialFrame = createPanel("TutorialFrame", "HOW TO PLAY", 500)
tutorialFrame.Parent = menuGui

local tutorialScroll = Instance.new("ScrollingFrame")
tutorialScroll.Name = "ContentScroll"
tutorialScroll.Size = UDim2.new(1, 0, 1, -120)
tutorialScroll.Position = UDim2.new(0, 0, 0, 64)
tutorialScroll.BackgroundTransparency = 1
tutorialScroll.BorderSizePixel = 0
tutorialScroll.ScrollBarThickness = 4
tutorialScroll.ScrollBarImageColor3 = COLORS.aviation
tutorialScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
tutorialScroll.CanvasSize = UDim2.new()
tutorialScroll.Parent = tutorialFrame

local tutorialLayout = Instance.new("UIListLayout")
tutorialLayout.SortOrder = Enum.SortOrder.LayoutOrder
tutorialLayout.Padding = UDim.new(0, 14)
tutorialLayout.Parent = tutorialScroll

local function createInfoCard(parent, order, heading, body, accent)
	local card = Instance.new("Frame")
	card.Name = heading:gsub("%s+", "") .. "Card"
	card.Size = UDim2.new(1, -8, 0, 92)
	card.BackgroundColor3 = COLORS.panelSoft
	card.BackgroundTransparency = 0.25
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Parent = parent
	addCorner(card, 16)
	addStroke(card, accent, 1, 0.72)

	local cardTitle = Instance.new("TextLabel")
	cardTitle.Size = UDim2.new(1, -28, 0, 26)
	cardTitle.Position = UDim2.new(0, 14, 0, 12)
	cardTitle.BackgroundTransparency = 1
	cardTitle.Text = heading
	cardTitle.TextColor3 = accent
	cardTitle.TextSize = 16
	cardTitle.Font = Enum.Font.GothamBold
	cardTitle.TextXAlignment = Enum.TextXAlignment.Left
	cardTitle.Parent = card

	local cardBody = Instance.new("TextLabel")
	cardBody.Size = UDim2.new(1, -28, 0, 44)
	cardBody.Position = UDim2.new(0, 14, 0, 40)
	cardBody.BackgroundTransparency = 1
	cardBody.Text = body
	cardBody.TextColor3 = COLORS.muted
	cardBody.TextSize = 14
	cardBody.Font = Enum.Font.Gotham
	cardBody.TextWrapped = true
	cardBody.TextXAlignment = Enum.TextXAlignment.Left
	cardBody.TextYAlignment = Enum.TextYAlignment.Top
	cardBody.Parent = card
end

createInfoCard(tutorialScroll, 1, "CONTROLS", "WASD to move, mouse to look, E to interact, and follow each career's on-screen prompts.", COLORS.aviation)
createInfoCard(tutorialScroll, 2, "CAREER PATHS", "Aviation, Culinary Arts, Healthcare, and Cybersecurity each include fast hands-on tasks.", COLORS.nurse)
createInfoCard(tutorialScroll, 3, "GOAL", "Finish every station and build the highest career readiness score you can.", COLORS.chef)

local tutBack = createButton("BackButton", "BACK", tutorialFrame, 1, COLORS.aviation)
tutBack.Size = UDim2.new(0, 200, 0, 52)
tutBack.Position = UDim2.new(0.5, -100, 1, -35)
tutBack.AnchorPoint = Vector2.new(0, 0)

----------------------------------------------------------------------
-- SETTINGS FRAME (fully functional)
----------------------------------------------------------------------
local settingsFrame = Instance.new("Frame")
settingsFrame.Name = "SettingsFrame"
settingsFrame.Size = UDim2.new(0.88, 0, 0, 530)
settingsFrame.Position = UDim2.new(0.5, 0, 0.54, 0)
settingsFrame.AnchorPoint = Vector2.new(0.5, 0.5)
settingsFrame.BackgroundColor3 = Color3.fromRGB(8, 12, 26)
settingsFrame.BackgroundTransparency = 0.14
settingsFrame.BorderSizePixel = 0
settingsFrame.Visible = false
settingsFrame.Parent = menuGui
addCorner(settingsFrame, 22)
addStroke(settingsFrame, COLORS.stroke, 1.5, 0.42)

local setHeader = Instance.new("TextLabel")
setHeader.Name = "TitleLabel"
setHeader.Size = UDim2.new(1, -48, 0, 34)
setHeader.Position = UDim2.new(0, 24, 0, 20)
setHeader.BackgroundTransparency = 1
setHeader.Text = GS:t("settings")
setHeader.TextColor3 = COLORS.ink
setHeader.TextSize = 24
setHeader.Font = Enum.Font.GothamBlack
setHeader.TextXAlignment = Enum.TextXAlignment.Left
setHeader.Parent = settingsFrame

local setDivider = Instance.new("Frame")
setDivider.Size = UDim2.new(1, -48, 0, 1)
setDivider.Position = UDim2.new(0, 24, 0, 62)
setDivider.BackgroundColor3 = COLORS.stroke
setDivider.BackgroundTransparency = 0.55
setDivider.BorderSizePixel = 0
setDivider.Parent = settingsFrame

-- Scrollable content area
local setScroll = Instance.new("ScrollingFrame")
setScroll.Name = "ContentFrame"
setScroll.Size = UDim2.new(1, -48, 0, 390)
setScroll.Position = UDim2.new(0, 24, 0, 74)
setScroll.BackgroundTransparency = 1
setScroll.BorderSizePixel = 0
setScroll.ScrollBarThickness = 3
setScroll.ScrollBarImageColor3 = COLORS.stroke
setScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
setScroll.CanvasSize = UDim2.new()
setScroll.Parent = settingsFrame

local setList = Instance.new("UIListLayout")
setList.SortOrder = Enum.SortOrder.LayoutOrder
setList.Padding = UDim.new(0, 8)
setList.Parent = setScroll

-- ── Helpers ───────────────────────────────────────────────────────
-- A11y targets: rows ≥ 72px, chips ≥ 44px, arrows ≥ 44px touch target

local UNSEL_BG  = Color3.fromRGB(20, 26, 48)
local UNSEL_TXT = Color3.fromRGB(200, 210, 228)  -- higher contrast than muted

-- Creates a labelled row frame
local function makeRow(order, icon, labelText, accent, rowH)
	rowH = rowH or 72
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, rowH)
	row.BackgroundColor3 = Color3.fromRGB(16, 22, 44)
	row.BackgroundTransparency = 0.30
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Parent = setScroll
	addCorner(row, 14)
	addStroke(row, accent, 1.2, 0.72)

	local iconL = Instance.new("TextLabel")
	iconL.Size = UDim2.new(0, 34, 1, 0)
	iconL.Position = UDim2.new(0, 14, 0, 0)
	iconL.BackgroundTransparency = 1
	iconL.Text = icon
	iconL.TextColor3 = accent
	iconL.TextSize = 20
	iconL.Font = Enum.Font.GothamBold
	iconL.TextXAlignment = Enum.TextXAlignment.Center
	iconL.Parent = row

	local lbl = Instance.new("TextLabel")
	lbl.Name = "RowLabel"
	lbl.Size = UDim2.new(0.44, 0, 0, 24)
	lbl.Position = UDim2.new(0, 54, 0.5, -12)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.TextColor3 = COLORS.ink  -- full white for max readability
	lbl.TextSize = 15
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	return row, lbl
end

-- Segmented chip control with proper a11y sizing + hover feedback
local function makeChips(parent, options, defaultIndex, accent, onSelect)
	local CHIP_H = 44
	local CHIP_W = math.max(64, math.floor(240 / #options) - 6)
	local totalW = #options * CHIP_W + (#options - 1) * 6
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0, totalW, 0, CHIP_H)
	container.AnchorPoint = Vector2.new(1, 0.5)
	container.Position = UDim2.new(1, -16, 0.5, 0)
	container.BackgroundTransparency = 1
	container.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = container

	local chips = {}
	local current = defaultIndex

	local function refresh()
		for i, chip in ipairs(chips) do
			local sel = (i == current)
			chip.BackgroundColor3 = sel and accent or UNSEL_BG
			chip.BackgroundTransparency = sel and 0.0 or 0.45
			chip.TextColor3 = sel and Color3.fromRGB(255, 255, 255) or UNSEL_TXT
			chip.TextSize = sel and 15 or 14
		end
	end

	for i, label in ipairs(options) do
		local chip = Instance.new("TextButton")
		chip.Name = "Chip" .. i
		chip.Size = UDim2.new(0, CHIP_W, 0, CHIP_H)
		chip.BackgroundColor3 = UNSEL_BG
		chip.BackgroundTransparency = 0.45
		chip.BorderSizePixel = 0
		chip.Text = label
		chip.TextColor3 = UNSEL_TXT
		chip.TextSize = 14
		chip.Font = Enum.Font.GothamBold
		chip.AutoButtonColor = false
		chip.Parent = container
		addCorner(chip, 10)

		-- Hover feedback
		chip.MouseEnter:Connect(function()
			if i ~= current then chip.BackgroundTransparency = 0.25 end
		end)
		chip.MouseLeave:Connect(function()
			if i ~= current then chip.BackgroundTransparency = 0.45 end
		end)

		local idx = i
		chip.MouseButton1Click:Connect(function()
			current = idx
			refresh()
			onSelect(idx, label)
		end)
		chips[i] = chip
	end
	refresh()

	return function(idx) current = idx; refresh() end
end

-- Volume row: [◀] [value] [▶]  — ◀ on left decreases, ▶ on right increases
local function makeVolumeRow(order, icon, labelTxt, accent, getLabel, onDecrease, onIncrease)
	local row, _ = makeRow(order, icon, labelTxt, accent)

	-- Container keeps the three elements right-aligned as a group
	local ctrl = Instance.new("Frame")
	ctrl.Size = UDim2.new(0, 174, 0, 44)
	ctrl.AnchorPoint = Vector2.new(1, 0.5)
	ctrl.Position = UDim2.new(1, -16, 0.5, 0)
	ctrl.BackgroundTransparency = 1
	ctrl.Parent = row

	local ctrlLayout = Instance.new("UIListLayout")
	ctrlLayout.FillDirection = Enum.FillDirection.Horizontal
	ctrlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	ctrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	ctrlLayout.Padding = UDim.new(0, 6)
	ctrlLayout.Parent = ctrl

	local function makeArrow(text)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 44, 0, 44)
		btn.BackgroundColor3 = Color3.fromRGB(28, 36, 64)
		btn.BackgroundTransparency = 0.20
		btn.BorderSizePixel = 0
		btn.Text = text
		btn.TextColor3 = accent
		btn.TextSize = 18
		btn.Font = Enum.Font.GothamBold
		btn.AutoButtonColor = false
		btn.Parent = ctrl
		addCorner(btn, 10)
		btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0.0 end)
		btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 0.20 end)
		return btn
	end

	local decBtn = makeArrow("◀")  -- decrease, LEFT in the group
	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(0, 68, 0, 44)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = getLabel()
	valLabel.TextColor3 = COLORS.ink
	valLabel.TextSize = 17
	valLabel.Font = Enum.Font.GothamBold
	valLabel.TextXAlignment = Enum.TextXAlignment.Center
	valLabel.Parent = ctrl
	local incBtn = makeArrow("▶")  -- increase, RIGHT in the group

	decBtn.MouseButton1Click:Connect(function() onDecrease(); valLabel.Text = getLabel() end)
	incBtn.MouseButton1Click:Connect(function() onIncrease(); valLabel.Text = getLabel() end)
	return row
end

-- ── ROW 1: Master Volume ──────────────────────────────────────────
local volRow = makeVolumeRow(1, "🔊", GS:t("volume"), COLORS.aviation,
	function() return GS:getMasterVolumeLabel() end,
	function() GS:stepMasterVolume(-1) end,
	function() GS:stepMasterVolume(1)  end)
volRow.Name = "VolumeRow"

-- ── ROW 2: Music Volume ───────────────────────────────────────────
local musRow = makeVolumeRow(2, "🎵", GS:t("music"), COLORS.nurse,
	function() return GS:getMusicVolumeLabel() end,
	function() GS:stepMusicVolume(-1) end,
	function() GS:stepMusicVolume(1)  end)
musRow.Name = "MusicRow"

-- ── ROW 3: Hard Mode ─────────────────────────────────────────────
local hmRow = Instance.new("Frame")
hmRow.Name = "HardModeRow"
hmRow.Size = UDim2.new(1, 0, 0, 88)
hmRow.BackgroundColor3 = Color3.fromRGB(38, 16, 16)
hmRow.BackgroundTransparency = 0.35
hmRow.BorderSizePixel = 0
hmRow.LayoutOrder = 3
hmRow.Parent = setScroll
addCorner(hmRow, 14)
addStroke(hmRow, COLORS.cyber, 1.2, 0.65)

local hmIcon = Instance.new("TextLabel")
hmIcon.Size = UDim2.new(0, 34, 0, 30)
hmIcon.Position = UDim2.new(0, 14, 0, 14)
hmIcon.BackgroundTransparency = 1
hmIcon.Text = "🎯"
hmIcon.TextColor3 = COLORS.cyber
hmIcon.TextSize = 20
hmIcon.Font = Enum.Font.GothamBold
hmIcon.Parent = hmRow

local hmLabel = Instance.new("TextLabel")
hmLabel.Name = "RowLabel"
hmLabel.Size = UDim2.new(0.48, 0, 0, 24)
hmLabel.Position = UDim2.new(0, 54, 0, 12)
hmLabel.BackgroundTransparency = 1
hmLabel.Text = GS:t("hardMode")
hmLabel.TextColor3 = COLORS.ink
hmLabel.TextSize = 15
hmLabel.Font = Enum.Font.GothamMedium
hmLabel.TextXAlignment = Enum.TextXAlignment.Left
hmLabel.Parent = hmRow

local hmDesc = Instance.new("TextLabel")
hmDesc.Name = "HardModeDesc"
hmDesc.Size = UDim2.new(0.72, 0, 0, 32)
hmDesc.Position = UDim2.new(0, 54, 0, 40)
hmDesc.BackgroundTransparency = 1
hmDesc.Text = GS:t("hardModeDesc")
hmDesc.TextColor3 = Color3.fromRGB(200, 150, 150)
hmDesc.TextSize = 12
hmDesc.Font = Enum.Font.Gotham
hmDesc.TextWrapped = true
hmDesc.TextXAlignment = Enum.TextXAlignment.Left
hmDesc.Parent = hmRow

local setHardMode = makeChips(hmRow,
	{ GS:t("off"), GS:t("on") },
	GS.hardMode and 2 or 1,
	COLORS.cyber,
	function(idx) GS:set("hardMode", idx == 2) end)

-- ── ROW 4: Language ───────────────────────────────────────────────
local langRow, langLbl = makeRow(4, "🌐", GS:t("language"), COLORS.chef)
langRow.Name = "LanguageRow"

local langOptions = { "EN", "ES" }
local setLang = makeChips(langRow, langOptions,
	GS.language == "es" and 2 or 1,
	COLORS.chef,
	function(idx)
		GS:set("language", langOptions[idx] == "ES" and "es" or "en")
		setHeader.Text       = GS:t("settings")
		langLbl.Text         = GS:t("language")
		hmLabel.Text         = GS:t("hardMode")
		hmDesc.Text          = GS:t("hardModeDesc")
		tutBtn.Text          = GS:t("tutorial")
		playBtn.Text         = GS:t("play")
		setBtn.Text          = GS:t("settings")
		volRow.RowLabel.Text = GS:t("volume")
		musRow.RowLabel.Text = GS:t("music")
	end)
_ = setLang

-- ── ROW 5: Text Size ──────────────────────────────────────────────
local tsRow, tsLbl = makeRow(5, "Aa", GS:t("textSize"), COLORS.aviation)
tsRow.Name = "TextSizeRow"
_ = tsLbl

local textScales = { 0.85, 1.0, 1.15 }
local function applyTextScale()
	local s = GS.textScale
	-- Dock buttons
	for _, btn in ipairs({ tutBtn, playBtn, setBtn }) do
		btn.TextSize = math.floor(17 * s)
	end
	-- Title area
	subtitle.TextSize = math.floor(16 * s)
	hint.TextSize     = math.floor(13 * s)
	-- Settings panel rows
	for _, row in ipairs(setScroll:GetChildren()) do
		if row:IsA("Frame") then
			local lbl = row:FindFirstChild("RowLabel")
			if lbl then lbl.TextSize = math.floor(15 * s) end
		end
	end
	setHeader.TextSize = math.floor(24 * s)
end

local setTextSize = makeChips(tsRow,
	{ GS:t("small"), GS:t("medium"), GS:t("large") },
	2,
	COLORS.aviation,
	function(idx)
		GS:set("textScale", textScales[idx])
		applyTextScale()
	end)
_ = setTextSize

-- ── ROW 6: Graphics ───────────────────────────────────────────────
local grRow, _ = makeRow(6, "◈", GS:t("graphics"), COLORS.nurse)
grRow.Name = "GraphicsRow"

local setGraphics = makeChips(grRow,
	{ GS:t("high"), GS:t("low") },
	GS.graphics == "low" and 2 or 1,
	COLORS.nurse,
	function(idx) GS:set("graphics", idx == 2 and "low" or "high") end)
_ = setGraphics

-- ── BACK BUTTON ───────────────────────────────────────────────────
local setBack = createButton("BackButton", GS:t("back"), settingsFrame, 1, COLORS.cyber)
setBack.Size = UDim2.new(0, 200, 0, 52)
setBack.Position = UDim2.new(0.5, -100, 1, -66)
setBack.AnchorPoint = Vector2.new(0, 0)

print("MenuGuiCreator: EndRoom title menu created successfully")
