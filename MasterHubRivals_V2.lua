-- MASTER HUB · RIVALS · FINAL
task.wait(2)

-- ============================================================
-- SERVICES
-- ============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")

local LP  = Players.LocalPlayer
local Cam = workspace.CurrentCamera

-- ============================================================
-- SETTINGS
-- ============================================================
local S = {
    UIVisible   = true,
    ToggleKey   = Enum.KeyCode.RightShift,
    AimKey      = Enum.KeyCode.LeftShift,
    Aimbot      = false,
    AimPart     = "Head",
    FOV         = 120,
    Smooth      = 60,
    Prediction  = 0,
    VisibleOnly = false,
    TeamCheck   = true,
    ESPBox      = false,
    ESPName     = false,
    ESPHealth   = false,
    Tracers     = false,
    ESPChams    = false,
    NoRecoil    = false,
    Hitbox      = false,
    HitboxSize  = 6,
    Crosshair   = false,
}

-- ============================================================
-- COLORS  (from old script - proven working)
-- ============================================================
local C = {
    bg0         = Color3.fromRGB(5,   8,  15),
    bg1         = Color3.fromRGB(10,  14, 24),
    bg2         = Color3.fromRGB(18,  23, 38),
    bg3         = Color3.fromRGB(28,  34, 54),
    bg4         = Color3.fromRGB(38,  46, 70),
    border      = Color3.fromRGB(60,  70, 120),
    borderGlow  = Color3.fromRGB(130, 100, 255),
    purple      = Color3.fromRGB(160, 100, 255),
    blue        = Color3.fromRGB(100, 150, 255),
    pink        = Color3.fromRGB(255, 100, 200),
    cyan        = Color3.fromRGB(80,  220, 255),
    combat      = Color3.fromRGB(255, 100, 130),
    visuals     = Color3.fromRGB(200, 120, 255),
    settings    = Color3.fromRGB(120, 255, 160),
    success     = Color3.fromRGB(80,  255, 150),
    warning     = Color3.fromRGB(255, 220, 80),
    danger      = Color3.fromRGB(255, 80,  120),
    info        = Color3.fromRGB(120, 200, 255),
    textBright  = Color3.fromRGB(255, 255, 255),
    textMain    = Color3.fromRGB(230, 235, 255),
    textSoft    = Color3.fromRGB(180, 190, 230),
    textMuted   = Color3.fromRGB(120, 130, 180),
    white       = Color3.fromRGB(255, 255, 255),
}

-- ============================================================
-- TWEEN PRESETS  (from old script)
-- ============================================================
local TI = {
    fast   = TweenInfo.new(0.15, Enum.EasingStyle.Quart,  Enum.EasingDirection.Out),
    smooth = TweenInfo.new(0.25, Enum.EasingStyle.Quint,  Enum.EasingDirection.Out),
    spring = TweenInfo.new(0.4,  Enum.EasingStyle.Back,   Enum.EasingDirection.Out),
}

local function tween(obj, info, props)
    if not obj or not obj.Parent then return end
    TweenService:Create(obj, info, props):Play()
end

local function addCorner(obj, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = obj
    return c
end

local function addStroke(obj, col, thick, trans)
    local s = Instance.new("UIStroke")
    s.Color        = col   or C.border
    s.Thickness    = thick or 1.5
    s.Transparency = trans or 0
    s.Parent       = obj
    return s
end

-- ============================================================
-- SCREENGUI  (from old script - proven working)
-- ============================================================
pcall(function() CoreGui:FindFirstChild("MasterHubFinal"):Destroy() end)
pcall(function() LP:WaitForChild("PlayerGui"):FindFirstChild("MasterHubFinal"):Destroy() end)

local sg = Instance.new("ScreenGui")
sg.Name           = "MasterHubFinal"
sg.DisplayOrder   = 999
sg.ResetOnSpawn   = false
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local guiOK = false
pcall(function() sg.Parent = CoreGui; guiOK = true end)
if not guiOK then sg.Parent = LP:WaitForChild("PlayerGui") end

-- ============================================================
-- FLOATING TOGGLE BUTTON  (from old script)
-- ============================================================
local toggleBtn = Instance.new("Frame")
toggleBtn.BackgroundColor3      = C.purple
toggleBtn.BackgroundTransparency= 0.1
toggleBtn.BorderSizePixel       = 0
toggleBtn.Size                  = UDim2.new(0, 50, 0, 50)
toggleBtn.Position              = UDim2.new(1, -70, 1, -90)
toggleBtn.ZIndex                = 1000
toggleBtn.Parent                = sg
addCorner(toggleBtn, 30)
addStroke(toggleBtn, C.borderGlow, 3)

local toggleIcon = Instance.new("TextLabel")
toggleIcon.BackgroundTransparency = 1
toggleIcon.Text      = "⚡"
toggleIcon.TextColor3= C.white
toggleIcon.TextSize  = 28
toggleIcon.Font      = Enum.Font.GothamBold
toggleIcon.Size      = UDim2.new(1, 0, 1, 0)
toggleIcon.Parent    = toggleBtn

local toggleHit = Instance.new("TextButton")
toggleHit.BackgroundTransparency = 1
toggleHit.Size   = UDim2.new(1, 0, 1, 0)
toggleHit.Text   = ""
toggleHit.ZIndex = 1001
toggleHit.Parent = toggleBtn

-- pulse
local pulse = Instance.new("Frame")
pulse.BackgroundColor3      = C.purple
pulse.BackgroundTransparency= 0.5
pulse.Size                  = UDim2.new(1, 0, 1, 0)
pulse.ZIndex                = 999
pulse.Parent                = toggleBtn
addCorner(pulse, 30)

task.spawn(function()
    while sg.Parent do
        tween(pulse, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            Size = UDim2.new(1.3,0,1.3,0), Position = UDim2.new(-0.15,0,-0.15,0), BackgroundTransparency = 1
        })
        task.wait(1.5)
        tween(pulse, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1,0,1,0), Position = UDim2.new(0,0,0,0), BackgroundTransparency = 0.5
        })
        task.wait(0.1)
    end
