--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║           TOWER DEFENSE MACRO FRAMEWORK — CLIENT-SIDE LUAU SCRIPT           ║
║    Compatible with: All Star Tower Defense, Anime Guardians, and similar     ║
║                                                                              ║
║  HOW IT WORKS (overview):                                                    ║
║  1. RemoteEventDetector hooks into the game's network layer by wrapping      ║
║     the FireServer method on known placement/upgrade/sell RemoteEvents.      ║
║  2. MacroRecorder captures every hooked call and stores world-space          ║
║     Vector3 positions + the original RemoteEvent arguments verbatim.        ║
║  3. GameTracker reads wave, timer, and money values from common GUI /        ║
║     ReplicatedStorage paths (update the path table for your game).          ║
║  4. MacroPlayer replays stored actions by re-firing the same RemoteEvents    ║
║     with the same arguments — completely camera-independent.                 ║
║  5. InputHandler binds F6–F10 for record / stop / play / save / load.       ║
╚══════════════════════════════════════════════════════════════════════════════╝
--]]

-- ─────────────────────────────────────────────────────────────────────────────
--  SERVICES
-- ─────────────────────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")  -- used for JSON encode/decode

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────────────────────────────────────────
--  CONFIGURATION  ◄── Edit these paths to match the specific game you target
-- ─────────────────────────────────────────────────────────────────────────────
local CONFIG = {
    -- ── RemoteEvent search roots (searched in order) ──────────────────────
    remoteSearchRoots = {
        ReplicatedStorage,
        game:GetService("Workspace"),
        LocalPlayer:WaitForChild("PlayerScripts"),
    },

    -- ── Known RemoteEvent name patterns per action type ───────────────────
    --    Each entry is a list of candidate names tried in order.
    --    The detector will also do a deep search if none match directly.
    remoteNames = {
        place   = { "PlaceTower",   "placeTower",   "Place",   "TowerPlace"  },
        upgrade = { "UpgradeTower", "upgradeTower", "Upgrade", "TowerUpgrade"},
        ability = { "UseAbility",   "Ability",      "TowerAbility"           },
        sell    = { "SellTower",    "sellTower",    "Sell",    "TowerSell"   },
    },

    -- ── GUI paths for game-state values ──────────────────────────────────
    --    Provide multiple candidates; the tracker tries each until one works.
    guiPaths = {
        wave  = {
            "PlayerGui.GameGui.WaveLabel",
            "PlayerGui.ScreenGui.WaveFrame.WaveLabel",
            "PlayerGui.Main.Wave",
        },
        money = {
            "PlayerGui.GameGui.MoneyLabel",
            "PlayerGui.ScreenGui.MoneyFrame.MoneyLabel",
            "PlayerGui.Main.Money",
        },
        timer = {
            "PlayerGui.GameGui.TimerLabel",
            "PlayerGui.ScreenGui.TimerLabel",
        },
    },

    -- ── ReplicatedStorage paths for game-state values (fallback) ─────────
    rsPaths = {
        wave  = { "GameData.Wave", "GameState.CurrentWave" },
        money = { "GameData.Money", "PlayerData.Money"     },
    },

    -- ── Playback timing tolerance (seconds) ──────────────────────────────
    timeTolerance  = 0.5,

    -- ── Minimum delay between replayed actions (seconds) ─────────────────
    minActionDelay = 0.1,

    -- ── Save slot (uses a datastore-safe key stored in a BindableEvent hack)
    saveKey = "TDMacroSave_v1",
}

-- ─────────────────────────────────────────────────────────────────────────────
--  UTILITIES
-- ─────────────────────────────────────────────────────────────────────────────
local Util = {}

--- Safely index a dot-separated path string from a root object.
--- e.g. Util.resolvePath(game, "PlayerGui.GameGui.WaveLabel")
function Util.resolvePath(root, path)
    local obj = root
    for part in path:gmatch("[^%.]+") do
        if typeof(obj) ~= "Instance" then return nil end
        obj = obj:FindFirstChild(part)
        if not obj then return nil end
    end
    return obj
end

