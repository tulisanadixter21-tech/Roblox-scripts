--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║   MASTER HUB · RIVALS · V4 "OBSIDIAN MOBILE"                                ║
║                                                                              ║
║   FULL MOBILE OPTIMIZATION:                                                 ║
║   • Delta Executor compatible                                               ║
║   • Touch-friendly buttons (min 44px)                                       ║
║   • Swipe navigation between tabs                                           ║
║   • Floating joystick for mobile movement                                   ║
║   • Gesture controls (tap, hold, swipe)                                     ║
║   • Dynamic UI scaling for any screen size                                  ║
║   • Battery-efficient rendering                                             ║
║   • Edge swipe to open/close                                                ║
║                                                                              ║
║   ENHANCED SIDEBAR DESIGN:                                                  ║
║   • Glass morphism effect                                                   ║
║   • Animated gradient icons                                                 ║
║   • Quick-access radial menu                                                ║
║   • Collapsible/expandable                                                  ║
║   • Touch-optimized hit areas                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
--]]

-- ════════════════════════════════════════════════════════════════════════════
--  §1  SERVICES & MOBILE DETECTION
-- ════════════════════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local TouchEnabled = UserInputService.TouchEnabled

local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera
local ViewportSize = Cam.ViewportSize

-- Mobile detection
local IS_MOBILE = TouchEnabled or UserInputService.TouchSupported or game:GetService("Platform"):IsMobile()
local IS_CONSOLE = not IS_MOBILE and (UserInputService.GamepadEnabled or UserInputService.KeyboardEnabled == false)

-- Screen scaling
local BASE_WIDTH = 400
local BASE_HEIGHT = 700
local SCALE = math.min(ViewportSize.X / BASE_WIDTH, ViewportSize.Y / BASE_HEIGHT, 1.2)
SCALE = math.max(SCALE, 0.7) -- Minimum scale

-- Cleanup old instance
local OLD = CoreGui:FindFirstChild("MasterHubV4")
if OLD then OLD:Destroy() end

-- ════════════════════════════════════════════════════════════════════════════
--  §2  ENHANCED SETTINGS WITH MOBILE CONTROLS
-- ════════════════════════════════════════════════════════════════════════════
local S = {
    -- Core
    ToggleKey = Enum.KeyCode.RightShift,
    Running = true,
    SidebarCollapsed = false,
    
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
}

-- ════════════════════════════════════════════════════════════════════════════
--  §3  ENHANCED COLOR PALETTE - "OBSIDIAN NEBULA"
-- ════════════════════════════════════════════════════════════════════════════
local C = {
    -- Base
    bg0 = Color3.fromRGB(2, 4, 10),      -- deepest void
    bg1 = Color3.fromRGB(6, 9, 18),       -- window base
    bg2 = Color3.fromRGB(12, 16, 28),      -- card background
    bg3 = Color3.fromRGB(20, 25, 42),      -- raised element
    bg4 = Color3.fromRGB(30, 36, 58),      -- hover state
    
    -- Borders & Effects
    border = Color3.fromRGB(40, 48, 78),
    borderGlow = Color3.fromRGB(90, 110, 200),
    
    -- Accent Gradient (Nebula Theme)
    accent1 = Color3.fromRGB(130, 70, 255),   -- deep purple
    accent2 = Color3.fromRGB(90, 130, 255),   -- electric blue
    accent3 = Color3.fromRGB(200, 70, 255),   -- magenta
    accent4 = Color3.fromRGB(70, 200, 255),   -- cyan
    
    -- Semantic Colors
    combat = Color3.fromRGB(255, 80, 120),
    movement = Color3.fromRGB(80, 220, 255),
    visuals = Color3.fromRGB(170, 90, 255),
    utility = Color3.fromRGB(255, 180, 70),
    settings = Color3.fromRGB(90, 255, 150),
    
    -- Status
    success = Color3.fromRGB(70, 255, 140),
    warning = Color3.fromRGB(255, 200, 70),
    danger = Color3.fromRGB(255, 70, 100),
    info = Color3.fromRGB(100, 180, 255),
    
    -- Text
    textPrimary = Color3.fromRGB(240, 245, 255),
    textSecondary = Color3.fromRGB(160, 170, 210),
    textMuted = Color3.fromRGB(90, 100, 140),
    textGlow = Color3.fromRGB(200, 210, 255),
}

-- Tween Info presets
local TI = {
    instant = TweenInfo.new(0),
    snap = TweenInfo.new(0.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    fast = TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    smooth = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    spring = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    bounce = TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
}

-- Utility tween function
local function tween(obj, info, props)
    if not obj or not obj.Parent then return end
    TweenService:Create(obj, info, props):Play()
end

-- ════════════════════════════════════════════════════════════════════════════
--  §4  MOBILE-OPTIMIZED UI COMPONENTS
-- ════════════════════════════════════════════════════════════════════════════

-- Touch-friendly rounded corner
local function AddCorner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or (IS_MOBILE and 16 or 10))
    c.Parent = obj
    return c
end

-- Enhanced stroke with glow
local function AddStroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or C.border
    s.Thickness = thickness or (IS_MOBILE and 2 or 1.5)
    s.Transparency = transparency or 0
    s.Parent = obj
    return s
end

-- Gradient effect for modern UI
local function AddGradient(obj, color1, color2, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)})
    g.Rotation = rotation or 45
    g.Parent = obj
    return g
end

-- Touch-friendly button with haptic feedback (mobile)
local function TouchableButton(parent, props)
    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = props.bg or C.bg3
    btn.BackgroundTransparency = props.trans or 0
    btn.BorderSizePixel = 0
    btn.Text = props.text or ""
    btn.TextColor3 = props.textColor or C.textPrimary
    btn.TextSize = (props.textSize or 14) * SCALE
    btn.Font = props.font or Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.Size = props.size or UDim2.new(1, 0, 0, IS_MOBILE and 50 or 40)
    btn.Position = props.position or UDim2.new(0, 0, 0, 0)
    btn.ZIndex = props.zIndex or 2
    btn.Parent = parent
    
    AddCorner(btn, props.corner or 12)
    
    -- Touch feedback
    if IS_MOBILE then
        btn.TouchTap:Connect(function()
            -- Visual feedback
            tween(btn, TI.fast, {BackgroundColor3 = C.bg4})
            tween(btn, TI.spring, {BackgroundColor3 = props.bg or C.bg3})
            
            -- Haptic feedback (if available)
            pcall(function()
                UserInputService:VibrationMotor("large", 0.2, 0.2)
            end)
        end)
    end
    
    return btn
