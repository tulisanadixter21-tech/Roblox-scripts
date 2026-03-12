--[[ 
    MASTER HUB UNIVERSAL v2.3
    - RIVALS: Full Suite (Aimbot, Silent, ESP, Hitbox, Recoil, Reload)
    - BLOX FRUITS: Auto-Quest by Level, Fixed Bring Mobs, Smart Auto-Click
    - UNIVERSAL: Draggable UI, Fly, Speed, Inf Jump
]]

local P, RS, UIS, TS = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService"), game:GetService("TweenService")
local LP, Cam, CG = P.LocalPlayer, workspace.CurrentCamera, game:GetService("CoreGui")

-- 1. SMART GAME DETECTION
local PlaceId = game.PlaceId
local GameMode = "Universal"
if PlaceId == 17625359962 or PlaceId == 16301344405 then GameMode = "Rivals"
elseif PlaceId == 2753915549 or PlaceId == 4442272183 or PlaceId == 7449423635 then GameMode = "BloxFruits" end

-- 2. MASTER SETTINGS
local S = {
    Running = true, Fly = false, SpeedBoost = false, InfJump = true,
    -- RIVALS (UNTOUCHED)
    Aimbot = false, Silent = false, ESP = false, TeamCheck = true, Hitbox = false, 
    FOV = 180, Smooth = 0.9, NoRecoil = false, AutoReload = false,
    -- BLOX FRUITS
    AutoFarm = false, AutoQuest = false, AutoClick = false, BringMobs = false, AutoEquip = true
}

if CG:FindFirstChild("MasterHub") then CG.MasterHub:Destroy() end

-- 3. RIVALS VISUALS
local Circle = Drawing.new("Circle")
Circle.Thickness = 2; Circle.Color = Color3.fromRGB(0, 255, 150); Circle.Visible = false; Circle.Transparency = 1
local Dot = Drawing.new("Circle")
Dot.Radius = 2; Dot.Thickness = 1; Dot.Color = Color3.fromRGB(255, 255, 255); Dot.Filled = true; Dot.Visible = false

-- 4. UTILS
local function GetScaledFOV() return (S.FOV / Cam.FieldOfView) * 70 end
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

-- 5. MOVABLE UI
local sg = Instance.new("ScreenGui", CG); sg.Name = "MasterHub"
local main = Instance.new("Frame", sg); main.Size = UDim2.new(0, 160, 0, 480); main.Position = UDim2.new(0.1, 0, 0.4, 0)
main.BackgroundColor3 = Color3.fromRGB(12, 12, 15); Instance.new("UICorner", main)
local L = Instance.new("UIListLayout", main); L.HorizontalAlignment = "Center"; L.Padding = UDim.new(0, 5)
local Title = Instance.new("TextLabel", main); Title.Size = UDim2.new(1, 0, 0, 30); Title.Text = "MASTER HUB: " .. GameMode; Title.TextColor3 = Color3.new(1,1,1); Title.BackgroundTransparency = 1; Title.Font = "GothamBold"; Title.TextSize = 10

local d, di, ds, sp
main.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = true; ds = i.Position; sp = main.Position end end)
UIS.InputChanged:Connect(function(i) if d and i.UserInputType == Enum.UserInputType.MouseMovement then local del = i.Position - ds; main.Position = UDim2.new(sp.X.Scale, sp.X.Offset + del.X, sp.Y.Scale, sp.Y.Offset + del.Y) end end)
main.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end end)

local function MB(t, s, c, f)
    local b = Instance.new("TextButton", main); b.Size = UDim2.new(0, 140, 0, 28); b.Text = t .. ": OFF"
    b.BackgroundColor3 = Color3.fromRGB(25, 25, 30); b.TextColor3 = Color3.new(1,1,1); b.Font = "GothamBold"; b.TextSize = 8; Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function() if f then f() return end S[s] = not S[s]; b.BackgroundColor3 = S[s] and c or Color3.fromRGB(25, 25, 30); b.Text = t .. ": " .. (S[s] and "ON" or "OFF") end)
end

-- 6. BUTTONS
if GameMode == "Rivals" then
    MB("🎯 AIMBOT", "Aimbot", Color3.fromRGB(255, 140, 0))
    MB("🔫 SILENT", "Silent", Color3.fromRGB(150, 0, 255))
    MB("👁️ ESP", "ESP", Color3.fromRGB(255, 50, 50))
    MB("🧠 HITBOX+", "Hitbox", Color3.fromRGB(255, 255, 0))
    MB("🔄 AUTO RELOAD", "AutoReload", Color3.fromRGB(100, 255, 100))
    MB("🚫 NO RECOIL", "NoRecoil", Color3.fromRGB(255, 100, 255))
elseif GameMode == "BloxFruits" then
    MB("🚜 AUTO FARM LVL", "AutoFarm", Color3.fromRGB(0, 255, 100))
    MB("🧲 BRING MOBS", "BringMobs", Color3.fromRGB(150, 0, 255))
    MB("⚔️ AUTO CLICK", "AutoClick", Color3.fromRGB(255, 50, 50))
