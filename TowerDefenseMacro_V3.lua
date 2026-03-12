--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║   TOWER DEFENSE MACRO FRAMEWORK  ·  V3  (FIXED + AUTO-EXECUTE EDITION)     ║
║                                                                              ║
║  FIXES IN V3:                                                                ║
║   [1] Recording lost on close → auto-save after every captured action       ║
║       + auto-load previous recording on startup                              ║
║   [2] Actions not recording   → listeners registered once at init (not      ║
║       inside startRecording), gated by self.recording flag; duplicate       ║
║       listener stacking eliminated                                           ║
║   [3] Auto-Execute panel      → in-UI script editor with Run/Stop/Presets   ║
╚══════════════════════════════════════════════════════════════════════════════╝
--]]

-- ════════════════════════════════════════════════════════════════════════════
--  §1  SERVICES
-- ════════════════════════════════════════════════════════════════════════════
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ════════════════════════════════════════════════════════════════════════════
--  §2  CONFIG
-- ════════════════════════════════════════════════════════════════════════════
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
    timeTolerance    = 0.5,
    minActionDelay   = 0.1,
    autoSaveFile     = "TDMacro_autosave.json",   -- ← FIX [1]: auto-save path
    manualSaveFile   = "TDMacro_save.json",
    autoExecFile     = "TDMacro_autoexec.lua",    -- ← auto-exec script persistence
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
    return string.format("T%05d_%d", _idCounter, math.floor(os.clock() * 1000 % 100000))
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

-- Safe file read/write wrappers (executor environment)
function Util.writeFile(path, content)
    if writefile then
        local ok, err = pcall(writefile, path, content)
        if not ok then warn("[Util.writeFile] "..tostring(err)) end
        return ok
    end
    return false
end

function Util.readFile(path)
    if readfile then
        local ok, content = pcall(readfile, path)
        if ok and content and content ~= "" then return content end
    end
    return nil
end

function Util.fileExists(path)
    if isfile then
        local ok, result = pcall(isfile, path)
        return ok and result
    end
    -- fallback: try to read
    return Util.readFile(path) ~= nil
end

-- ════════════════════════════════════════════════════════════════════════════
--  §4  REMOTE EVENT DETECTOR
--  ──────────────────────────────────────────────────────────────────────────
--  FIX [2]: hookRemote now stores ONE callback per action type.
--  _dispatch fires it. Listeners registered via onAction() are called from
--  _dispatch but are themselves registered only ONCE at init time.
--  startRecording() no longer registers new listeners — it only sets a flag.
-- ════════════════════════════════════════════════════════════════════════════
local RemoteEventDetector = {}
RemoteEventDetector.__index = RemoteEventDetector

function RemoteEventDetector.new()
    local self      = setmetatable({}, RemoteEventDetector)
    self.remotes    = {}
    self.listeners  = {}   -- { [actionType] = {fn, fn, ...} }
    self._hooked    = {}   -- track which remotes have been hooked
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

--[[
    hookRemote — installs a metatable intercept on the RemoteEvent so that
    every FireServer call routes through our dispatcher BEFORE hitting the
    server. Uses getrawmetatable (available in all major executors).

    Important: we hook the SHARED metatable once per remote object. All
    subsequent FireServer calls on that object will pass through _dispatch.
]]
function RemoteEventDetector:hookRemote(actionType, remote)
    if not remote then return false end
    if self._hooked[remote] then
        -- already hooked (e.g. same remote shared between action types)
        self.remotes[actionType] = remote
        return true
    end

    local mt = getrawmetatable and getrawmetatable(remote)
    if not mt then
        warn("[RemoteEventDetector] getrawmetatable unavailable. Hook not installed for '"
            ..actionType.."'. Recording will not work outside executor context.")
        self.remotes[actionType] = remote
        return false
    end

    -- Capture the real FireServer before we overwrite __index
    local originalFS = remote.FireServer   -- resolves through original __index

    local detector = self   -- upvalue reference for closure
    setreadonly(mt, false)
    local prevIndex = mt.__index

    mt.__index = function(tbl, key)
        if key == "FireServer" then
            return function(selfRemote, ...)
                -- Determine which actionType this remote belongs to
                for aType, rem in pairs(detector.remotes) do
                    if rem == tbl then
                        detector:_dispatch(aType, tbl, { ... })
                        break
                    end
                end
                return originalFS(selfRemote, ...)
            end
        end
        -- Fallthrough to original __index for all other keys
        if type(prevIndex) == "function" then
            return prevIndex(tbl, key)
        elseif type(prevIndex) == "table" then
            return prevIndex[key]
        end
        return nil
    end
    setreadonly(mt, true)

    self._hooked[remote]    = true
    self.remotes[actionType] = remote
    print(string.format("[RemoteEventDetector] ✓ Hooked '%s' → %s",
        actionType, remote:GetFullName()))
    return true
end

-- Register a persistent listener called every time actionType fires.
-- Call this ONCE per listener at init time — not inside startRecording().
function RemoteEventDetector:onAction(actionType, callback)
    if not self.listeners[actionType] then
        self.listeners[actionType] = {}
    end
    table.insert(self.listeners[actionType], callback)
end

function RemoteEventDetector:_dispatch(actionType, remote, args)
    local list = self.listeners[actionType]
    if not list then return end
    for _, cb in ipairs(list) do
        task.spawn(cb, actionType, remote, args)
    end
end

