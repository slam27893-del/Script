--[[
    ===================================================================
    🔥 REDZ STYLE BLOX FRUITS FINDER & HOPPER - MAIN ENTRY LOADER 🔥
    ===================================================================
    - Repository: slam27893-del/Script
    - Executor: Delta Mobile (Android / iOS) & PC Compatible
    ===================================================================
]]

local REPO_BASE = "https://raw.githubusercontent.com/slam27893-del/Script/arena/01a0ccc0-script"

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
        -- Initialize modular setup
        Utils.Notify("Delta Blox Fruits", "تم تحميل الوحدات النمطية بنجاح!", 3)
        local uiInstance = UI.Create(Config, Constants, Utils, Detector, Hop, Notifier)

        task.spawn(function()
            task.wait(2)
            local res = Detector.ScanAll(Config, Constants)
            UI.HandleScanResults(res, Config, Constants, Utils, Notifier)
            if uiInstance and uiInstance.TabLive then
                UI.RenderLiveResults(uiInstance.TabLive, res, Config, Constants, Utils)
            end
        end)
    else
        -- Fallback to standalone bundle
        warn("[MainLoader] Modular load incomplete, executing bundle.lua...")
        local bundleSuccess, bundleCode = pcall(function()
            return game:HttpGet(REPO_BASE .. "/bundle.lua")
        end)
        if bundleSuccess and bundleCode then
            local chunk = loadstring(bundleCode)
            if chunk then
                chunk()
            end
        else
            error("[MainLoader] Failed to download bundle.lua!")
        end
    end
end

Start()
