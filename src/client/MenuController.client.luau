-- MenuController.client.luau
-- Handles menu UI: glassmorphism styling, animations, and button navigation
-- Shows menu after sleeping animation with fade-in effect

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameState"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("=== MenuController loaded ===")

-- CONFIGURATION
local MENU_FADE_IN_DURATION = 1.0  -- How long the menu takes to fade in
local FRAME_TRANSITION_DURATION = 0.3  -- How long frame transitions take

-- Wait for MenuGui to exist
local menuGui = playerGui:WaitForChild("MenuGui", 10)
if not menuGui then
	warn("MenuController: MenuGui not found!")
	return
end

-- Ensure MenuGui is above all effects (dark overlay, vignette, blur)
menuGui.DisplayOrder = 200  -- Above dark overlay (50), vignette (100)
menuGui.IgnoreGuiInset = true  -- Full screen coverage

print("MenuController: Found MenuGui (DisplayOrder set to 200)")

-- Get all frames
local menuFrame = menuGui:WaitForChild("MenuFrame")
local tutorialFrame = menuGui:WaitForChild("TutorialFrame")
local settingsFrame = menuGui:WaitForChild("SettingsFrame")

print("MenuController: Found all frames")

-- Get buttons from MenuFrame
local playButton = menuFrame:WaitForChild("PlayButton")
local tutorialButton = menuFrame:WaitForChild("TutorialButton")
local settingsButton = menuFrame:WaitForChild("SettingsButton")

-- Get back buttons
local tutorialBackButton = tutorialFrame:WaitForChild("BackButton")
local settingsBackButton = settingsFrame:WaitForChild("BackButton")

print("MenuController: Found all buttons")

-- ============================================
-- STORE ORIGINAL BUTTON POSITIONS (once at startup)
-- ============================================
-- This prevents position drift from entrance/exit animations

local originalButtonPositions = {}

local function storeOriginalPositions(frame)
	for _, child in pairs(frame:GetChildren()) do
		if child:IsA("TextButton") then
			originalButtonPositions[child] = child.Position
		end
	end
end

storeOriginalPositions(menuFrame)
storeOriginalPositions(tutorialFrame)
storeOriginalPositions(settingsFrame)

print("MenuController: Stored original button positions")

-- ============================================
-- CLEANUP ONLY - Don't modify Studio settings
-- ============================================
-- Just remove any constraints we may have added before
-- Let Studio handle ALL sizing and positioning

local function cleanupFrame(frame)
	-- Remove ALL UIAspectRatioConstraints from the frame (including ones from Studio)
	for _, child in pairs(frame:GetChildren()) do
		if child:IsA("UIAspectRatioConstraint") then
			child:Destroy()
			print("MenuController: Removed UIAspectRatioConstraint from " .. frame.Name)
		end
	end
	
	-- Also check descendants for any other constraints we may have added
	for _, desc in pairs(frame:GetDescendants()) do
		if desc:IsA("UIAspectRatioConstraint") then
			desc:Destroy()
		end
	end
end

-- Cleanup all frames (remove any constraints we added)
cleanupFrame(menuFrame)
cleanupFrame(tutorialFrame)
cleanupFrame(settingsFrame)

print("MenuController: Cleaned up all frames - using Studio settings only")

-- ============================================
-- GLASSMORPHISM STYLING (Simple & Reliable)
-- ============================================
-- This works WITH the global BlurEffect in Lighting from MenuCameraFlythrough
-- The global blur blurs the background, this gives the frosted glass panel look