end)

-- ============================================================
-- MAIN WINDOW  (from old script layout)
-- ============================================================
local WIN_W = math.min(460, Cam.ViewportSize.X - 30)
local WIN_H = math.min(580, Cam.ViewportSize.Y - 80)

local win = Instance.new("Frame")
win.Name                   = "MainWindow"
win.BackgroundColor3       = C.bg1
win.BackgroundTransparency = 0.02
win.BorderSizePixel        = 0
win.Size                   = UDim2.new(0, WIN_W, 0, WIN_H)
win.Position               = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
win.Visible                = true
win.ZIndex                 = 10
win.Parent                 = sg
addCorner(win, 20)
addStroke(win, C.borderGlow, 2)

-- glass + gradient overlays
local glass = Instance.new("Frame")
glass.BackgroundColor3      = Color3.fromRGB(255,255,255)
glass.BackgroundTransparency= 0.98
glass.Size                  = UDim2.new(1,0,1,0)
glass.Parent                = win
addCorner(glass, 20)

-- ── HEADER ──────────────────────────────────────────────────
local header = Instance.new("Frame")
header.BackgroundColor3      = C.bg0
header.BackgroundTransparency= 0.1
header.BorderSizePixel       = 0
header.Size                  = UDim2.new(1, 0, 0, 55)
header.Parent                = win
addCorner(header, 0)

local hContent = Instance.new("Frame")
hContent.BackgroundTransparency = 1
hContent.Size     = UDim2.new(1, -20, 1, 0)
hContent.Position = UDim2.new(0, 10, 0, 0)
hContent.Parent   = header

local titleLbl = Instance.new("TextLabel")
titleLbl.BackgroundTransparency = 1
titleLbl.Text      = "⚡ MASTER HUB"
titleLbl.TextColor3= C.textBright
titleLbl.TextSize  = 20
titleLbl.Font      = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Size      = UDim2.new(0.6, 0, 1, 0)
titleLbl.Parent    = hContent

local subLbl = Instance.new("TextLabel")
subLbl.BackgroundTransparency = 1
subLbl.Text       = "RIVALS"
subLbl.TextColor3 = C.purple
subLbl.TextSize   = 13
subLbl.Font       = Enum.Font.GothamBold
subLbl.TextXAlignment = Enum.TextXAlignment.Right
subLbl.Size       = UDim2.new(0.4, 0, 1, 0)
subLbl.Parent     = hContent

-- drag window
do
    local drag, ds, sp = false, nil, nil
    header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; ds = i.Position; sp = win.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - ds
            win.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)
end

-- ── SIDEBAR  (from old script) ──────────────────────────────
local sidebar = Instance.new("Frame")
sidebar.BackgroundColor3      = C.bg0
sidebar.BackgroundTransparency= 0.1
sidebar.BorderSizePixel       = 0
sidebar.Size                  = UDim2.new(0, 100, 1, -55)
sidebar.Position              = UDim2.new(0, 0, 0, 55)
sidebar.Parent                = win
addCorner(sidebar, 0)

local sideScroll = Instance.new("ScrollingFrame")
sideScroll.BackgroundTransparency = 1
sideScroll.BorderSizePixel        = 0
sideScroll.Size                   = UDim2.new(1, 0, 1, -10)
sideScroll.Position               = UDim2.new(0, 0, 0, 10)
sideScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
sideScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
sideScroll.ScrollBarThickness     = 2
sideScroll.ScrollBarImageColor3   = C.purple
sideScroll.Parent                 = sidebar

local sideList = Instance.new("UIListLayout")
sideList.Padding             = UDim.new(0, 6)
sideList.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideList.SortOrder           = Enum.SortOrder.LayoutOrder
sideList.Parent              = sideScroll

-- ── CONTENT AREA ────────────────────────────────────────────
local contentArea = Instance.new("Frame")
contentArea.BackgroundColor3      = C.bg1
contentArea.BackgroundTransparency= 0.1
contentArea.BorderSizePixel       = 0
contentArea.Size                  = UDim2.new(1, -100, 1, -55)
contentArea.Position              = UDim2.new(0, 100, 0, 55)
contentArea.Parent                = win
addCorner(contentArea, 0)

-- ============================================================
-- TABS
-- ============================================================
local TABS = {
    {icon="⚔️", name="COMBAT",  id="combat",  color=C.combat},
    {icon="👁️", name="VISUAL",  id="visuals", color=C.visuals},
    {icon="⚙️", name="MISC",    id="misc",    color=C.settings},
}

