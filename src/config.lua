--[[
    Blox Fruits Server Finder - User Configuration
    You can edit this file directly, or adjust settings in real-time through the UI.
]]

local Config = {
    -- Discord Webhook Settings
    -- ضع رابط الويب هوك الخاص بديسكورد هنا بين علامتي التنصيص (اختياري)
    WebhookURL = "",
    WebhookEnabled = false,

    -- Fruit Scan Filter
    -- خيارات: "RareOnly" (فواكه أسطورية وميثيكال فقط), "All" (كل الفواكه), "MythicalOnly"
    FruitFilter = "RareOnly",
    MinFruitRarity = 4, -- 4 = Legendary & Mythical (Kitsune, Dragon, Leopard, Dough, Portal, Buddha, etc.)
    NotifyAllFruits = false,

    -- Boss Detectors
    DetectBosses = true,
    DetectEliteBosses = true, -- Sea 3 Elite Hunters (Urban, Deandre, Diablo)
    DetectRaidBosses = true,  -- rip_indra, Dough King, Darkbeard, etc.

    -- World Event Detectors (Disabled by default as requested, can be toggled via UI)
    DetectMirageIsland = false,
    DetectFullMoon = false,
    DetectSwordDealer = true, -- Sea 2 Legendary Sword Dealer (Shisui, Wando, Saddi)

    -- Server Hopper Settings
    AutoHop = false,
    HopDelay = 5,             -- الثواني المقضية لفحص السيرفر قبل الانتقال للسيرفر التالي
    MaxServerPlayers = 11,     -- تجنب السيرفرات الممتلئة (الحد الأقصى عادة 12)
    MinServerPlayers = 1,      -- تجنب السيرفرات الفارغة تماماً إن رغبت

    -- Behavior on Finding Rare Target (Switchable Mode)
    AutoStayOnFind = true,    -- إيقاف التنقل والبقاء في السيرفر عند العثور على شيء نادر
    AutoTeleport = false,     -- الانتقال التلقائي لمكان الفاكهة/البوس مباشرة
    SoundAlert = true,        -- تشغيل رنة تنبيه عند إيجاد شيء نادر
    NotifyInGame = true,      -- إظهار إشعار داخل اللعبة

    -- Internal Cache
    VisitedJobIds = {},
}

return Config
