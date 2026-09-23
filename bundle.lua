--[[
    ===================================================================
    🔥 REDZ STYLE BLOX FRUITS FINDER & SERVER HOPPER (DELTA MOBILE) 🔥
    ===================================================================
    - Target Executor: Delta Mobile (Android / iOS) & PC Compatible
    - Version: 2.0 (Delta Mobile UI Patch)
    - Features:
      * Server Hop Finder (Roblox Public Servers API)
      * Spawned Fruits Detector (All / Rare / Mythical)
      * Boss & Elite Bosses Detector (Urban, Deandre, Diablo, Raids)
      * Mirage Island & Full Moon 100% Detectors
      * Discord Webhook Integration with Rich Embeds & Join Scripts
      * Direct Join Script Generator & Mobile Deep Link
      * Touch-Optimized Redz Hub UI with Draggable Floating Button
    -------------------------------------------------------------------
    DELTA MOBILE UI PATCH (v2):
      * gethui() is used FIRST for the ScreenGui, with an automatic safe
        fallback chain (gethui -> CoreGui -> PlayerGui) so Android builds
        that block CoreGui injection never throw errors.
      * ScreenGui.DisplayOrder = 999999 & IgnoreGuiInset = true so the UI
        always draws ABOVE the in-game mobile buttons.
      * Responsive window 440x285 (auto-fit on tiny screens) and a
        draggable 52x52 floating apple button with ZIndex = 1000.
      * NO restart lock: re-pressing Execute deletes the old instance
        (GUI + threads + connections) and boots a brand new one.
    ===================================================================
]]

-----------------------------------------------------------------------
-- SECTION 0: RE-EXECUTION HANDLING (DELTA MOBILE RESTART SAFE)
--   There is NO "script already running" lock anymore.
--   Pressing Execute again:
--     1) Shuts the previous instance down (threads cancelled, connections
--        disconnected, old ScreenGui destroyed from every GUI parent).
--     2) Starts a brand new instance immediately.
-----------------------------------------------------------------------
local GLOBAL_SESSION_KEY = "__DeltaBloxFruitsFinderSession"
local GUI_NAME = "DeltaBloxFruitsFinder"

-- Returns the executor environment table (getgenv() / _G) safely
local function getExecutorEnv()
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then
            return env
        end
    end
    if type(_G) == "table" then
        return _G
    end
    return {}
end

local ENV = getExecutorEnv()

-- True only when the value is a real Roblox Instance
local function isInstance(value)
    if value == nil then
        return false
    end
    local ok, name = pcall(function()
        return value.Name
    end)
    return ok and type(name) == "string"
end

-- Candidate ScreenGui parents ordered by Delta-mobile safety:
--   1) gethui()  -> executor hidden UI, never protected (best on Android)
--   2) CoreGui   -> blocked on some Android / Delta builds
--   3) PlayerGui -> 100% allowed, always works as a safe fallback
local function getGuiParents()
    local parents = {}
    local seen = {}

    local function add(obj)
        if obj == nil or seen[obj] then
            return
        end
        seen[obj] = true
        if isInstance(obj) and type(obj.FindFirstChild) == "function" then
            parents[#parents + 1] = obj
        end
    end

    if type(gethui) == "function" then
        local ok, hidden = pcall(gethui)
        if ok then
            add(hidden)
        end
    end

    local okCore, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if okCore then
        add(coreGui)
    end

    local okPlayer, playerGui = pcall(function()
        local localPlayer = game:GetService("Players").LocalPlayer
        if not localPlayer then
            return nil
        end
        local pg = localPlayer:FindFirstChild("PlayerGui")
        if not pg then
            pg = localPlayer:WaitForChild("PlayerGui", 10)
        end
        return pg
    end)
    if okPlayer then
        add(playerGui)
    end

    return parents
end

-- Destroys every leftover copy of this script's GUI (recursive, all parents)
local function destroyOldGuis()
    local removed = 0
    for _, parent in ipairs(getGuiParents()) do
        local guard = 0
        local target = parent:FindFirstChild(GUI_NAME, true)
        while target and guard < 8 do
            guard = guard + 1
            pcall(function()
                target:Destroy()
            end)
            removed = removed + 1
            target = parent:FindFirstChild(GUI_NAME, true)
        end

        local floatLeftover = parent:FindFirstChild("DeltaFloatBtn", true)
        if floatLeftover then
            pcall(function()
                floatLeftover:Destroy()
            end)
            removed = removed + 1
        end
    end
    return removed
end

-- Session object: every thread / connection of this run is registered here
local Session = {
    Kind = "bundle",
    GuiName = GUI_NAME,
    Alive = true,
    Cleaned = false,
    Threads = {},
    Connections = {},
    ScreenGui = nil,
    UI = nil,
    Hop = nil,
}

function Session.TrackThread(thread)
    if thread ~= nil then
        Session.Threads[#Session.Threads + 1] = thread
    end
    return thread
end

function Session.TrackConnection(connection)
    if connection ~= nil then
        Session.Connections[#Session.Connections + 1] = connection
    end
    return connection
end

-- task.spawn replacement that stops itself when the session is dead
function Session.Spawn(fn, arg1, arg2)
    local thread = task.spawn(function()
        if not Session.Alive then
            return
        end
        local ok, err = pcall(fn, arg1, arg2)
        if not ok then
            warn("[DeltaBlox] Thread error: " .. tostring(err))
        end
    end)
    return Session.TrackThread(thread)
end

function Session.Destroy()
    if Session.Cleaned then
        return
    end
    Session.Cleaned = true
    Session.Alive = false

    -- 1) stop background loops (auto hop, scans, webhooks...)
    for _, thread in ipairs(Session.Threads) do
        pcall(function()
            if coroutine.status(thread) ~= "dead" then
                task.cancel(thread)
            end
        end)
    end
    Session.Threads = {}

    -- 2) disconnect event listeners
    for _, connection in ipairs(Session.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    Session.Connections = {}

    -- 3) stop the hopper of the previous run
    if Session.Hop and type(Session.Hop.StopAutoHop) == "function" then
        pcall(Session.Hop.StopAutoHop)
    end

    -- 4) remove the previous user interface
    if Session.UI and type(Session.UI.Destroy) == "function" then
        pcall(Session.UI.Destroy, Session.UI)
    end
    if Session.ScreenGui then
        pcall(function()
            Session.ScreenGui:Destroy()
        end)
    end
    Session.ScreenGui = nil

    destroyOldGuis()
    print("[DeltaBlox] Previous instance shut down cleanly (re-execution safe).")
end

-- Shut down the previous instance (bundle OR modular) before booting this one
local WAS_RESTART = false
local previousSession = ENV[GLOBAL_SESSION_KEY]
if type(previousSession) == "table" then
    WAS_RESTART = true
    pcall(function()
        if type(previousSession.Destroy) == "function" then
            previousSession.Destroy(previousSession)
        else
            if type(previousSession.StopAutoHop) == "function" then
                previousSession.StopAutoHop()
            end
            if type(previousSession.Threads) == "table" then
                for _, thread in ipairs(previousSession.Threads) do
                    pcall(task.cancel, thread)
                end
            end
            if type(previousSession.Connections) == "table" then
                for _, connection in ipairs(previousSession.Connections) do
                    pcall(function()
                        connection:Disconnect()
                    end)
                end
            end
            if previousSession.ScreenGui then
                pcall(function()
                    previousSession.ScreenGui:Destroy()
                end)
            end
        end
    end)
end

-- Always clean leftovers of older versions of this script (older builds had
-- no session object at all, so their GUI could still be alive)
destroyOldGuis()

-- Register this brand new session (no lock is ever used)
ENV[GLOBAL_SESSION_KEY] = Session
ENV.DeltaBloxFruitsFinderLoaded = true -- kept only as an info flag, never blocks

local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

-- CoreGui is fetched inside a pcall: some Android / Delta builds block it
local CoreGui = nil
pcall(function()
    CoreGui = game:GetService("CoreGui")
end)

-----------------------------------------------------------------------
-- SECTION 1: CONSTANTS & DATABASE
-----------------------------------------------------------------------
local Constants = {}

Constants.PlaceIds = {
    Sea1 = 2753915549,
    Sea2 = 4442272183,
    Sea3 = 7449423635,
}

Constants.SeaNames = {
    [2753915549] = "Sea 1 (First Sea)",
    [4442272183] = "Sea 2 (Second Sea)",
    [7449423635] = "Sea 3 (Third Sea)",
}

Constants.Rarities = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Legendary = 4,
    Mythical = 5,
}

Constants.RarityNames = {
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Legendary",
    [5] = "Mythical",
}

Constants.RarityColors = {
    [1] = 0x808080, -- Gray
    [2] = 0x2ECC71, -- Green
    [3] = 0x3498DB, -- Blue
    [4] = 0x9B59B6, -- Purple
    [5] = 0xE67E22, -- Orange / Mythical Gold
}

Constants.SpecialColors = {
    Mirage = 0x00FFFF,   -- Cyan
    FullMoon = 0xF1C40F, -- Golden Yellow
    Boss = 0xE74C3C,     -- Red
    Elite = 0xFF007F,    -- Deep Pink
    SwordDealer = 0x1ABC9C, -- Teal
}

