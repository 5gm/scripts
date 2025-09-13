-- Apple Tree Auto Clicker + Teleport Cubes
-- LocalScript in StarterGui

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local clickDetector = workspace.__GAME_CONTENT.MainTree.Tree.Hitbox.ClickDetector
local cubesFolder = workspace.__GAME_CONTENT.PlayersCubes["8780164987"]

-- Flags
local autoRunning = false

-- UI Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AppleTreeUI"
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Helper: make buttons
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

-- Buttons
local startButton = makeButton("StartBtn", "Start", UDim2.new(0, 20, 0, 20))
local stopButton = makeButton("StopBtn", "Stop", UDim2.new(0, 160, 0, 20))
local closeButton = makeButton("CloseBtn", "Close", UDim2.new(0, 300, 0, 20))

-- Combined loop
local function runAutomation()
    while autoRunning do
        -- Click the tree
        fireclickdetector(clickDetector)

        -- Teleport cubes
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            for _, cube in pairs(cubesFolder:GetChildren()) do
                if cube:IsA("BasePart") then
                    cube.CFrame = root.CFrame + Vector3.new(math.random(-3,3), 0, math.random(-3,3))
                elseif cube:IsA("Model") and cube.PrimaryPart then
                    cube:SetPrimaryPartCFrame(root.CFrame + Vector3.new(math.random(-3,3), 0, math.random(-3,3)))
                end
            end
        end

        task.wait(0.2) -- controls both click + teleport speed
    end
end

-- Button functions
startButton.MouseButton1Click:Connect(function()
    if not autoRunning then
        autoRunning = true
        task.spawn(runAutomation)
    end
end)

stopButton.MouseButton1Click:Connect(function()
    autoRunning = false
end)

closeButton.MouseButton1Click:Connect(function()
    autoRunning = false
    screenGui:Destroy()
end)
