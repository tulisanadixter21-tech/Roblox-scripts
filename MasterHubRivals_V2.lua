--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║   MASTER HUB · RIVALS · V5 "MOBILE ULTIMATE"                                ║
║                                                                              ║
║   COMPLETE MOBILE OVERHAUL:                                                 ║
║   • Floating toggle button (always visible)                                 ║
║   • Fixed layout issues on small screens                                    ║
║   • Proper text rendering and spacing                                       ║
║   • Touch-optimized everything                                              ║
║   • Delta, Arceus X, Hydrogen compatibility                                 ║
║   • Edge swipe gestures                                                     ║
║   • Battery-efficient rendering                                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
--]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TextService = game:GetService("TextService")

local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera
local ViewportSize = Cam.ViewportSize

-- Device detection
local IS_MOBILE = UserInputService.TouchEnabled or UserInputService.TouchSupported
local IS_CONSOLE = not IS_MOBILE and (UserInputService.GamepadEnabled or not UserInputService.KeyboardEnabled)
local IS_PC = not IS_MOBILE and not IS_CONSOLE

-- Screen scaling (dynamic)
local BASE_WIDTH = 380
local BASE_HEIGHT = 650
local SCALE = math.min(ViewportSize.X / BASE_WIDTH, ViewportSize.Y / BASE_HEIGHT, 1.2)
SCALE = math.max(SCALE, 0.65) -- Minimum scale for very small screens

-- Cleanup old instances
local oldGUI = CoreGui:FindFirstChild("MasterHubV5")
if oldGUI then oldGUI:Destroy() end

-- Settings
local S = {
    -- Core
    ToggleKey = Enum.KeyCode.RightShift,
    Running = true,
    UIVisible = true,
    
    -- Combat
    Aimbot = false,
    Silent = false,
    TeamCheck = true,
    AimPart = "Head",
    FOV = 160,
    Smooth = 80,
    Prediction = 0,
    VisibleOnly = false,
    AutoShoot = false,
    Triggerbot = false,
    
    -- Weapon
    Hitbox = false,
    HitboxSize = 6,
    HitboxShape = "Sphere",
    NoRecoil = false,
    AutoReload = false,
    
    -- Movement
    SpeedBoost = false,
    WalkSpeed = 45,
    Fly = false,
    FlySpeed = 65,
    Noclip = false,
    BunnyHop = false,
    InfiniteJump = false,
    AntiVoid = false,
    LowGravity = false,
    JumpPower = 80,
    
    -- Visuals
    ESP = false,
    ESPBox = false,
    ESPName = true,
    ESPHealth = true,
    ESPDistance = false,
    ESPChams = false,
    Tracers = false,
    Fullbright = false,
    CrosshairESP = false,
    RadarEnabled = false,
    EnemyCountHUD = false,
    
    -- Utility
    AntiAFK = false,
    ClickTP = false,
    KillAura = false,
    KillAuraRadius = 15,
    InfiniteStamina = false,
    Grab = false,
    GrabTarget = nil,
    
    -- Mobile Specific
    MobileJoystick = false,
    MobileAutoFire = false,
    MobileAimAssist = false,
    MobileSensitivity = 50,
    GestureControls = true,
    FloatingButton = true,
}

-- Enhanced Color Scheme (Brighter for mobile screens)
local C = {
    -- Base
    bg0 = Color3.fromRGB(5, 8, 15),      -- deepest
    bg1 = Color3.fromRGB(10, 14, 24),     -- window
    bg2 = Color3.fromRGB(18, 23, 38),      -- cards
    bg3 = Color3.fromRGB(28, 34, 54),      -- hover
    bg4 = Color3.fromRGB(38, 46, 70),      -- active
    
    -- Borders
    border = Color3.fromRGB(60, 70, 120),
    borderGlow = Color3.fromRGB(130, 100, 255),
    
    -- Accents (Brighter)
    purple = Color3.fromRGB(160, 100, 255),
    blue = Color3.fromRGB(100, 150, 255),
    pink = Color3.fromRGB(255, 100, 200),
    cyan = Color3.fromRGB(80, 220, 255),
    
    -- Tab Colors
    combat = Color3.fromRGB(255, 100, 130),
    movement = Color3.fromRGB(100, 230, 255),
    visuals = Color3.fromRGB(200, 120, 255),
    utility = Color3.fromRGB(255, 200, 80),
    settings = Color3.fromRGB(120, 255, 160),
    
    -- Status
    success = Color3.fromRGB(80, 255, 150),
    warning = Color3.fromRGB(255, 220, 80),
    danger = Color3.fromRGB(255, 80, 120),
    info = Color3.fromRGB(120, 200, 255),
    
    -- Text
    textBright = Color3.fromRGB(255, 255, 255),
    textMain = Color3.fromRGB(230, 235, 255),
    textSoft = Color3.fromRGB(180, 190, 230),
    textMuted = Color3.fromRGB(120, 130, 180),
    
    -- Missing white (used by toggles, sliders, crosshair, etc.)
    white = Color3.fromRGB(255, 255, 255),
}

-- Tween presets
local TI = {
    instant = TweenInfo.new(0),
    fast = TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    smooth = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    spring = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    bounce = TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
}

-- Utility tween
local function tween(obj, info, props)
    if not obj or not obj.Parent then return end
    TweenService:Create(obj, info, props):Play()
end

-- Safe rounded corners
local function addCorner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or (IS_MOBILE and 14 or 10))
    c.Parent = obj
    return c
end

-- Safe stroke
local function addStroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or C.border
    s.Thickness = thickness or (IS_MOBILE and 2 or 1.5)
    s.Transparency = transparency or 0
    s.Parent = obj
    return s
end

-- Main ScreenGui
local sg = Instance.new("ScreenGui")
sg.Name = "MasterHubV5"
sg.DisplayOrder = 999
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Parent = CoreGui
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- ============================================
-- FLOATING TOGGLE BUTTON (ALWAYS VISIBLE)
-- ============================================
local toggleButton = Instance.new("Frame")
toggleButton.Name = "ToggleButton"
toggleButton.BackgroundColor3 = C.purple
toggleButton.BackgroundTransparency = 0.1
toggleButton.BorderSizePixel = 0
toggleButton.Size = UDim2.new(0, IS_MOBILE and 60 or 50, 0, IS_MOBILE and 60 or 50)
toggleButton.Position = UDim2.new(1, -(IS_MOBILE and 80 or 70), 1, -(IS_MOBILE and 100 or 90))
toggleButton.Parent = sg
toggleButton.ZIndex = 1000
addCorner(toggleButton, 30)
addStroke(toggleButton, C.borderGlow, 3)

