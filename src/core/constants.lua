--[[
    Blox Fruits Constants & Database
    Compatible with Delta Executor (Mobile & PC)
]]

local Constants = {}

-- Blox Fruits Place IDs
Constants.PlaceIds = {
    Sea1 = 2753915549,
    Sea2 = 4442272183,
    Sea3 = 7449423635,
}

-- Sea Names mapping
Constants.SeaNames = {
    [2753915549] = "Sea 1 (First Sea)",
    [4442272183] = "Sea 2 (Second Sea)",
    [7449423635] = "Sea 3 (Third Sea)",
}

-- Rarity Enums & Metadata
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

-- Embed Colors (Hexadecimal integers for Discord)
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

-- Comprehensive Fruit Rarity Table (All Blox Fruits up to Update 24 / Latest)
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

-- Boss Lists Categorized by Importance & Sea
Constants.EliteBosses = {
    ["Urban"] = { Sea = 3, Title = "Urban the Elite Pirate", Arabic = "أوربان (إيليت)" },
    ["Deandre"] = { Sea = 3, Title = "Deandre the Elite Pirate", Arabic = "دياندري (إيليت)" },
    ["Diablo"] = { Sea = 3, Title = "Diablo the Elite Pirate", Arabic = "ديابلو (إيليت)" },
}

Constants.SpecialBosses = {
    -- Sea 3 Special/Raid Bosses
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

    -- Sea 2 Special Bosses
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

    -- Sea 1 Special Bosses
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

-- Full Moon Moon Texture IDs used by Blox Fruits skybox
Constants.FullMoonAssetIds = {
    ["rbxassetid://9709149431"] = true,
    ["rbxassetid://9709149052"] = true,
    ["http://www.roblox.com/asset/?id=9709149431"] = true,
    ["http://www.roblox.com/asset/?id=9709149052"] = true,
    ["9709149431"] = true,
    ["9709149052"] = true,
}

return Constants