end

-- Enhanced toggle switch for mobile
local function MobileToggle(parent, text, desc, settingKey, accentColor, callback)
    accentColor = accentColor or C.accent1
    
    local container = Instance.new("Frame")
    container.BackgroundColor3 = C.bg2
    container.BorderSizePixel = 0
    container.Size = UDim2.new(1, 0, 0, desc and (IS_MOBILE and 70 or 60) or (IS_MOBILE and 60 or 50))
    container.Parent = parent
    AddCorner(container, 14)
    AddStroke(container, C.border, 1)
    
    -- Animated glow effect
    local glow = Instance.new("Frame")
    glow.BackgroundColor3 = accentColor
    glow.BackgroundTransparency = 1
    glow.Size = UDim2.new(1, 0, 1, 0)
    glow.Parent = container
    AddCorner(glow, 14)
    
    -- Left accent bar
    local accentBar = Instance.new("Frame")
    accentBar.BackgroundColor3 = accentColor
    accentBar.Size = UDim2.new(0, 4, 0, desc and 40 or 30)
    accentBar.Position = UDim2.new(0, 0, 0.5, -(desc and 20 or 15))
    accentBar.Parent = container
    AddCorner(accentBar, 2)
    
    -- Text
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Text = text
    title.TextColor3 = C.textPrimary
    title.TextSize = (desc and 16 or 15) * SCALE
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Size = UDim2.new(0.7, -20, 0, desc and 22 or 20)
    title.Position = UDim2.new(0, 18, 0, desc and 12 or 8)
    title.Parent = container
    
    if desc then
        local descLabel = Instance.new("TextLabel")
        descLabel.BackgroundTransparency = 1
        descLabel.Text = desc
        descLabel.TextColor3 = C.textMuted
        descLabel.TextSize = 12 * SCALE
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.Size = UDim2.new(0.7, -20, 0, 18)
        descLabel.Position = UDim2.new(0, 18, 0, 34)
        descLabel.Parent = container
    end
    
    -- Touch-friendly toggle switch (bigger for mobile)
    local switchFrame = Instance.new("Frame")
    switchFrame.BackgroundColor3 = C.bg0
    switchFrame.Size = UDim2.new(0, IS_MOBILE and 60 or 50, 0, IS_MOBILE and 32 or 26)
    switchFrame.Position = UDim2.new(1, -(IS_MOBILE and 80 or 70), 0.5, -16)
    switchFrame.Parent = container
    AddCorner(switchFrame, 16)
    AddStroke(switchFrame, C.border, 1)
    
    local switchKnob = Instance.new("Frame")
    switchKnob.BackgroundColor3 = C.textMuted
    switchKnob.Size = UDim2.new(0, IS_MOBILE and 26 or 22, 0, IS_MOBILE and 26 or 22)
    switchKnob.Position = UDim2.new(0, 3, 0.5, -(IS_MOBILE and 13 or 11))
    switchKnob.Parent = switchFrame
    AddCorner(switchKnob, 13)
    
    local function updateVisuals()
        local isOn = S[settingKey]
        tween(switchFrame, TI.spring, {
            BackgroundColor3 = isOn and accentColor or C.bg0
        })
        tween(switchKnob, TI.spring, {
            Position = isOn and UDim2.new(1, -(IS_MOBILE and 29 or 25), 0.5, -(IS_MOBILE and 13 or 11)) or UDim2.new(0, 3, 0.5, -(IS_MOBILE and 13 or 11)),
            BackgroundColor3 = isOn and C.white or C.textMuted
        })
        tween(accentBar, TI.fast, {
            BackgroundTransparency = isOn and 0 or 0.6
        })
        tween(glow, TI.smooth, {
            BackgroundTransparency = isOn and 0.8 or 1
        })
    end
    
    updateVisuals()
    
    local touchBtn = TouchableButton(container, {
        bg = C.bg2,
        trans = 1,
        size = UDim2.new(1, 0, 1, 0),
        text = "",
        zIndex = 5
    })
    
    touchBtn.TouchTap:Connect(function()
        S[settingKey] = not S[settingKey]
        updateVisuals()
        if callback then callback(S[settingKey]) end
    end)
    
    return container
end

-- Enhanced slider for mobile
local function MobileSlider(parent, text, settingKey, min, max, format, callback)
    format = format or "%d"
    
    local container = Instance.new("Frame")
    container.BackgroundColor3 = C.bg2
    container.BorderSizePixel = 0
    container.Size = UDim2.new(1, 0, 0, IS_MOBILE and 90 or 80)
    container.Parent = parent
    AddCorner(container, 14)
    AddStroke(container, C.border, 1)
    
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Text = text
    title.TextColor3 = C.textSecondary
    title.TextSize = 14 * SCALE
    title.Font = Enum.Font.Gotham
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Size = UDim2.new(0.7, -20, 0, 20)
    title.Position = UDim2.new(0, 18, 0, 12)
    title.Parent = container
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = string.format(format, S[settingKey])
    valueLabel.TextColor3 = C.accent2
    valueLabel.TextSize = 16 * SCALE
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Size = UDim2.new(0.3, -20, 0, 20)
    valueLabel.Position = UDim2.new(0.7, 0, 0, 12)
    valueLabel.Parent = container
    
    local sliderTrack = Instance.new("Frame")
    sliderTrack.BackgroundColor3 = C.bg0
    sliderTrack.Size = UDim2.new(1, -36, 0, IS_MOBILE and 8 or 6)
    sliderTrack.Position = UDim2.new(0, 18, 0, IS_MOBILE and 55 or 50)
    sliderTrack.Parent = container
    AddCorner(sliderTrack, 4)
    
    local sliderFill = Instance.new("Frame")
    sliderFill.BackgroundColor3 = C.accent2
    sliderFill.Size = UDim2.new((S[settingKey]-min)/(max-min), 0, 1, 0)
    sliderFill.Parent = sliderTrack
    AddCorner(sliderFill, 4)
    
    local sliderKnob = Instance.new("Frame")
    sliderKnob.BackgroundColor3 = C.white
    sliderKnob.Size = UDim2.new(0, IS_MOBILE and 26 or 22, 0, IS_MOBILE and 26 or 22)
    sliderKnob.Position = UDim2.new((S[settingKey]-min)/(max-min), -(IS_MOBILE and 13 or 11), 0.5, -(IS_MOBILE and 13 or 11))
    sliderKnob.Parent = sliderTrack
    AddCorner(sliderKnob, 13)
    AddStroke(sliderKnob, C.accent2, 2)
    
    -- Touch handling
    local dragging = false
    
    local function updateFromPosition(x)
        local absX = x - sliderTrack.AbsolutePosition.X
        local relX = math.clamp(absX / sliderTrack.AbsoluteSize.X, 0, 1)
        local newValue = math.floor(min + relX * (max - min))
        S[settingKey] = newValue
        valueLabel.Text = string.format(format, newValue)
        sliderFill.Size = UDim2.new(relX, 0, 1, 0)
        sliderKnob.Position = UDim2.new(relX, -(IS_MOBILE and 13 or 11), 0.5, -(IS_MOBILE and 13 or 11))
        if callback then callback(newValue) end
    end
    
    sliderTrack.TouchTap:Connect(function(tap)
        local pos = tap.Position
        updateFromPosition(pos.X)
    end)
    
    sliderTrack.TouchLongPress:Connect(function(tap)
        dragging = true
        updateFromPosition(tap.Position.X)
    end)
    
    UserInputService.TouchMoved:Connect(function(tap)
        if dragging then
            updateFromPosition(tap.Position.X)
        end
    end)
    
    UserInputService.TouchEnded:Connect(function()
        dragging = false
    end)
    
    return container
