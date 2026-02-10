-- https://www.roblox.com/games/127794225497302/Abyss
-------------------------
-- GLOBAL TOGGLES
-------------------------
getgenv().toggleChests = getgenv().toggleChests or false
getgenv().toggleFish   = getgenv().toggleFish or false

-------------------------
-- SERVICES & PATHS
-------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local gameWork = game:GetService("Workspace"):FindFirstChild("Game")
local chests = gameWork and gameWork:FindFirstChild("Chests")
local fishes = gameWork and gameWork:FindFirstChild("Fish") and gameWork.Fish:FindFirstChild("client")

-------------------------
-- COLORS
-------------------------
local tierColors = {
    ["Tier 1"] = Color3.fromRGB(0, 255, 0),
    ["Tier 2"] = Color3.fromRGB(255, 255, 0),
    ["Tier 3"] = Color3.fromRGB(255, 0, 0)
}

-------------------------
-- ESP STORAGE
-------------------------
getgenv().ESP_Table = getgenv().ESP_Table or {
    ChestConnections = {},
    FishConnections = {},
    CreatedUI = {}
}

-------------------------
-- CLEAR ESP
-------------------------
local function clearESP(type)
    local uiName = type == "FISH" and "FISH_UI" or "CHEST_UI"

    for obj, ui in pairs(getgenv().ESP_Table.CreatedUI) do
        if ui and ui.Name == uiName then
            ui:Destroy()
            getgenv().ESP_Table.CreatedUI[obj] = nil
        end
    end

    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BillboardGui") and v.Name == uiName then
            v:Destroy()
        end
    end
end

-------------------------
-- CREATE ESP
-------------------------
local function createESP(obj, text, subtext, color, uiName)
    if not obj or getgenv().ESP_Table.CreatedUI[obj] then return end

    local bbg = Instance.new("BillboardGui")
    bbg.Name = uiName
    bbg.Size = UDim2.new(0, 160, 0, 50)
    bbg.StudsOffset = Vector3.new(0, 3, 0)
    bbg.AlwaysOnTop = true
    bbg.Parent = obj

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.RichText = true
    label.Text = text .. "\n[" .. subtext .. "]"
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.RobotoMono
    label.TextSize = 14
    label.Parent = bbg

    getgenv().ESP_Table.CreatedUI[obj] = bbg
end

-------------------------
-- FISH ESP
-------------------------
local function applyFishESP(fish)
    if not fish or not getgenv().toggleFish then return end

    local stat = fish:FindFirstChild("stats", true)
    if not stat then return end

    local name = stat:FindFirstChild("Fish") and stat.Fish.Text or fish.Name
    local mut = stat:FindFirstChild("Mutation") and stat.Mutation:FindFirstChildOfClass("TextLabel")
    local mutation = mut and mut.Text or "Normal"

    local coloredMutation = "<font color='#FFFF00'>" .. mutation .. "</font>"

    createESP(fish, name, coloredMutation, Color3.fromRGB(0,255,255), "FISH_UI")
end

-------------------------
-- UI SETUP
-------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ESP_UI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 140)
frame.Position = UDim2.new(0, 20, 0, 200)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
frame.BorderSizePixel = 0
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,30)
title.BackgroundColor3 = Color3.fromRGB(40,40,40)
title.Text = "ESP TOGGLES"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.RobotoMono
title.TextSize = 14
title.Parent = frame

-------------------------
-- DRAG LOGIC
-------------------------
local dragging, dragStart, startPos

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-------------------------
-- TOGGLE BUTTONS
-------------------------
local function createToggle(text, posY, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,-20,0,36)
    btn.Position = UDim2.new(0,10,0,posY)
    btn.BackgroundColor3 = Color3.fromRGB(120,0,0)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.RobotoMono
    btn.TextSize = 14
    btn.BorderSizePixel = 0
    btn.Parent = frame

    local function refresh(state)
        btn.Text = text .. ": " .. (state and "ON" or "OFF")
        btn.BackgroundColor3 = state
            and Color3.fromRGB(0,120,0)
            or Color3.fromRGB(120,0,0)
    end

    refresh(false)

    btn.MouseButton1Click:Connect(function()
        local state = callback()
        refresh(state)
    end)
end

-------------------------
-- CHEST TOGGLE
-------------------------
createToggle("Chest ESP", 40, function()
    getgenv().toggleChests = not getgenv().toggleChests
    clearESP("CHEST")

    if getgenv().toggleChests and chests then
        for _, folder in pairs(chests:GetChildren()) do
            for _, chest in pairs(folder:GetChildren()) do
                createESP(
                    chest,
                    chest.Name,
                    folder.Name,
                    tierColors[folder.Name] or Color3.new(1,1,1),
                    "CHEST_UI"
                )
            end
        end
    end

    return getgenv().toggleChests
end)

-------------------------
-- FISH TOGGLE
-------------------------
createToggle("Fish ESP", 85, function()
    getgenv().toggleFish = not getgenv().toggleFish
    clearESP("FISH")

    if getgenv().toggleFish and fishes then
        for _, fish in pairs(fishes:GetChildren()) do
            applyFishESP(fish)
        end
    end

    return getgenv().toggleFish
end)

-------------------------
-- FISH LIVE UPDATE
-------------------------
if fishes then
    fishes.ChildAdded:Connect(function(child)
        task.wait(0.4)
        if getgenv().toggleFish then
            applyFishESP(child)
        end
    end)

    fishes.ChildRemoved:Connect(function(child)
        if getgenv().ESP_Table.CreatedUI[child] then
            getgenv().ESP_Table.CreatedUI[child]:Destroy()
            getgenv().ESP_Table.CreatedUI[child] = nil
        end
    end)
end
