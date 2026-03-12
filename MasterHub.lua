--[[ 
    MASTER HUB V14.2 | FULL COMPLETE SOURCE
    Optimized: Fast Hooking & Minified Logic
]]

local S = {Aimbot = false, Silent = true, ESP = false, TeamCheck = true, Fly = false, Smooth = 0.95, FOV = 180, Speed = 75, Running = true}
local P, RS, UIS = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService")
local LP, Cam, CG = P.LocalPlayer, workspace.CurrentCamera, game:GetService("CoreGui")

if CG:FindFirstChild("MasterHub") then CG.MasterHub:Destroy() end

-- --- 1. VISUALS (FOV) ---
local Circle = Drawing.new("Circle")
Circle.Thickness = 2; Circle.Color = Color3.fromRGB(0, 255, 150); Circle.Visible = false; Circle.Transparency = 1

-- --- 2. TARGETING ---
local function GetT()
    local T, C = nil, S.FOV
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

-- --- 3. SILENT AIM (FAST HOOK) ---
local OldNC; OldNC = hookmetamethod(game, "__namecall", function(self, ...)
    if S.Silent and getnamecallmethod() == "Raycast" then
        local T = GetT()
        if T then return T, T.Position, T.Normal, T.Material end
    end
    return OldNC(self, ...)
end)

-- --- 4. UI ---
local sg = Instance.new("ScreenGui", CG); sg.Name = "MasterHub"; sg.DisplayOrder = 999
local main = Instance.new("Frame", sg); main.Size = UDim2.new(0, 160, 0, 320); main.Position = UDim2.new(0.5, -80, 0.4, 0)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); main.Active = true; main.Draggable = true; Instance.new("UICorner", main)
local L = Instance.new("UIListLayout", main); L.HorizontalAlignment = "Center"; L.Padding = UDim.new(0, 5)

local function MB(t, s, c, f)
    local b = Instance.new("TextButton", main); b.Size = UDim2.new(0, 140, 0, 35); b.Text = t .. ": OFF"
    b.BackgroundColor3 = Color3.fromRGB(30, 30, 35); b.TextColor3 = Color3.new(1,1,1); b.Font = "GothamBold"; b.TextSize = 10; Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        if f then f() return end
        S[s] = not S[s]; b.BackgroundColor3 = S[s] and c or Color3.fromRGB(30, 30, 35); b.Text = t .. ": " .. (S[s] and "ON" or "OFF")
    end)
end

MB("🎯 AIMBOT", "Aimbot", Color3.fromRGB(255, 140, 0))
MB("🔫 SILENT AIM", "Silent", Color3.fromRGB(150, 0, 255))
MB("👁️ GLOW ESP", "ESP", Color3.fromRGB(255, 50, 50))
MB("✈️ FLY MODE", "Fly", Color3.fromRGB(0, 200, 100))
MB("👥 TEAM CHECK", "TeamCheck", Color3.fromRGB(0, 150, 255))
MB("❌ UNLOAD", nil, Color3.fromRGB(200, 0, 0), function() S.Running = false; Circle:Destroy(); sg:Destroy() end)

-- --- 5. ENGINE ---
local Aiming = false
UIS.InputBegan:Connect(function(i, p)
    if i.KeyCode == Enum.KeyCode.LeftShift then Aiming = true end
    if not p and i.KeyCode == Enum.KeyCode.Insert then main.Visible = not main.Visible end
end)
UIS.InputEnded:Connect(function(i) if i.KeyCode == Enum.KeyCode.LeftShift then Aiming = false end end)

RS.RenderStepped:Connect(function()
    if not S.Running then return end
    Circle.Position = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    Circle.Radius = S.FOV; Circle.Visible = S.Aimbot or S.Silent
    if S.Aimbot and Aiming then
        local T = GetT()
        if T then Cam.CFrame = Cam.CFrame:Lerp(CFrame.new(Cam.CFrame.Position, T.Position), S.Smooth) end
    end
    if S.Fly and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
        local hrp, v = LP.Character.HumanoidRootPart, Vector3.new(0,0,0)
        if UIS:IsKeyDown("W") then v = v + Cam.CFrame.LookVector end
        if UIS:IsKeyDown("S") then v = v - Cam.CFrame.LookVector end
        hrp.Velocity = (v * S.Speed) + Vector3.new(0, 1.5, 0)
    end
end)

-- --- 6. ESP ---
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