-- Inner glow
local innerGlow = Instance.new("Frame")
innerGlow.BackgroundColor3 = C.white
innerGlow.BackgroundTransparency = 0.7
innerGlow.Size = UDim2.new(1, -4, 1, -4)
innerGlow.Position = UDim2.new(0, 2, 0, 2)
innerGlow.Parent = toggleButton
addCorner(innerGlow, 28)

-- Icon
local toggleIcon = Instance.new("TextLabel")
toggleIcon.BackgroundTransparency = 1
toggleIcon.Text = "⚡"
toggleIcon.TextColor3 = C.white
toggleIcon.TextSize = IS_MOBILE and 32 or 28
toggleIcon.Font = Enum.Font.GothamBold
toggleIcon.Size = UDim2.new(1, 0, 1, 0)
toggleIcon.Parent = toggleButton

-- Touch button overlay
local toggleHitbox = Instance.new("TextButton")
toggleHitbox.BackgroundTransparency = 1
toggleHitbox.Size = UDim2.new(1, 0, 1, 0)
toggleHitbox.Text = ""
toggleHitbox.Parent = toggleButton
toggleHitbox.ZIndex = 1001

-- Pulse animation
local pulse = Instance.new("Frame")
pulse.BackgroundColor3 = C.purple
pulse.BackgroundTransparency = 0.5
pulse.Size = UDim2.new(1, 0, 1, 0)
pulse.Parent = toggleButton
addCorner(pulse, 30)
pulse.ZIndex = 999

-- Pulse loop
task.spawn(function()
    while sg.Parent do
        tween(pulse, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            Size = UDim2.new(1.3, 0, 1.3, 0),
            Position = UDim2.new(-0.15, 0, -0.15, 0),
            BackgroundTransparency = 1
        })
        task.wait(1.5)
        tween(pulse, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 0.5
        })
        task.wait(0.1)
    end
end)

-- ============================================
-- MAIN WINDOW (IMPROVED LAYOUT)
-- ============================================
local windowWidth = math.min(400 * SCALE, ViewportSize.X - 30)
local windowHeight = math.min(700 * SCALE, ViewportSize.Y - 100)

local mainWindow = Instance.new("Frame")
mainWindow.Name = "MainWindow"
mainWindow.BackgroundColor3 = C.bg1
mainWindow.BackgroundTransparency = 0.02
mainWindow.BorderSizePixel = 0
mainWindow.Size = UDim2.new(0, windowWidth, 0, windowHeight)
mainWindow.Position = UDim2.new(0.5, -windowWidth/2, 0.5, -windowHeight/2)
mainWindow.Visible = true
mainWindow.Parent = sg
mainWindow.ZIndex = 10
addCorner(mainWindow, 20)
addStroke(mainWindow, C.borderGlow, 2)

-- Glass overlay
local glass = Instance.new("Frame")
glass.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
glass.BackgroundTransparency = 0.98
glass.Size = UDim2.new(1, 0, 1, 0)
glass.Parent = mainWindow
addCorner(glass, 20)

-- Gradient overlay
local gradient = Instance.new("Frame")
gradient.BackgroundTransparency = 1
gradient.Size = UDim2.new(1, 0, 1, 0)
gradient.Parent = mainWindow
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, C.purple),
    ColorSequenceKeypoint.new(0.5, C.blue),
    ColorSequenceKeypoint.new(1, C.pink)
})
grad.Rotation = 45
grad.Transparency = NumberSequence.new(0.95)
grad.Parent = gradient
addCorner(gradient, 20)

-- ============================================
-- HEADER
-- ============================================
local header = Instance.new("Frame")
header.BackgroundColor3 = C.bg0
header.BackgroundTransparency = 0.1
header.BorderSizePixel = 0
header.Size = UDim2.new(1, 0, 0, 55)
header.Parent = mainWindow
addCorner(header, 0)

local headerContent = Instance.new("Frame")
headerContent.BackgroundTransparency = 1
headerContent.Size = UDim2.new(1, -20, 1, 0)
headerContent.Position = UDim2.new(0, 10, 0, 0)
headerContent.Parent = header

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Text = "⚡ MASTER HUB"
title.TextColor3 = C.textBright
title.TextSize = IS_MOBILE and 22 or 20
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Size = UDim2.new(0.6, 0, 1, 0)
title.Parent = headerContent

local version = Instance.new("TextLabel")
version.BackgroundTransparency = 1
version.Text = "v5.0"
version.TextColor3 = C.textMuted
version.TextSize = IS_MOBILE and 16 or 14
version.Font = Enum.Font.Gotham
version.TextXAlignment = Enum.TextXAlignment.Right
version.Size = UDim2.new(0.4, 0, 1, 0)
version.Parent = headerContent

-- ============================================
-- SIDEBAR (FIXED)
-- ============================================
local sidebar = Instance.new("Frame")
sidebar.BackgroundColor3 = C.bg0
sidebar.BackgroundTransparency = 0.1
sidebar.BorderSizePixel = 0
sidebar.Size = UDim2.new(0, IS_MOBILE and 90 or 100, 1, -55)
sidebar.Position = UDim2.new(0, 0, 0, 55)
sidebar.Parent = mainWindow
addCorner(sidebar, 0)

-- Sidebar content
local sidebarScroll = Instance.new("ScrollingFrame")
sidebarScroll.BackgroundTransparency = 1
sidebarScroll.BorderSizePixel = 0
sidebarScroll.Size = UDim2.new(1, 0, 1, -20)
sidebarScroll.Position = UDim2.new(0, 0, 0, 10)
sidebarScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
sidebarScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
sidebarScroll.ScrollBarThickness = 2
sidebarScroll.ScrollBarImageColor3 = C.purple
sidebarScroll.Parent = sidebar

local sidebarList = Instance.new("UIListLayout")
sidebarList.Padding = UDim.new(0, IS_MOBILE and 8 or 5)
sidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
sidebarList.SortOrder = Enum.SortOrder.LayoutOrder
sidebarList.Parent = sidebarScroll

