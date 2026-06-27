-- MenuGuiCreator.client.luau
-- Creates the MenuGui with all frames and buttons if it doesn't exist
-- Must run BEFORE MenuController

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Check if MenuGui already exists (from Studio)
if playerGui:FindFirstChild("MenuGui") then
	print("MenuGuiCreator: MenuGui already exists, skipping creation")
	return
end

print("MenuGuiCreator: Creating MenuGui from scratch...")

--------------------------------------------------------------
-- DESIGN CONSTANTS
--------------------------------------------------------------
local COLORS = {
	bg = Color3.fromRGB(8, 14, 28),
	cardBg = Color3.fromRGB(12, 20, 40),
	border = Color3.fromRGB(45, 85, 160),
	borderGlow = Color3.fromRGB(70, 130, 220),
	buttonBg = Color3.fromRGB(235, 238, 245),
	buttonText = Color3.fromRGB(15, 25, 45),
	titleText = Color3.fromRGB(255, 255, 255),
	bodyText = Color3.fromRGB(190, 195, 210),
	accent = Color3.fromRGB(100, 180, 255),
	accentGreen = Color3.fromRGB(120, 220, 160),
}

--------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------
local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or COLORS.border
	stroke.Thickness = thickness or 2
	stroke.Transparency = 0.3
	stroke.Parent = parent
	return stroke
end

local function createButton(name, text, parent, position)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(0.65, 0, 0, 65)
	button.Position = position
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.BackgroundColor3 = COLORS.buttonBg
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = COLORS.buttonText
	button.TextSize = 20
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = false
	button.Parent = parent
	
	addCorner(button, 8)
	
	return button
end

--------------------------------------------------------------
-- CREATE MENUGUI
--------------------------------------------------------------
local menuGui = Instance.new("ScreenGui")
menuGui.Name = "MenuGui"
menuGui.ResetOnSpawn = false
menuGui.IgnoreGuiInset = true
menuGui.DisplayOrder = 200
menuGui.Parent = playerGui

--------------------------------------------------------------
-- MENUFRAME (Main menu with Play, Tutorial, Settings)
--------------------------------------------------------------
local menuFrame = Instance.new("Frame")
menuFrame.Name = "MenuFrame"
menuFrame.Size = UDim2.new(0, 650, 0, 500)
menuFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
menuFrame.AnchorPoint = Vector2.new(0.5, 0.5)
menuFrame.BackgroundColor3 = COLORS.cardBg
menuFrame.BackgroundTransparency = 0.15
menuFrame.BorderSizePixel = 0
menuFrame.Visible = true
menuFrame.Parent = menuGui

addCorner(menuFrame, 14)
addStroke(menuFrame, COLORS.border, 2.5)

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, 0, 0, 90)
titleLabel.Position = UDim2.new(0, 0, 0, 45)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Career Exploration"
titleLabel.TextColor3 = COLORS.titleText
titleLabel.TextSize = 52
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.Parent = menuFrame

-- Buttons
local playButton = createButton("PlayButton", "PLAY", menuFrame, UDim2.new(0.5, 0, 0, 160))
local tutorialButton = createButton("TutorialButton", "TUTORIAL", menuFrame, UDim2.new(0.5, 0, 0, 245))
local settingsButton = createButton("SettingsButton", "SETTINGS", menuFrame, UDim2.new(0.5, 0, 0, 330))

--------------------------------------------------------------
-- TUTORIALFRAME
--------------------------------------------------------------
local tutorialFrame = Instance.new("Frame")
tutorialFrame.Name = "TutorialFrame"
tutorialFrame.Size = UDim2.new(0, 650, 0, 500)
tutorialFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
tutorialFrame.AnchorPoint = Vector2.new(0.5, 0.5)
tutorialFrame.BackgroundColor3 = COLORS.cardBg
tutorialFrame.BackgroundTransparency = 0.15
tutorialFrame.BorderSizePixel = 0
tutorialFrame.Visible = false
tutorialFrame.Parent = menuGui

addCorner(tutorialFrame, 14)
addStroke(tutorialFrame, COLORS.border, 2.5)