--- Try a list of dot-path strings from multiple roots; return first valid Instance.
function Util.findFirst(roots, pathList)
    for _, pathStr in ipairs(pathList) do
        -- pathStr may be absolute (starts with "PlayerGui") — resolve from game
        local obj = Util.resolvePath(game, pathStr)
        if obj then return obj end
        -- also try each root directly
        for _, root in ipairs(roots) do
            local rel = Util.resolvePath(root, pathStr)
            if rel then return rel end
        end
    end
    return nil
end

--- Deep-search an Instance tree for a RemoteEvent whose name matches any in nameList.
function Util.deepFindRemote(root, nameList)
    local nameSet = {}
    for _, n in ipairs(nameList) do nameSet[n:lower()] = true end

    local function recurse(inst)
        for _, child in ipairs(inst:GetChildren()) do
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

--- Generate a short unique ID string (no HttpService needed).
local _idCounter = 0
function Util.newId()
    _idCounter += 1
    return string.format("T%05d_%d", _idCounter, os.clock() * 1000 % 100000 // 1)
end

--- Parse a number out of a string like "Wave 3", "$1,200", "1200 Gold", etc.
function Util.parseNumber(text)
    if not text then return 0 end
    local s = tostring(text):gsub(",", ""):match("%-?%d+%.?%d*")
    return tonumber(s) or 0
end

--- Read a TextLabel's text and parse a number from it.
function Util.readGuiNumber(labelInst)
    if not labelInst then return 0 end
    if labelInst:IsA("TextLabel") or labelInst:IsA("TextBox") then
        return Util.parseNumber(labelInst.Text)
    end
    return 0
end

--- Serialize a Vector3 to a plain table for JSON storage.
function Util.vec3ToTable(v)
    return { x = v.X, y = v.Y, z = v.Z }
end

--- Deserialize a plain table back to a Vector3.
function Util.tableToVec3(t)
    return Vector3.new(t.x or 0, t.y or 0, t.z or 0)
end

--- Deep-copy a value (handles tables and Vector3; everything else by reference).
function Util.deepCopy(v)
    if type(v) == "table" then
        local copy = {}
        for k, val in pairs(v) do copy[Util.deepCopy(k)] = Util.deepCopy(val) end
        return copy
    end
    return v
end

-- ─────────────────────────────────────────────────────────────────────────────
--  REMOTE EVENT DETECTOR
--  Locates tower action RemoteEvents and wraps FireServer so we can intercept
--  every call transparently.
-- ─────────────────────────────────────────────────────────────────────────────
local RemoteEventDetector = {}
RemoteEventDetector.__index = RemoteEventDetector

function RemoteEventDetector.new()
    local self = setmetatable({}, RemoteEventDetector)
    self.remotes    = {}      -- { place=Remote, upgrade=Remote, ability=Remote, sell=Remote }
    self.hooks      = {}      -- { [actionType] = original FireServer fn }
    self.listeners  = {}      -- { [actionType] = list of callback(args) functions }
    return self
end

--- Search all configured roots for a RemoteEvent matching actionType.
function RemoteEventDetector:findRemote(actionType)
    local nameList = CONFIG.remoteNames[actionType] or {}
    for _, root in ipairs(CONFIG.remoteSearchRoots) do
        -- 1. Direct children of root
        for _, name in ipairs(nameList) do
            local r = root:FindFirstChild(name, true)  -- recursive
            if r and r:IsA("RemoteEvent") then
                return r
            end
        end
        -- 2. Deep search with case-insensitive name matching
        local found = Util.deepFindRemote(root, nameList)
        if found then return found end
    end
    return nil
end

--- Hook a RemoteEvent so every FireServer call is intercepted.
---   callback(actionType, remoteEvent, args) is called before the original.
function RemoteEventDetector:hookRemote(actionType, remote, callback)
    if not remote then return end

    local originalFireServer = remote.FireServer
    -- Store original so we can unhook later and still fire normally
    self.hooks[actionType] = originalFireServer

    -- Replace FireServer with our interceptor
    -- NOTE: Using __newindex on the metatable won't work for locked Roblox objects;
    --       instead we use a BindableEvent trick or the getrawmetatable exploit.
    --       In exploit environments (e.g. Synapse X, KRNL) getrawmetatable is available.
    local mt = getrawmetatable and getrawmetatable(remote)
    if mt then
        -- Exploit-environment hook (most executors support this)
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
        -- Fallback: wrap via a connection on OnClientEvent won't help for outbound;
        -- in standard Studio / test environments we can only use a proxy table.
        -- This path is provided for testing in Roblox Studio (no exploit context).
        warn("[MacroFramework] getrawmetatable unavailable — using Studio-safe proxy. "
           .."FireServer interception will NOT work in a live exploit context without getrawmetatable.")
    end

    self.remotes[actionType] = remote
    print(string.format("[RemoteEventDetector] Hooked '%s' → %s", actionType, remote:GetFullName()))
end

--- Register a listener that is called when a specific action fires.
function RemoteEventDetector:onAction(actionType, callback)
    if not self.listeners[actionType] then
        self.listeners[actionType] = {}
    end
    table.insert(self.listeners[actionType], callback)
end

--- Internal: fire registered listeners for an action.
function RemoteEventDetector:_dispatch(actionType, remote, args)
    local list = self.listeners[actionType]
    if not list then return end
    for _, cb in ipairs(list) do
        task.spawn(cb, actionType, remote, args)
    end
end

--- Locate all remotes and install hooks; call once at startup.
function RemoteEventDetector:init()
    for actionType, _ in pairs(CONFIG.remoteNames) do
        local remote = self:findRemote(actionType)
        if remote then
            self:hookRemote(actionType, remote, function(aType, rem, args)
                self:_dispatch(aType, rem, args)
            end)
        else
            warn(string.format("[RemoteEventDetector] Could not find remote for action '%s'. "
                .."Update CONFIG.remoteNames to match this game.", actionType))
        end
    end
end

--- Get the detected RemoteEvent for an action type (may be nil if not found).
function RemoteEventDetector:getRemote(actionType)
    return self.remotes[actionType]
end

-- ─────────────────────────────────────────────────────────────────────────────
--  GAME STATE TRACKER
--  Reads wave number, player money, and game timer from GUI / ReplicatedStorage.
-- ─────────────────────────────────────────────────────────────────────────────
local GameTracker = {}
GameTracker.__index = GameTracker

function GameTracker.new()
    local self = setmetatable({}, GameTracker)
    self.wave      = 0
    self.money     = 0
    self.gameTime  = 0     -- seconds since game start (from timer label or os.clock)
    self._startClock = os.clock()
    self._guiCache = {}    -- cache resolved GUI instances
    self._conn     = nil
    return self
end

--- Resolve and cache a GUI label by key ("wave", "money", "timer").
function GameTracker:_getLabel(key)
    if self._guiCache[key] then return self._guiCache[key] end
    local paths = CONFIG.guiPaths[key]
    if paths then
        local inst = Util.findFirst({ game }, paths)
        if inst then
            self._guiCache[key] = inst
            return inst
        end
    end
    return nil
end

--- Read current wave from GUI or ReplicatedStorage.
function GameTracker:readWave()
    -- Try GUI label
    local label = self:_getLabel("wave")
    if label then
        local n = Util.readGuiNumber(label)
        if n > 0 then self.wave = n; return n end
    end
    -- Try ReplicatedStorage value objects
    for _, path in ipairs(CONFIG.rsPaths.wave or {}) do
        local obj = Util.resolvePath(game, path)
        if obj and obj:IsA("IntValue") or (obj and obj:IsA("NumberValue")) then
            self.wave = obj.Value; return obj.Value
        end
    end
    return self.wave
end

--- Read current money from GUI or ReplicatedStorage.
function GameTracker:readMoney()
    local label = self:_getLabel("money")
    if label then
        local n = Util.readGuiNumber(label)
        if n >= 0 then self.money = n; return n end
    end
    for _, path in ipairs(CONFIG.rsPaths.money or {}) do
        local obj = Util.resolvePath(game, path)
        if obj then self.money = obj.Value; return obj.Value end
    end
    return self.money
end

--- Read game timer (seconds). Falls back to os.clock delta if GUI not found.
function GameTracker:readTime()
    local label = self:_getLabel("timer")
    if label then
        local n = Util.readGuiNumber(label)
        if n > 0 then self.gameTime = n; return n end
    end
    -- Fallback: elapsed wall-clock time since GameTracker was created
    self.gameTime = os.clock() - self._startClock
    return self.gameTime
end

--- Snapshot all state at once — call this when recording each action.
function GameTracker:snapshot()
    return {
        wave     = self:readWave(),
        money    = self:readMoney(),
        gameTime = self:readTime(),
    }
end

--- Start a lightweight polling loop (every 0.5s) to keep values fresh.
function GameTracker:startPolling()
    if self._conn then return end
    local lastTick = 0
    self._conn = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - lastTick < 0.5 then return end
        lastTick = now
        self:readWave()
        self:readMoney()
        self:readTime()
    end)