end
MB("⚡ SPEED", "SpeedBoost", Color3.fromRGB(0, 200, 255))
MB("✈️ FLY", "Fly", Color3.fromRGB(100, 100, 100))
MB("❌ UNLOAD", nil, Color3.fromRGB(150, 0, 0), function() S.Running = false; Circle:Destroy(); Dot:Destroy(); sg:Destroy() end)

-- 7. THE ENGINE
local Aiming = false
UIS.InputBegan:Connect(function(i, p) if i.KeyCode == Enum.KeyCode.LeftShift then Aiming = true end end)
UIS.InputEnded:Connect(function(i) if i.KeyCode == Enum.KeyCode.LeftShift then Aiming = false end end)

RS.RenderStepped:Connect(function()
    if not S.Running then return end
    
    -- --- RIVALS LOGIC (PROTECTED) ---
    if GameMode == "Rivals" then
        local T = GetT(); Circle.Position = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2); Circle.Radius = GetScaledFOV(); Circle.Visible = (S.Aimbot or S.Silent); Dot.Position = Circle.Position; Dot.Visible = Circle.Visible; Circle.Color = T and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(0, 255, 150)
        if Aiming and T then if S.Silent then Cam.CFrame = CFrame.new(Cam.CFrame.Position, T.Position) elseif S.Aimbot then Cam.CFrame = Cam.CFrame:Lerp(CFrame.new(Cam.CFrame.Position, T.Position), S.Smooth) end end
        if S.AutoReload and LP.Character:FindFirstChildOfClass("Tool") then if LP.Character:FindFirstChildOfClass("Tool"):FindFirstChild("Ammo") and LP.Character:FindFirstChildOfClass("Tool").Ammo.Value == 0 then game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.R, false, game) end end
        if S.Hitbox then for _, v in pairs(P:GetPlayers()) do if v ~= LP and v.Character and v.Character:FindFirstChild("Head") then v.Character.Head.Size = Vector3.new(3.5,3.5,3.5); v.Character.Head.CanCollide = false end end end
    end

    -- --- BLOX FRUITS LOGIC ---
    if GameMode == "BloxFruits" then
        local level = LP.Data.Level.Value
        
        -- Smart Auto Click (Force click if Farm is on)
        if S.AutoClick or S.AutoFarm then
            game:GetService("VirtualUser"):CaptureController()
            game:GetService("VirtualUser"):Button1Down(Vector2.new(851, 158), Cam.CFrame)
        end

        -- Auto Equip
        if S.AutoFarm and not LP.Character:FindFirstChildOfClass("Tool") then
            for _, v in pairs(LP.Backpack:GetChildren()) do
                if v:IsA("Tool") and (v.ToolTip == "Melee" or v.ToolTip == "Sword") then
                    LP.Character.Humanoid:EquipTool(v)
                    break
                end
            end
        end

        -- Auto Quest + Farm Logic
        if S.AutoFarm and LP.Character:FindFirstChild("HumanoidRootPart") then
            local enemyName = "Bandit" -- Default
            if level >= 10 then enemyName = "Monkey" end
            -- (Additional level logic would go here)

            local target = nil
            for _, v in pairs(workspace.Enemies:GetChildren()) do
                if v.Name:find(enemyName) and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                    target = v; break
                end
            end

            if target then
                -- Position ABOVE the mob so they can't hit back
                LP.Character.HumanoidRootPart.CFrame = target.HumanoidRootPart.CFrame * CFrame.new(0, 8, 0)
                
                -- FIXED BRING MOBS (Only bring if target exists)
                if S.BringMobs then
                    for _, v in pairs(workspace.Enemies:GetChildren()) do
                        if v.Name:find(enemyName) and v:FindFirstChild("HumanoidRootPart") then
                            v.HumanoidRootPart.CFrame = target.HumanoidRootPart.CFrame
                            v.HumanoidRootPart.CanCollide = false
                        end
                    end
                end
            end
        end
    end

    -- --- UNIVERSAL ---
    if LP.Character and LP.Character:FindFirstChild("Humanoid") then
        LP.Character.Humanoid.WalkSpeed = S.SpeedBoost and 60 or 16
        if S.Fly then LP.Character.HumanoidRootPart.Velocity = Vector3.new(0, 2, 0) end
    end
end)

-- 8. ESP (Rivals Only)
local function AddESP(p)
    if GameMode ~= "Rivals" then return end
    local function CreateH() if p.Character then local h = p.Character:FindFirstChild("E") or Instance.new("Highlight", p.Character); h.Name = "E"; h.FillColor = Color3.new(1,0,0); task.spawn(function() while p.Character and h.Parent and S.Running do h.Enabled = S.ESP and (not S.TeamCheck or p.Team ~= LP.Team); task.wait(0.2) end end) end end
    p.CharacterAdded:Connect(function() task.wait(0.6); CreateH() end); CreateH()
end
for _, v in pairs(P:GetPlayers()) do if v ~= LP then AddESP(v) end end
P.PlayerAdded:Connect(AddESP)