Constants.Fruits = {
    -- Mythical (5)
    ["Kitsune"] = { Rarity = 5, Price = 8000000, Arabic = "كيتسوني" },
    ["Dragon"] = { Rarity = 5, Price = 5000000, Arabic = "تنين" },
    ["Leopard"] = { Rarity = 5, Price = 5000000, Arabic = "فهد (ليوبارد)" },
    ["Yeti"] = { Rarity = 5, Price = 5000000, Arabic = "يتي" },
    ["Gas"] = { Rarity = 5, Price = 4200000, Arabic = "غاز" },
    ["T-Rex"] = { Rarity = 5, Price = 2700000, Arabic = "تي ريكس" },
    ["Mammoth"] = { Rarity = 5, Price = 2700000, Arabic = "ماموث" },
    ["Dough"] = { Rarity = 5, Price = 2800000, Arabic = "عجين (دو)" },
    ["Shadow"] = { Rarity = 5, Price = 2900000, Arabic = "ظل" },
    ["Venom"] = { Rarity = 5, Price = 3000000, Arabic = "سم (فينوم)" },
    ["Control"] = { Rarity = 5, Price = 3200000, Arabic = "تحكم (كنترول)" },
    ["Spirit"] = { Rarity = 5, Price = 3400000, Arabic = "روح (سبيريت)" },
    ["Gravity"] = { Rarity = 5, Price = 2500000, Arabic = "جاذبية" },

    -- Legendary (4)
    ["Blizzard"] = { Rarity = 4, Price = 2400000, Arabic = "عاصفة ثلجية" },
    ["Pain"] = { Rarity = 4, Price = 2300000, Arabic = "ألم (بين)" },
    ["Sound"] = { Rarity = 4, Price = 1700000, Arabic = "صوت" },
    ["Phoenix"] = { Rarity = 4, Price = 1800000, Arabic = "عنقاء (فينيكس)" },
    ["Portal"] = { Rarity = 4, Price = 1900000, Arabic = "بوابة (بورتال)" },
    ["Rumble"] = { Rarity = 4, Price = 2100000, Arabic = "رعد (رامبل)" },
    ["Spider"] = { Rarity = 4, Price = 1500000, Arabic = "عنكبوت" },
    ["Love"] = { Rarity = 4, Price = 1300000, Arabic = "حب" },
    ["Buddha"] = { Rarity = 4, Price = 1200000, Arabic = "بوذا" },
    ["Quake"] = { Rarity = 4, Price = 1000000, Arabic = "زلزال (كويك)" },
    ["Magma"] = { Rarity = 4, Price = 850000, Arabic = "حمم (ماقما)" },

    -- Rare (3)
    ["Ghost"] = { Rarity = 3, Price = 940000, Arabic = "شبح" },
    ["Barrier"] = { Rarity = 3, Price = 800000, Arabic = "حاجز" },
    ["Rubber"] = { Rarity = 3, Price = 750000, Arabic = "مطاط" },
    ["Light"] = { Rarity = 3, Price = 650000, Arabic = "ضوء" },
    ["Diamond"] = { Rarity = 3, Price = 600000, Arabic = "ألماس" },

    -- Uncommon (2)
    ["Dark"] = { Rarity = 2, Price = 500000, Arabic = "ظلام" },
    ["Sand"] = { Rarity = 2, Price = 420000, Arabic = "رمل" },
    ["Ice"] = { Rarity = 2, Price = 350000, Arabic = "ثلج" },
    ["Falcon"] = { Rarity = 2, Price = 300000, Arabic = "صقر" },
    ["Flame"] = { Rarity = 2, Price = 250000, Arabic = "نار" },
    ["Spike"] = { Rarity = 2, Price = 180000, Arabic = "أشواك" },

    -- Common (1)
    ["Smoke"] = { Rarity = 1, Price = 100000, Arabic = "دخان" },
    ["Bomb"] = { Rarity = 1, Price = 80000, Arabic = "قنبلة" },
    ["Spring"] = { Rarity = 1, Price = 60000, Arabic = "زنبرك" },
    ["Chop"] = { Rarity = 1, Price = 30000, Arabic = "تقطيع" },
    ["Spin"] = { Rarity = 1, Price = 7500, Arabic = "دوران" },
    ["Rocket"] = { Rarity = 1, Price = 5000, Arabic = "صاروخ" },
}

Constants.EliteBosses = {
    ["Urban"] = { Sea = 3, Title = "Urban the Elite Pirate", Arabic = "أوربان (إيليت)" },
    ["Deandre"] = { Sea = 3, Title = "Deandre the Elite Pirate", Arabic = "دياندري (إيليت)" },
    ["Diablo"] = { Sea = 3, Title = "Diablo the Elite Pirate", Arabic = "ديابلو (إيليت)" },
}

Constants.SpecialBosses = {
    -- Sea 3
    ["rip_indra"] = { Sea = 3, Tier = "Raid", Arabic = "ريب إندرا" },
    ["rip_indra (True Form)"] = { Sea = 3, Tier = "Raid", Arabic = "ريب إندرا (الشكل الحقيقي)" },
    ["Dough King"] = { Sea = 3, Tier = "Raid", Arabic = "ملك العجين (دو كينغ)" },
    ["Cake Prince"] = { Sea = 3, Tier = "Special", Arabic = "أمير الكعك" },
    ["Soul Reaper"] = { Sea = 3, Tier = "Special", Arabic = "حاصد الأرواح" },
    ["Cake Queen"] = { Sea = 3, Tier = "Boss", Arabic = "ملكة الكعك" },
    ["Beautiful Pirate"] = { Sea = 3, Tier = "Boss", Arabic = "القرصان الجميل" },
    ["Captain Elephant"] = { Sea = 3, Tier = "Boss", Arabic = "القائد الفيل" },
    ["Stone"] = { Sea = 3, Tier = "Boss", Arabic = "ستون" },
    ["Island Empress"] = { Sea = 3, Tier = "Boss", Arabic = "إمبراطورة الجزيرة" },
    ["Kilo Admiral"] = { Sea = 3, Tier = "Boss", Arabic = "أدميرال الكيلو" },

    -- Sea 2
    ["Darkbeard"] = { Sea = 2, Tier = "Raid", Arabic = "اللحية السوداء (دارك بيرد)" },
    ["Cursed Captain"] = { Sea = 2, Tier = "Special", Arabic = "القبطان الملعون" },
    ["Order"] = { Sea = 2, Tier = "Raid", Arabic = "أوردر (لاو)" },
    ["Don Swan"] = { Sea = 2, Tier = "Boss", Arabic = "دون سوان (دوفلامينغو)" },
    ["Tide Keeper"] = { Sea = 2, Tier = "Boss", Arabic = "حارس المد" },
    ["Awakened Ice Admiral"] = { Sea = 2, Tier = "Boss", Arabic = "أدميرال الجليد الموقظ" },
    ["Smoke Admiral"] = { Sea = 2, Tier = "Boss", Arabic = "أدميرال الدخان" },
    ["Fajita"] = { Sea = 2, Tier = "Boss", Arabic = "فوجيتورا (فاجيتا)" },
    ["Jeremy"] = { Sea = 2, Tier = "Boss", Arabic = "جيريمي (بيلامي)" },
    ["Diamond"] = { Sea = 2, Tier = "Boss", Arabic = "دايموند" },

    -- Sea 1
    ["Saber Expert"] = { Sea = 1, Tier = "Special", Arabic = "خبير السيوف (شانكس)" },
    ["The Saw"] = { Sea = 1, Tier = "Special", Arabic = "المنشار (آرلونغ)" },
    ["Greybeard"] = { Sea = 1, Tier = "Raid", Arabic = "اللحية البيضاء" },
    ["The Gorilla King"] = { Sea = 1, Tier = "Boss", Arabic = "ملك الغوريلا" },
    ["Bobby"] = { Sea = 1, Tier = "Boss", Arabic = "بوبي (باجي)" },
    ["Yeti"] = { Sea = 1, Tier = "Boss", Arabic = "اليتي" },
    ["Mob Leader"] = { Sea = 1, Tier = "Boss", Arabic = "زعيم العصابة" },
    ["Vice Admiral"] = { Sea = 1, Tier = "Boss", Arabic = "نائب الأدميرال" },
    ["Warden"] = { Sea = 1, Tier = "Boss", Arabic = "السجان" },
    ["Chief Warden"] = { Sea = 1, Tier = "Boss", Arabic = "رئيس السجانين" },
    ["Swan"] = { Sea = 1, Tier = "Boss", Arabic = "سوان" },
    ["Magma Admiral"] = { Sea = 1, Tier = "Boss", Arabic = "أدميرال الماغما" },
    ["Fishman Lord"] = { Sea = 1, Tier = "Boss", Arabic = "سيد البرمائيين" },
    ["Wysper"] = { Sea = 1, Tier = "Boss", Arabic = "وايبر" },
    ["Thunder God"] = { Sea = 1, Tier = "Boss", Arabic = "إينيل (إله الرعد)" },
    ["Cyborg"] = { Sea = 1, Tier = "Boss", Arabic = "فرانكي (سايبورغ)" },
}

Constants.FullMoonAssetIds = {
    ["rbxassetid://9709149431"] = true,
    ["rbxassetid://9709149052"] = true,
    ["http://www.roblox.com/asset/?id=9709149431"] = true,
    ["http://www.roblox.com/asset/?id=9709149052"] = true,
    ["9709149431"] = true,
    ["9709149052"] = true,
}

-----------------------------------------------------------------------
-- SECTION 2: CONFIGURATION
-----------------------------------------------------------------------
local Config = {
    WebhookURL = "",
    WebhookEnabled = false,
    FruitFilter = "RareOnly",
    MinFruitRarity = 4, -- 4 = Legendary & Mythical
    NotifyAllFruits = false,

    DetectBosses = true,
    DetectEliteBosses = true,
    DetectRaidBosses = true,

    DetectMirageIsland = false,
    DetectFullMoon = false,
    DetectSwordDealer = true,

    AutoHop = false,
    HopDelay = 5,
    MaxServerPlayers = 11,
    MinServerPlayers = 1,

    AutoStayOnFind = true,
    AutoTeleport = false,
    SoundAlert = true,
    NotifyInGame = true,
}

