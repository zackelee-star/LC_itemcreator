if _lcItemCreatorBridge then return end
_lcItemCreatorBridge = true

local allowedResource = 'LC_itemcreator'
local host = GetCurrentResourceName()
local itemsFile = 'data/items.lua'
local backupFile = 'data/items.lc_itemcreator.bak'
local beginMarker = '-- LC_ITEMCREATOR_ITEMS_BEGIN'
local endMarker = '-- LC_ITEMCREATOR_ITEMS_END'
local ItemList = require 'modules.items.shared'
local managedNames = {}
local currentDefinitions = {}
local currentRemovedItems = {}
local syncRequestTimes = {}
local syncRequestCooldown = 2000

local function quote(value)
    return string.format('%q', tostring(value or ''))
end

local function normalize(raw)
    if type(raw) ~= 'table' then return end

    local name = type(raw.name) == 'string' and raw.name:lower() or ''
    if #name < 1 or #name > 64 or not name:match('^[a-z0-9_]+$') then return end

    local label = type(raw.label) == 'string' and raw.label:sub(1, 80) or name
    local description = type(raw.description) == 'string' and raw.description:sub(1, 500) or ''
    local image = type(raw.image) == 'string' and raw.image:sub(1, 300) or ''
    local weight = math.max(0, math.floor(tonumber(raw.weight) or 0))
    local degrade = tonumber(raw.degrade)

    return {
        name = name,
        label = label,
        description = description,
        image = image,
        weight = weight,
        stack = raw.stack ~= false,
        close = raw.close ~= false,
        degrade = degrade and degrade > 0 and math.floor(degrade) or nil,
        decay = degrade and degrade > 0 and raw.decay == true or nil,
    }
end