local tabButtons  = {}
local contentFrames = {}
local activeTab   = "combat"

-- create scrolling content frames
for _, t in ipairs(TABS) do
    local frame = Instance.new("ScrollingFrame")
    frame.Name                = t.id
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel     = 0
    frame.Size                = UDim2.new(1, -16, 1, -10)
    frame.Position            = UDim2.new(0, 8, 0, 5)
    frame.CanvasSize          = UDim2.new(0, 0, 0, 0)
    frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    frame.ScrollBarThickness  = 3
    frame.ScrollBarImageColor3= t.color
    frame.Visible             = (t.id == "combat")
    frame.Parent              = contentArea
    local layout = Instance.new("UIListLayout")
    layout.Padding             = UDim.new(0, 8)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder           = Enum.SortOrder.LayoutOrder
    layout.Parent              = frame
    contentFrames[t.id] = frame
end

-- create sidebar tab buttons
for _, t in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Name                   = "Tab_"..t.id
    btn.BackgroundColor3       = C.bg2
    btn.BackgroundTransparency = t.id == "combat" and 0.2 or 0
    btn.BorderSizePixel        = 0
    btn.Text                   = t.icon
    btn.TextColor3             = t.id == "combat" and t.color or C.textSoft
    btn.TextSize               = 24
    btn.Font                   = Enum.Font.GothamBold
    btn.Size                   = UDim2.new(0, 70, 0, 66)
    btn.Parent                 = sideScroll
    addCorner(btn, 28)
    addStroke(btn, t.color, 1, t.id == "combat" and 0.1 or 0.5)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text       = t.name
    nameLbl.TextColor3 = C.textSoft
    nameLbl.TextSize   = 10
    nameLbl.Font       = Enum.Font.Gotham
    nameLbl.Size       = UDim2.new(1, 0, 0, 14)
    nameLbl.Position   = UDim2.new(0, 0, 1, -14)
    nameLbl.Parent     = btn

    local indicator = Instance.new("Frame")
    indicator.BackgroundColor3 = t.color
    indicator.Size             = UDim2.new(0, 4, 0, t.id == "combat" and 30 or 0)
    indicator.Position         = UDim2.new(1, -4, 0.5, -15)
    indicator.Parent           = btn
    addCorner(indicator, 2)

    tabButtons[t.id] = {btn=btn, indicator=indicator, color=t.color}

    local function switchFn()
        activeTab = t.id
        for id, data in pairs(tabButtons) do
            local active = (id == t.id)
            data.btn.BackgroundTransparency = active and 0.2 or 0
            data.btn.TextColor3             = active and data.color or C.textSoft
            tween(data.indicator, TI.spring, {Size = UDim2.new(0, 4, 0, active and 30 or 0)})
        end
        for id, frame in pairs(contentFrames) do
            frame.Visible = (id == t.id)
        end
    end

    tabButtons[t.id].switchFn = switchFn
    btn.MouseButton1Click:Connect(switchFn)
end

-- ============================================================
-- UI COMPONENTS  (from old script - proven working)
-- ============================================================

local function sectionHeader(parent, text, color)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text       = text
    lbl.TextColor3 = color or C.purple
    lbl.TextSize   = 13
    lbl.Font       = Enum.Font.GothamBold
    lbl.Size       = UDim2.new(1, -10, 0, 28)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent     = parent
end

local function createToggle(parent, text, desc, setting, color)
    color = color or C.purple
    local row = Instance.new("Frame")
    row.BackgroundColor3      = C.bg2
    row.BackgroundTransparency= 0.1
    row.BorderSizePixel       = 0
    row.Size                  = UDim2.new(1, -10, 0, desc and 65 or 54)
    row.Parent                = parent
    addCorner(row, 14)
    addStroke(row, C.border, 1, 0.3)

    local accent = Instance.new("Frame")
    accent.BackgroundColor3      = color
    accent.BackgroundTransparency= S[setting] and 0 or 0.6
    accent.Size                  = UDim2.new(0, 4, 0, desc and 38 or 30)
    accent.Position              = UDim2.new(0, 0, 0.5, desc and -19 or -15)
    accent.BorderSizePixel       = 0
    accent.Parent                = row
    addCorner(accent, 2)

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text       = text
    lbl.TextColor3 = C.textBright
    lbl.TextSize   = 14
    lbl.Font       = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Size       = UDim2.new(0.72, -18, 0, 20)
    lbl.Position   = UDim2.new(0, 12, 0, desc and 8 or 17)
    lbl.Parent     = row

    if desc then
        local dlbl = Instance.new("TextLabel")
        dlbl.BackgroundTransparency = 1
        dlbl.Text       = desc
        dlbl.TextColor3 = C.textMuted
        dlbl.TextSize   = 11
        dlbl.Font       = Enum.Font.Gotham
        dlbl.TextXAlignment = Enum.TextXAlignment.Left
        dlbl.Size       = UDim2.new(0.72, -18, 0, 16)
        dlbl.Position   = UDim2.new(0, 12, 0, 30)
        dlbl.Parent     = row
    end

    local track = Instance.new("Frame")
    track.BackgroundColor3 = S[setting] and color or C.bg0
    track.Size             = UDim2.new(0, 48, 0, 26)
    track.Position         = UDim2.new(1, -70, 0.5, -13)
    track.BorderSizePixel  = 0
    track.Parent           = row
    addCorner(track, 13)

    local knob = Instance.new("Frame")
    knob.BackgroundColor3 = S[setting] and C.white or C.textMuted
    knob.Size             = UDim2.new(0, 22, 0, 22)
    knob.Position         = S[setting] and UDim2.new(1,-24,0.5,-11) or UDim2.new(0,2,0.5,-11)
    knob.BorderSizePixel  = 0
    knob.Parent           = track
    addCorner(knob, 11)

    local function refresh()
        local on = S[setting]
        tween(track, TI.spring, {BackgroundColor3 = on and color or C.bg0})
        tween(knob,  TI.spring, {
            Position         = on and UDim2.new(1,-24,0.5,-11) or UDim2.new(0,2,0.5,-11),
            BackgroundColor3 = on and C.white or C.textMuted,
        })
        accent.BackgroundTransparency = on and 0 or 0.6
    end

    local hit = Instance.new("TextButton")
    hit.BackgroundTransparency = 1
    hit.Size   = UDim2.new(1, 0, 1, 0)
    hit.Text   = ""
    hit.Parent = row
    hit.MouseButton1Click:Connect(function()
        S[setting] = not S[setting]
        refresh()
    end)

    return row