-----------------------------------------------------------------------
-- SECTION 3: UTILS (DELTA MOBILE OPTIMIZED)
-----------------------------------------------------------------------
local Utils = {}

function Utils.HttpRequest(options)
    local requestFn = (syn and syn.request)
        or (http and http.request)
        or http_request
        or request
        or (fluxus and fluxus.request)

    if not requestFn then
        warn("[DeltaUtils] No compatible HTTP request function found!")
        return nil, "No HTTP function"
    end

    local success, response = pcall(function()
        return requestFn(options)
    end)

    if not success then
        return nil, response
    end
    return response
end

function Utils.SetClipboard(text)
    local clipFn = setclipboard or toclipboard or (syn and syn.write_clipboard)
    if clipFn then
        pcall(function() clipFn(tostring(text)) end)
        return true
    end
    return false
end

function Utils.Notify(title, message, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "Delta Blox Fruits",
            Text = message or "",
            Duration = duration or 6,
        })
    end)
end

function Utils.PlayAlertSound()
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://4590662766"
        sound.Volume = 1
        sound.Parent = SoundService
        sound:Play()
        task.delay(3, function() sound:Destroy() end)
    end)
end

function Utils.JsonEncode(tbl)
    local success, res = pcall(function()
        return HttpService:JSONEncode(tbl)
    end)
    return success and res or "{}"
end

function Utils.JsonDecode(str)
    local success, res = pcall(function()
        return HttpService:JSONDecode(str)
    end)
    return success and res or nil
end

function Utils.GetCurrentSea()
    local placeId = game.PlaceId
    if placeId == 2753915549 then return 1
    elseif placeId == 4442272183 then return 2
    elseif placeId == 7449423635 then return 3
    else return 0 end
end

function Utils.GetJoinScript(placeId, jobId)
    return string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s", game.Players.LocalPlayer)', tostring(placeId), tostring(jobId))
end

function Utils.GetMobileJoinLink(placeId, jobId)
    return string.format("roblox://experiences/start?placeId=%s&gameInstanceId=%s", tostring(placeId), tostring(jobId))
end

-- Viewport size helper (mobile / emulator safe)
function Utils.GetViewport()
    local size = Vector2.new(1280, 720)
    pcall(function()
        local camera = workspace.CurrentCamera
        if camera and camera.ViewportSize then
            size = camera.ViewportSize
        end
    end)
    if type(size) ~= "table" or size.X <= 0 or size.Y <= 0 then
        size = Vector2.new(1280, 720)
    end
    return size
end

