--==============================================================
-- CHARACTER TWEEN + GUI (Executor / Xeno) - COMBAT SAFE
-- Title: Made by Jha.GGWP
-- Features: Rejoin, Anti-AFK, Anti-Cheat, Toggle GUI button,
--           Save / Load / Replace / Delete configurations
--==============================================================

local ok, err = pcall(function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local existing = parentGui:FindFirstChild("TweenControlGui")
if existing then existing:Destroy() end
local existingToggle = parentGui:FindFirstChild("TweenToggleGui")
if existingToggle then existingToggle:Destroy() end
local existingTitle = parentGui:FindFirstChild("TweenTitleGui")
if existingTitle then existingTitle:Destroy() end

--==============================================================
-- CONFIG (current working config)
--==============================================================
local config = {
	tweenSpeed = 50,   -- studs per second
	stayTime   = 4,    -- seconds at each location
}

local locations = {
	CFrame.new(0,   5, 0),
	CFrame.new(20,  5, 0),
	CFrame.new(20,  5, 20),
	CFrame.new(0,   5, 20),
}

local function getRoot()
	local char = player.Character or player.CharacterAdded:Wait()
	return char:WaitForChild("HumanoidRootPart"), char
end

--==============================================================
-- CONFIG PERSISTENCE (saved to executor filesystem)
-- All configs live in one JSON file keyed by name.
--==============================================================
local CONFIG_FILE = "JhaGGWP_TweenConfigs.json"

-- Executor file API guards (works on most executors: Synapse, Xeno, etc.)
local hasFiles = (typeof(writefile) == "function")
	and (typeof(readfile) == "function")
	and (typeof(isfile) == "function")

local function serializeCF(cf)
	return { cf:GetComponents() } -- 12 numbers
end

local function deserializeCF(t)
	return CFrame.new(unpack(t))
end

-- read the whole config store -> table { name = {tweenSpeed, stayTime, locations={...}} }
local function loadStore()
	if not hasFiles then return {} end
	if not isfile(CONFIG_FILE) then return {} end
	local raw = readfile(CONFIG_FILE)
	local good, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if good and type(data) == "table" then return data end
	return {}
end

local function saveStore(store)
	if not hasFiles then return false, "No file API on this executor" end
	local good, raw = pcall(function() return HttpService:JSONEncode(store) end)
	if not good then return false, "Encode failed" end
	local wrote = pcall(function() writefile(CONFIG_FILE, raw) end)
	return wrote
end

-- build a serializable snapshot of the current state
local function snapshotCurrent()
	local locs = {}
	for i, cf in ipairs(locations) do
		locs[i] = serializeCF(cf)
	end
	return {
		tweenSpeed = config.tweenSpeed,
		stayTime   = config.stayTime,
		locations  = locs,
	}
end

-- apply a stored config snapshot to the live state
local function applySnapshot(snap)
	if type(snap) ~= "table" then return end
	config.tweenSpeed = tonumber(snap.tweenSpeed) or config.tweenSpeed
	config.stayTime   = tonumber(snap.stayTime)   or config.stayTime
	local locs = {}
	if type(snap.locations) == "table" then
		for i, t in ipairs(snap.locations) do
			local good, cf = pcall(deserializeCF, t)
			if good then locs[i] = cf end
		end
	end
	locations = locs
end

local function listConfigNames()
	local store = loadStore()
	local names = {}
	for name in pairs(store) do names[#names + 1] = name end
	table.sort(names)
	return names
end

--==============================================================
-- ANTI-AFK / ANTI-IDLE
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
-- ANTI-CHEAT (toggleable)
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
		if root.AssemblyLinearVelocity.Magnitude > 200 then
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		end
		root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end
	if hum and hum.PlatformStand then
		hum.PlatformStand = false
	end
end)

--==============================================================
-- TWEEN LOGIC
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

		root = getRoot()
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
frame.Size = UDim2.new(0, 250, 0, 470)
frame.Position = UDim2.new(0, 20, 0.5, -235)
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

-- Scrolling so everything fits
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, 0)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = frame

local layout = Instance.new("UIListLayout", scroll)
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
local pad = Instance.new("UIPadding", scroll)
pad.PaddingTop = UDim.new(0, 10)
pad.PaddingBottom = UDim.new(0, 10)

local function makeLabel(text, order)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 220, 0, 22)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(235, 235, 235)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 15
	lbl.LayoutOrder = order
	lbl.Parent = scroll
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
	box.Parent = scroll
	return box
end

local function makeButton(text, color, order)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 220, 0, 32)
	btn.BackgroundColor3 = color
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 15
	btn.Text = text
	btn.LayoutOrder = order
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	btn.Parent = scroll
	return btn
end

makeLabel("Tween Speed (studs/sec)", 2)
local speedBox = makeBox(config.tweenSpeed, 3)
makeLabel("Stay Time (seconds)", 4)
local stayBox = makeBox(config.stayTime, 5)

local saveLocBtn = makeButton("Save Current Position", Color3.fromRGB(60, 120, 200), 6)
local clearBtn   = makeButton("Clear Saved Locations", Color3.fromRGB(120, 90, 40), 7)
local startBtn   = makeButton("Start Tween", Color3.fromRGB(50, 150, 70), 8)
local stopBtn    = makeButton("Stop Tween", Color3.fromRGB(170, 60, 60), 9)
local acBtn      = makeButton("Anti-Cheat: ON", Color3.fromRGB(80, 80, 150), 10)
local rejoinBtn  = makeButton("Rejoin Server", Color3.fromRGB(150, 100, 50), 11)