end

function GameTracker:stopPolling()
    if self._conn then self._conn:Disconnect(); self._conn = nil end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  PLACEMENT DETECTOR
--  Specialised sub-module that extracts the world-space Vector3 position from
--  a placement RemoteEvent call and maps placed models to tower IDs.
-- ─────────────────────────────────────────────────────────────────────────────
local PlacementDetector = {}
PlacementDetector.__index = PlacementDetector

function PlacementDetector.new()
    local self = setmetatable({}, PlacementDetector)
    -- Map from tower unique ID → { model=Instance, position=Vector3, ... }
    self.activeTowers = {}
    return self
end

--- Extract position from RemoteEvent args.
---   Most tower defense games pass position as the first or second argument.
---   This function tries common patterns and returns the first Vector3 found.
function PlacementDetector:extractPosition(args)
    for _, arg in ipairs(args) do
        if typeof(arg) == "Vector3" then
            return arg
        end
        -- Some games pass a CFrame
        if typeof(arg) == "CFrame" then
            return arg.Position
        end
    end
    -- Some games pass x, y, z as separate numbers
    if #args >= 3 and type(args[1]) == "number"
        and type(args[2]) == "number" and type(args[3]) == "number" then
        return Vector3.new(args[1], args[2], args[3])
    end
    return nil