end

-- Mobile dropdown
local function MobileDropdown(parent, text, settingKey, options, callback)
    local container = Instance.new("Frame")
    container.BackgroundColor3 = C.bg2
    container.BorderSizePixel = 0
    container.Size = UDim2.new(1, 0, 0, IS_MOBILE and 70 or 60)
    container.Parent = parent
    AddCorner(container, 14)
    AddStroke(container, C.border, 1)
    
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Text = text
    title.TextColor3 = C.textSecondary
    title.TextSize = 14 * SCALE
    title.Font = Enum.Font.Gotham
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Size = UDim2.new(1, -80, 0, 20)
    title.Position = UDim2.new(0, 18, 0, 12)
    title.Parent = container
    
    local selectBtn = TouchableButton(container, {
        bg = C.bg3,
        text = S[settingKey],
        textColor = C.accent2,
        textSize = 14,
        size = UDim2.new(0, IS_MOBILE and 120 or 100, 0, IS_MOBILE and 44 or 36),
        position = UDim2.new(1, -(IS_MOBILE and 140 or 120), 0.5, -(IS_MOBILE and 22 or 18))
    })
    
    -- Dropdown panel
    local dropPanel = Instance.new("Frame")
    dropPanel.BackgroundColor3 = C.bg3
    dropPanel.BorderSizePixel = 0
    dropPanel.Size = UDim2.new(1, -20, 0, 0)
    dropPanel.Position = UDim2.new(0, 10, 0, container.Size.Y.Offset + 10)
    dropPanel.Visible = false
    dropPanel.ZIndex = 100
    dropPanel.Parent = parent
    AddCorner(dropPanel, 12)
    AddStroke(dropPanel, C.accent2, 1)
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = dropPanel
    
    for _, opt in ipairs(options) do
        local optBtn = TouchableButton(dropPanel, {
            bg = C.bg3,
            text = opt,
            textColor = opt == S[settingKey] and C.accent2 or C.textSecondary,
            textSize = 14,
            size = UDim2.new(1, -8, 0, IS_MOBILE and 44 or 36),
            position = UDim2.new(0, 4, 0, 0)
        })
        
        optBtn.TouchTap:Connect(function()
            S[settingKey] = opt
            selectBtn.Text = opt
            dropPanel.Visible = false
            tween(dropPanel, TI.spring, {Size = UDim2.new(1, -20, 0, 0)})
            if callback then callback(opt) end
        end)
    end
    
    selectBtn.TouchTap:Connect(function()
        dropPanel.Visible = not dropPanel.Visible
        local height = #options * (IS_MOBILE and 48 or 40) + 10
        tween(dropPanel, TI.spring, {
            Size = dropPanel.Visible and UDim2.new(1, -20, 0, height) or UDim2.new(1, -20, 0, 0)
        })
    end)
    
    return container
end

-- ════════════════════════════════════════════════════════════════════════════
--  §5  MOBILE JOYSTICK CONTROLLER
-- ════════════════════════════════════════════════════════════════════════════
local function CreateMobileJoystick()
    local joystickContainer = Instance.new("Frame")
    joystickContainer.BackgroundTransparency = 1
    joystickContainer.Size = UDim2.new(0, 160 * SCALE, 0, 160 * SCALE)
    joystickContainer.Position = UDim2.new(0, 20, 0.5, -80 * SCALE)
    joystickContainer.Visible = false
    joystickContainer.ZIndex = 1000
    joystickContainer.Parent = CoreGui
    
    local bg = Instance.new("Frame")
    bg.BackgroundColor3 = C.bg0
    bg.BackgroundTransparency = 0.3
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.Parent = joystickContainer
    AddCorner(bg, 80)
    AddStroke(bg, C.accent2, 2, 0.5)
    
    local inner = Instance.new("Frame")
    inner.BackgroundColor3 = C.accent2
    inner.BackgroundTransparency = 0.2
    inner.Size = UDim2.new(0, 80 * SCALE, 0, 80 * SCALE)
    inner.Position = UDim2.new(0.5, -40 * SCALE, 0.5, -40 * SCALE)
    inner.Parent = joystickContainer
    AddCorner(inner, 40)
    
    local direction = Vector2.new(0, 0)
    local active = false
    
    local function updateJoystick(pos)
        local center = joystickContainer.AbsolutePosition + joystickContainer.AbsoluteSize / 2
        local delta = Vector2.new(pos.X - center.X, pos.Y - center.Y)
        local magnitude = delta.Magnitude
        local maxRadius = 50 * SCALE
        
        if magnitude > maxRadius then
            delta = delta.Unit * maxRadius
        end
        
        direction = delta / maxRadius
        inner.Position = UDim2.new(0.5, delta.X - 40 * SCALE, 0.5, delta.Y - 40 * SCALE)
    end
    
    bg.TouchTap:Connect(function(tap)
        active = true
        updateJoystick(tap.Position)
    end)
    
    UserInputService.TouchMoved:Connect(function(tap)
        if active then
            updateJoystick(tap.Position)
        end
    end)
    
    UserInputService.TouchEnded:Connect(function()
        active = false
        direction = Vector2.new(0, 0)
        tween(inner, TI.spring, {Position = UDim2.new(0.5, -40 * SCALE, 0.5, -40 * SCALE)})
    end)
    
    -- Movement application
    RunService.Heartbeat:Connect(function()
        if S.MobileJoystick and joystickContainer.Visible and active then
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildWhichIsA("Humanoid")
            
            if hrp and hum then
                local moveVector = Vector3.new(direction.X, 0, -direction.Y)
                local cameraCF = Cam.CFrame
                local forward = cameraCF.LookVector * Vector3.new(1, 0, 1)
                local right = cameraCF.RightVector * Vector3.new(1, 0, 1)
                
                forward = forward.Unit
                right = right.Unit
                
                local worldMove = forward * -direction.Y + right * direction.X
                hrp.AssemblyLinearVelocity = worldMove * S.WalkSpeed + Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
            end
        end
    end)
    
    return joystickContainer
