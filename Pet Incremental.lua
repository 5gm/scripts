local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Pet Incremental private",
   Icon = 0, -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
   LoadingTitle = "loading bro calm down",
   LoadingSubtitle = "by 5gm",
   Theme = "Amber Glow", -- Check https://docs.sirius.menu/rayfield/configuration/themes

   DisableRayfieldPrompts = true,
   DisableBuildWarnings = true, -- Prevents Rayfield from warning when the script has a version mismatch with the interface

   ConfigurationSaving = {
      Enabled = true,
      FolderName = config, -- Create a custom folder for your hub/game
      FileName = "Pet Incremental private config"
   },

   Discord = {
      Enabled = false, -- Prompt the user to join your Discord server if their executor supports it
      Invite = "noinvitelink", -- The Discord invite code, do not include discord.gg/. E.g. discord.gg/ ABCD would be ABCD
      RememberJoins = true -- Set this to false to make them join the discord every time they load it up
   },

   KeySystem = false, -- Set this to true to use our key system
   KeySettings = {
      Title = "Untitled",
      Subtitle = "Key System",
      Note = "No method of obtaining the key is provided", -- Use this to tell the user how to get a key
      FileName = "Key", -- It is recommended to use something unique as other scripts using Rayfield may overwrite your key file
      SaveKey = true, -- The user's key will be saved, but if you change the key, they will be unable to use your script
      GrabKeyFromSite = false, -- If this is true, set Key below to the RAW site you would like Rayfield to get the key from
      Key = {"Hello"} -- List of keys that will be accepted by the system, can be RAW file links (pastebin, github etc) or simple strings ("hello","key22")
   }
})

Rayfield:Notify({
   Title = "loaded bitch",
   Content = "hi",
   Duration = 6.5,
   Image = 4483362458,
})

local homeTab = Window:CreateTab("home", 4483362458) -- Title, Image
local currencyTab = Window:CreateTab("convert", 4483362458) -- Title, Image
local teleportTab = Window:CreateTab("goto", 4483362458) -- Title, Image
local miscTab = Window:CreateTab("misc", 4483362458) -- Title, Image
local Paragraph = currencyTab:CreateParagraph({Title = "RISKY!", Content = "if you turn on auto ruby you will lose all your money"})

--toggle states
local autoEvolve
local autoEquipBest
local autoRank
local autoConvertRuby
local autoplasma
local autoRune
local autotime
local autoRune2
local autoMine
local getgamepass

--loops
local autoEvolveLoop
local autoEquipLoop
local autoRankLoop
local autoRubyLoop
local autoplasmaLoop
local autoRuneLoop
local autoRune2Loop
local autoMineLoop

--dependancies
local VirtualUser = game:GetService("VirtualUser")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer


local Toggle1 = homeTab:CreateToggle({
    Name = "Auto Evolve",
    CurrentValue = false,
    Flag = "autorebirthflag",
    Callback = function(v)
        autoEvolve = v

        if autoEvolve then
            local autoEvolveLoop = task.spawn(function()
                while autoEvolve do
                    game:GetService("ReplicatedStorage"):WaitForChild("RE"):FireServer("EvolveAll")
                    task.wait(1)
                end
            end)
        end
    end
})

local Toggle1 = homeTab:CreateToggle({
    Name = "Auto Equip Best",
    CurrentValue = false,
    Flag = "autoequipflag",
    Callback = function(e)
        autoEquipBest = e

        if autoEquipBest then
            local autoEquipLoop = task.spawn(function()
                while autoEquipBest do
                    game:GetService("ReplicatedStorage"):WaitForChild("RE"):FireServer("EquipBest")
                    task.wait(0.3)
                end
            end)
        end
    end
})

local Toggle1 = homeTab:CreateToggle({
    Name = "Auto Rank",
    CurrentValue = false,
    Flag = "autorankflag",
    Callback = function(r)
        autoRank = r

        if autoRank then
            local autoRankLoop = task.spawn(function()
                while autoRank do
                    game:GetService("ReplicatedStorage"):WaitForChild("RE"):FireServer("RankUp")
                    task.wait(10)
                end
            end)
        end
    end
})

local Toggle1 = homeTab:CreateToggle({
    Name = "Auto Plasma",
    CurrentValue = false,
    Flag = "autoplasmaflag",
    Callback = function(p)
        autoplasma = p

        if autoplasma then
            local autoplasmaLoop = task.spawn(function()
                while autoplasma do
                    game:GetService("ReplicatedStorage"):WaitForChild("RE"):FireServer("Plasma", true)
                    task.wait(0.001)
                end
            end)
        end
    end
})

local Toggle1 = homeTab:CreateToggle({
    Name = "Auto Mine",
    CurrentValue = false,
    Flag = "automineflag",
    Callback = function(m)
        autoMine = m

        if autoMine then
            local autoMineLoop = task.spawn(function()
                while autoMine do
                    game:GetService("ReplicatedStorage"):WaitForChild("RE"):FireServer("Mine", "Stone")
                    task.wait(0.00000000001)
                end
            end)
        end
    end
})

local Toggle1 = currencyTab:CreateToggle({
    Name = "Auto Ruby",
    CurrentValue = false,
    Flag = "autorubyflag",
    Callback = function(rc)
        autoConvertRuby = rc

        if autoConvertRuby then
            autoRubyLoop = task.spawn(function()
                while autoConvertRuby do
                    game:GetService("ReplicatedStorage"):WaitForChild("RE"):FireServer("RubyConvert")
                    task.wait(1)
                end
            end)
        else
            if autoRubyLoop then
                task.cancel(autoRubyLoop)
                autoRubyLoop = nil
            end
        end
    end
})