end

--- Extract the slot / unit index from RemoteEvent args (usually an integer).
function PlacementDetector:extractSlot(args)
    for i = #args, 1, -1 do  -- slot is often last
        if type(args[i]) == "number" and args[i] == math.floor(args[i])
            and args[i] >= 1 and args[i] <= 10 then
            return args[i]
        end
    end
    return nil
end

--- Extract a tower model reference if the game passes an instance in args.
function PlacementDetector:extractTowerModel(args)
    for _, arg in ipairs(args) do
        if typeof(arg) == "Instance" and arg:IsA("Model") then
            return arg
        end
    end
    return nil
end

--- Register a newly placed tower with a generated unique ID.
---   Returns the unique ID string.
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

--- Find the active tower whose position is closest to a given Vector3.
---   Used to resolve upgrade / sell targets when only position is available.
function PlacementDetector:findNearestTower(pos, maxDist)
    maxDist = maxDist or 3
    local best, bestDist = nil, maxDist
    for uid, data in pairs(self.activeTowers) do
        local d = (data.position - pos).Magnitude
        if d < bestDist then best = uid; bestDist = d end
    end
    return best
end

--- Remove a tower by UID (called on sell).
function PlacementDetector:removeTower(uid)
    self.activeTowers[uid] = nil
end

-- ─────────────────────────────────────────────────────────────────────────────
--  MACRO RECORDER
--  Listens to RemoteEventDetector dispatches and stores structured action records.
-- ─────────────────────────────────────────────────────────────────────────────
local MacroRecorder = {}
MacroRecorder.__index = MacroRecorder

function MacroRecorder.new(detector, tracker, placementDet)
    local self = setmetatable({}, MacroRecorder)
    self.detector      = detector       -- RemoteEventDetector
    self.tracker       = tracker        -- GameTracker
    self.placement     = placementDet   -- PlacementDetector
    self.recording     = false
    self.macro         = {}             -- list of action records
    self._connections  = {}
    return self
end