--==============================================================
-- CONFIGURATION MANAGER UI
--==============================================================
makeLabel("--- Configurations ---", 12)
local cfgNameBox = makeBox("MyConfig", 13)

-- selected config display + cycle button (acts as a simple dropdown)
local selectBtn = makeButton("Selected: (none)", Color3.fromRGB(70, 70, 90), 14)

local cfgSaveBtn    = makeButton("Save Config", Color3.fromRGB(50, 150, 70), 15)
local cfgLoadBtn    = makeButton("Load Config", Color3.fromRGB(60, 120, 200), 16)
local cfgReplaceBtn = makeButton("Replace Config", Color3.fromRGB(180, 150, 50), 17)
local cfgDeleteBtn  = makeButton("Delete Config", Color3.fromRGB(170, 60, 60), 18)

local statusLbl = makeLabel("Locations saved: " .. #locations, 19)

-- selection state for the cycle "dropdown"
local cfgNames = listConfigNames()
local selectedIndex = 0 -- 0 = none

local function selectedName()
	if selectedIndex >= 1 and selectedIndex <= #cfgNames then
		return cfgNames[selectedIndex]
	end
	return nil
end

local function refreshConfigList(keepName)
	cfgNames = listConfigNames()
	if keepName then
		selectedIndex = 0
		for i, n in ipairs(cfgNames) do
			if n == keepName then selectedIndex = i break end
		end
	elseif selectedIndex > #cfgNames then
		selectedIndex = #cfgNames
	end
	local sel = selectedName()
	selectBtn.Text = "Selected: " .. (sel or "(none)")
end

refreshConfigList()

if not hasFiles then
	statusLbl.Text = "No file API: configs won't persist"
end

--==============================================================
-- BEHAVIOUR
--==============================================================
local function applyConfig()
	local s = tonumber(speedBox.Text); local t = tonumber(stayBox.Text)
	if s then config.tweenSpeed = s end
	if t then config.stayTime = t end
end
speedBox.FocusLost:Connect(applyConfig)
stayBox.FocusLost:Connect(applyConfig)

local function syncBoxes()
	speedBox.Text = tostring(config.tweenSpeed)
	stayBox.Text = tostring(config.stayTime)
end

saveLocBtn.MouseButton1Click:Connect(function()
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

-- cycle through saved configs (tap to pick next one)
selectBtn.MouseButton1Click:Connect(function()
	if #cfgNames == 0 then
		statusLbl.Text = "No saved configs yet"
		return
	end
	selectedIndex = selectedIndex + 1
	if selectedIndex > #cfgNames then selectedIndex = 1 end
	local sel = selectedName()
	selectBtn.Text = "Selected: " .. (sel or "(none)")
	if sel then cfgNameBox.Text = sel end
end)

-- SAVE: create a new config under the typed name
cfgSaveBtn.MouseButton1Click:Connect(function()
	if not hasFiles then statusLbl.Text = "No file API on this executor" return end
	applyConfig()
	local name = (cfgNameBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then statusLbl.Text = "Enter a config name first" return end
	local store = loadStore()
	if store[name] then statusLbl.Text = "Exists - use Replace instead" return end
	store[name] = snapshotCurrent()
	local good = saveStore(store)
	refreshConfigList(name)
	statusLbl.Text = good and ("Saved config: " .. name) or "Save failed"
end)

-- LOAD: apply the selected (or typed) config
cfgLoadBtn.MouseButton1Click:Connect(function()
	if not hasFiles then statusLbl.Text = "No file API on this executor" return end
	local name = selectedName() or ((cfgNameBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if not name or name == "" then statusLbl.Text = "Select or type a config" return end
	local store = loadStore()
	if not store[name] then statusLbl.Text = "Config not found: " .. name return end
	stopLoop()
	applySnapshot(store[name])
	syncBoxes()
	cfgNameBox.Text = name
	refreshConfigList(name)
	statusLbl.Text = "Loaded '" .. name .. "' (" .. #locations .. " locs)"
end)

-- REPLACE: overwrite an existing config with current state
cfgReplaceBtn.MouseButton1Click:Connect(function()
	if not hasFiles then statusLbl.Text = "No file API on this executor" return end
	applyConfig()
	local name = selectedName() or ((cfgNameBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if not name or name == "" then statusLbl.Text = "Select or type a config" return end
	local store = loadStore()
	store[name] = snapshotCurrent()
	local good = saveStore(store)
	refreshConfigList(name)
	statusLbl.Text = good and ("Replaced config: " .. name) or "Replace failed"
end)

-- DELETE: remove the selected (or typed) config
cfgDeleteBtn.MouseButton1Click:Connect(function()
	if not hasFiles then statusLbl.Text = "No file API on this executor" return end
	local name = selectedName() or ((cfgNameBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if not name or name == "" then statusLbl.Text = "Select or type a config" return end
	local store = loadStore()
	if not store[name] then statusLbl.Text = "Config not found: " .. name return end
	store[name] = nil
	local good = saveStore(store)
	selectedIndex = 0
	refreshConfigList()
	statusLbl.Text = good and ("Deleted config: " .. name) or "Delete failed"
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
		if moved then return end
		gui.Enabled = not gui.Enabled
	end)
end

print("[TweenGui] Loaded (combat-safe). Parented to:", parentGui.Name)

end)

if not ok then
	warn("[TweenGui] ERROR: " .. tostring(err))
end