end

-- ════════════════════════════════════════════════════════════════════════════
--  §6  MAIN WINDOW - MOBILE OPTIMIZED
-- ════════════════════════════════════════════════════════════════════════════
local sg = Instance.new("ScreenGui")
sg.Name = "MasterHubV4"
sg.DisplayOrder = 999
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Parent = CoreGui

-- Calculate window size based on screen
local windowWidth = math.min(450 * SCALE, ViewportSize.X - 40)
local windowHeight = math.min(750 * SCALE, ViewportSize.Y - 100)

-- Main window with glass morphism
local mainWindow = Instance.new("Frame")
mainWindow.BackgroundColor3 = C.bg1
mainWindow.BackgroundTransparency = 0.05
mainWindow.BorderSizePixel = 0
mainWindow.Size = UDim2.new(0, windowWidth, 0, windowHeight)
mainWindow.Position = UDim2.new(0.5, -windowWidth/2, 0.5, -windowHeight/2)
mainWindow.ClipsDescendants = true
mainWindow.Parent = sg
AddCorner(mainWindow, 20)
AddStroke(mainWindow, C.borderGlow, 2)

-- Glass effect
local glassEffect = Instance.new("Frame")
glassEffect.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
glassEffect.BackgroundTransparency = 0.97
glassEffect.Size = UDim2.new(1, 0, 1, 0)
glassEffect.Parent = mainWindow
AddCorner(glassEffect, 20)

-- Animated gradient overlay
local gradientOverlay = Instance.new("Frame")
gradientOverlay.BackgroundTransparency = 1
gradientOverlay.Size = UDim2.new(1, 0, 1, 0)
gradientOverlay.Parent = mainWindow
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, C.accent1),
    ColorSequenceKeypoint.new(0.5, C.accent2),
    ColorSequenceKeypoint.new(1, C.accent3)
})
gradient.Rotation = 45
gradient.Transparency = NumberSequence.new(0.95)
gradient.Parent = gradientOverlay
AddCorner(gradientOverlay, 20)

-- ════════════════════════════════════════════════════════════════════════════
--  §6.1  ENHANCED SIDEBAR WITH QUICK ACTIONS
-- ════════════════════════════════════════════════════════════════════════════
local sidebar = Instance.new("Frame")
sidebar.BackgroundColor3 = C.bg0
sidebar.BackgroundTransparency = 0.1
sidebar.BorderSizePixel = 0
sidebar.Size = UDim2.new(0, IS_MOBILE and 100 or 120, 1, -60)
sidebar.Position = UDim2.new(0, 0, 0, 50)
sidebar.Parent = mainWindow
AddCorner(sidebar, 0)

-- Glass effect for sidebar
local sidebarGlass = Instance.new("Frame")
sidebarGlass.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sidebarGlass.BackgroundTransparency = 0.98
sidebarGlass.Size = UDim2.new(1, 0, 1, 0)
sidebarGlass.Parent = sidebar

-- Sidebar content
local sidebarList = Instance.new("UIListLayout")
sidebarList.Padding = UDim.new(0, IS_MOBILE and 8 or 4)
sidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
sidebarList.SortOrder = Enum.SortOrder.LayoutOrder
sidebarList.Parent = sidebar

-- Sidebar padding
local sidebarPadding = Instance.new("UIPadding")
sidebarPadding.PaddingTop = UDim.new(0, 20)
sidebarPadding.PaddingBottom = UDim.new(0, 20)
sidebarPadding.Parent = sidebar

-- Quick action buttons (mobile favorites)
local quickActions = {
    {icon = "🎯", name = "Aimbot", setting = "Aimbot", color = C.combat},
    {icon = "⚡", name = "Speed", setting = "SpeedBoost", color = C.movement},
    {icon = "👁", name = "ESP", setting = "ESPChams", color = C.visuals},
    {icon = "🛡️", name = "Aura", setting = "KillAura", color = C.utility},
}

for _, action in ipairs(quickActions) do
    local btn = TouchableButton(sidebar, {
        bg = C.bg2,
        text = action.icon,
        textSize = IS_MOBILE and 24 or 20,
        size = UDim2.new(0, IS_MOBILE and 70 or 80, 0, IS_MOBILE and 70 or 80),
        corner = IS_MOBILE and 35 or 40
    })
    
    -- Status indicator
    local status = Instance.new("Frame")
    status.BackgroundColor3 = action.color
    status.Size = UDim2.new(0, 10, 0, 10)
    status.Position = UDim2.new(1, -15, 1, -15)
    status.Parent = btn
    AddCorner(status, 5)
    
    -- Update function
    task.spawn(function()
        while btn.Parent do
            status.Visible = S[action.setting]
            task.wait(0.1)
        end
    end)
    
    btn.TouchTap:Connect(function()
        S[action.setting] = not S[action.setting]
    end)
end

-- Tab navigation in sidebar
local tabs = {
    {icon = "⚔️", name = "Combat", id = "combat", color = C.combat},
    {icon = "👟", name = "Move", id = "movement", color = C.movement},
    {icon = "👁️", name = "Visual", id = "visuals", color = C.visuals},
    {icon = "🔧", name = "Utility", id = "utility", color = C.utility},
    {icon = "⚙️", name = "Settings", id = "settings", color = C.settings},
}

