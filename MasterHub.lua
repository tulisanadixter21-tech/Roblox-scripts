--[[ 
    MASTER HUB v4.0 - CAVEMAN EDITION (JJSPLOIT FIX)
    No complex math. No map scanning. Just raw teleporting.
]]

local P = game:GetService("Players")
local LP = P.LocalPlayer
local CG = game:GetService("CoreGui")
local RS = game:GetService("RunService")

local S = {Farming = false, Unloaded = false}

-- CLEANUP OLD UI
if CG:FindFirstChild("CavemanUI") then CG.CavemanUI:Destroy() end

-- BAREBONES UI
local sg = Instance.new("ScreenGui", CG); sg.Name = "CavemanUI"
local main = Instance.new("Frame", sg); main.Size = UDim2.new(0, 150, 0, 100); main.Position = UDim2.new(0.1, 0, 0.4, 0); main.BackgroundColor3 = Color3.fromRGB(20, 20, 20); main.Active = true; main.Draggable = true

local btnFarm = Instance.new("TextButton", main); btnFarm.Size = UDim2.new(1, -10, 0, 40); btnFarm.Position = UDim2.new(0, 5, 0, 5); btnFarm.Text = "FARM DESERT: OFF"; btnFarm.BackgroundColor3 = Color3.fromRGB(50, 0, 0); btnFarm.TextColor3 = Color3.new(1,1,1); btnFarm.Font = "GothamBold"
local btnUnload = Instance.new("TextButton", main); btnUnload.Size = UDim2.new(1, -10, 0, 40); btnUnload.Position = UDim2.new(0, 5, 0, 50); btnUnload.Text = "UNLOAD"; btnUnload.BackgroundColor3 = Color3.fromRGB(100, 0, 0); btnUnload.TextColor3 = Color3.new(1,1,1); btnUnload.Font = "GothamBold"

btnFarm.MouseButton1Click:Connect(function()
    S.Farming = not S.Farming
    btnFarm.Text = "FARM DESERT: " .. (S.Farming and "ON" or "OFF")
    btnFarm.BackgroundColor3 = S.Farming and Color3.fromRGB(0, 100, 0) or Color3.fromRGB(50, 0, 0)
end)

btnUnload.MouseButton1Click:Connect(function()
    S.Unloaded = true
    S.Farming = false
    sg:Destroy()
end)

-- BRUTE FORCE LOOP
RS.Stepped:Connect(function()
    if S.Unloaded or not S.Farming then return end
    
    local char = LP.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    -- 1. FORCE EQUIP COMBAT
    local tool = LP.Backpack:FindFirstChild("Combat")
    if tool then char.Humanoid:EquipTool(tool) end

    -- 2. AUTO CLICKER
    game:GetService("VirtualUser"):Button1Down(Vector2.new(0,0))

    -- 3. FIND DESERT BANDIT & BRUTE FORCE TELEPORT
    local targetMob = nil
    for _, v in pairs(workspace.Enemies:GetChildren()) do
        if v.Name == "Desert Bandit" and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
            targetMob = v
            break
        end
    end

    if targetMob then
        -- Hover directly above the mob
        char.HumanoidRootPart.CFrame = targetMob.HumanoidRootPart.CFrame * CFrame.new(0, 6, 0)
        char.HumanoidRootPart.Velocity = Vector3.new(0,0,0) -- Stop bouncing
    else
        -- If no mob is spawned, sit at the spawner
        local spawner = workspace.EnemySpawns:FindFirstChild("Desert Bandit")
        if spawner then
            char.HumanoidRootPart.CFrame = spawner.CFrame * CFrame.new(0, 10, 0)
            char.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
        end
    end
end)