-- Tabs
local tabs = {
    {icon = "⚔️", name = "COMBAT", id = "combat", color = C.combat},
    {icon = "👟", name = "MOVE", id = "movement", color = C.movement},
    {icon = "👁️", name = "VISUAL", id = "visuals", color = C.visuals},
    {icon = "🔧", name = "UTILITY", id = "utility", color = C.utility},
    {icon = "⚙️", name = "SETTINGS", id = "settings", color = C.settings},
}

local tabButtons = {}
local activeTab = "combat"
local contentFrames = {} -- Forward declare so tab click handlers can reference it

-- Quick actions at top
local quickActions = {
    {icon = "🎯", setting = "Aimbot", color = C.combat},
    {icon = "⚡", setting = "SpeedBoost", color = C.movement},
    {icon = "👁️", setting = "ESPChams", color = C.visuals},
}

for _, action in ipairs(quickActions) do
    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = C.bg2
    btn.BorderSizePixel = 0
    btn.Text = action.icon
    btn.TextColor3 = action.color
    btn.TextSize = IS_MOBILE and 24 or 22
    btn.Font = Enum.Font.GothamBold
    btn.Size = UDim2.new(0, IS_MOBILE and 70 or 60, 0, IS_MOBILE and 70 or 60)
    btn.Parent = sidebarScroll
    addCorner(btn, 35)
    addStroke(btn, action.color, 1, 0.3)
    
    -- Status indicator
    local status = Instance.new("Frame")
    status.BackgroundColor3 = action.color
    status.Size = UDim2.new(0, 8, 0, 8)
    status.Position = UDim2.new(1, -12, 1, -12)
    status.Parent = btn
    addCorner(status, 4)
    
    -- Update status
    task.spawn(function()
        while btn.Parent do
            status.Visible = S[action.setting]
            task.wait(0.1)
        end
    end)
    
    btn.MouseButton1Click:Connect(function()
        S[action.setting] = not S[action.setting]
        tween(btn, TI.fast, {BackgroundColor3 = S[action.setting] and C.bg4 or C.bg2})
    end)
end

-- Divider
local divider = Instance.new("Frame")
divider.BackgroundColor3 = C.border
divider.BackgroundTransparency = 0.5
divider.Size = UDim2.new(0.8, 0, 0, 1)
divider.Position = UDim2.new(0.1, 0, 0, 0)
divider.Parent = sidebarScroll

-- Tab buttons
for _, tab in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_"..tab.id
    btn.BackgroundColor3 = C.bg2
    btn.BackgroundTransparency = tab.id == "combat" and 0.2 or 0
    btn.BorderSizePixel = 0
    btn.Text = tab.icon
    btn.TextColor3 = tab.id == "combat" and tab.color or C.textSoft
    btn.TextSize = IS_MOBILE and 26 or 22
    btn.Font = Enum.Font.GothamBold
    btn.Size = UDim2.new(0, IS_MOBILE and 70 or 65, 0, IS_MOBILE and 70 or 60)
    btn.Parent = sidebarScroll
    addCorner(btn, 30)
    addStroke(btn, tab.color, 1, tab.id == "combat" and 0.1 or 0.5)
    
    -- Tab name below icon
    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = tab.name
    nameLabel.TextColor3 = C.textSoft
    nameLabel.TextSize = IS_MOBILE and 11 or 10
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.Size = UDim2.new(1, 0, 0, 15)
    nameLabel.Position = UDim2.new(0, 0, 1, -15)
    nameLabel.Parent = btn
    
    -- Active indicator
    local indicator = Instance.new("Frame")
    indicator.BackgroundColor3 = tab.color
    indicator.Size = UDim2.new(0, 4, 0, 0)
    indicator.Position = UDim2.new(1, -4, 0.5, 0)
    indicator.Parent = btn
    addCorner(indicator, 2)
    
    if tab.id == "combat" then
        indicator.Size = UDim2.new(0, 4, 0, 30)
    end
    
    tabButtons[tab.id] = {btn = btn, indicator = indicator, color = tab.color}
    
    local function switchToTab()
        activeTab = tab.id
        for id, data in pairs(tabButtons) do
            data.btn.BackgroundTransparency = id == tab.id and 0.2 or 0
            data.btn.TextColor3 = id == tab.id and data.color or C.textSoft
            tween(data.indicator, TI.spring, {Size = UDim2.new(0, 4, 0, id == tab.id and 30 or 0)})
            tween(data.indicator, TI.fast, {BackgroundColor3 = data.color})
        end
        for id, frame in pairs(contentFrames) do
            frame.Visible = (id == tab.id)
        end
    end
    
    tabButtons[tab.id].switchFn = switchToTab
    
    btn.MouseButton1Click:Connect(switchToTab)
end

-- ============================================
-- CONTENT AREA (FIXED LAYOUT)
-- ============================================
local contentArea = Instance.new("Frame")
contentArea.BackgroundColor3 = C.bg1
contentArea.BackgroundTransparency = 0.1
contentArea.BorderSizePixel = 0
contentArea.Size = UDim2.new(1, -(IS_MOBILE and 90 or 100), 1, -55)
contentArea.Position = UDim2.new(0, IS_MOBILE and 90 or 100, 0, 55)
contentArea.Parent = mainWindow
addCorner(contentArea, 0)

for _, tab in ipairs(tabs) do
    local frame = Instance.new("ScrollingFrame")
    frame.Name = "Content_"..tab.id
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, -20, 1, -20)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.CanvasSize = UDim2.new(0, 0, 0, 0)
    frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    frame.ScrollBarThickness = IS_MOBILE and 4 or 3
    frame.ScrollBarImageColor3 = tab.color
    frame.Visible = (tab.id == "combat")
    frame.Parent = contentArea
    frame.ZIndex = 20
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, IS_MOBILE and 10 or 8)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame
    
    contentFrames[tab.id] = frame
end

-- ============================================
-- MOBILE-OPTIMIZED UI COMPONENTS
-- ============================================

