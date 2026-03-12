--[[ 
    MASTER HUB V11.0 - SILENT OVERDRIVE
    - Silent Aim: Bullets track targets in FOV
    - Center FOV: Locked to screen center
    - Speed: Instant Snap (0.95)
]]

local Settings = {
    Aimbot = false,
    SilentAim = false,
    ESP = false,
    TeamCheck = true,
    Fly = false,
    -- OVERDRIVE TUNING
    Smoothness = 0.95,
    FOV = 180,
    FlySpeed = 70,
    Running = true
}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- --- 1. FOV VISUALS ---
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.Color = Color3.fromRGB(255, 50, 50) -- Red for Silent Aim
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Visible = false

-- --- 2. THE TARGETING CORE ---
local function GetClosestTarget()
    local Target, Closest = nil, Settings.FOV
    local Center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LP and v.Character then
            if Settings.TeamCheck and (v.Team == LP.Team or v.TeamColor == LP.TeamColor) then continue end
            
            local Part = v.Character:FindFirstChild("Head") or v.Character:FindFirstChild("UpperTorso")
            if Part then
                local pos, onScreen = Camera:WorldToViewportPoint(Part.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - Center).Magnitude
                    if dist < Closest then 
                        Closest = dist
                        Target = Part 
                    end
                end
            end
        end
    end
    return Target
end

-- --- 3. SILENT AIM LOGIC ---
-- This hooks the game's internal 'Namecall' to redirect shots
local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", function(Self, ...)
    local Args = {...}
    local Method = getnamecallmethod()

    if Settings.SilentAim and Method == "FindPartOnRayWithIgnoreList" or Method == "Raycast" then
        local T = GetClosestTarget()
        if T then
            -- This forces the bullet's destination to the target's position
            return T, T.Position, T.Normal, T.Material
        end
    end
    return OldNamecall(Self, ...)
end)

-- --- 4. ENGINE LOOPS ---
local IsAiming = false
UIS.InputBegan:Connect(function(i) 
    if i.KeyCode == Enum.KeyCode.LeftShift or i.UserInputType == Enum.UserInputType.MouseButton2 then IsAiming = true end 
end)
UIS.InputEnded:Connect(function(i) 
    if i.KeyCode == Enum.KeyCode.LeftShift or i.UserInputType == Enum.UserInputType.MouseButton2 then IsAiming = false end 
end)

RunService.RenderStepped:Connect(function()
    if not Settings.Running then return end
    
    local Center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Position = Center
    FOVCircle.Radius = Settings.FOV
    FOVCircle.Visible = Settings.Aimbot or Settings.SilentAim

    if Settings.Aimbot and IsAiming then
        local T = GetClosestTarget()
        if T then
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, T.Position), Settings.Smoothness)
        end
    end
end)

-- --- 5. UI & UNLOAD ---
local function Unload()
    Settings.Running = false; FOVCircle:Destroy()
    if game:GetService("CoreGui"):FindFirstChild("MasterHub") then game:GetService("CoreGui").MasterHub:Destroy() end
end

local sg = Instance.new("ScreenGui", game:GetService("CoreGui")); sg.Name = "MasterHub"
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 180, 0, 350); main.Position = UDim2.new(0, 50, 0, 50)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 15); main.Active = true; main.Draggable = true
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

MakeBtn("🎯 AIMBOT (SNAP)", "Aimbot", Color3.fromRGB(255, 140, 0))
MakeBtn("🔫 SILENT AIM", "SilentAim", Color3.fromRGB(200, 0, 255))
MakeBtn("👁️ GLOW ESP", "ESP", Color3.fromRGB(255, 50, 50))
MakeBtn("✈️ FLY MODE", "Fly", Color3.fromRGB(0, 200, 100))
MakeBtn("❌ SELF-DESTRUCT", nil, Color3.fromRGB(200, 0, 0), Unload)
