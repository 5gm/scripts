-- Wait for the game to load
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Service getter using cloneref for security
get_service = setmetatable({}, {
    __index = function(self, index)
        return cloneref(game.GetService(game, index))
    end
})

-- Fetch services with cloneref
local proximityprompt_service = get_service.ProximityPromptService
local marketplace_service = get_service.MarketplaceService
local user_input_service = get_service.UserInputService
local virtual_user = get_service.VirtualUser

-- Initialize UI Library
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

-- Disable existing anti-afk connections
local pcall = pcall
for _, SkibidiConnection in getconnections(game:GetService("Players").LocalPlayer.Idled) do
    pcall(SkibidiConnection.Disable, SkibidiConnection)
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
local backpack = LocalPlayer.Backpack

-- World folder checks
local world = workspace:FindFirstChild("World")
if not world then
    return LocalPlayer:Kick("World folder not found!")
end

local npcs = world:FindFirstChild("NPCs")
if not npcs then
    return LocalPlayer:Kick("NPCs folder not found!")
end

local zones = world:FindFirstChild("Zones") and world.Zones:FindFirstChild("_Ambience")
if not zones then
    return LocalPlayer:Kick("Zones folder not found!")
end

local hole_folders = world:FindFirstChild("Zones") and world.Zones:FindFirstChild("_NoDig")
if not hole_folders then
    return LocalPlayer:Kick("Holes folder not found!")
end

local totems = workspace:FindFirstChild("Active") and workspace.Active:FindFirstChild("Totems")
if not totems then
    return LocalPlayer:Kick("Totems folder not found!")
end

local bosses = workspace:FindFirstChild("Spawns") and workspace.Spawns:FindFirstChild("BossSpawns")
if not bosses then
    return LocalPlayer:Kick("Bosses folder not found!")
end

-- Variables
local staff_option = "Notify"
local dig_method = "Fire Signal"
local dig_option = "Legit"
local auto_sell_delay = 5
local tp_walk_speed = 10
local sell_delay = 0.5

local auto_pizza = false
local anti_staff = false
local auto_sell = false
local auto_hole = false
local inf_jump = false
local anti_afk = false
local auto_dig = false
local tp_walk = false
local tweeksiscute = false

-- Utility functions
function get_tool()
    return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
end

function closest_totem()
    local totem = nil
    local dist = 9e99
    for _, v in totems:GetChildren() do
        if v:GetAttribute("IsActive") then
            local distance = (v:GetPivot().Position - LocalPlayer.Character:GetPivot().Position).Magnitude
            if distance < dist then
                dist = distance
                totem = v
            end
        end
    end
    return totem
end

function is_staff(v)
    local rank = v:GetRankInGroup(35289532)
    local role = v:GetRoleInGroup(35289532)
    if rank >= 2 then
        if staff_option == "Kick" then
            LocalPlayer:Kick(role.." detected! Username: "..v.DisplayName)
        elseif staff_option == "Notify" then
            Library:Notify({
                Title = "Staff Detected!",
                Description = role.." detected! Username: "..v.DisplayName,
                Time = 5
            })
        end
    end
end

-- Remote events
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
local FarmGroup = Tabs.Main:AddRightGroupbox("Farm Features", "tractor")
local ShopGroup = Tabs.Shop:AddLeftGroupbox("Shop Features", "dollar-sign")
local MiscGroup = Tabs.Misc:AddLeftGroupbox("Misc Features", "cog")
local StaffGroup = Tabs.Misc:AddRightGroupbox("Staff Settings", "shield")
local TeleportGroup = Tabs.Teleport:AddLeftGroupbox("Teleport", "map-pin")

-- Variables for connections
local autoFarmClickLoop
local autoFarmInstantConnection
local dig_connection
local anti_afk_connection
local movement_connection
local player_join_connection

