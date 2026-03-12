--[[ 
    MASTER HUB V8.8 - FINAL STABILITY
    Keybinds:
    - Hold L-SHIFT or RIGHT-CLICK: Aimbot Lock
    - Tap INSERT: Toggle Menu Visibility
    - Tap R-SHIFT: Self-Destruct (Clears everything)
]]

local Settings = {
    Aimbot = false,
    ESP = false,
    TeamCheck = true,
    Fly = false,
    Smoothness = 0.12,
    AimPart = "Head",
    FlySpeed = 55,
    Running = true,
    Visible = true
}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

-- --- 1. BYPASS INPUT HANDLER ---
local IsAiming = false
UIS.InputBegan:Connect(function(input, processed)
    -- We ignore 'processed' so we see the key even if the game is using it for sprinting
    if input.KeyCode == Enum.KeyCode.LeftShift or input.UserInputType == Enum.UserInputType.MouseButton2 then
        IsAiming = true
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.UserInputType == Enum.UserInputType.MouseButton2 then
        IsAiming = false
    end
end)

-- --- 2. THE UNLOAD SYSTEM ---
local function UnloadScript()
    Settings.Running = false
    Settings.Aimbot = false
    Settings.ESP = false
    
    -- Clear ESP Highlights
    for _, v in pairs(Players:GetPlayers()) do
        if v.Character and v.Character:FindFirstChild("HubHighlight") then
            v.Character.HubHighlight:Destroy()
        end
    end
    
    -- Delete UI
    if game:GetService("CoreGui"):FindFirstChild("MasterHub") then
        game:GetService("CoreGui").MasterHub:Destroy()
    end
    print("Master Hub: Unloaded Successfully")
end

-- --- 3. TARGETING ENGINE ---
local function GetTarget()
    local Target, Closest = nil, 600
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LP and v.Character then
            -- Team Check Logic
            if Settings.TeamCheck and (v.Team == LP.Team or v.TeamColor == LP.TeamColor) then continue end
            
            -- Rivals Brute Force Search
            local AimPart = v.Character:FindFirstChild("Head") or v.Character:FindFirstChild("UpperTorso") or v.Character:FindFirstChild("HumanoidRootPart")
            if AimPart then
                local pos, onScreen = Camera:WorldToViewportPoint(AimPart.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - UIS:GetMouseLocation()).Magnitude
                    if dist < Closest then Closest = dist; Target = AimPart end
                end
            end
        end
    end
    return Target
end

-- --- 4. GLOW ESP ---
local function ApplyESP(plr)
    local function Update()
        if plr == LP then return end
        local char = plr.Character or plr.CharacterAdded:Wait()
        local h = char:FindFirstChild("HubHighlight") or Instance.new("Highlight")
        h.Name = "HubHighlight"; h.Parent = char
        h.FillColor = Color3.fromRGB(255, 0, 0); h.OutlineColor = Color3.new(1,1,1)
        
        RunService.Heartbeat:Connect(function()
            if h.Parent and Settings.Running then
                local isEnemy = not Settings.TeamCheck or (plr.Team ~= LP.Team)
                h.Enabled = Settings.ESP and isEnemy
            elseif not Settings.Running then
                h:Destroy()
            end
        end)
    end
    Update(); plr.CharacterAdded:Connect(Update)
end
for _, v in pairs(Players:GetPlayers()) do ApplyESP(v) end
Players.PlayerAdded:Connect(ApplyESP)

-- --- 5. MAIN LOOP ---
RunService.RenderStepped:Connect(function()
    if not Settings.Running then return end

    -- Aimbot Smooth Lock
    if Settings.Aimbot and IsAiming then
        local T = GetTarget()
        if T then
            local lookAt = CFrame.new(Camera.CFrame.Position, T.Position)
            Camera.CFrame = Camera.CFrame:Lerp(lookAt, Settings.Smoothness)
        end
    end

    -- Flight
    if Settings.Fly and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
        local vec = Vector3.new(0,0,0)
        if UIS:IsKeyDown(Enum.KeyCode.W) then vec = vec + Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then vec = vec - Camera.CFrame.LookVector end
        LP.Character.HumanoidRootPart.Velocity = (vec * Settings.FlySpeed) + Vector3.new(0,1.5,0)
    end
end)

-- --- 6. UI CONSTRUCTION ---
local sg = Instance.new("ScreenGui", game:GetService("CoreGui")); sg.Name = "MasterHub"
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 180, 0, 320); main.Position = UDim2.new(0, 50, 0, 50)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); main.Active = true; main.Draggable = true
Instance.new("UICorner", main)
local layout = Instance.new("UIListLayout", main); layout.HorizontalAlignment = "Center"; layout.Padding = UDim.new(0, 6)

local function MakeBtn(txt, setting, color, func)
    local b = Instance.new("TextButton", main)
    b.Size = UDim2.new(0, 160, 0, 35); b.Text = txt; b.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    b.TextColor3 = Color3.new(1,1,1); b.Font = "GothamBold"; b.TextSize = 10; Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        if func then func() return end
        Settings[setting] = not Settings[setting]
        b.BackgroundColor3 = Settings[setting] and color or Color3.fromRGB(35, 35, 40)
        b.Text = txt .. (setting and (Settings[setting] and ": ON" or ": OFF") or "")
    end)
end

MakeBtn("🎯 AIMBOT", "Aimbot", Color3.fromRGB(255, 140, 0))
MakeBtn("👁️ GLOW ESP", "ESP", Color3.fromRGB(255, 50, 50))
MakeBtn("✈️ FLY MODE", "Fly", Color3.fromRGB(0, 200, 100))
MakeBtn("👥 TEAM CHECK", "TeamCheck", Color3.fromRGB(0, 150, 255))
MakeBtn("❌ SELF-DESTRUCT", nil, Color3.fromRGB(200, 0, 0), UnloadScript)

-- Global Controls
UIS.InputBegan:Connect(function(i, p)
    if p then return end
    if i.KeyCode == Enum.KeyCode.RightShift then UnloadScript()
    elseif i.KeyCode == Enum.KeyCode.Insert then Settings.Visible = not Settings.Visible; main.Visible = Settings.Visible end
end)