-- Search for all remotes and hook them. Call once at startup.
function RemoteEventDetector:init()
    local found = 0
    for actionType in pairs(CONFIG.remoteNames) do
        local remote = self:findRemote(actionType)
        if remote then
            if self:hookRemote(actionType, remote) then
                found += 1
            end
        else
            warn(string.format(
                "[RemoteEventDetector] Remote not found for '%s' — update CONFIG.remoteNames",
                actionType))
        end
    end
    print(string.format("[RemoteEventDetector] Init complete: %d/%d remotes hooked.",
        found, #(function() local c=0 for _ in pairs(CONFIG.remoteNames) do c+=1 end return {c} end)()[1]))
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
    local lbl = self:_getLabel("wave")
    if lbl then
        local n = Util.readGuiNumber(lbl)
        if n > 0 then self.wave = n; return n end
    end
    for _, path in ipairs(CONFIG.rsPaths.wave or {}) do
        local obj = Util.resolvePath(game, path)
        if obj then self.wave = obj.Value; return obj.Value end
    end
    return self.wave
end

function GameTracker:readMoney()
    local lbl = self:_getLabel("money")
    if lbl then
        local n = Util.readGuiNumber(lbl)
        if n >= 0 then self.money = n; return n end
    end
    for _, path in ipairs(CONFIG.rsPaths.money or {}) do
        local obj = Util.resolvePath(game, path)
        if obj then self.money = obj.Value; return obj.Value end
    end
    return self.money
end

function GameTracker:readTime()
    local lbl = self:_getLabel("timer")
    if lbl then
        local n = Util.readGuiNumber(lbl)
        if n > 0 then self.gameTime = n; return n end
    end
    self.gameTime = os.clock() - self._start
    return self.gameTime
end

function GameTracker:snapshot()
    return {
        wave     = self:readWave(),
        money    = self:readMoney(),
        gameTime = self:readTime(),
    }
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
    if #args >= 3 and type(args[1])=="number"
        and type(args[2])=="number" and type(args[3])=="number" then
        return Vector3.new(args[1], args[2], args[3])
    end
    return nil
end

function PlacementDetector:extractSlot(args)
    for i = #args, 1, -1 do
        if type(args[i])=="number" and args[i]==math.floor(args[i])
            and args[i]>=1 and args[i]<=10 then
            return args[i]
        end
    end
    return nil
end

function PlacementDetector:extractTowerModel(args)
    for _, a in ipairs(args) do
        if typeof(a)=="Instance" and a:IsA("Model") then return a end
    end
    return nil
end

function PlacementDetector:registerTower(position, slot, model)
    local uid = Util.newId()
    self.activeTowers[uid] = {
        uid      = uid,
        position = position,
        slot     = slot,
        model    = model,
        placedAt = os.clock(),
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
--  ──────────────────────────────────────────────────────────────────────────
--  FIX [2]:  The capture listener is registered ONCE in attachListeners().
--            startRecording() only sets self.recording = true.
--            stopRecording() sets self.recording = false.
--  FIX [1]:  Every captured action immediately auto-saves to disk.
-- ════════════════════════════════════════════════════════════════════════════
local MacroRecorder = {}
MacroRecorder.__index = MacroRecorder

function MacroRecorder.new(detector, tracker, placementDet)
    local self = setmetatable({}, MacroRecorder)
    self.detector    = detector
    self.tracker     = tracker
    self.placement   = placementDet
    self.recording   = false
    self.macro       = {}
    self._onCapture  = nil   -- callback(record) → UI can react
    return self
end

function MacroRecorder:_buildRecord(actionType, args)
    local state    = self.tracker:snapshot()
    local position = self.placement:extractPosition(args)
    local slot     = self.placement:extractSlot(args)

    -- Serialise args to JSON-safe format
    local safeArgs = {}
    for _, v in ipairs(args) do
        if typeof(v) == "Vector3" then
            table.insert(safeArgs, { __type="Vector3", data=Util.vec3ToTable(v) })
        elseif typeof(v) == "CFrame" then
            local p, r = v.Position, { v:ToEulerAnglesXYZ() }
            table.insert(safeArgs, {
                __type="CFrame",
                pos=Util.vec3ToTable(p),
                rx=r[1], ry=r[2], rz=r[3],
            })
        elseif typeof(v) == "Instance" then
            table.insert(safeArgs, {
                __type="Instance",
                name=v.Name,
                path=v:GetFullName(),
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
    elseif (actionType == "upgrade" or actionType == "ability" or actionType == "sell")
            and position then
        record.towerUID = self.placement:findNearestTower(position)
        if actionType == "sell" and record.towerUID then
            self.placement:removeTower(record.towerUID)
        end
    end

    return record
end

--[[
    FIX [2]: attachListeners() — called ONCE at init.
    Registers a single listener per action type on the detector.
    The listener is gated by self.recording, so it only captures when active.
    This prevents listener accumulation (old bug: each REC press added new listeners).
]]
function MacroRecorder:attachListeners()
    for _, actionType in ipairs({ "place", "upgrade", "ability", "sell" }) do
        self.detector:onAction(actionType, function(aType, _, args)
            -- Gate: only capture when recording is active
            if not self.recording then return end

            local record = self:_buildRecord(aType, args)
            table.insert(self.macro, record)

            -- FIX [1]: auto-save immediately after every captured action
            self:_autoSave()

            -- Notify UI
            if self._onCapture then
                task.spawn(self._onCapture, record)
            end
        end)
    end
end

-- FIX [1]: write current macro to auto-save file after every action
function MacroRecorder:_autoSave()
    local ok, json = pcall(function()
        return HttpService:JSONEncode(self.macro)
    end)
    if ok then
        Util.writeFile(CONFIG.autoSaveFile, json)
    end
end

-- FIX [1]: try to restore the last auto-save on startup
function MacroRecorder:tryAutoLoad()
    local content = Util.readFile(CONFIG.autoSaveFile)
    if not content then return false end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if ok and type(data) == "table" and #data > 0 then
        self.macro = data
        print(string.format(
            "[MacroRecorder] Auto-loaded %d actions from previous session.", #data))
        return true
    end
    return false
end

-- FIX [2]: startRecording just sets the flag — NO new listeners
function MacroRecorder:startRecording()
    if self.recording then return end
    self.recording = true
    self.macro     = {}
    -- Clear old auto-save so we don't mix sessions
    Util.writeFile(CONFIG.autoSaveFile, "[]")
    print("[MacroRecorder] ▶ Recording started.")
end

function MacroRecorder:stopRecording()
    if not self.recording then return self.macro end
    self.recording = false
    self:_autoSave()   -- ensure final save
    print(string.format(
        "[MacroRecorder] ■ Stopped. %d actions captured and auto-saved.", #self.macro))
    return self.macro
end

function MacroRecorder:getMacro()   return Util.deepCopy(self.macro) end
function MacroRecorder:setMacro(m)  self.macro = m end

-- ════════════════════════════════════════════════════════════════════════════
--  §8  MACRO PLAYER
-- ════════════════════════════════════════════════════════════════════════════
local MacroPlayer = {}
MacroPlayer.__index = MacroPlayer

function MacroPlayer.new(detector, tracker)
    local self     = setmetatable({}, MacroPlayer)
    self.detector  = detector
    self.tracker   = tracker
    self.playing   = false
    self._thread   = nil
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
        warn("[MacroPlayer] No remote for action: " .. tostring(record.action))
        return
    end
    local args = deserialiseArgs(record.remoteArgs or {})
    remote:FireServer(table.unpack(args))
end

function MacroPlayer:playMacro(macro, onProgress)
    if self.playing then return end
    if not macro or #macro == 0 then return end
    self.playing = true

    self._thread = task.spawn(function()
        for i, record in ipairs(macro) do
            if not self.playing then break end

            -- Wait for correct wave
            if record.wave and record.wave > 0 then
                local deadline = os.clock() + 300
                while self.tracker:readWave() < record.wave
                    and os.clock() < deadline do
                    task.wait(0.25)
                end
            end

            -- Wait for correct game time
            if record.time and record.time > 0 then
                local deadline = os.clock() + 60
                while os.clock() < deadline do
                    local t = self.tracker:readTime()
                    if math.abs(t - record.time) <= CONFIG.timeTolerance then break end
                    if t > record.time + CONFIG.timeTolerance then break end
                    task.wait(0.05)
                end
            end

            -- Check money for placements
            if record.action == "place" and record.money and record.money > 0 then
                local deadline = os.clock() + 30
                while self.tracker:readMoney() < record.money
                    and os.clock() < deadline do
                    task.wait(0.5)
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

-- ════════════════════════════════════════════════════════════════════════════
--  §9  STORAGE
-- ════════════════════════════════════════════════════════════════════════════
local MacroStorage = {}

function MacroStorage.save(macro, filename)
    filename = filename or CONFIG.manualSaveFile
    local ok, json = pcall(function() return HttpService:JSONEncode(macro) end)
    if not ok then warn("[MacroStorage] Encode error: "..tostring(json)); return false end
    local written = Util.writeFile(filename, json)
    if written then
        print("[MacroStorage] Saved "..#macro.." actions → "..filename)
    else
        -- Fallback: print JSON for manual copy
        print("[MacroStorage] writefile unavailable — copy JSON:\n"..json)
    end
    return true
end

function MacroStorage.load(filename)
    filename = filename or CONFIG.manualSaveFile
    local content = Util.readFile(filename)
    if not content then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(content) end)
    if ok and type(data) == "table" then
        print("[MacroStorage] Loaded "..#data.." actions from "..filename)
        return data
    end
    warn("[MacroStorage] Decode error for: "..filename)
    return nil
end

-- ════════════════════════════════════════════════════════════════════════════
--  §10  AUTO-EXECUTE ENGINE
--  ──────────────────────────────────────────────────────────────────────────
--  Runs arbitrary Luau code entered in the UI editor.
--  The script runs in a protected thread; errors are reported back to UI.
--  Scripts are persisted to disk and auto-loaded when the hub opens.
-- ════════════════════════════════════════════════════════════════════════════
local AutoExec = {}
AutoExec._thread  = nil
AutoExec._running = false

-- Preset scripts shown in the UI dropdown
AutoExec.PRESETS = {
    {
        name = "— Select Preset —",
        code = "",
    },
    {
        name = "Loop: Auto-Play Macro",
        code = [[-- Automatically replay the macro every time it finishes.
-- Adjust DELAY_BETWEEN_RUNS (seconds) as needed.
local DELAY_BETWEEN_RUNS = 5

while Framework.player do
    local macro = Framework.recorder:getMacro()
    if #macro > 0 and not Framework.player.playing then
        Framework.player:playMacro(macro)
        -- Wait for playback to finish
        while Framework.player.playing do task.wait(1) end
        task.wait(DELAY_BETWEEN_RUNS)
    else
        task.wait(2)
    end
end]],
    },
    {
        name = "Loop: Auto-Save Every 30s",
        code = [[-- Continuously save the macro every 30 seconds.
while Framework.recorder do
    task.wait(30)
    if #Framework.recorder.macro > 0 then
        Framework.storage.save(Framework.recorder:getMacro())
        print("[AutoExec] Auto-saved macro.")
    end
end]],
    },
    {
        name = "Notify: Wave Change Alert",
        code = [[-- Print a message every time the wave number increases.
local lastWave = 0
while Framework.tracker do
    local w = Framework.tracker:readWave()
    if w > lastWave then
        lastWave = w
        print("[AutoExec] Wave changed → " .. w)
    end
    task.wait(1)
end]],
    },
    {
        name = "Util: Print All Remotes",
        code = [[-- Print every RemoteEvent found in ReplicatedStorage.
for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
    if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
        print("[Remote] " .. v:GetFullName())
    end
end]],
    },
    {
        name = "Util: Dump Macro to Output",
        code = [[-- Print every recorded action to the developer console.
local macro = Framework.recorder:getMacro()
print(string.format("[AutoExec] Macro contains %d actions:", #macro))
for i, r in ipairs(macro) do
    print(string.format("  [%d] %s | wave=%d | time=%.1fs | slot=%s | uid=%s",
        i, r.action, r.wave or 0, r.time or 0,
        tostring(r.slot), tostring(r.towerUID)))
end]],
    },
}

-- Run code string in a protected task. Returns success, errorMsg.
function AutoExec.run(code, onError)
    if AutoExec._running then
        AutoExec.stop()
        task.wait(0.05)
    end

    -- Persist the script
    Util.writeFile(CONFIG.autoExecFile, code)

    local fn, compileErr = loadstring(code)
    if not fn then
        local msg = "[AutoExec] Compile error: " .. tostring(compileErr)
        warn(msg)
        if onError then onError(msg) end
        return false, compileErr
    end

    AutoExec._running = true
    AutoExec._thread  = task.spawn(function()
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
        task.cancel(AutoExec._thread)
        AutoExec._thread  = nil
    end
    AutoExec._running = false
end

function AutoExec.loadSaved()
    return Util.readFile(CONFIG.autoExecFile) or ""
end

-- ════════════════════════════════════════════════════════════════════════════
--  §11  UI  —  COLOUR PALETTE & TWEEN PRESETS
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
    codeBlue    = Color3.fromRGB(100, 180, 255),
}

local TI_FAST   = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TI_MED    = TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TI_SPRING = TweenInfo.new(0.45, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)

local function tw(inst, info, props)
    TweenService:Create(inst, info, props):Play()
end

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
    s.Color = color or C.border; s.Thickness = thick or 1
    s.Transparency = trans or 0; s.Parent = parent
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
    t.BackgroundTransparency = 1; t.BorderSizePixel = 0
    t.Text         = p.text   or ""
    t.TextColor3   = p.color  or C.textPrimary
    t.TextSize     = p.size   or 12
    t.Font         = p.font   or Enum.Font.GothamBold
    t.RichText     = p.rich   or false
    t.TextXAlignment = p.xalign or Enum.TextXAlignment.Left
    t.TextYAlignment = p.yalign or Enum.TextYAlignment.Center
    t.TextWrapped  = p.wrap   or false
    t.Size         = p.sz     or UDim2.new(1,0,0,20)
    t.Position     = p.upos   or UDim2.new(0,0,0,0)
    t.ZIndex       = p.z      or 3
    t.Name         = p.name   or "Label"
    t.Parent = parent
    return t
end

local function mkBtn(parent, p)
    local b = Instance.new("TextButton")
    b.BackgroundColor3       = p.bg    or C.surfaceHigh
    b.BackgroundTransparency = p.trans or 0
    b.BorderSizePixel        = 0
    b.Text       = p.text  or ""
    b.TextColor3 = p.color or C.white
    b.TextSize   = p.size  or 12
    b.Font       = p.font  or Enum.Font.GothamBold
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
        tw(btn, TI_FAST, { BackgroundColor3 = hoverBg })
    end)
    btn.MouseLeave:Connect(function()
        tw(btn, TI_FAST, { BackgroundColor3 = normBg })
    end)
end

local function pulsingDot(parent, color, sz, pos)
    local dot = mkFrame(parent, {
        bg   = color,
        size = UDim2.new(0, sz, 0, sz),
        pos  = pos,
        z    = 5,
        name = "Dot",
    })
    mkCorner(dot, sz // 2)
    TweenService:Create(dot,
        TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundTransparency = 0.6 }):Play()
    return dot
end

-- ════════════════════════════════════════════════════════════════════════════
--  §13  MAIN UI BUILD
-- ════════════════════════════════════════════════════════════════════════════
local UI = {}

function UI.build(recorder, player, storage)
    local WIN_W, WIN_H = 430, 560

    local sg = Instance.new("ScreenGui")
    sg.Name = "MacroPremiumUI_V3"; sg.DisplayOrder = 999
    sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    sg.Parent = PlayerGui

    -- glow behind window
    local glow = mkFrame(sg, {
        bg   = C.accentDim, trans = 0.88,
        size = UDim2.new(0, WIN_W+60, 0, WIN_H+60),
        pos  = UDim2.new(0.5, -(WIN_W//2+30), 0.5, -(WIN_H//2+30)),
        z    = 0, name = "Glow",
    })
    mkCorner(glow, 24)

    -- main window
    local win = mkFrame(sg, {
        bg   = C.bg,
        size = UDim2.new(0, WIN_W, 0, WIN_H),
        pos  = UDim2.new(0.5, -(WIN_W//2), 0.5, -(WIN_H//2)+30),
        clip = false, z = 1, name = "Window",
    })
    mkCorner(win, 14)
    mkStroke(win, C.border, 1.5)
    win.BackgroundTransparency = 1
    tw(win, TI_SPRING, {
        BackgroundTransparency = 0,
        Position = UDim2.new(0.5, -(WIN_W//2), 0.5, -(WIN_H//2)),
    })

    -- scanline
    local scan = mkFrame(win, {
        bg=C.accent, trans=0.85,
        size=UDim2.new(1,0,0,1), pos=UDim2.new(0,0,0,0), z=20,
    })
    task.spawn(function()
        while sg.Parent do
            scan.Position = UDim2.new(0,0,0,0)
            tw(scan, TweenInfo.new(3, Enum.EasingStyle.Linear),
                { Position = UDim2.new(0,0,1,-1) })
            task.wait(3)
        end
    end)

    -- ── Title bar ──────────────────────────────────────────────────────────
    local titleBar = mkFrame(win, {
        bg=C.surfaceHigh, size=UDim2.new(1,0,0,48),
        pos=UDim2.new(0,0,0,0), z=5, name="TitleBar",
    })
    mkCorner(titleBar, 14)
    mkFrame(titleBar, { -- cover bottom rounded corners
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
        text="Tower Defense · v3.0", color=C.textSecond, size=9,
        font=Enum.Font.Gotham,
        sz=UDim2.new(0,200,0,48), upos=UDim2.new(0,24,0,17), z=6,
    })

    -- FIX indicator badge
    local fixBadge = mkFrame(titleBar, {
        bg=C.success, trans=0, size=UDim2.new(0,64,0,18),
        pos=UDim2.new(1,-160,0.5,-9), z=7, name="FixBadge",
    })
    mkCorner(fixBadge, 9)
    mkLabel(fixBadge, {
        text="FIXED v3", color=C.bg, size=9, font=Enum.Font.GothamBold,
        sz=UDim2.new(1,0,1,0), xalign=Enum.TextXAlignment.Center, z=8,
    })

    -- close
    local closeBtn = mkBtn(titleBar, {
        bg=Color3.fromRGB(220,55,55), text="✕", color=C.white, size=12,
        sz=UDim2.new(0,22,0,22), upos=UDim2.new(1,-30,0.5,-11), z=7, name="Close",
    })
    mkCorner(closeBtn, 6)
    addHover(closeBtn, Color3.fromRGB(220,55,55), Color3.fromRGB(255,80,80))
    closeBtn.MouseButton1Click:Connect(function()
        tw(win,  TI_MED, { BackgroundTransparency=1, Position=UDim2.new(0.5,-(WIN_W//2),0.5,-(WIN_H//2)+30) })
        tw(glow, TI_MED, { BackgroundTransparency=1 })
        task.delay(0.35, function() sg:Destroy() end)
    end)

    -- minimise
    local minBtn = mkBtn(titleBar, {
        bg=Color3.fromRGB(200,160,30), text="−", color=C.white, size=15,
        sz=UDim2.new(0,22,0,22), upos=UDim2.new(1,-56,0.5,-11), z=7, name="Min",
    })
    mkCorner(minBtn, 6)
    addHover(minBtn, Color3.fromRGB(200,160,30), Color3.fromRGB(255,210,40))
    local minimised = false
    minBtn.MouseButton1Click:Connect(function()
        minimised = not minimised
        tw(win, TI_MED, {
            Size = minimised and UDim2.new(0,WIN_W,0,48) or UDim2.new(0,WIN_W,0,WIN_H)
        })
    end)

    -- drag (clamped)
    do
        local drag, dstart, wstart = false, nil, nil
        titleBar.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                drag=true; dstart=inp.Position; wstart=win.Position
            end
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                drag = false
                -- clamp
                local vp = workspace.CurrentCamera.ViewportSize
                local ap = win.AbsolutePosition
                local as = win.AbsoluteSize
                win.Position = UDim2.new(0,
                    math.clamp(ap.X, 0, vp.X - as.X), 0,
                    math.clamp(ap.Y, 0, vp.Y - as.Y))
            end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement
                      or inp.UserInputType == Enum.UserInputType.Touch) then
                local d = inp.Position - dstart
                win.Position = UDim2.new(
                    wstart.X.Scale, wstart.X.Offset + d.X,
                    wstart.Y.Scale, wstart.Y.Offset + d.Y)
            end
        end)
    end

    -- ── Tab bar ────────────────────────────────────────────────────────────
    local TABS = {
        { id="macro",    label="◉ Macro",    accent=C.accent   },
        { id="autoexec", label="⚙ AutoExec", accent=C.violet   },
        { id="log",      label="≡ Log",      accent=C.warning  },
    }
    local activeTab = nil
    local tabBtns   = {}
    local tabPages  = {}

    local tabBar = mkFrame(win, {
        bg=C.surface, size=UDim2.new(1,0,0,38),
        pos=UDim2.new(0,0,0,48), z=5, name="TabBar",
    })
    mkFrame(tabBar, { bg=C.border, size=UDim2.new(1,0,0,1), pos=UDim2.new(0,0,1,-1), z=6 })

    local tabList = Instance.new("UIListLayout")
    tabList.FillDirection = Enum.FillDirection.Horizontal
    tabList.Padding = UDim.new(0,0)
    tabList.Parent  = tabBar

    local function setTab(id)
        for _, td in ipairs(TABS) do
            local pg  = tabPages[td.id]
            local btn = tabBtns[td.id]
            local on  = (td.id == id)
            if pg  then pg.Visible = on end
            if btn then
                tw(btn, TI_FAST, {
                    BackgroundColor3 = on and td.accent or C.surface,
                    TextColor3       = on and C.white   or C.textSecond,
                })
            end
        end
        activeTab = id
    end

    local tabW = WIN_W / #TABS
    for _, td in ipairs(TABS) do
        local btn = mkBtn(tabBar, {
            bg=C.surface, text=td.label, color=C.textSecond,
            size=9, font=Enum.Font.GothamBold,
            sz=UDim2.new(0,tabW,1,0), z=6, name="Tab_"..td.id,
        })
        btn.MouseButton1Click:Connect(function() setTab(td.id) end)
        tabBtns[td.id] = btn

        -- Each tab gets a scrolling container
        local pg = Instance.new("ScrollingFrame")
        pg.BackgroundTransparency = 1
        pg.BorderSizePixel        = 0
        pg.Size                   = UDim2.new(1,0,1,-88)
        pg.Position               = UDim2.new(0,0,0,88)
        pg.CanvasSize             = UDim2.new(0,0,0,0)
        pg.AutomaticCanvasSize    = Enum.AutomaticSize.Y
        pg.ScrollBarThickness     = 3
        pg.ScrollBarImageColor3   = C.accentDim
        pg.ZIndex                 = 3
        pg.Visible                = false
        pg.Name                   = "Page_"..td.id
        pg.Parent                 = win

        local pgList = Instance.new("UIListLayout")
        pgList.FillDirection       = Enum.FillDirection.Vertical
        pgList.HorizontalAlignment = Enum.HorizontalAlignment.Center
        pgList.Padding             = UDim.new(0,5)
        pgList.SortOrder           = Enum.SortOrder.LayoutOrder
        pgList.Parent              = pg

        local pgPad = Instance.new("UIPadding")
        pgPad.PaddingLeft   = UDim.new(0,8)
        pgPad.PaddingRight  = UDim.new(0,8)
        pgPad.PaddingTop    = UDim.new(0,8)
        pgPad.PaddingBottom = UDim.new(0,8)
        pgPad.Parent        = pg

        tabPages[td.id] = pg
    end

    -- ── Status bar ─────────────────────────────────────────────────────────
    local statBar = mkFrame(win, {
        bg=C.surfaceHigh, size=UDim2.new(1,-16,0,42),
        pos=UDim2.new(0,8,0,88), z=4, name="StatBar",
    })
    mkCorner(statBar, 10)
    mkStroke(statBar, C.border, 1)
    -- stat bar sits on top of all tab pages
    statBar.ZIndex = 5

    local function statChip(icon, color, xPos)
        local chip = mkFrame(statBar, {
            bg=C.bg, trans=1,
            size=UDim2.new(0, (WIN_W-16)//3, 1, 0),
            pos=UDim2.new(0, xPos, 0, 0), z=5,
        })
        if xPos > 0 then
            mkFrame(chip, { bg=C.border, size=UDim2.new(0,1,0.5,0), pos=UDim2.new(0,0,0.25,0), z=6 })
        end
        mkLabel(chip, {
            text=icon, color=color, size=14,
            sz=UDim2.new(0,22,1,0), upos=UDim2.new(0,8,0,0),
            xalign=Enum.TextXAlignment.Center, z=6,
        })
        local val = mkLabel(chip, {
            text="0", color=C.textPrimary, size=11, font=Enum.Font.GothamBold,
            sz=UDim2.new(1,-32,1,0), upos=UDim2.new(0,32,0,0), z=6, name="Val",
        })
        return val
    end
    local chipW = (WIN_W-16)//3
    local waveVal  = statChip("⚡", C.accent,   0)
    local timeVal  = statChip("⏱", C.violet,    chipW)
    local moneyVal = statChip("💰", C.success,   chipW*2)

    -- live update loop
    task.spawn(function()
        while sg.Parent do
            if Framework and Framework.tracker then
                local s = Framework.tracker:snapshot()
                waveVal.Text  = "Wave "..s.wave
                timeVal.Text  = string.format("%.0fs", s.gameTime)
                moneyVal.Text = tostring(s.money)
            end
            if Framework and Framework.recorder then
                -- update action count shown in tab
                tabBtns["macro"].Text = "◉ Macro ("..#Framework.recorder.macro..")"
            end
            task.wait(0.4)
        end
    end)

    -- ══════════════════════════════════════════════════════════════════════
    --  §13.1  MACRO TAB CONTENT
    -- ══════════════════════════════════════════════════════════════════════
    local mp = tabPages["macro"]

    -- state badge
    local badgeRow = mkFrame(mp, {
        bg=C.bg, trans=1, size=UDim2.new(1,0,0,32), name="BadgeRow",
    })
    local badge = mkFrame(badgeRow, {
        bg=C.surfaceHigh, size=UDim2.new(0,130,0,26),
        pos=UDim2.new(0,0,0.5,-13), name="Badge",
    })
    mkCorner(badge, 13)
    mkStroke(badge, C.accentDim, 1)
    local bDot   = pulsingDot(badge, C.textDim, 8, UDim2.new(0,10,0.5,-4))
    local bLabel = mkLabel(badge, {
        text="IDLE", color=C.textSecond, size=10, font=Enum.Font.GothamBold,
        sz=UDim2.new(1,-28,1,0), upos=UDim2.new(0,24,0,0), z=4,
    })

    local countChip = mkFrame(badgeRow, {
        bg=C.surfaceHigh, size=UDim2.new(0,160,0,26),
        pos=UDim2.new(0,138,0.5,-13),
    })
    mkCorner(countChip, 13)
    mkStroke(countChip, C.border, 1)
    local countLbl = mkLabel(countChip, {
        text="0 actions", color=C.textSecond, size=10, font=Enum.Font.Gotham,
        sz=UDim2.new(1,0,1,0), xalign=Enum.TextXAlignment.Center, z=4,
    })

    -- ── Fix [1] status indicator
    local saveChip = mkFrame(badgeRow, {
        bg=C.surfaceHigh, size=UDim2.new(0,80,0,26),
        pos=UDim2.new(1,-80,0.5,-13),
    })
    mkCorner(saveChip, 13)
    mkStroke(saveChip, C.border, 1)
    local saveLbl = mkLabel(saveChip, {
        text="💾 Auto", color=C.success, size=9, font=Enum.Font.GothamBold,
        sz=UDim2.new(1,0,1,0), xalign=Enum.TextXAlignment.Center, z=4,
    })

    -- Buttons
    local BTN_DEFS = {
        { name="RecBtn",  text="● REC",   bg=Color3.fromRGB(200,40,40),  hov=Color3.fromRGB(255,70,70),  key="F6" },
        { name="StopBtn", text="■ STOP",  bg=Color3.fromRGB(50,60,90),   hov=Color3.fromRGB(80,95,140),  key="F7" },
        { name="PlayBtn", text="▶ PLAY",  bg=Color3.fromRGB(30,130,80),  hov=Color3.fromRGB(50,190,110), key="F8" },
        { name="SaveBtn", text="⬇ SAVE",  bg=Color3.fromRGB(60,60,110),  hov=Color3.fromRGB(90,90,160),  key="F9" },
        { name="LoadBtn", text="⬆ LOAD",  bg=Color3.fromRGB(60,60,110),  hov=Color3.fromRGB(90,90,160),  key="F10"},
    }
    local btnRefs  = {}
    local btnRow   = mkFrame(mp, {
        bg=C.bg, trans=1, size=UDim2.new(1,0,0,44), name="BtnRow",
    })
    local BW = math.floor((WIN_W - 32) / #BTN_DEFS) - 4
    for i, def in ipairs(BTN_DEFS) do
        local xOff = (i-1) * (BW + 4)
        local b = mkBtn(btnRow, {
            bg=def.bg, text=def.text, color=C.white, size=10,
            sz=UDim2.new(0,BW,0,40), upos=UDim2.new(0,xOff,0,0),
            z=4, name=def.name,
        })
        mkCorner(b, 9)
        mkStroke(b, Color3.new(1,1,1), 1, 0.88)
        addHover(b, def.bg, def.hov)
        mkLabel(b, {
            text=def.key, color=Color3.new(1,1,1), size=8, font=Enum.Font.Code,
            sz=UDim2.new(1,0,0,12), upos=UDim2.new(0,0,1,-12),
            xalign=Enum.TextXAlignment.Center, z=5,
        }).BackgroundTransparency = 1
        btnRefs[def.name] = b
    end

    -- Progress bar
    local progTrack = mkFrame(mp, {
        bg=C.surfaceHigh, size=UDim2.new(1,0,0,6), name="ProgTrack",
    })
    mkCorner(progTrack, 3)
    local progFill = mkFrame(progTrack, {
        bg=C.accent, size=UDim2.new(0,0,1,0), name="Fill",
    })
    mkCorner(progFill, 3)
    local progLbl = mkLabel(mp, {
        text="Ready", color=C.textDim, size=10, font=Enum.Font.Code,
        sz=UDim2.new(1,0,0,14), xalign=Enum.TextXAlignment.Right, z=4,
    })

    -- Step delay slider row
    local sliderRow = mkFrame(mp, {
        bg=C.surfaceHigh, size=UDim2.new(1,0,0,46), name="SliderRow",
    })
    mkCorner(sliderRow, 10)
    mkStroke(sliderRow, C.border, 1)
    mkLabel(sliderRow, {
        text="Step Delay", color=C.textSecond, size=10, font=Enum.Font.Gotham,
        sz=UDim2.new(0,80,1,0), upos=UDim2.new(0,12,0,0), z=4,
    })
    local delayLbl = mkLabel(sliderRow, {
        text="0.10s", color=C.accent, size=10, font=Enum.Font.GothamBold,
        sz=UDim2.new(0,50,1,0), upos=UDim2.new(1,-62,0,0),
        xalign=Enum.TextXAlignment.Right, z=4,
    })
    local sTrack = mkFrame(sliderRow, {
        bg=C.bg, size=UDim2.new(1,-160,0,4), pos=UDim2.new(0,96,0.5,-2),
    })
    mkCorner(sTrack, 2)
    local sFill = mkFrame(sTrack, {
        bg=C.accent, size=UDim2.new(0.1,0,1,0),
    })
    mkCorner(sFill, 2)
    local sThumb = mkFrame(sTrack, {
        bg=C.white, size=UDim2.new(0,12,0,12),
        pos=UDim2.new(0.1,-6,0.5,-6), z=5,
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
            if not drag then return end
            if inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local rel = math.clamp((inp.Position.X - sTrack.AbsolutePosition.X)
                / sTrack.AbsoluteSize.X, 0, 1)
            sFill.Size      = UDim2.new(rel, 0, 1, 0)
            sThumb.Position = UDim2.new(rel, -6, 0.5, -6)
            local v = DMIN + rel * (DMAX - DMIN)
            CONFIG.minActionDelay = v
            delayLbl.Text = string.format("%.2fs", v)
        end)
    end

    -- ── UI Helper functions ────────────────────────────────────────────────
    local function setBadge(text, color, dotColor)
        bLabel.Text           = text
        bLabel.TextColor3     = color or C.textSecond
        bDot.BackgroundColor3 = dotColor or C.textDim
    end

    local function setProgress(frac, text)
        tw(progFill, TI_MED, { Size = UDim2.new(math.clamp(frac,0,1),0,1,0) })
        if text then progLbl.Text = text end
    end

    -- ── Wire macro buttons ─────────────────────────────────────────────────
    btnRefs["RecBtn"].MouseButton1Click:Connect(function()
        if player.playing then
            UI.log("error", "Stop playback first (F7)")
            return
        end
        recorder:startRecording()
        setBadge("● REC", C.danger, C.danger)
        saveLbl.Text      = "💾 Live"
        saveLbl.TextColor3= C.warning
        UI.log("system", "Recording started — actions auto-save after each capture")
        setProgress(0, "Recording…")
    end)

    btnRefs["StopBtn"].MouseButton1Click:Connect(function()
        if recorder.recording then
            local m = recorder:stopRecording()
            setBadge("IDLE", C.textSecond, C.textDim)
            saveLbl.Text       = "💾 Auto"
            saveLbl.TextColor3 = C.success
            countLbl.Text      = #m.." actions"
            UI.log("system", string.format("Stopped — %d actions captured & saved", #m))
            setProgress(0, "Ready")
        elseif player.playing then
            player:stopPlayback()
            setBadge("IDLE", C.textSecond, C.textDim)
            UI.log("system", "Playback stopped by user")
            setProgress(0, "Stopped")
        end
    end)

    btnRefs["PlayBtn"].MouseButton1Click:Connect(function()
        local macro = recorder:getMacro()
        if #macro == 0 then
            UI.log("error", "No macro — record or load first")
            return
        end
        player:playMacro(macro, function(i, total, record)
            setProgress(i/total, string.format("Step %d/%d", i, total))
            if record then
                UI.log(record.action, string.format(
                    "w=%d t=%.1fs slot=%s",
                    record.wave or 0, record.time or 0, tostring(record.slot)))
            else
                setBadge("IDLE", C.textSecond, C.textDim)
                setProgress(1, "Complete ✓")
                UI.log("system", "Playback finished")
            end
        end)
        setBadge("▶ PLAYING", C.success, C.success)
        UI.log("system", "Playback started — "..#macro.." actions")
    end)

    btnRefs["SaveBtn"].MouseButton1Click:Connect(function()
        local ok = storage.save(recorder:getMacro())
        if ok then
            UI.log("system", "Saved → TDMacro_save.json")
            setBadge("SAVED ✓", C.success, C.success)
            task.delay(2, function()
                if not recorder.recording then setBadge("IDLE",C.textSecond,C.textDim) end
            end)
        else
            UI.log("error", "Save failed — check console")
        end
    end)

    btnRefs["LoadBtn"].MouseButton1Click:Connect(function()
        local macro = storage.load()
        if macro then
            recorder:setMacro(macro)
            countLbl.Text = #macro.." actions"
            UI.log("system", "Loaded "..#macro.." actions from TDMacro_save.json")
            setBadge("LOADED ✓", C.accent, C.accent)
            task.delay(2, function() setBadge("IDLE",C.textSecond,C.textDim) end)
        else
            UI.log("error", "Load failed — file not found")
        end
    end)

    -- ── Notify recorder captures into UI ──────────────────────────────────
    recorder._onCapture = function(record)
        local pos = record.position
        local posStr = pos
            and string.format("(%.0f,%.0f,%.0f)", pos.x, pos.y, pos.z) or "?"
        UI.log(record.action, string.format(
            "pos=%s slot=%s uid=%s", posStr,
            tostring(record.slot), tostring(record.towerUID)))
        countLbl.Text = #recorder.macro.." actions"
        saveLbl.Text       = "💾 Saved"
        saveLbl.TextColor3 = C.success
        task.delay(1, function()
            saveLbl.Text       = "💾 Live"
            saveLbl.TextColor3 = C.warning
        end)
    end

    -- ══════════════════════════════════════════════════════════════════════
    --  §13.2  AUTO-EXECUTE TAB CONTENT
    -- ══════════════════════════════════════════════════════════════════════
    local ap = tabPages["autoexec"]

    -- Info banner
    local infoBanner = mkFrame(ap, {
        bg=C.surfaceHigh, size=UDim2.new(1,0,0,36), name="InfoBanner",
    })
    mkCorner(infoBanner, 9)
    mkStroke(infoBanner, C.violet, 1, 0.5)
    mkLabel(infoBanner, {
        text="⚡  Write Luau · access Framework global · runs in protected thread",
        color=C.textSecond, size=10, font=Enum.Font.Gotham,
        sz=UDim2.new(1,-12,1,0), upos=UDim2.new(0,8,0,0),
        wrap=true, z=4,
    })

    -- Preset dropdown row
    local presetRow = mkFrame(ap, {
        bg=C.surfaceHigh, size=UDim2.new(1,0,0,36), name="PresetRow",
    })
    mkCorner(presetRow, 9)
    mkStroke(presetRow, C.border, 1)
    mkLabel(presetRow, {
        text="Preset:", color=C.textSecond, size=10, font=Enum.Font.Gotham,
        sz=UDim2.new(0,55,1,0), upos=UDim2.new(0,10,0,0), z=4,
    })

    local presetBtn = mkBtn(presetRow, {
        bg=C.bg, text=AutoExec.PRESETS[1].name, color=C.textPrimary,
        size=10, font=Enum.Font.Gotham,
        sz=UDim2.new(1,-68,0,26), upos=UDim2.new(0,58,0.5,-13),
        z=5, name="PresetBtn",
    })
    mkCorner(presetBtn, 6)
    mkStroke(presetBtn, C.border, 1)

    -- Dropdown popup
    local dropdown = mkFrame(ap, {
        bg=C.surfaceHigh, size=UDim2.new(1,0,0,0),
        pos=UDim2.new(0,0,0,0), z=20, clip=true, name="Dropdown",
    })
    mkCorner(dropdown, 9)
    mkStroke(dropdown, C.accentDim, 1)
    dropdown.Visible = false

    local ddList = Instance.new("UIListLayout")
    ddList.FillDirection = Enum.FillDirection.Vertical
    ddList.Padding = UDim.new(0, 2)
    ddList.Parent  = dropdown

    local ddPad = Instance.new("UIPadding")
    ddPad.PaddingLeft = UDim.new(0,4); ddPad.PaddingRight  = UDim.new(0,4)
    ddPad.PaddingTop  = UDim.new(0,4); ddPad.PaddingBottom = UDim.new(0,4)
    ddPad.Parent = dropdown

    local dropOpen = false
    local codeBox  -- forward ref

    for _, preset in ipairs(AutoExec.PRESETS) do
        local item = mkBtn(dropdown, {
            bg=C.surfaceHigh, text=preset.name, color=C.textPrimary,
            size=10, font=Enum.Font.Gotham,
            sz=UDim2.new(1,0,0,26), z=21, name="DDItem",
        })
        mkCorner(item, 6)
        addHover(item, C.surfaceHigh, Color3.fromRGB(28,34,62))
        item.MouseButton1Click:Connect(function()
            presetBtn.Text = preset.name
            if preset.code ~= "" and codeBox then
                codeBox.Text = preset.code
            end
            dropdown.Visible = false
            dropOpen = false
            tw(dropdown, TI_MED, { Size=UDim2.new(1,0,0,0) })
        end)
    end

    presetBtn.MouseButton1Click:Connect(function()
        dropOpen = not dropOpen
        dropdown.Visible = dropOpen
        local targetH = dropOpen and (#AutoExec.PRESETS * 28 + 8) or 0
        tw(dropdown, TI_MED, { Size=UDim2.new(1,0,0,targetH) })
    end)

    -- Code editor TextBox
    local editorWrapper = mkFrame(ap, {
        bg=Color3.fromRGB(6,8,14), size=UDim2.new(1,0,0,200), name="EditorWrapper",
    })
    mkCorner(editorWrapper, 9)
    mkStroke(editorWrapper, C.border, 1)

    -- line-number strip
    local lineStrip = mkFrame(editorWrapper, {
        bg=Color3.fromRGB(12,15,28), size=UDim2.new(0,28,1,0),
        pos=UDim2.new(0,0,0,0), z=3, name="LineStrip",
    })
    mkStroke(lineStrip, C.border, 1)

    codeBox = Instance.new("TextBox")
    codeBox.BackgroundTransparency = 1
    codeBox.TextColor3   = C.codeGreen
    codeBox.PlaceholderText = "-- write your Luau script here\n-- Framework global is available"
    codeBox.PlaceholderColor3 = C.textDim
    codeBox.TextSize     = 11
    codeBox.Font         = Enum.Font.Code
    codeBox.MultiLine    = true
    codeBox.ClearTextOnFocus = false
    codeBox.TextXAlignment = Enum.TextXAlignment.Left
    codeBox.TextYAlignment = Enum.TextYAlignment.Top
    codeBox.Size         = UDim2.new(1,-36,1,-8)
    codeBox.Position     = UDim2.new(0,32,0,4)
    codeBox.ZIndex       = 4
    codeBox.Name         = "CodeBox"
    codeBox.Parent       = editorWrapper

    -- load saved script
    local savedCode = AutoExec.loadSaved()
    if savedCode ~= "" then codeBox.Text = savedCode end

    -- update line numbers as text changes
    codeBox:GetPropertyChangedSignal("Text"):Connect(function()
        local lines = 0
        for _ in (codeBox.Text.."\n"):gmatch("[^\n]*\n") do lines += 1 end
        local numText = ""
        for i = 1, math.max(lines, 1) do
            numText = numText .. tostring(i) .. "\n"
        end
        -- we use a label inside lineStrip for line numbers
        local numLbl = lineStrip:FindFirstChild("LineNums")
        if not numLbl then
            numLbl = mkLabel(lineStrip, {
                text=numText, color=C.textDim, size=11, font=Enum.Font.Code,
                sz=UDim2.new(1,0,1,0), upos=UDim2.new(0,2,0,4),
                xalign=Enum.TextXAlignment.Right, yalign=Enum.TextYAlignment.Top,
                wrap=false, z=5, name="LineNums",
            })
        else
            numLbl.Text = numText
        end
    end)

    -- Run / Stop / Clear buttons
    local execBtnRow = mkFrame(ap, {
        bg=C.bg, trans=1, size=UDim2.new(1,0,0,36), name="ExecBtnRow",
    })
    local listExec = Instance.new("UIListLayout")
    listExec.FillDirection = Enum.FillDirection.Horizontal
    listExec.Padding = UDim.new(0,6)
    listExec.Parent  = execBtnRow

    local function execBtn(text, bg, hov)
        local b = mkBtn(execBtnRow, {
            bg=bg, text=text, color=C.white, size=11,
            sz=UDim2.new(0,0,0,34), z=5,
        })
        b.AutomaticSize = Enum.AutomaticSize.X
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0,14); pad.PaddingRight = UDim.new(0,14)
        pad.Parent = b
        mkCorner(b, 8)
        addHover(b, bg, hov)
        return b
    end

    local runBtn   = execBtn("▶  RUN",   Color3.fromRGB(30,140,80),  Color3.fromRGB(50,200,110))
    local stopEBtn = execBtn("■  STOP",  Color3.fromRGB(50,60,90),   Color3.fromRGB(80,95,140))
    local clearBtn = execBtn("✕  CLEAR", Color3.fromRGB(80,30,30),   Color3.fromRGB(140,50,50))
    local saveEBtn = execBtn("💾 SAVE",  Color3.fromRGB(60,60,110),  Color3.fromRGB(90,90,160))

    -- Status label for auto-exec
    local execStatus = mkLabel(ap, {
        text="● Idle", color=C.textDim, size=10, font=Enum.Font.Code,
        sz=UDim2.new(1,0,0,18), xalign=Enum.TextXAlignment.Left, z=4,
    })

    runBtn.MouseButton1Click:Connect(function()
        local code = codeBox.Text
        if not code or code:gsub("%s","") == "" then
            UI.log("error", "[AutoExec] Nothing to run")
            return
        end
        execStatus.Text       = "● Running…"
        execStatus.TextColor3 = C.warning
        tw(runBtn, TI_FAST, { BackgroundColor3 = Color3.fromRGB(50,200,110) })

        local ok, err = AutoExec.run(code, function(errMsg)
            execStatus.Text       = "✖ Error"
            execStatus.TextColor3 = C.danger
            UI.log("error", errMsg)
            tw(runBtn, TI_FAST, { BackgroundColor3 = Color3.fromRGB(30,140,80) })
        end)

        if ok then
            UI.log("system", "[AutoExec] Script started")
        else
            execStatus.Text       = "✖ Compile Error"
            execStatus.TextColor3 = C.danger
            UI.log("error", "[AutoExec] "..tostring(err))
        end
    end)

    stopEBtn.MouseButton1Click:Connect(function()
        AutoExec.stop()
        execStatus.Text       = "● Idle"
        execStatus.TextColor3 = C.textDim
        tw(runBtn, TI_FAST, { BackgroundColor3 = Color3.fromRGB(30,140,80) })
        UI.log("system", "[AutoExec] Script stopped")
    end)

    clearBtn.MouseButton1Click:Connect(function()
        codeBox.Text = ""
        UI.log("system", "[AutoExec] Editor cleared")
    end)

    saveEBtn.MouseButton1Click:Connect(function()
        Util.writeFile(CONFIG.autoExecFile, codeBox.Text)
        execStatus.Text       = "💾 Saved"
        execStatus.TextColor3 = C.success
        task.delay(2, function()
            execStatus.Text       = "● Idle"
            execStatus.TextColor3 = C.textDim
        end)
        UI.log("system", "[AutoExec] Script saved → "..CONFIG.autoExecFile)
    end)

    -- ══════════════════════════════════════════════════════════════════════
    --  §13.3  LOG TAB CONTENT
    -- ══════════════════════════════════════════════════════════════════════
    local lp = tabPages["log"]

    -- log clear button
    local logTopRow = mkFrame(lp, {
        bg=C.bg, trans=1, size=UDim2.new(1,0,0,28), name="LogTopRow",
    })
    local clearLogBtn = mkBtn(logTopRow, {
        bg=Color3.fromRGB(60,40,40), text="✕  Clear Log", color=C.textSecond,
        size=10, font=Enum.Font.Gotham,
        sz=UDim2.new(0,100,0,24), upos=UDim2.new(1,-100,0.5,-12),
        z=4, name="ClearLog",
    })
    mkCorner(clearLogBtn, 6)
    addHover(clearLogBtn, Color3.fromRGB(60,40,40), Color3.fromRGB(120,50,50))

    -- Log scroll frame
    local logScroll = Instance.new("ScrollingFrame")
    logScroll.BackgroundColor3       = C.surfaceHigh
    logScroll.BackgroundTransparency = 0
    logScroll.BorderSizePixel        = 0
    logScroll.Size                   = UDim2.new(1,0,0,340)
    logScroll.CanvasSize             = UDim2.new(0,0,0,0)
    logScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    logScroll.ScrollBarThickness     = 3
    logScroll.ScrollBarImageColor3   = C.accentDim
    logScroll.ZIndex                 = 3
    logScroll.Name                   = "LogScroll"
    logScroll.Parent                 = lp
    mkCorner(logScroll, 10)
    mkStroke(logScroll, C.border, 1)

    local logListLayout = Instance.new("UIListLayout")
    logListLayout.FillDirection  = Enum.FillDirection.Vertical
    logListLayout.Padding        = UDim.new(0,1)
    logListLayout.SortOrder      = Enum.SortOrder.LayoutOrder
    logListLayout.Parent         = logScroll

    local logInnerPad = Instance.new("UIPadding")
    logInnerPad.PaddingLeft   = UDim.new(0,8)
    logInnerPad.PaddingRight  = UDim.new(0,8)
    logInnerPad.PaddingTop    = UDim.new(0,4)
    logInnerPad.PaddingBottom = UDim.new(0,4)
    logInnerPad.Parent        = logScroll

    local logCount = 0
    local MAX_LOG  = 120

    local LOG_COLORS = {
        place   = C.success,
        upgrade = C.accent,
        ability = C.violet,
        sell    = C.warning,
        system  = C.textSecond,
        error   = C.danger,
    }
    local LOG_ICONS = {
        place="⬛", upgrade="⬆", ability="✦", sell="💲", system="◈", error="✖",
    }

    local function addLog(actionType, message)
        logCount += 1
        if logCount > MAX_LOG then
            local oldest = logScroll:FindFirstChildWhichIsA("Frame")
            if oldest then oldest:Destroy(); logCount -= 1 end
        end

        local color = LOG_COLORS[actionType] or C.textSecond
        local icon  = LOG_ICONS[actionType]  or "·"

        local row = mkFrame(logScroll, {
            bg   = logCount%2==0 and C.surfaceHigh or Color3.fromRGB(16,21,38),
            size = UDim2.new(1,0,0,22), z=4, name="Row"..logCount,
        })
        row.LayoutOrder = logCount
        row.BackgroundTransparency = 1
        tw(row, TI_FAST, { BackgroundTransparency = 0 })

        mkLabel(row, {
            text=icon.." "..string.upper(actionType),
            color=color, size=10, font=Enum.Font.GothamBold,
            sz=UDim2.new(0,72,1,0), z=5,
        })
        mkLabel(row, {
            text=message, color=C.textSecond, size=10, font=Enum.Font.Code,
            sz=UDim2.new(1,-76,1,0), upos=UDim2.new(0,76,0,0),
            xalign=Enum.TextXAlignment.Left, wrap=false, z=5,
        })
        task.defer(function()
            if logScroll and logScroll.Parent then
                logScroll.CanvasPosition =
                    Vector2.new(0, logScroll.AbsoluteCanvasSize.Y)
            end
        end)
    end

    clearLogBtn.MouseButton1Click:Connect(function()
        for _, c in ipairs(logScroll:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        logCount = 0
    end)

    UI.log = addLog   -- expose globally

    -- ── Keyboard shortcuts ────────────────────────────────────────────────
    local keyBinds = {
        [Enum.KeyCode.F6]  = function() btnRefs["RecBtn"].MouseButton1Click:Fire()  end,
        [Enum.KeyCode.F7]  = function() btnRefs["StopBtn"].MouseButton1Click:Fire() end,
        [Enum.KeyCode.F8]  = function() btnRefs["PlayBtn"].MouseButton1Click:Fire() end,
        [Enum.KeyCode.F9]  = function() btnRefs["SaveBtn"].MouseButton1Click:Fire() end,
        [Enum.KeyCode.F10] = function() btnRefs["LoadBtn"].MouseButton1Click:Fire() end,
    }
    UserInputService.InputBegan:Connect(function(inp, processed)
        if processed then return end
        local fn = keyBinds[inp.KeyCode]
        if fn then task.spawn(fn) end
    end)

    setTab("macro")
    addLog("system", "Framework v3 ready — recording fix active")

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

    -- FIX [2]: hook remotes FIRST, then register listeners
    detector:init()

    -- FIX [2]: register capture listeners ONCE (not inside startRecording)
    recorder:attachListeners()

    -- FIX [1]: try to restore last session's auto-save
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
        UI.log("system", string.format(
            "Restored %d actions from previous session ✓", #recorder.macro))
    end

    return Framework
end

Framework = init()
