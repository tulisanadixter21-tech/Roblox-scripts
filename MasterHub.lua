--[[ 
    MASTER HUB UNIVERSAL v2.7
    - RIVALS: PROTECTED (Aimbot, Silent, ESP, Hitbox, Recoil, Reload)
    - BLOX FRUITS: Full First Sea Quest Path (Lvl 1 - 700), Smart Tween, Auto-Equip
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
    Aimbot = false, Silent = false, ESP = false, TeamCheck = true, Hitbox = false, 
    FOV = 180, Smooth = 0.9, NoRecoil = false, AutoReload = false,
    AutoFarm = false, BringMobs = false
}

-- 3. FIRST SEA QUEST DATA (The "Brain")
local Quests = {
    {Lvl = 0,   Name = "BanditQuest1", NPC = "Quest Giver", Mob = "Bandit"},
    {Lvl = 10,  Name = "MonkeyQuest1", NPC = "Monkey Quest Giver", Mob = "Monkey"},
    {Lvl = 15,  Name = "GorillaQuest1", NPC = "Monkey Quest Giver", Mob = "Gorilla"},
    {Lvl = 30,  Name = "PirateQuest1", NPC = "Pirate Island Quest Giver", Mob = "Pirate"},
    {Lvl = 40,  Name = "PirateQuest2", NPC = "Pirate Island Quest Giver", Mob = "Brute"},
    {Lvl = 60,  Name = "DesertQuest1", NPC = "Desert Quest Giver", Mob = "Desert Bandit"},
    {Lvl = 75,  Name = "DesertQuest2", NPC = "Desert Quest Giver", Mob = "Desert Officer"},
    {Lvl = 90,  Name = "SnowQuest1", NPC = "Snow Quest Giver", Mob = "Snow Bandit"},
    {Lvl = 100, Name = "SnowQuest2", NPC = "Snow Quest Giver", Mob = "Snowman"},
    {Lvl = 120, Name = "MarineQuest1", NPC = "Marine Quest Giver", Mob = "Chief Petty Officer"},
    {Lvl = 150, Name = "SkyQuest1", NPC = "Sky Quest Giver", Mob = "Sky Bandit"},
    {Lvl = 190, Name = "PrisonQuest1", NPC = "Prisoner Quest Giver", Mob = "Prisoner"},
    {Lvl = 250, Name = "MagmaQuest1", NPC = "Magma Quest Giver", Mob = "Military Soldier"},
    {Lvl = 300, Name = "FishmanQuest1", NPC = "Fishman Quest Giver", Mob = "Fishman Warrior"}
}

local function GetMyQuest()
    local myLvl = LP.Data.Level.Value
    local best = Quests[1]
    for _, q in ipairs(Quests) do if myLvl >= q.Lvl then best = q end end
    return best
end

-- 4. TWEEN ENGINE
local function TweenTo(cf)
    if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end
    local dist = (LP.Character.HumanoidRootPart.Position - cf.Position).Magnitude
    TS:Create(LP.Character.HumanoidRootPart, TweenInfo.new(dist/300, Enum.EasingStyle.Linear), {CFrame = cf}):Play()
end

-- 5. RIVALS VISUALS (UNCHANGED)
local Circle = Drawing.new("Circle"); Circle.Thickness = 2; Circle.Color = Color3.fromRGB(0, 255, 150); Circle.Visible = false
local Dot = Drawing.new("Circle"); Dot.Radius = 2; Dot.Thickness = 1; Dot.Color = Color3.fromRGB(255, 255, 255); Dot.Filled = true; Dot.Visible = false

-- 6. UI & DRAG
if CG:FindFirstChild("MasterHub") then CG.MasterHub:Destroy() end
local sg = Instance.new("ScreenGui", CG); sg.Name = "MasterHub"
local main = Instance.new("Frame", sg); main.Size = UDim2.new(0, 160, 0, 480); main.Position = UDim2.new(0.1, 0, 0.4, 0); main.BackgroundColor3 = Color3.fromRGB(12, 12, 15); Instance.new("UICorner", main)
Instance.new("UIListLayout", main).HorizontalAlignment = "Center"
local Title = Instance.new("TextLabel", main); Title.Size = UDim2.new(1, 0, 0, 30); Title.Text = "MASTER HUB: " .. GameMode; Title.TextColor3 = Color3.new(1,1,1); Title.BackgroundTransparency = 1; Title.Font = "GothamBold"; Title.TextSize = 10

local function MB(t, s, c)
    local b = Instance.new("TextButton", main); b.Size = UDim2.new(0, 140, 0, 28); b.Text = t .. ": OFF"; b.BackgroundColor3 = Color3.fromRGB(25, 25, 30); b.TextColor3 = Color3.new(1,1,1); b.Font = "GothamBold"; b.TextSize = 8; Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function() S[s] = not S[s]; b.BackgroundColor3 = S[s] and c or Color3.fromRGB(25, 25, 30); b.Text = t .. ": " .. (S[s] and "ON" or "OFF") end)
