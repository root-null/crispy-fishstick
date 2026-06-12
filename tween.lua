--==============================================================
-- SIMPLE CHARACTER TWEEN SYSTEM WITH GUI (Executor / Xeno)
-- Tweens YOUR character through saved locations, waiting at each.
--==============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

--==============================================================
-- CONFIG (defaults, editable in the GUI)
--==============================================================
local config = {
	tweenSpeed = 50,   -- studs per second
	stayTime   = 4,    -- seconds to wait at each location
}

--==============================================================
-- CHARACTER HELPERS
--==============================================================
local function getRoot()
	local char = player.Character or player.CharacterAdded:Wait()
	return char:WaitForChild("HumanoidRootPart"), char
end

--==============================================================
-- SAVED LOCATIONS (Location 1, 2, 3, 4 ...) as CFrames
--==============================================================
local locations = {
	CFrame.new(0,   5, 0),
	CFrame.new(20,  5, 0),
	CFrame.new(20,  5, 20),
	CFrame.new(0,   5, 20),
}

--==============================================================
-- TWEEN LOGIC
--==============================================================
local running = false
local currentTween = nil

local function tweenTo(cframe)
	local root = getRoot()
	-- Anchor so physics/walking doesn't fight the tween
	root.Anchored = true

	local distance = (root.Position - cframe.Position).Magnitude
	local duration = distance / math.max(config.tweenSpeed, 0.01)

	local info = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
	currentTween = TweenService:Create(root, info, { CFrame = cframe })
	currentTween:Play()
	currentTween.Completed:Wait()
end

local function startLoop()
	if running then return end
	running = true

	task.spawn(function()
		while running do
			for i, cf in ipairs(locations) do
				if not running then break end
				tweenTo(cf)                 -- move to location i
				if not running then break end
				task.wait(config.stayTime)  -- stay before next
			end
		end
		-- restore physics when stopped
		local root = getRoot()
		root.Anchored = false
	end)
end

local function stopLoop()
	running = false
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
	local ok, root = pcall(getRoot)
	if ok and root then root.Anchored = false end
end

--==============================================================
-- SIMPLE GUI
--==============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "TweenControlGui"
gui.ResetOnSpawn = false
-- Executors usually expose gethui(); fall back to CoreGui / PlayerGui
local parentGui = (gethui and gethui())
	or (game:GetService("CoreGui"))
	or player:WaitForChild("PlayerGui")
gui.Parent = parentGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 240, 0, 330)
frame.Position = UDim2.new(0, 20, 0.5, -165)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = frame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.Parent = frame

local function makeLabel(text, order)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 220, 0, 24)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(235, 235, 235)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 16
	lbl.LayoutOrder = order
	lbl.Parent = frame
	return lbl
end

local function makeBox(default, order)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0, 220, 0, 30)
	box.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.Font = Enum.Font.Gotham
	box.TextSize = 15
	box.Text = tostring(default)
	box.ClearTextOnFocus = false
	box.LayoutOrder = order
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = box
	box.Parent = frame
	return box
end

local function makeButton(text, color, order)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 220, 0, 34)
	btn.BackgroundColor3 = color
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 15
	btn.Text = text
	btn.AutoButtonColor = true
	btn.LayoutOrder = order
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn
	btn.Parent = frame
	return btn
end

makeLabel("Character Tween", 1)

makeLabel("Tween Speed (studs/sec)", 2)
local speedBox = makeBox(config.tweenSpeed, 3)

makeLabel("Stay Time (seconds)", 4)
local stayBox = makeBox(config.stayTime, 5)

local saveBtn  = makeButton("Save Current Position", Color3.fromRGB(60, 120, 200), 6)
local clearBtn = makeButton("Clear Saved Locations", Color3.fromRGB(120, 90, 40), 7)
local startBtn = makeButton("Start Tween", Color3.fromRGB(50, 150, 70), 8)
local stopBtn  = makeButton("Stop Tween", Color3.fromRGB(170, 60, 60), 9)

local statusLbl = makeLabel("Locations saved: " .. #locations, 10)

--==============================================================
-- GUI EVENTS
--==============================================================
local function applyConfig()
	local s = tonumber(speedBox.Text)
	local t = tonumber(stayBox.Text)
	if s then config.tweenSpeed = s end
	if t then config.stayTime = t end
end

speedBox.FocusLost:Connect(applyConfig)
stayBox.FocusLost:Connect(applyConfig)

saveBtn.MouseButton1Click:Connect(function()
	local root = getRoot()
	table.insert(locations, root.CFrame)   -- save your character's current spot
	statusLbl.Text = "Locations saved: " .. #locations
end)

clearBtn.MouseButton1Click:Connect(function()
	stopLoop()
	locations = {}
	statusLbl.Text = "Locations saved: 0"
end)

startBtn.MouseButton1Click:Connect(function()
	applyConfig()
	if #locations == 0 then
		statusLbl.Text = "No locations to tween!"
		return
	end
	startLoop()
	statusLbl.Text = "Tweening... (" .. #locations .. " locations)"
end)

stopBtn.MouseButton1Click:Connect(function()
	stopLoop()
	statusLbl.Text = "Stopped. Saved: " .. #locations
end)
