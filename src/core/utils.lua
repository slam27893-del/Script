--[[
    Blox Fruits Utils - Mobile / Delta Optimized
    Handles HTTP requests, clipboard, touch dragging, notifications, and audio.
]]

local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local Utils = {}

-- Delta Mobile Compatible HTTP Request Wrapper
function Utils.HttpRequest(options)
    local requestFn = (syn and syn.request)
        or (http and http.request)
        or http_request
        or request
        or (fluxus and fluxus.request)

    if not requestFn then
        warn("[DeltaUtils] No compatible HTTP request function found in executor!")
        return nil, "No HTTP function"
    end

    local success, response = pcall(function()
        return requestFn(options)
    end)

    if not success then
        warn("[DeltaUtils] HTTP Request failed: " .. tostring(response))
        return nil, response
    end

    return response
end

-- Delta Mobile Compatible Clipboard Helper
function Utils.SetClipboard(text)
    local clipFn = setclipboard or toclipboard or (syn and syn.write_clipboard)
    if clipFn then
        pcall(function()
            clipFn(tostring(text))
        end)
        return true
    else
        warn("[DeltaUtils] Clipboard function not supported!")
        return false
    end
end

-- In-Game Native Notification
function Utils.Notify(title, message, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "Delta Blox Fruits",
            Text = message or "",
            Duration = duration or 6,
        })
    end)
end

-- Play Sound Alert
function Utils.PlayAlertSound()
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://4590662766" -- Pleasant chime/alert
        sound.Volume = 1
        sound.Parent = SoundService
        sound:Play()
        task.delay(3, function()
            sound:Destroy()
        end)
    end)
end

-- JSON Serialization Helpers
function Utils.JsonEncode(tbl)
    local success, res = pcall(function()
        return HttpService:JSONEncode(tbl)
    end)
    if success then return res end
    return "{}"
end

function Utils.JsonDecode(str)
    local success, res = pcall(function()
        return HttpService:JSONDecode(str)
    end)
    if success then return res end
    return nil
end

-- Current Sea Detection (1, 2, or 3)
function Utils.GetCurrentSea()
    local placeId = game.PlaceId
    if placeId == 2753915549 then
        return 1
    elseif placeId == 4442272183 then
        return 2
    elseif placeId == 7449423635 then
        return 3
    else
        return 0 -- Unknown / Test place
    end
end

-- Teleport Code Generator (Lua script to join this exact server)
function Utils.GetJoinScript(placeId, jobId)
    return string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s", game.Players.LocalPlayer)', tostring(placeId), tostring(jobId))
end

-- Roblox Mobile Deep Link for launching directly into server
function Utils.GetMobileJoinLink(placeId, jobId)
    return string.format("roblox://experiences/start?placeId=%s&gameInstanceId=%s", tostring(placeId), tostring(jobId))
end

-- Mobile & PC Touch/Mouse Dragging for UI
function Utils.MakeDraggable(topBar, mainFrame)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    local function update(input)
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    topBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

return Utils