local function serialize(definition)
    local lines = {
        ('    [%s] = {'):format(quote(definition.name)),
        ('        label = %s,'):format(quote(definition.label)),
        ('        weight = %s,'):format(definition.weight),
        ('        stack = %s,'):format(tostring(definition.stack)),
        ('        close = %s,'):format(tostring(definition.close)),
    }

    if definition.description ~= '' then
        lines[#lines + 1] = ('        description = %s,'):format(quote(definition.description))
    end
    if definition.degrade then
        lines[#lines + 1] = ('        degrade = %s,'):format(definition.degrade)
        lines[#lines + 1] = ('        decay = %s,'):format(tostring(definition.decay == true))
    end
    if definition.image ~= '' then
        lines[#lines + 1] = '        client = {'
        lines[#lines + 1] = ('            image = %s,'):format(quote(definition.image))
        lines[#lines + 1] = '        },'
    end

    lines[#lines + 1] = '    },'
    return table.concat(lines, '\n')
end

local function buildRegion(definitions)
    local lines = { '    ' .. beginMarker }
    for index = 1, #definitions do lines[#lines + 1] = serialize(definitions[index]) end
    lines[#lines + 1] = '    ' .. endMarker
    return table.concat(lines, '\n')
end

local function stripRegion(content)
    local first = content:find(beginMarker, 1, true)
    if not first then return content end

    local last = content:find(endMarker, first, true)
    if not last then return nil, 'managed_region_is_incomplete' end

    local start = first
    while start > 1 and content:sub(start - 1, start - 1):match('[ \t]') do start = start - 1 end
    if start > 1 and content:sub(start - 1, start - 1) == '\n' then start = start - 1 end

    local finish = last + #endMarker
    if content:sub(finish + 1, finish + 1) == '\r' then finish = finish + 1 end
    if content:sub(finish + 1, finish + 1) == '\n' then finish = finish + 1 end

    return content:sub(1, start - 1) .. content:sub(finish + 1)
end

local function writeItems(definitions)
    local original = LoadResourceFile(host, itemsFile)
    if not original or original == '' then return false, 'items_lua_unreadable' end

    local stripped, stripError = stripRegion(original)
    if not stripped then return false, stripError end

    local closeStart = stripped:find('}%s*$')
    if not closeStart then return false, 'items_table_end_not_found' end

    local prefix = stripped:sub(1, closeStart - 1):gsub('%s+$', '')
    local final = prefix .. '\n\n' .. buildRegion(definitions) .. '\n' .. stripped:sub(closeStart)
    local compiled, compileError = load(final, '@@ox_inventory/data/items.lua', 't', {})
    if not compiled then return false, ('generated_items_invalid: %s'):format(compileError) end

    if final == original then return true end

    SaveResourceFile(host, backupFile, original, #original)
    SaveResourceFile(host, itemsFile, final, #final)

    local written = LoadResourceFile(host, itemsFile)
    if written ~= final then
        SaveResourceFile(host, itemsFile, original, #original)
        return false, 'items_lua_write_verification_failed'
    end

    return true
end

local function registerLive(definitions)
    local nextNames = {}
    local removedItems = {}

    for index = 1, #definitions do
        local definition = definitions[index]
        nextNames[definition.name] = definition
        ItemList[definition.name] = {
            name = definition.name,
            label = definition.label,
            description = definition.description,
            weight = definition.weight,
            stack = definition.stack,
            close = definition.close,
            degrade = definition.degrade,
            decay = definition.decay,
            durability = definition.degrade and true or nil,
            client = definition.image ~= '' and {
                image = definition.image,
            } or nil,
        }
    end

    for name, previous in pairs(managedNames) do
        if not nextNames[name] then
            -- 所持中のスロットは次回ロードまで残るため、現在のランタイムだけ
            -- 非使用の定義を保持します。nilにすると移動時の重量計算で
            -- ox_inventoryが存在しないitemを参照してエラーになります。
            local removed = {
                name = name,
                label = ('%s（削除済み）'):format(previous.label or name),
                description = 'このアイテムは削除済みのため使用できません。サーバー再起動後に所持品から除外されます。',
                image = previous.image,
                weight = tonumber(previous.weight) or 0,
                stack = previous.stack ~= false,
                close = true,
                removed = true,
            }

            ItemList[name] = {
                name = removed.name,
                label = removed.label,
                description = removed.description,
                weight = removed.weight,
                stack = removed.stack,
                close = removed.close,
                client = type(removed.image) == 'string' and removed.image ~= '' and {
                    image = removed.image,
                } or nil,
            }
            removedItems[#removedItems + 1] = removed
        end
    end

    managedNames = nextNames
    currentDefinitions = definitions
    currentRemovedItems = removedItems
    TriggerClientEvent('LC_itemcreator:ox:refreshItems', -1, definitions, removedItems)
end

RegisterNetEvent('LC_itemcreator:ox:requestItems', function()
    local playerSource = tonumber(source)
    if not playerSource or playerSource <= 0 or not GetPlayerName(playerSource) then return end

    local now = GetGameTimer()
    local lastRequest = syncRequestTimes[playerSource]
    local elapsed = lastRequest and (now - lastRequest)

    if elapsed and elapsed >= 0 and elapsed < syncRequestCooldown then return end
    syncRequestTimes[playerSource] = now

    TriggerClientEvent(
        'LC_itemcreator:ox:refreshItems',
        playerSource,
        currentDefinitions,
        currentRemovedItems
    )
end)

AddEventHandler('playerDropped', function()
    syncRequestTimes[source] = nil
end)

exports('lcItemCreatorApply', function(rawDefinitions)
    if GetInvokingResource() ~= allowedResource then return false, 'unauthorized_resource' end
    if type(rawDefinitions) ~= 'table' then return false, 'invalid_definitions' end

    local definitions = {}
    local names = {}

    for index = 1, #rawDefinitions do
        local definition = normalize(rawDefinitions[index])
        if not definition then return false, ('invalid_definition_at_%s'):format(index) end
        if names[definition.name] then return false, ('duplicate_definition_%s'):format(definition.name) end

        names[definition.name] = true
        definitions[#definitions + 1] = definition
    end

    table.sort(definitions, function(a, b) return a.name < b.name end)

    local written, writeError = writeItems(definitions)
    if not written then return false, writeError end

    registerLive(definitions)
    return true, ('published_%s_items'):format(#definitions)
end)

exports('lcItemCreatorStatus', function()
    local count = 0
    for _ in pairs(managedNames) do count = count + 1 end

    return {
        ready = true,
        message = 'リアルタイム反映ブリッジは正常です。',
        managedItems = count,
    }
end)