end

local function createSlider(parent, text, setting, min, max, fmt)
    fmt = fmt or "%d"
    local row = Instance.new("Frame")
    row.BackgroundColor3      = C.bg2
    row.BackgroundTransparency= 0.1
    row.BorderSizePixel       = 0
    row.Size                  = UDim2.new(1, -10, 0, 78)
    row.Parent                = parent
    addCorner(row, 14)
    addStroke(row, C.border, 1, 0.3)

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text       = text
    lbl.TextColor3 = C.textSoft
    lbl.TextSize   = 13
    lbl.Font       = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Size       = UDim2.new(0.6, 0, 0, 20)
    lbl.Position   = UDim2.new(0, 12, 0, 10)
    lbl.Parent     = row

    local valLbl = Instance.new("TextLabel")
    valLbl.BackgroundTransparency = 1
    valLbl.Text       = string.format(fmt, S[setting])
    valLbl.TextColor3 = C.blue
    valLbl.TextSize   = 15
    valLbl.Font       = Enum.Font.GothamBold
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Size       = UDim2.new(0.4, -12, 0, 20)
    valLbl.Position   = UDim2.new(0.6, 0, 0, 10)
    valLbl.Parent     = row

    local track = Instance.new("Frame")
    track.BackgroundColor3 = C.bg0
    track.Size             = UDim2.new(1, -24, 0, 6)
    track.Position         = UDim2.new(0, 12, 0, 48)
    track.BorderSizePixel  = 0
    track.Parent           = row
    addCorner(track, 3)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = C.blue
    fill.Size             = UDim2.new((S[setting]-min)/(max-min), 0, 1, 0)
    fill.BorderSizePixel  = 0
    fill.Parent           = track
    addCorner(fill, 3)

    local knob = Instance.new("Frame")
    knob.BackgroundColor3 = C.white
    knob.Size             = UDim2.new(0, 18, 0, 18)
    knob.Position         = UDim2.new((S[setting]-min)/(max-min), -9, 0.5, -9)
    knob.BorderSizePixel  = 0
    knob.Parent           = track
    addCorner(knob, 9)
    addStroke(knob, C.blue, 2)

    local dragging = false
    local function update(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v   = math.floor(min + rel*(max-min))
        S[setting]    = v
        valLbl.Text   = string.format(fmt, v)
        fill.Size     = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -9, 0.5, -9)
    end

    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    return row
end

local function createDropdown(parent, text, setting, options, color)
    color = color or C.purple
    local row = Instance.new("Frame")
    row.BackgroundColor3      = C.bg2
    row.BackgroundTransparency= 0.1
    row.BorderSizePixel       = 0
    row.Size                  = UDim2.new(1, -10, 0, 54)
    row.Parent                = parent
    addCorner(row, 14)
    addStroke(row, C.border, 1, 0.3)
    row.ClipsDescendants = false

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text       = text
    lbl.TextColor3 = C.textSoft
    lbl.TextSize   = 13
    lbl.Font       = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Size       = UDim2.new(0.5, 0, 1, 0)
    lbl.Position   = UDim2.new(0, 12, 0, 0)
    lbl.Parent     = row

    local selBtn = Instance.new("TextButton")
    selBtn.BackgroundColor3 = C.bg3
    selBtn.BorderSizePixel  = 0
    selBtn.Text             = S[setting]
    selBtn.TextColor3       = color
    selBtn.TextSize         = 13
    selBtn.Font             = Enum.Font.GothamBold
    selBtn.Size             = UDim2.new(0, 100, 0, 34)
    selBtn.Position         = UDim2.new(1, -112, 0.5, -17)
    selBtn.Parent           = row
    addCorner(selBtn, 9)
    addStroke(selBtn, color, 1)

    local panel = Instance.new("Frame")
    panel.BackgroundColor3 = C.bg3
    panel.BorderSizePixel  = 0
    panel.Size             = UDim2.new(0, 100, 0, 0)
    panel.Position         = UDim2.new(1, -112, 1, 4)
    panel.ClipsDescendants = true
    panel.ZIndex           = 100
    panel.Visible          = false
    panel.Parent           = row
    addCorner(panel, 9)
    addStroke(panel, color, 1)

    local pList = Instance.new("UIListLayout")
    pList.SortOrder = Enum.SortOrder.LayoutOrder
    pList.Parent    = panel

    for _, opt in ipairs(options) do
        local ob = Instance.new("TextButton")
        ob.BackgroundColor3 = C.bg3
        ob.BorderSizePixel  = 0
        ob.Text             = opt
        ob.TextColor3       = opt == S[setting] and color or C.textSoft
        ob.TextSize         = 13
        ob.Font             = Enum.Font.Gotham
        ob.Size             = UDim2.new(1, 0, 0, 34)
        ob.ZIndex           = 101
        ob.Parent           = panel
        addCorner(ob, 7)
        ob.MouseButton1Click:Connect(function()
            S[setting]    = opt
            selBtn.Text   = opt
            panel.Visible = false
            tween(panel, TI.fast, {Size = UDim2.new(0, 100, 0, 0)})
            for _, c in ipairs(panel:GetChildren()) do
                if c:IsA("TextButton") then
                    c.TextColor3 = c.Text == opt and color or C.textSoft
                end
            end
        end)
    end

    selBtn.MouseButton1Click:Connect(function()
        panel.Visible = not panel.Visible
        local h = panel.Visible and #options * 34 or 0
        tween(panel, TI.smooth, {Size = UDim2.new(0, 100, 0, h)})
    end)
    return row
