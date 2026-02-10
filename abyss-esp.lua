-- https://www.roblox.com/games/127794225497302/Abyss

-------------------------------------------------
-- GLOBAL SETTINGS
-------------------------------------------------
getgenv().toggleChests = getgenv().toggleChests or false
getgenv().toggleFish   = getgenv().toggleFish or false

getgenv().FishESP_Filter = getgenv().FishESP_Filter or {
    ShowNormal = true,
    ShowShiny  = true,
    MinStars   = 1
}

-------------------------------------------------
-- SERVICES
-------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local gameWork = workspace:FindFirstChild("Game")
local chests = gameWork and gameWork:FindFirstChild("Chests")
local fishes = gameWork
    and gameWork:FindFirstChild("Fish")
    and gameWork.Fish:FindFirstChild("client")

-------------------------------------------------
-- COLORS
-------------------------------------------------
local tierColors = {
    ["Tier 1"] = Color3.fromRGB(0,255,0),
    ["Tier 2"] = Color3.fromRGB(255,255,0),
    ["Tier 3"] = Color3.fromRGB(255,0,0)
}

-------------------------------------------------
-- ESP STORAGE
-------------------------------------------------
getgenv().ESP_Table = getgenv().ESP_Table or {
    CreatedUI = {}
}

-------------------------------------------------
-- CLEAR ESP
-------------------------------------------------
local function clearESP(kind)
    local uiName = kind == "FISH" and "FISH_UI" or "CHEST_UI"

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

-------------------------------------------------
-- CREATE ESP
-------------------------------------------------
local function createESP(obj, title, subtitle, color, uiName)
    if not obj or getgenv().ESP_Table.CreatedUI[obj] then return end

    local gui = Instance.new("BillboardGui")
    gui.Name = uiName
    gui.Size = UDim2.new(0,170,0,50)
    gui.StudsOffset = Vector3.new(0,3,0)
    gui.AlwaysOnTop = true
    gui.Parent = obj

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.RichText = true
    label.Text = title .. "\n[" .. subtitle .. "]"
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.RobotoMono
    label.TextSize = 14
    label.Parent = gui

    getgenv().ESP_Table.CreatedUI[obj] = gui
end

-------------------------------------------------
-- RARITY STAR DETECTION (UI-BASED)
-------------------------------------------------
local function getRarityStars(stat)
    local rarity = stat:FindFirstChild("Rarity")
    if not rarity then return 1 end

    local label = rarity:FindFirstChildOfClass("TextLabel")
    if not label or typeof(label.Text) ~= "string" then
        return 1
    end

    local _, count = string.gsub(label.Text, "⭐", "")
    return math.clamp(count, 1, 5)
end

-------------------------------------------------
-- FISH ESP
-------------------------------------------------
local function applyFishESP(fish)
    if not fish or not getgenv().toggleFish then return end

    local stat = fish:FindFirstChild("stats", true)
    if not stat then return end

    local name = stat:FindFirstChild("Fish")
        and stat.Fish.Text
        or fish.Name

    -----------------------
    -- MUTATION CHECK
    -----------------------
    local mutation = "Normal"
    local mutationFrame = stat:FindFirstChild("Mutation")
    if mutationFrame then
        local label = mutationFrame:FindFirstChildOfClass("TextLabel")
        if label and string.find(label.Text, "Shiny") then
            mutation = "Shiny"
        end
    end

    -----------------------
    -- RARITY
    -----------------------
    local stars = getRarityStars(stat)

    -----------------------
    -- FILTERS
    -----------------------
    if mutation == "Normal" and not getgenv().FishESP_Filter.ShowNormal then
        return
    end

    if mutation == "Shiny" and not getgenv().FishESP_Filter.ShowShiny then
        return
    end

    if stars < getgenv().FishESP_Filter.MinStars then
        return
    end

    -----------------------
    -- TEXT FORMAT
    -----------------------
    local mutationText =
        mutation == "Shiny"
        and "<font color='#FFD700'>Shiny</font>"
        or "<font color='#AAAAAA'>Normal</font>"

    local rarityText =
        "<font color='#FFD700'>" .. string.rep("⭐", stars) .. "</font>"

    createESP(
        fish,
        name,
        mutationText .. " " .. rarityText,
        Color3.fromRGB(0,255,255),
        "FISH_UI"
    )
end

-------------------------------------------------
-- CHEST ESP APPLY
-------------------------------------------------
local function applyChestESP()
    clearESP("CHEST")
    if not getgenv().toggleChests or not chests then return end

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

-------------------------------------------------
-- UI
-------------------------------------------------
local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.Name = "ESP_UI"
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0,210,0,160)
frame.Position = UDim2.new(0,20,0,200)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
frame.BorderSizePixel = 0

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1,0,0,30)
title.BackgroundColor3 = Color3.fromRGB(40,40,40)
title.Text = "ESP SETTINGS"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.RobotoMono
title.TextSize = 14

-------------------------------------------------
-- DRAGGING
-------------------------------------------------
local dragging, dragStart, startPos

title.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = i.Position
        startPos = frame.Position
    end
end)

UserInputService.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
    or i.UserInputType == Enum.UserInputType.Touch) then
        local delta = i.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-------------------------------------------------
-- TOGGLE BUTTON
-------------------------------------------------
local function createToggle(text, y, callback)
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(1,-20,0,34)
    btn.Position = UDim2.new(0,10,0,y)
    btn.Font = Enum.Font.RobotoMono
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.TextColor3 = Color3.new(1,1,1)

    local function refresh(state)
        btn.Text = text .. ": " .. (state and "ON" or "OFF")
        btn.BackgroundColor3 = state
            and Color3.fromRGB(0,120,0)
            or Color3.fromRGB(120,0,0)
    end

    refresh(false)

    btn.MouseButton1Click:Connect(function()
        refresh(callback())
    end)
end

-------------------------------------------------
-- BUTTONS
-------------------------------------------------
createToggle("Chest ESP", 40, function()
    getgenv().toggleChests = not getgenv().toggleChests
    applyChestESP()
    return getgenv().toggleChests
end)

createToggle("Fish ESP", 80, function()
    getgenv().toggleFish = not getgenv().toggleFish
    clearESP("FISH")

    if getgenv().toggleFish and fishes then
        for _, fish in pairs(fishes:GetChildren()) do
            applyFishESP(fish)
        end
    end

    return getgenv().toggleFish
end)

-------------------------------------------------
-- LIVE FISH UPDATE
-------------------------------------------------
if fishes then
    fishes.ChildAdded:Connect(function(fish)
        task.wait(0.4)
        if getgenv().toggleFish then
            applyFishESP(fish)
        end
    end)

    fishes.ChildRemoved:Connect(function(fish)
        if getgenv().ESP_Table.CreatedUI[fish] then
            getgenv().ESP_Table.CreatedUI[fish]:Destroy()
            getgenv().ESP_Table.CreatedUI[fish] = nil
        end
    end)
end
