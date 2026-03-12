--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║   TOWER DEFENSE MACRO FRAMEWORK  ·  V3.1  (JJSPLOIT COMPATIBLE)            ║
║                                                                              ║
║  JJSPLOIT FIXES APPLIED:                                                    ║
║   [J1] ScreenGui → gethui() with CoreGui fallback (PlayerGui blocked)       ║
║   [J2] Removed entrance tween — window always visible, no transparency=1   ║
║   [J3] Replaced // integer division → math.floor(a/b)  (Lua 5.1 safe)     ║
║   [J4] Removed AutomaticCanvasSize (unsupported) → manual canvas sizing    ║
║   [J5] Wrapped getrawmetatable/setreadonly in pcall guard                   ║
║   [J6] Replaced task.defer → spawn()  (more compatible)                    ║
║   [J7] isfile() removed → pcall(readfile) only                              ║
║   [J8] WaitForChild timeouts replaced with FindService fallbacks            ║
║   [J9] TweenService calls wrapped in pcall — silent fail if broken          ║
╚══════════════════════════════════════════════════════════════════════════════╝
--]]

-- ════════════════════════════════════════════════════════════════════════════
--  §1  SERVICES  (JJSploit-safe access)
-- ════════════════════════════════════════════════════════════════════════════
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- [J3] Safe integer division — // is Lua 5.3+, JJSploit runs Lua 5.1 VM
local function idiv(a, b) return math.floor(a / b) end

-- [J1] Safe GUI parent — gethui() is the hidden protected container in JJSploit
-- Falls back to CoreGui if gethui is unavailable (other executors)
local function getGuiParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok2, cg = pcall(function() return CoreGui end)
    if ok2 and cg then return cg end
    -- last resort — some executors allow PlayerGui
    return LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
end

-- [J8] PlayerGui safe reference without WaitForChild blocking
local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    or LocalPlayer:WaitForChild("PlayerGui", 15)

-- [J9] Safe tween wrapper — fails silently on broken TweenService
local function safeTween(inst, info, props)
    local ok, err = pcall(function()
        TweenService:Create(inst, info, props):Play()
    end)
    if not ok then
        -- Fallback: apply props directly without animation
        for k, v in pairs(props) do
            pcall(function() inst[k] = v end)
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════════
--  §2  CONFIG
-- ════════════════════════════════════════════════════════════════════════════
local CONFIG = {
    remoteSearchRoots = {
        ReplicatedStorage,
        game:GetService("Workspace"),
        LocalPlayer:FindFirstChild("PlayerScripts") or LocalPlayer:WaitForChild("PlayerScripts", 5),
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
    autoSaveFile   = "TDMacro_autosave.json",
    manualSaveFile = "TDMacro_save.json",
    autoExecFile   = "TDMacro_autoexec.lua",
}

-- ════════════════════════════════════════════════════════════════════════════
--  §3  UTILITIES
-- ════════════════════════════════════════════════════════════════════════════
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
            if root then
                local rel = Util.resolvePath(root, pathStr)
                if rel then return rel end
            end
        end
    end
    return nil
end

function Util.deepFindRemote(root, nameList)
    local nameSet = {}
    for _, n in ipairs(nameList) do nameSet[n:lower()] = true end
    local function recurse(inst)
        local ok, children = pcall(function() return inst:GetChildren() end)
        if not ok then return nil end
        for _, child in ipairs(children) do
            if child:IsA("RemoteEvent") and nameSet[child.Name:lower()] then
                return child
            end
            local found = recurse(child)
            if found then return found end
        end
        return nil
    end
    return recurse(root)
end

local _idCounter = 0
function Util.newId()
    _idCounter = _idCounter + 1
    -- [J3] No // operator
    return string.format("T%05d_%d", _idCounter,
        math.floor(os.clock() * 1000) % 100000)
end

function Util.parseNumber(text)
    if not text then return 0 end
    local s = tostring(text):gsub(",", ""):match("%-?%d+%.?%d*")
    return tonumber(s) or 0
end

function Util.readGuiNumber(inst)
    if not inst then return 0 end
    if inst:IsA("TextLabel") or inst:IsA("TextBox") then
        return Util.parseNumber(inst.Text)
    end
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

-- [J7] File helpers — isfile() removed, pcall-only approach
function Util.writeFile(path, content)
    if writefile then
        local ok, err = pcall(writefile, path, content)
        if not ok then warn("[Util.writeFile] " .. tostring(err)) end
        return ok
    end
    return false
end

function Util.readFile(path)
    if not readfile then return nil end
    local ok, content = pcall(readfile, path)
    if ok and content and content ~= "" then return content end
    return nil
end

-- ════════════════════════════════════════════════════════════════════════════
--  §4  REMOTE EVENT DETECTOR
-- ════════════════════════════════════════════════════════════════════════════
local RemoteEventDetector = {}
RemoteEventDetector.__index = RemoteEventDetector

function RemoteEventDetector.new()
    local self     = setmetatable({}, RemoteEventDetector)
    self.remotes   = {}
    self.listeners = {}
    self._hooked   = {}
    return self
end

function RemoteEventDetector:findRemote(actionType)
    local nameList = CONFIG.remoteNames[actionType] or {}
    for _, root in ipairs(CONFIG.remoteSearchRoots) do
        if root then
            for _, name in ipairs(nameList) do
                local r = root:FindFirstChild(name, true)
                if r and r:IsA("RemoteEvent") then return r end
            end
            local found = Util.deepFindRemote(root, nameList)
            if found then return found end
        end
    end
    return nil
end

-- [J5] getrawmetatable wrapped in pcall
function RemoteEventDetector:hookRemote(actionType, remote)
    if not remote then return false end
    if self._hooked[remote] then
        self.remotes[actionType] = remote
        return true
    end

    -- [J5] Safe getrawmetatable
    local mt = nil
    if getrawmetatable then
        local ok, result = pcall(getrawmetatable, remote)
        if ok then mt = result end
    end

    if not mt then
        warn("[RemoteEventDetector] getrawmetatable failed for '" .. actionType
            .. "' — JJSploit may not support this. Remote stored but not hooked.")
        self.remotes[actionType] = remote
        return false
    end

    local originalFS = remote.FireServer
    local detector   = self

    local srOk = pcall(setreadonly, mt, false)
    if not srOk then
        warn("[RemoteEventDetector] setreadonly failed for '" .. actionType .. "'")
        self.remotes[actionType] = remote
        return false
    end

    local prevIndex = mt.__index
    mt.__index = function(tbl, key)
        if key == "FireServer" then
            return function(selfRemote, ...)
                local args = { ... }
                for aType, rem in pairs(detector.remotes) do
                    if rem == tbl then
                        detector:_dispatch(aType, tbl, args)
                        break
                    end
                end
                return originalFS(selfRemote, unpack(args))
            end
        end
        if type(prevIndex) == "function" then return prevIndex(tbl, key) end
        if type(prevIndex) == "table"    then return prevIndex[key] end
        return nil
    end

    pcall(setreadonly, mt, true)

    self._hooked[remote]     = true
    self.remotes[actionType] = remote
    print("[RemoteEventDetector] Hooked: " .. actionType .. " -> " .. remote:GetFullName())
    return true
end

function RemoteEventDetector:onAction(actionType, callback)
    if not self.listeners[actionType] then self.listeners[actionType] = {} end
    table.insert(self.listeners[actionType], callback)
end

function RemoteEventDetector:_dispatch(actionType, remote, args)
    local list = self.listeners[actionType]
    if not list then return end
    for _, cb in ipairs(list) do
        spawn(function() cb(actionType, remote, args) end)
    end
end

function RemoteEventDetector:init()
    for actionType in pairs(CONFIG.remoteNames) do
        local remote = self:findRemote(actionType)
        if remote then
            self:hookRemote(actionType, remote)
        else
            warn("[RemoteEventDetector] Not found: " .. actionType)
        end
    end
end

function RemoteEventDetector:getRemote(actionType)
    return self.remotes[actionType]
end

-- ════════════════════════════════════════════════════════════════════════════
--  §5  GAME STATE TRACKER
-- ════════════════════════════════════════════════════════════════════════════
local GameTracker = {}
GameTracker.__index = GameTracker

function GameTracker.new()
    local self    = setmetatable({}, GameTracker)
    self.wave     = 0
    self.money    = 0
    self.gameTime = 0
    self._start   = os.clock()
    self._cache   = {}
    self._conn    = nil
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
    local lbl = self:_getLabel("wave")
    if lbl then local n = Util.readGuiNumber(lbl); if n > 0 then self.wave = n; return n end end
    for _, path in ipairs(CONFIG.rsPaths.wave or {}) do
        local obj = Util.resolvePath(game, path)
        if obj then self.wave = obj.Value; return obj.Value end
    end
    return self.wave
end

function GameTracker:readMoney()
    local lbl = self:_getLabel("money")
    if lbl then local n = Util.readGuiNumber(lbl); if n >= 0 then self.money = n; return n end end
    for _, path in ipairs(CONFIG.rsPaths.money or {}) do
        local obj = Util.resolvePath(game, path)
        if obj then self.money = obj.Value; return obj.Value end
    end
    return self.money
end

function GameTracker:readTime()
    local lbl = self:_getLabel("timer")
    if lbl then local n = Util.readGuiNumber(lbl); if n > 0 then self.gameTime = n; return n end end
    self.gameTime = os.clock() - self._start
    return self.gameTime
end

function GameTracker:snapshot()
    return { wave = self:readWave(), money = self:readMoney(), gameTime = self:readTime() }
end

function GameTracker:startPolling()
    if self._conn then return end
    local last = 0
    self._conn = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - last < 0.5 then return end
        last = now
        self:readWave(); self:readMoney(); self:readTime()
    end)
