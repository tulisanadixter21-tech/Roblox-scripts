--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║   MASTER HUB  ·  RIVALS DEFINITIVE EDITION  ·  V2.0                        ║
║   UI Framework: tabbed glass-morphism panel, modular components,            ║
║   smooth tweens, clamped drag, sliders, toggles, keybind selector           ║
╚══════════════════════════════════════════════════════════════════════════════╝
--]]

-- ════════════════════════════════════════════════════════
--  §1  SERVICES & LOCALS
-- ════════════════════════════════════════════════════════
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")

local LP   = Players.LocalPlayer
local Cam  = workspace.CurrentCamera

-- cleanup old instance
if CoreGui:FindFirstChild("MasterHubV2") then
    CoreGui.MasterHubV2:Destroy()
end

-- ════════════════════════════════════════════════════════
--  §2  SETTINGS TABLE  (single source of truth)
-- ════════════════════════════════════════════════════════
local S = {
    -- Combat
    Aimbot      = false,
    Silent      = false,
    Hitbox      = false,
    NoRecoil    = false,
    AutoReload  = false,
    TeamCheck   = true,
    FOV         = 180,
    Smooth      = 0.85,

    -- Movement
    SpeedBoost  = false,
    Fly         = false,
    WalkSpeed   = 45,
    JumpPower   = 80,
    FlySpeed    = 75,

    -- Visuals
    ESP         = false,

    -- Misc
    ToggleKey   = Enum.KeyCode.Insert,
    Running     = true,
}

-- ════════════════════════════════════════════════════════
--  §3  COLOUR PALETTE  &  TWEEN PRESETS
-- ════════════════════════════════════════════════════════
local C = {
    bg          = Color3.fromRGB(9,  11, 20),
    surface     = Color3.fromRGB(15, 18, 34),
    surfaceHi   = Color3.fromRGB(22, 27, 50),
    border      = Color3.fromRGB(38, 50, 95),
    accent      = Color3.fromRGB(90, 200, 255),   -- ice-blue
    accentDim   = Color3.fromRGB(45, 110, 165),
    danger      = Color3.fromRGB(255, 70,  70),
    success     = Color3.fromRGB(70,  225, 130),
    warn        = Color3.fromRGB(255, 185, 50),
    violet      = Color3.fromRGB(170, 85,  255),
    txt1        = Color3.fromRGB(218, 232, 255),
    txt2        = Color3.fromRGB(110, 135, 185),
    txtDim      = Color3.fromRGB(55,  72,  110),
    white       = Color3.new(1,1,1),

    -- Tab accent colours
    tabCombat   = Color3.fromRGB(255, 90,  90),
    tabMove     = Color3.fromRGB(90,  210, 255),
    tabVisual   = Color3.fromRGB(175, 90,  255),
    tabSettings = Color3.fromRGB(255, 185, 50),
}

