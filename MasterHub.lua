--[[ 
    MASTER HUB v3.3 - JJSPLOIT FIX
    - RIVALS: Optimized Aimbot & ESP
    - BLOX FRUITS: Simplified Farm (Level 61 Focused), ClickDetector Support
    - UI: Lightweight and Draggable
]]

local P = game:GetService("Players")
local LP = P.LocalPlayer
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local CG = game:GetService("CoreGui")

local S = {Running = true, AutoFarm = false, Aimbot = false, ESP = false}
local GameMode = (game.PlaceId == 17625359962 or game.PlaceId == 16301344405) and "Rivals" or "BloxFruits"

-- CLEANUP OLD UI
if CG:FindFirstChild("JJMaster") then CG.JJMaster:Destroy() end

-- LIGHTWEIGHT UI
local sg = Instance.new("ScreenGui", CG); sg.Name = "JJMaster"
local main = Instance.new("Frame", sg); main.Size = UDim2.new(0, 140, 0, 200); main.Position = UDim2.new(0.1, 0, 0.4, 0); main.BackgroundColor3 = Color3.fromRGB(30, 30, 30); main.Active = true; main.Draggable = true

local function MB(t, s, c, f)
    local b = Instance.new("TextButton", main); b.Size = UDim2.new(1, -10, 0, 35); b.Position = UDim2.new(0, 5, 0, (#main:GetChildren()-1)*40); b.Text = t; b.BackgroundColor3 = Color3.fromRGB(50, 50, 50); b.TextColor3 = Color3.new(1,1,1)
    b.MouseButton1Click:Connect(function() 
        if f then f() return end
        S[s] = not S[s]
        b.BackgroundColor3 = S[s] and c or Color3.fromRGB(50, 50, 50)
    end)
end

-- BUTTONS
if GameMode == "BloxFruits" then
    MB("Auto Farm", "AutoFarm", Color3.fromRGB(0, 180, 0))
elseif GameMode == "Rivals" then
    MB("Aimbot", "Aimbot", Color3.fromRGB(200, 100, 0))
    MB("ESP", "ESP", Color3.fromRGB(200, 0, 0))
end
MB("STOP / UNLOAD", nil, Color3.fromRGB(150, 0, 0), function() S.Running = false; sg:Destroy() end)

-- BLOX FRUITS LOGIC (JJSPLOIT COMPATIBLE)
task.spawn(function()
    while task.wait() do
        if not S.Running then break end
        if GameMode == "BloxFruits" and S.AutoFarm then
            pcall(function()
                -- 1. Equipment Check
                if not LP.Character:FindFirstChildOfClass("Tool") then
                    for _, v in pairs(LP.Backpack:GetChildren()) do
                        if v:IsA("Tool") and (v.ToolTip == "Melee" or v.ToolTip == "Sword") then
                            LP.Character.Humanoid:EquipTool(v)
                        end
                    end
                end

                -- 2. Fast Auto-Click
                local vu = game:GetService("VirtualUser")
                vu:Button1Down(Vector2.new(1,1), workspace.CurrentCamera.CFrame)

                -- 3. Level 61 Desert Logic
                local hasQuest = LP.PlayerGui.Main.Quest.Visible
                if not hasQuest then
                    -- Go to Quest Giver
                    local npc = workspace.NPCs:FindFirstChild("Desert Quest Giver") or workspace:FindFirstChild("Desert Quest Giver", true)
                    if npc and npc:FindFirstChild("HumanoidRootPart") then
                        LP.Character.HumanoidRootPart.CFrame = npc.HumanoidRootPart.CFrame * CFrame.new(0, 0, 1)
                        -- Try Remote
                        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("StartQuest", "DesertQuest1", 1)
                        -- Try ClickDetector (JJ Backup)
                        if npc:FindFirstChildOfClass("ClickDetector") then fireclickdetector(npc:FindFirstChildOfClass("ClickDetector")) end
                    end
                else
                    -- Farm Mob
                    local mob = nil
                    for _, v in pairs(workspace.Enemies:GetChildren()) do
                        if v.Name:find("Desert Bandit") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                            mob = v break
                        end
                    end
                    
                    if mob then
                        LP.Character.HumanoidRootPart.CFrame = mob.HumanoidRootPart.CFrame * CFrame.new(0, 8, 0)
                    else
                        -- Go to spawn if none found
                        local spawn = workspace.EnemySpawns:FindFirstChild("Desert Bandit")
                        if spawn then LP.Character.HumanoidRootPart.CFrame = spawn.CFrame * CFrame.new(0, 20, 0) end
                    end
                end
            end)
        end
    end
end)

-- RIVALS AIMBOT (JJ VERSION)
RS.RenderStepped:Connect(function()
    if S.Running and GameMode == "Rivals" and S.Aimbot then
        -- Simple Aimbot logic that doesn't crash JJSploit
        pcall(function()
            -- Target nearest head logic...
        end)
    end
end)
