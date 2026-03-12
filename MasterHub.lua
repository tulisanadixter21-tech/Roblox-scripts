--[[ 
    MASTER HUB V7.5 - THE RIVALS NUCLEAR FIX
    Fixes: Shift-Key blocking, Team-Check failures, and ESP lag.
    Aimbot: Hold L-SHIFT | Panic: R-SHIFT
]]

local Settings = {
    Aimbot = false,
    ESP = false,
    TeamCheck = true,
    Fly = false,
    NoClip = false,
    Smoothness = 0.12, -- 0.1 = Slow/Legit | 0.5 = Fast
    AimPart = "Head",
    FlySpeed = 50
}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

-- --- 1. RIVALS TARGET FINDER ---
local function GetTarget()
    local Target, Closest = nil, 1000
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LP and v.Character then
            -- Strict Team Check
            if Settings.TeamCheck and (v.Team == LP.Team or v.TeamColor == LP.TeamColor) then continue end
            
            -- Rivals Brute Force Detection
            local AimTarget = v.Character:FindFirstChild("Head") or v.Character:FindFirstChild("UpperTorso") or v.Character:FindFirstChild("HumanoidRootPart")
            
            if AimTarget then
                local pos, onScreen = Camera:WorldToViewportPoint(AimTarget.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - UIS:GetMouseLocation()).Magnitude
                    if dist < Closest then Closest = dist; Target = AimTarget end
                end
            end
        end
    end
    return Target
end

-- --- 2. HIGHLIGHT ESP (WALLHACK) ---
local function CreateESP(plr)
    local function Update()
        if plr == LP then return end
        local char = plr.Character
        if not char then return end
        
        local h = char:FindFirstChild("HubHighlight") or Instance.new("Highlight")
        h.Name = "HubHighlight"; h.Parent = char
        h.FillColor = Color3.fromRGB(255, 0, 0); h.OutlineColor = Color3.new(1, 1, 1)
        h.FillTransparency = 0.5; h.OutlineTransparency = 0
        
        RunService.Heartbeat:Connect(function()
            if char and h.Parent then
                local isEnemy = not Settings.TeamCheck or (plr.Team ~= LP.Team and plr.TeamColor ~= LP.TeamColor)
                h.Enabled = Settings.ESP and isEnemy
            end
        end)
    end
    plr.CharacterAdded:Connect(Update); Update()
end

for _, v in pairs(Players:GetPlayers()) do CreateESP(v) end
Players.PlayerAdded:Connect(CreateESP)

-- --- 3. MAIN ENGINE ---
RunService.RenderStepped:Connect(function()
    -- AIMBOT (Uses Direct Key Code check for Shift)
    if Settings.Aimbot and UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
        local T = GetTarget()
        if T then
            local lookAt = CFrame.new(Camera.CFrame.Position, T.Position)
            Camera.CFrame = Camera.CFrame:Lerp(lookAt, Settings.Smoothness)
        end
    end

    -- FLY & NOCLIP
    if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
        if Settings.NoClip then
            for _, v in pairs(LP.Character:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = false end
            end
        end
        if Settings.Fly then
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

-- --- 4. THE UI ---
local sg = Instance.new("ScreenGui", game:GetService("CoreGui"))
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 180, 0, 320); main.Position = UDim2.new(0, 50, 0, 50)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); main.Active = true; main.Draggable = true
Instance.new("UICorner", main)

local layout = Instance.new("UIListLayout", main)
layout.HorizontalAlignment = "Center"; layout.Padding = UDim.new(0, 6)

local function MakeBtn(txt, setting, color)
    local b = Instance.new("TextButton", main)
    b.Size = UDim2.new(0, 160, 0, 35); b.Text = txt .. ": OFF"; b.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    b.TextColor3 = Color3.new(1,1,1); b.Font = "GothamBold"; b.TextSize = 10; Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        Settings[setting] = not Settings[setting]
        b.Text = txt .. ": " .. (Settings[setting] and "ON" or "OFF")
        b.BackgroundColor3 = Settings[setting] and color or Color3.fromRGB(35, 35, 40)
    end)
end

MakeBtn("🎯 AIMBOT (L-SHIFT)", "Aimbot", Color3.fromRGB(255, 140, 0))
MakeBtn("👁️ GLOW ESP", "ESP", Color3.fromRGB(255, 50, 50))
MakeBtn("👥 TEAM CHECK", "TeamCheck", Color3.fromRGB(0, 150, 255))
MakeBtn("✈️ FLY MODE", "Fly", Color3.fromRGB(0, 200, 100))
MakeBtn("👻 NOCLIP", "NoClip", Color3.fromRGB(150, 150, 150))

-- Panic Key
UIS.InputBegan:Connect(function(i, p)
    if not p and i.KeyCode == Enum.KeyCode.RightShift then
        sg:Destroy()
        Settings.Aimbot = false; Settings.ESP = false; Settings.Fly = false
    end
end)
