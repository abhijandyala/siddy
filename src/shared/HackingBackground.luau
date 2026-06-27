--[[
	HackingBackground Module
	Creates and manages a subtle cybersecurity-themed background effect
	with scrolling code, grid overlay, and animated data streams.
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local HackingBackground = {}
HackingBackground.__index = HackingBackground

local CODE_CHARS = {"0", "1", "A", "F", "C", "E", "7", "3", "9", "B", "D", "2", "4", "8", "6", "5"}

local function generateCodeText()
	local codeText = ""
	for _ = 1, 60 do
		codeText = codeText .. CODE_CHARS[math.random(1, #CODE_CHARS)] .. "\n"
	end
	return codeText
end

function HackingBackground.new()
	local self = setmetatable({}, HackingBackground)
	self._gui = nil
	self._background = nil
	self._active = false
	return self
end

function HackingBackground:Initialize(playerGui, displayOrder)
	if self._active then return end
	self._active = true
	
	displayOrder = displayOrder or 950
	
	-- Main ScreenGui
	local hackBgGui = Instance.new("ScreenGui")
	hackBgGui.Name = "HackingBackground"
	hackBgGui.IgnoreGuiInset = true
	hackBgGui.DisplayOrder = displayOrder
	hackBgGui.Parent = playerGui
	self._gui = hackBgGui
	
	-- Background frame
	local hackBg = Instance.new("Frame")
	hackBg.Size = UDim2.new(1, 0, 1, 0)
	hackBg.BackgroundColor3 = Color3.fromRGB(8, 12, 28)
	hackBg.BackgroundTransparency = 0
	hackBg.BorderSizePixel = 0
	hackBg.Parent = hackBgGui
	self._background = hackBg
	
	-- Grid overlay
	self:_createGrid(hackBg)
	
	-- Scrolling code columns
	self:_createCodeColumns(hackBg)
	
	-- Corner glow effect
	self:_createCornerGlow(hackBg)
	
	-- Data stream lines
	self:_createDataStreams(hackBg)
end

function HackingBackground:_createGrid(parent)
	local gridFrame = Instance.new("Frame")
	gridFrame.Size = UDim2.new(1, 0, 1, 0)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = parent
	
	-- Horizontal scan lines
	for i = 0, 40 do
		local scanLine = Instance.new("Frame")
		scanLine.Size = UDim2.new(1, 0, 0, 1)
		scanLine.Position = UDim2.new(0, 0, i / 40, 0)
		scanLine.BackgroundColor3 = Color3.fromRGB(30, 60, 100)
		scanLine.BackgroundTransparency = 0.92
		scanLine.BorderSizePixel = 0
		scanLine.Parent = gridFrame
	end
	
	-- Vertical grid lines
	for i = 0, 30 do
		local vLine = Instance.new("Frame")
		vLine.Size = UDim2.new(0, 1, 1, 0)
		vLine.Position = UDim2.new(i / 30, 0, 0, 0)
		vLine.BackgroundColor3 = Color3.fromRGB(30, 60, 100)
		vLine.BackgroundTransparency = 0.94
		vLine.BorderSizePixel = 0
		vLine.Parent = gridFrame
	end
end

function HackingBackground:_createCodeColumns(parent)
	local function animateColumn(columnFrame, duration, codeLabel)
		if not self._gui or not self._gui.Parent then return end
		
		local startPos = UDim2.new(columnFrame.Position.X.Scale, 0, -1, 0)
		local endPos = UDim2.new(columnFrame.Position.X.Scale, 0, 0.5, 0)
		
		columnFrame.Position = startPos
		codeLabel.Text = generateCodeText()
		
		local tween = TweenService:Create(columnFrame, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			Position = endPos
		})
		
		tween.Completed:Connect(function()
			if self._gui and self._gui.Parent then
				animateColumn(columnFrame, duration, codeLabel)
			end
		end)
		
		tween:Play()
	end
	
	for col = 1, 12 do
		local columnFrame = Instance.new("Frame")
		columnFrame.Size = UDim2.new(0, 20, 2, 0)
		columnFrame.Position = UDim2.new((col - 1) / 12 + 0.02, 0, -1, 0)
		columnFrame.BackgroundTransparency = 1
		columnFrame.Parent = parent
		columnFrame.ClipsDescendants = false
		
		local codeLabel = Instance.new("TextLabel")
		codeLabel.Size = UDim2.new(1, 0, 1, 0)
		codeLabel.Position = UDim2.new(0, 0, 0, 0)
		codeLabel.BackgroundTransparency = 1
		codeLabel.Text = generateCodeText()
		codeLabel.TextColor3 = Color3.fromRGB(40, 80, 140)
		codeLabel.TextTransparency = 0.75 + (col % 3) * 0.05
		codeLabel.TextSize = 14
		codeLabel.Font = Enum.Font.Code
		codeLabel.TextYAlignment = Enum.TextYAlignment.Top
		codeLabel.Parent = columnFrame
		
		local duration = 8 + (col % 4) * 3
		task.delay(col * 0.3, function()
			animateColumn(columnFrame, duration, codeLabel)
		end)
	end
end

function HackingBackground:_createCornerGlow(parent)
	local glowCorner = Instance.new("Frame")
	glowCorner.Size = UDim2.new(0.4, 0, 0.4, 0)
	glowCorner.Position = UDim2.new(-0.1, 0, -0.1, 0)
	glowCorner.BackgroundColor3 = Color3.fromRGB(30, 80, 180)
	glowCorner.BackgroundTransparency = 0.95
	glowCorner.BorderSizePixel = 0
	glowCorner.Parent = parent
	
	local glowGradient = Instance.new("UIGradient")
	glowGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 140, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 12, 28))
	})
	glowGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(1, 1)
	})
	glowGradient.Parent = glowCorner
	
	-- Pulse animation
	task.spawn(function()
		while self._gui and self._gui.Parent do
			TweenService:Create(glowCorner, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				BackgroundTransparency = 0.9
			}):Play()
			task.wait(2)
			if not self._gui or not self._gui.Parent then break end
			TweenService:Create(glowCorner, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				BackgroundTransparency = 0.97
			}):Play()
			task.wait(2)
		end
	end)