local TI = {
    fast   = TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    med    = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    slow   = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    spring = TweenInfo.new(0.40, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
    bounce = TweenInfo.new(0.35, Enum.EasingStyle.Bounce,Enum.EasingDirection.Out),
}

local function tw(inst, info, props)
    TweenService:Create(inst, info, props):Play()
end

-- ════════════════════════════════════════════════════════
--  §4  UTILITY FUNCTIONS
-- ════════════════════════════════════════════════════════
local function GetScaledFOV()
    return (S.FOV / Cam.FieldOfView) * 70
end

-- ── IsAlive: true only if the player has a living character in workspace
--   Fixes: dead ragdolls targeted (Health=0), unloaded characters targeted
local function IsAlive(player)
    local char = player.Character
    if not char then return false end
    -- Must be parented to workspace (not a cached ragdoll elsewhere)
    if char.Parent ~= workspace then return false end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return true
end

-- ── IsEnemy: true only if player is a valid, living enemy
--   Fixes: team-mates targeted when TeamCheck=true,
--          nil-team edge case (both nil → nil==nil → true → wrongly skipped)
local function IsEnemy(player)
    if player == LP then return false end
    if not IsAlive(player) then return false end
    if S.TeamCheck then
        -- Only skip if BOTH teams are non-nil AND they actually match.
        -- If either team is nil (loading/unassigned) treat as enemy to be safe.
        local myTeam     = LP.Team
        local theirTeam  = player.Team
        if myTeam ~= nil and theirTeam ~= nil and theirTeam == myTeam then
            return false   -- same real team → not an enemy
        end
    end
    return true
end

local function GetTarget()
    local best, bestDist = nil, GetScaledFOV()
    local mid = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
    for _, v in ipairs(Players:GetPlayers()) do
        if not IsEnemy(v) then continue end
        local head = v.Character:FindFirstChild("Head")
        if head then
            local pos, vis = Cam:WorldToViewportPoint(head.Position)
            if vis then
                local d = (Vector2.new(pos.X, pos.Y) - mid).Magnitude
                if d < bestDist then bestDist = d; best = head end
            end
        end
    end
    return best
end

local function ClampToScreen(frame)
    local vp   = Cam.ViewportSize
    local apos = frame.AbsolutePosition
    local asize= frame.AbsoluteSize
    local x    = math.clamp(apos.X, 0, vp.X - asize.X)
    local y    = math.clamp(apos.Y, 0, vp.Y - asize.Y)
    frame.Position = UDim2.new(0, x, 0, y)
end

-- ════════════════════════════════════════════════════════
--  §5  UI FRAMEWORK  —  base helpers
-- ════════════════════════════════════════════════════════
local function NewCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
    return c
end

local function NewStroke(parent, color, thick, trans)
    local s = Instance.new("UIStroke")
    s.Color        = color or C.border
    s.Thickness    = thick or 1
    s.Transparency = trans or 0
    s.Parent = parent
    return s
end

local function NewPadding(parent, all, l, r, t, b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft   = UDim.new(0, l or all or 6)
    p.PaddingRight  = UDim.new(0, r or all or 6)
    p.PaddingTop    = UDim.new(0, t or all or 6)
    p.PaddingBottom = UDim.new(0, b or all or 6)
    p.Parent = parent
    return p
end

local function NewList(parent, dir, align, valign, pad)
    local l = Instance.new("UIListLayout")
    l.FillDirection       = dir    or Enum.FillDirection.Vertical
    l.HorizontalAlignment = align  or Enum.HorizontalAlignment.Left
    l.VerticalAlignment   = valign or Enum.VerticalAlignment.Top
    l.Padding             = UDim.new(0, pad or 4)
    l.SortOrder           = Enum.SortOrder.LayoutOrder
    l.Parent = parent
    return l
end

local function NewFrame(parent, props)
    local f = Instance.new("Frame")
    f.BackgroundColor3       = props.bg    or C.surface
    f.BackgroundTransparency = props.trans or 0
    f.BorderSizePixel        = 0
    f.Size                   = props.size  or UDim2.new(1,0,0,30)
    f.Position               = props.pos   or UDim2.new(0,0,0,0)
    f.ZIndex                 = props.z     or 1
    f.Name                   = props.name  or "Frame"
    if props.clip ~= nil then f.ClipsDescendants = props.clip end
    f.Parent = parent
    return f
end

local function NewLabel(parent, props)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.BorderSizePixel        = 0
    t.Text                   = props.text   or ""
    t.TextColor3             = props.color  or C.txt1
    t.TextSize               = props.size   or 12
    t.Font                   = props.font   or Enum.Font.GothamBold
    t.RichText               = props.rich   or false
    t.TextXAlignment         = props.xalign or Enum.TextXAlignment.Left
    t.TextYAlignment         = props.yalign or Enum.TextYAlignment.Center
    t.TextWrapped            = props.wrap   or false
    t.Size                   = props.sz     or UDim2.new(1,0,0,20)
    t.Position               = props.upos   or UDim2.new(0,0,0,0)
    t.ZIndex                 = props.z      or 3
    t.Name                   = props.name   or "Label"
    t.Parent = parent
    return t
end

local function NewBtn(parent, props)
    local b = Instance.new("TextButton")
    b.BackgroundColor3       = props.bg    or C.surfaceHi
    b.BackgroundTransparency = props.trans or 0
    b.BorderSizePixel        = 0
    b.Text                   = props.text  or ""
    b.TextColor3             = props.color or C.txt1
    b.TextSize               = props.size  or 12
    b.Font                   = props.font  or Enum.Font.GothamBold
    b.AutoButtonColor        = false
    b.Size                   = props.sz    or UDim2.new(1,0,0,30)
    b.Position               = props.upos  or UDim2.new(0,0,0,0)
    b.ZIndex                 = props.z     or 3
    b.Name                   = props.name  or "Button"
    b.Parent = parent
    return b
end

-- Ripple animation on a button
local function AddRipple(btn)
    btn.MouseButton1Down:Connect(function(x, y)
        local ripple = Instance.new("Frame")
        ripple.BackgroundColor3 = Color3.new(1,1,1)
        ripple.BackgroundTransparency = 0.7
        ripple.BorderSizePixel = 0
        ripple.ZIndex = btn.ZIndex + 2
        NewCorner(ripple, 999)
        ripple.Size = UDim2.new(0,0,0,0)
        local rel = Vector2.new(x - btn.AbsolutePosition.X, y - btn.AbsolutePosition.Y)
        ripple.Position = UDim2.new(0, rel.X, 0, rel.Y)
        ripple.AnchorPoint = Vector2.new(0.5, 0.5)
        ripple.Parent = btn
        local maxR = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 1.5
        tw(ripple, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, maxR, 0, maxR),
            BackgroundTransparency = 1,
        })
        task.delay(0.5, function() ripple:Destroy() end)
    end)
end

-- ════════════════════════════════════════════════════════
--  §6  MODULAR UI COMPONENTS
-- ════════════════════════════════════════════════════════

