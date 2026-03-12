--[[ 
    MASTER HUB V14.1 | FULL COMPLETE SOURCE
    Features: Aimbot (Shift), Silent Aim, FOV Circle, Glow ESP, Fly
    Binds: L-SHIFT (Aim), INSERT (Menu), R-SHIFT (Unload)
]]

local Settings = {
    Aimbot = false,
    Silent = true,
    ESP = false,
    TeamCheck = true,
    Fly = false,
    Smoothness = 0.95,
    FOV = 180,
    FlySpeed = 75,
    Running = true
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local CoreGui = game:GetService("CoreGui")

-- Cleanup old instances
if CoreGui:FindFirstChild("MasterHub") then CoreGui.MasterHub:Destroy() end

-- --- 1. VISUALS (FOV CIRCLE) ---
local Circle = Drawing.new("Circle")
Circle.Thickness = 2
Circle.Color = Color3.fromRGB(0, 255, 150)
Circle.Visible = false
Circle.Filled = false
Circle.Transparency = 1

-- --- 2. TARGETING CORE ---
local function GetClosestTarget()
    local Target, Closest = nil, Settings.FOV
    local Center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LP and v.Character and v.Character:FindFirstChild("Head") then
            if Settings.TeamCheck and (v.Team == LP.Team) then continue end
            
            local pos, onScreen = Camera:WorldToViewportPoint(v.Character.Head.Position)
            if onScreen then
                local dist = (Vector2.new(pos.X, pos.Y) - Center).Magnitude
                if dist < Closest then 
                    Closest = dist
                    Target = v.Character.Head 
                end
            end
        end
    end
    return Target
end

-- --- 3. SILENT AIM (HOOKMETAMETHOD) ---
local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if Settings.Silent and (method == "FindPartOnRayWithIgnoreList" or method == "Raycast") then
        local T = GetClosestTarget()
        if T then
            -- Redirects the bullet path to the target head
            return T, T.Position, T.Normal, T.Material
        end
    end
    return OldNamecall(self, ...)
end)

-- --- 4. UI CONSTRUCTION ---
local sg = Instance.new("ScreenGui", CoreGui)
sg.Name = "MasterHub"
sg.DisplayOrder = 999

local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 160, 0, 320)
main.Position = UDim2.new(0.5, -80, 0.4, 0)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
main.Active = true
main.Draggable = true
Instance.new("UICorner", main)

local layout = Instance.new("UIListLayout", main)
layout.HorizontalAlignment = "Center"
layout.Padding = UDim.new(0, 5)

local function MakeBtn(txt, setting, color, func)
    local b = Instance.new("TextButton", main)
    b.Size = UDim2.new(0, 140, 0, 35)
    b.Text = txt .. ": OFF"
    b.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = "GothamBold"
    b.TextSize = 10
    Instance.new("UICorner", b)
    
    b.MouseButton1Click:Connect(function()
        if func then func() return end
        Settings[setting] = not Settings[setting]
        b.BackgroundColor3 = Settings[setting] and color or Color3.fromRGB(30, 30, 35)
        b.Text = txt .. ": " .. (Settings[setting] and "ON" or "OFF")
    end)
end

MakeBtn("🎯 AIMBOT", "Aimbot", Color3.fromRGB(255, 140, 0))
MakeBtn("🔫 SILENT AIM", "Silent", Color3.fromRGB(150, 0, 255))
MakeBtn("👁️ GLOW ESP", "ESP", Color3.fromRGB(255, 50, 50))
MakeBtn("✈️ FLY MODE", "Fly", Color3.fromRGB(0, 200, 100))
MakeBtn("👥 TEAM CHECK", "TeamCheck", Color3.fromRGB(0, 150, 255))
MakeBtn("❌ UNLOAD", nil, Color3.fromRGB(200, 0, 0), function() 
    Settings.Running = false
    Circle:Destroy()
    sg:Destroy() 
end)

-- --- 5. MAIN ENGINE LOOPS ---
local IsAiming = false
UIS.InputBegan:Connect(function(i, p)
    if i.KeyCode == Enum.KeyCode.LeftShift then IsAiming = true end
    if not p and i.KeyCode == Enum.KeyCode.Insert then main.Visible = not main.Visible end
    if not p and i.KeyCode == Enum.KeyCode.RightShift then 
        Settings.Running = false
        Circle:Destroy()
        sg:Destroy()
    end
end)
UIS.InputEnded:Connect(function(i) if i.KeyCode == Enum.KeyCode.LeftShift then IsAiming = false end end)

RunService.RenderStepped:Connect(function()
    if not Settings.Running then return end
    
    -- Update FOV Position
    Circle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    Circle.Radius = Settings.FOV
    Circle.Visible = Settings.Aimbot or Settings.Silent

    -- Smooth Aimbot Lock
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

-- --- 6. PERSISTENT ESP ---
local function AddESP(p)
    local function CreateHighlight()
        if p.Character then
            local h = p.Character:FindFirstChild("MasterHighlight") or Instance.new("Highlight", p.Character)
            h.Name = "MasterHighlight"
            h.FillColor = Color3.new(1, 0, 0)
            h.OutlineColor = Color3.new(1, 1, 1)
            
            task.spawn(function()
                while p.Character and h.Parent and Settings.Running do
                    h.Enabled = Settings.ESP and (not Settings.TeamCheck or p.Team ~= LP.Team)
                    task.wait(0.2)
                end
            end)
        end
    end
    p.CharacterAdded:Connect(function() task.wait(0.6); CreateHighlight() end)
    CreateHighlight()
end

for _, v in pairs(Players:GetPlayers()) do if v ~= LP then AddESP(v) end end
Players.PlayerAdded:Connect(AddESP)