-- Enhanced Auto Dig Toggle
DigGroup:AddToggle("AutoDig", {
    Text = "Auto Dig Minigame",
    Default = false,
    Tooltip = "Automatically completes dig minigames",
    Callback = function(state)
        auto_dig = state
        if state then
            dig_connection = PlayerGui.ChildAdded:Connect(function(v)
                if auto_dig and not auto_pizza and v.Name == "Dig" then
                    local strong_hit = v:FindFirstChild("Safezone"):FindFirstChild("Holder"):FindFirstChild("Area_Strong")
                    local player_bar = v:FindFirstChild("Safezone"):FindFirstChild("Holder"):FindFirstChild("PlayerBar")
                    local mobile_button = v:FindFirstChild("MobileClick")
                    local minigame_connection = player_bar:GetPropertyChangedSignal("Position"):Connect(function()
                        if not auto_dig or auto_pizza then return end
                        if dig_option == "Legit" and math.abs(player_bar.Position.X.Scale - strong_hit.Position.X.Scale) <= 0.04 then
                            if dig_method == "Fire Signal" then
                                firesignal(mobile_button.Activated)
                                task.wait()
                            elseif dig_method == "Tool Activate" then
                                local tool = get_tool()
                                if tool then
                                    tool:Activate()
                                    task.wait()
                                end
                            end
                        elseif dig_option == "Blatant" then
                            player_bar.Position = UDim2.new(strong_hit.Position.X.Scale, 0, 0, 0)
                            if dig_method == "Fire Signal" then
                                firesignal(mobile_button.Activated)
                                task.wait()
                            elseif dig_method == "Tool Activate" then
                                local tool = get_tool()
                                if tool then
                                    tool:Activate()
                                    task.wait()
                                end
                            end
                        end
                    end)
                end
            end)
        else
            if dig_connection then
                dig_connection:Disconnect()
                dig_connection = nil
            end
        end
    end
})

DigGroup:AddDropdown("DigOption", {
    Values = {"Legit", "Blatant"},
    Default = "Legit",
    Text = "Dig Option",
    Callback = function(value)
        dig_option = value
    end
})

DigGroup:AddDropdown("DigMethod", {
    Values = {"Fire Signal", "Tool Activate"},
    Default = "Fire Signal",
    Text = "Dig Method",
    Callback = function(value)
        dig_method = value
    end
})

-- Auto Farm Toggle (Original)
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

-- Auto Holes
DigGroup:AddToggle("AutoHoles", {
    Text = "Auto Holes",
    Default = false,
    Tooltip = "Creates holes if not in dig minigame",
    Callback = function(state)
        auto_hole = state
        if state then
            task.spawn(function()
                repeat
                    if not auto_pizza then
                        local tool = get_tool()
                        if not tool or not tool.Name:find("Shovel") then
                            for _, v in backpack:GetChildren() do
                                if v.Name:find("Shovel") then
                                    v.Parent = LocalPlayer.Character
                                end
                            end
                        end
                        if hole_folders:FindFirstChild(LocalPlayer.Name.."_Crater_Hitbox") then
                            hole_folders[LocalPlayer.Name.."_Crater_Hitbox"]:Destroy()
                        end
                        if not LocalPlayer.PlayerGui:FindFirstChild("Dig") then
                            tool:Activate()
                        end
                    end
                    task.wait(.5)
                until not auto_hole
            end)
        end
    end
})

--dig while moving
local moveWhileDiggingConnection