end

-- ============================================================
-- POPULATE TABS
-- ============================================================

-- COMBAT TAB
do
    local f = contentFrames["combat"]

    sectionHeader(f, "  ⚔  AIMBOT", C.combat)

    local keyInfo = Instance.new("TextLabel")
    keyInfo.BackgroundTransparency = 1
    keyInfo.Text       = "  Hold LEFT SHIFT to lock aim"
    keyInfo.TextColor3 = C.warning
    keyInfo.TextSize   = 12
    keyInfo.Font       = Enum.Font.GothamBold
    keyInfo.Size       = UDim2.new(1, -10, 0, 22)
    keyInfo.TextXAlignment = Enum.TextXAlignment.Left
    keyInfo.Parent     = f

    createToggle(f, "Aimbot",      "Auto aim at enemies",       "Aimbot",      C.combat)
    createDropdown(f,"Aim Part",   "AimPart", {"Head","Torso"}, C.combat)
    createSlider(f,  "FOV Radius", "FOV",        20, 300, "%d")
    createSlider(f,  "Smoothness", "Smooth",      1, 100, "%d%%")
    createSlider(f,  "Prediction", "Prediction",  0,  20, "%d")
    createToggle(f, "Visible Only","Only visible enemies",       "VisibleOnly", C.warning)
    createToggle(f, "Team Check",  "Skip teammates",             "TeamCheck",   C.textMuted)

    sectionHeader(f, "  🔫  WEAPON", C.combat)
    createToggle(f, "No Recoil",   "Remove camera recoil",      "NoRecoil",    C.combat)
    createToggle(f, "Hitbox+",     "Expand enemy hitboxes",     "Hitbox",      C.combat)
    createSlider(f, "Hitbox Size", "HitboxSize", 2, 20, "%d")

    sectionHeader(f, "  ✛  CROSSHAIR", C.info)
    createToggle(f, "Crosshair",   "Custom crosshair",          "Crosshair",   C.info)
end

-- VISUALS TAB
do
    local f = contentFrames["visuals"]

    sectionHeader(f, "  👁  ESP", C.visuals)
    createToggle(f, "ESP Box",    "Box around players", "ESPBox",    C.visuals)
    createToggle(f, "Name Tags",  "Show names",         "ESPName",   C.visuals)
    createToggle(f, "Health Bars","Show HP bar",        "ESPHealth", C.success)
    createToggle(f, "Tracers",    "Lines to players",   "Tracers",   C.visuals)
    createToggle(f, "Chams",      "Outline thru walls", "ESPChams",  C.visuals)
end

