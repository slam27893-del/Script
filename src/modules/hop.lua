--[[
    Blox Fruits Server Hopper Module
    Auto server hop with anti-repeat cache, Delta mobile compatibility, and queue management.
]]

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local Hop = {}
local isHoppingActive = false
local currentHopThread = nil
local visitedServers = {}
local historyFileName = "DeltaBlox_HopCache.json"

-- Load visited servers history if file system functions exist in executor
local function loadHistory(Utils)
    if readfile and isfile and isfile(historyFileName) then
        pcall(function()
            local content = readfile(historyFileName)
            local data = Utils.JsonDecode(content)
            if type(data) == "table" then
                for k, v in pairs(data) do
                    visitedServers[k] = v
                end
            end
        end)
    end
    -- Always mark current server as visited
    if game.JobId and game.JobId ~= "" then
        visitedServers[game.JobId] = true
    end
end

-- Save visited history
local function saveHistory(Utils)
    if writefile then
        pcall(function()
            writefile(historyFileName, Utils.JsonEncode(visitedServers))
        end)
    end
end

-- Fetch public servers list from Roblox API
local function fetchServerList(placeId, Utils, cursor)
    local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100", tostring(placeId))
    if cursor and cursor ~= "" then
        url = url .. "&cursor=" .. tostring(cursor)
    end

    local response, err = Utils.HttpRequest({
        Url = url,
        Method = "GET",
        Headers = {
            ["Content-Type"] = "application/json",
        },
    })

    if not response or not response.Body then
        return nil, err or "Empty response"
    end

    local data = Utils.JsonDecode(response.Body)
    if not data or not data.data then
        return nil, "Invalid JSON received from Roblox API"
    end

    return data
end

-- Find a valid target server
function Hop.FindNextServer(placeId, Config, Utils)
    local cursor = nil
    local attempts = 0
    local maxAttempts = 3

    while attempts < maxAttempts do
        attempts = attempts + 1
        local serverData, err = fetchServerList(placeId, Utils, cursor)
        if not serverData then
            task.wait(1.5)
        else
            local list = serverData.data
            for _, srv in ipairs(list) do
                local srvId = srv.id
                local playing = tonumber(srv.playing) or 0
                local maxPlayers = tonumber(srv.maxPlayers) or 12

                -- Validation checks
                if srvId ~= game.JobId and not visitedServers[srvId] then
                    if playing < (Config.MaxServerPlayers or 11) and playing >= (Config.MinServerPlayers or 1) then
                        return srvId, srv
                    end
                end
            end

            cursor = serverData.nextPageCursor
            if not cursor or cursor == "" then
                -- Reset cache if all available servers have been visited
                visitedServers = {}
                visitedServers[game.JobId] = true
                cursor = nil
            end
        end
        task.wait(1)
    end

    return nil, "No available server found"
end

-- Teleport to specific JobId
function Hop.TeleportToJobId(placeId, targetJobId, Utils)
    local player = Players.LocalPlayer
    if not player then return false end

    visitedServers[targetJobId] = true
    saveHistory(Utils)

    Utils.Notify("Delta Hopper", "جاري الانتقال للسيرفر: " .. string.sub(targetJobId, 1, 8) .. "...", 4)

    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, targetJobId, player)
    end)

    if not success then
        warn("[DeltaHopper] Teleport failed: " .. tostring(err))
        return false, err
    end
    return true
end

-- Hop to next available server
function Hop.HopOnce(placeId, Config, Utils)
    local targetId, srv = Hop.FindNextServer(placeId, Config, Utils)
    if targetId then
        return Hop.TeleportToJobId(placeId, targetId, Utils)
    else
        Utils.Notify("Delta Hopper", "لم يتم العثور على سيرفر متاح حالياً، يعاد المحاولة...", 3)
        return false, "No server found"
    end
end

-- Start automated hopper loop
function Hop.StartAutoHop(placeId, Config, Utils, scanCallback)
    if isHoppingActive then return end
    isHoppingActive = true
    loadHistory(Utils)

    currentHopThread = task.spawn(function()
        while isHoppingActive do
            -- 1. Perform detection scan in current server
            local scanResult = scanCallback and scanCallback()
            
            -- If rare target found and AutoStay is enabled, stop hopping!
            if scanResult and scanResult.HasTarget and Config.AutoStayOnFind then
                isHoppingActive = false
                Utils.PlayAlertSound()
                Utils.Notify("لقطة نادرة! 🎯", "تم العثور على هدف وإيقاف التنقل التلقائي لتثبيت الحساب.", 8)
                break
            end

            -- 2. Wait configured scan delay before hopping
            local delayTime = Config.HopDelay or 5
            for i = delayTime, 1, -1 do
                if not isHoppingActive then break end
                task.wait(1)
            end

            if not isHoppingActive then break end

            -- 3. Hop to next server
            local ok = Hop.HopOnce(placeId, Config, Utils)
            if not ok then
                task.wait(3)
            else
                -- Wait 15 seconds for teleport to process
                task.wait(15)
            end
        end
    end)
end

-- Stop automated hopper
function Hop.StopAutoHop()
    isHoppingActive = false
    if currentHopThread then
        task.cancel(currentHopThread)
        currentHopThread = nil
    end
end

-- Get Hopper Status
function Hop.IsHopping()
    return isHoppingActive
end

-- Teleport Fail listener
TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
    warn("[DeltaHopper] Teleport Init Failed: " .. tostring(errorMessage))
    if isHoppingActive then
        task.wait(2)
        Hop.HopOnce(game.PlaceId, { MaxServerPlayers = 11, MinServerPlayers = 1 }, {
            HttpRequest = function() end,
            Notify = function() end,
            JsonDecode = function() return nil end,
            JsonEncode = function() return "{}" end,
        })
    end
end)

return Hop