-- ── §6.1  TOGGLE ──────────────────────────────────────
--  Returns the row Frame. onChanged(newValue) is called on toggle.
local function CreateToggle(parent, text, settingKey, accentColor, onChanged)
    accentColor = accentColor or C.accent

    local row = NewFrame(parent, {
        bg   = C.surfaceHi,
        size = UDim2.new(1,-12,0,38),
        name = "Toggle_"..settingKey,
    })
    NewCorner(row, 9)
    -- hover
    row.MouseEnter:Connect(function()
        tw(row, TI.fast, { BackgroundColor3 = Color3.fromRGB(28,34,62) })
    end)
    row.MouseLeave:Connect(function()
        tw(row, TI.fast, { BackgroundColor3 = C.surfaceHi })
    end)

    -- label
    NewLabel(row, {
        text  = text,
        color = C.txt1,
        size  = 11,
        font  = Enum.Font.Gotham,
        sz    = UDim2.new(1,-56,1,0),
        upos  = UDim2.new(0,12,0,0),
        z     = 4,
    })

    -- switch track
    local track = NewFrame(row, {
        bg   = C.border,
        size = UDim2.new(0,36,0,20),
        pos  = UDim2.new(1,-46,0.5,-10),
        name = "Track",
    })
    NewCorner(track, 10)

    -- switch thumb
    local thumb = NewFrame(track, {
        bg   = C.white,
        size = UDim2.new(0,14,0,14),
        pos  = UDim2.new(0,3,0.5,-7),
        z    = 5,
        name = "Thumb",
    })
    NewCorner(thumb, 7)

    local function refresh()
        local on = S[settingKey]
        tw(track, TI.fast, { BackgroundColor3 = on and accentColor or C.border })
        tw(thumb, TI.fast, { Position = on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7) })
        tw(thumb, TI.fast, { BackgroundColor3 = on and C.white or Color3.fromRGB(160,170,200) })
    end
    refresh()

    -- clickable overlay
    local overlay = NewBtn(row, {
        bg    = C.bg,
        trans = 1,
        size  = UDim2.new(1,0,1,0),
        color = C.bg,
        z     = 6,
        name  = "Overlay",
    })
    AddRipple(overlay)
    overlay.MouseButton1Click:Connect(function()
        S[settingKey] = not S[settingKey]
        refresh()
        if onChanged then onChanged(S[settingKey]) end
    end)

    return row
end

-- ── §6.2  SLIDER ──────────────────────────────────────
local function CreateSlider(parent, text, settingKey, minVal, maxVal, onChanged)
    local row = NewFrame(parent, {
        bg   = C.surfaceHi,
        size = UDim2.new(1,-12,0,54),
        name = "Slider_"..settingKey,
    })
    NewCorner(row, 9)

    -- title + value
    NewLabel(row, {
        text  = text,
        color = C.txt2,
        size  = 10,
        font  = Enum.Font.Gotham,
        sz    = UDim2.new(0.65,0,0,18),
        upos  = UDim2.new(0,12,0,5),
        z     = 4,
    })
    local valLbl = NewLabel(row, {
        text   = tostring(S[settingKey]),
        color  = C.accent,
        size   = 10,
        font   = Enum.Font.GothamBold,
        sz     = UDim2.new(0.35,-8,0,18),
        upos   = UDim2.new(0.65,0,0,5),
        xalign = Enum.TextXAlignment.Right,
        z      = 4,
    })

    -- track
    local track = NewFrame(row, {
        bg   = C.bg,
        size = UDim2.new(1,-24,0,4),
        pos  = UDim2.new(0,12,0,32),
        name = "Track",
    })
    NewCorner(track, 2)

    local fill = NewFrame(track, {
        bg   = C.accent,
        size = UDim2.new((S[settingKey] - minVal) / (maxVal - minVal), 0, 1, 0),
        name = "Fill",
    })
    NewCorner(fill, 2)

    local thumb = NewFrame(track, {
        bg   = C.white,
        size = UDim2.new(0,12,0,12),
        pos  = UDim2.new(fill.Size.X.Scale, -6, 0.5, -6),
        z    = 5,
        name = "Thumb",
    })
    NewCorner(thumb, 6)

    -- drag logic
    local dragging = false
    local function updateSlider(x)
        local trackAbs  = track.AbsolutePosition
        local trackW    = track.AbsoluteSize.X
        local relX      = math.clamp((x - trackAbs.X) / trackW, 0, 1)
        local val       = math.floor(minVal + relX * (maxVal - minVal))
        S[settingKey]   = val
        valLbl.Text     = tostring(val)
        fill.Size       = UDim2.new(relX, 0, 1, 0)
        thumb.Position  = UDim2.new(relX, -6, 0.5, -6)
        if onChanged then onChanged(val) end
    end

    thumb.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(inp.Position.X)
        end
    end)
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            updateSlider(inp.Position.X)
        end
    end)

    return row
end

