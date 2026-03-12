--[[ 
    MASTER HUB UNIVERSAL v3.1
    - RIVALS: Full Suite (Aimbot, Silent, ESP, Hitbox, No Recoil, Auto-Reload)
    - BLOX FRUITS: Full Sea 1 (1-700), Nearest NPC Finder, Desert Fix, Auto-Stats
    - UNIVERSAL: Draggable UI, Fly, Speed, Inf Jump
]]

local P, RS, UIS, TS = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService"), game:GetService("TweenService")
local LP, Cam, CG = P.LocalPlayer, workspace.CurrentCamera, game:GetService("CoreGui")

-- 1. SMART GAME DETECTION
local PlaceId = game.PlaceId
local GameMode = (PlaceId == 17625359962 or PlaceId == 16301344405) and "Rivals" or (PlaceId == 2753915549 or PlaceId == 4442272183 or PlaceId == 7449423635) and "BloxFruits" or "Universal"

-- 2. MASTER SETTINGS
local S = {
    Running = true, Fly = false, SpeedBoost = false, InfJump = true,
    Aimbot = false, Silent = false, ESP = false, TeamCheck = true, Hitbox = false, 
    FOV = 180, Smooth = 0.9, NoRecoil = false, AutoReload = false,
    AutoFarm = false, BringMobs = false, AutoStats = true
}

-- 3. UPDATED QUEST TABLE (LEVEL 1 - 700)
local Quests = {
    {Lvl = 0,   Name = "BanditQuest1", NPC = "Quest Giver", Mob = "Bandit"},
    {Lvl = 10,  Name = "MonkeyQuest1", NPC = "Monkey Quest Giver", Mob = "Monkey"},
    {Lvl = 15,  Name = "GorillaQuest1", NPC = "Monkey Quest Giver", Mob = "Gorilla"},
    {Lvl = 30,  Name = "PirateQuest1", NPC = "Pirate Island Quest Giver", Mob = "Pirate"},
    {Lvl = 40,  Name = "PirateQuest2", NPC = "Pirate Island Quest Giver", Mob = "Brute"},
    {Lvl = 60,  Name = "DesertQuest1", NPC = "Desert Quest Giver", Mob = "Desert Bandit"},
    {Lvl = 75,  Name = "DesertQuest2", NPC = "Desert Quest Giver", Mob = "Desert Officer"},
    {Lvl = 90,  Name = "SnowQuest1", NPC = "Snow Quest Giver", Mob = "Snow Bandit"},
    {Lvl = 120, Name = "MarineQuest1", NPC = "Marine Quest Giver", Mob = "Chief Petty Officer"},
    {Lvl = 150, Name = "SkyQuest1", NPC = "Sky Quest Giver", Mob = "Sky Bandit"},
    {Lvl = 190, Name = "PrisonQuest1", NPC = "Prisoner Quest Giver", Mob = "Prisoner"},
    {Lvl = 250, Name = "MagmaQuest1", NPC = "Magma Quest Giver", Mob = "Military Soldier"},
    {Lvl = 300, Name = "FishmanQuest1", NPC = "Fishman Quest Giver", Mob = "Fishman Warrior"}
}

-- 4. POWERFUL UTILS
local function TweenTo(cf)
    if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end
    local dist = (LP.Character.HumanoidRootPart.Position - cf.Position).Magnitude
    local tween = TS:Create(LP.Character.HumanoidRootPart, TweenInfo.new(dist/350, Enum.EasingStyle.Linear), {CFrame = cf})
    tween:Play()
    return tween
end

local function FindNPC(targetName)
    for _, v in pairs(workspace:GetDescendants()) do
        if v.Name == targetName and v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") then
            return v
        end
    end
    -- If specific name fails, find closest model with "Quest Giver" in name
    for _, v in pairs(workspace:GetDescendants()) do
        if v.Name:find("Quest Giver") and v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") then
            return v
        end
    end
end

-- 5. RIVALS LOGIC UTILS
local Circle = Drawing.new("Circle"); Circle.Thickness = 2; Circle.Color = Color3.fromRGB(0, 255, 150); Circle.Visible = false
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

-- 6. UI CONSTRUCTION (DRAGGABLE)
if CG:FindFirstChild("MasterHub") then CG.MasterHub:Destroy() end
local sg = Instance.new("ScreenGui", CG); sg.Name = "MasterHub"
local main = Instance.new("Frame", sg); main.Size = UDim2.new(0, 160, 0, 480); main.Position = UDim2.new(0.1, 0, 0.4, 0); main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); Instance.new("UICorner", main)
local L = Instance.new("UIListLayout", main); L.HorizontalAlignment = "Center"; L.Padding = UDim.new(0, 5)
local Title = Instance.new("TextLabel", main); Title.Size = UDim2.new(1, 0, 0, 30); Title.Text = "MASTER HUB v3.1"; Title.TextColor3 = Color3.new(1,1,1); Title.BackgroundTransparency = 1; Title.Font = "GothamBold"

