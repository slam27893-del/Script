--[[
    Blox Fruits Notifier Module
    Sends rich Discord Webhook embeds and in-game alerts for fruits, bosses, and events.
]]

local Players = game:GetService("Players")

local Notifier = {}

-- Send Webhook Payload via Utils.HttpRequest
local function sendWebhook(webhookUrl, payload, Utils)
    if not webhookUrl or webhookUrl == "" or not webhookUrl:find("discord") then
        return false, "Invalid or empty Discord Webhook URL"
    end

    local body = Utils.JsonEncode(payload)
    local response, err = Utils.HttpRequest({
        Url = webhookUrl,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
        },
        Body = body,
    })

    if not response then
        warn("[Notifier] Failed to send webhook: " .. tostring(err))
        return false, err
    end

    return true
end

-- Test Webhook function
function Notifier.TestWebhook(webhookUrl, Utils)
    local payload = {
        username = "Delta Blox Fruits Finder",
        avatar_url = "https://raw.githubusercontent.com/slam27893-del/Script/main/assets/icon.png",
        embeds = {
            {
                title = "✅ تجربة اتصال الويب هوك بنجاح!",
                description = "تم ربط سكربت Delta بنجاح مع سيرفر الديسكورد الخاص بك.\nأنت الآن جاهز لاستقبال تنبيهات الفواكه والبوسات والميراج فوراً!",
                color = 0x2ECC71, -- Emerald Green
                fields = {
                    {
                        name = "🎮 المكان الحالي",
                        value = string.format("Place ID: `%s`", tostring(game.PlaceId)),
                        inline = true,
                    },
                    {
                        name = "🆔 Job ID السيرفر",
                        value = string.format("`%s`", tostring(game.JobId)),
                        inline = true,
                    },
                },
                footer = {
                    text = "Delta Blox Fruits Finder • Active & Connected",
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }
        }
    }

    return sendWebhook(webhookUrl, payload, Utils)
end

-- Notify Spawned Fruit
function Notifier.NotifyFruit(fruit, Config, Constants, Utils)
    local placeId = game.PlaceId
    local seaName = Constants.SeaNames[placeId] or ("Sea " .. tostring(Utils.GetCurrentSea()))
    local joinScript = Utils.GetJoinScript(placeId, game.JobId)
    local playerCount = #Players:GetPlayers()
    local color = Constants.RarityColors[fruit.Rarity] or 0xE67E22

    -- 1. In-game notifications
    if Config.NotifyInGame then
        Utils.Notify("🍎 فاكهة مرسبنة: " .. fruit.Name, "الندرة: " .. fruit.RarityName .. " (" .. fruit.Arabic .. ")", 7)
    end
    if Config.SoundAlert then
        Utils.PlayAlertSound()
    end

    -- 2. Discord Webhook notification
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
                        {
                            name = "🌊 البحر (Sea)",
                            value = seaName,
                            inline = true,
                        },
                        {
                            name = "👥 عدد اللاعبين بالسيرفر",
                            value = string.format("%d / 12", playerCount),
                            inline = true,
                        },
                        {
                            name = "🆔 Server JobId",
                            value = string.format("```%s```", tostring(game.JobId)),
                            inline = false,
                        },
                        {
                            name = "⚡ كود الدخول المباشر (انسخه ونفذه بحسابك الأساسي):",
                            value = string.format("```lua\n%s\n```", joinScript),
                            inline = false,
                        },
                    },
                    footer = {
                        text = "Delta Blox Fruits Finder • Redz Style",
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }
            }
        }

        task.spawn(function()
            sendWebhook(Config.WebhookURL, payload, Utils)
        end)
    end
end

