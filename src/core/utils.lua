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

-- Viewport size helper (Delta mobile / emulator safe)
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
    Mobile & PC Touch/Mouse Dragging for UI (Delta mobile optimized)
    - Finger (Touch) and mouse (PC / emulator) support.
    - Never lets the dragged element leave the screen.
    - Returns a controller:
        controller.Dragging    -> true while the finger holds the element
        controller.WasDragged  -> true right after a real drag gesture
        controller.Destroy()   -> disconnects all listeners
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

return Utils
