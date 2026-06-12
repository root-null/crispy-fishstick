--==============================================================
-- HUMAN-LIKE CHARACTER TWEEN + GUI (Executor / Xeno)
-- Walks/jumps/dashes (Q) to locations, real obstacle checks,
-- anti-cheat friendly movement, anti-idle (no 20min kick)
-- Jump ONLY on real obstacles, stop jumping/dashing on arrival
--==============================================================

local ok, err = pcall(function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local existing = parentGui:FindFirstChild("TweenControlGui")
if existing then existing:Destroy() end

--==============================================================
-- CONFIG
--==============================================================
local config = {
	walkSpeed   = 16,   -- studs/sec while walking (keep close to game default for anti-cheat)
	stayTime    = 4,    -- seconds at each location
	dashKey     = Enum.KeyCode.Q,
	useDash     = true, -- press Q toward each location
	arriveDist  = 4,    -- how close counts as "arrived"
	jumpOnStuck = true, -- jump if an obstacle is detected
}

local function getChar()
	local char = player.Character or player.CharacterAdded:Wait()
	local root = char:WaitForChild("HumanoidRootPart")
	local hum  = char:WaitForChild("Humanoid")
	return root, hum, char
end

--==============================================================
-- SAVED LOCATIONS (1,2,3,4 ...)
--==============================================================
local locations = {
	CFrame.new(0,   5, 0),
	CFrame.new(20,  5, 0),
	CFrame.new(20,  5, 20),
	CFrame.new(0,   5, 20),
}

--==============================================================
-- OBSTACLE DETECTION (real raycast)
--==============================================================
local function buildParams(char)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = { char }
	p.IgnoreWater = true
	return p
end

-- Returns true if something solid is right in front of us within `dist`
local function isBlocked(root, char, dir, dist)
	local params = buildParams(char)
	local origin = root.Position
	local result = workspace:Raycast(origin, dir.Unit * dist, params)
	return result ~= nil, result
end

--==============================================================
-- HUMAN-LIKE MOVEMENT
--==============================================================
local running = false

local function pressDash()
	-- Fire the dash key like a real key press (works with most games' bindings)
	VirtualInputManager:SendKeyEvent(true,  config.dashKey, false, game)
	task.wait(0.05)
	VirtualInputManager:SendKeyEvent(false, config.dashKey, false, game)
end

local function moveTo(targetPos)
	local root, hum, char = getChar()
	hum.WalkSpeed = config.walkSpeed

	local lastDashTime = 0
	local stuckTimer = 0
	local lastPos = root.Position

	while running do
		root, hum, char = getChar()
		local pos = root.Position
		local flatTarget = Vector3.new(targetPos.X, pos.Y, targetPos.Z)
		local toTarget = (flatTarget - pos)
		local dist = (Vector3.new(targetPos.X, 0, targetPos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude

		-- Arrived: stop walking, dashing, and jumping immediately
		if dist <= config.arriveDist then
			hum:MoveTo(pos)      -- stop moving
			hum.Jump = false     -- make sure we don't jump on arrival
			break
		end

		-- Walk toward target
		hum:MoveTo(flatTarget)

		-- Real obstacle check in travel direction
		local dir = toTarget.Magnitude > 0 and toTarget.Unit or root.CFrame.LookVector
		local blocked = isBlocked(root, char, dir, 4)

		-- Stuck detection (barely moved)
		if (pos - lastPos).Magnitude < 0.15 then
			stuckTimer = stuckTimer + 1
		else
			stuckTimer = 0
		end
		lastPos = pos

		-- Jump ONLY when there is a real obstacle (or genuinely stuck)
		if config.jumpOnStuck and (blocked or stuckTimer > 12) then
			hum.Jump = true
			stuckTimer = 0
		end

		-- Dash (Q) toward location, but never when close to arriving
		if config.useDash and (os.clock() - lastDashTime) > 1.2 and dist > config.arriveDist + 6 then
			root.CFrame = CFrame.lookAt(pos, flatTarget)
			pressDash()
			lastDashTime = os.clock()
		end

		RunService.Heartbeat:Wait()
	end
end

local function startLoop()
	if running then return end
	running = true
	task.spawn(function()
		while running do
			for _, cf in ipairs(locations) do
				if not running then break end
				moveTo(cf.Position)
				if not running then break end
				-- Just wait at the location, no arrival jump
				task.wait(config.stayTime)
			end
		end
	end)
end

local function stopLoop()
	running = false
end

--==============================================================
-- ANTI-IDLE (prevents 20-min AFK kick)
--==============================================================
pcall(function()
	player.Idled:Connect(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
	end)
end)

-- Backup: periodic tiny input every 60s in case Idled doesn't fire
task.spawn(function()
	while task.wait(60) do
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new(0, 0))
		end)
	end
end)

--==============================================================
-- GUI
--==============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "TweenControlGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = parentGui
if syn and syn.protect_gui then syn.protect_gui(gui) end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 250, 0, 410)
frame.Position = UDim2.new(0, 20, 0.5, -205)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

-- Manual dragging
do
	local dragging, dragStart, startPos
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

local layout = Instance.new("UIListLayout", frame)
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
local pad = Instance.new("UIPadding", frame)
pad.PaddingTop = UDim.new(0, 10)

local function makeLabel(text, order)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 230, 0, 22)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(235, 235, 235)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 15
	lbl.LayoutOrder = order
	lbl.Parent = frame
	return lbl
