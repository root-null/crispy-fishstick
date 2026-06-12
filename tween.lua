--==============================================================
-- CHARACTER TWEEN + GUI (Executor / Xeno) - COMBAT SAFE
-- Title: Made by Jha.GGWP
-- Features: Rejoin, Anti-AFK, Anti-Cheat, Toggle GUI button
--==============================================================

local ok, err = pcall(function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer

local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local existing = parentGui:FindFirstChild("TweenControlGui")
if existing then existing:Destroy() end
local existingToggle = parentGui:FindFirstChild("TweenToggleGui")
if existingToggle then existingToggle:Destroy() end
local existingTitle = parentGui:FindFirstChild("TweenTitleGui")
if existingTitle then existingTitle:Destroy() end

--==============================================================
-- CONFIG
--==============================================================
local config = {
	tweenSpeed = 50,   -- studs per second
	stayTime   = 4,    -- seconds at each location
}

local function getRoot()
	local char = player.Character or player.CharacterAdded:Wait()
	return char:WaitForChild("HumanoidRootPart"), char
end

--==============================================================
-- ANTI-AFK / ANTI-IDLE
-- Defeats the 20-minute idle kick by simulating input.
--==============================================================
do
	if _G.__TweenIdleConn then pcall(function() _G.__TweenIdleConn:Disconnect() end) end
	local idleConn = player.Idled:Connect(function()
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)
	_G.__TweenIdleConn = idleConn
end

--==============================================================
-- ANTI-CHEAT (kill velocity + keep humanoid alive each frame)
-- Toggleable. Prevents fling / ragdoll while we override CFrame
-- so server-side checks don't flag erratic physics.
--==============================================================
local antiCheatOn = true

if _G.__TweenAntiCheatConn then pcall(function() _G.__TweenAntiCheatConn:Disconnect() end) end
_G.__TweenAntiCheatConn = RunService.Heartbeat:Connect(function()
	if not antiCheatOn then return end
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if root then
		-- damp extreme velocities that trigger anti-cheat fling detection
		if root.AssemblyLinearVelocity.Magnitude > 200 then
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		end
		root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end
	if hum and hum.PlatformStand then
		hum.PlatformStand = false -- recover from ragdoll-based anti-cheat
	end
end)

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
-- TWEEN LOGIC (manual lerp, NO anchoring)
--==============================================================
local running = false

local function moveTo(targetCF)
	local root = getRoot()
	local distance = (root.Position - targetCF.Position).Magnitude
	local duration = distance / math.max(config.tweenSpeed, 0.01)

	local elapsed = 0
	local startCF = root.CFrame

	while elapsed < duration and running do
		local dt = RunService.Heartbeat:Wait()
		elapsed = elapsed + dt
		local alpha = math.clamp(elapsed / duration, 0, 1)

		root = getRoot() -- refetch in case of respawn
		root.CFrame = startCF:Lerp(targetCF, alpha)
		root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end

	if running then
		getRoot().CFrame = targetCF
	end
end

local function startLoop()
	if running then return end
	running = true
	task.spawn(function()
		while running do
			for _, cf in ipairs(locations) do
				if not running then break end
				moveTo(cf)
				if not running then break end
				task.wait(config.stayTime)
			end
		end
	end)
end

local function stopLoop()
	running = false
end

--==============================================================
-- REJOIN
--==============================================================
local function rejoin()
	pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
	end)
end

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
frame.Size = UDim2.new(0, 240, 0, 360)
frame.Position = UDim2.new(0, 20, 0.5, -180)
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
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
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
	btn.LayoutOrder = order
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	btn.Parent = frame
	return btn
end

makeLabel("Tween Speed (studs/sec)", 2)
local speedBox = makeBox(config.tweenSpeed, 3)
makeLabel("Stay Time (seconds)", 4)
local stayBox = makeBox(config.stayTime, 5)

