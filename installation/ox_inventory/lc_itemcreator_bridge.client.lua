if _lcItemCreatorBridgeClient then return end
_lcItemCreatorBridgeClient = true

local ItemList = require 'modules.items.shared'
local deletedItemEvent = 'LC_itemcreator:ox:deletedItem'
local syncRequestPending = false

local function requestCurrentDefinitions()
    if syncRequestPending then return end
    syncRequestPending = true

    SetTimeout(250, function()
        syncRequestPending = false
        TriggerServerEvent('LC_itemcreator:ox:requestItems')
    end)
end

local function imagePath(image)
    if type(image) ~= 'string' or image == '' then return end
    if image:match('^[%w]+://') then return image end
    return ('%s/%s'):format(client.imagepath, image)
end

RegisterNetEvent(deletedItemEvent, function()
    lib.notify({
        title = 'LC Item Creator',
        description = 'このアイテムは削除済みのため使用できません。',
        type = 'error',
    })
end)

local function refreshNui(definitions)
    if not client.uiLoaded or type(PlayerData) ~= 'table' or type(PlayerData.inventory) ~= 'table' then return end

    local itemData = {}
    for index = 1, #definitions do
        local definition = definitions[index]
        local count = 0

        for _, slot in pairs(PlayerData.inventory) do
            if slot.name == definition.name then count = count + (slot.count or 0) end
        end

        itemData[definition.name] = {
            label = definition.label,
            stack = definition.stack,
            close = definition.close,
            count = count,
            description = definition.description,
            image = imagePath(definition.image),
        }
    end

    SendNUIMessage({
        action = 'init',
        data = {
            locale = {},
            items = itemData,
            money = {},
            leftInventory = {
                id = cache.playerId,
                slots = shared.playerslots,
                items = PlayerData.inventory,
                maxWeight = shared.playerweight,
                money = PlayerData.money,
            },
            imagepath = client.imagepath,
            customize = client.customize,
            colors = client.colors,
            logo = client.logo,
        },
    })
end

RegisterNetEvent('LC_itemcreator:ox:refreshItems', function(definitions, removedItems)
    if type(definitions) ~= 'table' then return end

    local displayDefinitions = table.clone(definitions)

    if type(removedItems) == 'table' then
        for index = 1, #removedItems do
            local removed = removedItems[index]

            -- 旧ブリッジから文字列が届いた場合の後方互換です。
            if type(removed) == 'string' then
                ItemList[removed] = nil
            elseif type(removed) == 'table'
                and type(removed.name) == 'string'
                and removed.name:match('^[a-z0-9_]+$') then
                ItemList[removed.name] = {
                    name = removed.name,
                    label = removed.label or removed.name,
                    description = removed.description or '',
                    weight = tonumber(removed.weight) or 0,
                    stack = removed.stack ~= false,
                    close = true,
                    count = 0,
                    client = {
                        image = imagePath(removed.image),
                        event = deletedItemEvent,
                    },
                }
                displayDefinitions[#displayDefinitions + 1] = removed
            end
        end
    end

    for index = 1, #definitions do
        local definition = definitions[index]
        if type(definition) == 'table'
            and type(definition.name) == 'string'
            and definition.name:match('^[a-z0-9_]+$') then
            ItemList[definition.name] = {
                name = definition.name,
                label = definition.label or definition.name,
                description = definition.description or '',
                weight = tonumber(definition.weight) or 0,
                stack = definition.stack ~= false,
                close = definition.close ~= false,
                degrade = definition.degrade,
                decay = definition.decay,
                count = 0,
                client = definition.image ~= '' and { image = imagePath(definition.image) } or nil,
            }
        end
    end

    refreshNui(displayDefinitions)
end)

AddEventHandler('ox_inventory:setPlayerInventory', function()
    requestCurrentDefinitions()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    SetTimeout(1000, function()
        if type(PlayerData) == 'table' and PlayerData.loaded then
            requestCurrentDefinitions()
        end
    end)
end)
