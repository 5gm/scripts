local Players = game:GetService("Players")
local player = Players.LocalPlayer
local clickDetector = workspace.__GAME_CONTENT.MainTree.Tree.Hitbox.ClickDetector

local autoClicking = false
local runService = game:GetService("RunService")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AppleTreeUI"
screenGui.Parent = player:WaitForChild("PlayerGui")

local function makeButton(name, text, position)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Text = text
    button.Size = UDim2.new(0, 120, 0, 40)
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    button.TextColor3 = Color3.new(1,1,1)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 20
    button.Parent = screenGui
    return button
end

local startButton = makeButton("StartBtn", "Start", UDim2.new(0, 20, 0, 20))
local stopButton = makeButton("StopBtn", "Stop", UDim2.new(0, 160, 0, 20))
local closeButton = makeButton("CloseBtn", "Close", UDim2.new(0, 300, 0, 20))

local function autoClick()
    while autoClicking do
        fireclickdetector(clickDetector)
        task.wait(0.01)
    end
end

startButton.MouseButton1Click:Connect(function()
    if not autoClicking then
        autoClicking = true
        task.spawn(autoClick)
    end
end)

stopButton.MouseButton1Click:Connect(function()
    autoClicking = false
end)

closeButton.MouseButton1Click:Connect(function()
    autoClicking = false
    screenGui:Destroy()
end)