-- MISC TAB
do
    local f = contentFrames["misc"]

    sectionHeader(f, "  ⚙  SCRIPT", C.settings)

    local unloadBtn = Instance.new("TextButton")
    unloadBtn.BackgroundColor3 = Color3.fromRGB(35, 10, 15)
    unloadBtn.BorderSizePixel  = 0
    unloadBtn.Text             = "💀  UNLOAD SCRIPT"
    unloadBtn.TextColor3       = C.danger
    unloadBtn.TextSize         = 15
    unloadBtn.Font             = Enum.Font.GothamBold
    unloadBtn.Size             = UDim2.new(1, -10, 0, 52)
    unloadBtn.Parent           = f
    addCorner(unloadBtn, 12)
    addStroke(unloadBtn, C.danger, 1.5)

    local confirmed = false
    unloadBtn.MouseButton1Click:Connect(function()
        if not confirmed then
            confirmed = true
            unloadBtn.Text       = "⚠️  CLICK AGAIN TO CONFIRM"
            unloadBtn.TextColor3 = C.warning
            tween(unloadBtn, TI.fast, {BackgroundColor3 = Color3.fromRGB(40, 30, 5)})
            task.delay(3, function()
                if confirmed then
                    confirmed = false
                    pcall(function()
                        unloadBtn.Text       = "💀  UNLOAD SCRIPT"
                        unloadBtn.TextColor3 = C.danger
                        tween(unloadBtn, TI.fast, {BackgroundColor3 = Color3.fromRGB(35, 10, 15)})
                    end)
                end
            end)
        else
            -- Clean up drawings
            for _, e in pairs(espCache) do
                pcall(function()
                    for _, l in ipairs(e.lines) do l:Remove() end
                    e.name:Remove(); e.hp:Remove()
                    e.hpBar:Remove(); e.hpBarBg:Remove(); e.tracer:Remove()
                end)
            end
            pcall(function() fovCircle:Remove() end)
            for i = 1, 4 do pcall(function() crossLines[i]:Remove() end) end
            -- Remove chams
            for _, plr in ipairs(Players:GetPlayers()) do
                pcall(function()
                    local s = plr.Character and plr.Character:FindFirstChild("__Chams")
                    if s then s:Destroy() end
                end)
            end
            sg:Destroy()
        end
    end)

    local infoLbl = Instance.new("TextLabel")
    infoLbl.BackgroundTransparency = 1
    infoLbl.Text       = "Safely removes all drawings and GUI"
    infoLbl.TextColor3 = C.textMuted
    infoLbl.TextSize   = 11
    infoLbl.Font       = Enum.Font.Gotham
    infoLbl.Size       = UDim2.new(1, -10, 0, 20)
    infoLbl.TextXAlignment = Enum.TextXAlignment.Left
    infoLbl.Parent     = f
end

-- ============================================================
-- TOGGLE BUTTON LOGIC
-- ============================================================
toggleHit.MouseButton1Click:Connect(function()
    S.UIVisible = not S.UIVisible
    win.Visible = S.UIVisible
    toggleIcon.Text = S.UIVisible and "⚡" or "✕"
    tween(toggleBtn, TI.spring, {BackgroundColor3 = S.UIVisible and C.purple or C.danger})
end)

-- ============================================================
-- PLAYER HELPERS
-- ============================================================
local function isAlive(plr)
    local c = plr.Character
    if not c then return false end
    local h = c:FindFirstChildWhichIsA("Humanoid")
    return h ~= nil and h.Health > 0
end

local function isEnemy(plr)
    if plr == LP then return false end
    if not isAlive(plr) then return false end
    if S.TeamCheck and LP.Team and plr.Team and LP.Team == plr.Team then return false end
    return true
end

local function getAimPart(char)
    if S.AimPart == "Head" then
        return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    else
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    end
end

local function isVisible(part)
    local origin = Cam.CFrame.Position
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LP.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, part.Position - origin, params)
    return result == nil or result.Instance:IsDescendantOf(part.Parent)
end

-- ============================================================
-- DRAWING SETUP  (safe init)
-- ============================================================
local drawOK = false
pcall(function()
    local t = Drawing.new("Line"); t:Remove(); drawOK = true
end)

local fovCircle, crossLines = nil, {}

if drawOK then
    fovCircle              = Drawing.new("Circle")
    fovCircle.Thickness    = 1.5
    fovCircle.Filled       = false
    fovCircle.NumSides     = 64
    fovCircle.Visible      = false
    fovCircle.Transparency = 1
    fovCircle.Color        = C.purple
    fovCircle.ZIndex       = 7

    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness    = 2
        l.Visible      = false
        l.Transparency = 1
        l.Color        = C.white
        l.ZIndex       = 7
        crossLines[i]  = l
    end
end

-- ============================================================
-- ESP CACHE
-- ============================================================
local espCache = {}

local function getESP(plr)
    if espCache[plr] then return espCache[plr] end
    if not drawOK then return nil end
    local e = {lines={}}
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness = 1.5; l.Visible = false; l.Transparency = 1; l.ZIndex = 5
        e.lines[i] = l
    end
    e.name = Drawing.new("Text")
    e.name.Size=16; e.name.Center=true; e.name.Outline=true
    e.name.OutlineColor=Color3.new(0,0,0); e.name.Transparency=1; e.name.Visible=false; e.name.ZIndex=6

    e.hp = Drawing.new("Text")
    e.hp.Size=13; e.hp.Center=true; e.hp.Outline=true
    e.hp.OutlineColor=Color3.new(0,0,0); e.hp.Transparency=1; e.hp.Visible=false; e.hp.ZIndex=6

    e.hpBar = Drawing.new("Line")
    e.hpBar.Thickness=3; e.hpBar.Transparency=1; e.hpBar.Visible=false; e.hpBar.ZIndex=5

    e.hpBarBg = Drawing.new("Line")
    e.hpBarBg.Thickness=3; e.hpBarBg.Color=Color3.fromRGB(30,30,30)
    e.hpBarBg.Transparency=0.5; e.hpBarBg.Visible=false; e.hpBarBg.ZIndex=4

    e.tracer = Drawing.new("Line")
    e.tracer.Thickness=1; e.tracer.Transparency=1; e.tracer.Visible=false; e.tracer.ZIndex=3

    espCache[plr] = e
    return e
end

local function hideESP(e)
    if not e then return end
    for _, l in ipairs(e.lines) do l.Visible=false end
    e.name.Visible=false; e.hp.Visible=false
    e.hpBar.Visible=false; e.hpBarBg.Visible=false; e.tracer.Visible=false
end