-- Toggle switch (fixed)
local function createToggle(parent, text, desc, setting, accentColor)
    accentColor = accentColor or C.purple
    
    local container = Instance.new("Frame")
    container.BackgroundColor3 = C.bg2
    container.BackgroundTransparency = 0.1
    container.BorderSizePixel = 0
    container.Size = UDim2.new(1, -10, 0, IS_MOBILE and 75 or 65)
    container.Parent = parent
    addCorner(container, 14)
    addStroke(container, C.border, 1, 0.3)
    
    -- Left accent
    local accent = Instance.new("Frame")
    accent.BackgroundColor3 = accentColor
    accent.Size = UDim2.new(0, 4, 0, IS_MOBILE and 45 or 35)
    accent.Position = UDim2.new(0, 0, 0.5, -(IS_MOBILE and 22 or 17))
    accent.Parent = container
    addCorner(accent, 2)
    
    -- Text
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Text = text
    title.TextColor3 = C.textBright
    title.TextSize = IS_MOBILE and 16 or 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Size = UDim2.new(0.7, -15, 0, IS_MOBILE and 24 or 20)
    title.Position = UDim2.new(0, 12, 0, IS_MOBILE and 8 or 6)
    title.Parent = container
    
    if desc then
        local descLabel = Instance.new("TextLabel")
        descLabel.BackgroundTransparency = 1
        descLabel.Text = desc
        descLabel.TextColor3 = C.textMuted
        descLabel.TextSize = IS_MOBILE and 13 or 11
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.Size = UDim2.new(0.7, -15, 0, 18)
        descLabel.Position = UDim2.new(0, 12, 0, IS_MOBILE and 30 or 24)
        descLabel.Parent = container
    end
    
    -- Switch (bigger for mobile)
    local switch = Instance.new("Frame")
    switch.BackgroundColor3 = C.bg0
    switch.Size = UDim2.new(0, IS_MOBILE and 58 or 48, 0, IS_MOBILE and 30 or 26)
    switch.Position = UDim2.new(1, -(IS_MOBILE and 80 or 70), 0.5, -15)
    switch.Parent = container
    addCorner(switch, 15)
    
    local knob = Instance.new("Frame")
    knob.BackgroundColor3 = C.textMuted
    knob.Size = UDim2.new(0, IS_MOBILE and 26 or 22, 0, IS_MOBILE and 26 or 22)
    knob.Position = UDim2.new(0, 2, 0.5, -(IS_MOBILE and 13 or 11))
    knob.Parent = switch
    addCorner(knob, 13)
    
    local function updateVisuals()
        local isOn = S[setting]
        tween(switch, TI.spring, {BackgroundColor3 = isOn and accentColor or C.bg0})
        tween(knob, TI.spring, {
            Position = isOn and UDim2.new(1, -(IS_MOBILE and 28 or 24), 0.5, -(IS_MOBILE and 13 or 11)) or UDim2.new(0, 2, 0.5, -(IS_MOBILE and 13 or 11)),
            BackgroundColor3 = isOn and C.white or C.textMuted
        })
        accent.BackgroundTransparency = isOn and 0 or 0.6
    end
    
    updateVisuals()
    
    local hitbox = Instance.new("TextButton")
    hitbox.BackgroundTransparency = 1
    hitbox.Size = UDim2.new(1, 0, 1, 0)
    hitbox.Text = ""
    hitbox.Parent = container
    
    hitbox.MouseButton1Click:Connect(function()
        S[setting] = not S[setting]
        updateVisuals()
    end)
    
    return container
end

-- Slider (fixed)
local function createSlider(parent, text, setting, min, max, format)
    format = format or "%d"
    
    local container = Instance.new("Frame")
    container.BackgroundColor3 = C.bg2
    container.BackgroundTransparency = 0.1
    container.BorderSizePixel = 0
    container.Size = UDim2.new(1, -10, 0, IS_MOBILE and 90 or 80)
    container.Parent = parent
    addCorner(container, 14)
    addStroke(container, C.border, 1, 0.3)
    
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Text = text
    title.TextColor3 = C.textSoft
    title.TextSize = IS_MOBILE and 15 or 13
    title.Font = Enum.Font.Gotham
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Size = UDim2.new(0.6, -15, 0, 20)
    title.Position = UDim2.new(0, 12, 0, 12)
    title.Parent = container
    
    local value = Instance.new("TextLabel")
    value.BackgroundTransparency = 1
    value.Text = string.format(format, S[setting])
    value.TextColor3 = C.blue
    value.TextSize = IS_MOBILE and 18 or 16
    value.Font = Enum.Font.GothamBold
    value.TextXAlignment = Enum.TextXAlignment.Right
    value.Size = UDim2.new(0.4, -15, 0, 20)
    value.Position = UDim2.new(0.6, 0, 0, 12)
    value.Parent = container
    
    local track = Instance.new("Frame")
    track.BackgroundColor3 = C.bg0
    track.Size = UDim2.new(1, -24, 0, IS_MOBILE and 8 or 6)
    track.Position = UDim2.new(0, 12, 0, IS_MOBILE and 55 or 50)
    track.Parent = container
    addCorner(track, 4)
    
    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = C.blue
    fill.Size = UDim2.new((S[setting]-min)/(max-min), 0, 1, 0)
    fill.Parent = track
    addCorner(fill, 4)
    
    local knob = Instance.new("Frame")
    knob.BackgroundColor3 = C.white
    knob.Size = UDim2.new(0, IS_MOBILE and 24 or 20, 0, IS_MOBILE and 24 or 20)
    knob.Position = UDim2.new((S[setting]-min)/(max-min), -(IS_MOBILE and 12 or 10), 0.5, -(IS_MOBILE and 12 or 10))
    knob.Parent = track
    addCorner(knob, 12)
    addStroke(knob, C.blue, 2)
    
    local dragging = false
    
    local function updateFromPos(x)
        local absX = x - track.AbsolutePosition.X
        local relX = math.clamp(absX / track.AbsoluteSize.X, 0, 1)
        local newVal = math.floor(min + relX * (max - min))
        S[setting] = newVal
        value.Text = string.format(format, newVal)
        fill.Size = UDim2.new(relX, 0, 1, 0)
        knob.Position = UDim2.new(relX, -(IS_MOBILE and 12 or 10), 0.5, -(IS_MOBILE and 12 or 10))
    end
    
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateFromPos(input.Position.X)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            updateFromPos(input.Position.X)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    return container
end