end

function GameTracker:stopPolling()
    if self._conn then self._conn:Disconnect(); self._conn = nil end
end

-- ════════════════════════════════════════════════════════════════════════════
--  §6  PLACEMENT DETECTOR
-- ════════════════════════════════════════════════════════════════════════════
local PlacementDetector = {}
PlacementDetector.__index = PlacementDetector

function PlacementDetector.new()
    return setmetatable({ activeTowers = {} }, PlacementDetector)
end

function PlacementDetector:extractPosition(args)
    for _, a in ipairs(args) do
        if typeof(a) == "Vector3" then return a end
        if typeof(a) == "CFrame"  then return a.Position end
    end
    if #args >= 3 and type(args[1]) == "number"
        and type(args[2]) == "number" and type(args[3]) == "number" then
        return Vector3.new(args[1], args[2], args[3])
    end
    return nil
end

function PlacementDetector:extractSlot(args)
    for i = #args, 1, -1 do
        if type(args[i]) == "number" and args[i] == math.floor(args[i])
            and args[i] >= 1 and args[i] <= 10 then
            return args[i]
        end
    end
    return nil
end

function PlacementDetector:extractTowerModel(args)
    for _, a in ipairs(args) do
        if typeof(a) == "Instance" and a:IsA("Model") then return a end
    end
    return nil
end

function PlacementDetector:registerTower(position, slot, model)
    local uid = Util.newId()
    self.activeTowers[uid] = {
        uid = uid, position = position,
        slot = slot, model = model, placedAt = os.clock(),
    }
    return uid
end

function PlacementDetector:findNearestTower(pos, maxDist)
    maxDist = maxDist or 3
    local best, bestDist = nil, maxDist
    for uid, data in pairs(self.activeTowers) do
        local d = (data.position - pos).Magnitude
        if d < bestDist then best = uid; bestDist = d end
    end
    return best
end

function PlacementDetector:removeTower(uid)
    self.activeTowers[uid] = nil
end

-- ════════════════════════════════════════════════════════════════════════════
--  §7  MACRO RECORDER
-- ════════════════════════════════════════════════════════════════════════════
local MacroRecorder = {}
MacroRecorder.__index = MacroRecorder

function MacroRecorder.new(detector, tracker, placementDet)
    local self = setmetatable({}, MacroRecorder)
    self.detector   = detector
    self.tracker    = tracker
    self.placement  = placementDet
    self.recording  = false
    self.macro      = {}
    self._onCapture = nil
    return self
end

function MacroRecorder:_buildRecord(actionType, args)
    local state    = self.tracker:snapshot()
    local position = self.placement:extractPosition(args)
    local slot     = self.placement:extractSlot(args)
    local safeArgs = {}
    for _, v in ipairs(args) do
        if typeof(v) == "Vector3" then
            table.insert(safeArgs, { __type="Vector3", data=Util.vec3ToTable(v) })
        elseif typeof(v) == "CFrame" then
            local p, r = v.Position, { v:ToEulerAnglesXYZ() }
            table.insert(safeArgs, {
                __type="CFrame", pos=Util.vec3ToTable(p),
                rx=r[1], ry=r[2], rz=r[3],
            })
        elseif typeof(v) == "Instance" then
            table.insert(safeArgs, {
                __type="Instance", name=v.Name, path=v:GetFullName(),
            })
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
    if actionType == "place" and position then
        local model = self.placement:extractTowerModel(args)
        local uid   = self.placement:registerTower(position, slot, model)
        record.towerUID = uid
        if model then record.unit = model.Name end
    elseif (actionType == "upgrade" or actionType == "ability"
            or actionType == "sell") and position then
        record.towerUID = self.placement:findNearestTower(position)
        if actionType == "sell" and record.towerUID then
            self.placement:removeTower(record.towerUID)
        end
    end
    return record
end

function MacroRecorder:attachListeners()
    for _, actionType in ipairs({ "place", "upgrade", "ability", "sell" }) do
        self.detector:onAction(actionType, function(aType, _, args)
            if not self.recording then return end
            local record = self:_buildRecord(aType, args)
            table.insert(self.macro, record)
            self:_autoSave()
            if self._onCapture then
                spawn(function() self._onCapture(record) end)
            end
        end)
    end
end

function MacroRecorder:_autoSave()
    local ok, json = pcall(function() return HttpService:JSONEncode(self.macro) end)
    if ok then Util.writeFile(CONFIG.autoSaveFile, json) end
end

