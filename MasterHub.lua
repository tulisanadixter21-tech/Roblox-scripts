--[[ 
    MASTER HUB V6.9 - SHIFT KEY AIMBOT
    Panic Key: Right-Shift | Aimbot Key: Hold Left-Shift
]]

local Settings = {
    ClickerEnabled = false,
    Aimbot_Enabled = false,
    ESP_Enabled = false,
    TeamCheck = true,
    Flying = false,
    NoClip = false,
    InfJump = false,
    AutoEquip = false,
    
    ClickPos = Vector2.new(500, 500),
    Interval = 0.07,
    FlySpeed = 50,
    AimPart = "Head",
    -- CHANGE: Now uses Left Shift instead of Right Click
    AimKey = Enum.KeyCode.LeftShift 
}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local Camera = workspace.CurrentCamera

-- --- 1. OPTIMIZED COMBAT ENGINE ---
local frameCount = 0
RunService.RenderStepped:Connect(function()
    frameCount = (frameCount + 1) % 2
    if frameCount ~= 0 then return end 

    -- AIMBOT LOGIC: Toggle ON + Holding Left Shift
    if Settings.Aimbot_Enabled and UIS:IsKeyDown(Settings.AimKey) then
        local Target, MaxDist = nil, 600
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LP and v.Character and v.Character:FindFirstChild(Settings.AimPart) then
                
                -- REFINED TEAM CHECK
                if Settings.TeamCheck then
                    -- Ignore if they are on your team OR if they are "Neutral" (common in lobbies)
                    if v.Team == LP.Team or v.TeamColor == LP.TeamColor or v.Neutral == true then 
                        continue 
                    end
                end
                
                local pos, onScreen = Camera:WorldToViewportPoint(v.Character[Settings.AimPart].Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - UIS:GetMouseLocation()).Magnitude
                    if dist < MaxDist then MaxDist = dist; Target = v end
                end
            end
        end
        if Target then 
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, Target.Character[Settings.AimPart].Position) 
        end
    end

    -- Movement (Fly/NoClip)
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

-- --- 2. UI SYSTEM ---
local sg = Instance.new("ScreenGui", game:GetService("CoreGui"))
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 180, 0, 380); main.Position = UDim2.new(0, 30, 0, 30)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 15); main.Active = true; main.Draggable = true
Instance.new("UICorner", main)

local scroll = Instance.new("ScrollingFrame", main)
scroll.Size = UDim2.new(1, 0, 1, -10); scroll.Position = UDim2.new(0, 0, 0, 5)
scroll.BackgroundTransparency = 1; scroll.CanvasSize = UDim2.new(0, 0, 2.5, 0); scroll.ScrollBarThickness = 0
local layout = Instance.new("UIListLayout", scroll); layout.HorizontalAlignment = "Center"; layout.Padding = UDim.new(0, 4)

local function MakeBtn(txt, setting, color, custom)
    local b = Instance.new("TextButton", scroll)
    b.Size = UDim2.new(0, 165, 0, 32); b.Text = txt .. ": OFF"; b.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    b.TextColor3 = Color3.new(1,1,1); b.Font = "GothamBold"; b.TextSize = 10; Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        if custom then custom() return end
        Settings[setting] = not Settings[setting]
        b.Text = txt .. ": " .. (Settings[setting] and "ON" or "OFF")
        b.BackgroundColor3 = Settings[setting] and color or Color3.fromRGB(30, 30, 35)
    end)
end

-- UI Buttons
MakeBtn("🚨 PANIC (R-SHIFT)", nil, Color3.fromRGB(200, 0, 0), function() 
    for k, v in pairs(Settings) do if type(v) == "boolean" then Settings[k] = false end end
    RunService:Set3dRenderingEnabled(true)
end)
MakeBtn("🖱️ CLICKER", "ClickerEnabled", Color3.fromRGB(0, 180, 100))
MakeBtn("🎯 AIMBOT (L-SHIFT)", "Aimbot_Enabled", Color3.fromRGB(255, 140, 0))
MakeBtn("👁️ ESP", "ESP_Enabled", Color3.fromRGB(255, 50, 50))
MakeBtn("✈️ FLY", "Flying", Color3.fromRGB(0, 150, 255))
MakeBtn("👻 NOCLIP", "NoClip", Color3.fromRGB(130, 130, 130))
MakeBtn("🦘 INF JUMP", "InfJump", Color3.fromRGB(180, 0, 255))
MakeBtn("👥 TEAM CHECK", "TeamCheck", Color3.fromRGB(50, 100, 255))

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
