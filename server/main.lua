lib.checkDependency('ox_lib', '3.0.0', true)
lib.checkDependency('oxmysql', '2.7.0', true)
lib.checkDependency('ox_inventory', '2.30.0', true)

local frameworkReady, frameworkError = ItemCreatorFramework.Initialize()
if not frameworkReady then
    error(('[LC_itemcreator] Framework initialization failed: %s'):format(
        tostring(frameworkError)
    ), 0)
end

local cache = {}
local initialized = false
local mutationTimes = {}

local function DebugPrint(...)
    if not SharedConfig.debug then return end
    lib.print.debug(...)
end

local function response(success, message, data)
    return { success = success == true, message = message, data = data }
end

local function notify(source, message, notificationType)
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'LC Item Creator',
        description = message,
        type = notificationType or 'inform',
    })
end

local function normalizeSource(value)
    local source = tonumber(value)
    if not source or source <= 0 or source ~= math.floor(source) then return end
    return source
end

local function getAccessContext(source)
    source = normalizeSource(source)
    if not source then return end

    local player = ItemCreatorFramework.GetPlayer(source)
    if not player then return end

    local job = player.PlayerData.job or {}
    local grade = type(job.grade) == 'table' and job.grade.level or job.grade
    grade = tonumber(grade) or 0

    local admin = IsPlayerAceAllowed(source, ServerConfig.adminAce)
    local minimumGrade = ServerConfig.allowedJobs[job.name]
    local jobAllowed = minimumGrade ~= nil and grade >= minimumGrade

    if not admin and not jobAllowed then return end

    -- 管理者権限はコマンドを開くための代替権限にだけ使用し、
    -- 他ジョブの定義を閲覧・編集する権限には昇格させません。
    local ownerJob = jobAllowed and job.name or ServerConfig.adminDefaultOwner

    return {
        admin = admin,
        jobName = job.name or ServerConfig.adminDefaultOwner,
        ownerJob = ownerJob,
        grade = grade,
    }
end

local function canManage(context, row)
    return row.owner_job == context.ownerJob
end

local function isRateLimited(source)
    local now = GetGameTimer()
    local previous = mutationTimes[source]
    if previous and now - previous < ServerConfig.limits.mutationCooldown then return true end

    mutationTimes[source] = now
    return false
end

local function reloadCache()
    local rows, errorCode = LCItemStorage.GetAll()
    if not rows then return false, errorCode end

    local definitions, decodeError = LCItemPublisher.DecodeRows(rows)
    if not definitions then return false, decodeError end

    cache = definitions
    return true
end

local function publishCache()
    return LCItemPublisher.Publish(cache)
end

local function rollback(previous, itemName)
    local restored, restoreError = LCItemStorage.Restore(previous, itemName)
    if not restored then
        lib.print.error(('[LC_itemcreator] Database rollback failed for %s: %s'):format(itemName, restoreError))
        return false
    end

    local cacheRestored, cacheError = reloadCache()
    if not cacheRestored then
        lib.print.error(('[LC_itemcreator] Cache rollback failed for %s: %s'):format(itemName, cacheError))
        return false
    end

    local republished, publishError = publishCache()
    if not republished then
        lib.print.error(('[LC_itemcreator] Publish rollback failed for %s: %s'):format(itemName, publishError))
    end

    return republished
end

local function syncRecipe(definition)
    local compatibility = ServerConfig.recipeCompatibility
    if not compatibility.enabled then return end

    local success, errorCode = LCItemStorage.SyncLegacyRecipe(definition)
    if not success then
        lib.print.warn(('[LC_itemcreator] Legacy recipe sync failed for %s: %s'):format(definition.name, errorCode))
        return
    end

    if definition.enabled ~= false and definition.recipe and #definition.recipe.materials > 0 then
        TriggerEvent(compatibility.addOrUpdateEvent, definition.ownerJob, definition.name)
    else
        TriggerEvent(compatibility.deleteEvent, definition.ownerJob, definition.name)
    end
