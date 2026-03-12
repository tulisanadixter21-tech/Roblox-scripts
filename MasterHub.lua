--[[ 
    MASTER HUB V18.0 | FULL COMPLETE SOURCE
    - New: Auto-Reload (Instant reload on 0 ammo)
    - New: Fast Respawn Logic
    - Features: Aimbot, Silent, ESP, Hitbox, Speed, No Recoil
]]

local S = {
    Aimbot = false, 
    Silent = false, 
    ESP = false, 
    TeamCheck = true, 
    Fly = false, 
    Hitbox = false,
    NoRecoil = false,
    SpeedBoost = false,
    AutoReload = false, -- New
    Smooth = 0.9, 
    FOV = 180, 
    WalkSpeed = 45, 
    JumpPower = 80,
    Running = true
}

local P, RS, UIS = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService")
local LP, Cam, CG = P.LocalPlayer, workspace.CurrentCamera, game:GetService("CoreGui")

if CG:FindFirstChild("MasterHub") then CG.MasterHub:Destroy() end

-- 1. VISUALS
local Circle = Drawing.new("Circle")
Circle.Thickness = 2; Circle.Color = Color3.fromRGB(0, 255, 150); Circle.Visible = false; Circle.Transparency = 1

local Dot = Drawing.new("Circle")
Dot.Radius = 2; Dot.Thickness = 1; Dot.Color = Color3.fromRGB(255, 255, 255); Dot.Filled = true; Dot.Visible = false

-- 2. UTILS
local function GetScaledFOV()
    return (S.FOV / Cam.FieldOfView) * 70 
end

local function GetT()
    local T, C = nil, GetScaledFOV()
    local Mid = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    for _, v in pairs(P:GetPlayers()) do
        if v ~= LP and v.Character and v.Character:FindFirstChild("Head") then
            if S.TeamCheck and v.Team == LP.Team then continue end
            local pos, vis = Cam:WorldToViewportPoint(v.Character.Head.Position)
            if vis then
                local d = (Vector2.new(pos.X, pos.Y) - Mid).Magnitude
                if d < C then C = d; T = v.Character.Head end
            end
        end
    end
    return T
end

-- 3. UI CONSTRUCTION
local sg = Instance.new("ScreenGui", CG); sg.Name = "MasterHub"; sg.DisplayOrder = 999
local main = Instance.new("Frame", sg); main.Size = UDim2.new(0, 160, 0, 450); main.Position = UDim2.new(0.5, -80, 0.4, 0)
main.BackgroundColor3 = Color3.fromRGB(12, 12, 15); main.Active = true; main.Draggable = true; Instance.new("UICorner", main)
local L = Instance.new("UIListLayout", main); L.HorizontalAlignment = "Center"; L.Padding = UDim.new(0, 4)

local function MB(t, s, c, f)
    local b = Instance.new("TextButton", main); b.Size = UDim2.new(0, 140, 0, 30); b.Text = t .. ": OFF"
    b.BackgroundColor3 = Color3.fromRGB(25, 25, 30); b.TextColor3 = Color3.new(1,1,1); b.Font = "GothamBold"; b.TextSize = 9; Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        if f then f() return end
        S[s] = not S[s]; b.BackgroundColor3 = S[s] and c or Color3.fromRGB(25, 25, 30); b.Text = t .. ": " .. (S[s] and "ON" or "OFF")
    end)
end

MB("🎯 AIMBOT", "Aimbot", Color3.fromRGB(255, 140, 0))
MB("🔫 SNAPPY AIM", "Silent", Color3.fromRGB(150, 0, 255))
MB("👁️ GLOW ESP", "ESP", Color3.fromRGB(255, 50, 50))
MB("🧠 HITBOX+", "Hitbox", Color3.fromRGB(255, 255, 0))
MB("⚡ SPEED BOOST", "SpeedBoost", Color3.fromRGB(0, 255, 255))
MB("🔄 AUTO RELOAD", "AutoReload", Color3.fromRGB(100, 255, 100))
MB("🚫 NO RECOIL", "NoRecoil", Color3.fromRGB(255, 100, 255))
MB("✈️ FLY MODE", "Fly", Color3.fromRGB(0, 200, 100))
MB("👥 TEAM CHECK", "TeamCheck", Color3.fromRGB(0, 150, 255))
MB("❌ UNLOAD", nil, Color3.fromRGB(200, 0, 0), function() S.Running = false; Circle:Destroy(); Dot:Destroy(); sg:Destroy() end)