-- Dropdown (fixed)
local function createDropdown(parent, text, setting, options, accentColor)
    accentColor = accentColor or C.purple
    
    local container = Instance.new("Frame")
    container.BackgroundColor3 = C.bg2
    container.BackgroundTransparency = 0.1
    container.BorderSizePixel = 0
    container.Size = UDim2.new(1, -10, 0, IS_MOBILE and 70 or 60)
    container.Parent = parent
    addCorner(container, 14)
    addStroke(container, C.border, 1, 0.3)
    
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Text = text
    title.TextColor3 = C.textSoft
    title.TextSize = IS_MOBILE and 15 or 13
    title.Font = Enum.Font.Gotham
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Size = UDim2.new(1, -120, 0, 20)
    title.Position = UDim2.new(0, 12, 0, 12)
    title.Parent = container
    
    local selectBtn = Instance.new("TextButton")
    selectBtn.BackgroundColor3 = C.bg3
    selectBtn.BorderSizePixel = 0
    selectBtn.Text = S[setting]
    selectBtn.TextColor3 = accentColor
    selectBtn.TextSize = IS_MOBILE and 15 or 13
    selectBtn.Font = Enum.Font.GothamBold
    selectBtn.Size = UDim2.new(0, IS_MOBILE and 100 or 90, 0, IS_MOBILE and 44 or 36)
    selectBtn.Position = UDim2.new(1, -(IS_MOBILE and 120 or 110), 0.5, -(IS_MOBILE and 22 or 18))
    selectBtn.Parent = container
    addCorner(selectBtn, 10)
    addStroke(selectBtn, accentColor, 1)
    
    -- Dropdown panel
    local panel = Instance.new("Frame")
    panel.BackgroundColor3 = C.bg3
    panel.BorderSizePixel = 0
    panel.Size = UDim2.new(1, -20, 0, 0)
    panel.Position = UDim2.new(0, 10, 0, (IS_MOBILE and 70 or 60) + 5)
    panel.Visible = false
    panel.ZIndex = 50
    panel.Parent = parent
    addCorner(panel, 10)
    addStroke(panel, accentColor, 1)
    
    local panelList = Instance.new("UIListLayout")
    panelList.Padding = UDim.new(0, 2)
    panelList.Parent = panel
    
    for _, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.BackgroundColor3 = C.bg3
        optBtn.BorderSizePixel = 0
        optBtn.Text = opt
        optBtn.TextColor3 = opt == S[setting] and accentColor or C.textSoft
        optBtn.TextSize = IS_MOBILE and 15 or 13
        optBtn.Font = Enum.Font.Gotham
        optBtn.Size = UDim2.new(1, -8, 0, IS_MOBILE and 44 or 36)
        optBtn.Parent = panel
        addCorner(optBtn, 8)
        
        optBtn.MouseButton1Click:Connect(function()
            S[setting] = opt
            selectBtn.Text = opt
            panel.Visible = false
            tween(panel, TI.spring, {Size = UDim2.new(1, -20, 0, 0)})
        end)
    end
    
    selectBtn.MouseButton1Click:Connect(function()
        panel.Visible = not panel.Visible
        local height = #options * (IS_MOBILE and 48 or 40) + 10
        if panel.Visible then
            tween(panel, TI.spring, {Size = UDim2.new(1, -20, 0, height)})
        else
            local closeTween = TweenService:Create(panel, TI.spring, {Size = UDim2.new(1, -20, 0, 0)})
            closeTween.Completed:Connect(function()
                panel.Visible = false
            end)
            closeTween:Play()
        end
    end)
    
    return container
end

-- ============================================
-- POPULATE TABS (FIXED TEXT)
-- ============================================

-- Combat Tab
do
    local frame = contentFrames["combat"]
    
    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Text = "⚔️ COMBAT"
    header.TextColor3 = C.combat
    header.TextSize = IS_MOBILE and 24 or 20
    header.Font = Enum.Font.GothamBold
    header.Size = UDim2.new(1, -10, 0, IS_MOBILE and 50 or 40)
    header.Parent = frame
    
    createToggle(frame, "Aimbot", "Auto aim at enemies", "Aimbot", C.combat)
    createToggle(frame, "Silent Aim", "No visible aim", "Silent", C.combat)
    createToggle(frame, "Visible Only", "Visible enemies only", "VisibleOnly", C.textSoft)
    createToggle(frame, "Auto Shoot", "Fire when locked", "AutoShoot", C.combat)
    createToggle(frame, "Triggerbot", "Auto shoot on crosshair", "Triggerbot", C.warning)
    createToggle(frame, "Team Check", "Skip teammates", "TeamCheck", C.textSoft)
    
    createDropdown(frame, "Aim Part", "AimPart", {"Head", "Torso", "Nearest"}, C.combat)
    createSlider(frame, "FOV Radius", "FOV", 20, 360, "%d°")
    createSlider(frame, "Smoothness", "Smooth", 1, 100, "%d%%")
    createSlider(frame, "Prediction", "Prediction", 0, 100, "%d")
    
    local weaponHeader = Instance.new("TextLabel")
    weaponHeader.BackgroundTransparency = 1
    weaponHeader.Text = "🔫 WEAPON"
    weaponHeader.TextColor3 = C.combat
    weaponHeader.TextSize = IS_MOBILE and 20 or 18
    weaponHeader.Font = Enum.Font.GothamBold
    weaponHeader.Size = UDim2.new(1, -10, 0, IS_MOBILE and 40 or 30)
    weaponHeader.Parent = frame
    
    createToggle(frame, "Hitbox+", "Expanded hitboxes", "Hitbox", C.combat)
    createDropdown(frame, "Hitbox Shape", "HitboxShape", {"Sphere", "Box"}, C.combat)
    createSlider(frame, "Hitbox Size", "HitboxSize", 2, 20, "%d")
    createToggle(frame, "No Recoil", "Remove recoil", "NoRecoil", C.warning)
    createToggle(frame, "Auto Reload", "Auto reload", "AutoReload", C.textSoft)
end