local function clampNumber(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

--[[
    Touch + Mouse dragging engine (Delta mobile optimized)
    - Works with finger (Touch) and mouse on PC / emulator.
    - Keeps the dragged element fully inside the screen.
    - Returns a controller:
        controller.Dragging    -> true while a finger holds the element
        controller.WasDragged  -> true right after a real drag (used to
                                  avoid "open/close UI" on a drag gesture)
        controller.Destroy()   -> disconnects every listener
]]
function Utils.MakeDraggable(handle, target, keepInsideScreen)
    if keepInsideScreen == nil then
        keepInsideScreen = true
    end

    local controller = {
        Dragging = false,
        WasDragged = false,
    }

    local dragging = false
    local moved = false
    local dragInput = nil
    local dragStart = nil
    local startOffset = nil
    local connections = {}

    local function track(connection)
        connections[#connections + 1] = connection
        return connection
    end

    local function isDragInput(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
    end

    local function parentOrigin()
        local parent = target.Parent
        if parent and parent.AbsolutePosition then
            return parent.AbsolutePosition
        end
        return Vector2.new(0, 0)
    end

    local function applyPosition(absX, absY)
        local parent = target.Parent
        local parentSize = nil
        if parent and parent.AbsoluteSize then
            parentSize = parent.AbsoluteSize
        end
        if not parentSize or parentSize.X <= 0 or parentSize.Y <= 0 then
            parentSize = Utils.GetViewport()
        end

        local size = target.AbsoluteSize or Vector2.new(0, 0)
        if keepInsideScreen then
            local maxX = parentSize.X - size.X
            local maxY = parentSize.Y - size.Y
            if maxX < 0 then
                maxX = 0
            end
            if maxY < 0 then
                maxY = 0
            end
            absX = clampNumber(absX, 0, maxX)
            absY = clampNumber(absY, 0, maxY)
        end

        target.Position = UDim2.new(0, math.floor(absX), 0, math.floor(absY))
    end

    local function beginDrag(input)
        dragging = true
        moved = false
        controller.Dragging = true
        controller.WasDragged = false
        dragStart = input.Position
        startOffset = target.AbsolutePosition - parentOrigin()
    end

    local function endDrag()
        dragging = false
        controller.Dragging = false
        dragInput = nil
        controller.WasDragged = moved
    end

    track(handle.InputBegan:Connect(function(input)
        if isDragInput(input) then
            beginDrag(input)
        end
    end))

    track(handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    track(handle.InputEnded:Connect(function(input)
        if isDragInput(input) then
            endDrag()
        end
    end))

    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput and dragStart and startOffset then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then
                moved = true
            end
            applyPosition(startOffset.X + delta.X, startOffset.Y + delta.Y)
        end
    end))

    function controller.Destroy()
        for _, connection in ipairs(connections) do
            pcall(function()
                connection:Disconnect()
            end)
        end
        connections = {}
        dragging = false
        controller.Dragging = false
    end

    return controller
end

-----------------------------------------------------------------------
-- SECTION 4: DETECTOR MODULE
-----------------------------------------------------------------------
local Detector = {}

local function cleanFruitName(rawName)
    if not rawName then return "" end
    local name = tostring(rawName)
    name = name:gsub(" Fruit", "")
    name = name:gsub("Fruit", "")
    name = name:gsub("%s+", "")
    return name
end

local function findFruitData(rawName)
    local cleaned = cleanFruitName(rawName):lower()
    for fruitName, data in pairs(Constants.Fruits) do
        local key = fruitName:lower()
        if cleaned == key or string.find(cleaned, key) or string.find(key, cleaned) then
            return fruitName, data
        end
    end
    return nil, nil
end

function Detector.ScanFruits()
    local foundFruits = {}
    local player = Players.LocalPlayer
    local char = player and player.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
    local myPos = root and root.Position or Vector3.new(0, 0, 0)

    for _, obj in ipairs(Workspace:GetChildren()) do
        pcall(function()
            if (obj:IsA("Tool") or obj:IsA("Model")) and obj.Name ~= "Character" then
                local rawName = obj.Name
                local fruitBase, fruitData = findFruitData(rawName)

                if not fruitData and (rawName:lower():find("fruit") or obj:FindFirstChild("Handle")) then
                    for _, child in ipairs(obj:GetChildren()) do
                        fruitBase, fruitData = findFruitData(child.Name)
                        if fruitData then break end
                    end
                end

                if fruitData then
                    local handle = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart") or (obj:IsA("BasePart") and obj)
                    local pos = handle and handle.Position or Vector3.new(0, 0, 0)
                    local dist = root and math.floor((myPos - pos).Magnitude) or 0
                    local rarity = fruitData.Rarity or 1

                    local isIncluded = false
                    if Config.FruitFilter == "All" or Config.NotifyAllFruits then
                        isIncluded = true
                    elseif Config.FruitFilter == "MythicalOnly" then
                        isIncluded = (rarity == 5)
                    else
                        isIncluded = (rarity >= (Config.MinFruitRarity or 4))
                    end

                    if isIncluded then
                        table.insert(foundFruits, {
                            Name = fruitBase .. " Fruit",
                            BaseName = fruitBase,
                            Arabic = fruitData.Arabic or fruitBase,
                            Rarity = rarity,
                            RarityName = Constants.RarityNames[rarity] or "Unknown",
                            Price = fruitData.Price or 0,
                            Instance = obj,
                            Position = pos,
                            Distance = dist,
                        })
                    end
                end
            end
        end)
    end
    return foundFruits
end

function Detector.ScanBosses()
    local foundBosses = {}
    local player = Players.LocalPlayer
    local char = player and player.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
    local myPos = root and root.Position or Vector3.new(0, 0, 0)

    local function inspectEnemy(npc)
        pcall(function()
            if not npc:IsA("Model") then return end
            local humanoid = npc:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then return end

            local name = npc.Name
            local rootPart = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head") or npc.PrimaryPart
            local pos = rootPart and rootPart.Position or Vector3.new(0, 0, 0)
            local dist = root and math.floor((myPos - pos).Magnitude) or 0
            local hpPercent = math.floor((humanoid.Health / humanoid.MaxHealth) * 100)

            if Config.DetectEliteBosses and Constants.EliteBosses[name] then
                local eliteInfo = Constants.EliteBosses[name]
                table.insert(foundBosses, {
                    Name = name,
                    Type = "Elite",
                    Arabic = eliteInfo.Arabic or name,
                    Title = eliteInfo.Title or name,
                    Health = math.floor(humanoid.Health),
                    MaxHealth = math.floor(humanoid.MaxHealth),
                    HealthPercent = hpPercent,
                    Position = pos,
                    Distance = dist,
                    Instance = npc,
                })
                return
            end

            if Config.DetectRaidBosses and Constants.SpecialBosses[name] then
                local bossInfo = Constants.SpecialBosses[name]
                table.insert(foundBosses, {
                    Name = name,
                    Type = bossInfo.Tier or "Boss",
                    Arabic = bossInfo.Arabic or name,
                    Title = name,
                    Health = math.floor(humanoid.Health),
                    MaxHealth = math.floor(humanoid.MaxHealth),
                    HealthPercent = hpPercent,
                    Position = pos,
                    Distance = dist,
                    Instance = npc,
                })
                return
            end
        end)
    end

    local enemiesFolder = Workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do inspectEnemy(enemy) end
    end

    local npcsFolder = Workspace:FindFirstChild("NPCs")
    if npcsFolder then
        for _, npc in ipairs(npcsFolder:GetChildren()) do inspectEnemy(npc) end
    end

    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model ~= char and not (enemiesFolder and model.Parent == enemiesFolder) then
            if Constants.EliteBosses[model.Name] or Constants.SpecialBosses[model.Name] then
                inspectEnemy(model)
            end
        end
    end

    return foundBosses
end

function Detector.ScanMirageIsland()
    local result = { Found = false, Name = nil, Type = nil }
    pcall(function()
        local locations = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
        local function checkName(name)
            local lower = name:lower()
            if lower:find("mirage") then return "Mirage Island", "Mirage"
            elseif lower:find("kitsune island") or lower:find("kitsuneisland") then return "Kitsune Island", "Kitsune" end
            return nil, nil
        end

        if locations then
            for _, loc in ipairs(locations:GetChildren()) do
                local friendly, typ = checkName(loc.Name)
                if friendly then result.Found = true; result.Name = friendly; result.Type = typ; return end
            end
        end

        for _, child in ipairs(Workspace:GetChildren()) do
            local friendly, typ = checkName(child.Name)
            if friendly then result.Found = true; result.Name = friendly; result.Type = typ; return end
        end
    end)
    return result
end

function Detector.ScanFullMoon()
    local result = { IsFullMoon = false, MoonPercent = 0, ClockTime = Lighting.ClockTime, Description = "No Full Moon" }
    pcall(function()
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky and sky.MoonTextureId then
            local texId = tostring(sky.MoonTextureId)
            if Constants.FullMoonAssetIds[texId] then
                result.IsFullMoon = true
                result.MoonPercent = 100
                result.Description = "Full Moon Peak (100%)"
                return
            end
        end

        local fullMoonTag = Lighting:FindFirstChild("FullMoon") or Lighting:GetAttribute("FullMoon")
        if fullMoonTag == true or (typeof(fullMoonTag) == "Instance") then
            result.IsFullMoon = true
            result.MoonPercent = 100
            result.Description = "Full Moon Active"
            return
        end

        local moonPhaseObj = Lighting:FindFirstChild("MoonPhase")
        if moonPhaseObj and moonPhaseObj:IsA("ValueBase") then
            local val = tonumber(moonPhaseObj.Value) or 0
            result.MoonPercent = val
            if val >= 95 then
                result.IsFullMoon = true
                result.Description = string.format("Full Moon (%d%%)", val)
            end
        end
    end)
    return result
end

function Detector.ScanLegendarySwordDealer()
    local result = { Found = false, Location = nil }
    pcall(function()
        local npcs = Workspace:FindFirstChild("NPCs") or Workspace
        for _, npc in ipairs(npcs:GetChildren()) do
            if npc.Name == "Legendary Sword Dealer" or npc.Name:lower():find("sword dealer") then
                result.Found = true
                local hrp = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head") or npc.PrimaryPart
                result.Location = hrp and hrp.Position or Vector3.new(0, 0, 0)
                return
            end
        end
    end)
    return result
end

function Detector.ScanAll()
    local scanData = {
        Fruits = Detector.ScanFruits(),
        Bosses = Detector.ScanBosses(),
        Mirage = Config.DetectMirageIsland and Detector.ScanMirageIsland() or { Found = false },
        FullMoon = Config.DetectFullMoon and Detector.ScanFullMoon() or { IsFullMoon = false },
        SwordDealer = Config.DetectSwordDealer and Detector.ScanLegendarySwordDealer() or { Found = false },
        Timestamp = os.time(),
    }

    scanData.HasTarget = (#scanData.Fruits > 0)
        or (#scanData.Bosses > 0)
        or (scanData.Mirage.Found == true)
        or (scanData.FullMoon.IsFullMoon == true)
        or (scanData.SwordDealer.Found == true)

    return scanData
end

-----------------------------------------------------------------------
-- SECTION 5: NOTIFIER MODULE
-----------------------------------------------------------------------
local Notifier = {}

local function sendWebhook(webhookUrl, payload)
    if not webhookUrl or webhookUrl == "" or not webhookUrl:find("discord") then
        return false, "Invalid Discord Webhook URL"
    end
    local body = Utils.JsonEncode(payload)
    local response, err = Utils.HttpRequest({
        Url = webhookUrl,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    })
    return (response ~= nil), err
end

function Notifier.TestWebhook(webhookUrl)
    local payload = {
        username = "Delta Blox Fruits Finder",
        embeds = {
            {
                title = "✅ تم ربط الويب هوك بنجاح!",
                description = "سكربت Delta شغال ومتصل بسيرفرك في الديسكورد.\nسوف تتلقى إشعارات فورية عند العثور على فواكه نادرة، بوسات، أو جزر الميراج!",
                color = 0x2ECC71,
                fields = {
                    { name = "🌊 البحر (Sea)", value = tostring(Utils.GetCurrentSea()), inline = true },
                    { name = "🆔 Job ID السيرفر الحالي", value = string.format("`%s`", tostring(game.JobId)), inline = true },
                },
                footer = { text = "Delta Blox Fruits Finder • Redz Style" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }
        }
    }
    return sendWebhook(webhookUrl, payload)
end

function Notifier.NotifyFruit(fruit)
    local placeId = game.PlaceId
    local seaName = Constants.SeaNames[placeId] or ("Sea " .. tostring(Utils.GetCurrentSea()))
    local joinScript = Utils.GetJoinScript(placeId, game.JobId)
    local playerCount = #Players:GetPlayers()
    local color = Constants.RarityColors[fruit.Rarity] or 0xE67E22

    if Config.NotifyInGame then
        Utils.Notify("🍎 فاكهة مرسبنة: " .. fruit.Name, "الندرة: " .. fruit.RarityName .. " (" .. fruit.Arabic .. ")", 7)
    end
    if Config.SoundAlert then
        Utils.PlayAlertSound()
    end

    if Config.WebhookEnabled and Config.WebhookURL and Config.WebhookURL ~= "" then
        local payload = {
            username = "Delta Fruit Finder",
            content = "@everyone 🚨 **تم العثور على فاكهة نادرة في السيرفر!**",
            embeds = {
                {
                    title = string.format("🍇 فاكهة: %s (%s)", fruit.Name, fruit.Arabic),
                    description = string.format("**الندرة:** `%s` (مستوى %d/5)\n**السعر:** $%s Beli\n**المسافة الحالية:** %d متر",
                        fruit.RarityName, fruit.Rarity, tostring(fruit.Price), fruit.Distance or 0),
                    color = color,
                    fields = {
                        { name = "🌊 البحر (Sea)", value = seaName, inline = true },
                        { name = "👥 عدد اللاعبين", value = string.format("%d / 12", playerCount), inline = true },
                        { name = "🆔 Server JobId", value = string.format("```%s```", tostring(game.JobId)), inline = false },
                        { name = "⚡ كود الدخول للحساب الأساسي (Roblox Console / Executor):", value = string.format("```lua\n%s\n```", joinScript), inline = false },
                    },
                    footer = { text = "Delta Blox Fruits Finder • Redz Hub Edition" },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }
            }
        }
        task.spawn(function() sendWebhook(Config.WebhookURL, payload) end)
    end
end

function Notifier.NotifyBoss(boss)
    local placeId = game.PlaceId
    local seaName = Constants.SeaNames[placeId] or ("Sea " .. tostring(Utils.GetCurrentSea()))
    local joinScript = Utils.GetJoinScript(placeId, game.JobId)
    local playerCount = #Players:GetPlayers()
    local color = (boss.Type == "Elite") and Constants.SpecialColors.Elite or Constants.SpecialColors.Boss

    if Config.NotifyInGame then
        Utils.Notify("👑 رصد بوس: " .. boss.Name, "النوع: " .. boss.Type .. " | صحته: " .. tostring(boss.HealthPercent) .. "%", 6)
    end
    if Config.SoundAlert then
        Utils.PlayAlertSound()
    end

    if Config.WebhookEnabled and Config.WebhookURL and Config.WebhookURL ~= "" then
        local payload = {
            username = "Delta Boss Finder",
            content = "⚔️ **تم رصد بوس في السيرفر!**",
            embeds = {
                {
                    title = string.format("👑 البوس: %s (%s)", boss.Name, boss.Arabic or boss.Name),
                    description = string.format("**النوع:** `%s`\n**الصحة:** %d / %d (%d%%)",
                        boss.Type, boss.Health, boss.MaxHealth, boss.HealthPercent),
                    color = color,
                    fields = {
                        { name = "🌊 البحر (Sea)", value = seaName, inline = true },
                        { name = "👥 عدد اللاعبين", value = string.format("%d / 12", playerCount), inline = true },
                        { name = "🆔 Server JobId", value = string.format("```%s```", tostring(game.JobId)), inline = false },
                        { name = "⚡ كود الدخول للحساب الأساسي:", value = string.format("```lua\n%s\n```", joinScript), inline = false },
                    },
                    footer = { text = "Delta Blox Fruits Finder • Boss Tracker" },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }
            }
        }
        task.spawn(function() sendWebhook(Config.WebhookURL, payload) end)
    end
end

function Notifier.NotifyMirage(mirageData)
    local placeId = game.PlaceId
    local seaName = Constants.SeaNames[placeId] or "Sea 3"
    local joinScript = Utils.GetJoinScript(placeId, game.JobId)

    if Config.NotifyInGame then
        Utils.Notify("🏝️ جزيرة الميراج!", "تم العثور على جزيرة الميراج بالسيرفر الحالي!", 10)
    end
    if Config.SoundAlert then Utils.PlayAlertSound() end

    if Config.WebhookEnabled and Config.WebhookURL and Config.WebhookURL ~= "" then
        local payload = {
            username = "Delta Event Finder",
            content = "@everyone 🏝️ **حدث نادر: ظهرت جزيرة الميراج (Mirage Island)!**",
            embeds = {
                {
                    title = "🏝️ جزيرة الميراج (Mirage Island) نشطة الآن!",
                    description = "الجزيرة موجودة حالياً بالخريطة، جاهزة لسحب مقبض Race V4 والتروس!",
                    color = Constants.SpecialColors.Mirage,
                    fields = {
                        { name = "🌊 البحر", value = seaName, inline = true },
                        { name = "🆔 Job ID", value = string.format("```%s```", tostring(game.JobId)), inline = false },
                        { name = "⚡ كود الدخول للحساب الأساسي:", value = string.format("```lua\n%s\n```", joinScript), inline = false },
                    },
                    footer = { text = "Delta Blox Fruits Finder • Mirage Detector" },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }
            }
        }
        task.spawn(function() sendWebhook(Config.WebhookURL, payload) end)
    end
end

function Notifier.NotifyFullMoon(moonData)
    local placeId = game.PlaceId
    local joinScript = Utils.GetJoinScript(placeId, game.JobId)

    if Config.NotifyInGame then
        Utils.Notify("🌕 قمر كامل (Full Moon)!", "القمر مكتمل 100% في السيرفر الحالي!", 10)
    end
    if Config.SoundAlert then Utils.PlayAlertSound() end

    if Config.WebhookEnabled and Config.WebhookURL and Config.WebhookURL ~= "" then
        local payload = {
            username = "Delta Event Finder",
            content = "🌕 **اكتمال القمر (Full Moon 100%) في السيرفر!**",
            embeds = {
                {
                    title = "🌕 اكتمال القمر (Full Moon Active)",
                    description = "ذروة اكتمال القمر جاهزة لتجارب Race V4 وسحب المقبض في الميراج!",
                    color = Constants.SpecialColors.FullMoon,
                    fields = {
                        { name = "🆔 Job ID", value = string.format("```%s```", tostring(game.JobId)), inline = false },
                        { name = "⚡ كود الدخول المباشر:", value = string.format("```lua\n%s\n```", joinScript), inline = false },
                    },
                    footer = { text = "Delta Blox Fruits Finder • Full Moon Detector" },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }
            }
        }
        task.spawn(function() sendWebhook(Config.WebhookURL, payload) end)
    end
end

function Notifier.NotifySwordDealer(dealerData)
    local placeId = game.PlaceId
    local joinScript = Utils.GetJoinScript(placeId, game.JobId)

    if Config.NotifyInGame then
        Utils.Notify("⚔️ بائع السيوف الأسطوري!", "Legendary Sword Dealer متواجد في البحر الثاني!", 8)
    end
    if Config.SoundAlert then Utils.PlayAlertSound() end

    if Config.WebhookEnabled and Config.WebhookURL and Config.WebhookURL ~= "" then
        local payload = {
            username = "Delta Event Finder",
            content = "⚔️ **بائع السيوف الأسطوري متواجد في السيرفر (Sea 2)!**",
            embeds = {
                {
                    title = "⚔️ Legendary Sword Dealer رُصد في Sea 2",
                    description = "البائع موجود لبيع أحد السيوف الأسطورية (Shisui, Wando, Saddi)!",
                    color = Constants.SpecialColors.SwordDealer,
                    fields = {
                        { name = "🆔 Job ID", value = string.format("```%s```", tostring(game.JobId)), inline = false },
                        { name = "⚡ كود الدخول للحساب الأساسي:", value = string.format("```lua\n%s\n```", joinScript), inline = false },
                    },
                    footer = { text = "Delta Blox Fruits Finder • Sword Dealer" },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }
            }
        }
        task.spawn(function() sendWebhook(Config.WebhookURL, payload) end)
    end
end

-----------------------------------------------------------------------
-- SECTION 6: SERVER HOPPER MODULE
-----------------------------------------------------------------------
local Hop = {}
local isHoppingActive = false
local currentHopThread = nil
local visitedServers = {}
local historyFileName = "DeltaBlox_HopCache.json"

local function loadHistory()
    if readfile and isfile and isfile(historyFileName) then
        pcall(function()
            local content = readfile(historyFileName)
            local data = Utils.JsonDecode(content)
            if type(data) == "table" then
                for k, v in pairs(data) do visitedServers[k] = v end
            end
        end)
    end
    if game.JobId and game.JobId ~= "" then
        visitedServers[game.JobId] = true
    end
end

local function saveHistory()
    if writefile then
        pcall(function()
            writefile(historyFileName, Utils.JsonEncode(visitedServers))
        end)
    end
end

local function fetchServerList(placeId, cursor)
    local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100", tostring(placeId))
    if cursor and cursor ~= "" then
        url = url .. "&cursor=" .. tostring(cursor)
    end

    local response, err = Utils.HttpRequest({
        Url = url,
        Method = "GET",
        Headers = { ["Content-Type"] = "application/json" },
    })

    if not response or not response.Body then return nil, err end
    local data = Utils.JsonDecode(response.Body)
    if not data or not data.data then return nil, "Invalid JSON" end
    return data
end

function Hop.FindNextServer(placeId)
    local cursor = nil
    local attempts = 0
    local maxAttempts = 3

    while attempts < maxAttempts do
        attempts = attempts + 1
        local serverData = fetchServerList(placeId, cursor)
        if serverData and serverData.data then
            for _, srv in ipairs(serverData.data) do
                local srvId = srv.id
                local playing = tonumber(srv.playing) or 0
                if srvId ~= game.JobId and not visitedServers[srvId] then
                    if playing < (Config.MaxServerPlayers or 11) and playing >= (Config.MinServerPlayers or 1) then
                        return srvId, srv
                    end
                end
            end
            cursor = serverData.nextPageCursor
            if not cursor or cursor == "" then
                visitedServers = {}
                visitedServers[game.JobId] = true
                cursor = nil
            end
        end
        task.wait(1)
    end
    return nil, "No available server found"
end

function Hop.TeleportToJobId(placeId, targetJobId)
    local player = Players.LocalPlayer
    if not player then return false end

    visitedServers[targetJobId] = true
    saveHistory()

    Utils.Notify("Delta Hopper", "جاري الانتقال للسيرفر: " .. string.sub(targetJobId, 1, 8) .. "...", 4)
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, targetJobId, player)
    end)
    return success, err
end

function Hop.HopOnce(placeId)
    local targetId = Hop.FindNextServer(placeId)
    if targetId then
        return Hop.TeleportToJobId(placeId, targetId)
    else
        Utils.Notify("Delta Hopper", "لم يتم العثور على سيرفر متاح، إعادة المحاولة...", 3)
        return false, "No server found"
    end
end

function Hop.StartAutoHop(placeId, scanCallback)
    if isHoppingActive then return end
    isHoppingActive = true
    loadHistory()

    currentHopThread = Session.Spawn(function()
        while isHoppingActive and Session.Alive do
            local scanResult = scanCallback and scanCallback()
            if scanResult and scanResult.HasTarget and Config.AutoStayOnFind then
                isHoppingActive = false
                Utils.PlayAlertSound()
                Utils.Notify("لقطة نادرة! 🎯", "تم العثور على هدف وإيقاف التنقل التلقائي لتثبيت الحساب.", 8)
                break
            end

            local delayTime = Config.HopDelay or 5
            for i = delayTime, 1, -1 do
                if not isHoppingActive or not Session.Alive then break end
                task.wait(1)
            end

            if not isHoppingActive or not Session.Alive then break end

            local ok = Hop.HopOnce(placeId)
            if not ok then
                task.wait(3)
            else
                task.wait(15)
            end
        end
    end)
end

function Hop.StopAutoHop()
    isHoppingActive = false
    if currentHopThread then
        pcall(task.cancel, currentHopThread)
        currentHopThread = nil
    end
end

function Hop.IsHopping()
    return isHoppingActive
end

-- Registered so a re-execution can stop the old hopper immediately
Session.Hop = Hop

Session.TrackConnection(TeleportService.TeleportInitFailed:Connect(function(player, result, msg)
    if isHoppingActive and Session.Alive then
        task.wait(2)
        Hop.HopOnce(game.PlaceId)
    end
end))

-----------------------------------------------------------------------
-- SECTION 7: USER INTERFACE (REDZ HUB STYLE - DELTA MOBILE PATCH v2)
-----------------------------------------------------------------------
local UI = {}

--[[
    Parents the ScreenGui using the safest Delta-mobile chain:
        1) gethui()                      (executor hidden UI - first choice)
        2) CoreGui                       (often blocked on Android)
        3) Players.LocalPlayer.PlayerGui (always allowed fallback)
    Silent failures are detected too: if the Parent does not stick we move
    to the next candidate instead of leaving an invisible GUI behind.
]]
local function parentScreenGui(gui)
    for _, candidate in ipairs(getGuiParents()) do
        local ok = pcall(function()
            gui.Parent = candidate
        end)
        if ok and gui.Parent == candidate then
            return candidate
        end
    end

    -- Last resort: straight into PlayerGui (never blocked by Roblox)
    local ok = pcall(function()
        local localPlayer = game:GetService("Players").LocalPlayer
        local playerGui = localPlayer:FindFirstChild("PlayerGui")
        if not playerGui then
            playerGui = localPlayer:WaitForChild("PlayerGui", 10)
        end
        gui.Parent = playerGui
    end)
    if ok and gui.Parent then
        return gui.Parent
    end
    return nil
