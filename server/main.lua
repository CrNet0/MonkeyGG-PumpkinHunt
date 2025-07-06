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
    debugPrint("[PumpkinHunt] Pumpkin locations updated.")
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
    debugPrint("[PumpkinHunt] Rare Pumpkin Event Started!")
end

local function endRarePumpkinEvent()
    rarePumpkinEventActive = false
    rarePumpkinLocations = {}
    vCLIENT.endRarePumpkinEvent()
    debugPrint("[PumpkinHunt] Rare Pumpkin Event Ended!")
end

CreateThread(function()
    updatePumpkinLocations()
    local updateInterval = 1800000
    while true do
        Wait(updateInterval)
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
    if not Functions or not Functions["Framework"] or not Functions["Functions"] then
        debugPrint("[PumpkinHunt] Erro: Configuração de Functions ausente.")
        return
    end
    if not selectedFunctions then
        debugPrint("[PumpkinHunt] Erro: selectedFunctions não definido.")
        return
    end
    if not Pumpkin then
        debugPrint("[PumpkinHunt] Erro: Pumpkin config não carregada.")
        return
    end

    local source = source
    local Passport = selectedFunctions[1](source)
    if not Passport then
        sendNotification(source, "vermelho", "Erro ao obter passaporte.", "Pumpkin Hunt")
        return
    end

    local currentTime = os.time()
    local playerPed = GetPlayerPed(source)
    if not playerPed or not DoesEntityExist(playerPed) then
        sendNotification(source, "vermelho", "Jogador não encontrado.", "Pumpkin Hunt")
        return
    end
    local playerCoords = GetEntityCoords(playerPed)
    local locations = rarePumpkinEventActive and rarePumpkinLocations or currentPumpkinLocations
    if not locations or #locations == 0 then
        sendNotification(source, "vermelho", "Nenhuma abóbora disponível.", "Pumpkin Hunt")
        return
    end

    local newCooldowns = {}
    for _, cooldown in ipairs(pumpkinCooldowns) do
        if currentTime - cooldown.timeCollected < COOLDOWN_TIME then
            table.insert(newCooldowns, cooldown)
        end
    end
    pumpkinCooldowns = newCooldowns

    for i, Coords in ipairs(locations) do
        local pumpkinId = string.format("%.2f,%.2f,%.2f,%s", Coords.x, Coords.y, Coords.z, tostring(Passport))
        local distance = #(playerCoords - vec3(Coords.x, Coords.y, Coords.z))
        debugPrint("[PumpkinHunt] Checking distance to pumpkin " .. i .. ": " .. distance)

        if distance <= 2.0 then
            debugPrint("[PumpkinHunt] Distance is within range for pumpkin " .. i)
            for _, cooldown in ipairs(pumpkinCooldowns) do
                if cooldown.playerSource == source and cooldown.pumpkinId == pumpkinId then
                    local timePassed = currentTime - cooldown.timeCollected
                    if timePassed < COOLDOWN_TIME then
                        local remainingTime = COOLDOWN_TIME - timePassed
                        sendNotification(source, "vermelho", "Você já coletou essa abóbora, volte em " .. remainingTime .. " segundos.", "Pumpkin Hunt")
                        debugPrint("[PumpkinHunt] Cooldown active for pumpkin " .. i .. ", remaining time: " .. remainingTime)
                        return
                    end
                end
            end

            local totalItemsToCollect = math.random(1, 3)
            local collectedItems = {}

            for j = 1, totalItemsToCollect do
                local prize = getRandomPrize()
                local Valuation = math.random(1, 3)
                debugPrint("[PumpkinHunt] Generated prize: " .. prize .. ", valuation: " .. Valuation)

                if (selectedFunctions[2](Passport) + (_G.ItemWeight and _G.ItemWeight(prize) or 0) * Valuation) <= selectedFunctions[3](Passport) then
                    
                    TriggerClientEvent("Pumpkin:PlayCollectAnim", source)
                    selectedFunctions[4](Passport, prize, Valuation, true)
                    table.insert(collectedItems, prize)
                    debugPrint("[PumpkinHunt] Prize " .. prize .. " added to inventory.")
                else
                    sendNotification(source, "amarelo", "Sua recompensa caiu no chão.", "Mochila Sobrecarregada")
                    if exports and exports["inventory"] and exports["inventory"].Drops then
                        exports["inventory"]:Drops(Passport, source, prize, Valuation)
                    end
                    debugPrint("[PumpkinHunt] Inventory full, prize " .. prize .. " dropped on the ground.")
                end
            end

            table.insert(pumpkinCooldowns, { playerSource = source, pumpkinId = pumpkinId, timeCollected = currentTime })
            debugPrint("[PumpkinHunt] Cooldown added for pumpkin " .. i)

            if #collectedItems > 0 then
                sendNotification(source, "azul", "Você coletou: " .. table.concat(collectedItems, ", ") .. " na Pumpkin Hunt.", "Pumpkin Hunt")
                debugPrint("[PumpkinHunt] Collected items: " .. table.concat(collectedItems, ", "))
            end

            return
        end
    end

    sendNotification(source, "vermelho", "Você precisa estar mais perto de uma abóbora.", "Pumpkin Hunt")
    debugPrint("[PumpkinHunt] Player is not close enough to any pumpkin.")
end)
