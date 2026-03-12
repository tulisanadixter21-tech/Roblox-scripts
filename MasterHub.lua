--[[ 
    MASTER HUB V7.2 - RIVALS "BRUTE FORCE" EDITION
    Fixes: Broken ESP, Team-Locking, and Aimbot Snapping.
    Aimbot: Hold L-SHIFT | Panic: R-SHIFT
]]

local Settings = {
    Aimbot_Enabled = false,
    ESP_Enabled = false,
    TeamCheck = true,
    Flying = false,
    NoClip = false,
    
    AimPart = "Head", -- Fallback logic included below
    AimKey = Enum.KeyCode.LeftShift,
    Smoothness = 0.1, -- Ultra smooth for Rivals
    FlySpeed = 60
}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

-- --- 1. UNIVERSAL TARGET FINDER ---
local function GetTarget()
    local Target, Closest = nil, math.huge
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LP and v.Character then
            -- Check if they are actually an enemy (Rivals specific check)
            if Settings.TeamCheck and v.Team == LP.Team then continue end
            
            -- Rivals sometimes renames the Head to "FakeHead" or hides it
            local Part = v.Character:FindFirstChild("Head") or v.Character:FindFirstChild("UpperTorso") or v.Character:FindFirstChildOfClass("Part")
            
            if Part then
                local pos, onScreen = Camera:WorldToViewportPoint(Part.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - UIS:GetMouseLocation()).Magnitude
                    if dist < Closest then Closest = dist; Target = Part end
                end
            end
        end
    end
    return Target
end

-- --- 2. THE NEW RIVALS ESP ---
local function AddESP(plr)
    local Box = Drawing.new("Square")
    Box.Visible = false; Box.Color = Color3.new(1, 0, 0); Box.Thickness = 1; Box.Filled = false

    local Tracer = Drawing.new("Line")
    Tracer.Visible = false; Tracer.Color = Color3.new(1, 1, 1); Tracer.Thickness = 1

    RunService.RenderStepped:Connect(function()
        if Settings.ESP_Enabled and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            if Settings.TeamCheck and plr.Team == LP.Team then 
                Box.Visible = false; Tracer.Visible = false; return 
            end

            local hrp = plr.Character.HumanoidRootPart
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)

            if onScreen then
                -- Box Logic
                local size = 1000 / pos.Z -- Scales with distance
                Box.Size = Vector2.new(size, size * 1.5)
                Box.Position = Vector2.new(pos.X - Box.Size.X / 2, pos.Y - Box.Size.Y / 2)
                Box.Visible = true
                
                -- Tracer Logic (Bottom center to player)
                Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                Tracer.To = Vector2.new(pos.X, pos.Y)
                Tracer.Visible = true
            else
                Box.Visible = false; Tracer.Visible = false
            end
        else
            Box.Visible = false; Tracer.Visible = false
        end
    end)
end

-- Apply ESP to everyone
for _, p in pairs(Players:GetPlayers()) do AddESP(p) end
Players.PlayerAdded:Connect(AddESP)

-- --- 3. MAIN LOOP ---
RunService.RenderStepped:Connect(function()
    -- Aimbot
    if Settings.Aimbot_Enabled and UIS:IsKeyDown(Settings.AimKey) then
        local T = GetTarget()
        if T then
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, T.Position), Settings.Smoothness)
        end
    end
    
    -- NoClip
    if Settings.NoClip and LP.Character then
        for _, v in pairs(LP.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
end)

-- --- 4. PANIC & UI ---
-- [Keep your existing UI code but link the buttons to these new Settings]