DigGroup:AddToggle("MoveWhileDigging", {
    Text = "Move While Digging",
    Default = false,
    Tooltip = "Allows you to move while the dig UI is open",
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

-- Farm Features
FarmGroup:AddToggle("AutoPizza", {
    Text = "Auto Pizza Delivery",
    Default = false,
    Tooltip = "Automatically does pizza deliveries",
    Callback = function(state)
        auto_pizza = state
        if state then
            task.spawn(function()
                repeat
                    ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Change_Zone"):FireServer("Penguins Pizza")
                    ReplicatedStorage:WaitForChild("DialogueRemotes"):WaitForChild("StartInfiniteQuest"):InvokeServer("Pizza Penguin")
                    wait(math.random(1, 3))
                    LocalPlayer.Character:MoveTo(workspace:FindFirstChild("Active"):FindFirstChild("PizzaCustomers"):FindFirstChildOfClass("Model"):GetPivot().Position)
                    wait(math.random(2, 5))
                    ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Quest_DeliverPizza"):InvokeServer()
                    wait(math.random(1, 3))
                    ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Change_Zone"):FireServer("Penguins Pizza")
                    ReplicatedStorage:WaitForChild("DialogueRemotes"):WaitForChild("CompleteInfiniteQuest"):InvokeServer("Pizza Penguin")
                    task.wait(math.random(60, 90))
                until not auto_pizza
            end)
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
                    task.wait(sell_delay)
                end
            end)
        end
    end
})

ShopGroup:AddSlider("SellDelay", {
    Text = "Auto Sell Delay",
    Default = 0.5,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Compact = false,
    Callback = function(value)
        sell_delay = value
    end
})

ShopGroup:AddButton({
    Text = "Sell All Items Once",
    Func = function()
        for _, v in backpack:GetChildren() do
            ReplicatedStorage:WaitForChild("DialogueRemotes"):WaitForChild("SellHeldItem"):FireServer(v)
        end
    end,
    Tooltip = "Sells all items in your inventory once"
})

ShopGroup:AddButton({
    Text = "Sell Held Item",
    Func = function()
        local tool = get_tool()
        if not tool then
            return Library:Notify({
                Title = "No Tool",
                Description = "No Tool Found!",
                Time = 3
            })
        end
        if not tool:GetAttribute("InventoryLink") then
            return Library:Notify({
                Title = "Can't Sell!",
                Description = "Can't Sell This Item!",
                Time = 3
            })
        end
        ReplicatedStorage:WaitForChild("DialogueRemotes"):WaitForChild("SellHeldItem"):FireServer(tool)
    end,
    Tooltip = "Sells the currently held item"
})

ShopGroup:AddButton({
    Text = "Claim Unclaimed Discovered Items",
    Func = function()
        for _, v in LocalPlayer.PlayerGui:FindFirstChild("HUD"):FindFirstChild("Frame"):FindFirstChild("Journal"):FindFirstChild("Scroller"):GetChildren() do
            if v:IsA("ImageButton") and v:FindFirstChild("Discovered").Visible then
                firesignal(v.MouseButton1Click)
            end
        end
    end,
    Tooltip = "Claims every unclaimed discovered item in journal"
})

-- Staff Settings
StaffGroup:AddToggle("AntiStaff", {
    Text = "Anti Staff",
    Default = false,
    Tooltip = "Kicks/Notifies you when staff joins",
    Callback = function(state)
        anti_staff = state
        if state then
            for _, v in Players:GetPlayers() do
                if v ~= LocalPlayer then
                    is_staff(v)
                end
            end
            player_join_connection = Players.PlayerAdded:Connect(function(v)
                if anti_staff then
                    is_staff(v)
                end
            end)
        else
            if player_join_connection then
                player_join_connection:Disconnect()
                player_join_connection = nil
            end
        end
    end
})

StaffGroup:AddDropdown("StaffMethod", {
    Values = {"Notify", "Kick"},
    Default = "Notify",
    Text = "Staff Method",
    Callback = function(value)
        staff_option = value
    end
})

-- Misc Features
MiscGroup:AddToggle("AntiAfk", {
    Text = "Anti AFK",
    Default = false,
    Tooltip = "Won't disconnect you after 20 minutes",
    Callback = function(state)
        anti_afk = state
        if state then
            anti_afk_connection = LocalPlayer.Idled:Connect(function()
                if anti_afk then
                    virtual_user:CaptureController()
                    virtual_user:ClickButton2(Vector2.new())
                end
            end)
        else
            if anti_afk_connection then
                anti_afk_connection:Disconnect()
                anti_afk_connection = nil
            end
        end
    end
})

MiscGroup:AddToggle("InfJump", {
    Text = "Infinite Jump",
    Default = false,
    Tooltip = "Lets you jump infinitely",
    Callback = function(state)
        inf_jump = state
        if state then
            user_input_service.JumpRequest:Connect(function()
                if inf_jump and not tweeksiscute then
                    tweeksiscute = true
                    LocalPlayer.Character:FindFirstChild("Humanoid"):ChangeState("Jumping")
                    wait()
                    tweeksiscute = false
                end
            end)
        end
    end
})

MiscGroup:AddToggle("TpWalk", {
    Text = "TP Walk",
    Default = false,
    Tooltip = "Lets you move fast",
    Callback = function(state)
        tp_walk = state
        if state then
            movement_connection = RunService.Heartbeat:Connect(function()
                if tp_walk and LocalPlayer.Character:FindFirstChild("Humanoid") then
                    if LocalPlayer.Character.Humanoid.MoveDirection.Magnitude > 0 then
                        LocalPlayer.Character:TranslateBy(LocalPlayer.Character.Humanoid.MoveDirection * tp_walk_speed / 10)
                    end
                end
            end)
        else
            if movement_connection then
                movement_connection:Disconnect()
                movement_connection = nil
            end
        end
    end
})

MiscGroup:AddSlider("TpWalkSpeed", {
    Text = "TP Walk Speed",
    Default = 10,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Compact = false,
    Callback = function(value)
        tp_walk_speed = value
    end
})

-- Teleport Features
TeleportGroup:AddButton({
    Text = "Teleport to Merchant",
    Func = function()
        local char = LocalPlayer.Character
        local merchant = workspace:FindFirstChild("World")
            and workspace.World:FindFirstChild("NPCs")
            and workspace.World.NPCs:FindFirstChild("Merchant Cart")
        if char and char:FindFirstChild("HumanoidRootPart") and merchant and merchant.WorldPivot then
            char.HumanoidRootPart.CFrame = CFrame.new(merchant.WorldPivot.Position)
            Library:Notify({Title = "Teleported!", Description = "You have been teleported to the Merchant.", Time = 3})
        else
            Library:Notify({Title = "Teleport Failed", Description = "Merchant not found!", Time = 3})
        end
    end,
    Tooltip = "Teleport directly to the Merchant Cart"
})

TeleportGroup:AddButton({
    Text = "Teleport to Meteor",
    Func = function()
        if workspace:FindFirstChild("Active"):FindFirstChild("ActiveMeteor") then
            LocalPlayer.Character:MoveTo(workspace.Active.ActiveMeteor:GetPivot().Position)
            Library:Notify({Title = "Teleported!", Description = "Teleported to meteor.", Time = 3})
        else
            Library:Notify({Title = "No Meteor", Description = "No meteor found!", Time = 3})
        end
    end,
    Tooltip = "Teleports to meteor"
})

TeleportGroup:AddButton({
    Text = "Teleport to Enchantment Altar",
    Func = function()
        LocalPlayer.Character:MoveTo(world:FindFirstChild("Interactive"):FindFirstChild("Enchanting"):FindFirstChild("EnchantmentAltar"):FindFirstChild("EnchantPart"):GetPivot().Position)
        Library:Notify({Title = "Teleported!", Description = "Teleported to Enchantment Altar.", Time = 3})
    end,
    Tooltip = "Teleports to EnchantmentAltar"
})

TeleportGroup:AddButton({
    Text = "Teleport to Active Totem",
    Func = function()
        local totem = closest_totem()
        if not totem then
            return Library:Notify({Title = "No Totem", Description = "No Active Totem Found!", Time = 3})
        end
        LocalPlayer.Character:MoveTo(totem:GetPivot().Position)
        Library:Notify({Title = "Teleported!", Description = "Teleported to active totem.", Time = 3})
    end,
    Tooltip = "Teleports to closest active totem"
})

-- UI Settings
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
    SaveManager:LoadAutoloadConfig()
