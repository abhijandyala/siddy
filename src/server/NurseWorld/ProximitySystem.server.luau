--[[
	ProximitySystem.luau
	Script: ServerScriptService/NurseWorld/ProximitySystem
	
	Manages proximity-based triggers for patient beds in the hospital wing.
	When a player walks near a patient bed, it activates the scenario.
	
	Workspace Setup Required:
		- Folder: Workspace/NurseWorld/PatientBeds
		- Each bed: PatientBed_01, PatientBed_02, PatientBed_03
		- Each bed needs a child Part called "TriggerZone" (invisible, CanCollide = false)
		- Each bed needs a child Part called "InteractPrompt" (BillboardGui attachment point)
	
	Uses ProximityPrompt for modern Roblox interaction.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProximitySystem = {}
ProximitySystem.__index = ProximitySystem

-- Configuration
local PROMPT_DISTANCE = 12 -- studs
local PROMPT_HOLD_DURATION = 0.5 -- seconds to hold E
local PROMPT_TEXT = "Assess Patient"
local PROMPT_ACTION_TEXT = "Hold"

function ProximitySystem.new(patientBedsFolder: Folder)
	local self = setmetatable({}, ProximitySystem)

	self._bedsFolder = patientBedsFolder
	self._prompts = {} -- { [locationName] = ProximityPrompt }
	self._activeScenarios = {} -- { [locationName] = true } -- which scenarios have been completed
	self._lockedScenarios = {} -- { [locationName] = true } -- which are locked (sequential)
	self._onInteractCallbacks = {} -- { function(player, locationName) }
	self._currentlyActive = nil -- currently active scenario location

	return self
end

-- Initialize proximity prompts on all patient beds
function ProximitySystem:Setup()
	if not self._bedsFolder then
		warn("[ProximitySystem] PatientBeds folder not found!")
		return
	end

	for _, bed in self._bedsFolder:GetChildren() do
		if bed:IsA("Model") or bed:IsA("Part") then
			self:_createPromptForBed(bed)
		end
	end

	-- Lock all scenarios except the first one initially
	self:_updateLocks()

	print("[ProximitySystem] Setup complete. Found " .. tostring(#self._bedsFolder:GetChildren()) .. " patient beds.")
end

-- Create a ProximityPrompt for a patient bed
function ProximitySystem:_createPromptForBed(bed: Instance)
	local locationName = bed.Name

	-- Find or create the interaction point
	local interactPart = bed:FindFirstChild("InteractPoint")
	if not interactPart then
		-- If no specific interact point, use the bed's PrimaryPart or the part itself
		if bed:IsA("Model") then
			interactPart = bed.PrimaryPart or bed:FindFirstChildWhichIsA("Part")
		else
			interactPart = bed
		end
	end

	if not interactPart then
		warn("[ProximitySystem] No valid part found for bed: " .. locationName)
		return
	end

	-- Create ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PatientPrompt"
	prompt.ObjectText = self:_getPatientLabel(locationName)
	prompt.ActionText = PROMPT_TEXT
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt.Parent = interactPart

	-- Store reference
	self._prompts[locationName] = prompt

	-- Connect trigger
	prompt.Triggered:Connect(function(player)
		self:_onPromptTriggered(player, locationName)
	end)

	-- Visual indicator setup (billboard)
	self:_createBillboard(interactPart, locationName)
end

-- Create a billboard GUI above the patient bed
function ProximitySystem:_createBillboard(part: Part, locationName: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PatientIndicator"
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 30
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "PatientName"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = self:_getPatientLabel(locationName)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	-- Status indicator dot
	local statusDot = Instance.new("Frame")
	statusDot.Name = "StatusDot"
	statusDot.Size = UDim2.new(0, 12, 0, 12)
	statusDot.Position = UDim2.new(0, -16, 0.5, -6)
	statusDot.BackgroundColor3 = Color3.fromRGB(100, 255, 100) -- green = available
	statusDot.BorderSizePixel = 0
	statusDot.Parent = label

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = statusDot
end

-- Get patient display label from location name
function ProximitySystem:_getPatientLabel(locationName: string): string
	local labels = {
		PatientBed_01 = "Mrs. Robinson — Bed 1",
		PatientBed_02 = "Mr. Alvarez — Bed 2",
		PatientBed_03 = "Ms. Chen — Bed 3",
	}
	return labels[locationName] or locationName
end

-- Handle proximity prompt triggered
function ProximitySystem:_onPromptTriggered(player: Player, locationName: string)
	-- Check if this scenario is locked
	if self._lockedScenarios[locationName] then
		-- Could fire a UI notification here
		print("[ProximitySystem] Scenario " .. locationName .. " is locked. Complete previous scenarios first.")
		return
	end

	-- Check if already completed
	if self._activeScenarios[locationName] then
		print("[ProximitySystem] Scenario " .. locationName .. " already completed.")
		return
	end

	-- Check if another scenario is currently active
	if self._currentlyActive then
		print("[ProximitySystem] Another scenario is in progress.")
		return
	end

	self._currentlyActive = locationName

	-- Disable all prompts while scenario is active
	self:_setAllPromptsEnabled(false)

	-- Fire callbacks
	for _, callback in self._onInteractCallbacks do
		task.spawn(callback, player, locationName)
	end
end

-- Register a callback for when a patient is interacted with
function ProximitySystem:OnInteract(callback: (player: Player, locationName: string) -> ())
	table.insert(self._onInteractCallbacks, callback)
end

-- Mark a scenario as completed and unlock the next one
function ProximitySystem:CompleteScenario(locationName: string)
	self._activeScenarios[locationName] = true
	self._currentlyActive = nil

	-- Update the billboard to show completed
	self:_updateBedStatus(locationName, "completed")

	-- Unlock next scenario
	self:_updateLocks()

	-- Re-enable prompts for available scenarios
	self:_setAllPromptsEnabled(true)
end

-- Update lock state (sequential progression)
function ProximitySystem:_updateLocks()
	local bedNames = { "PatientBed_01", "PatientBed_02", "PatientBed_03" }

	for i, bedName in bedNames do
		if i == 1 then
			-- First bed is always unlocked
			self._lockedScenarios[bedName] = false
		else
			-- Unlock if previous bed is completed
			local prevBed = bedNames[i - 1]
			self._lockedScenarios[bedName] = not self._activeScenarios[prevBed]
		end

		-- Update visual status
		if self._activeScenarios[bedName] then
			self:_updateBedStatus(bedName, "completed")
		elseif self._lockedScenarios[bedName] then
			self:_updateBedStatus(bedName, "locked")
		else
			self:_updateBedStatus(bedName, "available")
		end
	end
end

-- Update billboard status indicator
function ProximitySystem:_updateBedStatus(locationName: string, status: string)
	local prompt = self._prompts[locationName]
	if not prompt then return end

	local part = prompt.Parent
	local billboard = part:FindFirstChild("PatientIndicator")
	if not billboard then return end

	local label = billboard:FindFirstChild("PatientName")
	if not label then return end

	local dot = label:FindFirstChild("StatusDot")
	if not dot then return end

	if status == "completed" then
		dot.BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- gray
		prompt.Enabled = false
	elseif status == "locked" then
		dot.BackgroundColor3 = Color3.fromRGB(255, 100, 100) -- red
		prompt.Enabled = false
	elseif status == "available" then
		dot.BackgroundColor3 = Color3.fromRGB(100, 255, 100) -- green
		prompt.Enabled = true
	end
end

-- Enable/disable all prompts
function ProximitySystem:_setAllPromptsEnabled(enabled: boolean)
	for locationName, prompt in self._prompts do
		if not self._activeScenarios[locationName] and not self._lockedScenarios[locationName] then
			prompt.Enabled = enabled
		end
	end
end

-- Check if all scenarios are complete
function ProximitySystem:AllComplete(): boolean
	return self._activeScenarios["PatientBed_01"] == true
		and self._activeScenarios["PatientBed_02"] == true
		and self._activeScenarios["PatientBed_03"] == true
end

-- Reset (for replay)
function ProximitySystem:Reset()
	self._activeScenarios = {}
	self._lockedScenarios = {}
	self._currentlyActive = nil
	self:_updateLocks()
end

return ProximitySystem