local function removeESP(plr)
    local e = espCache[plr]; if not e then return end
    pcall(function()
        for _, l in ipairs(e.lines) do l:Remove() end
        e.name:Remove(); e.hp:Remove(); e.hpBar:Remove(); e.hpBarBg:Remove(); e.tracer:Remove()
    end)
    espCache[plr] = nil
end

Players.PlayerRemoving:Connect(removeESP)

-- Clean up chams when character respawns
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        local s = char:FindFirstChild("__Chams")
        if s then s:Destroy() end
    end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        local s = char:FindFirstChild("__Chams")
        if s then s:Destroy() end
    end)
end

local function drawBox(e, x1,y1,x2,y2, col)
    local segs = {
        {Vector2.new(x1,y1),Vector2.new(x2,y1)},
        {Vector2.new(x1,y2),Vector2.new(x2,y2)},
        {Vector2.new(x1,y1),Vector2.new(x1,y2)},
        {Vector2.new(x2,y1),Vector2.new(x2,y2)},
    }
    for i, s in ipairs(segs) do
        e.lines[i].From=s[1]; e.lines[i].To=s[2]
        e.lines[i].Color=col; e.lines[i].Visible=true
    end
end

local function getBounds(char)
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp then return nil end

    -- Use head top and feet bottom for accurate height
    local topPos    = head and (head.Position + Vector3.new(0, head.Size.Y/2 + 0.1, 0))
                           or  (hrp.Position  + Vector3.new(0, 3, 0))
    local bottomPos = hrp.Position - Vector3.new(0, 3, 0)

    local cp, cvis = Cam:WorldToViewportPoint(hrp.Position)
    if not cvis then return nil end

    local tp = Cam:WorldToViewportPoint(topPos)
    local bp = Cam:WorldToViewportPoint(bottomPos)

    local y1 = math.min(tp.Y, cp.Y - 10)
    local y2 = math.max(bp.Y, cp.Y + 10)
    local h  = y2 - y1
    local w  = h * 0.4
    local cx = cp.X

    return cx - w, y1, cx + w, y2, cx, cp.Y
end

-- ============================================================
-- TARGET FINDER
-- ============================================================
local cachedTarget = nil
local lockedTarget = nil
local aimKeyHeld   = false

local function findTarget()
    local best, bestDist = nil, math.huge
    local mid   = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    local fovPx = (S.FOV / Cam.FieldOfView) * (Cam.ViewportSize.X/2)
    for _, plr in ipairs(Players:GetPlayers()) do
        if not isEnemy(plr) then continue end
        local part = getAimPart(plr.Character)
        if not part then continue end
        local sp, vis = Cam:WorldToViewportPoint(part.Position)
        if not vis then continue end
        if S.VisibleOnly and not isVisible(part) then continue end
        local d2 = (Vector2.new(sp.X,sp.Y) - mid).Magnitude
        if d2 < fovPx and d2 < bestDist then
            bestDist = d2; best = part
        end
    end
    return best
end

UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == S.AimKey then
        aimKeyHeld   = true
        lockedTarget = findTarget()
    end
    if i.KeyCode == S.ToggleKey then
        S.UIVisible = not S.UIVisible
        win.Visible = S.UIVisible
        toggleIcon.Text = S.UIVisible and "⚡" or "✕"
        tween(toggleBtn, TI.spring, {BackgroundColor3 = S.UIVisible and C.purple or C.danger})
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.KeyCode == S.AimKey then
        aimKeyHeld = false; lockedTarget = nil
    end
end)

