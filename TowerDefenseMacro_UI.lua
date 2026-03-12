--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║        TOWER DEFENSE MACRO FRAMEWORK  —  PREMIUM UI EDITION                 ║
║        Compatible: All Star Tower Defense · Anime Guardians · similar       ║
╚══════════════════════════════════════════════════════════════════════════════╝
--]]

-- ─────────────────────────────────────────────────────────────────────────────
--  SERVICES
-- ─────────────────────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────────────────────────────────────────
--  CONFIG  (update remoteNames + guiPaths to match your game)
-- ─────────────────────────────────────────────────────────────────────────────
local CONFIG = {
    remoteSearchRoots = {
        ReplicatedStorage,
        game:GetService("Workspace"),
        LocalPlayer:WaitForChild("PlayerScripts"),
    },
    remoteNames = {
        place   = { "PlaceTower",   "placeTower",   "Place",   "TowerPlace"   },
        upgrade = { "UpgradeTower", "upgradeTower", "Upgrade", "TowerUpgrade" },
        ability = { "UseAbility",   "Ability",      "TowerAbility"            },
        sell    = { "SellTower",    "sellTower",    "Sell",    "TowerSell"    },
    },
    guiPaths = {
        wave  = { "PlayerGui.GameGui.WaveLabel",  "PlayerGui.Main.Wave"  },
        money = { "PlayerGui.GameGui.MoneyLabel", "PlayerGui.Main.Money" },
        timer = { "PlayerGui.GameGui.TimerLabel"                         },
    },
    rsPaths = {
        wave  = { "GameData.Wave",  "GameState.CurrentWave" },
        money = { "GameData.Money", "PlayerData.Money"      },
    },
    timeTolerance  = 0.5,
    minActionDelay = 0.1,
}

-- ─────────────────────────────────────────────────────────────────────────────
--  UTILITIES
-- ─────────────────────────────────────────────────────────────────────────────
local Util = {}

function Util.resolvePath(root, path)
    local obj = root
    for part in path:gmatch("[^%.]+") do
        if typeof(obj) ~= "Instance" then return nil end
        obj = obj:FindFirstChild(part)
        if not obj then return nil end
    end
    return obj
end

function Util.findFirst(roots, pathList)
    for _, pathStr in ipairs(pathList) do
        local obj = Util.resolvePath(game, pathStr)
        if obj then return obj end
        for _, root in ipairs(roots) do
            local rel = Util.resolvePath(root, pathStr)
            if rel then return rel end
        end
    end
    return nil
end

function Util.deepFindRemote(root, nameList)
    local nameSet = {}
    for _, n in ipairs(nameList) do nameSet[n:lower()] = true end
    local function recurse(inst)
        for _, child in ipairs(inst:GetChildren()) do
            if child:IsA("RemoteEvent") and nameSet[child.Name:lower()] then return child end
            local found = recurse(child)
            if found then return found end
        end
        return nil
    end
    return recurse(root)
end

local _idCounter = 0
function Util.newId()
    _idCounter += 1
    return string.format("T%05d_%d", _idCounter, os.clock() * 1000 % 100000 // 1)
end

function Util.parseNumber(text)
    if not text then return 0 end
    local s = tostring(text):gsub(",", ""):match("%-?%d+%.?%d*")
    return tonumber(s) or 0
end

function Util.readGuiNumber(inst)
    if not inst then return 0 end
    if inst:IsA("TextLabel") or inst:IsA("TextBox") then return Util.parseNumber(inst.Text) end
    return 0
end

function Util.vec3ToTable(v)  return { x = v.X, y = v.Y, z = v.Z } end
function Util.tableToVec3(t)  return Vector3.new(t.x or 0, t.y or 0, t.z or 0) end

function Util.deepCopy(v)
    if type(v) == "table" then
        local c = {}
        for k, val in pairs(v) do c[Util.deepCopy(k)] = Util.deepCopy(val) end
        return c
    end
    return v
end

-- ─────────────────────────────────────────────────────────────────────────────
--  REMOTE EVENT DETECTOR
-- ─────────────────────────────────────────────────────────────────────────────
local RemoteEventDetector = {}
RemoteEventDetector.__index = RemoteEventDetector

function RemoteEventDetector.new()
    local self = setmetatable({}, RemoteEventDetector)
    self.remotes   = {}
    self.hooks     = {}
    self.listeners = {}
    return self
end

function RemoteEventDetector:findRemote(actionType)
    local nameList = CONFIG.remoteNames[actionType] or {}
    for _, root in ipairs(CONFIG.remoteSearchRoots) do
        for _, name in ipairs(nameList) do
            local r = root:FindFirstChild(name, true)
            if r and r:IsA("RemoteEvent") then return r end
        end
        local found = Util.deepFindRemote(root, nameList)
        if found then return found end
    end
    return nil
end

function RemoteEventDetector:hookRemote(actionType, remote, callback)
    if not remote then return end
    local originalFireServer = remote.FireServer
    self.hooks[actionType]   = originalFireServer
    local mt = getrawmetatable and getrawmetatable(remote)
    if mt then
        local oldIndex = mt.__index
        setreadonly(mt, false)
        mt.__index = function(tbl, key)
            if key == "FireServer" then
                return function(self2, ...)
                    local args = { ... }
                    callback(actionType, tbl, args)
                    return originalFireServer(self2, table.unpack(args))
                end
            end
            return oldIndex(tbl, key)
        end
        setreadonly(mt, true)
    else
        warn("[MacroFramework] getrawmetatable unavailable — Studio-safe mode only.")
    end
    self.remotes[actionType] = remote
end

function RemoteEventDetector:onAction(actionType, callback)
    if not self.listeners[actionType] then self.listeners[actionType] = {} end
    table.insert(self.listeners[actionType], callback)
end

function RemoteEventDetector:_dispatch(actionType, remote, args)
    local list = self.listeners[actionType]
    if not list then return end
    for _, cb in ipairs(list) do task.spawn(cb, actionType, remote, args) end
end

function RemoteEventDetector:init()
    for actionType in pairs(CONFIG.remoteNames) do
        local remote = self:findRemote(actionType)
        if remote then
            self:hookRemote(actionType, remote, function(aType, rem, args)
                self:_dispatch(aType, rem, args)
            end)
        else
            warn(string.format("[RemoteEventDetector] Remote not found for '%s'", actionType))
        end
    end
end

function RemoteEventDetector:getRemote(actionType)
    return self.remotes[actionType]
end

-- ─────────────────────────────────────────────────────────────────────────────
--  GAME STATE TRACKER
-- ─────────────────────────────────────────────────────────────────────────────
local GameTracker = {}
GameTracker.__index = GameTracker

function GameTracker.new()
    local self     = setmetatable({}, GameTracker)
    self.wave      = 0
    self.money     = 0
    self.gameTime  = 0
    self._start    = os.clock()
    self._cache    = {}
    self._conn     = nil
    return self
end

function GameTracker:_getLabel(key)
    if self._cache[key] then return self._cache[key] end
    local paths = CONFIG.guiPaths[key]
    if paths then
        local inst = Util.findFirst({ game }, paths)
        if inst then self._cache[key] = inst; return inst end
    end
    return nil
end

function GameTracker:readWave()
    local label = self:_getLabel("wave")
    if label then local n = Util.readGuiNumber(label); if n > 0 then self.wave = n; return n end end
    for _, path in ipairs(CONFIG.rsPaths.wave or {}) do
        local obj = Util.resolvePath(game, path)
        if obj then self.wave = obj.Value; return obj.Value end
    end
    return self.wave
end

function GameTracker:readMoney()
    local label = self:_getLabel("money")
    if label then local n = Util.readGuiNumber(label); if n >= 0 then self.money = n; return n end end
    for _, path in ipairs(CONFIG.rsPaths.money or {}) do
        local obj = Util.resolvePath(game, path)
        if obj then self.money = obj.Value; return obj.Value end
    end
    return self.money
end

function GameTracker:readTime()
    local label = self:_getLabel("timer")
    if label then local n = Util.readGuiNumber(label); if n > 0 then self.gameTime = n; return n end end
    self.gameTime = os.clock() - self._start
    return self.gameTime
end

function GameTracker:snapshot()
    return { wave = self:readWave(), money = self:readMoney(), gameTime = self:readTime() }
end

function GameTracker:startPolling()
    if self._conn then return end
    local lastTick = 0
    self._conn = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - lastTick < 0.5 then return end
        lastTick = now
        self:readWave(); self:readMoney(); self:readTime()
    end)