-- Tutorial Title
local tutorialTitle = Instance.new("TextLabel")
tutorialTitle.Name = "TitleLabel"
tutorialTitle.Size = UDim2.new(1, 0, 0, 60)
tutorialTitle.Position = UDim2.new(0, 0, 0, 22)
tutorialTitle.BackgroundTransparency = 1
tutorialTitle.Text = "HOW TO PLAY"
tutorialTitle.TextColor3 = COLORS.titleText
tutorialTitle.TextSize = 36
tutorialTitle.Font = Enum.Font.GothamBlack
tutorialTitle.Parent = tutorialFrame

-- Scrolling Content Area
local tutorialScroll = Instance.new("ScrollingFrame")
tutorialScroll.Name = "ContentScroll"
tutorialScroll.Size = UDim2.new(0.92, 0, 0, 310)
tutorialScroll.Position = UDim2.new(0.5, 0, 0, 85)
tutorialScroll.AnchorPoint = Vector2.new(0.5, 0)
tutorialScroll.BackgroundTransparency = 1
tutorialScroll.BorderSizePixel = 0
tutorialScroll.ScrollBarThickness = 4
tutorialScroll.ScrollBarImageColor3 = COLORS.accent
tutorialScroll.CanvasSize = UDim2.new(0, 0, 0, 320)
tutorialScroll.Parent = tutorialFrame

local tutorialLayout = Instance.new("UIListLayout")
tutorialLayout.SortOrder = Enum.SortOrder.LayoutOrder
tutorialLayout.Padding = UDim.new(0, 12)
tutorialLayout.Parent = tutorialScroll

-- Section: Controls
local controlsSection = Instance.new("Frame")
controlsSection.Name = "ControlsSection"
controlsSection.Size = UDim2.new(1, -10, 0, 85)
controlsSection.BackgroundColor3 = Color3.fromRGB(18, 28, 50)
controlsSection.BackgroundTransparency = 0.4
controlsSection.LayoutOrder = 1
controlsSection.Parent = tutorialScroll
addCorner(controlsSection, 10)

local controlsTitle = Instance.new("TextLabel")
controlsTitle.Size = UDim2.new(1, -24, 0, 28)
controlsTitle.Position = UDim2.new(0, 12, 0, 10)
controlsTitle.BackgroundTransparency = 1
controlsTitle.Text = "CONTROLS"
controlsTitle.TextColor3 = COLORS.accentGreen
controlsTitle.TextSize = 17
controlsTitle.Font = Enum.Font.GothamBold
controlsTitle.TextXAlignment = Enum.TextXAlignment.Left
controlsTitle.Parent = controlsSection

local controlsBody = Instance.new("TextLabel")
controlsBody.Size = UDim2.new(1, -24, 0, 36)
controlsBody.Position = UDim2.new(0, 12, 0, 40)
controlsBody.BackgroundTransparency = 1
controlsBody.Text = "WASD to move   •   E to interact   •   Mouse to look"
controlsBody.TextColor3 = COLORS.bodyText
controlsBody.TextSize = 17
controlsBody.Font = Enum.Font.GothamMedium
controlsBody.TextXAlignment = Enum.TextXAlignment.Left
controlsBody.Parent = controlsSection

-- Section: Careers
local careersSection = Instance.new("Frame")
careersSection.Name = "CareersSection"
careersSection.Size = UDim2.new(1, -10, 0, 190)
careersSection.BackgroundColor3 = Color3.fromRGB(18, 28, 50)
careersSection.BackgroundTransparency = 0.4
careersSection.LayoutOrder = 2
careersSection.Parent = tutorialScroll
addCorner(careersSection, 10)

local careersTitle = Instance.new("TextLabel")
careersTitle.Size = UDim2.new(1, -24, 0, 28)
careersTitle.Position = UDim2.new(0, 12, 0, 10)
careersTitle.BackgroundTransparency = 1
careersTitle.Text = "CAREER PATHS"
careersTitle.TextColor3 = COLORS.accentGreen
careersTitle.TextSize = 17
careersTitle.Font = Enum.Font.GothamBold
careersTitle.TextXAlignment = Enum.TextXAlignment.Left
careersTitle.Parent = careersSection

