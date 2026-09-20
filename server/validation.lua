LCItemValidation = {}

local statusNames = { 'hunger', 'thirst', 'stress' }

function LCItemValidation.GetStatusEditing()
    local configured = ServerConfig.statusEditing
    if configured == nil then return { mode = 'all', categories = {} } end
    if type(configured) ~= 'table' then return { mode = 'category', categories = {} } end
    local result = { mode = configured.mode == 'all' and 'all' or 'category', categories = {} }
    for category, rules in pairs(type(configured.categories) == 'table' and configured.categories or {}) do
        local allowed = {}
        for _, status in ipairs(statusNames) do
            allowed[status] = type(rules) == 'table' and rules[status] == true
        end
        result.categories[category] = allowed
    end
    return result
end

function LCItemValidation.IsMaterialAllowed(name, category)
    local configured = ServerConfig.materials[name]
    local categories
    if type(configured) == 'table' then categories = configured.categories end
    return categories == nil or type(categories) == 'table' and categories[category] == true
end

local function isFinite(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function trim(value)
    return type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
end

local function number(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not isFinite(value) then return fallback end
    return lib.math.clamp(value, minimum, maximum)
end

local function isEnabledValue(value)
    return value == true or value == 1 or value == '1'
end

local function validateImage(raw)
    local image = trim(raw)
    if image == '' then return '' end
    if #image > 300 then return nil, '画像の指定が長すぎます。' end

    local host = image:match('^https://([^/%?#:]+)')
    if host then
        host = host:lower()
        if not ServerConfig.image.allowedHosts[host] then
            return nil, ('画像URLのドメイン「%s」は許可されていません。'):format(host)
        end
        return image
    end

    if ServerConfig.image.allowFileName
        and image:match('^[%w_%-%.]+$')
        and not image:find('%.%.', 1, true) then
        return image
    end

    return nil, '画像は許可済みHTTPS URLまたは画像ファイル名で指定してください。'
end

local function validateMaterials(rawMaterials, oxItems, category)
    if rawMaterials == nil then
        return { materials = {}, materialPoints = 0, materialWeight = 0 }
    end
    if type(rawMaterials) ~= 'table' then return nil, '素材データが不正です。' end
    if #rawMaterials > ServerConfig.limits.maxMaterials then
        return nil, ('素材は最大%s種類です。'):format(ServerConfig.limits.maxMaterials)
    end

    local materials = {}
    local seen = {}
    local materialPoints = 0
    local materialWeight = 0

    for index = 1, #rawMaterials do
        local raw = rawMaterials[index]
        local name = type(raw) == 'table' and trim(raw.name):lower() or ''
        local requestedCount = type(raw) == 'table' and tonumber(raw.count or 1) or nil
        local count = requestedCount and math.floor(requestedCount) or 0

        if name == '' or not name:match('^[a-z0-9_]+$') then
            return nil, ('素材%sのアイテム名が不正です。'):format(index)
        end
        if not oxItems[name] then return nil, ('素材「%s」はox_inventoryに存在しません。'):format(name) end
        if category and not LCItemValidation.IsMaterialAllowed(name, category) then
            return nil, ('素材「%s」は選択したカテゴリーでは使用できません。'):format(name)
        end
        if seen[name] then return nil, ('素材「%s」が重複しています。'):format(name) end
        if not isFinite(requestedCount) or requestedCount ~= 1 or count ~= 1 then
            return nil, ('素材「%s」は1個だけ指定できます。'):format(name)
        end

        seen[name] = true
        materials[#materials + 1] = { name = name, count = count }

        local configured = ServerConfig.materials[name]
        local points = configured and tonumber(configured.points) or 0
        local weight = configured and tonumber(configured.weight) or tonumber(oxItems[name].weight) or 0
        materialPoints = materialPoints + math.max(points, 0) * count
        materialWeight = materialWeight + math.max(weight, 0) * count
    end

    return {
        materials = materials,
        materialPoints = materialPoints,
        materialWeight = materialWeight,
    }
end

function LCItemValidation.GetAlcoholBaseLevel()
    return number(ServerConfig.materialPoints.alcoholBaseLevel, 0, ServerConfig.limits.maxAlcoholLevel, 1.0)
end

local function calculateStatusPoints(consumable)
    local pointConfig = ServerConfig.materialPoints
    local costs = pointConfig.statusCosts
    local effects = consumable.effects or {}
    local total = 0

    for status, cost in pairs(costs) do
        total = total + math.abs(tonumber(effects[status]) or 0) * math.max(tonumber(cost) or 0, 0)
    end

    if consumable.category == 'alcohol' then
        total = total + math.abs((tonumber(consumable.alcoholLevel) or 0) - LCItemValidation.GetAlcoholBaseLevel())
            * math.max(tonumber(pointConfig.alcoholMultiplier) or 0, 0)
    end

    return math.floor(total * 100 + 0.5) / 100
end

local function getConsumableOptions()
    if GetResourceState('LC_consumables') ~= 'started' then return end

    local called, options = pcall(function()
        return exports.LC_consumables:GetConsumableOptions()
    end)

    if not called or type(options) ~= 'table' then return end
    return options
end

local function containsValue(values, expected)
    if type(values) ~= 'table' then return false end

    for index = 1, #values do
        if values[index] == expected then return true end
    end

    return false
end

function LCItemValidation.GetExpirationOptions()
    local expiration = type(SharedConfig.expiration) == 'table' and SharedConfig.expiration or {}
    local configuredOptions = type(expiration.options) == 'table' and expiration.options or {}
    local options = {}
    local seen = {}

    for index = 1, #configuredOptions do
        local configured = configuredOptions[index]
        local minutes = type(configured) == 'table' and tonumber(configured.minutes) or nil
        local label = type(configured) == 'table' and trim(configured.label) or ''

        if isFinite(minutes)
            and minutes == math.floor(minutes)
            and minutes >= 0
            and minutes <= ServerConfig.limits.maxDegradeMinutes
            and label ~= ''
            and not seen[minutes] then
            seen[minutes] = true
            options[#options + 1] = { label = label, minutes = minutes }
        end
    end

    if #options == 0 then
        options[1] = { label = '賞味期限なし', minutes = 0 }
        seen[0] = true
    end

    local defaultMinutes = tonumber(expiration.defaultMinutes)
    if not isFinite(defaultMinutes) or not seen[defaultMinutes] then
        defaultMinutes = options[1].minutes
    end

    return options, defaultMinutes
end

local function validateExpirationMinutes(value)
    local minutes = tonumber(value)
    if not isFinite(minutes) or minutes ~= math.floor(minutes) then
        return nil, '賞味期限をプリセットから選択してください。'
    end

    local options = LCItemValidation.GetExpirationOptions()
    for index = 1, #options do
        if options[index].minutes == minutes then return minutes end
    end

    return nil, '賞味期限をプリセットから選択してください。'
end

local function validateConsumable(raw, oxItems)
    if type(raw) ~= 'table' then return nil, '消費効果を設定してください。' end

    local consumableOptions = getConsumableOptions()
    if not consumableOptions then
        return nil, 'LC_consumablesから消費アイテム設定を取得できません。'
    end

    local category = trim(raw.category):lower()
    if type(consumableOptions.categories) ~= 'table' or not consumableOptions.categories[category] then
        return nil, '消費カテゴリーが不正です。'
    end

    local presentation = trim(raw.presentation):lower()
    if type(consumableOptions.presentations) ~= 'table' or not consumableOptions.presentations[presentation] then
        return nil, '使用アニメーションが不正です。'
    end

    local categoryPresentations = consumableOptions.categoryPresentations or {}
    if not containsValue(categoryPresentations[category], presentation) then
        return nil, '選択したカテゴリーではこのアニメーションを使用できません。'
    end

    local presentationSettings = consumableOptions.presentations[presentation]
    if type(presentationSettings) ~= 'table' then
        return nil, 'LC_consumablesからアニメーション設定を取得できません。'
    end

    local fixedDuration = tonumber(presentationSettings.duration)
    if not isFinite(fixedDuration) or fixedDuration <= 0 then
        return nil, '使用アニメーションの固定時間が不正です。'
    end

    local props = type(presentationSettings.props) == 'table' and presentationSettings.props or {}
    local prop = trim(raw.prop):lower()
    if not props[prop] then
        prop = trim(presentationSettings.defaultProp):lower()
    end
    if prop == '' or not props[prop] then
        return nil, '使用Propが不正です。'
    end

    local effectPreset = trim(raw.effectPreset):lower()
    if effectPreset == '' then effectPreset = 'none' end
    if not SharedConfig.effectPresets[effectPreset] then return nil, '画面効果が不正です。' end

    local statusLimit = ServerConfig.limits.statusDelta
    local rawEffects = type(raw.effects) == 'table' and raw.effects or {}
    local statusEditing = LCItemValidation.GetStatusEditing()
    local allowedStatuses = statusEditing.categories[category] or {}
    for _, status in ipairs(statusNames) do
        if statusEditing.mode ~= 'all' and allowedStatuses[status] ~= true
            and rawEffects[status] ~= nil and tonumber(rawEffects[status]) ~= 0 then
            return nil, ('選択したカテゴリーではステータス「%s」を設定できません。'):format(status)
        end
    end
    local result = {
        category = category,
        presentation = presentation,
        prop = prop,
        effects = {
            hunger = number(rawEffects.hunger, -statusLimit, statusLimit, 0),
            thirst = number(rawEffects.thirst, -statusLimit, statusLimit, 0),
            stress = number(rawEffects.stress, -statusLimit, statusLimit, 0),
        },
        effectPreset = effectPreset,
        effectDuration = math.floor(number(
            raw.effectDuration,
            0,
            ServerConfig.limits.maxEffectDuration,
            0
        )),
        alcoholLevel = category == 'alcohol' and number(
            raw.alcoholLevel,
            0,
            ServerConfig.limits.maxAlcoholLevel,
            LCItemValidation.GetAlcoholBaseLevel()
        ) or 0,
        canOverdose = category == 'alcohol' and raw.canOverdose == true or false,
    }

    return result
end

function LCItemValidation.Validate(raw, context, existing)
    if type(raw) ~= 'table' then return nil, '入力データが不正です。' end

    local ownerJob = existing and existing.owner_job or context.ownerJob
    if type(ownerJob) ~= 'string' or ownerJob == '' or ownerJob ~= context.ownerJob then
        return nil, '別ジョブのアイテムは作成・編集できません。'
    end

    local name = trim(raw.name):lower()
    if #name < 3 or #name > 64 or not name:match('^[a-z0-9_]+$') then
        return nil, 'アイテム名には半角英数字のみ使用できます。'
    end

    if existing and name ~= existing.name then return nil, '登録後のアイテム名は変更できません。' end

    if name:sub(1, #ownerJob + 1) ~= ownerJob .. '_' then
        return nil, ('アイテム名は「%s_」から始めてください。'):format(ownerJob)
    end

    if not existing then
        local suffix = name:sub(#ownerJob + 2)
        if suffix == '' or not suffix:match('^[a-z0-9]+$') then
            return nil, 'アイテム名には半角英数字のみ使用できます。'
        end
    end

    local label = trim(raw.label)
    if #label < 1 or #label > 80 then return nil, '表示名は1～80文字で指定してください。' end

    local itemType = trim(raw.type):lower()
    if not SharedConfig.itemTypes[itemType] then return nil, 'アイテムタイプが不正です。' end

    local image, imageError = validateImage(raw.image)
    if not image then return nil, imageError end

    local description = trim(raw.description)
    if #description > ServerConfig.limits.maxDescriptionLength then
        return nil, ('説明文は最大%s文字です。'):format(ServerConfig.limits.maxDescriptionLength)
    end

    local degradeMinutes, expirationError = validateExpirationMinutes(raw.degradeMinutes)
    if degradeMinutes == nil then return nil, expirationError end

    local oxItems = exports.ox_inventory:Items()
    if type(oxItems) ~= 'table' then return nil, 'ox_inventoryのアイテム一覧を取得できません。' end

    local category = itemType == 'usable' and trim(type(raw.consumable) == 'table' and raw.consumable.category):lower() or nil
    local recipe, recipeError = validateMaterials(raw.materials, oxItems, category)
    if not recipe then return nil, recipeError end

    local enabled
    if existing then
        enabled = isEnabledValue(existing.enabled)
    else
        enabled = raw.enabled ~= false
    end

    local definition = {
        name = name,
        label = label,
        ownerJob = ownerJob,
        type = itemType,
        weight = math.floor(number(raw.weight, 0, ServerConfig.limits.maxWeight, 0)),
        stack = raw.stack ~= false,
        close = raw.close ~= false,
        description = description,
        image = image,
        degradeMinutes = degradeMinutes,
        decay = raw.decay == true,
        enabled = enabled,
        recipe = recipe,
    }

    if itemType == 'usable' then
        local consumable, consumableError = validateConsumable(raw.consumable, oxItems)
        if not consumable then return nil, consumableError end

        local statusPoints = calculateStatusPoints(consumable)
        recipe.statusPoints = statusPoints
        if ServerConfig.materialPoints.enforceBudget and statusPoints > recipe.materialPoints then
            return nil, string.format(
                '使用Pが素材Pを%sP超過しています。素材またはステータス値を調整してください。',
                statusPoints - recipe.materialPoints
            )
        end

        if ServerConfig.materialPoints.autoWeightForUsable then
            definition.weight = math.floor(recipe.materialWeight)
        end
        definition.consumable = consumable
    end

    return definition
end