--- Build a full action record from raw RemoteEvent args and game state.
function MacroRecorder:_buildRecord(actionType, args)
    local state    = self.tracker:snapshot()
    local position = self.placement:extractPosition(args)
    local slot     = self.placement:extractSlot(args)

    -- Serialise args for storage: Vector3 → plain table, everything else as-is
    local safeArgs = {}
    for _, v in ipairs(args) do
        if typeof(v) == "Vector3" then
            table.insert(safeArgs, { __type = "Vector3", data = Util.vec3ToTable(v) })
        elseif typeof(v) == "CFrame" then
            local p, r = v.Position, { v:ToEulerAnglesXYZ() }
            table.insert(safeArgs, { __type = "CFrame",
                pos = Util.vec3ToTable(p), rx = r[1], ry = r[2], rz = r[3] })
        elseif typeof(v) == "Instance" then
            -- Store path and name; cannot JSON-serialise instances
            table.insert(safeArgs, { __type = "Instance",
                name = v.Name, path = v:GetFullName() })
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
        unit       = nil,          -- populated below if discoverable
        towerUID   = nil,
        position   = position and Util.vec3ToTable(position) or nil,
        remoteArgs = safeArgs,
    }

    -- For placements, register the tower and grab its UID
    if actionType == "place" and position then
        local model = self.placement:extractTowerModel(args)
        local uid   = self.placement:registerTower(position, slot, model)
        record.towerUID = uid
        -- Try to infer unit name from model or args
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

--- Start recording. Attaches listeners to the detector.
function MacroRecorder:startRecording()
    if self.recording then
        warn("[MacroRecorder] Already recording.")
        return
    end
    self.recording = true
    self.macro = {}
    print("[MacroRecorder] ▶ Recording started.")

    -- Register listeners for every action type
    for _, actionType in ipairs({ "place", "upgrade", "ability", "sell" }) do
        self.detector:onAction(actionType, function(aType, remote, args)
            if not self.recording then return end
            local record = self:_buildRecord(aType, args)
            table.insert(self.macro, record)
            print(string.format(
                "[MacroRecorder] Captured %s | wave=%d | time=%.1fs | slot=%s | uid=%s",
                aType, record.wave, record.time,
                tostring(record.slot), tostring(record.towerUID)
            ))
        end)
    end
end

