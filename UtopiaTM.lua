repeat
	task.wait()
until game:IsLoaded()

local Hub = "UtopiaHub"
local Discord_Invite = "Pbk4HgjzvG"
local UI_Theme = "Dark"

local PlaceIDs = {}

makefolder(Hub)

local UI = loadstring(game:HttpGet(
	"https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
))()

local cloneref = cloneref or function(i) return i end
local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))
local AssetService = cloneref(game:GetService("AssetService"))
local Request = http_request or request or syn.request or http

-- PlaceId detection (optional, safe to keep)
local GamePlacesPages = AssetService:GetGamePlacesAsync()
local Pages = GamePlacesPages:GetCurrentPage()

while true do
	for _, place in ipairs(Pages) do
		if PlaceIDs[tostring(place.PlaceId)] then
			break
		end
	end
	if GamePlacesPages.IsFinished then
		break
	end
	GamePlacesPages:AdvanceToNextPageAsync()
	Pages = GamePlacesPages:GetCurrentPage()
end

local function notify(title, content, duration)
	UI:Notify({
		Title = title,
		Content = content,
		Duration = duration or 8
	})
end

-- UI Window
local Window = UI:CreateWindow({
	Title = Hub,
	SubTitle = "Loader",
	TabWidth = 160,
	Size = UDim2.fromOffset(580, 320),
	Acrylic = false,
	Theme = UI_Theme,
	MinimizeKey = Enum.KeyCode.End,
})

local Tabs = {
	Main = Window:AddTab({ Title = "Main", Icon = "" })
}

Tabs.Main:AddButton({
	Title = "Join Discord",
	Callback = function()
		setclipboard("https://discord.gg/" .. Discord_Invite)
		notify("Copied To Clipboard", "discord.gg/" .. Discord_Invite, 16)

		Request({
			Url = "http://127.0.0.1:6463/rpc?v=1",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["origin"] = "https://discord.com"
			},
			Body = HttpService:JSONEncode({
				cmd = "INVITE_BROWSER",
				args = { code = Discord_Invite },
				nonce = "."
			}),
		})
	end,
})

Window:SelectTab(1)
notify(Hub, "Loaded successfully (No key required)")