end

function GameTracker:stopPolling()
    if self._conn then self._conn:Disconnect(); self._conn = nil end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  PLACEMENT DETECTOR
-- ─────────────────────────────────────────────────────────────────────────────
local PlacementDetector = {}
PlacementDetector.__index = PlacementDetector

function PlacementDetector.new()
    local self = setmetatable({}, PlacementDetector)
    self.activeTowers = {}
    return self
end

function PlacementDetector:extractPosition(args)
    for _, arg in ipairs(args) do
        if typeof(arg) == "Vector3" then return arg end
        if typeof(arg) == "CFrame"  then return arg.Position end
    end
    if #args >= 3 and type(args[1])=="number" and type(args[2])=="number" and type(args[3])=="number" then
        return Vector3.new(args[1], args[2], args[3])
    end
    return nil
end

function PlacementDetector:extractSlot(args)
    for i = #args, 1, -1 do
        if type(args[i])=="number" and args[i]==math.floor(args[i]) and args[i]>=1 and args[i]<=10 then
            return args[i]
        end
    end
    return nil
end

function PlacementDetector:extractTowerModel(args)
    for _, arg in ipairs(args) do
        if typeof(arg)=="Instance" and arg:IsA("Model") then return arg end
    end
    return nil
end

function PlacementDetector:registerTower(position, slot, model)
    local uid = Util.newId()
    self.activeTowers[uid] = { uid=uid, position=position, slot=slot, model=model, placedAt=os.clock() }
    return uid
end

function PlacementDetector:findNearestTower(pos, maxDist)
    maxDist = maxDist or 3
    local best, bestDist = nil, maxDist
    for uid, data in pairs(self.activeTowers) do
        local d = (data.position - pos).Magnitude
        if d < bestDist then best=uid; bestDist=d end
    end
    return best
end

function PlacementDetector:removeTower(uid) self.activeTowers[uid] = nil end

-- ─────────────────────────────────────────────────────────────────────────────
--  MACRO RECORDER
-- ─────────────────────────────────────────────────────────────────────────────
local MacroRecorder = {}
MacroRecorder.__index = MacroRecorder

function MacroRecorder.new(detector, tracker, placementDet)
    local self = setmetatable({}, MacroRecorder)
    self.detector  = detector
    self.tracker   = tracker
    self.placement = placementDet
    self.recording = false
    self.macro     = {}
    return self
end

function MacroRecorder:_buildRecord(actionType, args)
    local state    = self.tracker:snapshot()
    local position = self.placement:extractPosition(args)
    local slot     = self.placement:extractSlot(args)
    local safeArgs = {}
    for _, v in ipairs(args) do
        if typeof(v)=="Vector3" then
            table.insert(safeArgs, { __type="Vector3", data=Util.vec3ToTable(v) })
        elseif typeof(v)=="CFrame" then
            local p, r = v.Position, { v:ToEulerAnglesXYZ() }
            table.insert(safeArgs, { __type="CFrame", pos=Util.vec3ToTable(p), rx=r[1], ry=r[2], rz=r[3] })
        elseif typeof(v)=="Instance" then
            table.insert(safeArgs, { __type="Instance", name=v.Name, path=v:GetFullName() })
        else
            table.insert(safeArgs, v)
        end
    end
    local record = {
        action     = actionType,
        wave       = state.wave,
        time       = state.gameTime,
        money      = state.money,
        slot       = slot,
        unit       = nil,
        towerUID   = nil,
        position   = position and Util.vec3ToTable(position) or nil,
        remoteArgs = safeArgs,
    }
    if actionType=="place" and position then
        local model = self.placement:extractTowerModel(args)
        local uid   = self.placement:registerTower(position, slot, model)
        record.towerUID = uid
        if model then record.unit = model.Name end
    elseif (actionType=="upgrade" or actionType=="ability" or actionType=="sell") and position then
        record.towerUID = self.placement:findNearestTower(position)
        if actionType=="sell" and record.towerUID then
            self.placement:removeTower(record.towerUID)
        end
    end
    return record