-- Notify Boss Found
function Notifier.NotifyBoss(boss, Config, Constants, Utils)
    local placeId = game.PlaceId
    local seaName = Constants.SeaNames[placeId] or ("Sea " .. tostring(Utils.GetCurrentSea()))
    local joinScript = Utils.GetJoinScript(placeId, game.JobId)
    local playerCount = #Players:GetPlayers()
    local color = (boss.Type == "Elite") and Constants.SpecialColors.Elite or Constants.SpecialColors.Boss

    -- In-game notification
    if Config.NotifyInGame then
        Utils.Notify("👑 رصد بوس: " .. boss.Name, "النوع: " .. boss.Type .. " | صحته: " .. tostring(boss.HealthPercent) .. "%", 6)
    end
    if Config.SoundAlert then
        Utils.PlayAlertSound()
    end

    -- Discord Webhook notification
    if Config.WebhookEnabled and Config.WebhookURL and Config.WebhookURL ~= "" then
        local payload = {
            username = "Delta Boss Finder",
            content = "⚔️ **تم رصد بوس نشط في السيرفر!**",
            embeds = {
                {
                    title = string.format("👑 البوس: %s (%s)", boss.Name, boss.Arabic or boss.Name),
                    description = string.format("**النوع:** `%s`\n**الصحة:** %d / %d (%d%%)\n**المسافة:** %d متر",
                        boss.Type, boss.Health, boss.MaxHealth, boss.HealthPercent, boss.Distance or 0),
                    color = color,
                    fields = {
                        {
                            name = "🌊 البحر (Sea)",
                            value = seaName,
                            inline = true,
                        },
                        {
                            name = "👥 عدد اللاعبين بالسيرفر",
                            value = string.format("%d / 12", playerCount),
                            inline = true,
                        },
                        {
                            name = "🆔 Server JobId",
                            value = string.format("```%s```", tostring(game.JobId)),
                            inline = false,
                        },
                        {
                            name = "⚡ كود الدخول للحساب الأساسي:",
                            value = string.format("```lua\n%s\n```", joinScript),
                            inline = false,
                        },
                    },
                    footer = {
                        text = "Delta Blox Fruits Finder • Boss Tracker",
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }
            }
        }

        task.spawn(function()
            sendWebhook(Config.WebhookURL, payload, Utils)
        end)
    end
end

-- Notify Mirage Island
function Notifier.NotifyMirage(mirageData, Config, Constants, Utils)
    local placeId = game.PlaceId
    local seaName = Constants.SeaNames[placeId] or "Sea 3"
    local joinScript = Utils.GetJoinScript(placeId, game.JobId)

    if Config.NotifyInGame then
        Utils.Notify("🏝️ جزيرة الميراج!", "تم العثور على جزيرة الميراج بالسيرفر الحالي!", 10)
    end
    if Config.SoundAlert then
        Utils.PlayAlertSound()
    end

    if Config.WebhookEnabled and Config.WebhookURL and Config.WebhookURL ~= "" then
        local payload = {
            username = "Delta Event Finder",
            content = "@everyone 🏝️ **حدث نادر: ظهرت جزيرة الميراج (Mirage Island)!**",
            embeds = {
                {
                    title = "🏝️ جزيرة الميراج (Mirage Island) نشطة الآن!",
                    description = "الجزيرة موجودة حالياً في الخريطة، استعد لتفعيل Race V4 أو التروس (Gears) فوراً!",
                    color = Constants.SpecialColors.Mirage,
                    fields = {
                        {
                            name = "🌊 البحر",
                            value = seaName,
                            inline = true,
                        },
                        {
                            name = "🆔 Job ID",
                            value = string.format("```%s```", tostring(game.JobId)),
                            inline = false,
                        },
                        {
                            name = "⚡ كود الدخول للحساب الأساسي:",
                            value = string.format("```lua\n%s\n```", joinScript),
                            inline = false,
                        },
                    },
                    footer = {
                        text = "Delta Blox Fruits Finder • Mirage Detector",
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }
            }
        }

        task.spawn(function()
            sendWebhook(Config.WebhookURL, payload, Utils)
        end)
    end
end

-- Notify Full Moon
function Notifier.NotifyFullMoon(moonData, Config, Constants, Utils)
    local placeId = game.PlaceId
    local seaName = Constants.SeaNames[placeId] or "Blox Fruits"
    local joinScript = Utils.GetJoinScript(placeId, game.JobId)

    if Config.NotifyInGame then
        Utils.Notify("🌕 قمر كامل (Full Moon)!", "القمر مكتمل 100% في السيرفر الحالي!", 10)
    end
    if Config.SoundAlert then
        Utils.PlayAlertSound()
    end

    if Config.WebhookEnabled and Config.WebhookURL and Config.WebhookURL ~= "" then
        local payload = {
            username = "Delta Event Finder",
            content = "🌕 **اكتمال القمر (Full Moon 100%) في السيرفر!**",
            embeds = {
                {
                    title = "🌕 اكتمال القمر (Full Moon Active)",
                    description = "السيرفر يمر بذروة اكتمال القمر حالياً (جاهز لتجارب Race V4 وسحب المقبض)!",
                    color = Constants.SpecialColors.FullMoon,
                    fields = {
                        {
                            name = "🌊 البحر",
                            value = seaName,
                            inline = true,
                        },
                        {
                            name = "🆔 Job ID",
                            value = string.format("```%s```", tostring(game.JobId)),
                            inline = false,
                        },
                        {
                            name = "⚡ كود الدخول المباشر:",
                            value = string.format("```lua\n%s\n```", joinScript),
                            inline = false,
                        },
                    },
                    footer = {
                        text = "Delta Blox Fruits Finder • Full Moon Detector",
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }
            }
        }

        task.spawn(function()
            sendWebhook(Config.WebhookURL, payload, Utils)
        end)
    end
end

-- Notify Legendary Sword Dealer
function Notifier.NotifySwordDealer(dealerData, Config, Constants, Utils)
    local placeId = game.PlaceId
    local joinScript = Utils.GetJoinScript(placeId, game.JobId)

    if Config.NotifyInGame then
        Utils.Notify("⚔️ بائع السيوف الأسطوري!", "Legendary Sword Dealer متواجد في البحر الثاني!", 8)
    end
    if Config.SoundAlert then
        Utils.PlayAlertSound()
    end

    if Config.WebhookEnabled and Config.WebhookURL and Config.WebhookURL ~= "" then
        local payload = {
            username = "Delta Event Finder",
            content = "⚔️ **بائع السيوف الأسطوري (Legendary Sword Dealer) متواجد في السيرفر!**",
            embeds = {
                {
                    title = "⚔️ Legendary Sword Dealer رُصد في Sea 2",
                    description = "البائع موجود لبيع أحد السيوف الأسطورية (Shisui, Wando, Saddi)!",
                    color = Constants.SpecialColors.SwordDealer,
                    fields = {
                        {
                            name = "🆔 Job ID",
                            value = string.format("```%s```", tostring(game.JobId)),
                            inline = false,
                        },
                        {
                            name = "⚡ كود الدخول للحساب الأساسي:",
                            value = string.format("```lua\n%s\n```", joinScript),
                            inline = false,
                        },
                    },
                    footer = {
                        text = "Delta Blox Fruits Finder • Sword Dealer",
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }
            }
        }

        task.spawn(function()
            sendWebhook(Config.WebhookURL, payload, Utils)
        end)
    end
end

return Notifier
