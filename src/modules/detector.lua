--[[
    Blox Fruits Detector Module
    Scans for Fruits, Bosses (Elite, Raid, Regular), Mirage Island, Full Moon, and NPCs.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local Detector = {}

-- Helper to extract clean fruit base name
local function cleanFruitName(rawName)
    if not rawName then return "" end
    local name = tostring(rawName)
    name = name:gsub(" Fruit", "")
    name = name:gsub("Fruit", "")
    name = name:gsub("%s+", "")
    return name
end

-- Match raw string with known fruits dictionary
local function findFruitData(rawName, Constants)
    local cleaned = cleanFruitName(rawName):lower()
    for fruitName, data in pairs(Constants.Fruits) do
        local key = fruitName:lower()
        if cleaned == key or string.find(cleaned, key) or string.find(key, cleaned) then
            return fruitName, data
        end
    end
    return nil, nil
end

-- 1. Scan for Spawned Fruits on the map
function Detector.ScanFruits(Config, Constants)
    local foundFruits = {}
    local player = Players.LocalPlayer
    local char = player and player.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
    local myPos = root and root.Position or Vector3.new(0, 0, 0)

    -- Scan workspace root children
    for _, obj in ipairs(Workspace:GetChildren()) do
        pcall(function()
            -- Blox fruits spawned on ground are typically Models or Tools with Handle
            if (obj:IsA("Tool") or obj:IsA("Model")) and obj.Name ~= "Character" then
                local rawName = obj.Name
                local fruitBase, fruitData = findFruitData(rawName, Constants)

                -- Also inspect child handles or meshparts if rawName is just "Fruit" or "Handle"
                if not fruitData and (rawName:lower():find("fruit") or obj:FindFirstChild("Handle")) then
                    for _, child in ipairs(obj:GetChildren()) do
                        fruitBase, fruitData = findFruitData(child.Name, Constants)
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
                    else -- "RareOnly" (Legendary and Mythical)
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

-- 2. Scan for Active Bosses
function Detector.ScanBosses(Config, Constants)
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

            -- Check Elite Bosses
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

            -- Check Special / Raid Bosses
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

    -- Look in workspace.Enemies
    local enemiesFolder = Workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do
            inspectEnemy(enemy)
        end
    end

    -- Look in workspace.NPCs
    local npcsFolder = Workspace:FindFirstChild("NPCs")
    if npcsFolder then
        for _, npc in ipairs(npcsFolder:GetChildren()) do
            inspectEnemy(npc)
        end
    end

    -- Look in workspace root
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model ~= char and not (enemiesFolder and model.Parent == enemiesFolder) then
            if Constants.EliteBosses[model.Name] or Constants.SpecialBosses[model.Name] then
                inspectEnemy(model)
            end
        end
    end

    return foundBosses
end

-- 3. Scan for Mirage Island & Kitsune Island
function Detector.ScanMirageIsland()
    local result = {
        Found = false,
        Name = nil,
        Type = nil,
    }

    pcall(function()
        -- Blox Fruits locations folder
        local locations = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
        
        local function checkName(name)
            local lower = name:lower()
            if lower:find("mirage") then
                return "Mirage Island", "Mirage"
            elseif lower:find("kitsune island") or lower:find("kitsuneisland") then
                return "Kitsune Island", "Kitsune"
            end
            return nil, nil
        end

        if locations then
            for _, loc in ipairs(locations:GetChildren()) do
                local friendly, typ = checkName(loc.Name)
                if friendly then
                    result.Found = true
                    result.Name = friendly
                    result.Type = typ
                    return
                end
            end
        end

        -- Check Workspace and Workspace.Map
        for _, child in ipairs(Workspace:GetChildren()) do
            local friendly, typ = checkName(child.Name)
            if friendly then
                result.Found = true
                result.Name = friendly
                result.Type = typ
                return
            end
        end

        local map = Workspace:FindFirstChild("Map")
        if map then
            for _, child in ipairs(map:GetChildren()) do
                local friendly, typ = checkName(child.Name)
                if friendly then
                    result.Found = true
                    result.Name = friendly
                    result.Type = typ
                    return
                end
            end
        end
    end)

    return result
end

-- 4. Scan for Full Moon
function Detector.ScanFullMoon(Constants)
    local result = {
        IsFullMoon = false,
        MoonPercent = 0,
        ClockTime = Lighting.ClockTime,
        Description = "No Full Moon",
    }

    pcall(function()
        -- Skybox moon texture check
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

        -- Check for FullMoon attribute or child in Lighting or Workspace
        local fullMoonTag = Lighting:FindFirstChild("FullMoon") or Lighting:GetAttribute("FullMoon")
        if fullMoonTag == true or (typeof(fullMoonTag) == "Instance") then
            result.IsFullMoon = true
            result.MoonPercent = 100
            result.Description = "Full Moon Active"
            return
        end

        -- Blox Fruits moon phase calculation check if available
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

-- 5. Scan for Legendary Sword Dealer (Sea 2)
function Detector.ScanLegendarySwordDealer()
    local result = {
        Found = false,
        Location = nil,
    }

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

-- Comprehensive Scan aggregator
function Detector.ScanAll(Config, Constants)
    local scanData = {
        Fruits = Detector.ScanFruits(Config, Constants),
        Bosses = Detector.ScanBosses(Config, Constants),
        Mirage = Config.DetectMirageIsland and Detector.ScanMirageIsland() or { Found = false },
        FullMoon = Config.DetectFullMoon and Detector.ScanFullMoon(Constants) or { IsFullMoon = false },
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

return Detector