end

function HackingBackground:_createDataStreams(parent)
	for i = 1, 6 do
		local streamLine = Instance.new("Frame")
		streamLine.Size = UDim2.new(0.15, 0, 0, 2)
		streamLine.Position = UDim2.new(-0.2, 0, 0.15 + i * 0.12, 0)
		streamLine.BackgroundColor3 = Color3.fromRGB(60, 140, 255)
		streamLine.BackgroundTransparency = 0.7 + (i % 2) * 0.1
		streamLine.BorderSizePixel = 0
		streamLine.Parent = parent
		
		task.spawn(function()
			local delayTime = i * 0.8
			task.wait(delayTime)
			while self._gui and self._gui.Parent do
				streamLine.Position = UDim2.new(-0.2, 0, streamLine.Position.Y.Scale, 0)
				local duration = 3 + math.random() * 2
				TweenService:Create(streamLine, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
					Position = UDim2.new(1.2, 0, streamLine.Position.Y.Scale, 0)
				}):Play()
				task.wait(duration + math.random() * 2)
			end
		end)
	end
end

function HackingBackground:FadeOut(duration)
	duration = duration or 0.5
	if not self._gui or not self._background then return end
	
	local fadeInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	
	TweenService:Create(self._background, fadeInfo, {BackgroundTransparency = 1}):Play()
	
	for _, child in pairs(self._background:GetChildren()) do
		if child:IsA("Frame") then
			TweenService:Create(child, fadeInfo, {BackgroundTransparency = 1}):Play()
		elseif child:IsA("TextLabel") then
			TweenService:Create(child, fadeInfo, {TextTransparency = 1}):Play()
		end
	end
end

function HackingBackground:Cleanup()
	self._active = false
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	self._background = nil
end

function HackingBackground:IsActive()
	return self._active and self._gui ~= nil and self._gui.Parent ~= nil
end

return HackingBackground