local function applyGlassmorphism(frame)
	-- Deep navy blue background for sleek dark theme
	frame.BackgroundColor3 = Color3.fromRGB(12, 20, 45)
	frame.BackgroundTransparency = 0.25
	
	-- Add UIStroke for glowing electric blue border
	local stroke = frame:FindFirstChild("GlassStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "GlassStroke"
		stroke.Parent = frame
	end
	stroke.Color = Color3.fromRGB(60, 140, 255)
	stroke.Transparency = 0.3
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	
	-- Match UICorner if the frame has one (for the stroke)
	local frameCorner = frame:FindFirstChildOfClass("UICorner")
	
	print("MenuController: Applied glassmorphism to " .. frame.Name)
end

-- Apply glassmorphism to all main frames
applyGlassmorphism(menuFrame)
applyGlassmorphism(tutorialFrame)
applyGlassmorphism(settingsFrame)

print("MenuController: Glassmorphism applied to all frames")

-- ============================================
-- UPDATE TITLE TEXT TO WHITE
-- ============================================

for _, frame in ipairs({menuFrame, tutorialFrame, settingsFrame}) do
	for _, child in pairs(frame:GetDescendants()) do
		if child:IsA("TextLabel") then
			child.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
end

print("MenuController: Title text updated to white")

-- ============================================
-- BUTTON HOVER/CLICK ANIMATIONS
-- ============================================

local function setupButtonAnimations(button)
	-- Store original properties
	local originalSize = button.Size
	local originalPosition = button.Position
	local originalBgColor = button.BackgroundColor3
	local originalBgTransparency = button.BackgroundTransparency
	local originalTextColor = button.TextColor3
	
	-- Animation parameters
	local hoverTween = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local hoverOutTween = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local clickTween = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local releaseTween = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	
	-- Create glow frame behind button
	local glow = Instance.new("Frame")
	glow.Name = "ButtonGlow"
	glow.Size = UDim2.new(1, 16, 1, 12)
	glow.Position = UDim2.new(0.5, 0, 0.5, 0)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundColor3 = Color3.fromRGB(60, 140, 255)
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.ZIndex = button.ZIndex - 1
	glow.Parent = button
	
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0, 12)
	glowCorner.Parent = glow
	
	-- Add UIStroke for button border (starts subtle)
	local buttonStroke = button:FindFirstChild("ButtonStroke")
	if not buttonStroke then
		buttonStroke = Instance.new("UIStroke")
		buttonStroke.Name = "ButtonStroke"
		buttonStroke.Parent = button
	end
	buttonStroke.Color = Color3.fromRGB(80, 120, 180)
	buttonStroke.Transparency = 0.6
	buttonStroke.Thickness = 1.5
	
	-- Track hover state for click handling
	local isHovering = false
	local isPressed = false
	
	-- MouseEnter: Scale up, show glow, fill with blue
	button.MouseEnter:Connect(function()
		if not button.Active then return end
		isHovering = true
		
		-- Scale up slightly (1.03x)
		local scaledSize = UDim2.new(
			originalSize.X.Scale * 1.03,
			originalSize.X.Offset * 1.03,
			originalSize.Y.Scale * 1.03,
			originalSize.Y.Offset * 1.03
		)
		
		TweenService:Create(button, hoverTween, {
			Size = scaledSize,
			BackgroundColor3 = Color3.fromRGB(30, 70, 140),
			BackgroundTransparency = 0.15
		}):Play()
		
		-- Show glow
		TweenService:Create(glow, hoverTween, {
			BackgroundTransparency = 0.7
		}):Play()
		
		-- Brighten border
		TweenService:Create(buttonStroke, hoverTween, {
			Color = Color3.fromRGB(100, 180, 255),
			Transparency = 0.2,
			Thickness = 2
		}):Play()
		
		-- Brighten text slightly
		if button:IsA("TextButton") then
			TweenService:Create(button, hoverTween, {
				TextColor3 = Color3.fromRGB(255, 255, 255)
			}):Play()
		end
	end)
	
	-- MouseLeave: Reverse all hover effects
	button.MouseLeave:Connect(function()
		isHovering = false
		isPressed = false
		
		TweenService:Create(button, hoverOutTween, {
			Size = originalSize,
			BackgroundColor3 = originalBgColor,
			BackgroundTransparency = originalBgTransparency
		}):Play()
		
		-- Hide glow
		TweenService:Create(glow, hoverOutTween, {
			BackgroundTransparency = 1
		}):Play()
		
		-- Reset border
		TweenService:Create(buttonStroke, hoverOutTween, {
			Color = Color3.fromRGB(80, 120, 180),
			Transparency = 0.6,
			Thickness = 1.5
		}):Play()
		
		-- Reset text color
		if button:IsA("TextButton") then
			TweenService:Create(button, hoverOutTween, {
				TextColor3 = originalTextColor
			}):Play()
		end
	end)
	
	-- MouseButton1Down: Press effect (scale down)
	button.MouseButton1Down:Connect(function()
		if not button.Active then return end
		isPressed = true
		
		local pressedSize = UDim2.new(
			originalSize.X.Scale * 0.96,
			originalSize.X.Offset * 0.96,
			originalSize.Y.Scale * 0.96,
			originalSize.Y.Offset * 0.96
		)
		
		TweenService:Create(button, clickTween, {
			Size = pressedSize
		}):Play()
		
		-- Flash border bright
		TweenService:Create(buttonStroke, clickTween, {
			Color = Color3.fromRGB(150, 220, 255),
			Transparency = 0
		}):Play()
	end)
	
	-- MouseButton1Up: Release effect (spring back)
	button.MouseButton1Up:Connect(function()
		isPressed = false
		
		if isHovering then
			-- Spring back to hover size
			local scaledSize = UDim2.new(
				originalSize.X.Scale * 1.03,
				originalSize.X.Offset * 1.03,
				originalSize.Y.Scale * 1.03,
				originalSize.Y.Offset * 1.03
			)
			
			TweenService:Create(button, releaseTween, {
				Size = scaledSize
			}):Play()
			
			TweenService:Create(buttonStroke, releaseTween, {
				Color = Color3.fromRGB(100, 180, 255),
				Transparency = 0.2
			}):Play()
		else
			-- Spring back to original size
			TweenService:Create(button, releaseTween, {
				Size = originalSize
			}):Play()
		end
	end)
	
	print("MenuController: Button animations setup for " .. button.Name)