local Toggle1 = homeTab:CreateToggle({
    Name = "Auto Rune",
    CurrentValue = false,
    Flag = "autoruneflag",
    Callback = function(r)
        autoRune = r

        if autoRune then
            local autoRuneLoop = task.spawn(function()
                while autoRune do
                    game:GetService("ReplicatedStorage"):WaitForChild("RE"):FireServer("Rune", "Rune1")
                    task.wait(0.001)
                end
            end)
        end
    end
})

local Toggle1 = homeTab:CreateToggle({
    Name = "Auto Rune 2",
    CurrentValue = false,
    Flag = "autorune2flag",
    Callback = function(r)
        autoRune2 = r

        if autoRune2 then
            local autoRune2Loop = task.spawn(function()
                while autoRune2 do
                    game:GetService("ReplicatedStorage"):WaitForChild("RE"):FireServer("Rune", "Rune2")
                    task.wait(0.001)
                end
            end)
        end
    end
})

local Toggle1 = homeTab:CreateToggle({
    Name = "2x Time",
    CurrentValue = false,
    Flag = "autotimeflag",
    Callback = function(t)
        autotime = t

        if autotime then
                while autotime do
                    game:GetService("ReplicatedStorage"):WaitForChild("RE"):FireServer("TimeMachine", true)
                    task.wait(1)
                end
        end
    end
})

local Button = teleportTab:CreateButton({
    Name = "Spawn",
    Callback = function()
        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-18.8723, 5.0000, -42.7216)
    end
})

local Button = teleportTab:CreateButton({
    Name = "Leaderboard",
    Callback = function()
        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-70.2490, 3.2503, -17.5179)
    end
})

local Button = teleportTab:CreateButton({
    Name = "Mines",
    Callback = function()
        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(4.95152521, -64.0963058, -20.7245159, 0.081381999, -0.00019608943,
        -0.996682942, -0.00176266488, 0.999998391, -0.00034066831, 0.996681452, 0.00178454223, 0.0813815221)
    end
})

local Button = teleportTab:CreateButton({
    Name = "Sacrifice",
    Callback = function()
        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0.4932, 32.2501, -398.8056)
    end
})



























local walkspeedSlider = miscTab:CreateSlider({
    Name = "Walk Speed",
    Range = {10, 250},
    Increment = 1,
    Suffix = "speed",
    CurrentValue = 10,
    Flag = "walkspeed", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(w)
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = w
    end,
 })
 
 local jumpheightSlider = miscTab:CreateSlider({
    Name = "Jump Power",
    Range = {50, 250},
    Increment = 1,
    Suffix = "power",
    CurrentValue = 50,
     Flag = "Slider2",
     Callback = function(Value)
         local player = game.Players.LocalPlayer
         if player and player.Character and player.Character:FindFirstChild("Humanoid") then
             local humanoid = player.Character:FindFirstChild("Humanoid")
             humanoid.UseJumpPower = true
             humanoid.JumpPower = math.clamp(Value, 50, 300)
         end
     end,
 })
 
 local player = game.Players.LocalPlayer
 local character = player.Character or player.CharacterAdded:Wait()
 local humanoid = character:WaitForChild("Humanoid")
 local rootPart = character:WaitForChild("HumanoidRootPart")
 
 local noclip = false
 
 -- Function to toggle noclip
 local function toggleNoclip()
     noclip = not noclip
 end
 
 -- Listen for a key press to toggle noclip (e.g., "N" key)
 local UserInputService = game:GetService("UserInputService")
 UserInputService.InputBegan:Connect(function(input, gameProcessed)
     if gameProcessed then return end
     if input.KeyCode == Enum.KeyCode.N then
         toggleNoclip()
     end
 end)
 
 -- Main loop to disable collisions if noclip is on
 game:GetService("RunService").Heartbeat:Connect(function()
     if not character or not humanoid or not rootPart then
         return
     end
 
     if noclip then
         -- Disable collision for humanoid parts to go through walls
         for _, part in pairs(character:GetChildren()) do
             if part:IsA("BasePart") then
                 part.CanCollide = false
             end
         end
     else
         -- Re-enable collision for humanoid parts
         for _, part in pairs(character:GetChildren()) do
             if part:IsA("BasePart") then
                 part.CanCollide = true
             end
         end
     end
 end)
 
 -- Creating a button in the miscTab to toggle noclip
 local Button = miscTab:CreateButton({
    Name = "Toggle Noclip",
    Callback = function()
        toggleNoclip()
    end,
 })

 local Button = miscTab:CreateButton({
    Name = "Get Gamepasses",
    Callback = function()
        -- Set all gamepasses to true
        local passes = game:GetService("Players").LocalPlayer.Data.Passes
        passes.DoubleCoins.Value = true
        passes.DoubleGems.Value = true
        passes.DoubleMoney.Value = true
        passes.DoublePlasma.Value = true
        passes.DoubleRuby.Value = true
        passes.DoubleTime.Value = true
        passes.EggClone.Value = true
        passes.InfiniteStorage.Value = true
        passes.PetClone.Value = true
        passes.PetEvo.Value = true
        passes.RunFaster.Value = true
        passes.RuneBulk.Value = true
        passes.RuneClone.Value = true
    end
})
