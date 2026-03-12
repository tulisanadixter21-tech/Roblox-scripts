--[[ 
    MASTER HUB V7.7 - FINAL DEFINITIVE
    Controls:
    - Hold L-SHIFT: Aimbot
    - Tap INSERT: Hide/Show Menu
    - Tap R-SHIFT: Self-Destruct (Unload)
]]

local Settings = {
    Aimbot = false,
    ESP = false,
    TeamCheck = true,
    Fly = false,
    NoClip = false,
    Smoothness = 0.12,
    AimPart = "Head",
    FlySpeed = 50,
    Running = true,
    Visible = true
}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

-- --- 1. CLEANUP / UNLOAD SYSTEM ---
local function UnloadScript()
    Settings.Running = false
    Settings.Aimbot = false
    Settings.ESP = false
    Settings.Fly = false
    
    -- Remove ESP Highlights
    for _, v in pairs(Players:GetPlayers()) do
        if v.Character and v.Character:FindFirstChild("HubHighlight") then
            v.Character.HubHighlight:Destroy()
        end
    end
    
    -- Destroy the UI
    if game:GetService("CoreGui"):FindFirstChild("MasterHub") then
        game:GetService("CoreGui").MasterHub:Destroy()
    end
    
    print("Master Hub v7.7: Unloaded Successfully")
end

-- --- 2. THE ENGINE ---
RunService.RenderStepped:Connect(function()
    if not Settings.Running then return end

    -- Aimbot Logic
    if Settings.Aimbot and UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
        local Target, Closest = nil, 1000
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LP and v.Character then
                if Settings.TeamCheck and (v.Team == LP.Team or v.TeamColor == LP.TeamColor) then continue end
                
                -- Target Search (Head > Torso > Root)
                local Part = v.Character:FindFirstChild("Head") or v.Character:FindFirstChild("UpperTorso") or v.Character:FindFirstChild("HumanoidRootPart")
                if Part then
                    local pos, onScreen = Camera:WorldToViewportPoint(Part.Position)
                    if onScreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - UIS:GetMouseLocation()).Magnitude
                        if dist < Closest then Closest = dist; Target = Part end
                    end
                end
            end
        end
        if Target then 
            local lookAt = CFrame.new(Camera.CFrame.Position, Target.Position)
            Camera.CFrame = Camera.CFrame:Lerp(lookAt, Settings.Smoothness)
        end
    end

    -- Flight Logic
    if Settings.Fly and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
        local vec = Vector3.new(0,0,0)
        if UIS:IsKeyDown(Enum.KeyCode.W) then vec = vec + Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then vec = vec - Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then vec = vec - Camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then vec = vec + Camera.CFrame.RightVector end
        LP.Character.HumanoidRootPart.Velocity = vec * Settings.FlySpeed
        LP.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end
end)

-- --- 3. GLOW ESP ---
local function CreateESP(plr)
    local function Update()
        if plr == LP then return end
        plr.CharacterAdded:Connect(function(char)
            if not Settings.Running then return end
            local h = Instance.new("Highlight")
            h.Name = "HubHighlight"; h.Parent = char
            h.FillColor = Color3.fromRGB(255, 0, 0)
            h.OutlineColor = Color3.new(1, 1, 1)
            
            RunService.Heartbeat:Connect(function()
                if h.Parent then
                    local isEnemy = not Settings.TeamCheck or (plr.Team ~= LP.Team and plr.TeamColor ~= LP.TeamColor)
                    h.Enabled = Settings.ESP and isEnemy
                end
            end)
        end)
        if plr.Character then -- Apply if already spawned
            local char = plr.Character
            local h = char:FindFirstChild("HubHighlight") or Instance.new("Highlight")
            h.Name = "HubHighlight"; h.Parent = char
            h.FillColor = Color3.fromRGB(255, 0, 0)
            RunService.Heartbeat:Connect(function()
                if h.Parent then
                    local isEnemy = not Settings.TeamCheck or (plr.Team ~= LP.Team and plr.TeamColor ~= LP.TeamColor)
                    h.Enabled = Settings.ESP and isEnemy
                end
            end)
        end
    end
    Update()
end
for _, v in pairs(Players:GetPlayers()) do CreateESP(v) end
Players.PlayerAdded:Connect(CreateESP)

-- --- 4. THE UI ---
local sg = Instance.new("ScreenGui", game:GetService("CoreGui"))
sg.Name = "MasterHub"
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 180, 0, 320); main.Position = UDim2.new(0, 50, 0, 50)
main.BackgroundColor3 = Color3.fromRGB(12, 12, 15); main.Active = true; main.Draggable = true
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

-- UI Buttons
MakeBtn("🎯 AIMBOT", "Aimbot", Color3.fromRGB(255, 140, 0))
MakeBtn("👁️ GLOW ESP", "ESP", Color3.fromRGB(255, 50, 50))
MakeBtn("✈️ FLY MODE", "Fly", Color3.fromRGB(0, 200, 100))
MakeBtn("👥 TEAM CHECK", "TeamCheck", Color3.fromRGB(0, 150, 255))
MakeBtn("❌ SELF-DESTRUCT", nil, Color3.fromRGB(200, 0, 0), UnloadScript)

-- --- 5. GLOBAL KEYBINDS ---
UIS.InputBegan:Connect(function(i, p)
    if p then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        UnloadScript()
    elseif i.KeyCode == Enum.KeyCode.Insert then
        Settings.Visible = not Settings.Visible
        main.Visible = Settings.Visible
    end
end)