--- Stop recording. Returns the recorded macro table.
function MacroRecorder:stopRecording()
    if not self.recording then
        warn("[MacroRecorder] Not currently recording.")
        return self.macro
    end
    self.recording = false
    print(string.format("[MacroRecorder] ■ Recording stopped. %d actions captured.", #self.macro))
    return self.macro
end

--- Return the current macro table (shallow copy).
function MacroRecorder:getMacro()
    return Util.deepCopy(self.macro)
end

--- Replace the internal macro table (used after loading from storage).
function MacroRecorder:setMacro(macroTable)
    self.macro = macroTable
end

-- ─────────────────────────────────────────────────────────────────────────────
--  MACRO PLAYER
--  Replays a macro table by waiting for matching game state and firing remotes.
-- ─────────────────────────────────────────────────────────────────────────────
local MacroPlayer = {}
MacroPlayer.__index = MacroPlayer

function MacroPlayer.new(detector, tracker)
    local self = setmetatable({}, MacroPlayer)
    self.detector  = detector
    self.tracker   = tracker
    self.playing   = false
    self._thread   = nil
    return self
end

--- Reconstruct a RemoteEvent argument list from the serialised safe format.
local function deserialiseArgs(safeArgs)
    local out = {}
    for _, v in ipairs(safeArgs) do
        if type(v) == "table" then
            if v.__type == "Vector3" then
                table.insert(out, Util.tableToVec3(v.data))
            elseif v.__type == "CFrame" then
                local p = Util.tableToVec3(v.pos)
                table.insert(out, CFrame.new(p) * CFrame.fromEulerAnglesXYZ(v.rx, v.ry, v.rz))
            elseif v.__type == "Instance" then
                -- Best-effort: try to find the instance in the game tree
                local inst = game:FindFirstChild(v.path, true)
                    or Util.resolvePath(game, v.path)
                if inst then table.insert(out, inst)
                else warn("[MacroPlayer] Could not resolve Instance: " .. tostring(v.path)) end
            else
                table.insert(out, v)
            end
        else
            table.insert(out, v)
        end
    end
    return out
end

--- Wait until the game wave matches or the time tolerance is met.
local function waitForState(tracker, record)
    -- Wait for correct wave
    if record.wave and record.wave > 0 then
        local deadline = os.clock() + 300  -- max wait 5 minutes
        while tracker:readWave() < record.wave and os.clock() < deadline do
            task.wait(0.25)
        end
    end

    -- Wait for matching game time (within tolerance)
    if record.time and record.time > 0 then
        local deadline = os.clock() + 60
        while os.clock() < deadline do
            local t = tracker:readTime()
            if math.abs(t - record.time) <= CONFIG.timeTolerance then break end
            if t > record.time + CONFIG.timeTolerance then break end  -- overshot, fire anyway
            task.wait(0.05)
        end
    end
end

--- Check we have enough money; if not, wait up to 30s.
local function waitForMoney(tracker, required)
    if not required or required <= 0 then return true end
    local deadline = os.clock() + 30
    while tracker:readMoney() < required and os.clock() < deadline do
        task.wait(0.5)
    end
    return tracker:readMoney() >= required
end

--- Execute a single recorded action.
function MacroPlayer:_executeAction(record)
    local actionType = record.action
    local remote     = self.detector:getRemote(actionType)

    if not remote then
        warn(string.format("[MacroPlayer] No remote found for action '%s' — skipping.", actionType))
        return
    end

    -- Deserialise arguments back to Roblox types
    local args = deserialiseArgs(record.remoteArgs or {})

    -- Fire the server-side event exactly as the original client would have
    remote:FireServer(table.unpack(args))

    print(string.format(
        "[MacroPlayer] ▶ Fired %s | wave=%d | uid=%s",
        actionType, record.wave or 0, tostring(record.towerUID)
    ))
end

--- Play a macro table from start to finish.
function MacroPlayer:playMacro(macro)
    if self.playing then
        warn("[MacroPlayer] Already playing a macro.")
        return
    end
    if not macro or #macro == 0 then
        warn("[MacroPlayer] Macro is empty.")
        return
    end

    self.playing = true
    print(string.format("[MacroPlayer] ▶ Playback started (%d actions).", #macro))

    self._thread = task.spawn(function()
        for i, record in ipairs(macro) do
            if not self.playing then break end

            -- Wait for game state (wave + time)
            waitForState(self.tracker, record)
            if not self.playing then break end

            -- Verify money if it's a placement
            if record.action == "place" and record.money then
                local ok = waitForMoney(self.tracker, record.money)
                if not ok then
                    warn(string.format(
                        "[MacroPlayer] Insufficient money for action %d (%s). Skipping.",
                        i, record.action))
                    task.wait(CONFIG.minActionDelay)
                    continue
                end
            end

            -- Execute the action
            self:_executeAction(record)

            -- Small inter-action delay to avoid server flooding
            task.wait(CONFIG.minActionDelay)
        end

        self.playing = false
        print("[MacroPlayer] ■ Playback complete.")
    end)
end

--- Abort playback.
function MacroPlayer:stopPlayback()
    self.playing = false
    if self._thread then
        task.cancel(self._thread)
        self._thread = nil
    end
    print("[MacroPlayer] ■ Playback stopped by user.")
end

-- ─────────────────────────────────────────────────────────────────────────────
--  MACRO STORAGE
--  Saves and loads macro tables via a local DataStore workaround.
--  In executor environments, writefile / readfile are typically available.
-- ─────────────────────────────────────────────────────────────────────────────
local MacroStorage = {}

local SAVE_FILENAME = "TDMacro_save.json"

--- Serialise macro to JSON and write to file (executor: writefile).
function MacroStorage.save(macro)
    local ok, jsonStr = pcall(function()
        return HttpService:JSONEncode(macro)
    end)
    if not ok then
        warn("[MacroStorage] JSON encode failed: " .. tostring(jsonStr))
        return false
    end

    -- writefile is available in most Roblox script executors
    if writefile then
        local writeOk, err = pcall(writefile, SAVE_FILENAME, jsonStr)
        if writeOk then
            print("[MacroStorage] Macro saved to: " .. SAVE_FILENAME)
            return true
        else
            warn("[MacroStorage] writefile failed: " .. tostring(err))
        end
    else
        -- Fallback: print JSON to output so user can copy it manually
        print("[MacroStorage] writefile unavailable. Copy the JSON below:\n" .. jsonStr)
        return true
    end
    return false
end

--- Read JSON from file and decode back to macro table (executor: readfile).
function MacroStorage.load()
    if readfile then
        local ok, content = pcall(readfile, SAVE_FILENAME)
        if not ok or not content or content == "" then
            warn("[MacroStorage] Could not read file: " .. SAVE_FILENAME)
            return nil
        end
        local decOk, macro = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if decOk and type(macro) == "table" then
            print(string.format("[MacroStorage] Loaded %d actions from %s.",
                #macro, SAVE_FILENAME))
            return macro
        else
            warn("[MacroStorage] JSON decode failed: " .. tostring(macro))
        end
    else
        warn("[MacroStorage] readfile unavailable. Paste JSON manually into MacroStorage.loadFromString().")
    end
    return nil
end

--- Manually load a macro from a raw JSON string (for environments without readfile).
function MacroStorage.loadFromString(jsonStr)
    local ok, macro = pcall(function()
        return HttpService:JSONDecode(jsonStr)
    end)
    if ok and type(macro) == "table" then
        print(string.format("[MacroStorage] Loaded %d actions from string.", #macro))
        return macro
    end
    warn("[MacroStorage] Failed to decode JSON string.")
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
--  ON-SCREEN HUD
--  Simple TextLabel overlay so you can see macro status in-game.
-- ─────────────────────────────────────────────────────────────────────────────
local HUD = {}

local _hudGui, _hudLabel

function HUD.init()
    _hudGui = Instance.new("ScreenGui")
    _hudGui.Name           = "MacroHUD"
    _hudGui.ResetOnSpawn   = false
    _hudGui.DisplayOrder   = 999
    _hudGui.Parent         = PlayerGui

    _hudLabel = Instance.new("TextLabel")
    _hudLabel.Size             = UDim2.new(0, 320, 0, 24)
    _hudLabel.Position         = UDim2.new(0, 8, 0, 8)
    _hudLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    _hudLabel.BackgroundTransparency = 0.45
    _hudLabel.TextColor3       = Color3.fromRGB(255, 255, 255)
    _hudLabel.TextSize         = 14
    _hudLabel.Font             = Enum.Font.Code
    _hudLabel.TextXAlignment   = Enum.TextXAlignment.Left
    _hudLabel.Text             = "  [Macro] Idle  |  F6=Rec  F7=Stop  F8=Play  F9=Save  F10=Load"
    _hudLabel.Parent           = _hudGui
end

function HUD.set(text)
    if _hudLabel then _hudLabel.Text = "  [Macro] " .. text end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  INPUT HANDLER
--  Binds F6–F10 to macro operations.
-- ─────────────────────────────────────────────────────────────────────────────
local InputHandler = {}

function InputHandler.init(recorder, player, storage)
    -- Keybind map
    local binds = {
        [Enum.KeyCode.F6]  = function()   -- START RECORDING
            if player.playing then
                HUD.set("Stop playback first (F8 again).")
                return
            end
            recorder:startRecording()
            HUD.set("● RECORDING…  |  F7=Stop")
        end,

        [Enum.KeyCode.F7]  = function()   -- STOP RECORDING
            local macro = recorder:stopRecording()
            HUD.set(string.format("Recorded %d actions.  |  F8=Play  F9=Save", #macro))
        end,

        [Enum.KeyCode.F8]  = function()   -- PLAY / STOP PLAYBACK
            if player.playing then
                player:stopPlayback()
                HUD.set("Playback stopped.  |  F8=Play again")
            else
                local macro = recorder:getMacro()
                if #macro == 0 then
                    HUD.set("No macro loaded. Record (F6) or load (F10) first.")
                    return
                end
                player:playMacro(macro)
                HUD.set(string.format("▶ PLAYING (%d actions)…  |  F8=Stop", #macro))
            end
        end,

        [Enum.KeyCode.F9]  = function()   -- SAVE
            local macro = recorder:getMacro()
            local ok    = storage.save(macro)
            HUD.set(ok and "Macro saved ✓" or "Save failed — see output.")
        end,

        [Enum.KeyCode.F10] = function()   -- LOAD
            local macro = storage.load()
            if macro then
                recorder:setMacro(macro)
                HUD.set(string.format("Loaded %d actions ✓  |  F8=Play", #macro))
            else
                HUD.set("Load failed — see output.")
            end
        end,
    }

    UserInputService.InputBegan:Connect(function(input, processed)
        -- processed = true means a GUI element consumed the input; ignore it
        if processed then return end
        local fn = binds[input.KeyCode]
        if fn then
            task.spawn(fn)
        end
    end)

    print("[InputHandler] Keybinds registered: F6=Record  F7=Stop  F8=Play/Stop  F9=Save  F10=Load")
end

-- ─────────────────────────────────────────────────────────────────────────────
--  BOOTSTRAP — assemble and initialise all modules
-- ─────────────────────────────────────────────────────────────────────────────
local function init()
    print("════════════════════════════════════════════════")
    print("  Tower Defense Macro Framework — Initialising  ")
    print("════════════════════════════════════════════════")

    -- 1. Build module instances
    local detector   = RemoteEventDetector.new()
    local tracker    = GameTracker.new()
    local placement  = PlacementDetector.new()
    local recorder   = MacroRecorder.new(detector, tracker, placement)
    local player     = MacroPlayer.new(detector, tracker)

    -- 2. Hook RemoteEvents (must be first so we capture calls from frame 1)
    detector:init()

    -- 3. Start game-state polling
    tracker:startPolling()

    -- 4. Create on-screen HUD
    HUD.init()

    -- 5. Bind keyboard shortcuts
    InputHandler.init(recorder, player, MacroStorage)

    print("════════════════════════════════════════════════")
    print("  Ready!  F6=Record  F7=Stop  F8=Play  F9=Save  F10=Load")
    print("════════════════════════════════════════════════")

    -- Return public API so the framework can be used from other scripts
    return {
        detector  = detector,
        tracker   = tracker,
        placement = placement,
        recorder  = recorder,
        player    = player,
        storage   = MacroStorage,
        hud       = HUD,
    }
end

-- Run immediately when the script is executed
local Framework = init()

--[[
══════════════════════════════════════════════════════════════════════════════
  QUICK SETUP GUIDE
══════════════════════════════════════════════════════════════════════════════

  1. CONFIGURE FOR YOUR GAME
     ─────────────────────────
     Open the CONFIG table at the top of this file and update:
       • CONFIG.remoteNames   — match the exact RemoteEvent names in your game.
         To find them, run this snippet in the executor console:
           for _, v in ipairs(game.ReplicatedStorage:GetDescendants()) do
             if v:IsA("RemoteEvent") then print(v:GetFullName()) end
           end
       • CONFIG.guiPaths      — paths to the Wave / Money / Timer labels in PlayerGui.

  2. RECORD A MACRO
     ──────────────
     • Join the tower defense game and start a match.
     • Press F6 to begin recording.
     • Play normally: place towers, upgrade them, use abilities, sell.
     • Press F7 to stop.  The macro is held in memory.

  3. SAVE / LOAD
     ────────────
     • Press F9 to save the macro to "TDMacro_save.json" in the executor folder.
     • Press F10 to load it back on a future session.

  4. PLAYBACK
     ─────────
     • Start a new match (or rejoin).
     • Press F8 to play the recorded macro.
       The script will wait for the correct wave / game time before firing
       each RemoteEvent, placing towers in the exact same world positions.
     • Press F8 again at any time to abort playback.

  5. SCRIPTED USAGE (advanced)
     ──────────────────────────
     You can also drive the framework programmatically:
       Framework.recorder:startRecording()
       Framework.recorder:stopRecording()
       Framework.player:playMacro(Framework.recorder:getMacro())
       Framework.storage.save(Framework.recorder:getMacro())
       local m = Framework.storage.load()
       Framework.recorder:setMacro(m)
       Framework.player:playMacro(m)

══════════════════════════════════════════════════════════════════════════════
--]]