local careersBody = Instance.new("TextLabel")
careersBody.Size = UDim2.new(1, -24, 0, 145)
careersBody.Position = UDim2.new(0, 12, 0, 40)
careersBody.BackgroundTransparency = 1
careersBody.Text = "1.  CYBERSECURITY ANALYST\n     Detect phishing, create passwords, protect systems\n\n2.  CHEF\n     Prepare meals, follow recipes, manage tasks\n\n3.  HEALTHCARE SPECIALIST\n     Review files, administer meds, handle emergencies"
careersBody.TextColor3 = COLORS.bodyText
careersBody.TextSize = 16
careersBody.Font = Enum.Font.Gotham
careersBody.TextXAlignment = Enum.TextXAlignment.Left
careersBody.TextYAlignment = Enum.TextYAlignment.Top
careersBody.TextWrapped = true
careersBody.Parent = careersSection

-- Section: Tip
local tipSection = Instance.new("Frame")
tipSection.Name = "TipSection"
tipSection.Size = UDim2.new(1, -10, 0, 60)
tipSection.BackgroundColor3 = Color3.fromRGB(25, 40, 70)
tipSection.BackgroundTransparency = 0.3
tipSection.LayoutOrder = 3
tipSection.Parent = tutorialScroll
addCorner(tipSection, 10)

local tipBody = Instance.new("TextLabel")
tipBody.Size = UDim2.new(1, -24, 1, 0)
tipBody.Position = UDim2.new(0, 12, 0, 0)
tipBody.BackgroundTransparency = 1
tipBody.Text = "💡  Follow on-screen prompts and aim for a high score!"
tipBody.TextColor3 = COLORS.accent
tipBody.TextSize = 17
tipBody.Font = Enum.Font.GothamMedium
tipBody.TextXAlignment = Enum.TextXAlignment.Left
tipBody.Parent = tipSection

-- Tutorial Back Button
local tutorialBackButton = createButton("BackButton", "BACK", tutorialFrame, UDim2.new(0.5, 0, 1, -80))

--------------------------------------------------------------
-- SETTINGSFRAME
--------------------------------------------------------------
local settingsFrame = Instance.new("Frame")
settingsFrame.Name = "SettingsFrame"
settingsFrame.Size = UDim2.new(0, 650, 0, 500)
settingsFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
settingsFrame.AnchorPoint = Vector2.new(0.5, 0.5)
settingsFrame.BackgroundColor3 = COLORS.cardBg
settingsFrame.BackgroundTransparency = 0.15
settingsFrame.BorderSizePixel = 0
settingsFrame.Visible = false
settingsFrame.Parent = menuGui

addCorner(settingsFrame, 14)
addStroke(settingsFrame, COLORS.border, 2.5)

-- Settings Title
local settingsTitle = Instance.new("TextLabel")
settingsTitle.Name = "TitleLabel"
settingsTitle.Size = UDim2.new(1, 0, 0, 60)
settingsTitle.Position = UDim2.new(0, 0, 0, 22)
settingsTitle.BackgroundTransparency = 1
settingsTitle.Text = "SETTINGS"
settingsTitle.TextColor3 = COLORS.titleText
settingsTitle.TextSize = 36
settingsTitle.Font = Enum.Font.GothamBlack
settingsTitle.Parent = settingsFrame

-- Settings Content Container
local settingsContent = Instance.new("Frame")
settingsContent.Name = "ContentFrame"
settingsContent.Size = UDim2.new(0.92, 0, 0, 310)
settingsContent.Position = UDim2.new(0.5, 0, 0, 85)
settingsContent.AnchorPoint = Vector2.new(0.5, 0)
settingsContent.BackgroundTransparency = 1
settingsContent.Parent = settingsFrame

local settingsLayout = Instance.new("UIListLayout")
settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
settingsLayout.Padding = UDim.new(0, 8)
settingsLayout.Parent = settingsContent

