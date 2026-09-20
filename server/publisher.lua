LCItemPublisher = {}

local function isEnabledValue(value)
    return value == true or value == 1 or value == '1'
end

local function decodeRow(row)
    local success, definition = pcall(json.decode, row.data)
    if not success or type(definition) ~= 'table' then
        return nil, ('invalid_json_for_%s'):format(row.name)
    end

    definition.name = row.name
    definition.label = row.label
    definition.ownerJob = row.owner_job
    definition.enabled = isEnabledValue(row.enabled)
    definition.revision = tonumber(row.revision) or 1
    definition.createdAt = row.created_at
    definition.updatedAt = row.updated_at
    return definition
end

function LCItemPublisher.DecodeRows(rows)
    local definitions = {}

    for index = 1, #rows do
        local definition, errorCode = decodeRow(rows[index])
        if not definition then return nil, errorCode end
        definitions[#definitions + 1] = definition
    end

    return definitions
end

local function buildInventoryDefinition(definition)
    return {
        name = definition.name,
        label = definition.label,
        weight = definition.weight,
        stack = definition.stack,
        close = definition.close,
        description = definition.description,
        image = definition.image,
        degrade = definition.degradeMinutes > 0 and definition.degradeMinutes or nil,
        decay = definition.degradeMinutes > 0 and definition.decay == true or nil,
    }
end

local function buildConsumableDefinition(definition)
    if definition.enabled == false or definition.type ~= 'usable' or type(definition.consumable) ~= 'table' then
        return
    end

    local consumable = definition.consumable
    return {
        name = definition.name,
        label = definition.label,
        category = consumable.category,
        presentation = consumable.presentation,
        prop = consumable.prop,
        effects = consumable.effects,
        effectPreset = consumable.effectPreset,
        effectDuration = consumable.effectDuration,
        alcoholLevel = consumable.alcoholLevel,
        canOverdose = consumable.canOverdose,
        enabled = true,
    }
end

function LCItemPublisher.Publish(definitions)
    if GetResourceState('ox_inventory') ~= 'started' then return false, 'ox_inventory_not_started' end
    if GetResourceState('LC_consumables') ~= 'started' then return false, 'LC_consumables_not_started' end

    local inventoryDefinitions = {}
    local consumableDefinitions = {}

    for index = 1, #definitions do
        inventoryDefinitions[#inventoryDefinitions + 1] = buildInventoryDefinition(definitions[index])

        local consumable = buildConsumableDefinition(definitions[index])
        if consumable then consumableDefinitions[#consumableDefinitions + 1] = consumable end
    end

    local bridgeCalled, bridgeSuccess, bridgeMessage = pcall(function()
        return exports.ox_inventory:lcItemCreatorApply(inventoryDefinitions)
    end)

    if not bridgeCalled then return false, 'ox_inventory_bridge_missing' end
    if bridgeSuccess ~= true then return false, bridgeMessage or 'ox_inventory_publish_failed' end

    local consumablesCalled, consumablesSuccess, consumablesMessage = pcall(function()
        return exports.LC_consumables:SyncDefinitions(consumableDefinitions)
    end)

    if not consumablesCalled then return false, 'consumables_sync_unavailable' end
    if consumablesSuccess ~= true then return false, consumablesMessage or 'consumables_sync_failed' end

    return true, {
        items = #inventoryDefinitions,
        consumables = #consumableDefinitions,
    }
end
