--[[
    ===================================================================
    🔥 REDZ STYLE BLOX FRUITS FINDER & HOPPER - MAIN ENTRY LOADER 🔥
    ===================================================================
    - Repository: slam27893-del/Script
    - Executor: Delta Mobile (Android / iOS) & PC Compatible
    -------------------------------------------------------------------
    - Loads the modular source (src/**) from the main branch.
    - If any module fails to load, it falls back to the standalone
      bundle.lua automatically.
    - Re-execution safe: there is NO restart lock. Running this file
      again shuts the previous instance down (threads, connections and
      the old ScreenGui) and boots a brand new one.
    ===================================================================
]]

local REPO_BASE = "https://raw.githubusercontent.com/slam27893-del/Script/main"

local Players = game:GetService("Players")

local GLOBAL_SESSION_KEY = "__DeltaBloxFruitsFinderSession"
local GUI_NAME = "DeltaBloxFruitsFinder"

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

local function isInstance(value)
    if value == nil then
        return false
    end
    local ok, name = pcall(function()
        return value.Name
    end)
    return ok and type(name) == "string"
end

-- gethui() first, then CoreGui, then PlayerGui (always safe)
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
        local localPlayer = Players.LocalPlayer
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

local function destroyOldGuis()
    for _, parent in ipairs(getGuiParents()) do
        local guard = 0
        local target = parent:FindFirstChild(GUI_NAME, true)
        while target and guard < 8 do
            guard = guard + 1
            pcall(function()
                target:Destroy()
            end)
            target = parent:FindFirstChild(GUI_NAME, true)
        end
    end
end

-- Shuts down a previous run (modular OR bundle) before starting this one
local function shutdownPrevious()
    local previous = ENV[GLOBAL_SESSION_KEY]
    if type(previous) ~= "table" then
        destroyOldGuis()
        return false
    end

    pcall(function()
        if type(previous.Destroy) == "function" then
            previous.Destroy(previous)
        else
            if type(previous.Hop) == "table" and type(previous.Hop.StopAutoHop) == "function" then
                previous.Hop.StopAutoHop()
            end
            if type(previous.Threads) == "table" then
                for _, thread in ipairs(previous.Threads) do
                    pcall(task.cancel, thread)
                end
            end
            if type(previous.Connections) == "table" then
                for _, connection in ipairs(previous.Connections) do
                    pcall(function()
                        connection:Disconnect()
                    end)
                end
            end
            if previous.ScreenGui then
                pcall(function()
                    previous.ScreenGui:Destroy()
                end)
            end
        end
    end)

    destroyOldGuis()
    return true
end

-- Session of this run: tracks threads and event connections
local Session = {
    Kind = "modular",
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

function Session.Spawn(fn, arg1, arg2)
    local thread = task.spawn(function()
        if not Session.Alive then
            return
        end
        local ok, err = pcall(fn, arg1, arg2)
        if not ok then
            warn("[MainLoader] Thread error: " .. tostring(err))
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

    for _, thread in ipairs(Session.Threads) do
        pcall(function()
            if coroutine.status(thread) ~= "dead" then
                task.cancel(thread)
            end
        end)
    end
    Session.Threads = {}

    for _, connection in ipairs(Session.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    Session.Connections = {}

    if Session.Hop and type(Session.Hop.StopAutoHop) == "function" then
        pcall(Session.Hop.StopAutoHop)
    end

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
    print("[MainLoader] Previous instance shut down cleanly (re-execution safe).")
end

-- Helper to safely load remote Lua files
local function loadModule(relPath)
    local url = REPO_BASE .. "/" .. relPath
    local success, content = pcall(function()
        return game:HttpGet(url)
    end)
    if success and content and #content > 10 then
        local chunk, err = loadstring(content)
        if chunk then
            return chunk()
        else
            warn("[MainLoader] Syntax error in module " .. relPath .. ": " .. tostring(err))
        end
    else
        warn("[MainLoader] Could not fetch remote module " .. relPath .. ", falling back...")
    end
    return nil
end

-- Forward declaration (defined after Start, used inside it)
local StartBundle

-- Try loading modular components first, fallback to self-contained bundle
local function Start()
    print("[DeltaBlox] Bootstrapping Redz Style Blox Fruits Finder...")

    local Constants = loadModule("src/core/constants.lua")
    local Utils = loadModule("src/core/utils.lua")
    local Config = loadModule("src/config.lua")
    local Detector = loadModule("src/modules/detector.lua")
    local Hop = loadModule("src/modules/hop.lua")
    local Notifier = loadModule("src/modules/notifier.lua")
    local UI = loadModule("src/modules/ui.lua")

    if Constants and Utils and Config and Detector and Hop and Notifier and UI then
        -- Modules are ready: shut down the previous run and register this one
        local wasRestart = shutdownPrevious()
        ENV[GLOBAL_SESSION_KEY] = Session
        Session.Hop = Hop

        Utils.Notify("Delta Blox Fruits", "تم تحميل الوحدات النمطية بنجاح!", 3)
        local uiInstance = UI.Create(Config, Constants, Utils, Detector, Hop, Notifier)
        if not uiInstance then
            warn("[MainLoader] UI failed to initialize, falling back to bundle.lua...")
            ENV[GLOBAL_SESSION_KEY] = nil
            return StartBundle()
        end
        Session.UI = uiInstance
        Session.ScreenGui = uiInstance.ScreenGui

        Session.Spawn(function()
            task.wait(2)
            if not Session.Alive then return end
            local res = Detector.ScanAll(Config, Constants)
            UI.HandleScanResults(res, Config, Constants, Utils, Notifier)
            if uiInstance.TabLive then
                UI.RenderLiveResults(uiInstance.TabLive, res, Config, Constants, Utils)
            end
        end)

        if wasRestart then
            Utils.Notify("تم إعادة التشغيل ✅", "تم حذف النسخة القديمة وتشغيل نسخة جديدة بنجاح.", 4)
        end
        print("[MainLoader] Modular initialization complete.")
    else
        -- Fallback to standalone bundle
        StartBundle()
    end
end

-- Fallback: download and run the self-contained bundle.lua
StartBundle = function()
    warn("[MainLoader] Modular load incomplete, executing bundle.lua...")
    local bundleSuccess, bundleCode = pcall(function()
        return game:HttpGet(REPO_BASE .. "/bundle.lua")
    end)
    if bundleSuccess and bundleCode then
        local chunk = loadstring(bundleCode)
        if chunk then
            chunk()
        else
            error("[MainLoader] bundle.lua has a syntax error!")
        end
    else
        error("[MainLoader] Failed to download bundle.lua!")
    end
end

Start()
