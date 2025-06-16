local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false -- Forces AddToggle to AddCheckbox
Library.ShowToggleFrameInKeybinds = true -- Make toggle keybinds work inside the keybinds UI (aka adds a toggle to the UI). Good for mobile users (Default value = true)

local Window = Library:CreateWindow({
	Title = "donworry",
	Footer = "version: 1.0",
	Icon = 7229442422,
	NotifySide = "Right",
	ShowCustomCursor = false,
})

--//--
local pcall
    = pcall

for _, SkibidiConnection in getconnections(game:GetService("Players").LocalPlayer.Idled) do
    pcall(SkibidiConnection.Disable   , SkibidiConnection)
    pcall(SkibidiConnection.Disconnect, SkibidiConnection)
end
--//--

local Tabs = {
    Main = Window:AddTab("Main", "user"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

local Farming = Tabs.Main:AddLeftGroupbox("Farming", "swords")
local Groupbox = Tabs.Main:AddRightGroupbox("Auto Equip", "candy")
local RewardsGroupbox = Tabs.Main:AddRightGroupbox("Rewards", "gift")

Groupbox:AddToggle("AutoEquipBest", {
    Text = "Auto Equip Best",
    Default = false,
    Tooltip = "Automatically equips your best pets/items.",
    Callback = function(Value)
        if Value then
            getgenv().AutoEquipBestConnection = task.spawn(function()
                while Toggles.AutoEquipBest.Value do
                    game:GetService("ReplicatedStorage").Bindable.Data.PetData.EquipBest:Fire()
                    task.wait(2) -- Adjust delay as needed
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

RewardsGroupbox:AddToggle("AutoClaimRewards", {
    Text = "Auto Claim Rewards",
    Default = false,
    Tooltip = "Automatically claims passive income rewards",
    Callback = function(Value)
        if Value then
            getgenv().AutoClaimRewardsConnection = task.spawn(function()
                local Event = game:GetService("ReplicatedStorage").Remote.Data.PassiveIncomeInstant
                local player = game.Players.LocalPlayer
                while Toggles.AutoClaimRewards.Value do
                    -- Fire the remote
                    Event:FireServer()
                    -- Click the quest claim button if it exists
                    local btn = player.PlayerGui:FindFirstChild("MainGUI")
                    if btn then
                        btn = btn:FindFirstChild("HUD")
                        if btn then
                            btn = btn:FindFirstChild("CurrentQuestFrame")
                            if btn then
                                btn = btn:FindFirstChild("Tasks")
                                if btn then
                                    btn = btn:FindFirstChild("ClaimTasks")
                                    if btn then
                                        btn = btn:FindFirstChild("Button")
                                        if btn and (btn:IsA("TextButton") or btn:IsA("ImageButton")) then
                                            btn:Activate()
                                        end
                                    end
                                end
                            end
                        end
                    end
                    task.wait(2) -- Adjust delay as needed
                end
            end)
        else
            if getgenv().AutoClaimRewardsConnection then
                task.cancel(getgenv().AutoClaimRewardsConnection)
                getgenv().AutoClaimRewardsConnection = nil
            end
        end
    end
})

-- Get all unique enemy names in workspace.Worlds.Solo.Enemies
local function GetEnemyFolders()
    local folders = {}
    if workspace:FindFirstChild("Worlds") then
        if workspace.Worlds:FindFirstChild("Solo") and workspace.Worlds.Solo:FindFirstChild("Enemies") then
            table.insert(folders, workspace.Worlds.Solo.Enemies)
        end
        if workspace.Worlds:FindFirstChild("OnePiece") and workspace.Worlds.OnePiece:FindFirstChild("Enemies") then
            table.insert(folders, workspace.Worlds.OnePiece.Enemies)
        end
        if workspace.Worlds:FindFirstChild("DBZ") and workspace.Worlds.DBZ:FindFirstChild("Enemies") then
            table.insert(folders, workspace.Worlds.DBZ.Enemies)
        end
        if workspace.Worlds:FindFirstChild("DemonSlayer") and workspace.Worlds.DemonSlayer:FindFirstChild("Enemies") then
            table.insert(folders, workspace.Worlds.DemonSlayer.Enemies)
        end
    end
    return folders
end

local function GetAllEnemies()
    local all = {}
    for _, folder in ipairs(GetEnemyFolders()) do
        for _, enemy in ipairs(folder:GetChildren()) do
            table.insert(all, enemy)
        end
    end
    return all
end

local function GetEnemyNames()
    local names = {}
    local found = {}
    for _, enemy in ipairs(GetAllEnemies()) do
        if enemy.Name and not found[enemy.Name] then
            table.insert(names, enemy.Name)
            found[enemy.Name] = true
        end
    end
    return names
end

-- Autofarm Mode Dropdown
local AutofarmModeDropdown = Farming:AddDropdown("AutofarmMode", {
    Values = { "Pick Enemy", "Pick Rarity" },
    Default = "Pick Enemy",
    Text = "Autofarm Mode",
    Tooltip = "Choose to autofarm by enemy or by rarity",
    Callback = function() end,
})

-- Enemy Dropdown (already exists)
local EnemyDropdown = Farming:AddDropdown("EnemyToFarm", {
    Values = GetEnemyNames(),
    Default = 1,
    Text = "Enemy to Autofarm",
    Tooltip = "Select which enemy to autofarm",
    Multi = false,
    Callback = function() end,
})

-- Rarity Dropdown
local function GetAllRarities()
    local rarities = {}
    local found = {}
    for _, enemy in ipairs(GetAllEnemies()) do
        local meta = enemy:FindFirstChild("Metadata")
        local rarity = "Common"
        if meta and meta:FindFirstChild("Rarity") then
            rarity = meta.Rarity:GetAttribute("Value") or "Common"
        end
        if not found[rarity] then
            table.insert(rarities, rarity)
            found[rarity] = true
        end
    end
    table.sort(rarities)
    return rarities
end

local RarityDropdown = Farming:AddDropdown("RarityToFarm", {
    Values = GetAllRarities(),
    Default = 1,
    Text = "Rarity to Autofarm",
    Tooltip = "Select which rarity to autofarm",
    Multi = false,
    Callback = function() end,
})

-- Show/hide dropdowns based on mode
local function UpdateDropdownVisibility()
    local mode = Options.AutofarmMode.Value
    EnemyDropdown:SetVisible(mode == "Pick Enemy")
    RarityDropdown:SetVisible(mode == "Pick Rarity")
end
Options.AutofarmMode:OnChanged(UpdateDropdownVisibility)
UpdateDropdownVisibility()

-- Button to refresh both dropdowns
Farming:AddButton({
    Text = "Refresh Enemy/Rarity List",
    Func = function()
        Options.EnemyToFarm:SetValues(GetEnemyNames())
        Options.RarityToFarm:SetValues(GetAllRarities())
    end,
    Tooltip = "Refresh the enemy and rarity dropdown lists"
})

-- Toggle for autofarming
Farming:AddToggle("AutofarmSelectedEnemy", {
    Text = "Autofarm",
    Default = false,
    Tooltip = "Autofarms the selected enemy or rarity",
    Callback = function(Value)
        if Value then
            getgenv().AutofarmEnemyConnection = task.spawn(function()
                while Toggles.AutofarmSelectedEnemy.Value do
                    local mode = Options.AutofarmMode.Value
                    if mode == "Pick Enemy" then
                        local selected = Options.EnemyToFarm.Value
                        if selected then
                            local candidates = {}
                            for _, enemy in ipairs(GetAllEnemies()) do
                                if enemy.Name == selected and enemy:FindFirstChild("HumanoidRootPart") then
                                    table.insert(candidates, enemy)
                                end
                            end
                            if #candidates > 0 then
                                local player = game.Players.LocalPlayer
                                local char = player.Character
                                local nearest, nearestDist = nil, math.huge
                                if char and char:FindFirstChild("HumanoidRootPart") then
                                    for _, enemy in ipairs(candidates) do
                                        local dist = (char.HumanoidRootPart.Position - enemy.HumanoidRootPart.Position).Magnitude
                                        if dist < nearestDist then
                                            nearest = enemy
                                            nearestDist = dist
                                        end
                                    end
                                    local target = nearest
                                    if target then
                                        char.HumanoidRootPart.CFrame = target.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
                                        repeat
                                            task.wait(0.2)
                                        until not Toggles.AutofarmSelectedEnemy.Value
                                            or not target.Parent
                                            or (target:GetAttribute("Health") or 0) <= 0
                                    end
                                end
                            end
                        end
                    elseif mode == "Pick Rarity" then
                        local selectedRarity = Options.RarityToFarm.Value
                        if selectedRarity then
                            local candidates = {}
                            for _, enemy in ipairs(GetAllEnemies()) do
                                local meta = enemy:FindFirstChild("Metadata")
                                local rarity = "Common"
                                if meta and meta:FindFirstChild("Rarity") then
                                    rarity = meta.Rarity:GetAttribute("Value") or "Common"
                                end
                                if rarity == selectedRarity and enemy:FindFirstChild("HumanoidRootPart") then
                                    table.insert(candidates, enemy)
                                end
                            end
                            if #candidates > 0 then
                                local player = game.Players.LocalPlayer
                                local char = player.Character
                                local nearest, nearestDist = nil, math.huge
                                if char and char:FindFirstChild("HumanoidRootPart") then
                                    for _, enemy in ipairs(candidates) do
                                        local dist = (char.HumanoidRootPart.Position - enemy.HumanoidRootPart.Position).Magnitude
                                        if dist < nearestDist then
                                            nearest = enemy
                                            nearestDist = dist
                                        end
                                    end
                                    local target = nearest
                                    if target then
                                        char.HumanoidRootPart.CFrame = target.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
                                        repeat
                                            task.wait(0.2)
                                        until not Toggles.AutofarmSelectedEnemy.Value
                                            or not target.Parent
                                            or (target:GetAttribute("Health") or 0) <= 0
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.2)
                end
            end)
        else
            if getgenv().AutofarmEnemyConnection then
                task.cancel(getgenv().AutofarmEnemyConnection)
                getgenv().AutofarmEnemyConnection = nil
            end
        end
    end
})

local VirtualInputManager = game:GetService("VirtualInputManager")

Farming:AddToggle("AutoArise", {
    Text = "Auto Arise",
    Default = false,
    Tooltip = "Spams the E key when enabled",
    Callback = function(Value)
        if Value then
            getgenv().AutoAriseConnection = task.spawn(function()
                while Toggles.AutoArise.Value do
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    task.wait(0.1)
                end
            end)
        else
            if getgenv().AutoAriseConnection then
                task.cancel(getgenv().AutoAriseConnection)
                getgenv().AutoAriseConnection = nil
            end
        end
    end
})

-- UI Settings
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")

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
MenuGroup:AddLabel("Menu bind")
	:AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })

MenuGroup:AddButton("Unload", function()
	Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind -- Allows you to have a custom keybind for the menu

-- Addons:
-- SaveManager (Allows you to have a configuration system)
-- ThemeManager (Allows you to have a menu theme system)

-- Hand the library over to our managers
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

-- Ignore keys that are used by ThemeManager.
-- (we dont want configs to save themes, do we?)
SaveManager:IgnoreThemeSettings()

-- Adds our MenuKeybind to the ignore list
-- (do you want each config to have a different menu key? probably not.)
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

-- use case for doing it this way:
-- a script hub could have themes in a global folder
-- and game configs in a separate folder per game
ThemeManager:SetFolder("donworry") -- This is the folder where themes will be saved
SaveManager:SetFolder("donworry/Anime Rising")
SaveManager:SetSubFolder("specific-place") -- if the game has multiple places inside of it (for example: DOORS)
-- you can use this to save configs for those places separately
-- The path in this script would be: MyScriptHub/specific-game/settings/specific-place
-- [ This is optional ]

-- Builds our config menu on the right side of our tab
SaveManager:BuildConfigSection(Tabs["UI Settings"])

-- Builds our theme menu (with plenty of built in themes) on the left side
-- NOTE: you can also call ThemeManager:ApplyToGroupbox to add it to a specific groupbox
ThemeManager:ApplyToTab(Tabs["UI Settings"])

-- You can use the SaveManager:LoadAutoloadConfig() to load a config
-- which has been marked to be one that auto loads!
SaveManager:LoadAutoloadConfig()