end

-- Apply button animations to all menu buttons
setupButtonAnimations(playButton)
setupButtonAnimations(tutorialButton)
setupButtonAnimations(settingsButton)
setupButtonAnimations(tutorialBackButton)
setupButtonAnimations(settingsBackButton)

print("MenuController: Button animations applied to all buttons")

-- ============================================
-- FRAME VISIBILITY AND ANIMATIONS
-- ============================================

-- Hide all frames initially (they start invisible)
local function hideAllFrames()
	menuFrame.Visible = false
	tutorialFrame.Visible = false
	settingsFrame.Visible = false
end

-- Show a frame with fade-in animation and staggered button entrance
local function showFrameWithFade(frame, duration)
	-- Start with frame background invisible
	local originalBgTransparency = 0.25  -- Deep blue glass transparency
	frame.BackgroundTransparency = 1
	
	-- Collect buttons for staggered animation
	local buttons = {}
	local titleLabel = nil
	
	-- Store original transparencies and make all children invisible
	for _, child in pairs(frame:GetDescendants()) do
		if child:IsA("GuiObject") then
			if child:IsA("TextLabel") then
				if not child:GetAttribute("OriginalTextTransparency") then
					child:SetAttribute("OriginalTextTransparency", child.TextTransparency)
				end
				child.TextTransparency = 1
				-- Detect title (usually larger text or named "Title")
				if child.Name:lower():find("title") or child.TextSize >= 24 then
					titleLabel = child
				end
			end
			if child:IsA("TextButton") then
				if not child:GetAttribute("OriginalTextTransparency") then
					child:SetAttribute("OriginalTextTransparency", child.TextTransparency)
				end
				if not child:GetAttribute("OriginalBgTransparency") then
					child:SetAttribute("OriginalBgTransparency", child.BackgroundTransparency)
				end
				child.TextTransparency = 1
				child.BackgroundTransparency = 1
				
				-- Get the TRUE original position from our stored table
				local trueOriginalPos = originalButtonPositions[child]
				if trueOriginalPos then
					-- Offset buttons to the left for slide-in effect (from true original)
					local offsetPos = UDim2.new(
						trueOriginalPos.X.Scale - 0.05,
						trueOriginalPos.X.Offset - 30,
						trueOriginalPos.Y.Scale,
						trueOriginalPos.Y.Offset
					)
					child.Position = offsetPos
				end
				table.insert(buttons, child)
			end
			if child:IsA("Frame") and child.Name ~= "ButtonGlow" then
				if not child:GetAttribute("OriginalBgTransparency") then
					child:SetAttribute("OriginalBgTransparency", child.BackgroundTransparency)
				end
				child.BackgroundTransparency = 1
			end
			if child:IsA("ImageLabel") or child:IsA("ImageButton") then
				if not child:GetAttribute("OriginalImgTransparency") then
					child:SetAttribute("OriginalImgTransparency", child.ImageTransparency)
				end
				child.ImageTransparency = 1
				child.BackgroundTransparency = 1
			end
		end
		if child:IsA("UIStroke") then
			if not child:GetAttribute("OriginalStrokeTransparency") then
				child:SetAttribute("OriginalStrokeTransparency", child.Transparency)
			end
			child.Transparency = 1
		end
	end
	
	-- Make frame visible
	frame.Visible = true
	
	-- Phase 1: Animate frame background (0.3s)
	local frameTween = TweenService:Create(
		frame,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = originalBgTransparency}
	)
	frameTween:Play()
	
	-- Animate frame's UIStroke
	local frameStroke = frame:FindFirstChild("GlassStroke")
	if frameStroke then
		TweenService:Create(frameStroke,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Transparency = frameStroke:GetAttribute("OriginalStrokeTransparency") or 0.3}
		):Play()
	end
	
	-- Phase 2: Title fades in (0.15s delay)
	task.delay(0.15, function()
		if titleLabel then
			TweenService:Create(titleLabel,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{TextTransparency = titleLabel:GetAttribute("OriginalTextTransparency") or 0}
			):Play()
		end
		
		-- Also fade in non-button elements
		for _, child in pairs(frame:GetDescendants()) do
			if child:IsA("TextLabel") and child ~= titleLabel then
				TweenService:Create(child,
					TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{TextTransparency = child:GetAttribute("OriginalTextTransparency") or 0}
				):Play()
			end
			if child:IsA("Frame") and child.Name ~= "ButtonGlow" then
				TweenService:Create(child,
					TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{BackgroundTransparency = child:GetAttribute("OriginalBgTransparency") or 0}
				):Play()
			end
			if child:IsA("ImageLabel") or child:IsA("ImageButton") then
				TweenService:Create(child,
					TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ImageTransparency = child:GetAttribute("OriginalImgTransparency") or 0}
				):Play()
			end
		end
	end)
	
	-- Phase 3: Buttons slide in with stagger (0.1s between each)
	local buttonDelay = 0.25  -- Start after title begins fading
	local staggerTime = 0.1   -- Time between each button
	
	for i, btn in ipairs(buttons) do
		task.delay(buttonDelay + (i - 1) * staggerTime, function()
			-- Get the TRUE original position from our stored table
			local trueOriginalPos = originalButtonPositions[btn]
			if not trueOriginalPos then
				trueOriginalPos = btn.Position  -- Fallback
			end
			
			-- Slide in from left with bounce to TRUE original position
			TweenService:Create(btn,
				TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{
					Position = trueOriginalPos,
					TextTransparency = btn:GetAttribute("OriginalTextTransparency") or 0,
					BackgroundTransparency = btn:GetAttribute("OriginalBgTransparency") or 0
				}
			):Play()
			
			-- Animate button's UIStroke
			local btnStroke = btn:FindFirstChild("ButtonStroke")
			if btnStroke then
				TweenService:Create(btnStroke,
					TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{Transparency = btnStroke:GetAttribute("OriginalStrokeTransparency") or 0.6}
				):Play()
			end
		end)
	end
