local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
    Title = "donworry",
    Footer = "yoza",
    Icon = 7229442422,
    NotifySide = "Right",
    ShowCustomCursor = false,
})

for _, SkibidiConnection in getconnections(game:GetService("Players").LocalPlayer.Idled) do
    pcall(SkibidiConnection.Disable, SkibidiConnection)
    pcall(SkibidiConnection.Disconnect, SkibidiConnection)
end

for i = 1, 7 do
    local door = workspace:FindFirstChild("FishingZone" .. (i == 1 and "" or tostring(i)) .. "Door")
    if door then door:Destroy() end
end

local fishingDoor = workspace:FindFirstChild("FishingDoor")
if fishingDoor then fishingDoor:Destroy() end

local gifted = game:GetService("Players").LocalPlayer:FindFirstChild("GiftedGamepasses")
if gifted then
    for _, v in ipairs(gifted:GetChildren()) do
        if v:IsA("BoolValue") then
            v.Value = true
        end
    end
end

local Tabs = {
    Main = Window:AddTab("Main", "pickaxe"),
    Fishing = Window:AddTab("Fishing", "fish"),
    Settings = Window:AddTab("Settings", "settings"),
}

local OreGroup = Tabs.Main:AddLeftGroupbox("Ore Farming", "gem")

OreGroup:AddToggle("AutoEquipBest", {
    Text = "Auto Farm Ore",
    Default = false,
    Tooltip = "Automatically farms ore using the main farming method",
    Callback = function(Value)
        if Value then
            getgenv().AutoEquipBestConnection = task.spawn(function()
                local Event = game:GetService("ReplicatedStorage").TouchBlock
                while Toggles.AutoEquipBest.Value do
                    Event:FireServer(
                        (function(bytes)
                            local b = buffer.create(#bytes)
                            for i = 1, #bytes do
                                buffer.writeu8(b, i - 1, bytes[i])
                            end
                            return b
                        end)({ 164, 206, 202, 207, 209, 207, 201, 205, 202, 211, 205, 200, 209, 207, 198, 205, 199, 202, 199, 198, 198, 206, 203, 207, 206, 204, 211, 221, 164, 172, 154, 141, 137, 154, 141, 162, 197, 223, 155, 158, 153, 136, 139, 202, 205, 204, 202, 205, 202, 204, 205, 223, 156, 144, 147, 147, 154, 156, 139, 154, 155, 223, 195, 153, 144, 145, 139, 223, 156, 144, 147, 144, 141, 194, 216, 141, 152, 157, 215, 206, 203, 203, 211, 206, 204, 206, 211, 206, 206, 198, 214, 216, 193, 188, 147, 158, 134, 223, 215, 171, 150, 154, 141, 223, 202, 214, 195, 208, 153, 144, 145, 139, 193, 223, 131, 223, 215, 188, 151, 158, 145, 156, 154, 197, 223, 206, 208, 207, 209, 207, 204, 214, 221, 211, 202, 211, 206, 211, 221, 188, 147, 158, 134, 221, 211, 198, 203, 200, 207, 199, 204, 198, 211, 221, 177, 144, 141, 146, 158, 147, 221, 162, 20, 96, 206, 221 }),
                        (function(bytes)
                            local b = buffer.create(#bytes)
                            for i = 1, #bytes do
                                buffer.writeu8(b, i - 1, bytes[i])
                            end
                            return b
                        end)({ 164, 172, 154, 141, 137, 154, 141, 162, 197, 223, 155, 158, 153, 136, 139, 202, 205, 204, 202, 205, 202, 204, 205, 223, 156, 144, 147, 147, 154, 156, 139, 154, 155, 223, 195, 153, 144, 145, 139, 223, 156, 144, 147, 144, 141, 194, 216, 141, 152, 157, 215, 206, 203, 203, 211, 206, 204, 206, 211, 206, 206, 198, 214, 216, 193, 188, 147, 158, 134, 223, 215, 171, 150, 154, 141, 223, 202, 214, 195, 208, 153, 144, 145, 139, 193, 223, 131, 223, 215, 188, 151, 158, 145, 156, 154, 197, 223, 206, 208, 207, 209, 207, 204, 214, 158, 197, 32, 53 })
                    )
                    task.wait(0.001)
                end
            end)
        else
            if getgenv().AutoEquipBestConnection then
                task.cancel(getgenv().AutoEquipBestConnection)
                getgenv().AutoEquipBestConnection = nil
            end
        end
    end
})

OreGroup:AddToggle("FarmAllOres", {
    Text = "Farm All Ores (use both)",
    Default = false,
    Tooltip = "Alternative ore farming method using touch detection",
    Callback = function(Value)
        if Value then
            getgenv().FarmAllOresConnection = task.spawn(function()
                local OreFolder = workspace:WaitForChild("OreFolder")
                local player = game.Players.LocalPlayer
                while Toggles.FarmAllOres.Value do
                    local character = player.Character or player.CharacterAdded:Wait()
                    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart")
                    for _, ore in ipairs(OreFolder:GetChildren()) do
                        local touchInterest = ore:FindFirstChild("TouchInterest")
                        if touchInterest then
                            pcall(function()
                                firetouchinterest(humanoidRootPart, touchInterest.Parent, 0)
                                task.wait()
                                firetouchinterest(humanoidRootPart, touchInterest.Parent, 1)
                            end)
                        end
                    end
                    task.wait(0.5)
                end
            end)
        else
            if getgenv().FarmAllOresConnection then
                task.cancel(getgenv().FarmAllOresConnection)
                getgenv().FarmAllOresConnection = nil
            end
        end
    end
})

local ProcessingGroup = Tabs.Main:AddRightGroupbox("Processing", "settings")

ProcessingGroup:AddToggle("AutoGrinder", {
    Text = "Auto Grinder",
    Default = false,
    Tooltip = "Automatically processes ore using the grinder",
    Callback = function(Value)
        if Value then
            getgenv().AutoGrinderConnection = task.spawn(function()
                local Event = game:GetService("ReplicatedStorage"):WaitForChild("GrinderTouch")
                while Toggles.AutoGrinder.Value do
                    pcall(function()
                        Event:FireServer("Amethyst", 11)
                    end)
                    task.wait(0.001)
                end
            end)
        else
            if getgenv().AutoGrinderConnection then
                task.cancel(getgenv().AutoGrinderConnection)
                getgenv().AutoGrinderConnection = nil
            end
        end
    end
})

local FishingGroup = Tabs.Fishing:AddLeftGroupbox("Fishing", "fish")

FishingGroup:AddToggle("AutoFishAnywhere", {
    Text = "Auto Fish (Best)",
    Default = false,
    Tooltip = "Automatically fishes the best fish anywhere",
    Callback = function(Value)
        if Value then
            getgenv().AutoFishAnywhereConnection = task.spawn(function()
                local Event = game:GetService("ReplicatedStorage"):WaitForChild("Fishing")
                local bufferData = { 164, 221, 171, 141, 138, 146, 143, 154, 139, 153, 150, 140, 151, 221, 211, 221, 173, 158, 141, 154, 221, 211, 204, 207, 211, 203, 205, 206, 207, 198, 203, 204, 211, 206, 162, 115, 245, 50, 238 }
                while Toggles.AutoFishAnywhere.Value do
                    pcall(function()
                        Event:FireServer(
                            (function(bytes)
                                local b = buffer.create(#bytes)
                                for i = 1, #bytes do
                                    buffer.writeu8(b, i - 1, bytes[i])
                                end
                                return b
                            end)(bufferData),
                            "0"
                        )
                    end)
                    task.wait(0.1)
                end
            end)
        else
            if getgenv().AutoFishAnywhereConnection then
                task.cancel(getgenv().AutoFishAnywhereConnection)
                getgenv().AutoFishAnywhereConnection = nil
            end
        end
    end
})

local SellingGroup = Tabs.Fishing:AddRightGroupbox("Selling", "dollar-sign")

SellingGroup:AddToggle("SellAllFishToggle", {
    Text = "Auto Sell Fish",
    Default = false,
    Tooltip = "Automatically sells all fish in inventory",
    Callback = function(Value)
        if Value then
            getgenv().SellAllFishToggleConnection = task.spawn(function()
                local Event = game:GetService("ReplicatedStorage"):WaitForChild("SellAllFish")
                while Toggles.SellAllFishToggle.Value do
                    pcall(function()
                        Event:FireServer()
                    end)
                    task.wait(1)
                end
            end)
        else
            if getgenv().SellAllFishToggleConnection then
                task.cancel(getgenv().SellAllFishToggleConnection)
                getgenv().SellAllFishToggleConnection = nil
            end
        end
    end
})

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = Library.KeybindFrame.Visible,
    Text = "Open Keybind Menu",
    Callback = function(value)
        Library.KeybindFrame.Visible = value
    end,
})

MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom Cursor",
    Default = true,
    Callback = function(Value)
        Library.ShowCustomCursor = Value
    end,
})

MenuGroup:AddDropdown("NotificationSide", {
    Values = { "Left", "Right" },
    Default = "Right",
    Text = "Notification Side",
    Callback = function(Value)
        Library:SetNotifySide(Value)
    end,
})

MenuGroup:AddDropdown("DPIDropdown", {
    Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
    Default = "100%",
    Text = "DPI Scale",
    Callback = function(Value)
        Value = Value:gsub("%%", "")
        local DPI = tonumber(Value)
        Library:SetDPIScale(DPI)
    end,
})

MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { 
    Default = "RightShift", 
    NoUI = true, 
    Text = "Menu keybind" 
})

MenuGroup:AddButton({
    Text = "Unload Script",
    Func = function()
        Library:Unload()
    end,
    Tooltip = "Completely unloads the script"
})

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("donworry")
SaveManager:SetFolder("donworry/Ore Grinding Incremental")

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

SaveManager:LoadAutoloadConfig()