end

function UI.Create()
    -- 1) ScreenGui (Delta mobile safe injection) ---------------------
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = GUI_NAME
    ScreenGui.ResetOnSpawn = false          -- survives respawn / death
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999999         -- above game buttons & other hubs
    ScreenGui.IgnoreGuiInset = true         -- draw over the mobile top inset
    ScreenGui.Enabled = true

    -- Optional properties: safe-set because old engines may not support them
    pcall(function() ScreenGui.ClipToDeviceSafeArea = false end)
    pcall(function() ScreenGui.OnTopOfCoreBlur = true end)

    local chosenParent = parentScreenGui(ScreenGui)
    if not chosenParent then
        warn("[DeltaBlox UI] Could not parent the ScreenGui in any GUI container!")
        return nil
    end
    Session.ScreenGui = ScreenGui

    -- 2) Responsive mobile window size (base 440x285) -----------------
    local viewport = Utils.GetViewport()
    local BASE_W, BASE_H = 440, 285
    local fitScale = 1
    if viewport.X > 40 and viewport.Y > 40 then
        fitScale = math.min(1, (viewport.X - 16) / BASE_W, (viewport.Y - 16) / BASE_H)
    end
    if fitScale < 0.7 then
        fitScale = 0.7 -- never shrink below readability on tiny screens
    end
    local WIN_W = math.floor(BASE_W * fitScale)
    local WIN_H = math.floor(BASE_H * fitScale)
    local startX = math.max(8, math.floor((viewport.X - WIN_W) / 2))
    local startY = math.max(8, math.floor((viewport.Y - WIN_H) / 2))

    local C_BG = Color3.fromRGB(17, 18, 24)
    local C_TOPBAR = Color3.fromRGB(23, 24, 32)
    local C_CARD = Color3.fromRGB(26, 28, 38)
    local C_ACCENT = Color3.fromRGB(255, 51, 85)
    local C_TEXT = Color3.fromRGB(240, 240, 245)
    local C_TEXT_MUTED = Color3.fromRGB(150, 155, 170)
    local C_GREEN = Color3.fromRGB(46, 204, 113)
    local C_GRAY = Color3.fromRGB(60, 65, 80)

    -- 3) Floating apple button: 52x52, ZIndex 1000, touch draggable ----
    local FloatButton = Instance.new("ImageButton")
    FloatButton.Name = "DeltaFloatBtn"
    FloatButton.Size = UDim2.new(0, 52, 0, 52)
    FloatButton.Position = UDim2.new(0, 15, 0.35, 0)
    FloatButton.BackgroundColor3 = C_BG
    FloatButton.BorderSizePixel = 0
    FloatButton.AutoButtonColor = false
    FloatButton.Active = true
    FloatButton.ZIndex = 1000
    FloatButton.Parent = ScreenGui

    Instance.new("UICorner", FloatButton).CornerRadius = UDim.new(0, 26)

    local FloatStroke = Instance.new("UIStroke")
    FloatStroke.Color = C_ACCENT
    FloatStroke.Thickness = 2
    FloatStroke.Parent = FloatButton

    local FloatIcon = Instance.new("TextLabel")
    FloatIcon.Name = "Icon"
    FloatIcon.Size = UDim2.new(1, 0, 1, 0)
    FloatIcon.BackgroundTransparency = 1
    FloatIcon.Font = Enum.Font.GothamBold
    FloatIcon.Text = "🍎"
    FloatIcon.TextSize = 26
    FloatIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    FloatIcon.ZIndex = 1001
    FloatIcon.Parent = FloatButton

    local floatDrag = Utils.MakeDraggable(FloatButton, FloatButton, true)

    -- 4) Main window: 440x285, draggable by its top bar -----------------
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, WIN_W, 0, WIN_H)
    MainFrame.Position = UDim2.new(0, startX, 0, startY)
    MainFrame.BackgroundColor3 = C_BG
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Visible = true
    MainFrame.Active = true
    MainFrame.ZIndex = 900
    MainFrame.Parent = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(40, 42, 55)
    MainStroke.Thickness = 1.5
    MainStroke.Parent = MainFrame

    -- Header / TopBar
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 38)
    TopBar.BackgroundColor3 = C_TOPBAR
    TopBar.BorderSizePixel = 0
    TopBar.Active = true -- required to catch touch input on mobile
    TopBar.Parent = MainFrame
    Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 10)

    local mainDrag = Utils.MakeDraggable(TopBar, MainFrame, true)

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0.7, 0, 1, 0)
    Title.Position = UDim2.new(0, 14, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.Text = "REDZ STYLE • BLOX FRUITS FINDER (DELTA)"
    Title.TextColor3 = C_TEXT
    Title.TextSize = 13
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TopBar

    local TitleDot = Instance.new("Frame")
    TitleDot.Size = UDim2.new(0, 8, 0, 8)
    TitleDot.Position = UDim2.new(0, 3, 0.5, -4)
    TitleDot.BackgroundColor3 = C_ACCENT
    TitleDot.BorderSizePixel = 0
    TitleDot.Parent = TopBar
    Instance.new("UICorner", TitleDot).CornerRadius = UDim.new(1, 0)

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = C_TEXT_MUTED
    CloseBtn.TextSize = 13
    CloseBtn.Parent = TopBar
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        Utils.Notify("Delta Blox Fruits", "تم إخفاء الواجهة، اضغط على أيقونة 🍎 لإرجاعها.", 3)
    end)

    FloatButton.MouseButton1Click:Connect(function()
        -- A finger drag must never toggle the window by accident
        if floatDrag.WasDragged then
            floatDrag.WasDragged = false
            return
        end
        MainFrame.Visible = not MainFrame.Visible
    end)

    -- Status Bar
    local InfoBar = Instance.new("Frame")
    InfoBar.Size = UDim2.new(1, -20, 0, 24)
    InfoBar.Position = UDim2.new(0, 10, 0, 42)
    InfoBar.BackgroundColor3 = C_CARD
    InfoBar.BorderSizePixel = 0
    InfoBar.Parent = MainFrame
    Instance.new("UICorner", InfoBar).CornerRadius = UDim.new(0, 5)

    local InfoText = Instance.new("TextLabel")
    InfoText.Size = UDim2.new(1, -10, 1, 0)
    InfoText.Position = UDim2.new(0, 8, 0, 0)
    InfoText.BackgroundTransparency = 1
    InfoText.Font = Enum.Font.GothamMedium
    InfoText.Text = string.format("🌊 Sea %d | 👥 اللاعبين: %d/12 | 🆔 السيرفر: %s",
        Utils.GetCurrentSea(), #Players:GetPlayers(), string.sub(tostring(game.JobId), 1, 10) .. "...")
    InfoText.TextColor3 = C_TEXT_MUTED
    InfoText.TextSize = 11
    InfoText.TextXAlignment = Enum.TextXAlignment.Left
    InfoText.Parent = InfoBar

    -- Tabs Sidebar (proportional so the window stays responsive on phones)
    local SIDEBAR_W = math.floor(WIN_W * 0.27)
    if SIDEBAR_W < 96 then
        SIDEBAR_W = 96
    end

    local TabContainer = Instance.new("Frame")
    TabContainer.Size = UDim2.new(0, SIDEBAR_W, 1, -74)
    TabContainer.Position = UDim2.new(0, 10, 0, 70)
    TabContainer.BackgroundColor3 = C_TOPBAR
    TabContainer.BorderSizePixel = 0
    TabContainer.Parent = MainFrame
    Instance.new("UICorner", TabContainer).CornerRadius = UDim.new(0, 6)

    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(1, -(SIDEBAR_W + 25), 1, -74)
    ContentContainer.Position = UDim2.new(0, SIDEBAR_W + 15, 0, 70)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame

    local tabs = {}
    local tabButtons = {}

    local function createTab(name, icon, id)
        local page = Instance.new("ScrollingFrame")
        page.Name = id .. "Page"
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = C_ACCENT
        page.Visible = false
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.Parent = ContentContainer

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 6)
        layout.Parent = page

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 2)
        padding.PaddingBottom = UDim.new(0, 10)
        padding.PaddingRight = UDim.new(0, 4)
        padding.Parent = page

        tabs[id] = page
        return page
    end

    local tabHopper = createTab("السيرفر", "🌐", "Hopper")
    local tabFilters = createTab("الفلاتر", "🔍", "Filters")
    local tabWebhook = createTab("الويب هوك", "📡", "Webhook")
    local tabLive = createTab("الفحص الحي", "📋", "Live")

    local tabList = {
        { id = "Hopper", label = "🌐 التنقل", page = tabHopper },
        { id = "Filters", label = "🔍 الفلاتر", page = tabFilters },
        { id = "Webhook", label = "📡 الويب هوك", page = tabWebhook },
        { id = "Live", label = "📋 الفحص الحي", page = tabLive },
    }

    local function switchTab(activeId)
        for _, item in ipairs(tabList) do
            local isActive = (item.id == activeId)
            item.page.Visible = isActive
            local btn = tabButtons[item.id]
            if btn then
                btn.BackgroundColor3 = isActive and C_ACCENT or Color3.fromRGB(24, 26, 34)
                btn.TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or C_TEXT_MUTED
            end
        end
    end

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.Parent = TabContainer

    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingTop = UDim.new(0, 6)
    tabPad.PaddingLeft = UDim.new(0, 6)
    tabPad.PaddingRight = UDim.new(0, 6)
    tabPad.Parent = TabContainer

    for idx, item in ipairs(tabList) do
        local btn = Instance.new("TextButton")
        btn.Name = item.id .. "Btn"
        btn.Size = UDim2.new(1, 0, 0, 34)
        btn.BackgroundColor3 = (idx == 1) and C_ACCENT or Color3.fromRGB(24, 26, 34)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamMedium
        btn.Text = item.label
        btn.TextColor3 = (idx == 1) and Color3.fromRGB(255, 255, 255) or C_TEXT_MUTED
        btn.TextSize = 12
        btn.Parent = TabContainer
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        tabButtons[item.id] = btn
        btn.MouseButton1Click:Connect(function() switchTab(item.id) end)
    end

    local function createToggle(parentPage, text, defaultVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 36)
        frame.BackgroundColor3 = C_CARD
        frame.BorderSizePixel = 0
        frame.Parent = parentPage
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -55, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.Text = text
        label.TextColor3 = C_TEXT
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, 38, 0, 22)
        toggleBtn.Position = UDim2.new(1, -44, 0.5, -11)
        toggleBtn.BackgroundColor3 = defaultVal and C_GREEN or C_GRAY
        toggleBtn.BorderSizePixel = 0
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.Text = defaultVal and "ON" or "OFF"
        toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleBtn.TextSize = 10
        toggleBtn.Parent = frame
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 11)

        local state = defaultVal
        toggleBtn.MouseButton1Click:Connect(function()
            state = not state
            toggleBtn.BackgroundColor3 = state and C_GREEN or C_GRAY
            toggleBtn.Text = state and "ON" or "OFF"
            if callback then callback(state) end
        end)
        return frame
    end

    local function createButton(parentPage, text, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 34)
        btn.BackgroundColor3 = color or C_CARD
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamMedium
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Parent = parentPage
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        btn.MouseButton1Click:Connect(function() if callback then callback() end end)
        return btn
    end

    -- TAB 1: HOPPER
    createToggle(tabHopper, "🚀 تنقل تلقائي بين السيرفرات (Auto Hop)", Config.AutoHop, function(val)
        Config.AutoHop = val
        if val then
            Hop.StartAutoHop(game.PlaceId, function()
                local res = Detector.ScanAll()
                UI.HandleScanResults(res)
                return res
            end)
        else
            Hop.StopAutoHop()
        end
    end)

    createToggle(tabHopper, "🛑 إيقاف التنقل عند العثور على نادر (Auto Stay)", Config.AutoStayOnFind, function(val)
        Config.AutoStayOnFind = val
    end)

    createToggle(tabHopper, "⚡ انتقال فوري لمكان الهدف (Auto Teleport)", Config.AutoTeleport, function(val)
        Config.AutoTeleport = val
    end)

    createButton(tabHopper, "⏩ تنقل لسيرفر جديد الآن (Hop Next)", C_ACCENT, function()
        Hop.HopOnce(game.PlaceId)
    end)

    createButton(tabHopper, "📋 نسخ كود الانضمام لهذا السيرفر للحافظة", Color3.fromRGB(40, 45, 60), function()
        local scriptStr = Utils.GetJoinScript(game.PlaceId, game.JobId)
        Utils.SetClipboard(scriptStr)
        Utils.Notify("تم النسخ بنجاح!", "تم نسخ كود الدخول للحافظة، يمكنك لصقه بحسابك الأساسي.", 4)
    end)

    createButton(tabHopper, "📱 نسخ رابط الجوين للجوال (Mobile Deep Link)", Color3.fromRGB(40, 45, 60), function()
        local linkStr = Utils.GetMobileJoinLink(game.PlaceId, game.JobId)
        Utils.SetClipboard(linkStr)
        Utils.Notify("تم النسخ!", "تم نسخ رابط التطبيق المباشر للجوال.", 4)
    end)

    -- TAB 2: FILTERS
    createToggle(tabFilters, "🍇 فواكه نادرة فقط (Mythical & Legendary)", (Config.FruitFilter == "RareOnly"), function(val)
        if val then
            Config.FruitFilter = "RareOnly"
            Config.MinFruitRarity = 4
        else
            Config.FruitFilter = "All"
            Config.MinFruitRarity = 1
        end
        Utils.Notify("الفلتر", "تم تحديث فلتر الفواكه: " .. Config.FruitFilter, 3)
    end)

    createToggle(tabFilters, "👑 فحص البوسات والريد (Special Bosses)", Config.DetectRaidBosses, function(val)
        Config.DetectRaidBosses = val
        Config.DetectBosses = val
    end)

    createToggle(tabFilters, "⚔️ فحص بوسات الإيليت (Urban, Deandre, Diablo)", Config.DetectEliteBosses, function(val)
        Config.DetectEliteBosses = val
    end)

    createToggle(tabFilters, "🏝️ فحص جزيرة الميراج (Mirage Island)", Config.DetectMirageIsland, function(val)
        Config.DetectMirageIsland = val
    end)

    createToggle(tabFilters, "🌕 فحص اكتمال القمر (Full Moon 100%)", Config.DetectFullMoon, function(val)
        Config.DetectFullMoon = val
    end)

    createToggle(tabFilters, "🗡️ كشف بائع السيوف الأسطوري (Sea 2 Dealer)", Config.DetectSwordDealer, function(val)
        Config.DetectSwordDealer = val
    end)

    createToggle(tabFilters, "🔔 تشغيل رنة تنبيه صوتية عند الاكتشاف", Config.SoundAlert, function(val)
        Config.SoundAlert = val
    end)

    -- TAB 3: WEBHOOK
    local webhookBoxContainer = Instance.new("Frame")
    webhookBoxContainer.Size = UDim2.new(1, 0, 0, 42)
    webhookBoxContainer.BackgroundColor3 = C_CARD
    webhookBoxContainer.BorderSizePixel = 0
    webhookBoxContainer.Parent = tabWebhook
    Instance.new("UICorner", webhookBoxContainer).CornerRadius = UDim.new(0, 6)

    local webhookBox = Instance.new("TextBox")
    webhookBox.Size = UDim2.new(1, -16, 1, -10)
    webhookBox.Position = UDim2.new(0, 8, 0, 5)
    webhookBox.BackgroundTransparency = 1
    webhookBox.Font = Enum.Font.Gotham
    webhookBox.PlaceholderText = "الصق رابط الـ Webhook هنا..."
    webhookBox.PlaceholderColor3 = C_TEXT_MUTED
    webhookBox.Text = Config.WebhookURL or ""
    webhookBox.TextColor3 = C_TEXT
    webhookBox.TextSize = 11
    webhookBox.ClearTextOnFocus = false
    webhookBox.Parent = webhookBoxContainer

    webhookBox.FocusLost:Connect(function()
        Config.WebhookURL = webhookBox.Text
        if #Config.WebhookURL > 10 then Config.WebhookEnabled = true end
    end)

    createToggle(tabWebhook, "📡 تفعيل إرسال التنبيهات للديسكورد", Config.WebhookEnabled, function(val)
        Config.WebhookEnabled = val
    end)

    createButton(tabWebhook, "🧪 إرسال رسالة تجريبية الآن (Test Webhook)", Color3.fromRGB(46, 117, 89), function()
        Config.WebhookURL = webhookBox.Text
        if not Config.WebhookURL or #Config.WebhookURL < 10 then
            Utils.Notify("خطأ", "يرجى كتابة رابط Webhook صحيح أولاً!", 4)
            return
        end
        Utils.Notify("جاري الإرسال...", "يتم إرسال رسالة تجريبية للديسكورد...", 3)
        local ok, err = Notifier.TestWebhook(Config.WebhookURL)
        if ok then
            Utils.Notify("نجاح! 🎉", "تم إرسال التجربة بنجاح، تفقد سيرفرك بالديسكورد!", 5)
        else
            Utils.Notify("فشل الإرسال", "تأكد من صحة الرابط: " .. tostring(err), 5)
        end
    end)

    local helpCard = Instance.new("Frame")
    helpCard.Size = UDim2.new(1, 0, 0, 75)
    helpCard.BackgroundColor3 = Color3.fromRGB(22, 23, 30)
    helpCard.BorderSizePixel = 0
    helpCard.Parent = tabWebhook
    Instance.new("UICorner", helpCard).CornerRadius = UDim.new(0, 6)

    local helpLabel = Instance.new("TextLabel")
    helpLabel.Size = UDim2.new(1, -16, 1, -10)
    helpLabel.Position = UDim2.new(0, 8, 0, 5)
    helpLabel.BackgroundTransparency = 1
    helpLabel.Font = Enum.Font.Gotham
    helpLabel.Text = "💡 كيف تسوي Webhook في دقيقة:\n1. في ديسكورد، اضغط كليك يمين على قناتك واختر Edit Channel.\n2. اضغط Integrations ثم Webhooks ثم New Webhook.\n3. انسخ الرابط والصقه في الخانة فوق واضغط تجربة."
    helpLabel.TextColor3 = C_TEXT_MUTED
    helpLabel.TextSize = 10
    helpLabel.TextWrapped = true
    helpLabel.TextXAlignment = Enum.TextXAlignment.Left
    helpLabel.Parent = helpCard

    -- TAB 4: LIVE SCAN RESULTS
    local scanNowBtn = createButton(tabLive, "🔄 فحص السيرفر الحالي الآن", C_ACCENT, function()
        Utils.Notify("جاري الفحص...", "يتم فحص محتويات السيرفر الآن...", 2)
        local res = Detector.ScanAll()
        UI.HandleScanResults(res)
        UI.RenderLiveResults(tabLive, res)
    end)
    scanNowBtn.LayoutOrder = 1

    local resultsContainer = Instance.new("Frame")
    resultsContainer.Name = "ResultsContainer"
    resultsContainer.Size = UDim2.new(1, 0, 0, 160)
    resultsContainer.BackgroundTransparency = 1
    resultsContainer.LayoutOrder = 2
    resultsContainer.Parent = tabLive

    local resLayout = Instance.new("UIListLayout")
    resLayout.SortOrder = Enum.SortOrder.LayoutOrder
    resLayout.Padding = UDim.new(0, 6)
    resLayout.Parent = resultsContainer

    switchTab("Hopper")

    -- 5) UI instance handle: used by the re-execution cleanup -----------
    local dragControllers = { floatDrag, mainDrag }

    local uiInstance = {
        ScreenGui = ScreenGui,
        MainFrame = MainFrame,
        ResultsContainer = resultsContainer,
        TabLive = tabLive,
        ParentContainer = chosenParent,
        DragControllers = dragControllers,
    }

    function uiInstance.Destroy()
        for _, controller in ipairs(dragControllers) do
            pcall(function()
                controller.Destroy()
            end)
        end
        dragControllers = {}
        if ScreenGui then
            pcall(function()
                ScreenGui:Destroy()
            end)
        end
    end

    return uiInstance
