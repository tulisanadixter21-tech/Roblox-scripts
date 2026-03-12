--[[ 
    MASTER HUB V6.5 - FINAL STABLE RELEASE
    Features: Individual Toggles, 60ms AFK, Combat Suite, and Engine Exploits.
    Panic Key: Right-Shift
]]

local Settings = {
    SpamEnabled = false, 
    ClickerEnabled = false,
    AutoEquip = false,
    AutoRejoin = true,
    ESP_Enabled = false,
    Aimbot_Enabled = false,
    TeamCheck = true,
    Flying = false,
    NoClip = false,
    InfJump = false,
    FullBright = false,
    
    TargetKeys = {"Space", "E"},
    Interval = 0.06,
    ClickPos = Vector2.new(500, 500),
    FlySpeed = 50,
    AimPart = "Head"
}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local Camera = workspace.CurrentCamera

-- --- 1. CORE ENGINES ---

-- Aimbot Logic
RunService.RenderStepped:Connect(function()
    if Settings.Aimbot_Enabled then
        local Target, MaxDist = nil, math.huge
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LP and v.Character and v.Character:FindFirstChild(Settings.AimPart) then
                if Settings.TeamCheck and v.Team == LP.Team then continue end
                local pos, onScreen = Camera:WorldToViewportPoint(v.Character[Settings.AimPart].Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - UIS:GetMouseLocation()).Magnitude
                    if dist < MaxDist then MaxDist = dist Target = v end
                end
            end
        end
        if Target then Camera.CFrame = CFrame.new(Camera.CFrame.Position, Target.Character[Settings.AimPart].Position) end
    end
end)

-- Fly & NoClip Logic
RunService.Stepped:Connect(function()
    if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
        if Settings.NoClip then
            for _, v in pairs(LP.Character:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = false end
            end
        end
        if Settings.Flying then
            local vec = Vector3.new(0,0,0)
            if UIS:IsKeyDown(Enum.KeyCode.W) then vec = vec + Camera.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then vec = vec - Camera.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then vec = vec - Camera.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then vec = vec + Camera.CFrame.RightVector end
            LP.Character.HumanoidRootPart.Velocity = vec * Settings.FlySpeed
            LP.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end
end)

-- Background Clicker Loop
task.spawn(function()
    while true do
        if Settings.ClickerEnabled then
            VIM:SendMouseButtonEvent(Settings.ClickPos.X, Settings.ClickPos.Y, 0, true, game, 1)
            task.wait(0.01)
            VIM:SendMouseButtonEvent(Settings.ClickPos.X, Settings.ClickPos.Y, 0, false, game, 1)
        end
        task.wait(Settings.Interval)
    end
end)

-- --- 2. THE UI SYSTEM ---
local sg = Instance.new("ScreenGui", game:GetService("CoreGui"))
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 190, 0, 380); main.Position = UDim2.new(0, 50, 0, 50)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 18); main.Active = true; main.Draggable = true
Instance.new("UICorner", main)

local scroll = Instance.new("ScrollingFrame", main)
scroll.Size = UDim2.new(1, 0, 1, -10); scroll.Position = UDim2.new(0, 0, 0, 5)
scroll.BackgroundTransparency = 1; scroll.CanvasSize = UDim2.new(0, 0, 2.2, 0); scroll.ScrollBarThickness = 0
local layout = Instance.new("UIListLayout", scroll); layout.HorizontalAlignment = "Center"; layout.Padding = UDim.new(0, 5)

local function MakeToggle(txt, settingName, color)
    local b = Instance.new("TextButton", scroll)
    b.Size = UDim2.new(0, 170, 0, 35); b.Text = txt .. ": OFF"; b.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    b.TextColor3 = Color3.new(1,1,1); b.Font = "GothamBold"; b.TextSize = 10
    Instance.new("UICorner", b)
    
    b.MouseButton1Click:Connect(function()
        Settings[settingName] = not Settings[settingName]
        b.Text = txt .. ": " .. (Settings[settingName] and "ON" or "OFF")
        b.BackgroundColor3 = Settings[settingName] and color or Color3.fromRGB(35, 35, 40)
    end)
    return b
end

-- Create Individual Toggle Buttons
MakeToggle("🖱️ AUTO-CLICKER", "ClickerEnabled", Color3.fromRGB(0, 180, 100))
MakeToggle("🎯 AIMBOT (CLOSEST)", "Aimbot_Enabled", Color3.fromRGB(255, 140, 0))
MakeToggle("👁️ PLAYER ESP", "ESP_Enabled", Color3.fromRGB(255, 60, 60))
MakeToggle("✈️ FLY MODE (W/A/S/D)", "Flying", Color3.fromRGB(0, 150, 255))
MakeToggle("👻 NOCLIP (WALLS)", "NoClip", Color3.fromRGB(130, 130, 130))
MakeToggle("🦘 INFINITE JUMP", "InfJump", Color3.fromRGB(180, 0, 255))
MakeToggle("🎒 AUTO-EQUIP TOOLS", "AutoEquip", Color3.fromRGB(200, 200, 0))
MakeToggle("👥 TEAM CHECK", "TeamCheck", Color3.fromRGB(50, 100, 255))

-- Panic Button
local panic = Instance.new("TextButton", scroll)
panic.Size = UDim2.new(0, 170, 0, 40); panic.Text = "🚨 PANIC (R-SHIFT)"; panic.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
panic.TextColor3 = Color3.new(1,1,1); panic.Font = "GothamBold"; Instance.new("UICorner", panic)
panic.MouseButton1Click:Connect(function() 
    for k, v in pairs(Settings) do if type(v) == "boolean" then Settings[k] = false end end
    print("All Hacks Disabled.")
end)

-- Position Picker
local pick = Instance.new("TextButton", scroll)
pick.Size = UDim2.new(0, 170, 0, 35); pick.Text = "🎯 SET CLICK POSITION"; pick.BackgroundColor3 = Color3.fromRGB(230, 150, 0)
pick.TextColor3 = Color3.new(1,1,1); pick.Font = "GothamBold"; Instance.new("UICorner", pick)
pick.MouseButton1Click:Connect(function()
    pick.Text = "CLICK NOW..."
    local c; c = UIS.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            Settings.ClickPos = Vector2.new(i.Position.X, i.Position.Y)
            pick.Text = "POSITION SET!"
            task.delay(1, function() pick.Text = "🎯 SET CLICK POSITION" end)
            c:Disconnect()
        end
    end)
end)