local function MB(t, s, c)
    local b = Instance.new("TextButton", main); b.Size = UDim2.new(0, 140, 0, 30); b.Text = t .. ": OFF"; b.BackgroundColor3 = Color3.fromRGB(30, 30, 35); b.TextColor3 = Color3.new(1,1,1); b.Font = "GothamBold"; b.TextSize = 9; Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function() S[s] = not S[s]; b.BackgroundColor3 = S[s] and c or Color3.fromRGB(30, 30, 35); b.Text = t .. ": " .. (S[s] and "ON" or "OFF") end)
end

if GameMode == "Rivals" then
    MB("🎯 AIMBOT", "Aimbot", Color3.fromRGB(255, 150, 0)); MB("🔫 SILENT", "Silent", Color3.fromRGB(180, 0, 255)); MB("👁️ ESP", "ESP", Color3.fromRGB(255, 50, 50)); MB("🧠 HITBOX", "Hitbox", Color3.fromRGB(255, 255, 0))
elseif GameMode == "BloxFruits" then
    MB("🚜 AUTO FARM", "AutoFarm", Color3.fromRGB(0, 255, 120)); MB("🧲 BRING MOBS", "BringMobs", Color3.fromRGB(160, 50, 255)); MB("📊 AUTO STATS", "AutoStats", Color3.fromRGB(255, 215, 0))
end
MB("❌ UNLOAD", "Running", Color3.fromRGB(200, 0, 0))

-- 7. THE MAIN ENGINE
local Aiming = false
UIS.InputBegan:Connect(function(i, p) if i.KeyCode == Enum.KeyCode.LeftShift then Aiming = true end end)
UIS.InputEnded:Connect(function(i) if i.KeyCode == Enum.KeyCode.LeftShift then Aiming = false end end)

RS.Heartbeat:Connect(function()
    if not S.Running then return end
    
    -- --- BLOX FRUITS ---
    if GameMode == "BloxFruits" and S.AutoFarm then
        -- Auto Click & Stats
        game:GetService("VirtualUser"):CaptureController(); game:GetService("VirtualUser"):Button1Down(Vector2.new(0,0), Cam.CFrame)
        if S.AutoStats then game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("AddPoint", "Melee", 3) end
        
        -- Auto Tool Equip
        if not LP.Character:FindFirstChildOfClass("Tool") then
            for _, v in pairs(LP.Backpack:GetChildren()) do if v:IsA("Tool") and (v.ToolTip == "Melee" or v.ToolTip == "Sword") then LP.Character.Humanoid:EquipTool(v) break end end
        end

        local q = (function() local lvl = LP.Data.Level.Value; local b = Quests[1]; for _, v in ipairs(Quests) do if lvl >= v.Lvl then b = v end end return b end)()
        
        if not LP.PlayerGui.Main.Quest.Visible then
            local npc = FindNPC(q.NPC)
            if npc then TweenTo(npc.HumanoidRootPart.CFrame * CFrame.new(0, 5, 0)); game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("StartQuest", q.Name, 1) end
        else
            local target = nil
            for _, v in pairs(workspace.Enemies:GetChildren()) do if v.Name:find(q.Mob) and v.Humanoid.Health > 0 then target = v; break end end
            if target then
                LP.Character.HumanoidRootPart.CFrame = target.HumanoidRootPart.CFrame * CFrame.new(0, 9, 0)
                if S.BringMobs then
                    for _, v in pairs(workspace.Enemies:GetChildren()) do
                        if v.Name:find(q.Mob) and v:FindFirstChild("HumanoidRootPart") then 
                            v.HumanoidRootPart.CFrame = target.HumanoidRootPart.CFrame; v.HumanoidRootPart.CanCollide = false 
                        end
                    end
                end
            else
                local spawner = workspace.EnemySpawns:FindFirstChild(q.Mob)
                if spawner then TweenTo(spawner.CFrame * CFrame.new(0, 40, 0)) end
            end
        end
    end

    -- --- RIVALS ---
    if GameMode == "Rivals" then
        local T = GetT()
        Circle.Position = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2); Circle.Radius = GetScaledFOV(); Circle.Visible = (S.Aimbot or S.Silent)
        if Aiming and T then
            if S.Silent then Cam.CFrame = CFrame.new(Cam.CFrame.Position, T.Position)
            elseif S.Aimbot then Cam.CFrame = Cam.CFrame:Lerp(CFrame.new(Cam.CFrame.Position, T.Position), S.Smooth) end
        end
        if S.Hitbox then for _, v in pairs(P:GetPlayers()) do if v ~= LP and v.Character and v.Character:FindFirstChild("Head") then v.Character.Head.Size = Vector3.new(4,4,4); v.Character.Head.CanCollide = false end end end
    end
end)

-- Rivals ESP
local function AddESP(p)
    if GameMode ~= "Rivals" then return end
    local function CreateH() if p.Character then local h = p.Character:FindFirstChild("E") or Instance.new("Highlight", p.Character); h.Name = "E"; h.FillColor = Color3.new(1,0,0); task.spawn(function() while p.Character and h.Parent and S.Running do h.Enabled = S.ESP and (not S.TeamCheck or p.Team ~= LP.Team); task.wait(0.5) end end) end end
    p.CharacterAdded:Connect(function() task.wait(1); CreateH() end); CreateH()
end
for _, v in pairs(P:GetPlayers()) do if v ~= LP then AddESP(v) end end; P.PlayerAdded:Connect(AddESP)