end

-- Hide a frame with fade-out animation
local function hideFrameWithFade(frame, duration)
	-- Animate frame background to invisible
	local frameTween = TweenService:Create(
		frame,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{BackgroundTransparency = 1}
	)
	frameTween:Play()
	
	-- Animate all children to invisible (NO position changes - just fade)
	for _, child in pairs(frame:GetDescendants()) do
		if child:IsA("GuiObject") then
			local tweenProps = {}
			
			if child:IsA("TextLabel") then
				tweenProps.TextTransparency = 1
			end
			if child:IsA("TextButton") then
				tweenProps.TextTransparency = 1
				tweenProps.BackgroundTransparency = 1
				-- NO position animation - just fade out
			end
			if child:IsA("Frame") and child.Name ~= "ButtonGlow" then
				tweenProps.BackgroundTransparency = 1
			end
			if child:IsA("ImageLabel") or child:IsA("ImageButton") then
				tweenProps.ImageTransparency = 1
			end
			
			if next(tweenProps) then
				local childTween = TweenService:Create(
					child,
					TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					tweenProps
				)
				childTween:Play()
			end
		end
		if child:IsA("UIStroke") then
			local strokeTween = TweenService:Create(
				child,
				TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{Transparency = 1}
			)
			strokeTween:Play()
		end
	end
	
	frameTween.Completed:Wait()
	frame.Visible = false
	
	-- Reset all button positions to their TRUE original positions after hiding
	for _, child in pairs(frame:GetChildren()) do
		if child:IsA("TextButton") then
			local trueOriginalPos = originalButtonPositions[child]
			if trueOriginalPos then
				child.Position = trueOriginalPos
			end
		end
	end
