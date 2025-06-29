local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
        Title = "donware",
        Footer = "version: yoza",
        Icon = 7229442422,
        NotifySide = "Right",
        ShowCustomCursor = false,
        Center = true,
        AutoShow = true,
        Resizable = true,
    })

local Tabs = {
    Main = Window:AddTab("Main", "pickaxe"),
    Shop = Window:AddTab("Shop", "dollar-sign"),
    Teleport = Window:AddTab("Teleport", "map-pin"),
    Misc = Window:AddTab("Misc", "mic"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

    --//--
local pcall
    = pcall

for _, SkibidiConnection in getconnections(game:GetService("Players").LocalPlayer.Idled) do
    pcall(SkibidiConnection.Disable   , SkibidiConnection)
    pcall(SkibidiConnection.Disconnect, SkibidiConnection)
end
-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")


local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local DigFinishedRemote = ReplicatedStorage.Remotes.Dig_Finished
local SellRemote = ReplicatedStorage.DialogueRemotes.SellAllItems

local function CreatePart(Name, Shape, Size)
    return {
        ["Color"] = nil,
        ["Transparency"] = 0,
        ["Name"] = Name,
        ["Position"] = Vector3.new(0, 0, 0),
        ["Orientation"] = Vector3.new(0, 0, 0),
        ["Material"] = Enum.Material.Pebble,
        ["Shape"] = Shape,
        ["Size"] = Size
    }
end

local digArgs = {
    [1] = 0,
    [2] = {
        {
            ["Color"] = nil,
            ["Transparency"] = 1,
            ["Name"] = "PositionPart",
            ["Position"] = Vector3.new(0, 0, 0),
            ["Orientation"] = Vector3.new(0, 0, 0),
            ["Material"] = Enum.Material.Plastic,
            ["Shape"] = Enum.PartType.Block,
            ["Size"] = Vector3.new(0.1, 0.1, 0.1)
        },
        CreatePart("CenterCylinder", Enum.PartType.Cylinder, Vector3.new(0.2, 5.3, 5.08))
    }
}

local sellArgs = {
    [1] = workspace.World.NPCs.Rocky
}

-- Create groupboxes
local DigGroup = Tabs.Main:AddLeftGroupbox("Dig Features", "shovel")
local ShopGroup = Tabs.Shop:AddLeftGroupbox("Shop Features", "dollar-sign")

-- Variables
local autoFarmClickLoop
local autoFarmInstantConnection

-- Auto Farm Toggle
DigGroup:AddToggle("AutoFarm", {
    Text = "Auto Farm",
    Default = false,
    Tooltip = "Automatically farms by clicking and completing digs",
    Callback = function(state)
        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

        if state then
            -- Equip shovel if not equipped
            if not LocalPlayer.Character:FindFirstChildOfClass("Tool") then
                for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                    if tool:IsA("Tool") and string.lower(tool.Name):find("shovel") then
                        tool.Parent = LocalPlayer.Character
                        break
                    end
                end
            end

            autoFarmClickLoop = RunService.RenderStepped:Connect(function()
                if not PlayerGui:FindFirstChild("Dig") then
                    local screenX = workspace.CurrentCamera.ViewportSize.X / 2
                    local screenY = workspace.CurrentCamera.ViewportSize.Y / 2
                    VirtualInputManager:SendMouseButtonEvent(screenX, screenY, 0, true, game, 0)
                    VirtualInputManager:SendMouseButtonEvent(screenX, screenY, 0, false, game, 0)
                end
            end)

            if PlayerGui:FindFirstChild("Dig") then
                task.delay(1.6, function()
                    if Toggles.AutoFarm.Value and PlayerGui:FindFirstChild("Dig") then
                        DigFinishedRemote:FireServer(unpack(digArgs))
                    end
                end)
            end

            autoFarmInstantConnection = PlayerGui.ChildAdded:Connect(function(child)
                if child.Name == "Dig" and Toggles.AutoFarm.Value then
                    task.delay(1.6, function()
                        if Toggles.AutoFarm.Value and PlayerGui:FindFirstChild("Dig") then
                            DigFinishedRemote:FireServer(unpack(digArgs))
                        end
                    end)
                end
            end)
        else
            if autoFarmClickLoop then
                autoFarmClickLoop:Disconnect()
                autoFarmClickLoop = nil
            end
            if autoFarmInstantConnection then
                autoFarmInstantConnection:Disconnect()
                autoFarmInstantConnection = nil
            end
            if humanoid then
                humanoid:UnequipTools()
            end
        end
    end
})

--dig while moving
local moveWhileDiggingConnection

DigGroup:AddToggle("MoveWhileDigging", {
    Text = "Move",
    Default = false,
    Tooltip = "Allows you to move while the dig UI is open.",
    Callback = function(state)
        if state then
            moveWhileDiggingConnection = RunService.RenderStepped:Connect(function()
                local char = LocalPlayer.Character
                if char then
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        -- Restore movement if disabled
                        if humanoid.WalkSpeed < 16 then
                            humanoid.WalkSpeed = 16
                        end
                        if humanoid.JumpPower < 50 then
                            humanoid.JumpPower = 50
                        end
                        -- Unanchor if anchored
                        if char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Anchored then
                            char.HumanoidRootPart.Anchored = false
                        end
                    end
                end
            end)
        else
            if moveWhileDiggingConnection then
                moveWhileDiggingConnection:Disconnect()
                moveWhileDiggingConnection = nil
            end
        end
    end
})

-- Shop Features
ShopGroup:AddButton({
    Text = "Sell All",
    Func = function()
        SellRemote:FireServer(unpack(sellArgs))
    end,
    Tooltip = "Sells all items in your inventory"
})

ShopGroup:AddToggle("AutoSell", {
    Text = "Auto Sell All",
    Default = false,
    Tooltip = "Automatically sells all items every 0.5 seconds",
    Callback = function(state)
        if state then
            task.spawn(function()
                while Toggles.AutoSell.Value do
                    SellRemote:FireServer(unpack(sellArgs))
                    task.wait(0.5)
                end
            end)
        end
    end
})

local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
    MenuGroup:AddToggle("KeybindMenuOpen", {
        Default = Library.KeybindFrame.Visible, Text = "Open Keybind Menu",
        Callback = function(v) Library.KeybindFrame.Visible = v end
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
    MenuGroup:AddLabel("Menu bind")
        :AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })

    MenuGroup:AddButton("Unload", function()
        for _, toggle in pairs(Toggles) do if toggle.SetValue then toggle:SetValue(false) end end
        Library:Unload()
    end)

    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    SaveManager:SetFolder("donworry/saves")
    SaveManager:BuildConfigSection(Tabs["UI Settings"])
    ThemeManager:ApplyToTab(Tabs["UI Settings"])
    task.wait(0.5)
    SaveManager:LoadAutoloadConfig()
