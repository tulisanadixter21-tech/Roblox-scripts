--[[ 
    MASTER HUB V10.0 - OVERDRIVE PERFORMANCE
    - FOV: Locked to screen center
    - Speed: Snappy/Instant lock
    - Binds: Hold L-SHIFT / Right-Click to Lock
]]

local Settings = {
    Aimbot = false,
    ESP = false,
    TeamCheck = true,
    Fly = false,
    -- OVERDRIVE TUNING --
    Smoothness = 0.95, -- 0.95 = Near Instant | 1.0 = Frame-1 Snap
    FOV = 200,         -- Larger FOV for fast targets
    FlySpeed = 70,
    Running = true
}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- --- 1. CENTERED FOV CIRCLE ---
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.Color = Color3.fromRGB(0, 255, 150) -- Neon Green for visibility
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Visible = false

-- --- 2. FAST TARGETING ENGINE ---
local function GetClosestTarget()
    local Target, Closest = nil, Settings.FOV
    -- Calculate Screen Center
    local Center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LP and v.Character then
            if Settings.TeamCheck and (v.Team == LP.Team or v.TeamColor == LP.TeamColor) then continue end
            
            -- Rivals Brute Force: Aim at Head or Torso
            local Part = v.Character:FindFirstChild("Head") or v.Character:FindFirstChild("UpperTorso")
            if Part then
                local pos, onScreen = Camera:WorldToViewportPoint(Part.Position)
                if onScreen then
                    -- Measure distance from CENTER of screen instead of mouse
                    local dist = (Vector2.new(pos.X, pos.Y) - Center).Magnitude
                    if dist < Closest then 
                        Closest = dist
                        Target = Part 
                    end
                end
            end
        end
    end
    return Target
end

-- --- 3. INPUT & MOVEMENT ---
local IsAiming = false
UIS.InputBegan:Connect(function(i) 
    if i.KeyCode == Enum.KeyCode.LeftShift or i.UserInputType == Enum.UserInputType.MouseButton2 then IsAiming = true end 
end)
UIS.InputEnded:Connect(function(i) 
    if i.KeyCode == Enum.KeyCode.LeftShift or i.UserInputType == Enum.UserInputType.MouseButton2 then IsAiming = false end 
end)

RunService.RenderStepped:Connect(function()
    if not Settings.Running then return end
    
    -- Keep FOV circle at Screen Center
    local Center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Position = Center
    FOVCircle.Radius = Settings.FOV
    FOVCircle.Visible = Settings.Aimbot

    if Settings.Aimbot and IsAiming then
        local T = GetClosestTarget()
        if T then
            -- High-Speed LERP
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, T.Position), Settings.Smoothness)
        end
    end
    
    -- Fly Movement
    if Settings.Fly and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LP.Character.HumanoidRootPart
        local vec = Vector3.new(0,0,0)
        if UIS:IsKeyDown(Enum.KeyCode.W) then vec = vec + Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then vec = vec - Camera.CFrame.LookVector end
        hrp.Velocity = (vec * Settings.FlySpeed) + Vector3.new(0, 1.5, 0)
    end
end)

-- --- 4. THE UI & UNLOAD ---
local function Unload()
    Settings.Running = false; FOVCircle:Destroy()
    if game:GetService("CoreGui"):FindFirstChild("MasterHub") then game:GetService("CoreGui").MasterHub:Destroy() end
    for _, v in pairs(Players:GetPlayers()) do
        if v.Character and v.Character:FindFirstChild("HubHighlight") then v.Character.HubHighlight:Destroy() end
    end
end

local sg = Instance.new("ScreenGui", game:GetService("CoreGui")); sg.Name = "MasterHub"
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 180, 0, 320); main.Position = UDim2.new(0, 50, 0, 50)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 12); main.Active = true; main.Draggable = true
Instance.new("UICorner", main)
local layout = Instance.new("UIListLayout", main); layout.HorizontalAlignment = "Center"; layout.Padding = UDim.new(0, 6)

local function MakeBtn(txt, setting, color, func)
    local b = Instance.new("TextButton", main)
    b.Size = UDim2.new(0, 160, 0, 35); b.Text = txt; b.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    b.TextColor3 = Color3.new(1,1,1); b.Font = "GothamBold"; b.TextSize = 10; Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        if func then func() return end
        Settings[setting] = not Settings[setting]
        b.BackgroundColor3 = Settings[setting] and color or Color3.fromRGB(30, 30, 35)
        b.Text = txt .. (setting and (Settings[setting] and ": ON" or ": OFF") or "")
    end)
end

MakeBtn("🎯 AIMBOT", "Aimbot", Color3.fromRGB(255, 140, 0))
MakeBtn("👁️ GLOW ESP", "ESP", Color3.fromRGB(255, 50, 50))
MakeBtn("✈️ FLY MODE", "Fly", Color3.fromRGB(0, 200, 100))
MakeBtn("👥 TEAM CHECK", "TeamCheck", Color3.fromRGB(0, 150, 255))
MakeBtn("❌ SELF-DESTRUCT", nil, Color3.fromRGB(200, 0, 0), Unload)

-- Keybinds
UIS.InputBegan:Connect(function(i, p)
    if p then return end
    if i.KeyCode == Enum.KeyCode.RightShift then Unload()
    elseif i.KeyCode == Enum.KeyCode.Insert then main.Visible = not main.Visible end
end)