end

function UI.RenderLiveResults(tabLive, scanResult)
    if not tabLive or not scanResult then return end
    local container = tabLive:FindFirstChild("ResultsContainer")
    if not container then return end

    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local C_CARD = Color3.fromRGB(26, 28, 38)
    local C_TEXT = Color3.fromRGB(240, 240, 245)
    local C_TEXT_MUTED = Color3.fromRGB(150, 155, 170)
    local C_ACCENT = Color3.fromRGB(255, 51, 85)
    local itemCount = 0

    for _, fruit in ipairs(scanResult.Fruits or {}) do
        itemCount = itemCount + 1
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, 0, 0, 50)
        itemFrame.BackgroundColor3 = C_CARD
        itemFrame.BorderSizePixel = 0
        itemFrame.Parent = container
        Instance.new("UICorner", itemFrame).CornerRadius = UDim.new(0, 6)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -110, 0, 22)
        title.Position = UDim2.new(0, 8, 0, 4)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = "🍇 " .. fruit.Name .. " (" .. fruit.Arabic .. ")"
        title.TextColor3 = C_TEXT
        title.TextSize = 11
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = itemFrame

        local desc = Instance.new("TextLabel")
        desc.Size = UDim2.new(1, -110, 0, 18)
        desc.Position = UDim2.new(0, 8, 0, 26)
        desc.BackgroundTransparency = 1
        desc.Font = Enum.Font.Gotham
        desc.Text = "الندرة: " .. fruit.RarityName .. " | المسافة: " .. tostring(fruit.Distance) .. "م"
        desc.TextColor3 = C_TEXT_MUTED
        desc.TextSize = 10
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.Parent = itemFrame

        local tpBtn = Instance.new("TextButton")
        tpBtn.Size = UDim2.new(0, 95, 0, 32)
        tpBtn.Position = UDim2.new(1, -100, 0.5, -16)
        tpBtn.BackgroundColor3 = C_ACCENT
        tpBtn.BorderSizePixel = 0
        tpBtn.Font = Enum.Font.GothamMedium
        tpBtn.Text = "انتقال لها ⚡"
        tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        tpBtn.TextSize = 10
        tpBtn.Parent = itemFrame
        Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 6)

        tpBtn.MouseButton1Click:Connect(function()
            pcall(function()
                local char = Players.LocalPlayer.Character
                local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
                if hrp and fruit.Position then
                    hrp.CFrame = CFrame.new(fruit.Position + Vector3.new(0, 3, 0))
                    Utils.Notify("انتقال", "تم الانتقال إلى الفاكهة بنجاح!", 3)
                end
            end)
        end)
    end

    for _, boss in ipairs(scanResult.Bosses or {}) do
        itemCount = itemCount + 1
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, 0, 0, 50)
        itemFrame.BackgroundColor3 = C_CARD
        itemFrame.BorderSizePixel = 0
        itemFrame.Parent = container
        Instance.new("UICorner", itemFrame).CornerRadius = UDim.new(0, 6)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -110, 0, 22)
        title.Position = UDim2.new(0, 8, 0, 4)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = "👑 " .. boss.Name .. " (" .. boss.Arabic .. ")"
        title.TextColor3 = C_TEXT
        title.TextSize = 11
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = itemFrame

        local desc = Instance.new("TextLabel")
        desc.Size = UDim2.new(1, -110, 0, 18)
        desc.Position = UDim2.new(0, 8, 0, 26)
        desc.BackgroundTransparency = 1
        desc.Font = Enum.Font.Gotham
        desc.Text = "النوع: " .. boss.Type .. " | الصحة: " .. tostring(boss.HealthPercent) .. "%"
        desc.TextColor3 = C_TEXT_MUTED
        desc.TextSize = 10
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.Parent = itemFrame

        local tpBtn = Instance.new("TextButton")
        tpBtn.Size = UDim2.new(0, 95, 0, 32)
        tpBtn.Position = UDim2.new(1, -100, 0.5, -16)
        tpBtn.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
        tpBtn.BorderSizePixel = 0
        tpBtn.Font = Enum.Font.GothamMedium
        tpBtn.Text = "انتقال للبوس ⚔️"
        tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        tpBtn.TextSize = 10
        tpBtn.Parent = itemFrame
        Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 6)

        tpBtn.MouseButton1Click:Connect(function()
            pcall(function()
                local char = Players.LocalPlayer.Character
                local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
                if hrp and boss.Position then
                    hrp.CFrame = CFrame.new(boss.Position + Vector3.new(0, 10, 0))
                    Utils.Notify("انتقال", "تم الانتقال إلى موقع البوس!", 3)
                end
            end)
        end)
    end

    if scanResult.Mirage and scanResult.Mirage.Found then
        itemCount = itemCount + 1
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, 0, 0, 44)
        itemFrame.BackgroundColor3 = Color3.fromRGB(20, 45, 50)
        itemFrame.BorderSizePixel = 0
        itemFrame.Parent = container
        Instance.new("UICorner", itemFrame).CornerRadius = UDim.new(0, 6)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -10, 1, 0)
        title.Position = UDim2.new(0, 10, 0, 0)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = "🏝️ جزيرة الميراج نشطة بالسيرفر الحالي!"
        title.TextColor3 = Color3.fromRGB(0, 255, 240)
        title.TextSize = 11
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = itemFrame
    end

    if scanResult.FullMoon and scanResult.FullMoon.IsFullMoon then
        itemCount = itemCount + 1
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, 0, 0, 44)
        itemFrame.BackgroundColor3 = Color3.fromRGB(50, 45, 20)
        itemFrame.BorderSizePixel = 0
        itemFrame.Parent = container
        Instance.new("UICorner", itemFrame).CornerRadius = UDim.new(0, 6)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -10, 1, 0)
        title.Position = UDim2.new(0, 10, 0, 0)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = "🌕 اكتمال القمر نشط (Full Moon 100%)!"
        title.TextColor3 = Color3.fromRGB(255, 215, 0)
        title.TextSize = 11
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = itemFrame
    end

    if itemCount == 0 then
        local emptyFrame = Instance.new("Frame")
        emptyFrame.Size = UDim2.new(1, 0, 0, 60)
        emptyFrame.BackgroundColor3 = C_CARD
        emptyFrame.BorderSizePixel = 0
        emptyFrame.Parent = container
        Instance.new("UICorner", emptyFrame).CornerRadius = UDim.new(0, 6)

        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, -20, 1, 0)
        emptyLabel.Position = UDim2.new(0, 10, 0, 0)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.Text = "لم يتم رصد عناصر مطابقة للفلتر في هذا السيرفر.\n(إذا كان التنقل التلقائي مفعلاً فسيتم الانتقال تلقائياً)"
        emptyLabel.TextColor3 = C_TEXT_MUTED
        emptyLabel.TextSize = 11
        emptyLabel.TextWrapped = true
        emptyLabel.Parent = emptyFrame
    end