end

local function makeBox(default, order)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0, 230, 0, 28)
	box.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.Font = Enum.Font.Gotham
	box.TextSize = 14
	box.Text = tostring(default)
	box.ClearTextOnFocus = false
	box.LayoutOrder = order
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
	box.Parent = frame
	return box
end

local function makeButton(text, color, order)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 230, 0, 32)
	btn.BackgroundColor3 = color
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Text = text
	btn.LayoutOrder = order
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	btn.Parent = frame
	return btn
end

makeLabel("Human-Like Tween", 1)
makeLabel("Walk Speed (studs/sec)", 2)
local speedBox = makeBox(config.walkSpeed, 3)
makeLabel("Stay Time (seconds)", 4)
local stayBox = makeBox(config.stayTime, 5)

local dashBtn  = makeButton("Dash (Q): ON", Color3.fromRGB(80, 80, 140), 6)
local saveBtn  = makeButton("Save Current Position", Color3.fromRGB(60, 120, 200), 7)
local clearBtn = makeButton("Clear Saved Locations", Color3.fromRGB(120, 90, 40), 8)
local startBtn = makeButton("Start", Color3.fromRGB(50, 150, 70), 9)
local stopBtn  = makeButton("Stop", Color3.fromRGB(170, 60, 60), 10)
local statusLbl = makeLabel("Locations saved: " .. #locations, 11)

local function applyConfig()
	local s = tonumber(speedBox.Text); local t = tonumber(stayBox.Text)
	if s then config.walkSpeed = s end
	if t then config.stayTime = t end
end
speedBox.FocusLost:Connect(applyConfig)
stayBox.FocusLost:Connect(applyConfig)

dashBtn.MouseButton1Click:Connect(function()
	config.useDash = not config.useDash
	dashBtn.Text = "Dash (Q): " .. (config.useDash and "ON" or "OFF")
end)

saveBtn.MouseButton1Click:Connect(function()
	local root = getChar()
	table.insert(locations, root.CFrame)
	statusLbl.Text = "Locations saved: " .. #locations
end)
clearBtn.MouseButton1Click:Connect(function()
	stopLoop(); locations = {}
	statusLbl.Text = "Locations saved: 0"
end)
startBtn.MouseButton1Click:Connect(function()
	applyConfig()
	if #locations == 0 then statusLbl.Text = "No locations to move to!" return end
	startLoop()
	statusLbl.Text = "Moving... (" .. #locations .. ")"
end)
stopBtn.MouseButton1Click:Connect(function()
	stopLoop()
	statusLbl.Text = "Stopped. Saved: " .. #locations
end)

print("[TweenGui] Loaded (human-like). Parented to:", parentGui.Name)

end)

if not ok then
	warn("[TweenGui] ERROR: " .. tostring(err))
end
