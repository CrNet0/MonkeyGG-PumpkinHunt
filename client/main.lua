-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp", "lib/Tunnel")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------

Monkey = {}
Tunnel.bindInterface("pumpkin", Monkey)
vSERVER = Tunnel.getInterface("pumpkin")

local PumpkinSpawned = {}
local PumpkinTargeted = {}
local currentPumpkinLocations = {}
local rarePumpkinEventActive = false
local rarePumpkinLocations = {}

Citizen.CreateThread(function()
    local animDict = "anim@scripted@player@freemode@tun_prep_ig1_grab_low@heeled@"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        RequestAnimDict(animDict)
        Wait(50)
    end
end)

local function debugPrint(message)
    if Pumpkin["Debug"] then
        print(message)
    end
end

function updatePumpkinLocations(locations)
    currentPumpkinLocations = locations
    for k, _ in pairs(PumpkinSpawned) do
        if DoesEntityExist(PumpkinSpawned[k]) then
            DeleteEntity(PumpkinSpawned[k])
        end
        PumpkinSpawned[k] = nil
    end
    for k, _ in pairs(PumpkinTargeted) do
        exports["target"]:RemCircleZone("Pumpkin:Collect" .. k)
        PumpkinTargeted[k] = false
    end
    debugPrint("Client: Pumpkin locations updated.")
end

function startRarePumpkinEvent(locations)
    rarePumpkinEventActive = true
    rarePumpkinLocations = locations
    for k, _ in pairs(PumpkinSpawned) do
        if DoesEntityExist(PumpkinSpawned[k]) then
            DeleteEntity(PumpkinSpawned[k])
        end
        PumpkinSpawned[k] = nil
    end
    for k, _ in pairs(PumpkinTargeted) do
        exports["target"]:RemCircleZone("Pumpkin:Collect" .. k)
        PumpkinTargeted[k] = false
    end
    debugPrint("Client: Rare Pumpkin Event Started!")
end

function endRarePumpkinEvent()
    rarePumpkinEventActive = false
    rarePumpkinLocations = {}
    for k, _ in pairs(PumpkinSpawned) do
        if DoesEntityExist(PumpkinSpawned[k]) then
            DeleteEntity(PumpkinSpawned[k])
        end
        PumpkinSpawned[k] = nil
    end
    for k, _ in pairs(PumpkinTargeted) do
        exports["target"]:RemCircleZone("Pumpkin:Collect" .. k)
        PumpkinTargeted[k] = false
    end
    debugPrint("Client: Rare Pumpkin Event Ended!")
end

vSERVER.updatePumpkinLocations = updatePumpkinLocations
vSERVER.startRarePumpkinEvent = startRarePumpkinEvent
vSERVER.endRarePumpkinEvent = endRarePumpkinEvent

CreateThread(function()
    while true do
        local Ped = PlayerPedId()
        local Coords = GetEntityCoords(Ped)
        local locations = rarePumpkinEventActive and rarePumpkinLocations or currentPumpkinLocations

        for i, pumpkinCoords in ipairs(locations) do
            local Distance = #(Coords - vec3(pumpkinCoords.x, pumpkinCoords.y, pumpkinCoords.z))
            debugPrint("Client: Checking distance to pumpkin " .. i .. ": " .. Distance)

            if Distance <= 50.0 then
                if not PumpkinSpawned[i] then
                    local PumpkinModelIndex = (i - 1) % #Pumpkin["Pumpkins"] + 1
                    local PumpkinModel = Pumpkin["Pumpkins"][PumpkinModelIndex]
                    local hash = GetHashKey(PumpkinModel)

                    RequestModel(hash)
                    while not HasModelLoaded(hash) do
                        Wait(10)
                    end

                    local x, y, z, heading = pumpkinCoords.x, pumpkinCoords.y, pumpkinCoords.z, pumpkinCoords.w
                    PumpkinSpawned[i] = CreateObject(hash, x, y, z - 1, true, true, false)
                    SetEntityHeading(PumpkinSpawned[i], heading)
                    FreezeEntityPosition(PumpkinSpawned[i], true)
                    SetModelAsNoLongerNeeded(hash)
                    debugPrint("Client: Pumpkin " .. i .. " spawned.")
                end
            else
                if PumpkinSpawned[i] then
                    if DoesEntityExist(PumpkinSpawned[i]) then
                        DeleteEntity(PumpkinSpawned[i])
                        debugPrint("Client: Pumpkin " .. i .. " despawned.")
                    end
                    PumpkinSpawned[i] = nil
                end
            end
        end

        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        local Ped = PlayerPedId()
        local PlayerCoords = GetEntityCoords(Ped)
        local locations = rarePumpkinEventActive and rarePumpkinLocations or currentPumpkinLocations

        for i, Coords in ipairs(locations) do
            local Distance = #(PlayerCoords - vec3(Coords.x, Coords.y, Coords.z))
            debugPrint("Client: Checking distance to target zone for pumpkin " .. i .. ": " .. Distance)

            if Distance <= 50.0 then
                if not PumpkinTargeted[i] then
                    local x, y, z, heading = Coords.x, Coords.y, Coords.z, Coords.w
                    
                    exports["target"]:AddCircleZone("Pumpkin:Collect" .. i, vec3(x, y, z - 0.9), 0.5, {
                        name = "PumpkinNPC" .. i,
                        heading = heading
                    }, {
                        Distance = 1.75,
                        options = {
                            {
                                event = "Pumpkin:Collect",
                                label = "Coletar Travessuras",
                                tunnel = "proserver"
                            }
                        }
                    })
                    debugPrint("Client: Target zone added for pumpkin " .. i)

                    PumpkinTargeted[i] = true
                end
            else
                if PumpkinTargeted[i] then
                    exports["target"]:RemCircleZone("Pumpkin:Collect" .. i)
                    PumpkinTargeted[i] = false
                    debugPrint("Client: Target zone removed for pumpkin " .. i)
                end
            end
        end

        Wait(1000)
    end
end)