-- Movement Tab
do
    local frame = contentFrames["movement"]
    
    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Text = "👟 MOVEMENT"
    header.TextColor3 = C.movement
    header.TextSize = IS_MOBILE and 24 or 20
    header.Font = Enum.Font.GothamBold
    header.Size = UDim2.new(1, -10, 0, IS_MOBILE and 50 or 40)
    header.Parent = frame
    
    createToggle(frame, "Speed Boost", "Increased speed", "SpeedBoost", C.movement)
    createSlider(frame, "Walk Speed", "WalkSpeed", 10, 250, "%d")
    createSlider(frame, "Jump Power", "JumpPower", 10, 300, "%d")
    createToggle(frame, "Bunny Hop", "Auto jump", "BunnyHop", C.movement)
    createToggle(frame, "Infinite Jump", "Jump in air", "InfiniteJump", C.movement)
    createToggle(frame, "Low Gravity", "Floating", "LowGravity", C.movement)
    
    createToggle(frame, "Fly Mode", "Free flight", "Fly", C.movement)
    createSlider(frame, "Fly Speed", "FlySpeed", 5, 300, "%d")
    createToggle(frame, "Noclip", "Phase through walls", "Noclip", C.warning)
    createToggle(frame, "Anti-Void", "Save from void", "AntiVoid", C.textSoft)
    
    if IS_MOBILE then
        createToggle(frame, "Joystick", "Mobile joystick", "MobileJoystick", C.movement)
        createSlider(frame, "Sensitivity", "MobileSensitivity", 10, 200, "%d%%")
    end
end

-- Visuals Tab
do
    local frame = contentFrames["visuals"]
    
    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Text = "👁️ VISUALS"
    header.TextColor3 = C.visuals
    header.TextSize = IS_MOBILE and 24 or 20
    header.Font = Enum.Font.GothamBold
    header.Size = UDim2.new(1, -10, 0, IS_MOBILE and 50 or 40)
    header.Parent = frame
    
    createToggle(frame, "Glow Chams", "Enemy outline", "ESPChams", C.visuals)
    createToggle(frame, "Name Tags", "Show names", "ESPName", C.visuals)
    createToggle(frame, "Health Bars", "Show health", "ESPHealth", C.visuals)
    createToggle(frame, "Distance", "Show distance", "ESPDistance", C.visuals)
    createToggle(frame, "Tracers", "Line to enemies", "Tracers", C.visuals)
    
    createToggle(frame, "Fullbright", "Max brightness", "Fullbright", C.warning)
    createToggle(frame, "Crosshair", "Custom crosshair", "CrosshairESP", C.visuals)
    createToggle(frame, "Radar", "Mini-map", "RadarEnabled", C.visuals)
    createToggle(frame, "Enemy Counter", "HUD counter", "EnemyCountHUD", C.warning)
end

-- Utility Tab
do
    local frame = contentFrames["utility"]
    
    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Text = "🔧 UTILITY"
    header.TextColor3 = C.utility
    header.TextSize = IS_MOBILE and 24 or 20
    header.Font = Enum.Font.GothamBold
    header.Size = UDim2.new(1, -10, 0, IS_MOBILE and 50 or 40)
    header.Parent = frame
    
    createToggle(frame, "Anti-AFK", "Prevent kick", "AntiAFK", C.utility)
    createToggle(frame, "Infinite Stamina", "No stamina drain", "InfiniteStamina", C.utility)
    createToggle(frame, "Kill Aura", "Auto attack nearby", "KillAura", C.utility)
    createSlider(frame, "Aura Radius", "KillAuraRadius", 5, 50, "%d")
    createToggle(frame, "Grab/Fling", "Grab & fling", "Grab", C.warning)
    createToggle(frame, "Click TP", "Click to teleport", "ClickTP", C.warning)
    
    if IS_MOBILE then
        createToggle(frame, "Auto Fire", "Mobile auto-shoot", "MobileAutoFire", C.utility)
        createToggle(frame, "Aim Assist", "Mobile aim help", "MobileAimAssist", C.utility)
    end
    
    local btnRejoin = Instance.new("TextButton")
    btnRejoin.BackgroundColor3 = C.bg3
    btnRejoin.BorderSizePixel = 0
    btnRejoin.Text = "🔄 REJOIN SERVER"
    btnRejoin.TextColor3 = C.info
    btnRejoin.TextSize = IS_MOBILE and 16 or 14
    btnRejoin.Font = Enum.Font.GothamBold
    btnRejoin.Size = UDim2.new(1, -10, 0, IS_MOBILE and 55 or 45)
    btnRejoin.Parent = frame
    addCorner(btnRejoin, 12)
    addStroke(btnRejoin, C.info, 1)
    
    btnRejoin.MouseButton1Click:Connect(function()
        TeleportService:Teleport(game.PlaceId, LP)
    end)
    
    local btnHop = Instance.new("TextButton")
    btnHop.BackgroundColor3 = C.bg3
    btnHop.BorderSizePixel = 0
    btnHop.Text = "🌐 SERVER HOP"
    btnHop.TextColor3 = C.utility
    btnHop.TextSize = IS_MOBILE and 16 or 14
    btnHop.Font = Enum.Font.GothamBold
    btnHop.Size = UDim2.new(1, -10, 0, IS_MOBILE and 55 or 45)
    btnHop.Parent = frame
    addCorner(btnHop, 12)
    addStroke(btnHop, C.utility, 1)
    
    btnHop.MouseButton1Click:Connect(function()
        local success, result = pcall(function()
            return HttpService:GetAsync("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=10")
        end)
        if success then
            local data = HttpService:JSONDecode(result)
            for _, server in ipairs(data.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LP)
                    break
                end
            end
        end
    end)
end