-- ── §6.3  SECTION DIVIDER ─────────────────────────────
local function CreateDivider(parent, text, accentColor)
    accentColor = accentColor or C.accentDim
    local row = NewFrame(parent, {
        bg   = C.bg,
        trans= 1,
        size = UDim2.new(1,-12,0,26),
        name = "Divider_"..text,
    })

    -- left line
    local ll = NewFrame(row, { bg=accentColor, size=UDim2.new(0,3,0,14), pos=UDim2.new(0,0,0.5,-7) })
    NewCorner(ll, 2)

    NewLabel(row, {
        text  = text:upper(),
        color = accentColor,
        size  = 9,
        font  = Enum.Font.GothamBold,
        sz    = UDim2.new(1,-12,1,0),
        upos  = UDim2.new(0,10,0,0),
        z     = 3,
    })

    -- right rule line
    local rl = NewFrame(row, { bg=C.border, size=UDim2.new(1,-80,0,1), pos=UDim2.new(0,76,0.5,0) })

    return row
end

-- ── §6.4  KEYBIND SELECTOR ────────────────────────────
local function CreateKeybind(parent, text, settingKey)
    local row = NewFrame(parent, {
        bg   = C.surfaceHi,
        size = UDim2.new(1,-12,0,38),
        name = "Keybind_"..settingKey,
    })
    NewCorner(row, 9)

    NewLabel(row, {
        text  = text,
        color = C.txt2,
        size  = 11,
        font  = Enum.Font.Gotham,
        sz    = UDim2.new(0.6,0,1,0),
        upos  = UDim2.new(0,12,0,0),
        z     = 4,
    })

    local badge = NewBtn(row, {
        bg    = C.bg,
        text  = S[settingKey].Name,
        color = C.accent,
        size  = 10,
        font  = Enum.Font.GothamBold,
        sz    = UDim2.new(0,74,0,24),
        upos  = UDim2.new(1,-82,0.5,-12),
        z     = 5,
        name  = "Badge",
    })
    NewCorner(badge, 6)
    NewStroke(badge, C.accentDim, 1)

    local listening = false
    badge.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        badge.Text = "..."
        tw(badge, TI.fast, { BackgroundColor3 = C.accentDim })
        local conn
        conn = UserInputService.InputBegan:Connect(function(inp, p)
            if p then return end
            if inp.UserInputType == Enum.UserInputType.Keyboard then
                S[settingKey] = inp.KeyCode
                badge.Text = inp.KeyCode.Name
                tw(badge, TI.fast, { BackgroundColor3 = C.bg })
                listening = false
                conn:Disconnect()
            end
        end)
    end)

    return row
end

-- ── §6.5  INFO ROW (read-only label pair) ─────────────
local function CreateInfo(parent, text, valueText)
    local row = NewFrame(parent, {
        bg   = C.bg,
        trans= 1,
        size = UDim2.new(1,-12,0,22),
        name = "Info_"..text,
    })
    NewLabel(row, {
        text  = text,
        color = C.txtDim,
        size  = 10,
        font  = Enum.Font.Gotham,
        sz    = UDim2.new(0.5,0,1,0),
        z     = 3,
    })
    local val = NewLabel(row, {
        text   = valueText or "—",
        color  = C.txt2,
        size   = 10,
        font   = Enum.Font.GothamBold,
        sz     = UDim2.new(0.5,0,1,0),
        upos   = UDim2.new(0.5,0,0,0),
        xalign = Enum.TextXAlignment.Right,
        z      = 3,
    })
    return row, val
end

-- ════════════════════════════════════════════════════════
--  §7  MAIN UI  —  window, title bar, tabs
-- ════════════════════════════════════════════════════════
local WIN_W  = 280
local WIN_H  = 480

local sg = Instance.new("ScreenGui")
sg.Name           = "MasterHubV2"
sg.DisplayOrder   = 999
sg.ResetOnSpawn   = false
sg.IgnoreGuiInset = true
sg.Parent         = CoreGui

