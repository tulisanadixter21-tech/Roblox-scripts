--[[ 
    MASTER HUB V7.3 - FINAL STABLE
    Fixed: Execution errors, Rivals Part-Detection, and Team Check.
]]

local Settings = {
    Aimbot_Enabled = false,
    ESP_Enabled = false,
    TeamCheck = true,
    Flying = false,
    NoClip = false,
    InfJump = false,
    ClickerEnabled = false,
    
    FlySpeed = 55,
    AimPart = "Head",
    AimKey = Enum.KeyCode.LeftShift,
    Smoothness = 0.12,
    ClickPos = Vector2.new(500, 500)
}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

-- --- 1. THE ENGINE ---
RunService.RenderStepped:Connect(function()
    -- AIMBOT
    if Settings.Aimbot_Enabled and UIS:IsKeyDown(Settings.AimKey) then
        local Target, Closest = nil, 800
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LP and v.Character then
                -- Rivals Team Check
                if Settings.TeamCheck and (v.Team == LP.Team or v.TeamColor == LP.TeamColor) then continue end
                
                -- Rivals Head/Torso Detection
                local AimTarget = v.Character:FindFirstChild("Head") or v.Character:FindFirstChild("HumanoidRootPart")
                if AimTarget then
                    local pos, onScreen = Camera:WorldToViewportPoint(AimTarget.Position)
                    if onScreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - UIS:GetMouseLocation()).Magnitude
                        if dist < Closest then Closest = dist; Target = AimTarget end
                    end
                end
            end
        end
        if Target then 
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, Target.Position), Settings.Smoothness)
        end
    end

    -- NOCLIP
    if Settings.NoClip and LP.Character then
        for _, v in pairs(LP.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
end)

-- --- 2. SIMPLE BOX ESP (Optimized) ---
local function CreateESP(plr)
    local Box = Drawing.new("Square")
    Box.Visible = false; Box.Color = Color3.new(1, 0, 0); Box.Thickness = 1
    
    RunService.RenderStepped:Connect(function()
        if Settings.ESP_Enabled and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            if Settings.TeamCheck and (plr.Team == LP.Team or plr.TeamColor == LP.TeamColor) then
                Box.Visible = false; return
            end
            
            local hrp = plr.Character.HumanoidRootPart
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local size = 1000 / pos.Z
                Box.Size = Vector2.new(size, size * 1.5)
                Box.Position = Vector2.new(pos.X - Box.Size.X / 2, pos.Y - Box.Size.Y / 2)
                Box.Visible = true
            else Box.Visible = false end
        else Box.Visible = false end
    end)
end
for _, v in pairs(Players:GetPlayers()) do CreateESP(v) end
Players.PlayerAdded:Connect(CreateESP)

-- --- 3. UI (CLEAN VERSION) ---
local sg = Instance.new("ScreenGui", game:GetService("CoreGui"))
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 180, 0, 320); main.Position = UDim2.new(0, 50, 0, 50)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 25); main.Active = true; main.Draggable = true
Instance.new("UICorner", main)

local layout = Instance.new("UIListLayout", main)
layout.HorizontalAlignment = "Center"; layout.Padding = UDim.new(0, 5)

local function MakeBtn(txt, setting, color)
    local b = Instance.new("TextButton", main)
    b.Size = UDim2.new(0, 160, 0, 32); b.Text = txt .. ": OFF"; b.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    b.TextColor3 = Color3.new(1,1,1); b.Font = "GothamBold"; b.TextSize = 10
    Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        Settings[setting] = not Settings[setting]
        b.Text = txt .. ": " .. (Settings[setting] and "ON" or "OFF")
        b.BackgroundColor3 = Settings[setting] and color or Color3.fromRGB(40, 40, 45)
    end)
end

MakeBtn("🎯 AIMBOT (L-SHIFT)", "Aimbot_Enabled", Color3.fromRGB(255, 140, 0))
MakeBtn("👁️ PLAYER ESP", "ESP_Enabled", Color3.fromRGB(255, 0, 0))
MakeBtn("👥 TEAM CHECK", "TeamCheck", Color3.fromRGB(0, 150, 255))
MakeBtn("✈️ FLY MODE", "Flying", Color3.fromRGB(0, 200, 100))
MakeBtn("👻 NOCLIP", "NoClip", Color3.fromRGB(150, 150, 150))
MakeBtn("🦘 INF JUMP", "InfJump", Color3.fromRGB(180, 0, 255))