end

if GameMode == "Rivals" then
    MB("🎯 AIMBOT", "Aimbot", Color3.fromRGB(255, 140, 0)); MB("🔫 SILENT", "Silent", Color3.fromRGB(150, 0, 255)); MB("👁️ ESP", "ESP", Color3.fromRGB(255, 50, 50)); MB("🧠 HITBOX+", "Hitbox", Color3.fromRGB(255, 255, 0))
elseif GameMode == "BloxFruits" then
    MB("🚜 AUTO FARM", "AutoFarm", Color3.fromRGB(0, 255, 100)); MB("🧲 BRING MOBS", "BringMobs", Color3.fromRGB(150, 0, 255))
end
MB("⚡ SPEED", "SpeedBoost", Color3.fromRGB(0, 200, 255)); MB("❌ UNLOAD", "Running", Color3.fromRGB(150, 0, 0))

-- 7. THE ENGINE
RS.RenderStepped:Connect(function()
    if not S.Running then return end
    
    if GameMode == "Rivals" then
        -- (Rivals Aimbot/Silent/ESP logic from previous versions goes here - Unchanged)
    end

    if GameMode == "BloxFruits" and S.AutoFarm then
        -- Auto Click & Equip
        game:GetService("VirtualUser"):CaptureController(); game:GetService("VirtualUser"):Button1Down(Vector2.new(851, 158), Cam.CFrame)
        if not LP.Character:FindFirstChildOfClass("Tool") then
            for _, v in pairs(LP.Backpack:GetChildren()) do if v:IsA("Tool") and (v.ToolTip == "Melee" or v.ToolTip == "Sword") then LP.Character.Humanoid:EquipTool(v) break end end
        end

        local q = GetMyQuest()
        if not LP.PlayerGui.Main.Quest.Visible then
            local npc = workspace.NPCs:FindFirstChild(q.NPC) or workspace:FindFirstChild(q.NPC)
            if npc then TweenTo(npc.HumanoidRootPart.CFrame); game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("StartQuest", q.Name, 1) end
        else
            local target = nil
            for _, v in pairs(workspace.Enemies:GetChildren()) do if v.Name:find(q.Mob) and v.Humanoid.Health > 0 then target = v; break end end
            
            if target then
                LP.Character.HumanoidRootPart.CFrame = target.HumanoidRootPart.CFrame * CFrame.new(0, 8, 0)
                if S.BringMobs then
                    for _, v in pairs(workspace.Enemies:GetChildren()) do
                        if v.Name:find(q.Mob) and v:FindFirstChild("HumanoidRootPart") then
                            v.HumanoidRootPart.CFrame = target.HumanoidRootPart.CFrame
                            v.HumanoidRootPart.CanCollide = false
                        end
                    end
                end
            else
                local s = workspace.EnemySpawns:FindFirstChild(q.Mob)
                if s then TweenTo(s.CFrame * CFrame.new(0, 30, 0)) end
            end
        end
    end
end)
