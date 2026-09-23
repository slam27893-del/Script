--[[
    Blox Fruits UI Module - Redz Hub & Quantum Hub Style
    Delta Mobile patch v2:
      * gethui() -> CoreGui -> PlayerGui safe parenting chain
      * DisplayOrder = 999999 and IgnoreGuiInset = true
      * Responsive 440x285 window + 52x52 draggable floating apple (ZIndex 1000)
      * Re-execution safe: the old GUI is destroyed and a new one is built
]]

local Players = game:GetService("Players")

local UI = {}

-- CoreGui is fetched inside a pcall: some Android / Delta builds block it
local CoreGui = nil
pcall(function()
    CoreGui = game:GetService("CoreGui")
end)

local GUI_NAME = "DeltaBloxFruitsFinder"

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

--[[
    Candidate ScreenGui parents ordered by Delta-mobile safety:
        1) gethui()                       -> executor hidden UI (first choice)
        2) CoreGui                        -> blocked on some Android builds
        3) Players.LocalPlayer.PlayerGui  -> always allowed safe fallback
]]
function UI.GetGuiParents()
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

    add(CoreGui)

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

-- Parents the ScreenGui to the first container that accepts it
function UI.ParentScreenGui(gui)
    for _, candidate in ipairs(UI.GetGuiParents()) do
        local ok = pcall(function()
            gui.Parent = candidate
        end)
        if ok and gui.Parent == candidate then
            return candidate
        end
    end

    -- Last resort: straight into PlayerGui (never blocked by Roblox)
    local ok = pcall(function()
        local localPlayer = Players.LocalPlayer
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

-- Destroys every leftover copy of this GUI (recursive, all GUI parents)
function UI.DestroyOldGuis()
    for _, parent in ipairs(UI.GetGuiParents()) do
        local guard = 0
        local target = parent:FindFirstChild(GUI_NAME, true)
        while target and guard < 8 do
            guard = guard + 1
            pcall(function()
                target:Destroy()
            end)
            target = parent:FindFirstChild(GUI_NAME, true)
        end

        local floatLeftover = parent:FindFirstChild("DeltaFloatBtn", true)
        if floatLeftover then
            pcall(function()
                floatLeftover:Destroy()
            end)
        end
    end
end

function UI.Create(Config, Constants, Utils, Detector, Hop, Notifier)
    -- Remove every previous instance before building the new UI
    UI.DestroyOldGuis()

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = GUI_NAME
    ScreenGui.ResetOnSpawn = false          -- survives respawn / death
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999999         -- above game buttons & other hubs
    ScreenGui.IgnoreGuiInset = true         -- draw over the mobile top inset
    ScreenGui.Enabled = true

    pcall(function() ScreenGui.ClipToDeviceSafeArea = false end)
    pcall(function() ScreenGui.OnTopOfCoreBlur = true end)

    local parent = UI.ParentScreenGui(ScreenGui)
    if not parent then
        warn("[DeltaBlox UI] Could not parent the ScreenGui in any GUI container!")
        return nil
    end

    -- Responsive mobile window size (base 440x285)
    local viewport = Utils.GetViewport()
    local BASE_W, BASE_H = 440, 285
    local fitScale = 1
    if viewport.X > 40 and viewport.Y > 40 then
        fitScale = math.min(1, (viewport.X - 16) / BASE_W, (viewport.Y - 16) / BASE_H)
    end
    if fitScale < 0.7 then
        fitScale = 0.7
    end
    local WIN_W = math.floor(BASE_W * fitScale)
    local WIN_H = math.floor(BASE_H * fitScale)
    local startX = math.max(8, math.floor((viewport.X - WIN_W) / 2))
    local startY = math.max(8, math.floor((viewport.Y - WIN_H) / 2))

    -- Color Palette (Redz Hub Dark & Neon Crimson)
    local C_BG = Color3.fromRGB(17, 18, 24)
    local C_TOPBAR = Color3.fromRGB(23, 24, 32)
    local C_CARD = Color3.fromRGB(26, 28, 38)
    local C_ACCENT = Color3.fromRGB(255, 51, 85) -- Redz Crimson Red
    local C_ACCENT_HOVER = Color3.fromRGB(255, 80, 110)
    local C_TEXT = Color3.fromRGB(240, 240, 245)
    local C_TEXT_MUTED = Color3.fromRGB(150, 155, 170)
    local C_GREEN = Color3.fromRGB(46, 204, 113)
    local C_GRAY = Color3.fromRGB(60, 65, 80)

    -- 1. Floating Mobile Toggle Icon: 52x52, ZIndex 1000, touch draggable
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

    local FloatCorner = Instance.new("UICorner")
    FloatCorner.CornerRadius = UDim.new(0, 26)
    FloatCorner.Parent = FloatButton

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

    -- 2. Main Window Frame (440x285, draggable by its top bar)
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

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame

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

    local TopBarCorner = Instance.new("UICorner")
    TopBarCorner.CornerRadius = UDim.new(0, 10)
    TopBarCorner.Parent = TopBar

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

    -- Close & Minimize Buttons
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

    -- Sub Info Bar (Current Sea, JobId summary, Server Status)
    local InfoBar = Instance.new("Frame")
    InfoBar.Size = UDim2.new(1, -20, 0, 24)
    InfoBar.Position = UDim2.new(0, 10, 0, 42)
    InfoBar.BackgroundColor3 = C_CARD
    InfoBar.BorderSizePixel = 0
    InfoBar.Parent = MainFrame
    Instance.new("UICorner", InfoBar).CornerRadius = UDim.new(0, 5)

    local currentSeaNum = Utils.GetCurrentSea()
    local InfoText = Instance.new("TextLabel")
    InfoText.Size = UDim2.new(1, -10, 1, 0)
    InfoText.Position = UDim2.new(0, 8, 0, 0)
    InfoText.BackgroundTransparency = 1
    InfoText.Font = Enum.Font.GothamMedium
    InfoText.Text = string.format("🌊 Sea %d | 👥 اللاعبين: %d/12 | 🆔 السيرفر: %s",
        currentSeaNum, #Players:GetPlayers(), string.sub(tostring(game.JobId), 1, 10) .. "...")
    InfoText.TextColor3 = C_TEXT_MUTED
    InfoText.TextSize = 11
    InfoText.TextXAlignment = Enum.TextXAlignment.Left
    InfoText.Parent = InfoBar

    -- Sidebar / Tab Selection (Left side, proportional for small phones)
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

    -- Content Area (Right side)
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(1, -(SIDEBAR_W + 25), 1, -74)
    ContentContainer.Position = UDim2.new(0, SIDEBAR_W + 15, 0, 70)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame

    -- Tabs Table
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

        btn.MouseButton1Click:Connect(function()
            switchTab(item.id)
        end)
    end

    -- Helper UI Component Builders
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

        return frame, function(newVal)
            state = newVal
            toggleBtn.BackgroundColor3 = state and C_GREEN or C_GRAY
            toggleBtn.Text = state and "ON" or "OFF"
        end
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

        btn.MouseButton1Click:Connect(function()
            if callback then callback() end
        end)
        return btn
    end

    -- ==========================================
    -- TAB 1: HOPPER & CONTROLS
    -- ==========================================
    local hopToggleFrame, setHopToggleUI = createToggle(tabHopper, "🚀 تنقل تلقائي بين السيرفرات (Auto Hop)", Config.AutoHop, function(val)
        Config.AutoHop = val
        if val then
            Hop.StartAutoHop(game.PlaceId, Config, Utils, function()
                local res = Detector.ScanAll(Config, Constants)
                UI.HandleScanResults(res, Config, Constants, Utils, Notifier)
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
        Hop.HopOnce(game.PlaceId, Config, Utils)
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

    -- ==========================================
    -- TAB 2: DETECTOR FILTERS
    -- ==========================================
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

    createToggle(tabFilters, "👑 فحص البوسات الخاصة والريد (Special Bosses)", Config.DetectRaidBosses, function(val)
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

    -- ==========================================
    -- TAB 3: DISCORD WEBHOOK
    -- ==========================================
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
        if #Config.WebhookURL > 10 then
            Config.WebhookEnabled = true
        end
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
        local ok, err = Notifier.TestWebhook(Config.WebhookURL, Utils)
        if ok then
            Utils.Notify("نجاح! 🎉", "تم إرسال التجربة بنجاح، تفقد قناتك بالديسكورد!", 5)
        else
            Utils.Notify("فشل الإرسال", "تأكد من صحة الرابط: " .. tostring(err), 5)
        end
    end)

    local helpCard = Instance.new("Frame")
    helpCard.Size = UDim2.new(1, 0, 0, 70)
    helpCard.BackgroundColor3 = Color3.fromRGB(22, 23, 30)
    helpCard.BorderSizePixel = 0
    helpCard.Parent = tabWebhook
    Instance.new("UICorner", helpCard).CornerRadius = UDim.new(0, 6)

    local helpLabel = Instance.new("TextLabel")
    helpLabel.Size = UDim2.new(1, -16, 1, -10)
    helpLabel.Position = UDim2.new(0, 8, 0, 5)
    helpLabel.BackgroundTransparency = 1
    helpLabel.Font = Enum.Font.Gotham
    helpLabel.Text = "💡 كيف تسوي Webhook في دقيقة:\n1. في ديسكورد، اضغط كليك يمين على قناتك واختر Edit Channel.\n2. اضغط Integrations ثم Webhooks ثم New Webhook.\n3. انسخ الرابط والصقه هنا واضغط اختبار."
    helpLabel.TextColor3 = C_TEXT_MUTED
    helpLabel.TextSize = 10
    helpLabel.TextWrapped = true
    helpLabel.TextXAlignment = Enum.TextXAlignment.Left
    helpLabel.Parent = helpCard

    -- ==========================================
    -- TAB 4: LIVE SCAN & RESULTS LOG
    -- ==========================================
    local scanNowBtn = createButton(tabLive, "🔄 فحص السيرفر الحالي الآن", C_ACCENT, function()
        Utils.Notify("جاري الفحص...", "يتم فحص محتويات السيرفر الآن...", 2)
        local res = Detector.ScanAll(Config, Constants)
        UI.HandleScanResults(res, Config, Constants, Utils, Notifier)
        UI.RenderLiveResults(tabLive, res, Config, Constants, Utils)
    end)

    local resultsContainer = Instance.new("Frame")
    resultsContainer.Name = "ResultsContainer"
    resultsContainer.Size = UDim2.new(1, 0, 0, 150)
    resultsContainer.BackgroundTransparency = 1
    resultsContainer.Parent = tabLive

    local resLayout = Instance.new("UIListLayout")
    resLayout.SortOrder = Enum.SortOrder.LayoutOrder
    resLayout.Padding = UDim.new(0, 6)
    resLayout.Parent = resultsContainer

    -- Initial Tab View
    switchTab("Hopper")

    -- Return control table (Destroy() is used by the re-execution cleanup)
    local dragControllers = { floatDrag, mainDrag }

    local uiInstance = {
        ScreenGui = ScreenGui,
        MainFrame = MainFrame,
        ResultsContainer = resultsContainer,
        TabLive = tabLive,
        SetHopToggleUI = setHopToggleUI,
        ParentContainer = parent,
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

-- Render Live Scan Results in Tab 4
function UI.RenderLiveResults(tabLive, scanResult, Config, Constants, Utils)
    if not tabLive or not scanResult then return end
    local container = tabLive:FindFirstChild("ResultsContainer")
    if not container then return end

    -- Clear previous items
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local C_CARD = Color3.fromRGB(26, 28, 38)
    local C_TEXT = Color3.fromRGB(240, 240, 245)
    local C_TEXT_MUTED = Color3.fromRGB(150, 155, 170)
    local C_ACCENT = Color3.fromRGB(255, 51, 85)

    local itemCount = 0

    -- Render Fruits
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

    -- Render Bosses
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

    -- Mirage Island Card
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
        title.Text = "🏝️ جزيرة الميراج نشطة في السيرفر الحالي!"
        title.TextColor3 = Color3.fromRGB(0, 255, 240)
        title.TextSize = 11
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = itemFrame
    end

    -- Full Moon Card
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

    -- Empty state
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
        emptyLabel.Text = "لم يتم رصد عناصر مطابقة للفلتر في هذا السيرفر.\n(إذا كان التنقل التلقائي مفعلاً فسيتم الانتقال قريباً)"
        emptyLabel.TextColor3 = C_TEXT_MUTED
        emptyLabel.TextSize = 11
        emptyLabel.TextWrapped = true
        emptyLabel.Parent = emptyFrame
    end
end

-- Scan Results dispatcher
function UI.HandleScanResults(scanResult, Config, Constants, Utils, Notifier)
    if not scanResult then return end

    -- Notify fruits
    for _, fruit in ipairs(scanResult.Fruits or {}) do
        Notifier.NotifyFruit(fruit, Config, Constants, Utils)
        if Config.AutoTeleport and fruit.Position then
            pcall(function()
                local char = Players.LocalPlayer.Character
                local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
                if hrp then
                    hrp.CFrame = CFrame.new(fruit.Position + Vector3.new(0, 3, 0))
                end
            end)
        end
    end

    -- Notify bosses
    for _, boss in ipairs(scanResult.Bosses or {}) do
        Notifier.NotifyBoss(boss, Config, Constants, Utils)
    end

    -- Notify Mirage
    if scanResult.Mirage and scanResult.Mirage.Found then
        Notifier.NotifyMirage(scanResult.Mirage, Config, Constants, Utils)
    end

    -- Notify Full Moon
    if scanResult.FullMoon and scanResult.FullMoon.IsFullMoon then
        Notifier.NotifyFullMoon(scanResult.FullMoon, Config, Constants, Utils)
    end

    -- Notify Sword Dealer
    if scanResult.SwordDealer and scanResult.SwordDealer.Found then
        Notifier.NotifySwordDealer(scanResult.SwordDealer, Config, Constants, Utils)
    end
end

return UI