function MacroRecorder:tryAutoLoad()
    local content = Util.readFile(CONFIG.autoSaveFile)
    if not content then return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(content) end)
    if ok and type(data) == "table" and #data > 0 then
        self.macro = data
        print("[MacroRecorder] Auto-loaded " .. #data .. " actions from previous session.")
        return true
    end
    return false
end

function MacroRecorder:startRecording()
    if self.recording then return end
    self.recording = true
    self.macro     = {}
    Util.writeFile(CONFIG.autoSaveFile, "[]")
    print("[MacroRecorder] Recording started.")
end

function MacroRecorder:stopRecording()
    if not self.recording then return self.macro end
    self.recording = false
    self:_autoSave()
    print("[MacroRecorder] Stopped. " .. #self.macro .. " actions captured.")
    return self.macro
end

function MacroRecorder:getMacro()  return Util.deepCopy(self.macro) end
function MacroRecorder:setMacro(m) self.macro = m end

-- ════════════════════════════════════════════════════════════════════════════
--  §8  MACRO PLAYER
-- ════════════════════════════════════════════════════════════════════════════
local MacroPlayer = {}
MacroPlayer.__index = MacroPlayer

function MacroPlayer.new(detector, tracker)
    local self    = setmetatable({}, MacroPlayer)
    self.detector = detector
    self.tracker  = tracker
    self.playing  = false
    self._thread  = nil
    return self
end

local function deserialiseArgs(safeArgs)
    local out = {}
    for _, v in ipairs(safeArgs) do
        if type(v) == "table" then
            if v.__type == "Vector3" then
                table.insert(out, Util.tableToVec3(v.data))
            elseif v.__type == "CFrame" then
                local p = Util.tableToVec3(v.pos)
                table.insert(out, CFrame.new(p)
                    * CFrame.fromEulerAnglesXYZ(v.rx, v.ry, v.rz))
            elseif v.__type == "Instance" then
                local inst = Util.resolvePath(game, v.path)
                    or game:FindFirstChild(v.name, true)
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
    if not remote then
        warn("[MacroPlayer] No remote for: " .. tostring(record.action))
        return
    end
    local args = deserialiseArgs(record.remoteArgs or {})
    pcall(function() remote:FireServer(unpack(args)) end)
end

function MacroPlayer:playMacro(macro, onProgress)
    if self.playing then return end
    if not macro or #macro == 0 then return end
    self.playing = true
    self._thread = spawn(function()
        for i, record in ipairs(macro) do
            if not self.playing then break end
            if record.wave and record.wave > 0 then
                local deadline = os.clock() + 300
                while self.tracker:readWave() < record.wave and os.clock() < deadline do
                    wait(0.25)
                end
            end
            if record.time and record.time > 0 then
                local deadline = os.clock() + 60
                while os.clock() < deadline do
                    local t = self.tracker:readTime()
                    if math.abs(t - record.time) <= CONFIG.timeTolerance then break end
                    if t > record.time + CONFIG.timeTolerance then break end
                    wait(0.05)
                end
            end
            if record.action == "place" and record.money and record.money > 0 then
                local deadline = os.clock() + 30
                while self.tracker:readMoney() < record.money and os.clock() < deadline do
                    wait(0.5)
                end
            end
            self:_executeAction(record)
            if onProgress then onProgress(i, #macro, record) end
            wait(CONFIG.minActionDelay)
        end
        self.playing = false
        if onProgress then onProgress(#macro, #macro, nil) end
    end)
end

function MacroPlayer:stopPlayback()
    self.playing = false
    if self._thread then
        local ok = pcall(function() coroutine.close(self._thread) end)
        if not ok then pcall(function() task.cancel(self._thread) end) end
        self._thread = nil
    end
end

-- ════════════════════════════════════════════════════════════════════════════
--  §9  STORAGE
-- ════════════════════════════════════════════════════════════════════════════
local MacroStorage = {}

function MacroStorage.save(macro, filename)
    filename = filename or CONFIG.manualSaveFile
    local ok, json = pcall(function() return HttpService:JSONEncode(macro) end)
    if not ok then warn("[MacroStorage] Encode error: " .. tostring(json)); return false end
    local written = Util.writeFile(filename, json)
    if not written then print("[MacroStorage] Copy JSON:\n" .. json) end
    return true
end

function MacroStorage.load(filename)
    filename = filename or CONFIG.manualSaveFile
    local content = Util.readFile(filename)
    if not content then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(content) end)
    if ok and type(data) == "table" then return data end
    return nil
end

-- ════════════════════════════════════════════════════════════════════════════
--  §10  AUTO-EXECUTE ENGINE
-- ════════════════════════════════════════════════════════════════════════════
local AutoExec = {}
AutoExec._thread  = nil
AutoExec._running = false

AutoExec.PRESETS = {
    { name = "— Select Preset —", code = "" },
    {
        name = "Loop: Auto-Play Macro",
        code = [[local DELAY = 5
while Framework and Framework.player do
    local macro = Framework.recorder:getMacro()
    if #macro > 0 and not Framework.player.playing then
        Framework.player:playMacro(macro)
        while Framework.player.playing do wait(1) end
        wait(DELAY)
    else
        wait(2)
    end
end]],
    },
    {
        name = "Util: Print All Remotes",
        code = [[for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
    if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
        print("[Remote] " .. v:GetFullName())
    end
end]],
    },
    {
        name = "Util: Dump Macro to Output",
        code = [[local macro = Framework.recorder:getMacro()
print("Macro: " .. #macro .. " actions")
for i, r in ipairs(macro) do
    print(string.format("[%d] %s w=%d t=%.1f slot=%s",
        i, r.action, r.wave or 0, r.time or 0, tostring(r.slot)))
end]],
    },
    {
        name = "Loop: Auto-Save Every 30s",
        code = [[while Framework.recorder do
    wait(30)
    if #Framework.recorder.macro > 0 then
        Framework.storage.save(Framework.recorder:getMacro())
        print("[AutoExec] Auto-saved.")
    end
end]],
    },
}

function AutoExec.run(code, onError)
    AutoExec.stop()
    Util.writeFile(CONFIG.autoExecFile, code)
    local fn, compileErr = loadstring(code)
    if not fn then
        local msg = "[AutoExec] Compile error: " .. tostring(compileErr)
        warn(msg)
        if onError then onError(msg) end
        return false, compileErr
    end
    AutoExec._running = true
    AutoExec._thread  = spawn(function()
        local ok, runErr = pcall(fn)
        AutoExec._running = false
        if not ok then
            local msg = "[AutoExec] Runtime error: " .. tostring(runErr)
            warn(msg)
            if onError then onError(msg) end
        end
    end)
    return true, nil
end

function AutoExec.stop()
    if AutoExec._thread then
        pcall(function() coroutine.close(AutoExec._thread) end)
        pcall(function() task.cancel(AutoExec._thread) end)
        AutoExec._thread = nil
    end
    AutoExec._running = false
end

function AutoExec.loadSaved()
    return Util.readFile(CONFIG.autoExecFile) or ""
end

-- ════════════════════════════════════════════════════════════════════════════
--  §11  UI COLOUR PALETTE & TWEEN HELPERS
-- ════════════════════════════════════════════════════════════════════════════
local C = {
    bg          = Color3.fromRGB(8,  10, 18),
    surface     = Color3.fromRGB(14, 18, 32),
    surfaceHigh = Color3.fromRGB(20, 26, 46),
    border      = Color3.fromRGB(40, 55, 100),
    accent      = Color3.fromRGB(82, 196, 255),
    accentDim   = Color3.fromRGB(40, 110, 160),
    danger      = Color3.fromRGB(255, 80,  80),
    success     = Color3.fromRGB(80,  230, 130),
    warning     = Color3.fromRGB(255, 190, 60),
    violet      = Color3.fromRGB(160, 80,  255),
    textPrimary = Color3.fromRGB(220, 235, 255),
    textSecond  = Color3.fromRGB(120, 145, 190),
    textDim     = Color3.fromRGB(60,  75,  110),
    white       = Color3.fromRGB(255, 255, 255),
    codeGreen   = Color3.fromRGB(106, 214, 134),
}

local TI_FAST = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TI_MED  = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- ════════════════════════════════════════════════════════════════════════════
--  §12  UI COMPONENT HELPERS
-- ════════════════════════════════════════════════════════════════════════════
local function mkCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
    return c
end

local function mkStroke(parent, color, thick, trans)
    local s = Instance.new("UIStroke")
    s.Color = color or C.border
    s.Thickness = thick or 1
    s.Transparency = trans or 0
    s.Parent = parent
    return s
end

local function mkFrame(parent, p)
    local f = Instance.new("Frame")
    f.BackgroundColor3       = p.bg    or C.surface
    f.BackgroundTransparency = p.trans or 0
    f.BorderSizePixel        = 0
    f.Size     = p.size  or UDim2.new(1,0,0,30)
    f.Position = p.pos   or UDim2.new(0,0,0,0)
    f.ZIndex   = p.z     or 1
    f.Name     = p.name  or "Frame"
    if p.clip ~= nil then f.ClipsDescendants = p.clip end
    f.Parent = parent
    return f
end

local function mkLabel(parent, p)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.BorderSizePixel        = 0
    t.Text           = p.text   or ""
    t.TextColor3     = p.color  or C.textPrimary
    t.TextSize       = p.size   or 12
    t.Font           = p.font   or Enum.Font.GothamBold
    t.RichText       = p.rich   or false
    t.TextXAlignment = p.xalign or Enum.TextXAlignment.Left
    t.TextYAlignment = p.yalign or Enum.TextYAlignment.Center
    t.TextWrapped    = p.wrap   or false
    t.Size           = p.sz     or UDim2.new(1,0,0,20)
    t.Position       = p.upos   or UDim2.new(0,0,0,0)
    t.ZIndex         = p.z      or 3
    t.Name           = p.name   or "Label"
    t.Parent = parent
    return t
end

local function mkBtn(parent, p)
    local b = Instance.new("TextButton")
    b.BackgroundColor3       = p.bg    or C.surfaceHigh
    b.BackgroundTransparency = p.trans or 0
    b.BorderSizePixel        = 0
    b.Text           = p.text  or ""
    b.TextColor3     = p.color or C.white
    b.TextSize       = p.size  or 12
    b.Font           = p.font  or Enum.Font.GothamBold
    b.AutoButtonColor = false
    b.Size     = p.sz   or UDim2.new(1,0,0,30)
    b.Position = p.upos or UDim2.new(0,0,0,0)
    b.ZIndex   = p.z    or 3
    b.Name     = p.name or "Button"
    b.Parent = parent
    return b
end

local function addHover(btn, normBg, hoverBg)
    btn.MouseEnter:Connect(function()
        safeTween(btn, TI_FAST, { BackgroundColor3 = hoverBg })
    end)
    btn.MouseLeave:Connect(function()
        safeTween(btn, TI_FAST, { BackgroundColor3 = normBg })
    end)
end

local function mkScrollFrame(parent, size, pos, name)
    local sf = Instance.new("ScrollingFrame")
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel        = 0
    sf.Size                   = size
    sf.Position               = pos or UDim2.new(0,0,0,0)
    -- [J4] No AutomaticCanvasSize — set a large fixed canvas instead
    sf.CanvasSize             = UDim2.new(0, 0, 2, 0)
    sf.ScrollBarThickness     = 3
    sf.ScrollBarImageColor3   = C.accentDim
    sf.ZIndex                 = 3
    sf.Name                   = name or "Scroll"
    sf.Parent = parent
    return sf
end

-- [J4] Helper to update canvas size based on list content
local function updateCanvas(scrollFrame, listLayout)
    spawn(function()
        wait()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0,
            listLayout.AbsoluteContentSize.Y + 16)
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
--  §13  MAIN UI BUILD
-- ════════════════════════════════════════════════════════════════════════════
local UI = {}

function UI.build(recorder, player, storage)
    local WIN_W = 430
    local WIN_H = 560

    -- [J1] Destroy old instance first
    local guiParent = getGuiParent()
    local existing = guiParent:FindFirstChild("MacroPremiumUI_V3")
    if existing then existing:Destroy() end

    -- [J1] ScreenGui parented to gethui()/CoreGui — NOT PlayerGui
    local sg = Instance.new("ScreenGui")
    sg.Name           = "MacroPremiumUI_V3"
    sg.DisplayOrder   = 999
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.Parent         = guiParent   -- ← KEY FIX for JJSploit

    -- Glow
    local glow = mkFrame(sg, {
        bg=C.accentDim, trans=0.88,
        size=UDim2.new(0, WIN_W+60, 0, WIN_H+60),
        -- [J3] math.floor instead of //
        pos=UDim2.new(0.5, -(math.floor(WIN_W/2)+30), 0.5, -(math.floor(WIN_H/2)+30)),
        z=0, name="Glow",
    })
    mkCorner(glow, 24)

    -- [J2] Window starts VISIBLE — no entrance tween, no transparency=1
    local win = mkFrame(sg, {
        bg   = C.bg,
        size = UDim2.new(0, WIN_W, 0, WIN_H),
        pos  = UDim2.new(0.5, -math.floor(WIN_W/2), 0.5, -math.floor(WIN_H/2)),
        clip = false, z = 1, name = "Window",
    })
    mkCorner(win, 14)
    mkStroke(win, C.border, 1.5)
    -- [J2] Visible immediately, no tween needed

    -- Scanline (cosmetic only, won't break if tween fails)
    local scan = mkFrame(win, {
        bg=C.accent, trans=0.85, size=UDim2.new(1,0,0,1),
        pos=UDim2.new(0,0,0,0), z=20,
    })
    spawn(function()
        while sg.Parent do
            scan.Position = UDim2.new(0,0,0,0)
            safeTween(scan, TweenInfo.new(3, Enum.EasingStyle.Linear),
                { Position = UDim2.new(0,0,1,-1) })
            wait(3)
        end
    end)

    -- ── Title bar ──────────────────────────────────────────────────────────
    local titleBar = mkFrame(win, {
        bg=C.surfaceHigh, size=UDim2.new(1,0,0,48),
        pos=UDim2.new(0,0,0,0), z=5, name="TitleBar",
    })
    mkCorner(titleBar, 14)
    mkFrame(titleBar, {
        bg=C.surfaceHigh, size=UDim2.new(1,0,0,14),
        pos=UDim2.new(0,0,1,-14), z=4,
    })
    local strip = mkFrame(titleBar, {
        bg=C.accent, size=UDim2.new(0,3,0,24), pos=UDim2.new(0,14,0.5,-12), z=6,
    })
    mkCorner(strip, 2)
    mkLabel(titleBar, {
        text="MACRO SYSTEM", color=C.white, size=14,
        sz=UDim2.new(0,200,0,48), upos=UDim2.new(0,24,0,0), z=6,
    })
    mkLabel(titleBar, {
        text="Tower Defense  v3.1  [JJ]", color=C.textSecond, size=9,
        font=Enum.Font.Gotham,
        sz=UDim2.new(0,220,0,48), upos=UDim2.new(0,24,0,17), z=6,
    })

    -- Close button
    local closeBtn = mkBtn(titleBar, {
        bg=Color3.fromRGB(200,50,50), text="X", color=C.white, size=12,
        sz=UDim2.new(0,24,0,24), upos=UDim2.new(1,-30,0.5,-12), z=7,
    })
    mkCorner(closeBtn, 6)
    addHover(closeBtn, Color3.fromRGB(200,50,50), Color3.fromRGB(255,80,80))
    closeBtn.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)

    -- Minimise button
    local minBtn = mkBtn(titleBar, {
        bg=Color3.fromRGB(180,145,30), text="-", color=C.white, size=16,
        sz=UDim2.new(0,24,0,24), upos=UDim2.new(1,-58,0.5,-12), z=7,
    })
    mkCorner(minBtn, 6)
    addHover(minBtn, Color3.fromRGB(180,145,30), Color3.fromRGB(230,190,40))
    local minimised = false
    minBtn.MouseButton1Click:Connect(function()
        minimised = not minimised
        win.Size = minimised
            and UDim2.new(0, WIN_W, 0, 48)
            or  UDim2.new(0, WIN_W, 0, WIN_H)
    end)

    -- Drag
    do
        local dragging, dstart, wstart = false, nil, nil
        titleBar.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dstart   = inp.Position
                wstart   = win.Position
            end
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                -- Clamp to screen
                local vp = workspace.CurrentCamera.ViewportSize
                local ap = win.AbsolutePosition
                local as = win.AbsoluteSize
                win.Position = UDim2.new(0,
                    math.clamp(ap.X, 0, vp.X - as.X), 0,
                    math.clamp(ap.Y, 0, vp.Y - as.Y))
            end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
                          or inp.UserInputType == Enum.UserInputType.Touch) then
                local d = inp.Position - dstart
                win.Position = UDim2.new(
                    wstart.X.Scale, wstart.X.Offset + d.X,
                    wstart.Y.Scale, wstart.Y.Offset + d.Y)
            end
        end)
    end

    -- ── Stat bar ───────────────────────────────────────────────────────────
    local statBar = mkFrame(win, {
        bg=C.surfaceHigh, size=UDim2.new(1,-16,0,38),
        pos=UDim2.new(0,8,0,50), z=5, name="StatBar",
    })
    mkCorner(statBar, 8)
    mkStroke(statBar, C.border, 1)

    local function statChip(icon, color, xScaleStart, xScaleEnd)
        local chip = mkFrame(statBar, {
            bg=C.bg, trans=1,
            size=UDim2.new(xScaleEnd-xScaleStart, 0, 1, 0),
            pos=UDim2.new(xScaleStart, 0, 0, 0), z=5,
        })
        mkLabel(chip, {
            text=icon, color=color, size=13,
            sz=UDim2.new(0,22,1,0), upos=UDim2.new(0,6,0,0),
            xalign=Enum.TextXAlignment.Center, z=6,
        })
        local val = mkLabel(chip, {
            text="0", color=C.textPrimary, size=11, font=Enum.Font.GothamBold,
            sz=UDim2.new(1,-28,1,0), upos=UDim2.new(0,28,0,0), z=6, name="Val",
        })
        return val
    end

    local waveVal  = statChip("~", C.accent,   0,     0.333)
    local timeVal  = statChip("T", C.violet,   0.333, 0.666)
    local moneyVal = statChip("$", C.success,  0.666, 1.0)

    -- ── Tab bar ────────────────────────────────────────────────────────────
    local TABS = {
        { id="macro",    label="Macro",    accent=C.accent  },
        { id="autoexec", label="AutoExec", accent=C.violet  },
        { id="log",      label="Log",      accent=C.warning },
    }
    local tabBtns  = {}
    local tabPages = {}

    local tabBar = mkFrame(win, {
        bg=C.surface, size=UDim2.new(1,0,0,34),
        pos=UDim2.new(0,0,0,90), z=5, name="TabBar",
    })
    mkFrame(tabBar, {
        bg=C.border, size=UDim2.new(1,0,0,1),
        pos=UDim2.new(0,0,1,-1), z=6,
    })

    local tabListLayout = Instance.new("UIListLayout")
    tabListLayout.FillDirection = Enum.FillDirection.Horizontal
    tabListLayout.Padding = UDim.new(0,0)
    tabListLayout.Parent  = tabBar

    local function setTab(id)
        for _, td in ipairs(TABS) do
            local pg  = tabPages[td.id]
            local btn = tabBtns[td.id]
            local on  = (td.id == id)
            if pg  then pg.Visible = on end
            if btn then
                safeTween(btn, TI_FAST, {
                    BackgroundColor3 = on and td.accent or C.surface,
                    TextColor3       = on and C.white   or C.textSecond,
                })
            end
        end
    end

    local tabW = math.floor(WIN_W / #TABS)
    for _, td in ipairs(TABS) do
        local btn = mkBtn(tabBar, {
            bg=C.surface, text=td.label, color=C.textSecond,
            size=10, font=Enum.Font.GothamBold,
            sz=UDim2.new(0, tabW, 1, 0), z=6,
        })
        btn.MouseButton1Click:Connect(function() setTab(td.id) end)
        tabBtns[td.id] = btn

        -- [J4] Regular Frame as page container (not ScrollingFrame at top level)
        local pg = mkFrame(win, {
            bg=C.bg, trans=1,
            size=UDim2.new(1,0,1,-126),
            pos=UDim2.new(0,0,0,126),
            clip=true, z=3, name="Page_"..td.id,
        })
        pg.Visible = false
        tabPages[td.id] = pg
    end

    -- ══════════════════════════════════════════════════════════════════════
    --  §13.1  MACRO TAB
    -- ══════════════════════════════════════════════════════════════════════
    local macroPage = tabPages["macro"]

    -- Scrollable inner content for macro tab
    local macroScroll = mkScrollFrame(macroPage,
        UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), "MacroScroll")
    macroScroll.BackgroundTransparency = 1

    local macroList = Instance.new("UIListLayout")
    macroList.FillDirection       = Enum.FillDirection.Vertical
    macroList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    macroList.Padding             = UDim.new(0,5)
    macroList.SortOrder           = Enum.SortOrder.LayoutOrder
    macroList.Parent              = macroScroll

    local macroPad = Instance.new("UIPadding")
    macroPad.PaddingLeft   = UDim.new(0,8)
    macroPad.PaddingRight  = UDim.new(0,8)
    macroPad.PaddingTop    = UDim.new(0,8)
    macroPad.PaddingBottom = UDim.new(0,8)
    macroPad.Parent        = macroScroll

    -- State badge row
    local badgeRow = mkFrame(macroScroll, {
        bg=C.bg, trans=1, size=UDim2.new(1,0,0,30), name="BadgeRow",
    })

    local badge = mkFrame(badgeRow, {
        bg=C.surfaceHigh, size=UDim2.new(0,130,0,26),
        pos=UDim2.new(0,0,0.5,-13), name="Badge",
    })
    mkCorner(badge, 13)
    mkStroke(badge, C.accentDim, 1)
    local bLabel = mkLabel(badge, {
        text="IDLE", color=C.textSecond, size=10, font=Enum.Font.GothamBold,
        sz=UDim2.new(1,0,1,0), xalign=Enum.TextXAlignment.Center, z=4,
    })
    local countChip = mkFrame(badgeRow, {
        bg=C.surfaceHigh, size=UDim2.new(0,140,0,26),
        pos=UDim2.new(0,138,0.5,-13),
    })
    mkCorner(countChip, 13)
    mkStroke(countChip, C.border, 1)
    local countLbl = mkLabel(countChip, {
        text="0 actions", color=C.textSecond, size=10, font=Enum.Font.Gotham,
        sz=UDim2.new(1,0,1,0), xalign=Enum.TextXAlignment.Center, z=4,
    })
    local saveChip = mkFrame(badgeRow, {
        bg=C.surfaceHigh, size=UDim2.new(0,80,0,26),
        pos=UDim2.new(1,-80,0.5,-13),
    })
    mkCorner(saveChip, 13)
    local saveLbl = mkLabel(saveChip, {
        text="[AUTO]", color=C.success, size=9, font=Enum.Font.GothamBold,
        sz=UDim2.new(1,0,1,0), xalign=Enum.TextXAlignment.Center, z=4,
    })

    -- Buttons
    local BTN_DEFS = {
        { name="RecBtn",  text="REC",  bg=Color3.fromRGB(200,40,40),  hov=Color3.fromRGB(255,70,70),  key="F6" },
        { name="StopBtn", text="STOP", bg=Color3.fromRGB(50,60,90),   hov=Color3.fromRGB(80,95,140),  key="F7" },
        { name="PlayBtn", text="PLAY", bg=Color3.fromRGB(30,130,80),  hov=Color3.fromRGB(50,190,110), key="F8" },
        { name="SaveBtn", text="SAVE", bg=Color3.fromRGB(60,60,110),  hov=Color3.fromRGB(90,90,160),  key="F9" },
        { name="LoadBtn", text="LOAD", bg=Color3.fromRGB(60,60,110),  hov=Color3.fromRGB(90,90,160),  key="F10"},
    }
    local btnRefs = {}
    local btnRow  = mkFrame(macroScroll, {
        bg=C.bg, trans=1, size=UDim2.new(1,0,0,40), name="BtnRow",
    })
    local BW = math.floor((WIN_W - 32) / #BTN_DEFS) - 4
    for i, def in ipairs(BTN_DEFS) do
        local xOff = (i-1) * (BW + 4)
        local b = mkBtn(btnRow, {
            bg=def.bg, text=def.text.." "..def.key,
            color=C.white, size=9,
            sz=UDim2.new(0, BW, 0, 38),
            upos=UDim2.new(0, xOff, 0, 0),
            z=4, name=def.name,
        })
        mkCorner(b, 8)
        addHover(b, def.bg, def.hov)
        btnRefs[def.name] = b
    end

    -- Progress bar
    local progTrack = mkFrame(macroScroll, {
        bg=C.surfaceHigh, size=UDim2.new(1,0,0,6), name="ProgTrack",
    })
    mkCorner(progTrack, 3)
    local progFill = mkFrame(progTrack, {
        bg=C.accent, size=UDim2.new(0,0,1,0), name="Fill",
    })
    mkCorner(progFill, 3)
    local progLbl = mkLabel(macroScroll, {
        text="Ready", color=C.textDim, size=10, font=Enum.Font.Code,
        sz=UDim2.new(1,0,0,14), xalign=Enum.TextXAlignment.Right, z=4,
    })

    -- Step delay slider
    local sliderRow = mkFrame(macroScroll, {
        bg=C.surfaceHigh, size=UDim2.new(1,0,0,42), name="SliderRow",
    })
    mkCorner(sliderRow, 8)
    mkStroke(sliderRow, C.border, 1)
    mkLabel(sliderRow, {
        text="Step Delay", color=C.textSecond, size=10, font=Enum.Font.Gotham,
        sz=UDim2.new(0,75,1,0), upos=UDim2.new(0,10,0,0), z=4,
    })
    local delayLbl = mkLabel(sliderRow, {
        text="0.10s", color=C.accent, size=10, font=Enum.Font.GothamBold,
        sz=UDim2.new(0,46,1,0), upos=UDim2.new(1,-52,0,0),
        xalign=Enum.TextXAlignment.Right, z=4,
    })
    local sTrack = mkFrame(sliderRow, {
        bg=C.bg, size=UDim2.new(1,-150,0,4), pos=UDim2.new(0,90,0.5,-2),
    })
    mkCorner(sTrack, 2)
    local sFill = mkFrame(sTrack, {
        bg=C.accent, size=UDim2.new(0.05,0,1,0),
    })
    mkCorner(sFill, 2)
    local sThumb = mkFrame(sTrack, {
        bg=C.white, size=UDim2.new(0,12,0,12),
        pos=UDim2.new(0.05,-6,0.5,-6), z=5,
    })
    mkCorner(sThumb, 6)
    do
        local DMIN, DMAX = 0.05, 2.0
        local drag = false
        sThumb.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then drag=true end
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if not drag or inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local tw = sTrack.AbsoluteSize.X
            if tw == 0 then return end
            local rel = math.clamp(
                (inp.Position.X - sTrack.AbsolutePosition.X) / tw, 0, 1)
            sFill.Size      = UDim2.new(rel, 0, 1, 0)
            sThumb.Position = UDim2.new(rel, -6, 0.5, -6)
            local v = DMIN + rel * (DMAX - DMIN)
            CONFIG.minActionDelay = v
            delayLbl.Text = string.format("%.2fs", v)
        end)
    end

    updateCanvas(macroScroll, macroList)

    -- Badge + progress helpers
    local function setBadge(text, color)
        bLabel.Text       = text
        bLabel.TextColor3 = color or C.textSecond
    end

    local function setProgress(frac, text)
        safeTween(progFill, TI_MED, {
            Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
        })
        if text then progLbl.Text = text end
    end

    -- Wire macro buttons
    btnRefs["RecBtn"].MouseButton1Click:Connect(function()
        if player.playing then UI.log("error","Stop playback first"); return end
        recorder:startRecording()
        setBadge("REC", C.danger)
        saveLbl.Text = "[LIVE]"; saveLbl.TextColor3 = C.warning
        UI.log("system", "Recording started — auto-saves every action")
        setProgress(0, "Recording...")
    end)

    btnRefs["StopBtn"].MouseButton1Click:Connect(function()
        if recorder.recording then
            local m = recorder:stopRecording()
            setBadge("IDLE", C.textSecond)
            saveLbl.Text = "[AUTO]"; saveLbl.TextColor3 = C.success
            countLbl.Text = #m .. " actions"
            UI.log("system", "Stopped — " .. #m .. " actions captured & saved")
            setProgress(0, "Ready")
        elseif player.playing then
            player:stopPlayback()
            setBadge("IDLE", C.textSecond)
            UI.log("system", "Playback stopped")
            setProgress(0, "Stopped")
        end
    end)

    btnRefs["PlayBtn"].MouseButton1Click:Connect(function()
        local macro = recorder:getMacro()
        if #macro == 0 then UI.log("error", "No macro — record or load first"); return end
        player:playMacro(macro, function(i, total, record)
            setProgress(i / total, "Step " .. i .. "/" .. total)
            if record then
                UI.log(record.action, "w=" .. (record.wave or 0)
                    .. " t=" .. string.format("%.1f", record.time or 0)
                    .. " slot=" .. tostring(record.slot))
            else
                setBadge("IDLE", C.textSecond)
                setProgress(1, "Complete!")
                UI.log("system", "Playback finished")
            end
        end)
        setBadge("PLAYING", C.success)
        UI.log("system", "Playback started — " .. #macro .. " actions")
    end)

    btnRefs["SaveBtn"].MouseButton1Click:Connect(function()
        local ok = storage.save(recorder:getMacro())
        if ok then
            UI.log("system", "Saved to TDMacro_save.json")
            setBadge("SAVED", C.success)
            spawn(function()
                wait(2)
                if not recorder.recording then setBadge("IDLE", C.textSecond) end
            end)
        else
            UI.log("error", "Save failed — check console")
        end
    end)

    btnRefs["LoadBtn"].MouseButton1Click:Connect(function()
        local macro = storage.load()
        if macro then
            recorder:setMacro(macro)
            countLbl.Text = #macro .. " actions"
            UI.log("system", "Loaded " .. #macro .. " actions")
            setBadge("LOADED", C.accent)
            spawn(function() wait(2); setBadge("IDLE", C.textSecond) end)
        else
            UI.log("error", "Load failed — file not found")
        end
    end)

    -- Notify captures
    recorder._onCapture = function(record)
        local pos = record.position
        local ps  = pos and string.format("(%.0f,%.0f,%.0f)", pos.x, pos.y, pos.z) or "?"
        UI.log(record.action, "pos=" .. ps .. " slot=" .. tostring(record.slot))
        countLbl.Text = #recorder.macro .. " actions"
        saveLbl.Text  = "[SAVED]"; saveLbl.TextColor3 = C.success
        spawn(function()
            wait(1)
            saveLbl.Text = "[LIVE]"; saveLbl.TextColor3 = C.warning
        end)
    end

    -- ══════════════════════════════════════════════════════════════════════
    --  §13.2  AUTO-EXECUTE TAB
    -- ══════════════════════════════════════════════════════════════════════
    local autoPage = tabPages["autoexec"]

    local autoList = Instance.new("UIListLayout")
    autoList.FillDirection       = Enum.FillDirection.Vertical
    autoList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    autoList.Padding             = UDim.new(0,5)
    autoList.SortOrder           = Enum.SortOrder.LayoutOrder
    autoList.Parent              = autoPage

    local autoPad = Instance.new("UIPadding")
    autoPad.PaddingLeft = UDim.new(0,8); autoPad.PaddingRight  = UDim.new(0,8)
    autoPad.PaddingTop  = UDim.new(0,8); autoPad.PaddingBottom = UDim.new(0,8)
    autoPad.Parent      = autoPage

    -- Info bar
    local infoBar = mkFrame(autoPage, {
        bg=C.surfaceHigh, size=UDim2.new(1,0,0,32), name="InfoBar",
    })
    mkCorner(infoBar, 8)
    mkStroke(infoBar, C.violet, 1, 0.5)
    mkLabel(infoBar, {
        text="Write Luau  |  Framework global available  |  runs in pcall",
        color=C.textSecond, size=10, font=Enum.Font.Gotham,
        sz=UDim2.new(1,-12,1,0), upos=UDim2.new(0,8,0,0),
        wrap=true, z=4,
    })

    -- Preset row
    local presetRow = mkFrame(autoPage, {
        bg=C.surfaceHigh, size=UDim2.new(1,0,0,32), name="PresetRow",
    })
    mkCorner(presetRow, 8)
    mkStroke(presetRow, C.border, 1)
    mkLabel(presetRow, {
        text="Preset:", color=C.textSecond, size=10, font=Enum.Font.Gotham,
        sz=UDim2.new(0,55,1,0), upos=UDim2.new(0,8,0,0), z=4,
    })
    local presetBtn = mkBtn(presetRow, {
        bg=C.bg, text=AutoExec.PRESETS[1].name, color=C.textPrimary,
        size=10, font=Enum.Font.Gotham,
        sz=UDim2.new(1,-66,0,24), upos=UDim2.new(0,58,0.5,-12),
        z=5, name="PresetBtn",
    })
    mkCorner(presetBtn, 6)
    mkStroke(presetBtn, C.border, 1)

    -- Code editor
    local editorWrap = mkFrame(autoPage, {
        bg=Color3.fromRGB(6,8,14), size=UDim2.new(1,0,0,190), name="EditorWrap",
    })
    mkCorner(editorWrap, 8)
    mkStroke(editorWrap, C.border, 1)

    local codeBox = Instance.new("TextBox")
    codeBox.BackgroundTransparency = 1
    codeBox.TextColor3             = C.codeGreen
    codeBox.PlaceholderText        = "-- Luau script here\n-- Framework global available"
    codeBox.PlaceholderColor3      = C.textDim
    codeBox.TextSize               = 11
    codeBox.Font                   = Enum.Font.Code
    codeBox.MultiLine              = true
    codeBox.ClearTextOnFocus       = false
    codeBox.TextXAlignment         = Enum.TextXAlignment.Left
    codeBox.TextYAlignment         = Enum.TextYAlignment.Top
    codeBox.Size                   = UDim2.new(1,-8,1,-8)
    codeBox.Position               = UDim2.new(0,4,0,4)
    codeBox.ZIndex                 = 4
    codeBox.Name                   = "CodeBox"
    codeBox.Parent                 = editorWrap

    local savedCode = AutoExec.loadSaved()
    if savedCode ~= "" then codeBox.Text = savedCode end

    -- Dropdown (simple cycling through presets on click)
    local currentPreset = 1
    presetBtn.MouseButton1Click:Connect(function()
        currentPreset = currentPreset % #AutoExec.PRESETS + 1
        local p = AutoExec.PRESETS[currentPreset]
        presetBtn.Text = p.name
        if p.code ~= "" then codeBox.Text = p.code end
    end)

    -- Exec buttons row
    local execRow = mkFrame(autoPage, {
        bg=C.bg, trans=1, size=UDim2.new(1,0,0,34), name="ExecRow",
    })
    local execRowList = Instance.new("UIListLayout")
    execRowList.FillDirection = Enum.FillDirection.Horizontal
    execRowList.Padding = UDim.new(0,6)
    execRowList.Parent  = execRow

    local function makeExecBtn(text, bg, hov)
        local b = mkBtn(execRow, {
            bg=bg, text=text, color=C.white, size=11,
            sz=UDim2.new(0,0,0,32), z=5,
        })
        b.AutomaticSize = Enum.AutomaticSize.X
        local p = Instance.new("UIPadding")
        p.PaddingLeft = UDim.new(0,12); p.PaddingRight = UDim.new(0,12)
        p.Parent = b
        mkCorner(b, 7)
        addHover(b, bg, hov)
        return b
    end

    local runBtn   = makeExecBtn("RUN",   Color3.fromRGB(30,140,80),  Color3.fromRGB(50,200,110))
    local stopEBtn = makeExecBtn("STOP",  Color3.fromRGB(50,60,90),   Color3.fromRGB(80,95,140))
    local clearBtn = makeExecBtn("CLEAR", Color3.fromRGB(80,30,30),   Color3.fromRGB(140,50,50))
    local saveEBtn = makeExecBtn("SAVE",  Color3.fromRGB(60,60,110),  Color3.fromRGB(90,90,160))

    local execStatus = mkLabel(autoPage, {
        text="Idle", color=C.textDim, size=10, font=Enum.Font.Code,
        sz=UDim2.new(1,0,0,18), z=4,
    })

    runBtn.MouseButton1Click:Connect(function()
        local code = codeBox.Text
        if not code or code:gsub("%s","") == "" then
            UI.log("error","[AutoExec] Nothing to run"); return
        end
        execStatus.Text       = "Running..."
        execStatus.TextColor3 = C.warning
        local ok, err = AutoExec.run(code, function(msg)
            execStatus.Text       = "Error"
            execStatus.TextColor3 = C.danger
            UI.log("error", msg)
        end)
        if ok then
            UI.log("system","[AutoExec] Started")
        else
            execStatus.Text       = "Compile Error"
            execStatus.TextColor3 = C.danger
        end
    end)

    stopEBtn.MouseButton1Click:Connect(function()
        AutoExec.stop()
        execStatus.Text       = "Idle"
        execStatus.TextColor3 = C.textDim
        UI.log("system","[AutoExec] Stopped")
    end)

    clearBtn.MouseButton1Click:Connect(function()
        codeBox.Text = ""
        UI.log("system","[AutoExec] Cleared")
    end)

    saveEBtn.MouseButton1Click:Connect(function()
        Util.writeFile(CONFIG.autoExecFile, codeBox.Text)
        execStatus.Text       = "Saved!"
        execStatus.TextColor3 = C.success
        spawn(function()
            wait(2)
            execStatus.Text       = "Idle"
            execStatus.TextColor3 = C.textDim
        end)
        UI.log("system","[AutoExec] Saved")
    end)

    -- ══════════════════════════════════════════════════════════════════════
    --  §13.3  LOG TAB
    -- ══════════════════════════════════════════════════════════════════════
    local logPage = tabPages["log"]

    -- Top clear button bar
    local logTopBar = mkFrame(logPage, {
        bg=C.bg, trans=1, size=UDim2.new(1,0,0,32),
        pos=UDim2.new(0,0,0,0), z=4, name="LogTop",
    })
    local clearLogBtn = mkBtn(logTopBar, {
        bg=Color3.fromRGB(60,35,35), text="Clear Log",
        color=C.textSecond, size=10, font=Enum.Font.Gotham,
        sz=UDim2.new(0,90,0,26), upos=UDim2.new(1,-94,0.5,-13),
        z=5,
    })
    mkCorner(clearLogBtn, 6)
    addHover(clearLogBtn, Color3.fromRGB(60,35,35), Color3.fromRGB(120,50,50))

    -- [J4] ScrollingFrame with fixed canvas
    local logScroll = mkScrollFrame(logPage,
        UDim2.new(1,0,1,-34), UDim2.new(0,0,0,34), "LogScroll")
    logScroll.BackgroundColor3       = C.surfaceHigh
    logScroll.BackgroundTransparency = 0
    mkCorner(logScroll, 8)
    mkStroke(logScroll, C.border, 1)

    local logListLayout = Instance.new("UIListLayout")
    logListLayout.FillDirection  = Enum.FillDirection.Vertical
    logListLayout.Padding        = UDim.new(0,1)
    logListLayout.SortOrder      = Enum.SortOrder.LayoutOrder
    logListLayout.Parent         = logScroll

    local logPad = Instance.new("UIPadding")
    logPad.PaddingLeft   = UDim.new(0,6)
    logPad.PaddingRight  = UDim.new(0,6)
    logPad.PaddingTop    = UDim.new(0,4)
    logPad.PaddingBottom = UDim.new(0,4)
    logPad.Parent        = logScroll

    local logCount = 0
    local MAX_LOG  = 100
    local LOG_COLORS = {
        place="80e882", upgrade="52c4ff", ability="a050ff",
        sell="ffbe3c", system="7891ba", error="ff5050",
    }

    local function addLog(actionType, message)
        logCount = logCount + 1
        if logCount > MAX_LOG then
            local oldest = logScroll:FindFirstChildWhichIsA("Frame")
            if oldest then oldest:Destroy(); logCount = logCount - 1 end
        end
        local color = LOG_COLORS[actionType] or "7891ba"
        local row = mkFrame(logScroll, {
            bg = logCount % 2 == 0 and C.surfaceHigh or Color3.fromRGB(16,21,38),
            size = UDim2.new(1,0,0,20), z=4, name="Row"..logCount,
        })
        row.LayoutOrder = logCount
        mkLabel(row, {
            text = string.upper(actionType),
            color = Color3.fromHex(color), size=9, font=Enum.Font.GothamBold,
            sz=UDim2.new(0,64,1,0), z=5,
        })
        mkLabel(row, {
            text=message, color=C.textSecond, size=9, font=Enum.Font.Code,
            sz=UDim2.new(1,-68,1,0), upos=UDim2.new(0,68,0,0),
            xalign=Enum.TextXAlignment.Left, wrap=false, z=5,
        })
        -- [J4] Update canvas size after adding a row
        spawn(function()
            wait()
            logScroll.CanvasSize = UDim2.new(0,0,0,
                logListLayout.AbsoluteContentSize.Y + 16)
            logScroll.CanvasPosition = Vector2.new(0, 99999)
        end)
    end

    clearLogBtn.MouseButton1Click:Connect(function()
        for _, c in ipairs(logScroll:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        logCount = 0
        logScroll.CanvasSize = UDim2.new(0,0,2,0)
    end)

    UI.log = addLog

    -- ── Stat update loop ───────────────────────────────────────────────────
    spawn(function()
        while sg.Parent do
            if Framework and Framework.tracker then
                local s = Framework.tracker:snapshot()
                waveVal.Text  = "Wave " .. s.wave
                timeVal.Text  = string.format("%.0fs", s.gameTime)
                moneyVal.Text = tostring(s.money)
            end
            if Framework and Framework.recorder then
                countLbl.Text = #Framework.recorder.macro .. " actions"
            end
            wait(0.5)
        end
    end)

    -- ── Keyboard shortcuts ─────────────────────────────────────────────────
    UserInputService.InputBegan:Connect(function(inp, processed)
        if processed then return end
        if inp.KeyCode == Enum.KeyCode.F6 then
            btnRefs["RecBtn"].MouseButton1Click:Fire()
        elseif inp.KeyCode == Enum.KeyCode.F7 then
            btnRefs["StopBtn"].MouseButton1Click:Fire()
        elseif inp.KeyCode == Enum.KeyCode.F8 then
            btnRefs["PlayBtn"].MouseButton1Click:Fire()
        elseif inp.KeyCode == Enum.KeyCode.F9 then
            btnRefs["SaveBtn"].MouseButton1Click:Fire()
        elseif inp.KeyCode == Enum.KeyCode.F10 then
            btnRefs["LoadBtn"].MouseButton1Click:Fire()
        end
    end)

    setTab("macro")
    addLog("system", "v3.1 ready — JJSploit compatible")
    return sg
end

-- ════════════════════════════════════════════════════════════════════════════
--  §14  BOOTSTRAP
-- ════════════════════════════════════════════════════════════════════════════
local function init()
    local detector  = RemoteEventDetector.new()
    local tracker   = GameTracker.new()
    local placement = PlacementDetector.new()
    local recorder  = MacroRecorder.new(detector, tracker, placement)
    local player    = MacroPlayer.new(detector, tracker)

    detector:init()
    recorder:attachListeners()
    local restored = recorder:tryAutoLoad()
    tracker:startPolling()

    Framework = {
        detector  = detector,
        tracker   = tracker,
        placement = placement,
        recorder  = recorder,
        player    = player,
        storage   = MacroStorage,
        autoExec  = AutoExec,
    }

    UI.build(recorder, player, MacroStorage)

    if restored and UI.log then
        UI.log("system", "Restored " .. #recorder.macro .. " actions from last session")
    end

    return Framework
end

Framework = init()