end

local function visibleDefinitions(context)
    local result = {}

    for index = 1, #cache do
        local definition = cache[index]
        if definition.ownerJob == context.ownerJob then
            result[#result + 1] = definition
        end
    end

    return result
end

local function materialOptions(definitions)
    local oxItems = exports.ox_inventory:Items()
    if type(oxItems) ~= 'table' then oxItems = {} end

    local byName = {}
    for name, configured in pairs(ServerConfig.materials) do
        local oxItem = oxItems[name]
        byName[name] = {
            name = name,
            label = configured.label or (oxItem and oxItem.label) or name,
            points = math.max(tonumber(configured.points) or 0, 0),
            weight = math.max(tonumber(configured.weight) or (oxItem and tonumber(oxItem.weight)) or 0, 0),
            icon = configured.icon or '📦',
            categories = configured.categories,
            available = oxItem ~= nil,
        }
    end

    -- 旧データに独自素材が含まれていても、編集画面から消えないように補完します。
    for definitionIndex = 1, #definitions do
        local recipe = definitions[definitionIndex].recipe
        local materials = type(recipe) == 'table' and recipe.materials or {}
        for materialIndex = 1, #materials do
            local name = materials[materialIndex].name
            if type(name) == 'string' and not byName[name] then
                local oxItem = oxItems[name]
                byName[name] = {
                    name = name,
                    label = (oxItem and oxItem.label) or name,
                    points = 0,
                    weight = (oxItem and tonumber(oxItem.weight)) or 0,
                    icon = '📦',
                    available = oxItem ~= nil,
                }
            end
        end
    end

    local result = {}
    for _, material in pairs(byName) do result[#result + 1] = material end
    table.sort(result, function(left, right)
        return left.label == right.label and left.name < right.name or left.label < right.label
    end)
    return result
end

local function integrationStatus()
    local called, status = pcall(function()
        return exports.ox_inventory:lcItemCreatorStatus()
    end)

    if not called or type(status) ~= 'table' then
        return { ready = false, message = 'ox_inventoryブリッジが未導入です。' }
    end

    return status
end

local function consumableOptions()
    if GetResourceState('LC_consumables') ~= 'started' then return end

    local called, options = pcall(function()
        return exports.LC_consumables:GetConsumableOptions()
    end)

    if not called or type(options) ~= 'table' then return end
    return options
end

local function bootstrap(source)
    local context = getAccessContext(source)
    if not context then return response(false, 'アイテム作成権限がありません。') end
    if not initialized then return response(false, '初期化中です。少し待ってから再度お試しください。') end

    local definitions = visibleDefinitions(context)
    local availableOptions = consumableOptions()
    if not availableOptions
        or type(availableOptions.categories) ~= 'table'
        or type(availableOptions.presentations) ~= 'table'
        or type(availableOptions.categoryPresentations) ~= 'table' then
        return response(false, 'LC_consumablesから消費アイテム設定を取得できません。')
    end

    local presentationLabels = {}
    for name, settings in pairs(availableOptions.presentations) do
        presentationLabels[name] = settings.label or name
    end

    local expirationOptions, defaultExpirationMinutes = LCItemValidation.GetExpirationOptions()

    return response(true, 'ok', {
        access = {
            admin = context.admin,
            jobName = context.jobName,
            ownerJob = context.ownerJob,
            grade = context.grade,
        },
        options = {
            itemTypes = SharedConfig.itemTypes,
            categories = availableOptions.categories,
            presentations = presentationLabels,
            presentationSettings = availableOptions.presentations,
            categoryPresentations = availableOptions.categoryPresentations,
            effectPresets = SharedConfig.effectPresets,
            materials = materialOptions(definitions),
            maxMaterials = ServerConfig.limits.maxMaterials,
            maxMaterialCount = ServerConfig.limits.maxMaterialCount,
            maxAlcoholLevel = ServerConfig.limits.maxAlcoholLevel,
            statusPointCosts = ServerConfig.materialPoints.statusCosts,
            statusEditing = LCItemValidation.GetStatusEditing(),
            alcoholPointMultiplier = ServerConfig.materialPoints.alcoholMultiplier,
            enforceMaterialBudget = ServerConfig.materialPoints.enforceBudget,
            autoWeightForUsable = ServerConfig.materialPoints.autoWeightForUsable,
            expirationOptions = expirationOptions,
            defaultExpirationMinutes = defaultExpirationMinutes,
            inventoryImagePath = GetConvar('inventory:imagepath', 'nui://ox_inventory/web/images'),
        },
        integration = integrationStatus(),
        items = definitions,
    })
end

local function businessCatalog(source)
    local result = bootstrap(source)
    if not result or result.success ~= true or type(result.data) ~= 'table' then
        return result or response(false, '商品一覧を取得できません。')
    end

    local data = result.data
    local access = type(data.access) == 'table' and data.access or {}
    local options = type(data.options) == 'table' and data.options or {}

    return response(true, 'ok', {
        jobName = access.ownerJob,
        ownerJob = access.ownerJob,
        items = type(data.items) == 'table' and data.items or {},
        materials = type(options.materials) == 'table' and options.materials or {},
        options = options,
        integration = data.integration,
    })
end

lib.callback.register('LC_itemcreator:server:bootstrap', bootstrap)

local function saveItem(source, raw, allowEnabledMutation)
    local context = getAccessContext(source)
    if not context then return response(false, '権限がありません。') end
    if not initialized then return response(false, '初期化が完了していません。') end
    if isRateLimited(source) then return response(false, '操作間隔が短すぎます。') end
    if type(raw) ~= 'table' then return response(false, '入力データが不正です。') end

    local requestedName = type(raw.name) == 'string' and raw.name:lower() or ''
    local previous, getError = LCItemStorage.Get(requestedName)
    if getError then return response(false, '既存データを確認できません。') end

    if previous then
        if not canManage(context, previous) then return response(false, '別ジョブのアイテムは編集できません。') end
        if tonumber(raw.revision) ~= tonumber(previous.revision) then
            return response(false, '他の操作で更新されています。再読込してください。')
        end
    end

    local definition, validationError = LCItemValidation.Validate(raw, context, previous)
    if not definition then return response(false, validationError) end
    if previous and allowEnabledMutation == true and type(raw.enabled) == 'boolean' then
        definition.enabled = raw.enabled
    end

    if not previous then
        local count, countError = LCItemStorage.CountByJob(definition.ownerJob)
        if count == nil then return response(false, countError) end
        if count >= ServerConfig.limits.maxItemsPerJob then
            return response(false, 'このジョブで登録できるアイテム数の上限に達しています。')
        end

        local oxItem = exports.ox_inventory:Items(definition.name)
        if oxItem then return response(false, '同名アイテムが既にox_inventoryに存在します。') end
    end

    local saved, saveError = LCItemStorage.Save(definition, previous)
    if not saved then return response(false, ('保存に失敗しました: %s'):format(saveError)) end

    local cacheLoaded, cacheError = reloadCache()
    if not cacheLoaded then
        rollback(previous, definition.name)
        return response(false, ('保存後の読込に失敗しました: %s'):format(cacheError))
    end

    local published, publishError = publishCache()
    if not published then
        rollback(previous, definition.name)
        return response(false, ('反映に失敗したため変更を戻しました: %s'):format(publishError))
    end

    syncRecipe(definition)

    return response(true, previous and 'アイテムを更新し、全プレイヤーへ反映しました。'
        or 'アイテムを作成し、全プレイヤーへ反映しました。', definition)
end

lib.callback.register('LC_itemcreator:server:save', function(source, raw)
    return saveItem(source, raw, false)
end)

lib.callback.register('LC_itemcreator:server:setEnabled', function(source, raw)
    local context = getAccessContext(source)
    if not context then return response(false, '権限がありません。') end
    if not initialized then return response(false, '初期化が完了していません。') end
    if isRateLimited(source) then return response(false, '操作間隔が短すぎます。') end
    if type(raw) ~= 'table' or type(raw.name) ~= 'string' then return response(false, '入力が不正です。') end

    local previous, getError = LCItemStorage.Get(raw.name:lower())
    if getError then return response(false, getError) end
    if not previous then return response(false, 'アイテムが見つかりません。') end
    if not canManage(context, previous) then return response(false, '別ジョブのアイテムは変更できません。') end
    if tonumber(raw.revision) ~= tonumber(previous.revision) then
        return response(false, '他の操作で更新されています。再読込してください。')
    end

    local decodedOk, definition = pcall(json.decode, previous.data)
    if not decodedOk or type(definition) ~= 'table' then return response(false, '保存データが破損しています。') end

    definition.name = previous.name
    definition.label = previous.label
    definition.ownerJob = previous.owner_job
    definition.enabled = raw.enabled == true

    local saved, saveError = LCItemStorage.Save(definition, previous)
    if not saved then return response(false, ('変更に失敗しました: %s'):format(saveError)) end

    local cacheLoaded, cacheError = reloadCache()
    if not cacheLoaded then
        rollback(previous, definition.name)
        return response(false, cacheError)
    end

    local published, publishError = publishCache()
    if not published then
        rollback(previous, definition.name)
        return response(false, ('反映に失敗したため変更を戻しました: %s'):format(publishError))
    end

    syncRecipe(definition)

    return response(true, definition.enabled and 'アイテムを有効化しました。' or 'アイテムを無効化しました。')
end)

local function deleteItem(source, raw)
    local context = getAccessContext(source)
    if not context then return response(false, '権限がありません。') end
    if not initialized then return response(false, '初期化が完了していません。') end
    if isRateLimited(source) then return response(false, '操作間隔が短すぎます。') end
    if type(raw) ~= 'table' or type(raw.name) ~= 'string' then
        return response(false, '入力が不正です。')
    end

    local previous, getError = LCItemStorage.Get(raw.name:lower())
    if getError then return response(false, getError) end
    if not previous then return response(false, 'アイテムが見つかりません。') end
    if not canManage(context, previous) then return response(false, '別ジョブのアイテムは削除できません。') end
    if tonumber(raw.revision) ~= tonumber(previous.revision) then
        return response(false, '他の操作で更新されています。再読込してください。')
    end
    if previous.enabled == true or tonumber(previous.enabled) == 1 or previous.enabled == '1' then
        return response(false, 'アイテムを無効化してから削除してください。')
    end

    local decodedOk, definition = pcall(json.decode, previous.data)
    if not decodedOk or type(definition) ~= 'table' then
        return response(false, '保存データが破損しています。')
    end

    definition.name = previous.name
    definition.label = previous.label
    definition.ownerJob = previous.owner_job
    definition.enabled = false

    local deleted, deleteError = LCItemStorage.Delete(previous.name, previous.revision)
    if not deleted then return response(false, ('削除に失敗しました: %s'):format(deleteError)) end

    local cacheLoaded, cacheError = reloadCache()
    if not cacheLoaded then
        rollback(previous, previous.name)
        return response(false, ('削除後の読込に失敗したため元に戻しました: %s'):format(cacheError))
    end

    local published, publishError = publishCache()
    if not published then
        rollback(previous, previous.name)
        return response(false, ('反映に失敗したため削除を元に戻しました: %s'):format(publishError))
    end

    syncRecipe(definition)
    return response(true, 'アイテムを削除し、全プレイヤーへ反映しました。', {
        name = previous.name,
    })
end

lib.callback.register('LC_itemcreator:server:delete', function(source, raw)
    return deleteItem(source, raw)
end)

local function getRecipe(itemName)
    if type(itemName) ~= 'string' then return end

    for index = 1, #cache do
        local definition = cache[index]
        if definition.name == itemName and definition.recipe then
            local legacyMaterials = {}
            for materialIndex = 1, #definition.recipe.materials do
                legacyMaterials[materialIndex] = definition.recipe.materials[materialIndex].name
            end

            return {
                item_name = definition.name,
                item_label = definition.label,
                materials = json.encode(legacyMaterials),
                material_data = definition.recipe.materials,
                created_by = definition.ownerJob,
                enabled = definition.enabled,
            }
        end
    end
end

local function getAllRecipes(ownerJob)
    local recipes = {}

    for index = 1, #cache do
        local definition = cache[index]
        if definition.recipe and #definition.recipe.materials > 0
            and (not ownerJob or definition.ownerJob == ownerJob) then
            recipes[#recipes + 1] = getRecipe(definition.name)
        end
    end

    return recipes
end

exports('GetBusinessCatalog', function(source)
    return businessCatalog(source)
end)

exports('SaveBusinessItem', function(source, definition)
    return saveItem(source, definition, true)
end)

exports('DeleteBusinessItem', function(source, itemName, revision)
    return deleteItem(source, {
        name = itemName,
        revision = revision,
    })
end)

exports('GetConsumableDefinitions', function()
    local definitions = {}

    for index = 1, #cache do
        local definition = cache[index]
        if definition.enabled and definition.type == 'usable' and definition.consumable then
            definitions[#definitions + 1] = {
                name = definition.name,
                label = definition.label,
                image = definition.image,
                ownerJob = definition.ownerJob,
                category = definition.consumable.category,
                presentation = definition.consumable.presentation,
                prop = definition.consumable.prop,
                effects = definition.consumable.effects,
                effectPreset = definition.consumable.effectPreset,
                effectDuration = definition.consumable.effectDuration,
                alcoholLevel = definition.consumable.alcoholLevel,
                canOverdose = definition.consumable.canOverdose,
                enabled = true,
            }
        end
    end

    return definitions
end)

exports('GetRecipe', getRecipe)
exports('GetAllRecipes', getAllRecipes)
exports('getRecipe', getRecipe)
exports('getAllRecipes', getAllRecipes)

lib.addCommand(SharedConfig.command, {
    help = 'LC Item Creatorを開きます',
}, function(source)
    if source <= 0 then
        return lib.print.info('[LC_itemcreator] This command must be used in game.')
    end

    if not getAccessContext(source) then
        return notify(source, 'アイテム作成権限がありません。', 'error')
    end

    TriggerClientEvent('LC_itemcreator:client:open', source)
end)

local function initialize()
    if initialized or not LCItemStorage.IsReady() then return end

    local loaded, loadError = reloadCache()
    if not loaded then
        return lib.print.error(('[LC_itemcreator] Initial cache load failed: %s'):format(loadError))
    end

    local published, publishError = publishCache()
    if not published then
        lib.print.error(('[LC_itemcreator] Initial publish failed: %s. See installation/README.md.'):format(publishError))
    else
        DebugPrint(('[LC_itemcreator] Published %s stored items'):format(#cache))
    end

    initialized = true
end

AddEventHandler('LC_itemcreator:server:storageReady', initialize)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetTimeout(500, function()
            if ServerConfig.autoInstall then
                local called, errorMessage = pcall(function()
                    exports[GetCurrentResourceName()]:startInstallation()
                end)
                if not called then
                    lib.print.error(('[LC_itemcreator] Auto-install failed: %s. See installation/README.md.'):format(errorMessage))
                end
            end
            initialize()
        end)
    elseif resourceName == 'ox_inventory' or resourceName == 'LC_consumables' then
        SetTimeout(1000, function()
            if initialized then
                local success, errorCode = publishCache()
                if not success then
                    lib.print.error(('[LC_itemcreator] Republish failed after %s start: %s'):format(resourceName, errorCode))
                end
            end
        end)
    end
end)

AddEventHandler('playerDropped', function()
    mutationTimes[source] = nil
end)

if LCItemStorage.IsReady() then initialize() end