local saveBtn   = makeButton("Save Current Position", Color3.fromRGB(60, 120, 200), 6)
local clearBtn  = makeButton("Clear Saved Locations", Color3.fromRGB(120, 90, 40), 7)
local startBtn  = makeButton("Start Tween", Color3.fromRGB(50, 150, 70), 8)
local stopBtn   = makeButton("Stop Tween", Color3.fromRGB(170, 60, 60), 9)
local acBtn     = makeButton("Anti-Cheat: ON", Color3.fromRGB(80, 80, 150), 10)
local rejoinBtn = makeButton("Rejoin Server", Color3.fromRGB(150, 100, 50), 11)
local statusLbl = makeLabel("Locations saved: " .. #locations, 12)

local function applyConfig()
	local s = tonumber(speedBox.Text); local t = tonumber(stayBox.Text)
	if s then config.tweenSpeed = s end
	if t then config.stayTime = t end
end
speedBox.FocusLost:Connect(applyConfig)
stayBox.FocusLost:Connect(applyConfig)

saveBtn.MouseButton1Click:Connect(function()
	table.insert(locations, getRoot().CFrame)
	statusLbl.Text = "Locations saved: " .. #locations
end)
clearBtn.MouseButton1Click:Connect(function()
	stopLoop(); locations = {}
	statusLbl.Text = "Locations saved: 0"
end)
startBtn.MouseButton1Click:Connect(function()
	applyConfig()
	if #locations == 0 then statusLbl.Text = "No locations to tween!" return end
	startLoop()
	statusLbl.Text = "Tweening... (" .. #locations .. ")"
end)
stopBtn.MouseButton1Click:Connect(function()
	stopLoop()
	statusLbl.Text = "Stopped. Saved: " .. #locations
end)
acBtn.MouseButton1Click:Connect(function()
	antiCheatOn = not antiCheatOn
	acBtn.Text = "Anti-Cheat: " .. (antiCheatOn and "ON" or "OFF")
	acBtn.BackgroundColor3 = antiCheatOn and Color3.fromRGB(80, 80, 150) or Color3.fromRGB(70, 70, 78)
end)
rejoinBtn.MouseButton1Click:Connect(function()
	statusLbl.Text = "Rejoining..."
	rejoin()
end)

--==============================================================
-- TITLE (upper middle): Made by Jha.GGWP
--==============================================================
local titleGui = Instance.new("ScreenGui")
titleGui.Name = "TweenTitleGui"
titleGui.ResetOnSpawn = false
titleGui.IgnoreGuiInset = true
titleGui.DisplayOrder = 1000
titleGui.Parent = parentGui

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(0, 320, 0, 40)
titleLbl.Position = UDim2.new(0.5, -160, 0, 12)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "Made by Jha.GGWP"
titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 26
titleLbl.TextStrokeTransparency = 0.5
titleLbl.Parent = titleGui

--==============================================================
-- TOGGLE BUTTON (black small square) - show/hide the GUI
--==============================================================
local toggleGui = Instance.new("ScreenGui")
toggleGui.Name = "TweenToggleGui"
toggleGui.ResetOnSpawn = false
toggleGui.IgnoreGuiInset = true
toggleGui.DisplayOrder = 1001
toggleGui.Parent = parentGui

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 32, 0, 32)
toggleBtn.Position = UDim2.new(0, 20, 0, 20)
toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
toggleBtn.BorderSizePixel = 0
toggleBtn.Text = ""
toggleBtn.AutoButtonColor = true
toggleBtn.Active = true
toggleBtn.Parent = toggleGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 4)

-- drag the toggle square too (ignores click if it was actually a drag)
do
	local dragging, dragStart, startPos, moved
	toggleBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			moved = false
			dragStart = input.Position
			startPos = toggleBtn.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			if d.Magnitude > 4 then moved = true end
			toggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	toggleBtn.MouseButton1Click:Connect(function()
		if moved then return end -- ignore click that was actually a drag
		gui.Enabled = not gui.Enabled
	end)
end

print("[TweenGui] Loaded (combat-safe). Parented to:", parentGui.Name)

end)

if not ok then
	warn("[TweenGui] ERROR: " .. tostring(err))
end