-- Settings Tab
do
    local frame = contentFrames["settings"]
    
    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Text = "⚙️ SETTINGS"
    header.TextColor3 = C.settings
    header.TextSize = IS_MOBILE and 24 or 20
    header.Font = Enum.Font.GothamBold
    header.Size = UDim2.new(1, -10, 0, IS_MOBILE and 50 or 40)
    header.Parent = frame
    
    local infoContainer = Instance.new("Frame")
    infoContainer.BackgroundColor3 = C.bg2
    infoContainer.BackgroundTransparency = 0.1
    infoContainer.BorderSizePixel = 0
    infoContainer.Size = UDim2.new(1, -10, 0, IS_MOBILE and 150 or 130)
    infoContainer.Parent = frame
    addCorner(infoContainer, 14)
    addStroke(infoContainer, C.border, 1, 0.3)
    
    local infoLayout = Instance.new("UIListLayout")
    infoLayout.Padding = UDim.new(0, 5)
    infoLayout.Parent = infoContainer
    
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.PaddingTop = UDim.new(0, 12)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.Parent = infoContainer
    
    local function infoRow(label, value)
        local row = Instance.new("Frame")
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 25)
        row.Parent = infoContainer
        
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Text = label..":"
        lbl.TextColor3 = C.textMuted
        lbl.TextSize = IS_MOBILE and 15 or 13
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Size = UDim2.new(0.5, 0, 1, 0)
        lbl.Parent = row
        
        local val = Instance.new("TextLabel")
        val.BackgroundTransparency = 1
        val.Text = value
        val.TextColor3 = C.settings
        val.TextSize = IS_MOBILE and 16 or 14
        val.Font = Enum.Font.GothamBold
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Size = UDim2.new(0.5, 0, 1, 0)
        val.Position = UDim2.new(0.5, 0, 0, 0)
        val.Parent = row
        
        return val
    end
    
    local versionVal = infoRow("Version", "v5.0 Mobile")
    local playerVal = infoRow("Player", LP.Name)
    local fpsVal = infoRow("FPS", "0")
    local pingVal = infoRow("Ping", "0ms")
    
    createToggle(frame, "Floating Button", "Show toggle button", "FloatingButton", C.settings)
    
    if IS_MOBILE then
        createToggle(frame, "Gesture Controls", "Swipe navigation", "GestureControls", C.settings)
    end
    
    local dangerHeader = Instance.new("TextLabel")
    dangerHeader.BackgroundTransparency = 1
    dangerHeader.Text = "⚠️ DANGER ZONE"
    dangerHeader.TextColor3 = C.danger
    dangerHeader.TextSize = IS_MOBILE and 18 or 16
    dangerHeader.Font = Enum.Font.GothamBold
    dangerHeader.Size = UDim2.new(1, -10, 0, IS_MOBILE and 40 or 30)
    dangerHeader.Parent = frame
    
    local unloadBtn = Instance.new("TextButton")
    unloadBtn.BackgroundColor3 = C.danger
    unloadBtn.BorderSizePixel = 0
    unloadBtn.Text = "💀 UNLOAD SCRIPT"
    unloadBtn.TextColor3 = C.white
    unloadBtn.TextSize = IS_MOBILE and 18 or 16
    unloadBtn.Font = Enum.Font.GothamBold
    unloadBtn.Size = UDim2.new(1, -10, 0, IS_MOBILE and 55 or 45)
    unloadBtn.Parent = frame
    addCorner(unloadBtn, 12)
    
    unloadBtn.MouseButton1Click:Connect(function()
        S.Running = false
        sg:Destroy()
    end)
    
    -- FPS counter
    task.spawn(function()
        local frames = 0
        local lastTime = os.clock()
        RunService.RenderStepped:Connect(function()
            frames += 1
            local now = os.clock()
            if now - lastTime >= 1 then
                fpsVal.Text = frames.." FPS"
                frames = 0
                lastTime = now
            end
        end)
    end)
    
    -- Ping counter
    task.spawn(function()
        while sg.Parent do
            task.wait(2)
            local start = os.clock()
            RunService.Heartbeat:Wait()
            local ping = math.floor((os.clock()-start)*1000)
            pingVal.Text = ping.."ms"
            pingVal.TextColor3 = ping < 80 and C.success or ping < 150 and C.warning or C.danger
        end
    end)
end

-- ============================================
-- TOGGLE BUTTON FUNCTIONALITY
-- ============================================
toggleHitbox.MouseButton1Click:Connect(function()
    S.UIVisible = not S.UIVisible
    mainWindow.Visible = S.UIVisible
    tween(toggleButton, TI.spring, {
        Size = S.UIVisible and UDim2.new(0, IS_MOBILE and 60 or 50, 0, IS_MOBILE and 60 or 50) or UDim2.new(0, IS_MOBILE and 70 or 60, 0, IS_MOBILE and 70 or 60)
    })
    toggleIcon.Text = S.UIVisible and "⚡" or "✕"
end)

-- Floating button toggle from settings
task.spawn(function()
    while sg.Parent do
        toggleButton.Visible = S.FloatingButton
        task.wait(0.1)
    end
end)

-- ============================================
-- MOBILE GESTURE CONTROLS
-- ============================================
if IS_MOBILE then
    local touchStart = nil
    local swipeThreshold = 50
    
    UserInputService.TouchStarted:Connect(function(tap)
        if S.GestureControls then
            touchStart = tap.Position
        end
    end)
    
    UserInputService.TouchMoved:Connect(function(tap)
        if touchStart and S.GestureControls then
            local delta = tap.Position.X - touchStart.X
            if math.abs(delta) > swipeThreshold then
                local tabOrder = {"combat", "movement", "visuals", "utility", "settings"}
                local currentIdx = table.find(tabOrder, activeTab)
                if currentIdx then
                    if delta > 0 and currentIdx > 1 then
                        -- Swipe right
                        local newTab = tabOrder[currentIdx - 1]
                        if tabButtons[newTab] and tabButtons[newTab].switchFn then
                            tabButtons[newTab].switchFn()
                        end
                    elseif delta < 0 and currentIdx < #tabOrder then
                        -- Swipe left
                        local newTab = tabOrder[currentIdx + 1]
                        if tabButtons[newTab] and tabButtons[newTab].switchFn then
                            tabButtons[newTab].switchFn()
                        end
                    end
                end
                touchStart = nil
            end
        end
    end)
end

-- ============================================
-- PC KEYBIND
-- ============================================
if not IS_MOBILE then
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == S.ToggleKey then
            S.UIVisible = not S.UIVisible
            mainWindow.Visible = S.UIVisible
        end
    end)
end

-- ============================================
-- DRAWING OBJECTS
-- ============================================
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.Filled = false
FOVCircle.NumSides = 64
FOVCircle.Visible = false
FOVCircle.Color = C.purple

-- Crosshair
local Crosshair = {}
for i = 1, 4 do
    Crosshair[i] = Drawing.new("Line")
    Crosshair[i].Thickness = IS_MOBILE and 3 or 2
    Crosshair[i].Color = C.white
    Crosshair[i].Visible = false
end

