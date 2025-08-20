-- Auto-delete specific gate parts
local gatePaths = {
    {"RhinoArea", "MainPart"},
    {"SmallMountain", "MainPart"},
    {"MushroomArea", "MainPart"},
    {"MontainTop", "InteractPoint"},
    {"Cave", "MainPart"},
    {"BuyEggsGate", "MainPart"},
    {"Armor", "MainPart"},
}
local Models = workspace:FindFirstChild("__Things")
    and workspace.__Things:FindFirstChild("Client")
    and workspace.__Things.Client:FindFirstChild("Gates")
    and workspace.__Things.Client.Gates:FindFirstChild("Models")
if Models then
    for _, path in ipairs(gatePaths) do
        local folder = Models:FindFirstChild(path[1])
        if folder then
            local part = folder:FindFirstChild(path[2])
            if part then
                part:Destroy()
            end
        end
    end
end

-- Minimal Rayfield UI: Click All Flowers button
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Bee Paradise | Flower Clicker",
    LoadingTitle = "Flower Clicker",
    LoadingSubtitle = "Rayfield UI",
    ConfigurationSaving = {
        Enabled = false
    },
    KeySystem = false,
})

local Main = Window:CreateTab("Main")

-- Auto re-exec across server hops
local RELOAD_URL = "" -- set a raw URL to this script for auto re-exec (e.g., Pastebin raw/Gist raw)
local function queueSelfForTeleport()
    local q = (syn and syn.queue_on_teleport) or queue_on_teleport
    if not q then
        Rayfield:Notify({ Title = "Teleport Queue", Content = "queue_on_teleport not supported by executor.", Duration = 4 })
        return false
    end
    if not RELOAD_URL or RELOAD_URL == "" then
        Rayfield:Notify({ Title = "Teleport Queue", Content = "Set Reload URL first.", Duration = 4 })
        return false
    end
    local code = ("loadstring(game:HttpGet(%q))()" ):format(RELOAD_URL)
    q(code)
    Rayfield:Notify({ Title = "Teleport Queue", Content = "Menu queued to re-exec on next server.", Duration = 3 })
    return true
end

-- UI to set reload URL and queue it
Main:CreateInput({
    Name = "Reload URL",
    PlaceholderText = "https://raw.githubusercontent.com/user/repo/bee-paradise.lua",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        RELOAD_URL = text or ""
    end
})

Main:CreateButton({
    Name = "Queue Re-Exec On Teleport",
    Callback = queueSelfForTeleport
})

-- Egg opening UI
local eggNames = {
    "Basic Egg",
    "Flower Egg",
    "Golden Egg",
    "Mountain Egg",
    "Mushroom Egg",
    "Rhino Egg",
    "Silver Egg",
    "Ticket Egg",
    "_Meme Egg",
}
local selectedEgg = eggNames[1]

-- Change this to the actual remote path if needed
local openEggRemote = workspace:FindFirstChild("__Remotes") and workspace.__Remotes:FindFirstChild("OpenEgg")

Main:CreateDropdown({
    Name = "Select Egg",
    Options = eggNames,
    CurrentOption = selectedEgg,
    Flag = "EggDropdown",
    Callback = function(option)
        selectedEgg = option
    end
})

Main:CreateButton({
    Name = "Open Selected Egg",
    Callback = function()
        if openEggRemote and selectedEgg then
            openEggRemote:FireServer(selectedEgg)
            Rayfield:Notify({
                Title = "Egg Opened",
                Content = "Requested to open: " .. tostring(selectedEgg),
                Duration = 3
            })
        else
            Rayfield:Notify({
                Title = "Error",
                Content = "Remote or egg not found!",
                Duration = 3
            })
        end
    end
})

-- Server Hop function
local function serverHop()
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local Players = game:GetService("Players")
    local gameId = 75617046546428
    local currentJobId = game.JobId
    local cursor = ""
    local found = false
    local tries = 0
    while not found and tries < 5 do
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100%s"):format(gameId, cursor ~= "" and ("&cursor="..cursor) or "")
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        if success and result and result.data then
            local servers = result.data
            local possible = {}
            for _, server in ipairs(servers) do
                if server.playing < server.maxPlayers and server.id ~= currentJobId then
                    table.insert(possible, server.id)
                end
            end
            if #possible > 0 then
                -- Ensure our script re-executes after teleport
                queueSelfForTeleport()
                local chosen = possible[math.random(1, #possible)]
                TeleportService:TeleportToPlaceInstance(gameId, chosen, Players.LocalPlayer)
                found = true
                break
            end
            cursor = result.nextPageCursor or ""
            if cursor == "" then break end
        else
            break
        end
        tries = tries + 1
    end
    if not found then
        Rayfield:Notify({
            Title = "Server Hop",
            Content = "No available servers found.",
            Duration = 4
        })
    end
end

-- Also queue at startup if a URL is already set
task.spawn(function()
    if RELOAD_URL ~= "" then
        pcall(queueSelfForTeleport)
    end
end)

local autoClickEnabled = false
local autoClickThread = nil
local clickDelay = 0.5 -- seconds between passes

local function clickAllFlowersOnce()
    local MAP = workspace:FindFirstChild("MAP") or workspace:WaitForChild("MAP")
    local Areas = MAP:FindFirstChild("Areas") or MAP:WaitForChild("Areas")
    for _, area in ipairs(Areas:GetChildren()) do
        local flowerSpawn = area:FindFirstChild("FlowerSpawn")
        local spawns = flowerSpawn and flowerSpawn:FindFirstChild("Spawns")
        if spawns then
            for _, d in ipairs(spawns:GetDescendants()) do
                if d:IsA("ClickDetector") then
                    pcall(function()
                        d.MaxActivationDistance = math.huge
                    end)
                    if syn and syn.fireclickdetector then
                        syn.fireclickdetector(d)
                    elseif fireclickdetector then
                        fireclickdetector(d)
                    end
                end
            end
        end
    end
end

local function startAutoClick()
    if autoClickThread then return end
    autoClickThread = task.spawn(function()
        while autoClickEnabled do
            clickAllFlowersOnce()
            task.wait(clickDelay)
        end
        autoClickThread = nil
    end)
end

local function stopAutoClick()
    autoClickEnabled = false
end

Main:CreateToggle({
    Name = "Auto Click Flowers",
    CurrentValue = false,
    Flag = "AutoClickFlowersToggle",
    Callback = function(Value)
        autoClickEnabled = Value
        if Value then
            startAutoClick()
        else
            stopAutoClick()
        end
    end
})

Main:CreateButton({
    Name = "Server Hop",
    Callback = serverHop
})