-- ============================================================
-- MAIN RENDER LOOP
-- ============================================================
RunService.RenderStepped:Connect(function()
    local vp  = Cam.ViewportSize
    local mid = Vector2.new(vp.X/2, vp.Y/2)

    cachedTarget = findTarget()

    -- Validate lock
    if lockedTarget and (not lockedTarget.Parent) then
        lockedTarget = findTarget()
    end

    -- ── AIMBOT ──────────────────────────────────────────────
    if S.Aimbot and aimKeyHeld and lockedTarget then
        local aimPos = lockedTarget.Position
        pcall(function()
            aimPos = lockedTarget.Position + lockedTarget.AssemblyLinearVelocity * (S.Prediction * 0.016)
        end)
        local sp, vis = Cam:WorldToViewportPoint(aimPos)
        if vis then
            local delta  = Vector2.new(sp.X, sp.Y) - mid
            local smooth = math.clamp((101 - S.Smooth) / 100, 0.01, 1)
            -- Try mousemoverel first (best), fallback to CFrame
            local ok = pcall(mousemoverel, delta.X * smooth, delta.Y * smooth)
            if not ok then
                Cam.CFrame = Cam.CFrame:Lerp(CFrame.new(Cam.CFrame.Position, aimPos), smooth)
            end
        end
    end

    -- ── FOV CIRCLE ──────────────────────────────────────────
    if drawOK and fovCircle then
        if S.Aimbot then
            fovCircle.Visible  = true
            fovCircle.Position = mid
            fovCircle.Radius   = (S.FOV / Cam.FieldOfView) * (vp.X/2)
            fovCircle.Color    = (aimKeyHeld and lockedTarget) and C.success
                              or cachedTarget and C.danger or C.purple
        else
            fovCircle.Visible = false
        end
    end

    -- ── CROSSHAIR ───────────────────────────────────────────
    if drawOK and S.Crosshair and #crossLines == 4 then
        local sz, gap = 10, 5
        local segs = {
            {Vector2.new(mid.X,mid.Y-sz-gap), Vector2.new(mid.X,mid.Y-gap)},
            {Vector2.new(mid.X,mid.Y+gap),    Vector2.new(mid.X,mid.Y+sz+gap)},
            {Vector2.new(mid.X-sz-gap,mid.Y), Vector2.new(mid.X-gap,mid.Y)},
            {Vector2.new(mid.X+gap,mid.Y),    Vector2.new(mid.X+sz+gap,mid.Y)},
        }
        for i, s in ipairs(segs) do
            crossLines[i].From=s[1]; crossLines[i].To=s[2]
            crossLines[i].Color   = cachedTarget and C.danger or C.white
            crossLines[i].Visible = true
        end
    elseif drawOK and #crossLines == 4 then
        for i = 1, 4 do crossLines[i].Visible = false end
    end

    -- ── ESP ─────────────────────────────────────────────────
    local espAny = S.ESPBox or S.ESPName or S.ESPHealth or S.Tracers or S.ESPChams

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end

        local char = plr.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildWhichIsA("Humanoid")

        -- Check if this player should show ESP
        local dist3D   = hrp and (hrp.Position - Cam.CFrame.Position).Magnitude or math.huge
        local showESP  = isEnemy(plr) and hrp ~= nil and hum ~= nil and dist3D <= 500

        -- Handle chams: show/hide based on showESP and toggle
        if char then
            local sel = char:FindFirstChild("__Chams")
            if showESP and S.ESPChams then
                -- Create if missing
                if not sel then
                    sel = Instance.new("SelectionBox")
                    sel.Name              = "__Chams"
                    sel.Adornee           = char
                    sel.Color3            = C.danger
                    sel.LineThickness     = 0.04
                    sel.SurfaceTransparency = 0.65
                    sel.SurfaceColor3     = C.danger
                    sel.Parent            = char
                end
            else
                -- Remove if exists but shouldn't be shown
                if sel then sel:Destroy() end
            end
        end

        -- Handle drawing ESP
        if not showESP then
            if drawOK and espCache[plr] then hideESP(espCache[plr]) end
            continue
        end

        if not drawOK or not espAny then continue end

        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not hum then hideESP(getESP(plr)); continue end

        local e = getESP(plr)
        local x1,y1,x2,y2,cx,cy = getBounds(char)
        if not x1 then hideESP(e); continue end

        local hp     = math.max(0, hum.Health)
        local maxHp  = math.max(1, hum.MaxHealth)
        local ratio  = hp / maxHp
        local col    = Color3.fromRGB(
            math.floor(255 * math.clamp(2*(1-ratio), 0, 1)),
            math.floor(255 * math.clamp(2*ratio,     0, 1)),
            50
        )

        if S.ESPBox then
            drawBox(e, x1,y1,x2,y2, col)
        else
            for _, l in ipairs(e.lines) do l.Visible=false end
        end

        if S.ESPHealth then
            local bx  = x1 - 5
            local barH = (y2 - y1)
            e.hpBarBg.From=Vector2.new(bx,y1); e.hpBarBg.To=Vector2.new(bx,y2)
            e.hpBarBg.Visible=true
            e.hpBar.From=Vector2.new(bx,y2); e.hpBar.To=Vector2.new(bx,y2-barH*ratio)
            e.hpBar.Color=col; e.hpBar.Visible=true
        else
            e.hpBar.Visible=false; e.hpBarBg.Visible=false
        end

        if S.ESPName then
            e.name.Text=plr.Name; e.name.Position=Vector2.new(cx,y1-18)
            e.name.Color=C.white; e.name.Visible=true
        else e.name.Visible=false end

        if S.ESPHealth and not S.ESPBox then
            e.hp.Text=math.floor(hp).."hp"; e.hp.Position=Vector2.new(cx,y2+2)
            e.hp.Color=col; e.hp.Visible=true
        else e.hp.Visible=false end

        if S.Tracers then
            e.tracer.From=Vector2.new(mid.X,vp.Y); e.tracer.To=Vector2.new(cx,y2)
            e.tracer.Color=col; e.tracer.Visible=true
        else e.tracer.Visible=false end
    end
end)

-- ============================================================
-- HEARTBEAT  (hitbox)
-- ============================================================
RunService.Heartbeat:Connect(function()
    if not S.Hitbox then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                hrp.Size        = Vector3.new(S.HitboxSize, S.HitboxSize, S.HitboxSize)
                hrp.Transparency= 0.85
            end)
        end
    end
end)

-- ============================================================
-- NO RECOIL
-- ============================================================
local prevPitch = nil
RunService.Stepped:Connect(function()
    if not S.NoRecoil then prevPitch=nil; return end
    if aimKeyHeld then prevPitch=nil; return end
    local rx, ry = Cam.CFrame:ToEulerAnglesYXZ()
    if prevPitch and rx < prevPitch then
        Cam.CFrame = CFrame.new(Cam.CFrame.Position) * CFrame.Angles(0,ry,0) * CFrame.Angles(prevPitch,0,0)
    end
    prevPitch = rx
end)

print("✅ Master Hub loaded | RightShift = toggle | LeftShift = aim lock")