end

function UI.HandleScanResults(scanResult)
    if not scanResult then return end

    for _, fruit in ipairs(scanResult.Fruits or {}) do
        Notifier.NotifyFruit(fruit)
        if Config.AutoTeleport and fruit.Position then
            pcall(function()
                local char = Players.LocalPlayer.Character
                local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
                if hrp then hrp.CFrame = CFrame.new(fruit.Position + Vector3.new(0, 3, 0)) end
            end)
        end
    end

    for _, boss in ipairs(scanResult.Bosses or {}) do
        Notifier.NotifyBoss(boss)
    end

    if scanResult.Mirage and scanResult.Mirage.Found then
        Notifier.NotifyMirage(scanResult.Mirage)
    end

    if scanResult.FullMoon and scanResult.FullMoon.IsFullMoon then
        Notifier.NotifyFullMoon(scanResult.FullMoon)
    end

    if scanResult.SwordDealer and scanResult.SwordDealer.Found then
        Notifier.NotifySwordDealer(scanResult.SwordDealer)
    end
end

-----------------------------------------------------------------------
-- SECTION 8: STARTUP & INITIALIZATION
-----------------------------------------------------------------------
local function Init()
    Utils.Notify("Delta Blox Fruits", "جاري تهيئة واجهة Redz Hub...", 3)

    local uiInstance = UI.Create()
    if not uiInstance then
        warn("[DeltaBlox] UI failed to initialize. Aborting startup.")
        return
    end
    Session.UI = uiInstance

    -- Initial scan on server join
    Session.Spawn(function()
        task.wait(2)
        if not Session.Alive then return end
        local initialScan = Detector.ScanAll()
        UI.HandleScanResults(initialScan)
        if uiInstance.TabLive then
            UI.RenderLiveResults(uiInstance.TabLive, initialScan)
        end
    end)

    if WAS_RESTART then
        Utils.Notify("تم إعادة التشغيل ✅", "تم حذف النسخة القديمة وتشغيل نسخة جديدة بنجاح.", 4)
        print("[DeltaBlox] Re-executed: old instance removed, new instance running.")
    end

    print("[DeltaBlox] Redz Hub Fruit & Boss Finder initialized successfully!")
end

Init()
