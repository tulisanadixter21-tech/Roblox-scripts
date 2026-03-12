--[[ 
    MASTER HUB V9.0 - THE RIVALS PERFORMANCE UPDATE
    - Hold L-SHIFT / Right-Click: Lock Target
    - Insert: Toggle Menu | Right-Shift: Self-Destruct
]]

local Settings = {
    Aimbot = false,
    ESP = false,
    TeamCheck = true,
    Fly = false,
    -- Performance Tunings
    Smoothness = 0.65, -- Cranked for fast movement
    FOV = 150,        -- The radius of the aimbot circle
    FlySpeed = 65,
    Running = true
}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()
local Camera = workspace.CurrentCamera
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- --- 1. THE FOV CIRCLE ---
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5; FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Filled = false; FOVCircle.Transparency = 0.7; FOVCircle.Visible = false

-- --- 2. TARGET ACQUISITION ---
local function GetClosestTarget()
    local Target, Closest = nil, Settings.FOV
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LP and v.Character then
            -- Bypass team check for FFA
            if Settings.TeamCheck and (v.Team == LP.Team or v.TeamColor == LP.TeamColor) then continue end
            
            -- Priority: Head -> Torso
            local Part = v.Character:FindFirstChild("Head") or v.Character:FindFirstChild("UpperTorso")
            if Part then
                local pos, onScreen = Camera:WorldToViewportPoint(Part.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - UIS:GetMouseLocation()).Magnitude
                    if dist < Closest then Closest = dist; Target = Part end
                end
            end
        end
    end
    return Target
end

-- --- 3. MAIN ENGINE ---
local IsAiming = false
UIS.InputBegan:Connect(function(i) 
    if i.KeyCode == Enum.KeyCode.LeftShift or i.UserInputType == Enum.UserInputType.MouseButton2 then IsAiming = true end 
end)
UIS.InputEnded:Connect(function(i) 
    if i.KeyCode == Enum.KeyCode.LeftShift or i.UserInputType == Enum.UserInputType.MouseButton2 then IsAiming = false end 
end)

RunService.RenderStepped:Connect(function()
    if not Settings.Running then return end
    
    -- Update FOV Circle Position
    FOVCircle.Position = UIS:GetMouseLocation()
    FOVCircle.Radius = Settings.FOV
    FOVCircle.Visible = Settings.Aimbot

    if Settings.Aimbot and IsAiming then
        local T = GetClosestTarget()
        if T then
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

-- --- 4. GLOW ESP & SELF-DESTRUCT ---
local function Unload()
    Settings.Running = false; Settings.Aimbot = false; Settings.ESP = false
    FOVCircle:Destroy()
    for _, v in pairs(Players:GetPlayers()) do
        if v.Character and v.Character:FindFirstChild("HubHighlight") then v.Character.HubHighlight:Destroy() end
    end
    if game:GetService("CoreGui"):FindFirstChild("MasterHub") then game:GetService("CoreGui").MasterHub:Destroy() end
end

local function ApplyESP(plr)
    local function Update()
        if plr == LP or not Settings.Running then return end
        local char = plr.Character or plr.CharacterAdded:Wait()
        local h = char:FindFirstChild("HubHighlight") or Instance.new("Highlight", char)
        h.Name = "HubHighlight"; h.FillColor = Color3.fromRGB(255, 0, 0)
        RunService.Heartbeat:Connect(function()
            if h.Parent and Settings.Running then
                h.Enabled = Settings.ESP and (not Settings.TeamCheck or plr.Team ~= LP.Team)
            end
        end)
    end
    Update(); plr.CharacterAdded:Connect(Update)
end
for _, v in pairs(Players:GetPlayers()) do ApplyESP(v) end
Players.PlayerAdded:Connect(ApplyESP)

-- --- 5. THE UI ---
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
MakeBtn("❌ SELF-DESTRUCT", nil, Color3.fromRGB(200, 0, 0), Unload)

UIS.InputBegan:Connect(function(i, p)
    if p then return end
    if i.KeyCode == Enum.KeyCode.RightShift then Unload()
    elseif i.KeyCode == Enum.KeyCode.Insert then main.Visible = not main.Visible end
end)