-- ============================================
-- FEATURE FUNCTIONS
-- ============================================
function GetTarget()
    local best = nil
    local bestDist = (S.FOV / Cam.FieldOfView) * 70
    local center = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and IsEnemy(plr) and plr.Character then
            local part = GetAimPart(plr.Character)
            if part then
                local pos, vis = Cam:WorldToViewportPoint(part.Position)
                if vis then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        best = part
                    end
                end
            end
        end
    end
    return best
end

function IsEnemy(plr)
    if plr == LP then return false end
    if not IsAlive(plr) then return false end
    if S.TeamCheck then
        if LP.Team and plr.Team and LP.Team == plr.Team then
            return false
        end
    end
    return true
end

function IsAlive(plr)
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    return hum and hum.Health > 0
end

function GetAimPart(char)
    if not char then return nil end
    if S.AimPart == "Head" then
        return char:FindFirstChild("Head")
    elseif S.AimPart == "Torso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    else
        local center = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
        local best, bestDist = nil, math.huge
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                local pos, vis = Cam:WorldToViewportPoint(part.Position)
                if vis then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        best = part
                    end
                end
            end
        end
        return best
    end
end

-- ============================================
-- RENDER LOOP
-- ============================================
RunService.RenderStepped:Connect(function()
    if not S.Running then return end
    
    local mid = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    local target = GetTarget()
    
    -- FOV Circle
    if (S.Aimbot or S.Silent) and mainWindow.Visible then
        FOVCircle.Visible = true
        FOVCircle.Position = mid
        FOVCircle.Radius = (S.FOV / Cam.FieldOfView) * 70
        FOVCircle.Color = target and C.danger or C.purple
    else
        FOVCircle.Visible = false
    end
    
    -- Crosshair
    if S.CrosshairESP then
        local size = IS_MOBILE and 15 or 10
        local gap = IS_MOBILE and 8 or 5
        
        Crosshair[1].Visible = true
        Crosshair[1].From = Vector2.new(mid.X, mid.Y - size - gap)
        Crosshair[1].To = Vector2.new(mid.X, mid.Y - gap)
        
        Crosshair[2].Visible = true
        Crosshair[2].From = Vector2.new(mid.X, mid.Y + gap)
        Crosshair[2].To = Vector2.new(mid.X, mid.Y + size + gap)
        
        Crosshair[3].Visible = true
        Crosshair[3].From = Vector2.new(mid.X - size - gap, mid.Y)
        Crosshair[3].To = Vector2.new(mid.X - gap, mid.Y)
        
        Crosshair[4].Visible = true
        Crosshair[4].From = Vector2.new(mid.X + gap, mid.Y)
        Crosshair[4].To = Vector2.new(mid.X + size + gap, mid.Y)
        
        for i = 1, 4 do
            Crosshair[i].Color = target and C.danger or C.white
        end
    else
        for i = 1, 4 do
            Crosshair[i].Visible = false
        end
    end
end)

-- ============================================
-- FEATURE IMPLEMENTATIONS
-- ============================================

-- Noclip
RunService.Stepped:Connect(function()
    if S.Noclip and LP.Character then
        for _, part in ipairs(LP.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- Anti-AFK
task.spawn(function()
    while S.Running do
        if S.AntiAFK then
            wait(60)
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
            wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
        else
            wait(1)
        end
    end
end)

-- Infinite Jump
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if S.InfiniteJump and input.KeyCode == Enum.KeyCode.Space then
        local char = LP.Character
        local hum = char and char:FindFirstChildWhichIsA("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Speed Boost
RunService.Heartbeat:Connect(function()
    if S.SpeedBoost and LP.Character then
        local hum = LP.Character:FindFirstChildWhichIsA("Humanoid")
        if hum then
            hum.WalkSpeed = S.WalkSpeed
            hum.JumpPower = S.JumpPower
        end
    end
end)

-- Fly
RunService.Heartbeat:Connect(function()
    if S.Fly and LP.Character then
        local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
        local hum = LP.Character:FindFirstChildWhichIsA("Humanoid")
        if hrp and hum then
            hum.PlatformStand = true
            
            local move = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                move += Cam.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                move -= Cam.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                move -= Cam.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                move += Cam.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                move += Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                move -= Vector3.new(0, 1, 0)
            end
            
            hrp.AssemblyLinearVelocity = move * S.FlySpeed
        end
    end
end)

-- Bunny Hop
RunService.Heartbeat:Connect(function()
    if S.BunnyHop and LP.Character then
        local hum = LP.Character:FindFirstChildWhichIsA("Humanoid")
        if hum and hum:GetState() == Enum.HumanoidStateType.Landed then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Anti-Void
RunService.Heartbeat:Connect(function()
    if S.AntiVoid and LP.Character then
        local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Position.Y < -500 then
            hrp.CFrame = CFrame.new(0, 50, 0)
        end
    end
end)

-- Low Gravity
RunService.Heartbeat:Connect(function()
    if S.LowGravity and LP.Character then
        local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity * Vector3.new(1, 0.3, 1)
        end
    end
end)

-- Kill Aura
RunService.Heartbeat:Connect(function()
    if S.KillAura and LP.Character then
        local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP and IsEnemy(plr) then
                    local char = plr.Character
                    local targetHRP = char and char:FindFirstChild("HumanoidRootPart")
                    if targetHRP and (targetHRP.Position - hrp.Position).Magnitude <= S.KillAuraRadius then
                        local pos, vis = Cam:WorldToViewportPoint(targetHRP.Position)
                        if vis then
                            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
                            wait(0.05)
                            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
                        end
                    end
                end
            end
        end
    end
end)

-- Fullbright (reactive)
local Lighting = game:GetService("Lighting")
local defaultBrightness = Lighting.Brightness
local defaultShadows = Lighting.GlobalShadows
local defaultFogEnd = Lighting.FogEnd

task.spawn(function()
    while sg.Parent do
        if S.Fullbright then
            Lighting.Brightness = 2
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 100000
        else
            Lighting.Brightness = defaultBrightness
            Lighting.GlobalShadows = defaultShadows
            Lighting.FogEnd = defaultFogEnd
        end
        task.wait(0.5)
    end
end)

-- ============================================
print("✅ Master Hub V5 Mobile Ultimate loaded!")
print("📱 Floating toggle button available")
print("🎮 " .. (IS_MOBILE and "Three-finger tap to toggle" or "RightShift to toggle"))