end

function MacroRecorder:startRecording()
    if self.recording then return end
    self.recording = true
    self.macro     = {}
    for _, actionType in ipairs({ "place","upgrade","ability","sell" }) do
        self.detector:onAction(actionType, function(aType, remote, args)
            if not self.recording then return end
            local record = self:_buildRecord(aType, args)
            table.insert(self.macro, record)
        end)
    end
end

function MacroRecorder:stopRecording()
    self.recording = false
    return self.macro
end

function MacroRecorder:getMacro()   return Util.deepCopy(self.macro) end
function MacroRecorder:setMacro(m)  self.macro = m end

-- ─────────────────────────────────────────────────────────────────────────────
--  MACRO PLAYER
-- ─────────────────────────────────────────────────────────────────────────────
local MacroPlayer = {}
MacroPlayer.__index = MacroPlayer

function MacroPlayer.new(detector, tracker)
    local self = setmetatable({}, MacroPlayer)
    self.detector = detector
    self.tracker  = tracker
    self.playing  = false
    self._thread  = nil
    return self
end

local function deserialiseArgs(safeArgs)
    local out = {}
    for _, v in ipairs(safeArgs) do
        if type(v)=="table" then
            if v.__type=="Vector3" then
                table.insert(out, Util.tableToVec3(v.data))
            elseif v.__type=="CFrame" then
                local p = Util.tableToVec3(v.pos)
                table.insert(out, CFrame.new(p) * CFrame.fromEulerAnglesXYZ(v.rx, v.ry, v.rz))
            elseif v.__type=="Instance" then
                local inst = game:FindFirstChild(v.path, true) or Util.resolvePath(game, v.path)
                if inst then table.insert(out, inst) end
            else
                table.insert(out, v)
            end
        else
            table.insert(out, v)
        end
    end
    return out
end

function MacroPlayer:_executeAction(record)
    local remote = self.detector:getRemote(record.action)
    if not remote then return end
    local args = deserialiseArgs(record.remoteArgs or {})
    remote:FireServer(table.unpack(args))
end