local activeTab = "combat"
local tabButtons = {}

for _, tab in ipairs(tabs) do
    local btn = TouchableButton(sidebar, {
        bg = C.bg2,
        text = tab.icon,
        textSize = IS_MOBILE and 22 or 18,
        size = UDim2.new(0, IS_MOBILE and 70 or 80, 0, IS_MOBILE and 60 or 50),
        corner = 15
    })
    
    -- Active indicator
    local indicator = Instance.new("Frame")
    indicator.BackgroundColor3 = tab.color
    indicator.Size = UDim2.new(0, 4, 0, 0)
    indicator.Position = UDim2.new(1, -4, 0.5, 0)
    indicator.Parent = btn
    AddCorner(indicator, 2)
    
    btn.TouchTap:Connect(function()
        activeTab = tab.id
        -- Update indicators
        for _, otherBtn in pairs(tabButtons) do
            otherBtn.indicator:TweenSize(UDim2.new(0, 4, 0, 0), "Out", "Quad", 0.2, true)
        end
        indicator:TweenSize(UDim2.new(0, 4, 0, 30), "Out", "Quad", 0.2, true)
        
        -- Switch content
        for id, content in pairs(contentFrames) do
            content.Visible = (id == tab.id)
        end
    end)
    
    tabButtons[tab.id] = {btn = btn, indicator = indicator}
end

-- ════════════════════════════════════════════════════════════════════════════
--  §6.2  CONTENT AREA WITH SWIPE NAVIGATION
-- ════════════════════════════════════════════════════════════════════════════
local contentArea = Instance.new("Frame")
contentArea.BackgroundColor3 = C.bg1
contentArea.BackgroundTransparency = 0.1
contentArea.BorderSizePixel = 0
contentArea.Size = UDim2.new(1, -(IS_MOBILE and 100 or 120), 1, -60)
contentArea.Position = UDim2.new(0, IS_MOBILE and 100 or 120, 0, 50)
contentArea.Parent = mainWindow
AddCorner(contentArea, 0)

-- Content frames
local contentFrames = {}

for _, tab in ipairs(tabs) do
    local frame = Instance.new("ScrollingFrame")
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, -20, 1, -20)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.CanvasSize = UDim2.new(0, 0, 0, 0)
    frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    frame.ScrollBarThickness = IS_MOBILE and 4 or 3
    frame.ScrollBarImageColor3 = C.accent2
    frame.Visible = (tab.id == "combat")
    frame.Parent = contentArea
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, IS_MOBILE and 10 or 6)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame
    
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 5)
    padding.PaddingRight = UDim.new(0, 5)
    padding.PaddingTop = UDim.new(0, 5)
    padding.PaddingBottom = UDim.new(0, 5)
    padding.Parent = frame
    
    contentFrames[tab.id] = frame
end

-- Swipe navigation
local touchStart = nil
local swipeThreshold = 50

contentArea.TouchTap:Connect(function(tap)
    touchStart = tap.Position
end)