-- ── Shadow glow behind window
local shadow = NewFrame(sg, {
    bg   = C.accentDim,
    trans= 0.88,
    size = UDim2.new(0, WIN_W+50, 0, WIN_H+50),
    pos  = UDim2.new(0.5,-(WIN_W//2+25), 0.5,-(WIN_H//2+25)),
    z    = 0,
    name = "Shadow",
})
NewCorner(shadow, 22)

-- ── Main window frame
local win = NewFrame(sg, {
    bg   = C.bg,
    size = UDim2.new(0, WIN_W, 0, WIN_H),
    pos  = UDim2.new(0.5, -(WIN_W//2), 0.5, -(WIN_H//2)),
    clip = false,
    z    = 1,
    name = "Window",
})
NewCorner(win, 14)
NewStroke(win, C.border, 1.5)

-- Entrance tween
win.Position = UDim2.new(0.5, -(WIN_W//2), 0.5, -(WIN_H//2) + 28)
win.BackgroundTransparency = 1
tw(win, TI.spring, {
    BackgroundTransparency = 0,
    Position = UDim2.new(0.5, -(WIN_W//2), 0.5, -(WIN_H//2)),
})
tw(shadow, TI.spring, { BackgroundTransparency = 0.88 })

-- ── Animated scanline
local scanline = NewFrame(win, {
    bg   = C.accent,
    trans= 0.85,
    size = UDim2.new(1,0,0,1),
    pos  = UDim2.new(0,0,0,0),
    z    = 20,
    name = "Scanline",
})
task.spawn(function()
    while sg.Parent do
        scanline.Position = UDim2.new(0,0,0,0)
        tw(scanline, TweenInfo.new(3.0, Enum.EasingStyle.Linear), { Position = UDim2.new(0,0,1,-1) })
        task.wait(3.0)
    end
end)

-- ════════════════════════════════════════════════════════
--  §7.1  TITLE BAR
-- ════════════════════════════════════════════════════════
local titleBar = NewFrame(win, {
    bg   = C.surfaceHi,
    size = UDim2.new(1,0,0,50),
    pos  = UDim2.new(0,0,0,0),
    z    = 5,
    name = "TitleBar",
})
NewCorner(titleBar, 14)
-- hide bottom corners
NewFrame(titleBar, {
    bg   = C.surfaceHi,
    size = UDim2.new(1,0,0,14),
    pos  = UDim2.new(0,0,1,-14),
    z    = 4,
    name = "CornerCover",
})

-- Left accent strip
local strip = NewFrame(titleBar, {
    bg   = C.accent,
    size = UDim2.new(0,3,0,26),
    pos  = UDim2.new(0,14,0.5,-13),
    z    = 6,
})
NewCorner(strip, 2)

-- Title
NewLabel(titleBar, {
    text  = "MASTER HUB",
    color = C.white,
    size  = 14,
    font  = Enum.Font.GothamBold,
    sz    = UDim2.new(0,160,0,50),
    upos  = UDim2.new(0,24,0,0),
    z     = 6,
})
NewLabel(titleBar, {
    text  = "RIVALS  ·  v2.0",
    color = C.txt2,
    size  = 9,
    font  = Enum.Font.Gotham,
    sz    = UDim2.new(0,160,0,50),
    upos  = UDim2.new(0,24,0,18),
    z     = 6,
})

-- Close button
local closeBtn = NewBtn(titleBar, {
    bg    = Color3.fromRGB(220, 55, 55),
    text  = "✕",
    color = C.white,
    size  = 12,
    sz    = UDim2.new(0,22,0,22),
    upos  = UDim2.new(1,-32,0.5,-11),
    z     = 7,
    name  = "CloseBtn",
})
NewCorner(closeBtn, 6)
closeBtn.MouseEnter:Connect(function() tw(closeBtn, TI.fast, { BackgroundColor3 = Color3.fromRGB(255,80,80) }) end)
closeBtn.MouseLeave:Connect(function() tw(closeBtn, TI.fast, { BackgroundColor3 = Color3.fromRGB(220,55,55) }) end)
closeBtn.MouseButton1Click:Connect(function()
    S.Running = false
    tw(win,    TI.med, { BackgroundTransparency=1, Position=UDim2.new(0.5,-(WIN_W//2),0.5,-(WIN_H//2)+28) })
    tw(shadow, TI.med, { BackgroundTransparency=1 })
    task.delay(0.35, function() sg:Destroy() end)
end)

-- Minimise button
local minBtn = NewBtn(titleBar, {
    bg    = Color3.fromRGB(200, 160, 30),
    text  = "−",
    color = C.white,
    size  = 14,
    sz    = UDim2.new(0,22,0,22),
    upos  = UDim2.new(1,-58,0.5,-11),
    z     = 7,
    name  = "MinBtn",
})
NewCorner(minBtn, 6)
minBtn.MouseEnter:Connect(function() tw(minBtn, TI.fast, { BackgroundColor3 = Color3.fromRGB(255,205,40) }) end)
minBtn.MouseLeave:Connect(function() tw(minBtn, TI.fast, { BackgroundColor3 = Color3.fromRGB(200,160,30) }) end)
local minimised = false
minBtn.MouseButton1Click:Connect(function()
    minimised = not minimised
    tw(win, TI.med, { Size = minimised and UDim2.new(0,WIN_W,0,50) or UDim2.new(0,WIN_W,0,WIN_H) })
end)

-- ── Drag system (title bar only, clamped) ─────────────
do
    local dragging, dragStart, winStart = false, nil, nil
    titleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = inp.Position
            winStart  = win.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if win.Parent then ClampToScreen(win) end
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
                      or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - dragStart
            win.Position = UDim2.new(
                winStart.X.Scale, winStart.X.Offset + delta.X,
                winStart.Y.Scale, winStart.Y.Offset + delta.Y
            )
        end
    end)
end

-- ════════════════════════════════════════════════════════
--  §7.2  TAB BAR
-- ════════════════════════════════════════════════════════
local TABS = {
    { name = "Combat",   icon = "⚔",  color = C.tabCombat   },
    { name = "Movement", icon = "⚡",  color = C.tabMove     },
    { name = "Visuals",  icon = "👁",  color = C.tabVisual   },
    { name = "Settings", icon = "⚙",  color = C.tabSettings },
}
local activeTab    = nil
local tabPages     = {}
local tabBtns      = {}

local tabBar = NewFrame(win, {
    bg   = C.surface,
    size = UDim2.new(1,0,0,40),
    pos  = UDim2.new(0,0,0,50),
    z    = 5,
    name = "TabBar",
})
-- bottom border
NewFrame(tabBar, { bg=C.border, size=UDim2.new(1,0,0,1), pos=UDim2.new(0,0,1,-1), z=6 })

local tabList = NewList(tabBar, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left,
    Enum.VerticalAlignment.Center, 0)
tabList.Parent = tabBar

--[[
    FIX: tabPages stores the PAGE FRAME (not the scroll).
    SetTab shows/hides the PAGE FRAME.
    Content helpers (CreateToggle etc.) receive the SCROLL FRAME via tabScrolls.
    Previously tabPages was overwritten with the scroll, so pg.Visible was
    being set on a ScrollingFrame (no visual effect) while the page Frame
    stayed permanently hidden.
]]
local tabScrolls = {}  -- scroll containers passed to content helpers

local function SetTab(tabName)
    for _, td in ipairs(TABS) do
        local pg  = tabPages[td.name]
        local btn = tabBtns[td.name]
        local on  = (td.name == tabName)
        if pg then
            pg.Visible = on
            if on then
                -- slide in from slightly below the final resting position
                pg.Position = UDim2.new(0, 0, 0, 98)
                tw(pg, TI.fast, { Position = UDim2.new(0, 0, 0, 90) })
            end
        end
        if btn then
            tw(btn, TI.fast, {
                BackgroundColor3 = on and td.color or C.surface,
                TextColor3       = on and C.white  or C.txt2,
            })
        end
    end
    activeTab = tabName
end

for _, td in ipairs(TABS) do
    local btn = NewBtn(tabBar, {
        bg    = C.surface,
        text  = td.icon.." "..td.name,
        color = C.txt2,
        size  = 9,
        font  = Enum.Font.GothamBold,
        sz    = UDim2.new(0, WIN_W / #TABS, 1, 0),
        z     = 6,
        name  = "Tab_"..td.name,
    })
    AddRipple(btn)
    btn.MouseButton1Click:Connect(function() SetTab(td.name) end)
    tabBtns[td.name] = btn

    -- FIX: page Frame is NOT transparent — it is the visible container.
    -- It sits below titleBar (z=5) and tabBar (z=5), so z=2 keeps it behind them.
    local page = NewFrame(win, {
        bg   = C.bg,      -- solid background, NOT trans=1
        trans= 0,
        size = UDim2.new(1, 0, 1, -90),   -- fills window below tab bar
        pos  = UDim2.new(0, 0, 0, 90),    -- starts right below tab bar (50+40)
        clip = true,
        z    = 2,         -- behind title/tab bars but above window bg
        name = "Page_"..td.name,
    })
    page.Visible = false
    tabPages[td.name] = page  -- FIX: store the Frame, not the scroll

    -- Scroll frame fills the page
    local scroll = Instance.new("ScrollingFrame")
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel        = 0
    scroll.Size                   = UDim2.new(1, 0, 1, 0)
    scroll.Position               = UDim2.new(0, 0, 0, 0)
    scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    scroll.ScrollBarThickness     = 3
    scroll.ScrollBarImageColor3   = C.accentDim
    scroll.ZIndex                 = 3
    scroll.Parent                 = page
    -- Left alignment so UDim2.new(1,-12,...) items stretch correctly.
    -- Padding of 6px each side gives 12px total margin matching the item offset.
    NewList(scroll, nil, Enum.HorizontalAlignment.Left, nil, 5)
    NewPadding(scroll, nil, 6, 6, 8, 8)

    tabScrolls[td.name] = scroll  -- content helpers use this
end

-- ════════════════════════════════════════════════════════
--  §8  POPULATE TABS
-- ════════════════════════════════════════════════════════

-- ── COMBAT ────────────────────────────────────────────
do
    local p = tabScrolls["Combat"]   -- FIX: use scroll container
    CreateDivider(p,   "Aim",            C.tabCombat)
    CreateToggle(p,    "Aimbot",         "Aimbot",     C.tabCombat)
    CreateToggle(p,    "Silent Aim",     "Silent",     C.tabCombat)
    CreateToggle(p,    "Team Check",     "TeamCheck",  C.accentDim)
    CreateSlider(p,    "FOV Radius",     "FOV",        30,  360)
    CreateSlider(p,    "Aim Smoothness", "Smooth",     10,  100, function(v) S.Smooth = v / 100 end)
    CreateDivider(p,   "Weapon",         C.tabCombat)
    CreateToggle(p,    "Hitbox+",        "Hitbox",     C.tabCombat)
    CreateToggle(p,    "No Recoil",      "NoRecoil",   C.tabCombat)
    CreateToggle(p,    "Auto Reload",    "AutoReload", C.tabCombat)
end

-- ── MOVEMENT ──────────────────────────────────────────
do
    local p = tabScrolls["Movement"]   -- FIX
    CreateDivider(p,   "Speed",          C.tabMove)
    CreateToggle(p,    "Speed Boost",    "SpeedBoost", C.tabMove)
    CreateSlider(p,    "Walk Speed",     "WalkSpeed",  10,  120)
    CreateSlider(p,    "Jump Power",     "JumpPower",  10,  200)
    CreateDivider(p,   "Fly",            C.tabMove)
    CreateToggle(p,    "Fly Mode",       "Fly",        C.tabMove)
    CreateSlider(p,    "Fly Speed",      "FlySpeed",   10,  200)
end

-- ── VISUALS ───────────────────────────────────────────
do
    local p = tabScrolls["Visuals"]   -- FIX
    CreateDivider(p,   "Players",        C.tabVisual)
    CreateToggle(p,    "Glow ESP",       "ESP",        C.tabVisual)
end

-- ── SETTINGS ──────────────────────────────────────────
do
    local p = tabScrolls["Settings"]   -- FIX
    CreateDivider(p,   "Keybinds",       C.tabSettings)
    CreateKeybind(p,   "Toggle Hub",     "ToggleKey")
    CreateDivider(p,   "Info",           C.tabSettings)
    local _, versionVal  = CreateInfo(p, "Version",  "v2.1 (team+dead fix)")
    local _, playerVal   = CreateInfo(p, "Player",   LP.Name)
    local _, fpsVal      = CreateInfo(p, "FPS",      "0")

    -- live FPS counter
    task.spawn(function()
        local frames, last = 0, os.clock()
        RunService.RenderStepped:Connect(function()
            frames += 1
            local now = os.clock()
            if now - last >= 1 then
                if fpsVal and fpsVal.Parent then fpsVal.Text = tostring(frames) end
                frames = 0; last = now
            end
        end)
    end)

    -- Unload button
    local unloadBtn = NewBtn(p, {
        bg    = Color3.fromRGB(180, 35, 35),
        text  = "⬛  UNLOAD SCRIPT",
        color = C.white,
        size  = 11,
        font  = Enum.Font.GothamBold,
        sz    = UDim2.new(1,-12,0,36),
        z     = 5,
        name  = "UnloadBtn",
    })
    NewCorner(unloadBtn, 9)
    NewStroke(unloadBtn, Color3.fromRGB(255,80,80), 1, 0.5)
    AddRipple(unloadBtn)
    unloadBtn.MouseEnter:Connect(function() tw(unloadBtn, TI.fast, { BackgroundColor3 = Color3.fromRGB(230,50,50) }) end)
    unloadBtn.MouseLeave:Connect(function() tw(unloadBtn, TI.fast, { BackgroundColor3 = Color3.fromRGB(180,35,35) }) end)
    -- FIX: Circle/Dot not yet declared here, so use a deferred callback
    unloadBtn.MouseButton1Click:Connect(function()
        S.Running = false
        -- safely remove drawings if they exist
        pcall(function() Circle:Remove() end)
        pcall(function() Dot:Remove() end)
        tw(win, TI.med, { BackgroundTransparency=1 })
        tw(shadow, TI.med, { BackgroundTransparency=1 })
        task.delay(0.3, function() sg:Destroy() end)
    end)
end

-- ════════════════════════════════════════════════════════
--  §9  DRAWING OBJECTS  (FOV circle + crosshair dot)
--  FIX: Declared BEFORE SetTab so unload button can reference them
-- ════════════════════════════════════════════════════════
local Circle = Drawing.new("Circle")
Circle.Thickness    = 1.5
Circle.Color        = Color3.fromRGB(0, 255, 150)
Circle.Visible      = false
Circle.Transparency = 1
Circle.Filled       = false
Circle.NumSides     = 64

local Dot = Drawing.new("Circle")
Dot.Radius      = 2
Dot.Thickness   = 1
Dot.Color       = Color3.fromRGB(255, 255, 255)
Dot.Filled      = true
Dot.Visible     = false

-- FIX: Open Combat tab AFTER all content populated + Drawing objects declared
SetTab("Combat")

-- ════════════════════════════════════════════════════════
--  §10  TOGGLE HUB VISIBILITY (keybind)
-- ════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(inp, processed)
    if processed then return end
    if inp.KeyCode == S.ToggleKey then
        win.Visible    = not win.Visible
        shadow.Visible = win.Visible
        if win.Visible then
            tw(win, TI.spring, { BackgroundTransparency = 0 })
        end
    end
end)

-- ════════════════════════════════════════════════════════
--  §11  FEATURE ENGINE  —  render loop
-- ════════════════════════════════════════════════════════
local Aiming = false
UserInputService.InputBegan:Connect(function(inp, p)
    if not p and inp.UserInputType == Enum.UserInputType.MouseButton2 then
        Aiming = true
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton2 then
        Aiming = false
    end
end)

RunService.RenderStepped:Connect(function()
    if not S.Running then return end

    local mid    = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
    local target = GetTarget()
    local char   = LP.Character
    local hum    = char and char:FindFirstChildWhichIsA("Humanoid")
    local hrp    = char and char:FindFirstChild("HumanoidRootPart")

    -- ── FOV Circle
    local showFOV = S.Aimbot or S.Silent
    Circle.Visible  = showFOV
    Dot.Visible     = showFOV
    Circle.Position = mid
    Dot.Position    = mid
    Circle.Radius   = GetScaledFOV()
    -- smoothly shift circle colour: green = no target, red = locked
    Circle.Color = target
        and Color3.fromRGB(255, 60, 60)
        or  Color3.fromRGB(0, 230, 140)

    -- ── Aim
    if Aiming and target then
        if S.Silent then
            Cam.CFrame = CFrame.new(Cam.CFrame.Position, target.Position)
        elseif S.Aimbot then
            Cam.CFrame = Cam.CFrame:Lerp(
                CFrame.new(Cam.CFrame.Position, target.Position), S.Smooth)
        end
    end

    -- ── Auto Reload
    if S.AutoReload and char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            local ammo = tool:FindFirstChild("Ammo")
            if ammo and ammo.Value == 0 then
                game:GetService("VirtualInputManager"):SendKeyEvent(
                    true, Enum.KeyCode.R, false, game)
            end
        end
    end

    -- ── Movement
    if hrp and hum then
        if S.Fly then
            local v = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then v += Cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then v -= Cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then v -= Cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then v += Cam.CFrame.RightVector end
            hrp.Velocity = v * S.FlySpeed + Vector3.new(0, 2, 0)
        elseif S.SpeedBoost then
            hum.WalkSpeed  = S.WalkSpeed
            hum.JumpPower  = S.JumpPower
        else
            hum.WalkSpeed  = 16
            hum.JumpPower  = 50
        end
    end

    -- ── Hitbox expansion (enemies + alive only — fixes dead body + team bug)
    if S.Hitbox then
        for _, v in ipairs(Players:GetPlayers()) do
            if IsEnemy(v) then
                local head = v.Character:FindFirstChild("Head")
                if head then
                    head.Size       = Vector3.new(3.5, 3.5, 3.5)
                    head.CanCollide = false
                end
            end
        end
    end
end)

-- ════════════════════════════════════════════════════════
--  §12  ESP MODULE
-- ════════════════════════════════════════════════════════
local function AddESP(player)
    --[[
        FIX [2] — ESP disappears when TeamCheck ON:
            Old code: h.Enabled = S.ESP and (not S.TeamCheck or player.Team ~= LP.Team)
            Bug:      When TeamCheck=true and player is ally → Enabled=false, correct.
                      But also when TeamCheck=true and player IS enemy → condition was
                      relying on broken team comparison (see IsEnemy fix), so allies
                      sometimes evaluated as enemies and vice versa.
            Fix:      Use IsEnemy() which handles nil-team edge case properly.
                      When TeamCheck=OFF  → show all living players (coloured by team).
                      When TeamCheck=ON   → show only living enemies.

        FIX [3] — Dead bodies highlighted:
            Rivals keeps the character model in workspace after death (ragdoll).
            Old code had no health check so the Highlight stayed on dead bodies.
            Fix: gate h.Enabled on IsAlive(player) every poll tick.
    --]]
    local function CreateHighlight()
        if not player.Character then return end

        -- Remove stale highlight from previous life if it exists
        local existing = player.Character:FindFirstChild("MH_ESP")
        if existing then existing:Destroy() end

        local h = Instance.new("Highlight")
        h.Name                = "MH_ESP"
        h.OutlineColor        = Color3.fromRGB(255, 255, 255)
        h.FillTransparency    = 0.5
        h.OutlineTransparency = 0
        h.Enabled             = false   -- start hidden, loop below decides
        h.Parent              = player.Character

        task.spawn(function()
            while h.Parent and S.Running do
                local alive   = IsAlive(player)       -- FIX [3]: skip dead bodies
                local isEnemy = IsEnemy(player)        -- FIX [2]: correct team logic

                if not S.ESP or not alive then
                    -- ESP off OR player is dead → always hide
                    h.Enabled = false
                elseif S.TeamCheck then
                    -- TeamCheck ON  → show only enemies
                    h.Enabled = isEnemy
                else
                    -- TeamCheck OFF → show everyone alive
                    h.Enabled = true
                end

                -- Colour: red = enemy, blue = teammate
                if h.Enabled then
                    h.FillColor = isEnemy
                        and Color3.fromRGB(220, 40,  40)
                        or  Color3.fromRGB(40,  120, 220)
                end

                task.wait(0.15)
            end
        end)
    end

    -- Re-create highlight on every respawn
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        CreateHighlight()
    end)
    CreateHighlight()
end

for _, v in ipairs(Players:GetPlayers()) do
    if v ~= LP then AddESP(v) end
end
Players.PlayerAdded:Connect(AddESP)

-- ════════════════════════════════════════════════════════
--  END OF MASTER HUB  v2.0
-- ════════════════════════════════════════════════════════