function MacroPlayer:playMacro(macro, onProgress)
    if self.playing then return end
    if not macro or #macro==0 then return end
    self.playing = true
    self._thread = task.spawn(function()
        for i, record in ipairs(macro) do
            if not self.playing then break end
            -- wait for wave
            if record.wave and record.wave > 0 then
                local dl = os.clock() + 300
                while self.tracker:readWave() < record.wave and os.clock() < dl do task.wait(0.25) end
            end
            -- wait for time
            if record.time and record.time > 0 then
                local dl = os.clock() + 60
                while os.clock() < dl do
                    local t = self.tracker:readTime()
                    if math.abs(t - record.time) <= CONFIG.timeTolerance then break end
                    if t > record.time + CONFIG.timeTolerance then break end
                    task.wait(0.05)
                end
            end
            self:_executeAction(record)
            if onProgress then onProgress(i, #macro, record) end
            task.wait(CONFIG.minActionDelay)
        end
        self.playing = false
        if onProgress then onProgress(#macro, #macro, nil) end
    end)
end

function MacroPlayer:stopPlayback()
    self.playing = false
    if self._thread then task.cancel(self._thread); self._thread = nil end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  STORAGE
-- ─────────────────────────────────────────────────────────────────────────────
local MacroStorage = {}
local SAVE_FILENAME = "TDMacro_save.json"

function MacroStorage.save(macro)
    local ok, jsonStr = pcall(function() return HttpService:JSONEncode(macro) end)
    if not ok then warn("[MacroStorage] Encode failed: "..tostring(jsonStr)); return false end
    if writefile then
        local wok, err = pcall(writefile, SAVE_FILENAME, jsonStr)
        if wok then return true else warn("[MacroStorage] writefile error: "..tostring(err)) end
    else
        print("[MacroStorage] Copy JSON:\n"..jsonStr)
        return true
    end
    return false
end

function MacroStorage.load()
    if readfile then
        local ok, content = pcall(readfile, SAVE_FILENAME)
        if not ok or not content or content=="" then return nil end
        local dok, macro = pcall(function() return HttpService:JSONDecode(content) end)
        if dok and type(macro)=="table" then return macro end
    else
        warn("[MacroStorage] readfile unavailable.")
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
--  PREMIUM UI
--  Design language: dark glass morphism, electric cyan/violet accents,
--  animated scanlines, pill-shaped status badges, live action log.
-- ─────────────────────────────────────────────────────────────────────────────
local UI = {}

-- ── Colour palette ──────────────────────────────────────────────────────────
local C = {
    bg          = Color3.fromRGB(8,  10, 18),
    surface     = Color3.fromRGB(14, 18, 32),
    surfaceHigh = Color3.fromRGB(20, 26, 46),
    border      = Color3.fromRGB(40, 55, 100),
    accent      = Color3.fromRGB(82, 196, 255),    -- electric cyan
    accentDim   = Color3.fromRGB(40, 110, 160),
    danger      = Color3.fromRGB(255, 80,  80),
    success     = Color3.fromRGB(80,  230, 130),
    warning     = Color3.fromRGB(255, 190, 60),
    violet      = Color3.fromRGB(160, 80,  255),
    textPrimary = Color3.fromRGB(220, 235, 255),
    textSecond  = Color3.fromRGB(120, 145, 190),
    textDim     = Color3.fromRGB(60,  75,  110),
    white       = Color3.fromRGB(255, 255, 255),
    black       = Color3.fromRGB(0,   0,   0),
}

local TI_FAST   = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TI_MED    = TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TI_SLOW   = TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TI_SPRING = TweenInfo.new(0.45, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)

-- ── Helper: create a UICorner ────────────────────────────────────────────────
local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

-- ── Helper: create a UIStroke ───────────────────────────────────────────────
local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color        = color or C.border
    s.Thickness    = thickness or 1
    s.Transparency = transparency or 0
    s.Parent       = parent
    return s
end

-- ── Helper: tween a property ────────────────────────────────────────────────
local function tween(inst, info, props)
    TweenService:Create(inst, info, props):Play()
end

-- ── Helper: make a Frame ────────────────────────────────────────────────────
local function frame(parent, props)
    local f = Instance.new("Frame")
    f.BackgroundColor3   = props.bg    or C.surface
    f.BackgroundTransparency = props.trans or 0
    f.BorderSizePixel    = 0
    f.Size               = props.size  or UDim2.new(0,100,0,100)
    f.Position           = props.pos   or UDim2.new(0,0,0,0)
    f.ZIndex             = props.z     or 1
    f.Name               = props.name  or "Frame"
    if props.clip ~= nil then f.ClipsDescendants = props.clip end
    f.Parent             = parent
    return f
end

-- ── Helper: make a TextLabel ─────────────────────────────────────────────────
local function label(parent, props)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.BorderSizePixel        = 0
    t.Text                   = props.text  or ""
    t.TextColor3             = props.color or C.textPrimary
    t.TextSize               = props.size  or 13
    t.Font                   = props.font  or Enum.Font.GothamBold
    t.RichText               = props.rich  or false
    t.TextXAlignment         = props.xalign or Enum.TextXAlignment.Left
    t.TextYAlignment         = props.yalign or Enum.TextYAlignment.Center
    t.TextWrapped            = props.wrap  or false
    t.Size                   = props.sz    or UDim2.new(1,0,0,20)
    t.Position               = props.upos  or UDim2.new(0,0,0,0)
    t.ZIndex                 = props.z     or 2
    t.Name                   = props.name  or "Label"
    t.Parent                 = parent
    return t
end

-- ── Helper: make a TextButton ────────────────────────────────────────────────
local function button(parent, props)
    local b = Instance.new("TextButton")
    b.BackgroundColor3       = props.bg    or C.accentDim
    b.BackgroundTransparency = props.trans or 0
    b.BorderSizePixel        = 0
    b.Text                   = props.text  or ""
    b.TextColor3             = props.color or C.white
    b.TextSize               = props.size  or 13
    b.Font                   = props.font  or Enum.Font.GothamBold
    b.AutoButtonColor        = false
    b.Size                   = props.sz    or UDim2.new(0,80,0,30)
    b.Position               = props.upos  or UDim2.new(0,0,0,0)
    b.ZIndex                 = props.z     or 3
    b.Name                   = props.name  or "Button"
    b.Parent                 = parent
    return b
end

-- ── Helper: hover effect for buttons ────────────────────────────────────────
local function addHover(btn, normalBg, hoverBg)
    btn.MouseEnter:Connect(function()
        tween(btn, TI_FAST, { BackgroundColor3 = hoverBg })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, TI_FAST, { BackgroundColor3 = normalBg })
    end)
    btn.MouseButton1Down:Connect(function()
        tween(btn, TI_FAST, { BackgroundColor3 = normalBg })
    end)
end

-- ── Helper: animated glow line (scanline) ───────────────────────────────────
local function addScanline(parent)
    local scan = frame(parent, {
        bg   = C.accent,
        trans= 0.82,
        size = UDim2.new(1,0,0,1),
        pos  = UDim2.new(0,0,0,0),
        z    = 10,
        name = "Scanline",
    })
    local function animScan()
        scan.Position = UDim2.new(0,0,0,0)
        tween(scan, TweenInfo.new(2.5, Enum.EasingStyle.Linear), { Position = UDim2.new(0,0,1,-1) })
    end
    animScan()
    task.spawn(function()
        while true do task.wait(2.5); animScan() end
    end)
    return scan
end

-- ── Helper: pulsing dot ──────────────────────────────────────────────────────
local function pulsingDot(parent, color, size, pos)
    local dot = frame(parent, { bg=color, size=UDim2.new(0,size,0,size), pos=pos, z=5, name="Dot" })
    corner(dot, size//2)
    local function pulse()
        tween(dot, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.6 })
    end
    pulse()
    return dot
end

-- ── Main build ───────────────────────────────────────────────────────────────
function UI.build(recorder, player, storage)
    -- Root ScreenGui
    local sg = Instance.new("ScreenGui")
    sg.Name            = "MacroPremiumUI"
    sg.ResetOnSpawn    = false
    sg.DisplayOrder    = 999
    sg.IgnoreGuiInset  = true
    sg.Parent          = PlayerGui

    -- ── Draggable main window ─────────────────────────────────────────────
    local WIN_W, WIN_H = 420, 520
    local win = frame(sg, {
        bg   = C.bg,
        size = UDim2.new(0, WIN_W, 0, WIN_H),
        pos  = UDim2.new(0.5, -(WIN_W//2), 0.5, -(WIN_H//2)),
        name = "Window",
        clip = false,
    })
    corner(win, 14)
    stroke(win, C.border, 1.5)
    addScanline(win)

    -- ambient glow behind window
    local glow = frame(sg, {
        bg   = C.accentDim,
        trans= 0.88,
        size = UDim2.new(0, WIN_W+60, 0, WIN_H+60),
        pos  = UDim2.new(0.5, -(WIN_W//2+30), 0.5, -(WIN_H//2+30)),
        z    = 0,
        name = "Glow",
    })
    corner(glow, 24)

    -- entrance animation
    win.BackgroundTransparency = 1
    win.Position = UDim2.new(0.5, -(WIN_W//2), 0.5, -(WIN_H//2) + 30)
    tween(win, TI_SPRING, {
        BackgroundTransparency = 0,
        Position = UDim2.new(0.5, -(WIN_W//2), 0.5, -(WIN_H//2))
    })

    -- ── Title bar ─────────────────────────────────────────────────────────
    local titleBar = frame(win, {
        bg   = C.surfaceHigh,
        size = UDim2.new(1,0,0,48),
        pos  = UDim2.new(0,0,0,0),
        name = "TitleBar",
    })
    corner(titleBar, 14)
    -- cover bottom corners of titleBar
    local tbCover = frame(titleBar, {
        bg   = C.surfaceHigh,
        size = UDim2.new(1,0,0,14),
        pos  = UDim2.new(0,0,1,-14),
        name = "Cover",
    })

    -- accent bar on left edge of title
    local accent_bar = frame(titleBar, {
        bg   = C.accent,
        size = UDim2.new(0,3,0,26),
        pos  = UDim2.new(0,14,0.5,-13),
        name = "AccentBar",
    })
    corner(accent_bar, 2)

    -- title text
    label(titleBar, {
        text  = "MACRO SYSTEM",
        color = C.white,
        size  = 15,
        font  = Enum.Font.GothamBold,
        sz    = UDim2.new(0,200,0,48),
        upos  = UDim2.new(0,26,0,0),
        z     = 4,
        name  = "Title",
    })
    label(titleBar, {
        text  = "Tower Defense · v2.0",
        color = C.textSecond,
        size  = 10,
        font  = Enum.Font.Gotham,
        sz    = UDim2.new(0,200,0,48),
        upos  = UDim2.new(0,26,0,16),
        z     = 4,
        name  = "Sub",
    })

    -- Close button
    local closeBtn = button(titleBar, {
        bg    = Color3.fromRGB(255,60,60),
        text  = "✕",
        color = C.white,
        size  = 13,
        sz    = UDim2.new(0,22,0,22),
        upos  = UDim2.new(1,-34,0.5,-11),
        z     = 5,
        name  = "Close",
    })
    corner(closeBtn, 6)
    addHover(closeBtn, Color3.fromRGB(255,60,60), Color3.fromRGB(255,100,100))
    closeBtn.MouseButton1Click:Connect(function()
        tween(win, TI_MED, { BackgroundTransparency=1, Position=UDim2.new(0.5,-(WIN_W//2),0.5,-(WIN_H//2)+30) })
        tween(glow, TI_MED, { BackgroundTransparency=1 })
        task.delay(0.35, function() sg:Destroy() end)
    end)

    -- Minimise button
    local minBtn = button(titleBar, {
        bg    = Color3.fromRGB(255,180,30),
        text  = "−",
        color = C.white,
        size  = 15,
        sz    = UDim2.new(0,22,0,22),
        upos  = UDim2.new(1,-60,0.5,-11),
        z     = 5,
        name  = "Minimize",
    })
    corner(minBtn, 6)
    addHover(minBtn, Color3.fromRGB(255,180,30), Color3.fromRGB(255,210,80))
    local minimised = false
    minBtn.MouseButton1Click:Connect(function()
        minimised = not minimised
        if minimised then
            tween(win, TI_MED, { Size = UDim2.new(0, WIN_W, 0, 48) })
        else
            tween(win, TI_MED, { Size = UDim2.new(0, WIN_W, 0, WIN_H) })
        end
    end)

    -- ── Drag logic ────────────────────────────────────────────────────────
    do
        local dragging, dragStart, startPos = false, nil, nil
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging  = true
                dragStart = input.Position
                startPos  = win.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                          or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                win.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    -- ── Content area ──────────────────────────────────────────────────────
    local content = frame(win, {
        bg   = C.bg,
        trans= 1,
        size = UDim2.new(1,-24,1,-60),
        pos  = UDim2.new(0,12,0,54),
        name = "Content",
        clip = true,
    })

    -- ── Status bar (Wave / Time / Money) ─────────────────────────────────
    local statusBar = frame(content, {
        bg   = C.surfaceHigh,
        size = UDim2.new(1,0,0,44),
        pos  = UDim2.new(0,0,0,0),
        name = "StatusBar",
    })
    corner(statusBar, 10)
    stroke(statusBar, C.border, 1)

    local statLayout = Instance.new("UIListLayout")
    statLayout.FillDirection  = Enum.FillDirection.Horizontal
    statLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    statLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
    statLayout.Padding        = UDim.new(0,0)
    statLayout.Parent         = statusBar

    local function statChip(icon, valName, color)
        local chip = frame(statusBar, {
            bg   = C.bg,
            trans= 1,
            size = UDim2.new(0, 130, 1, 0),
            name = valName.."Chip",
        })
        local sep = frame(chip, {
            bg   = C.border,
            size = UDim2.new(0,1,0.6,0),
            pos  = UDim2.new(1,-1,0.2,0),
        })
        local ico = label(chip, {
            text  = icon,
            color = color,
            size  = 14,
            font  = Enum.Font.GothamBold,
            sz    = UDim2.new(0,22,1,0),
            upos  = UDim2.new(0,10,0,0),
            xalign= Enum.TextXAlignment.Center,
            z     = 3,
        })
        local lbl = label(chip, {
            text  = "0",
            color = C.textPrimary,
            size  = 13,
            font  = Enum.Font.GothamBold,
            sz    = UDim2.new(1,-36,1,0),
            upos  = UDim2.new(0,34,0,0),
            z     = 3,
            name  = valName.."Val",
        })
        return lbl
    end

    local waveLabel  = statChip("⚡", "Wave",  C.accent)
    local timeLabel  = statChip("⏱", "Time",  C.violet)
    local moneyLabel = statChip("💰", "Money", C.success)

    -- ── State badge ────────────────────────────────────────────────────────
    local badgeRow = frame(content, {
        bg   = C.bg,
        trans= 1,
        size = UDim2.new(1,0,0,36),
        pos  = UDim2.new(0,0,0,52),
        name = "BadgeRow",
    })

    local badge = frame(badgeRow, {
        bg   = C.surfaceHigh,
        size = UDim2.new(0,120,0,28),
        pos  = UDim2.new(0,0,0.5,-14),
        name = "StateBadge",
    })
    corner(badge, 14)
    stroke(badge, C.accentDim, 1)
    local bDot = pulsingDot(badge, C.textDim, 8, UDim2.new(0,10,0.5,-4))
    local bLabel = label(badge, {
        text  = "IDLE",
        color = C.textSecond,
        size  = 11,
        font  = Enum.Font.GothamBold,
        sz    = UDim2.new(1,-28,1,0),
        upos  = UDim2.new(0,24,0,0),
        xalign= Enum.TextXAlignment.Left,
        z     = 4,
    })

    -- action count chip
    local countChip = frame(badgeRow, {
        bg   = C.surfaceHigh,
        size = UDim2.new(0,150,0,28),
        pos  = UDim2.new(0,128,0.5,-14),
        name = "CountChip",
    })
    corner(countChip, 14)
    stroke(countChip, C.border, 1)
    local countLabel = label(countChip, {
        text   = "0 actions recorded",
        color  = C.textSecond,
        size   = 11,
        font   = Enum.Font.Gotham,
        sz     = UDim2.new(1,0,1,0),
        xalign = Enum.TextXAlignment.Center,
        z      = 4,
    })

    -- ── Control buttons ────────────────────────────────────────────────────
    local btnRow = frame(content, {
        bg   = C.bg,
        trans= 1,
        size = UDim2.new(1,0,0,42),
        pos  = UDim2.new(0,0,0,96),
        name = "BtnRow",
    })

    local BTN_DEFS = {
        { name="RecBtn",  text="● REC",   bg=Color3.fromRGB(200,40,40),  hover=Color3.fromRGB(255,70,70),  key="F6" },
        { name="StopBtn", text="■ STOP",  bg=Color3.fromRGB(50,60,90),   hover=Color3.fromRGB(80,95,140),  key="F7" },
        { name="PlayBtn", text="▶ PLAY",  bg=Color3.fromRGB(30,130,80),  hover=Color3.fromRGB(50,190,110), key="F8" },
        { name="SaveBtn", text="⬇ SAVE",  bg=Color3.fromRGB(60,60,110),  hover=Color3.fromRGB(90,90,160),  key="F9" },
        { name="LoadBtn", text="⬆ LOAD",  bg=Color3.fromRGB(60,60,110),  hover=Color3.fromRGB(90,90,160),  key="F10"},
    }

    local btnRefs = {}
    local BW = (WIN_W - 24) / #BTN_DEFS - 4
    for i, def in ipairs(BTN_DEFS) do
        local xOff = (i-1) * (BW + 4)
        local btn_ = button(btnRow, {
            bg    = def.bg,
            text  = def.text,
            color = C.white,
            size  = 11,
            font  = Enum.Font.GothamBold,
            sz    = UDim2.new(0, BW, 0, 38),
            upos  = UDim2.new(0, xOff, 0, 0),
            z     = 4,
            name  = def.name,
        })
        corner(btn_, 9)
        stroke(btn_, Color3.fromRGB(255,255,255), 1, 0.88)
        addHover(btn_, def.bg, def.hover)
        -- small keybind hint
        label(btn_, {
            text  = def.key,
            color = Color3.fromRGB(255,255,255),
            size  = 8,
            font  = Enum.Font.Code,
            sz    = UDim2.new(1,0,0,12),
            upos  = UDim2.new(0,0,1,-12),
            xalign= Enum.TextXAlignment.Center,
            z     = 5,
            name  = "KeyHint",
        }).BackgroundTransparency = 1
        btnRefs[def.name] = btn_
    end

    -- ── Progress bar ───────────────────────────────────────────────────────
    local progTrack = frame(content, {
        bg   = C.surfaceHigh,
        size = UDim2.new(1,0,0,6),
        pos  = UDim2.new(0,0,0,146),
        name = "ProgressTrack",
    })
    corner(progTrack, 3)
    local progFill = frame(progTrack, {
        bg   = C.accent,
        size = UDim2.new(0,0,1,0),
        pos  = UDim2.new(0,0,0,0),
        name = "Fill",
    })
    corner(progFill, 3)
    local progLabel = label(content, {
        text  = "Ready",
        color = C.textDim,
        size  = 10,
        font  = Enum.Font.Code,
        sz    = UDim2.new(1,0,0,14),
        upos  = UDim2.new(0,0,0,156),
        xalign= Enum.TextXAlignment.Right,
        z     = 4,
        name  = "ProgressLabel",
    })

    -- ── Step delay slider ──────────────────────────────────────────────────
    local sliderSection = frame(content, {
        bg   = C.surfaceHigh,
        size = UDim2.new(1,0,0,46),
        pos  = UDim2.new(0,0,0,178),
        name = "SliderSection",
    })
    corner(sliderSection, 10)
    stroke(sliderSection, C.border, 1)

    label(sliderSection, {
        text  = "Step Delay",
        color = C.textSecond,
        size  = 11,
        font  = Enum.Font.Gotham,
        sz    = UDim2.new(0,80,1,0),
        upos  = UDim2.new(0,12,0,0),
        z     = 4,
    })

    local delayVal = label(sliderSection, {
        text  = "0.10s",
        color = C.accent,
        size  = 11,
        font  = Enum.Font.GothamBold,
        sz    = UDim2.new(0,50,1,0),
        upos  = UDim2.new(1,-62,0,0),
        xalign= Enum.TextXAlignment.Right,
        z     = 4,
    })

    local sliderTrack = frame(sliderSection, {
        bg   = C.bg,
        size = UDim2.new(1,-160,0,4),
        pos  = UDim2.new(0,96,0.5,-2),
        name = "SliderTrack",
    })
    corner(sliderTrack, 2)
    local sliderFill = frame(sliderTrack, {
        bg   = C.accent,
        size = UDim2.new(0.1,0,1,0),
        pos  = UDim2.new(0,0,0,0),
        name = "Fill",
    })
    corner(sliderFill, 2)
    local sliderThumb = frame(sliderTrack, {
        bg   = C.white,
        size = UDim2.new(0,12,0,12),
        pos  = UDim2.new(0.1,-6,0.5,-6),
        z    = 5,
        name = "Thumb",
    })
    corner(sliderThumb, 6)

    -- slider drag
    do
        local DELAY_MIN, DELAY_MAX = 0.05, 2.0
        local draggingSlider = false
        sliderThumb.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = true end
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = false end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if not draggingSlider then return end
            if inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local trackAbs = sliderTrack.AbsolutePosition
            local trackW   = sliderTrack.AbsoluteSize.X
            local relX     = math.clamp((inp.Position.X - trackAbs.X) / trackW, 0, 1)
            sliderFill.Size     = UDim2.new(relX, 0, 1, 0)
            sliderThumb.Position= UDim2.new(relX, -6, 0.5, -6)
            local delay = DELAY_MIN + relX * (DELAY_MAX - DELAY_MIN)
            CONFIG.minActionDelay = delay
            delayVal.Text = string.format("%.2fs", delay)
        end)
    end

    -- ── Action log ─────────────────────────────────────────────────────────
    local logHeader = frame(content, {
        bg   = C.bg,
        trans= 1,
        size = UDim2.new(1,0,0,22),
        pos  = UDim2.new(0,0,0,232),
        name = "LogHeader",
    })
    label(logHeader, {
        text  = "ACTION LOG",
        color = C.accentDim,
        size  = 10,
        font  = Enum.Font.GothamBold,
        sz    = UDim2.new(1,0,1,0),
        xalign= Enum.TextXAlignment.Left,
        z     = 3,
    })
    local logLine = frame(logHeader, {
        bg   = C.accentDim,
        size = UDim2.new(1,0,0,1),
        pos  = UDim2.new(0,0,1,-1),
    })

    local logScroll = Instance.new("ScrollingFrame")
    logScroll.BackgroundColor3       = C.surfaceHigh
    logScroll.BackgroundTransparency = 0
    logScroll.BorderSizePixel        = 0
    logScroll.Size                   = UDim2.new(1,0,0,180)
    logScroll.Position               = UDim2.new(0,0,0,258)
    logScroll.ScrollBarThickness     = 3
    logScroll.ScrollBarImageColor3   = C.accentDim
    logScroll.CanvasSize             = UDim2.new(0,0,0,0)
    logScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    logScroll.ZIndex                 = 3
    logScroll.Name                   = "LogScroll"
    logScroll.Parent                 = content
    corner(logScroll, 10)
    stroke(logScroll, C.border, 1)

    local logLayout = Instance.new("UIListLayout")
    logLayout.FillDirection  = Enum.FillDirection.Vertical
    logLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    logLayout.Padding        = UDim.new(0,1)
    logLayout.SortOrder      = Enum.SortOrder.LayoutOrder
    logLayout.Parent         = logScroll

    local logPad = Instance.new("UIPadding")
    logPad.PaddingLeft   = UDim.new(0,8)
    logPad.PaddingRight  = UDim.new(0,8)
    logPad.PaddingTop    = UDim.new(0,4)
    logPad.PaddingBottom = UDim.new(0,4)
    logPad.Parent        = logScroll

    local logCount = 0
    local MAX_LOG  = 80

    local ACTION_COLORS = {
        place   = C.success,
        upgrade = C.accent,
        ability = C.violet,
        sell    = C.warning,
        system  = C.textSecond,
        error   = C.danger,
    }
    local ACTION_ICONS = {
        place   = "⬛",
        upgrade = "⬆",
        ability = "✦",
        sell    = "💲",
        system  = "◈",
        error   = "✖",
    }

    local function addLog(actionType, message)
        logCount += 1
        -- prune oldest if over limit
        if logCount > MAX_LOG then
            local oldest = logScroll:FindFirstChildWhichIsA("Frame")
            if oldest then oldest:Destroy() end
            logCount -= 1
        end

        local color = ACTION_COLORS[actionType] or C.textSecond
        local icon  = ACTION_ICONS[actionType]  or "·"

        local row = frame(logScroll, {
            bg   = logCount%2==0 and C.surfaceHigh or Color3.fromRGB(16,21,38),
            size = UDim2.new(1,0,0,22),
            z    = 4,
            name = "LogRow"..logCount,
        })
        row.LayoutOrder = logCount
        -- fade in
        row.BackgroundTransparency = 1
        tween(row, TI_FAST, { BackgroundTransparency = logCount%2==0 and 0 or 0 })

        label(row, {
            text  = icon.." "..string.upper(actionType),
            color = color,
            size  = 10,
            font  = Enum.Font.GothamBold,
            sz    = UDim2.new(0,70,1,0),
            upos  = UDim2.new(0,0,0,0),
            xalign= Enum.TextXAlignment.Left,
            z     = 5,
        })
        label(row, {
            text  = message,
            color = C.textSecond,
            size  = 10,
            font  = Enum.Font.Code,
            sz    = UDim2.new(1,-76,1,0),
            upos  = UDim2.new(0,76,0,0),
            xalign= Enum.TextXAlignment.Left,
            wrap  = false,
            z     = 5,
        })

        -- auto-scroll to bottom
        task.defer(function()
            logScroll.CanvasPosition = Vector2.new(0, logScroll.AbsoluteCanvasSize.Y)
        end)
    end

    -- ── State helpers ─────────────────────────────────────────────────────
    local function setBadge(text, color, dotColor)
        bLabel.Text      = text
        bLabel.TextColor3= color or C.textSecond
        bDot.BackgroundColor3 = dotColor or C.textDim
    end

    local function setProgress(frac, text)
        tween(progFill, TI_MED, { Size = UDim2.new(math.clamp(frac,0,1), 0, 1, 0) })
        if text then progLabel.Text = text end
    end

    -- live stat update loop
    task.spawn(function()
        while sg.Parent do
            local state = Framework and Framework.tracker:snapshot()
            if state then
                waveLabel.Text  = "Wave "..tostring(state.wave)
                timeLabel.Text  = string.format("%.0fs", state.gameTime)
                moneyLabel.Text = tostring(state.money)
            end
            countLabel.Text = #recorder.macro.." actions"
            task.wait(0.4)
        end
    end)

    -- ── Wire buttons ──────────────────────────────────────────────────────
    btnRefs["RecBtn"].MouseButton1Click:Connect(function()
        if player.playing then addLog("error","Stop playback first"); return end
        recorder:startRecording()
        setBadge("● REC", C.danger, C.danger)
        addLog("system", "Recording started")
        setProgress(0, "Recording…")
    end)

    btnRefs["StopBtn"].MouseButton1Click:Connect(function()
        if recorder.recording then
            local m = recorder:stopRecording()
            setBadge("IDLE", C.textSecond, C.textDim)
            addLog("system", string.format("Stopped — %d actions captured", #m))
            setProgress(0, "Ready")
        elseif player.playing then
            player:stopPlayback()
            setBadge("IDLE", C.textSecond, C.textDim)
            addLog("system", "Playback aborted by user")
            setProgress(0, "Stopped")
        end
    end)

    btnRefs["PlayBtn"].MouseButton1Click:Connect(function()
        local macro = recorder:getMacro()
        if #macro==0 then addLog("error","No macro — record or load first"); return end
        player:playMacro(macro, function(i, total, record)
            local frac = i / total
            setProgress(frac, string.format("Step %d / %d", i, total))
            if record then
                addLog(record.action, string.format(
                    "w=%d t=%.1fs slot=%s",
                    record.wave or 0, record.time or 0, tostring(record.slot)
                ))
            else
                setBadge("IDLE", C.textSecond, C.textDim)
                setProgress(1, "Playback complete ✓")
                addLog("system", "Playback finished")
            end
        end)
        setBadge("▶ PLAYING", C.success, C.success)
        addLog("system", string.format("Playback started — %d actions", #macro))
    end)

    btnRefs["SaveBtn"].MouseButton1Click:Connect(function()
        local ok = storage.save(recorder:getMacro())
        if ok then
            addLog("system", "Macro saved → TDMacro_save.json")
            setBadge("SAVED ✓", C.success, C.success)
            task.delay(2, function() if not recorder.recording then setBadge("IDLE",C.textSecond,C.textDim) end end)
        else
            addLog("error", "Save failed — see console")
        end
    end)

    btnRefs["LoadBtn"].MouseButton1Click:Connect(function()
        local macro = storage.load()
        if macro then
            recorder:setMacro(macro)
            addLog("system", string.format("Loaded %d actions from file", #macro))
            setBadge("LOADED ✓", C.accent, C.accent)
            task.delay(2, function() setBadge("IDLE",C.textSecond,C.textDim) end)
        else
            addLog("error", "Load failed — file not found")
        end
    end)

    -- ── Keyboard shortcuts ────────────────────────────────────────────────
    local keyBinds = {
        [Enum.KeyCode.F6]  = function() btnRefs["RecBtn"]:GetPropertyChangedSignal("Text") btnRefs["RecBtn"].MouseButton1Click:Fire() end,
        [Enum.KeyCode.F7]  = function() btnRefs["StopBtn"].MouseButton1Click:Fire() end,
        [Enum.KeyCode.F8]  = function() btnRefs["PlayBtn"].MouseButton1Click:Fire() end,
        [Enum.KeyCode.F9]  = function() btnRefs["SaveBtn"].MouseButton1Click:Fire() end,
        [Enum.KeyCode.F10] = function() btnRefs["LoadBtn"].MouseButton1Click:Fire() end,
    }
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        local fn = keyBinds[input.KeyCode]
        if fn then task.spawn(fn) end
    end)

    -- ── Expose log function so other modules can push messages ────────────
    UI.log = addLog

    addLog("system", "Framework initialised — ready")

    return sg
end

-- ─────────────────────────────────────────────────────────────────────────────
--  BOOTSTRAP
-- ─────────────────────────────────────────────────────────────────────────────
local function init()
    local detector  = RemoteEventDetector.new()
    local tracker   = GameTracker.new()
    local placement = PlacementDetector.new()
    local recorder  = MacroRecorder.new(detector, tracker, placement)
    local player    = MacroPlayer.new(detector, tracker)

    detector:init()
    tracker:startPolling()

    Framework = {
        detector  = detector,
        tracker   = tracker,
        placement = placement,
        recorder  = recorder,
        player    = player,
        storage   = MacroStorage,
    }

    UI.build(recorder, player, MacroStorage)

    -- Hook recorder actions into UI log
    for _, aType in ipairs({"place","upgrade","ability","sell"}) do
        detector:onAction(aType, function(actionType, _, args)
            if not recorder.recording then return end
            local pos = placement:extractPosition(args)
            local posStr = pos and string.format("(%.0f,%.0f,%.0f)", pos.X,pos.Y,pos.Z) or "?"
            if UI.log then
                UI.log(actionType, string.format("pos=%s slot=%s", posStr,
                    tostring(placement:extractSlot(args))))
            end
        end)
    end

    return Framework
end

Framework = init()