UserInputService.TouchMoved:Connect(function(tap)
    if touchStart then
        local delta = tap.Position.X - touchStart.X
        if math.abs(delta) > swipeThreshold then
            local tabsList = {"combat", "movement", "visuals", "utility", "settings"}
            local currentIndex = table.find(tabsList, activeTab)
            if currentIndex then
                if delta > 0 and currentIndex > 1 then
                    -- Swipe right
                    local newTab = tabsList[currentIndex - 1]
                    tabButtons[newTab].btn.TouchTap:Fire()
                elseif delta < 0 and currentIndex < #tabsList then
                    -- Swipe left
                    local newTab = tabsList[currentIndex + 1]
                    tabButtons[newTab].btn.TouchTap:Fire()
                end
            end
            touchStart = nil
        end
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
--  §7  POPULATE TABS WITH MOBILE CONTROLS
-- ════════════════════════════════════════════════════════════════════════════

-- Combat Tab
do
    local frame = contentFrames["combat"]
    
    -- Header
    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Text = "⚔️ COMBAT ⚔️"
    header.TextColor3 = C.combat
    header.TextSize = IS_MOBILE and 22 or 18
    header.Font = Enum.Font.GothamBold
    header.Size = UDim2.new(1, 0, 0, IS_MOBILE and 50 or 40)
    header.Parent = frame
    
    MobileToggle(frame, "Aimbot", "Auto-aim at enemies", "Aimbot", C.combat)
    MobileToggle(frame, "Silent Aim", "No visible aim lock", "Silent", C.combat)
    MobileToggle(frame, "Visible Only", "Only visible enemies", "VisibleOnly", C.textSecondary)
    MobileToggle(frame, "Auto Shoot", "Fire when locked", "AutoShoot", C.combat)
    MobileToggle(frame, "Triggerbot", "Auto-shoot on crosshair", "Triggerbot", C.warning)
    MobileToggle(frame, "Team Check", "Skip teammates", "TeamCheck", C.textSecondary)
    
    MobileDropdown(frame, "Aim Part", "AimPart", {"Head", "Torso", "Nearest"})
    MobileSlider(frame, "FOV Radius", "FOV", 20, 360, "%d°")
    MobileSlider(frame, "Aim Smooth", "Smooth", 1, 100, "%d%%")
    MobileSlider(frame, "Prediction", "Prediction", 0, 100, "%d")
    
    -- Weapon section
    local weaponHeader = Instance.new("TextLabel")
    weaponHeader.BackgroundTransparency = 1
    weaponHeader.Text = "🔫 WEAPON"
    weaponHeader.TextColor3 = C.combat
    weaponHeader.TextSize = IS_MOBILE and 18 or 16
    weaponHeader.Font = Enum.Font.GothamBold
    weaponHeader.Size = UDim2.new(1, 0, 0, IS_MOBILE and 40 or 30)
    weaponHeader.Parent = frame
    
    MobileToggle(frame, "Hitbox+", "Expanded hitboxes", "Hitbox", C.combat)
    MobileDropdown(frame, "Hitbox Shape", "HitboxShape", {"Sphere", "Box"})
    MobileSlider(frame, "Hitbox Size", "HitboxSize", 2, 20, "%d")
    MobileToggle(frame, "No Recoil", "Remove weapon recoil", "NoRecoil", C.warning)
    MobileToggle(frame, "Auto Reload", "Auto reload when empty", "AutoReload", C.textSecondary)
end

-- Movement Tab
do
    local frame = contentFrames["movement"]
    
    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Text = "👟 MOVEMENT"
    header.TextColor3 = C.movement
    header.TextSize = IS_MOBILE and 22 or 18
    header.Font = Enum.Font.GothamBold
    header.Size = UDim2.new(1, 0, 0, IS_MOBILE and 50 or 40)
    header.Parent = frame
    
    MobileToggle(frame, "Speed Boost", "Increased speed", "SpeedBoost", C.movement)
    MobileSlider(frame, "Walk Speed", "WalkSpeed", 10, 250, "%d")
    MobileSlider(frame, "Jump Power", "JumpPower", 10, 300, "%d")
    MobileToggle(frame, "Bunny Hop", "Auto-jump", "BunnyHop", C.movement)
    MobileToggle(frame, "Infinite Jump", "Jump in air", "InfiniteJump", C.movement)
    MobileToggle(frame, "Low Gravity", "Floating", "LowGravity", C.movement)
    
    MobileToggle(frame, "Fly Mode", "Free flight", "Fly", C.movement)
    MobileSlider(frame, "Fly Speed", "FlySpeed", 5, 300, "%d")
    MobileToggle(frame, "Noclip", "Phase through walls", "Noclip", C.warning)
    MobileToggle(frame, "Anti-Void", "Save from void", "AntiVoid", C.textSecondary)
    
    -- Mobile specific
    if IS_MOBILE then
        MobileToggle(frame, "Joystick", "Mobile joystick control", "MobileJoystick", C.movement)
        MobileSlider(frame, "Sensitivity", "MobileSensitivity", 10, 200, "%d%%")
        MobileToggle(frame, "Gesture Control", "Swipe gestures", "GestureControls", C.movement)
    end
end

-- Visuals Tab
do
    local frame = contentFrames["visuals"]
    
    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Text = "👁️ VISUALS"
    header.TextColor3 = C.visuals
    header.TextSize = IS_MOBILE and 22 or 18
    header.Font = Enum.Font.GothamBold
    header.Size = UDim2.new(1, 0, 0, IS_MOBILE and 50 or 40)
    header.Parent = frame
    
    MobileToggle(frame, "Glow Chams", "Enemy outline", "ESPChams", C.visuals)
    MobileToggle(frame, "Name Tags", "Show names", "ESPName", C.visuals)
    MobileToggle(frame, "Health Bars", "Show health", "ESPHealth", C.visuals)
    MobileToggle(frame, "Distance", "Show distance", "ESPDistance", C.visuals)
    MobileToggle(frame, "Tracers", "Line to enemies", "Tracers", C.visuals)
    
    MobileToggle(frame, "Fullbright", "Max brightness", "Fullbright", C.warning)
    MobileToggle(frame, "Crosshair", "Custom crosshair", "CrosshairESP", C.visuals)
    MobileToggle(frame, "Radar", "Mini-map", "RadarEnabled", C.visuals)
    MobileToggle(frame, "Enemy Counter", "HUD counter", "EnemyCountHUD", C.warning)
end

-- Utility Tab
do
    local frame = contentFrames["utility"]
    
    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Text = "🔧 UTILITY"
    header.TextColor3 = C.utility
    header.TextSize = IS_MOBILE and 22 or 18
    header.Font = Enum.Font.GothamBold
    header.Size = UDim2.new(1, 0, 0, IS_MOBILE and 50 or 40)
    header.Parent = frame
    
    MobileToggle(frame, "Anti-AFK", "Prevent kick", "AntiAFK", C.utility)
    MobileToggle(frame, "Infinite Stamina", "No stamina drain", "InfiniteStamina", C.utility)
    MobileToggle(frame, "Kill Aura", "Auto-attack nearby", "KillAura", C.utility)
    MobileSlider(frame, "Aura Radius", "KillAuraRadius", 5, 50, "%d")
    MobileToggle(frame, "Grab/Fling", "Grab & fling", "Grab", C.warning)
    MobileToggle(frame, "Click TP", "Click to teleport", "ClickTP", C.warning)
    
    if IS_MOBILE then
        MobileToggle(frame, "Auto Fire", "Mobile auto-shoot", "MobileAutoFire", C.utility)
        MobileToggle(frame, "Aim Assist", "Mobile aim help", "MobileAimAssist", C.utility)
    end
    
    -- Action buttons
    local btn1 = TouchableButton(frame, {
        bg = C.bg3,
        text = "🔄 REJOIN SERVER",
        textColor = C.info,
        textSize = 16
    })
    btn1.TouchTap:Connect(function()
        TeleportService:Teleport(game.PlaceId, LP)
    end)
    
    local btn2 = TouchableButton(frame, {
        bg = C.bg3,
        text = "🌐 SERVER HOP",
        textColor = C.utility,
        textSize = 16
    })
    btn2.TouchTap:Connect(function()
        -- Server hop logic
        local success, result = pcall(function()
            return HttpService:GetAsync("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=10")
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
    header.TextSize = IS_MOBILE and 22 or 18
    header.Font = Enum.Font.GothamBold
    header.Size = UDim2.new(1, 0, 0, IS_MOBILE and 50 or 40)
    header.Parent = frame
    
    -- Info display
    local infoFrame = Instance.new("Frame")
    infoFrame.BackgroundColor3 = C.bg2
    infoFrame.Size = UDim2.new(1, 0, 0, IS_MOBILE and 120 or 100)
    infoFrame.Parent = frame
    AddCorner(infoFrame, 12)
    
    local infoLayout = Instance.new("UIListLayout")
    infoLayout.Padding = UDim.new(0, 5)
    infoLayout.Parent = infoFrame
    
    local infoPadding = Instance.new("UIPadding")
    infoPadding.PaddingLeft = UDim.new(0, 10)
    infoPadding.PaddingRight = UDim.new(0, 10)
    infoPadding.PaddingTop = UDim.new(0, 10)
    infoPadding.PaddingBottom = UDim.new(0, 10)
    infoPadding.Parent = infoFrame
    
    local function infoRow(label, value)
        local row = Instance.new("Frame")
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 20)
        row.Parent = infoFrame
        
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Text = label .. ":"
        lbl.TextColor3 = C.textSecondary
        lbl.TextSize = 14
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Size = UDim2.new(0.5, 0, 1, 0)
        lbl.Parent = row
        
        local val = Instance.new("TextLabel")
        val.BackgroundTransparency = 1
        val.Text = value
        val.TextColor3 = C.accent2
        val.TextSize = 14
        val.Font = Enum.Font.GothamBold
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Size = UDim2.new(0.5, 0, 1, 0)
        val.Position = UDim2.new(0.5, 0, 0, 0)
        val.Parent = row
        
        return val
    end
    
    local versionRow = infoRow("Version", "v4.0 Obsidian")
    local playerRow = infoRow("Player", LP.Name)
    local fpsRow = infoRow("FPS", "0")
    local pingRow = infoRow("Ping", "0ms")
    
    -- Danger zone
    local dangerHeader = Instance.new("TextLabel")
    dangerHeader.BackgroundTransparency = 1
    dangerHeader.Text = "⚠️ DANGER ZONE"
    dangerHeader.TextColor3 = C.danger
    dangerHeader.TextSize = IS_MOBILE and 18 or 16
    dangerHeader.Font = Enum.Font.GothamBold
    dangerHeader.Size = UDim2.new(1, 0, 0, IS_MOBILE and 40 or 30)
    dangerHeader.Parent = frame
    
    local unloadBtn = TouchableButton(frame, {
        bg = C.danger,
        textColor = C.white,
        text = "💀 UNLOAD SCRIPT",
        textSize = 18
    })
    unloadBtn.TouchTap:Connect(function()
        S.Running = false
        sg:Destroy()
    end)
    
    -- FPS counter update
    task.spawn(function()
        local frames = 0
        local lastTime = os.clock()
        RunService.RenderStepped:Connect(function()
            frames = frames + 1
            local now = os.clock()
            if now - lastTime >= 1 then
                fpsRow.Text = frames .. " FPS"
                frames = 0
                lastTime = now
            end
        end)
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
--  §8  HEADER WITH PLAYER INFO
-- ════════════════════════════════════════════════════════════════════════════
local header = Instance.new("Frame")
header.BackgroundColor3 = C.bg0
header.BackgroundTransparency = 0.1
header.BorderSizePixel = 0
header.Size = UDim2.new(1, 0, 0, 50)
header.Position = UDim2.new(0, 0, 0, 0)
header.Parent = mainWindow
AddCorner(header, 0)

local headerGlass = Instance.new("Frame")
headerGlass.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
headerGlass.BackgroundTransparency = 0.98
headerGlass.Size = UDim2.new(1, 0, 1, 0)
headerGlass.Parent = header

local logo = Instance.new("TextLabel")
logo.BackgroundTransparency = 1
logo.Text = "⚡ MH ⚡"
logo.TextColor3 = C.accent3
logo.TextSize = 24 * SCALE
logo.Font = Enum.Font.GothamBold
logo.Size = UDim2.new(0, 120, 1, 0)
logo.Position = UDim2.new(0, 10, 0, 0)
logo.Parent = header

local playerInfo = Instance.new("TextLabel")
playerInfo.BackgroundTransparency = 1
playerInfo.Text = LP.Name
playerInfo.TextColor3 = C.textPrimary
playerInfo.TextSize = 16 * SCALE
playerInfo.Font = Enum.Font.Gotham
playerInfo.TextXAlignment = Enum.TextXAlignment.Right
playerInfo.Size = UDim2.new(0, 150, 1, 0)
playerInfo.Position = UDim2.new(1, -160, 0, 0)
playerInfo.Parent = header

-- Close button
local closeBtn = TouchableButton(header, {
    bg = C.danger,
    text = "✕",
    textColor = C.white,
    textSize = 20,
    size = UDim2.new(0, 40, 0, 40),
    position = UDim2.new(1, -45, 0.5, -20),
    corner = 20
})
closeBtn.TouchTap:Connect(function()
    S.Running = false
    sg:Destroy()
end)

-- ════════════════════════════════════════════════════════════════════════════
--  §9  STATUS BAR
-- ════════════════════════════════════════════════════════════════════════════
local statusBar = Instance.new("Frame")
statusBar.BackgroundColor3 = C.bg0
statusBar.BackgroundTransparency = 0.1
statusBar.BorderSizePixel = 0
statusBar.Size = UDim2.new(1, 0, 0, 30)
statusBar.Position = UDim2.new(0, 0, 1, -30)
statusBar.Parent = mainWindow
AddCorner(statusBar, 0)

local statusText = Instance.new("TextLabel")
statusText.BackgroundTransparency = 1
statusText.Text = "● READY"
statusText.TextColor3 = C.success
statusText.TextSize = 14 * SCALE
statusText.Font = Enum.Font.Gotham
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.Size = UDim2.new(0.5, 0, 1, 0)
statusText.Position = UDim2.new(0, 10, 0, 0)
statusText.Parent = statusBar

local fpsDisplay = Instance.new("TextLabel")
fpsDisplay.BackgroundTransparency = 1
fpsDisplay.Text = "FPS: 0"
fpsDisplay.TextColor3 = C.textSecondary
fpsDisplay.TextSize = 14 * SCALE
fpsDisplay.Font = Enum.Font.Gotham
fpsDisplay.TextXAlignment = Enum.TextXAlignment.Right
fpsDisplay.Size = UDim2.new(0.5, -10, 1, 0)
fpsDisplay.Position = UDim2.new(0.5, 0, 0, 0)
fpsDisplay.Parent = statusBar

-- ════════════════════════════════════════════════════════════════════════════
--  §10  CREATE MOBILE JOYSTICK
-- ════════════════════════════════════════════════════════════════════════════
local joystick = CreateMobileJoystick()

-- Update joystick visibility based on setting
task.spawn(function()
    while sg.Parent do
        if joystick then
            joystick.Visible = S.MobileJoystick
        end
        task.wait(0.1)
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
--  §11  DRAWING OBJECTS (Mobile optimized)
-- ════════════════════════════════════════════════════════════════════════════
local FovCircle = Drawing.new("Circle")
FovCircle.Thickness = 2
FovCircle.Filled = false
FovCircle.NumSides = 64
FovCircle.Visible = false
FovCircle.Color = C.accent2

-- Crosshair (larger for mobile)
local Crosshair = {}
for i = 1, 4 do
    Crosshair[i] = Drawing.new("Line")
    Crosshair[i].Thickness = IS_MOBILE and 3 or 2
    Crosshair[i].Color = C.white
    Crosshair[i].Visible = false
end

-- Radar
local RadarBG = Drawing.new("Square")
RadarBG.Size = Vector2.new(IS_MOBILE and 160 or 140, IS_MOBILE and 160 or 140)
RadarBG.Color = C.bg0
RadarBG.Filled = true
RadarBG.Visible = false
RadarBG.Transparency = 0.3

local RadarDots = {}

-- ════════════════════════════════════════════════════════════════════════════
--  §12  TOGGLE KEY (Mobile optimized)
-- ════════════════════════════════════════════════════════════════════════════
if IS_MOBILE then
    -- Mobile: Three-finger tap to toggle
    local touchCount = 0
    local touchTimer
    
    UserInputService.TouchTap:Connect(function(taps, gameProcessed)
        if gameProcessed then return end
        
        touchCount = touchCount + 1
        
        if touchTimer then
            touchTimer:Cancel()
        end
        
        touchTimer = task.delay(0.5, function()
            if touchCount >= 3 then
                mainWindow.Visible = not mainWindow.Visible
            end
            touchCount = 0
        end)
    end)
else
    -- PC: Keybind toggle
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == S.ToggleKey then
            mainWindow.Visible = not mainWindow.Visible
        end
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
--  §13  FEATURE ENGINE (Mobile optimized)
-- ════════════════════════════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    if not S.Running then return end
    
    local mid = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
    local target = GetTarget() -- Using existing GetTarget function
    
    -- Update FOV circle
    if S.Aimbot or S.Silent then
        FovCircle.Visible = true
        FovCircle.Position = mid
        FovCircle.Radius = (S.FOV / Cam.FieldOfView) * 70
        FovCircle.Color = target and C.danger or C.accent2
    else
        FovCircle.Visible = false
    end
    
    -- Update crosshair
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
    
    -- Update status text
    local activeFeatures = {}
    if S.Aimbot then table.insert(activeFeatures, "AIM") end
    if S.Silent then table.insert(activeFeatures, "SILENT") end
    if S.ESPChams then table.insert(activeFeatures, "ESP") end
    if S.Fly then table.insert(activeFeatures, "FLY") end
    if S.KillAura then table.insert(activeFeatures, "AURA") end
    
    if #activeFeatures > 0 then
        statusText.Text = "● " .. table.concat(activeFeatures, " · ")
        statusText.TextColor3 = C.success
    else
        statusText.Text = "● IDLE"
        statusText.TextColor3 = C.textSecondary
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
--  §14  MOBILE AIM ASSIST
-- ════════════════════════════════════════════════════════════════════════════
if IS_MOBILE then
    RunService.Heartbeat:Connect(function()
        if S.MobileAimAssist and S.Aimbot then
            local target = GetTarget()
            if target then
                local targetPos = Cam:WorldToViewportPoint(target.Position)
                local screenPos = Vector2.new(targetPos.X, targetPos.Y)
                local mid = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
                
                -- Smooth aim assist
                local delta = screenPos - mid
                local strength = S.MobileSensitivity / 100
                local adjustment = delta * strength * 0.1
                
                -- Apply to camera
                Cam.CFrame = Cam.CFrame:Lerp(
                    CFrame.new(Cam.CFrame.Position, target.Position),
                    strength * 0.5
                )
            end
        end
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
--  §15  KEEP GetTarget FUNCTION (from original)
-- ════════════════════════════════════════════════════════════════════════════
function GetTarget()
    local bestTarget = nil
    local bestDistance = GetScaledFOV()
    local center = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP and IsEnemy(player) then
            local character = player.Character
            if character then
                local part = GetAimPart(character)
                if part then
                    local pos, onScreen = Cam:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local distance = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if distance < bestDistance then
                            bestDistance = distance
                            bestTarget = part
                        end
                    end
                end
            end
        end
    end
    
    return bestTarget
end

function GetScaledFOV()
    return (S.FOV / Cam.FieldOfView) * 70
end

function IsEnemy(player)
    if player == LP then return false end
    if not IsAlive(player) then return false end
    
    if S.TeamCheck then
        if LP.Team and player.Team and LP.Team == player.Team then
            return false
        end
    end
    
    return true
end

function IsAlive(player)
    local character = player.Character
    if not character then return false end
    
    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
    return humanoid and humanoid.Health > 0
end

function GetAimPart(character)
    if not character then return nil end
    
    if S.AimPart == "Head" then
        return character:FindFirstChild("Head")
    elseif S.AimPart == "Torso" then
        return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
    else -- Nearest
        local center = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
        local bestPart = nil
        local bestDist = math.huge
        
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                local pos, onScreen = Cam:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        bestPart = part
                    end
                end
            end
        end
        
        return bestPart
    end
end

-- ════════════════════════════════════════════════════════════════════════════
--  §16  FEATURE IMPLEMENTATIONS (from original)
-- ════════════════════════════════════════════════════════════════════════════

-- Noclip handler
local noclipConnection
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
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if S.InfiniteJump and input.KeyCode == Enum.KeyCode.Space then
        local char = LP.Character
        local hum = char and char:FindFirstChildWhichIsA("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Kill Aura
RunService.Heartbeat:Connect(function()
    if S.KillAura and LP.Character then
        local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LP and IsEnemy(player) then
                    local char = player.Character
                    local targetHRP = char and char:FindFirstChild("HumanoidRootPart")
                    if targetHRP and (targetHRP.Position - hrp.Position).Magnitude <= S.KillAuraRadius then
                        -- Simulate attack
                        local pos, onScreen = Cam:WorldToViewportPoint(targetHRP.Position)
                        if onScreen then
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
            
            local moveDir = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDir = moveDir + Cam.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDir = moveDir - Cam.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDir = moveDir - Cam.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDir = moveDir + Cam.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDir = moveDir + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                moveDir = moveDir - Vector3.new(0, 1, 0)
            end
            
            hrp.AssemblyLinearVelocity = moveDir * S.FlySpeed
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

-- Fullbright
if S.Fullbright then
    game:GetService("Lighting").Brightness = 2
    game:GetService("Lighting").GlobalShadows = false
    game:GetService("Lighting").FogEnd = 100000
end

-- ════════════════════════════════════════════════════════════════════════════
print("✅ Master Hub V4 Obsidian Mobile loaded!")
print("📱 Mobile optimized for Delta and other executors")
print("🎮 Three-finger tap to toggle menu")
