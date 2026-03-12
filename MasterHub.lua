--[[ 
    MASTER HUB V12.5 - PERFORMANCE UPDATE
    - Bind: Left-Shift ONLY (Right-Click removed)
    - Load Speed: Instant (Optimized Init)
    - Version: Stable 2026 Build
]]

local Settings = {
    Aimbot = false,
    ESP = false,
    TeamCheck = true,
    Fly = false,
    Smoothness = 0.95,
    FOV = 180,
    FlySpeed = 75,
    Running = true,
    Visible = true
}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

-- Cleanup old instances to prevent UI stacking
if CoreGui:FindFirstChild("MasterHub") then CoreGui.MasterHub:Destroy() end

-- --- 1. TARGETING SYSTEM ---
local function GetTarget()
    local Target, Closest = nil, Settings.FOV
    local Center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LP and v.Character then
            -- Team Check (Toggle off for FFA)
            if Settings.TeamCheck and (v.Team == LP.Team or v.TeamColor == LP.TeamColor) then continue end
            
            -- Targeted Body Parts
            local Part = v.Character:FindFirstChild("Head") or v.Character:FindFirstChild("UpperTorso")
            if Part then
                local pos, onScreen = Camera:WorldToViewportPoint(Part.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - Center).Magnitude
                    if dist < Closest then Closest = dist; Target = Part end
                end
            end
        end
    end
    return Target
end

-- --- 2. THE UI ---
local sg = Instance.new("ScreenGui", CoreGui)
sg.Name = "MasterHub"; sg.DisplayOrder = 999

local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 180, 0, 310); main.Position = UDim2.new(0.5, -90, 0.4, 0)
main.BackgroundColor3 = Color3.fromRGB(12, 12, 15); main.Active = true; main.Draggable = true
Instance.new("UICorner", main)

local layout = Instance.new("UIListLayout", main)
layout.HorizontalAlignment = "Center"; layout.Padding = UDim.new(0, 7)

local function MakeBtn(txt, setting, color, func)
    local b = Instance.new("TextButton", main)
    b.Size = UDim2.new(0, 160, 0, 35); b.Text = txt .. ": OFF"
    b.BackgroundColor3 = Color3.fromRGB(30, 30, 35); b.TextColor3 = Color3.new(1,1,1)
    b.Font = "GothamBold"; b.TextSize = 10; Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        if func then func() return end
        Settings[setting] = not Settings[setting]
        b.BackgroundColor3 = Settings[setting] and color or Color3.fromRGB(30, 30, 35)
        b.Text = txt .. ": " .. (Settings[setting] and "ON" or "OFF")
    end)
end

MakeBtn("🎯 AIMBOT", "Aimbot", Color3.fromRGB(255, 140, 0))
MakeBtn("👁️ GLOW ESP", "ESP", Color3.fromRGB(255, 50, 50))
MakeBtn("✈️ FLY MODE", "Fly", Color3.fromRGB(0, 200, 100))
MakeBtn("👥 TEAM CHECK", "TeamCheck", Color3.fromRGB(0, 150, 255))
MakeBtn("❌ UNLOAD", nil, Color3.fromRGB(200, 0, 0), function() Settings.Running = false; sg:Destroy() end)

-- --- 3. INPUT LISTENER (SHIFT ONLY) ---
local IsAiming = false
UIS.InputBegan:Connect(function(i, p)
    if i.KeyCode == Enum.KeyCode.LeftShift then 
        IsAiming = true 
    end
    -- Menu Toggle
    if not p and i.KeyCode == Enum.KeyCode.Insert then 
        main.Visible = not main.Visible 
    end
end)

UIS.InputEnded:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.LeftShift then 
        IsAiming = false 
    end
end)

-- --- 4. ENGINE LOOPS ---
RunService.RenderStepped:Connect(function()
    if not Settings.Running then return end
    
    -- Aimbot Lock
    if Settings.Aimbot and IsAiming then
        local T = GetTarget()
        if T then
            local lookAt = CFrame.new(Camera.CFrame.Position, T.Position)
            Camera.CFrame = Camera.CFrame:Lerp(lookAt, Settings.Smoothness)
        end
    end
    
    -- Flight Controls
    if Settings.Fly and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LP.Character.HumanoidRootPart
        local vec = Vector3.new(0,0,0)
        if UIS:IsKeyDown(Enum.KeyCode.W) then vec = vec + Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then vec = vec - Camera.CFrame.LookVector end
        hrp.Velocity = (vec * Settings.FlySpeed) + Vector3.new(0, 1.5, 0)
    end
end)

-- ESP Initialization
local function ApplyESP(plr)
    plr.CharacterAdded:Connect(function(char)
        if not Settings.Running then return end
        local h = Instance.new("Highlight", char)
        h.Name = "HubHighlight"; h.FillColor = Color3.fromRGB(255, 0, 0)
        RunService.Heartbeat:Connect(function()
            if h.Parent then
                h.Enabled = Settings.ESP and (not Settings.TeamCheck or plr.Team ~= LP.Team)
            end
        end)
    end)
end
for _, v in pairs(Players:GetPlayers()) do if v ~= LP then ApplyESP(v) end end
Players.PlayerAdded:Connect(ApplyESP)