end

-- Switch from one frame to another
local function switchFrame(fromFrame, toFrame)
	hideFrameWithFade(fromFrame, FRAME_TRANSITION_DURATION)
	showFrameWithFade(toFrame, FRAME_TRANSITION_DURATION)
end

-- ============================================
-- BUTTON CONNECTIONS
-- ============================================

-- Play Button - Fades to black, then starts the game
playButton.MouseButton1Click:Connect(function()
	print("MenuController: Play button clicked - starting game!")
	
	-- Prevent double-clicking
	playButton.Active = false
	tutorialButton.Active = false
	settingsButton.Active = false
	
	-- Create black screen overlay that fades in on top of everything
	local blackOverlay = Instance.new("ScreenGui")
	blackOverlay.Name = "PlayTransitionBlack"
	blackOverlay.IgnoreGuiInset = true
	blackOverlay.DisplayOrder = 500
	blackOverlay.Parent = playerGui
	
	local blackFrame = Instance.new("Frame")
	blackFrame.Name = "BlackFrame"
	blackFrame.Size = UDim2.new(1, 0, 1, 0)
	blackFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	blackFrame.BackgroundTransparency = 1
	blackFrame.BorderSizePixel = 0
	blackFrame.Parent = blackOverlay
	
	-- Smooth fade to black (0.5s)
	local fadeToBlack = TweenService:Create(
		blackFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{BackgroundTransparency = 0}
	)
	fadeToBlack:Play()
	fadeToBlack.Completed:Wait()
	
	print("MenuController: Screen is black - signaling game start")
	
	-- Screen is now fully black - signal game start
	GameState:StartGame()
	
	-- Clean up menu behind the black screen
	task.wait(0.1)
	menuGui.Enabled = false
	
	print("MenuController: Game started, menu hidden")
end)

-- Tutorial Button -> Show TutorialFrame
tutorialButton.MouseButton1Click:Connect(function()
	print("MenuController: Tutorial button clicked")
	switchFrame(menuFrame, tutorialFrame)
end)

-- Settings Button -> Show SettingsFrame
settingsButton.MouseButton1Click:Connect(function()
	print("MenuController: Settings button clicked")
	switchFrame(menuFrame, settingsFrame)
end)