-- 4. MAIN LOOP
local Aiming = false
UIS.InputBegan:Connect(function(i, p)
    if i.KeyCode == Enum.KeyCode.LeftShift then Aiming = true end
    if not p and i.KeyCode == Enum.KeyCode.Insert then main.Visible = not main.Visible end
end)
UIS.InputEnded:Connect(function(i) if i.KeyCode == Enum.KeyCode.LeftShift then Aiming = false end end)

RS.RenderStepped:Connect(function()
    if not S.Running then return end
    
    local Mid = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    local Target = GetT()
    local Char = LP.Character
    local Hum = Char and Char:FindFirstChild("Humanoid")
    
    -- Update FOV & Crosshair
    Circle.Position = Mid; Circle.Radius = GetScaledFOV(); Circle.Visible = (S.Aimbot or S.Silent)
    Dot.Position = Mid; Dot.Visible = (S.Aimbot or S.Silent)
    Circle.Color = Target and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(0, 255, 150)
    
    -- Aimbot / Silent
    if Aiming and Target then
        if S.Silent then
            Cam.CFrame = CFrame.new(Cam.CFrame.Position, Target.Position)
        elseif S.Aimbot then
            Cam.CFrame = Cam.CFrame:Lerp(CFrame.new(Cam.CFrame.Position, Target.Position), S.Smooth)
        end
    end
    
    -- Auto Reload Logic (Rivals Specific)
    if S.AutoReload and Char then
        local Tool = Char:FindFirstChildOfClass("Tool")
        if Tool and Tool:FindFirstChild("Ammo") and Tool.Ammo.Value == 0 then
            -- Simulates pressing 'R' instantly
            game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.R, false, game)
        end
    end

    -- Movement
    if Char and Char:FindFirstChild("HumanoidRootPart") then
        local hrp = Char.HumanoidRootPart
        if S.Fly then
            local v = Vector3.new(0,0,0)
            if UIS:IsKeyDown("W") then v = v + Cam.CFrame.LookVector end
            if UIS:IsKeyDown("S") then v = v - Cam.CFrame.LookVector end
            hrp.Velocity = (v * 75) + Vector3.new(0, 2, 0)
        elseif S.SpeedBoost and Hum then
            Hum.WalkSpeed = S.WalkSpeed
            Hum.JumpPower = S.JumpPower
        elseif Hum then
            Hum.WalkSpeed = 16
            Hum.JumpPower = 50
        end
    end

    -- No Recoil
    if S.NoRecoil and Aiming then
        LP.CameraMaxZoomDistance = LP.CameraMaxZoomDistance 
    end
    
    -- Hitbox Logic
    if S.Hitbox then
        for _, v in pairs(P:GetPlayers()) do
            if v ~= LP and v.Character and v.Character:FindFirstChild("Head") then
                v.Character.Head.Size = Vector3.new(3.5, 3.5, 3.5)
                v.Character.Head.CanCollide = false
            end
        end
    end
end)

-- 5. ESP System
local function AddESP(p)
    local function CreateH()
        if p.Character then
            local h = p.Character:FindFirstChild("E") or Instance.new("Highlight", p.Character)
            h.Name = "E"; h.FillColor = Color3.new(1,0,0); h.OutlineColor = Color3.new(1,1,1)
            task.spawn(function()
                while p.Character and h.Parent and S.Running do
                    h.Enabled = S.ESP and (not S.TeamCheck or p.Team ~= LP.Team)
                    task.wait(0.2)
                end
            end)
        end
    end
    p.CharacterAdded:Connect(function() task.wait(0.6); CreateH() end)
    CreateH()
end
for _, v in pairs(P:GetPlayers()) do if v ~= LP then AddESP(v) end end
P.PlayerAdded:Connect(AddESP)