-- Helper function for settings rows (with optional toggle options)
local function createSettingRow(name, label, defaultValue, order, parent, options)
	local row = Instance.new("Frame")
	row.Name = name
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = Color3.fromRGB(18, 28, 50)
	row.BackgroundTransparency = 0.4
	row.LayoutOrder = order
	row.Parent = parent
	addCorner(row, 10)
	
	local labelText = Instance.new("TextLabel")
	labelText.Name = "Label"
	labelText.Size = UDim2.new(0.55, -24, 1, 0)
	labelText.Position = UDim2.new(0, 20, 0, 0)
	labelText.BackgroundTransparency = 1
	labelText.Text = label
	labelText.TextColor3 = COLORS.bodyText
	labelText.TextSize = 18
	labelText.Font = Enum.Font.GothamMedium
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.Parent = row
	
	-- If options provided, create clickable toggle button
	if options and #options > 0 then
		local currentIndex = 1
		for i, opt in ipairs(options) do
			if opt == defaultValue then
				currentIndex = i
				break
			end
		end
		
		local toggleBtn = Instance.new("TextButton")
		toggleBtn.Name = "ToggleButton"
		toggleBtn.Size = UDim2.new(0, 120, 0, 36)
		toggleBtn.Position = UDim2.new(1, -140, 0.5, -18)
		toggleBtn.BackgroundColor3 = COLORS.accentGreen
		toggleBtn.BackgroundTransparency = 0.2
		toggleBtn.Text = defaultValue
		toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		toggleBtn.TextSize = 16
		toggleBtn.Font = Enum.Font.GothamBold
		toggleBtn.AutoButtonColor = false
		toggleBtn.Parent = row
		addCorner(toggleBtn, 8)
		
		-- Store current index in the button
		toggleBtn:SetAttribute("CurrentIndex", currentIndex)
		toggleBtn:SetAttribute("Options", table.concat(options, ","))
		
		-- Click handler to cycle through options
		toggleBtn.MouseButton1Click:Connect(function()
			local idx = toggleBtn:GetAttribute("CurrentIndex") or 1
			idx = idx + 1
			if idx > #options then idx = 1 end
			toggleBtn:SetAttribute("CurrentIndex", idx)
			toggleBtn.Text = options[idx]
			
			-- Update color based on value
			if options[idx] == "OFF" or options[idx] == "LOW" then
				toggleBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 80)
			else
				toggleBtn.BackgroundColor3 = COLORS.accentGreen
			end
		end)
		
		-- Hover effect
		toggleBtn.MouseEnter:Connect(function()
			toggleBtn.BackgroundTransparency = 0
		end)
		toggleBtn.MouseLeave:Connect(function()
			toggleBtn.BackgroundTransparency = 0.2
		end)
	else
		-- Static value (non-clickable)
		local valueText = Instance.new("TextLabel")
		valueText.Name = "Value"
		valueText.Size = UDim2.new(0.45, -20, 1, 0)
		valueText.Position = UDim2.new(0.55, 0, 0, 0)
		valueText.BackgroundTransparency = 1
		valueText.Text = defaultValue
		valueText.TextColor3 = COLORS.accentGreen
		valueText.TextSize = 18
		valueText.Font = Enum.Font.GothamBold
		valueText.TextXAlignment = Enum.TextXAlignment.Right
		valueText.Parent = row
	end
	
	return row
end

-- Settings rows with toggle options
createSettingRow("AudioRow", "Audio", "ON", 1, settingsContent, {"ON", "OFF"})
createSettingRow("GraphicsRow", "Graphics Quality", "HIGH", 2, settingsContent, {"HIGH", "LOW"})
createSettingRow("ControlsRow", "Control Scheme", "WASD + Mouse", 3, settingsContent, nil) -- Static
createSettingRow("VersionRow", "Game Version", "1.0.0", 4, settingsContent, nil) -- Static

-- Settings Back Button
local settingsBackButton = createButton("BackButton", "BACK", settingsFrame, UDim2.new(0.5, 0, 1, -80))

print("MenuGuiCreator: MenuGui created successfully!")
print("MenuGuiCreator: MenuFrame, TutorialFrame, and SettingsFrame ready")