-- Tutorial Back Button -> Show MenuFrame
tutorialBackButton.MouseButton1Click:Connect(function()
	print("MenuController: Tutorial back button clicked")
	switchFrame(tutorialFrame, menuFrame)
end)

-- Settings Back Button -> Show MenuFrame
settingsBackButton.MouseButton1Click:Connect(function()
	print("MenuController: Settings back button clicked")
	switchFrame(settingsFrame, menuFrame)
end)

print("MenuController: All buttons connected")

-- ============================================
-- FLOATING PANEL ANIMATION
-- ============================================

local floatingConnections = {}

local function addFloatingAnimation(frame)
	-- Store base position
	local basePos = frame.Position
	local floatOffset = 4  -- Pixels to float up/down
	local floatDuration = 2.5  -- Seconds per direction
	
	-- Start floating animation loop
	local floatCoroutine = task.spawn(function()
		while frame and frame.Parent do
			-- Float up
			local upTween = TweenService:Create(frame,
				TweenInfo.new(floatDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{Position = UDim2.new(
					basePos.X.Scale,
					basePos.X.Offset,
					basePos.Y.Scale,
					basePos.Y.Offset - floatOffset
				)}
			)
			upTween:Play()
			upTween.Completed:Wait()
			
			if not frame or not frame.Parent then break end
			
			-- Float down
			local downTween = TweenService:Create(frame,
				TweenInfo.new(floatDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{Position = UDim2.new(
					basePos.X.Scale,
					basePos.X.Offset,
					basePos.Y.Scale,
					basePos.Y.Offset + floatOffset
				)}
			)
			downTween:Play()
			downTween.Completed:Wait()
		end
	end)
	
	floatingConnections[frame] = floatCoroutine
	print("MenuController: Floating animation started for " .. frame.Name)
end

-- ============================================
-- GLOWING BORDER PULSE ANIMATION
-- ============================================

local function addBorderPulse(frame)
	local stroke = frame:FindFirstChild("GlassStroke")
	if not stroke then return end
	
	local baseTrans = 0.3
	local pulseTrans = 0.5
	local pulseDuration = 1.5
	
	task.spawn(function()
		while frame and frame.Parent do
			-- Pulse dimmer
			local dimTween = TweenService:Create(stroke,
				TweenInfo.new(pulseDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{Transparency = pulseTrans}
			)
			dimTween:Play()
			dimTween.Completed:Wait()
			
			if not frame or not frame.Parent then break end
			
			-- Pulse brighter
			local brightTween = TweenService:Create(stroke,
				TweenInfo.new(pulseDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{Transparency = baseTrans}
			)
			brightTween:Play()
			brightTween.Completed:Wait()
		end
	end)
	
	print("MenuController: Border pulse started for " .. frame.Name)
end

-- ============================================
-- SHOW MENU AFTER SLEEPING ANIMATION
-- ============================================

-- Timing: Must match MenuCameraFlythrough timing
-- Cinematic ends at 6.0s, then 1s fade from black = menu appears at 7.0s
local MENU_APPEAR_TIME = 7.5  -- Show menu after fade-in from black completes

print("MenuController: Waiting " .. MENU_APPEAR_TIME .. "s for sleeping animation to complete...")

-- Hide all frames initially
hideAllFrames()

-- Wait for the right moment
task.wait(MENU_APPEAR_TIME)

-- Show the main menu with fade-in
print("MenuController: Showing main menu with fade-in animation!")
showFrameWithFade(menuFrame, MENU_FADE_IN_DURATION)

-- Start floating and border pulse animations after entrance completes
task.delay(MENU_FADE_IN_DURATION + 0.5, function()
	addFloatingAnimation(menuFrame)
	addBorderPulse(menuFrame)
	
	-- Also set up animations for other frames (they'll be visible when switched to)
	addBorderPulse(tutorialFrame)
	addBorderPulse(settingsFrame)
end)

print("MenuController: Menu is now visible!")
