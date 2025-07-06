-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRPC = Tunnel.getInterface("vRP")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Monkey = {}
Tunnel.bindInterface("pumpkin", Monkey)
vCLIENT = Tunnel.getInterface("pumpkin")

local pumpkinCooldowns = {}
local currentPumpkinLocations = {}
local rarePumpkinEventActive = false
local rarePumpkinEventEndTime = 0
local rarePumpkinLocations = {}

local selectedFunctions = Functions["Functions"][Functions["Framework"]]

local prizeRarities = {
    common = 70,
    uncommon = 20,
    rare = 8,
    legendary = 2
}

local COOLDOWN_TIME = 100

local function debugPrint(message)
    if Pumpkin["Debug"] then
        print(message)
    end
end

local function getRandomPrize()
    local totalWeight = 0
    for _, prize in ipairs(Pumpkin["Prizes"]) do
        totalWeight = totalWeight + prizeRarities[prize.rarity]
    end

    local randomNumber = math.random(1, totalWeight)
    local currentWeight = 0

    for _, prize in ipairs(Pumpkin["Prizes"]) do
        currentWeight = currentWeight + prizeRarities[prize.rarity]
        if randomNumber <= currentWeight then
            return prize.name
        end
    end
end

local function playCollectAnimation(source)
    local animDict = "anim@scripted@player@freemode@tun_prep_ig1_grab_low@heeled@"
    local animName = "grab_low"

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        RequestAnimDict(animDict)
        Wait(50)
    end

    TaskPlayAnim(source, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)
    Wait(500)
end

local function sendNotification(source, type, message, title)
    TriggerClientEvent("Notify", source, type, message, title, 5000)
end

local function updatePumpkinLocations()
    currentPumpkinLocations = {}
    local locations = {}
    for _, loc in ipairs(Pumpkin["SpawnLocations"]) do
        table.insert(locations, loc)
    end
    local maxPumpkins = Pumpkin["MaxPumpkins"]
    for i = 1, maxPumpkins do
        if #locations > 0 then
            local randomIndex = math.random(1, #locations)
            table.insert(currentPumpkinLocations, locations[randomIndex])
            table.remove(locations, randomIndex)
        end
    end
    vCLIENT.updatePumpkinLocations(currentPumpkinLocations)
    debugPrint("Pumpkin locations updated.")
end

local function startRarePumpkinEvent()
    rarePumpkinEventActive = true
    rarePumpkinEventEndTime = os.time() + 600
    rarePumpkinLocations = {}
    local locations = {}
    for _, loc in ipairs(Pumpkin["SpawnLocations"]) do
        table.insert(locations, loc)
    end
    local maxRarePumpkins = Pumpkin["MaxRarePumpkins"]
    for i = 1, maxRarePumpkins do
        if #locations > 0 then
            local randomIndex = math.random(1, #locations)
            table.insert(rarePumpkinLocations, locations[randomIndex])
            table.remove(locations, randomIndex)
        end
    end
    vCLIENT.startRarePumpkinEvent(rarePumpkinLocations)
    debugPrint("Rare Pumpkin Event Started!")
end

local function endRarePumpkinEvent()
    rarePumpkinEventActive = false
    rarePumpkinLocations = {}
    vCLIENT.endRarePumpkinEvent()
    debugPrint("Rare Pumpkin Event Ended!")
end

CreateThread(function()
    updatePumpkinLocations()
    while true do
        Wait(3600000)
        updatePumpkinLocations()
    end
end)

CreateThread(function()
    while true do
        Wait(600000)
        if not rarePumpkinEventActive then
            startRarePumpkinEvent()
        end
        if rarePumpkinEventActive and os.time() >= rarePumpkinEventEndTime then
            endRarePumpkinEvent()
        end
    end
end)

RegisterNetEvent("Pumpkin:Collect")
AddEventHandler("Pumpkin:Collect", function()
    local source = source
    local Passport = selectedFunctions[1](source)

    local currentTime = os.time()
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local locations = rarePumpkinEventActive and rarePumpkinLocations or currentPumpkinLocations

    for i, Coords in ipairs(locations) do
        local pumpkinId = string.format("%.2f,%.2f,%.2f,%s", Coords.x, Coords.y, Coords.z, tostring(Passport))
        local distance = #(playerCoords - vec3(Coords.x, Coords.y, Coords.z))
        debugPrint("Checking distance to pumpkin " .. i .. ": " .. distance)

        if distance <= 2.0 then
            debugPrint("Distance is within range for pumpkin " .. i)
            for _, cooldown in ipairs(pumpkinCooldowns) do
                if cooldown.playerSource == source and cooldown.pumpkinId == pumpkinId then
                    local timePassed = currentTime - cooldown.timeCollected
                    if timePassed < COOLDOWN_TIME then
                        local remainingTime = COOLDOWN_TIME - timePassed
                        sendNotification(source, "vermelho", "Você já coletou essa abóbora, volte em " .. remainingTime .. " segundos.", "Pumpkin Hunt")
                        debugPrint("Cooldown active for pumpkin " .. i .. ", remaining time: " .. remainingTime)
                        return
                    end
                end
            end

            if Passport then
                debugPrint("Passport found for player " .. source)
                local totalItemsToCollect = math.random(1, 3)
                local collectedItems = {}

                for i = 1, totalItemsToCollect do
                    local prize = getRandomPrize()
                    local Valuation = math.random(1, 3)
                    debugPrint("Generated prize: " .. prize .. ", valuation: " .. Valuation)

                    if (selectedFunctions[2](Passport) + ItemWeight(prize) * Valuation) <= selectedFunctions[3](Passport) then
                        playCollectAnimation(source)
                        selectedFunctions[4](Passport, prize, Valuation, true)
                        table.insert(collectedItems, prize)
                        debugPrint("Prize " .. prize .. " added to inventory.")
                    else
                        sendNotification(source, "amarelo", "Sua recompensa caiu no chão.", "Mochila Sobrecarregada")
                        exports["inventory"]:Drops(Passport, source, prize, Valuation)
                        debugPrint("Inventory full, prize " .. prize .. " dropped on the ground.")
                    end
                end

                table.insert(pumpkinCooldowns, { playerSource = source, pumpkinId = pumpkinId, timeCollected = currentTime })
                debugPrint("Cooldown added for pumpkin " .. i)

                if #collectedItems > 0 then
                    sendNotification(source, "azul", "Você coletou: " .. table.concat(collectedItems, ", ") .. " na Pumpkin Hunt.", "Pumpkin Hunt")
                    debugPrint("Collected items: " .. table.concat(collectedItems, ", "))
                end

                return
            end
        end
    end

    sendNotification(source, "vermelho", "Você precisa estar mais perto de uma abóbora.", "Pumpkin Hunt")
    debugPrint("Player is not close enough to any pumpkin.")
end)
