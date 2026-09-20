LCItemStorage = {}

local ready = false

local function databaseError(operation, detail)
    return ('database_%s_failed: %s'):format(operation, tostring(detail or 'unknown'))
end

MySQL.ready(function()
    local success, result = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `lc_itemcreator_items` (
                `name` VARCHAR(64) NOT NULL,
                `label` VARCHAR(80) NOT NULL,
                `owner_job` VARCHAR(64) NOT NULL,
                `data` LONGTEXT NOT NULL,
                `enabled` TINYINT(1) NOT NULL DEFAULT 1,
                `revision` INT UNSIGNED NOT NULL DEFAULT 1,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`name`),
                KEY `idx_lc_itemcreator_owner_job` (`owner_job`),
                KEY `idx_lc_itemcreator_enabled` (`enabled`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])

        if ServerConfig.recipeCompatibility.enabled then
            MySQL.query.await([[
                CREATE TABLE IF NOT EXISTS `item_recipes` (
                    `id` INT AUTO_INCREMENT PRIMARY KEY,
                    `item_name` VARCHAR(100) NOT NULL UNIQUE,
                    `item_label` VARCHAR(255) NOT NULL,
                    `materials` TEXT NOT NULL,
                    `created_by` VARCHAR(50) NOT NULL,
                    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    INDEX `idx_item_name` (`item_name`),
                    INDEX `idx_created_by` (`created_by`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]])
        end
    end)

    if not success then
        lib.print.error(databaseError('migration', result))
        return
    end

    ready = true
    TriggerEvent('LC_itemcreator:server:storageReady')
end)

function LCItemStorage.IsReady()
    return ready
end

function LCItemStorage.Get(name)
    if not ready then return nil, 'database_not_ready' end

    local success, row = pcall(MySQL.single.await, [[
        SELECT `name`, `label`, `owner_job`, `data`, `enabled`, `revision`,
               `created_at`, `updated_at`
        FROM `lc_itemcreator_items`
        WHERE `name` = ?
    ]], { name })

    if not success then return nil, databaseError('get', row) end
    return row
end

function LCItemStorage.GetAll()
    if not ready then return nil, 'database_not_ready' end

    local success, rows = pcall(MySQL.query.await, [[
        SELECT `name`, `label`, `owner_job`, `data`, `enabled`, `revision`,
               `created_at`, `updated_at`
        FROM `lc_itemcreator_items`
        ORDER BY `owner_job`, `name`
    ]], {})

    if not success then return nil, databaseError('list', rows) end
    return rows or {}
end

function LCItemStorage.CountByJob(jobName)
    if not ready then return nil, 'database_not_ready' end

    local success, count = pcall(MySQL.scalar.await, [[
        SELECT COUNT(*) FROM `lc_itemcreator_items` WHERE `owner_job` = ?
    ]], { jobName })

    if not success then return nil, databaseError('count', count) end
    return tonumber(count) or 0
end

function LCItemStorage.Save(definition, previous)
    if not ready then return false, 'database_not_ready' end

    local encoded = json.encode(definition)
    local enabled = definition.enabled == false and 0 or 1

    if not previous then
        local success, result = pcall(MySQL.insert.await, [[
            INSERT INTO `lc_itemcreator_items`
                (`name`, `label`, `owner_job`, `data`, `enabled`, `revision`)
            VALUES (?, ?, ?, ?, ?, 1)
        ]], {
            definition.name,
            definition.label,
            definition.ownerJob,
            encoded,
            enabled,
        })

        if not success or not result then return false, databaseError('insert', result) end
        definition.revision = 1
        return true
    end

    local nextRevision = (tonumber(previous.revision) or 0) + 1
    local success, affected = pcall(MySQL.update.await, [[
        UPDATE `lc_itemcreator_items`
        SET `label` = ?, `data` = ?, `enabled` = ?, `revision` = ?
        WHERE `name` = ? AND `revision` = ?
    ]], {
        definition.label,
        encoded,
        enabled,
        nextRevision,
        definition.name,
        previous.revision,
    })

    if not success then return false, databaseError('update', affected) end
    if tonumber(affected) ~= 1 then return false, 'revision_conflict' end

    definition.revision = nextRevision
    return true
end

function LCItemStorage.Delete(name, revision)
    if not ready then return false, 'database_not_ready' end

    local success, affected = pcall(MySQL.update.await, [[
        DELETE FROM `lc_itemcreator_items`
        WHERE `name` = ? AND `revision` = ? AND `enabled` = 0
    ]], { name, revision })

    if not success then return false, databaseError('delete', affected) end
    if tonumber(affected) ~= 1 then return false, 'revision_conflict_or_item_enabled' end
    return true
end

function LCItemStorage.Restore(previous, name)
    if not ready then return false, 'database_not_ready' end

    if not previous then
        local success, result = pcall(MySQL.update.await,
            'DELETE FROM `lc_itemcreator_items` WHERE `name` = ?',
            { name }
        )
        return success, success and nil or databaseError('rollback_delete', result)
    end

    local success, result = pcall(MySQL.update.await, [[
        INSERT INTO `lc_itemcreator_items`
            (`name`, `label`, `owner_job`, `data`, `enabled`, `revision`, `created_at`, `updated_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            `label` = VALUES(`label`),
            `owner_job` = VALUES(`owner_job`),
            `data` = VALUES(`data`),
            `enabled` = VALUES(`enabled`),
            `revision` = VALUES(`revision`),
            `created_at` = VALUES(`created_at`),
            `updated_at` = VALUES(`updated_at`)
    ]], {
        previous.name,
        previous.label,
        previous.owner_job,
        previous.data,
        previous.enabled,
        previous.revision,
        previous.created_at,
        previous.updated_at,
    })

    return success, success and nil or databaseError('rollback_restore', result)
end

function LCItemStorage.SyncLegacyRecipe(definition)
    if not ready or not ServerConfig.recipeCompatibility.enabled then return true end

    local recipe = definition.recipe
    if definition.enabled == false or type(recipe) ~= 'table' or #recipe.materials == 0 then
        local success, result = pcall(MySQL.update.await,
            'DELETE FROM `item_recipes` WHERE `item_name` = ?',
            { definition.name }
        )
        return success, success and nil or databaseError('legacy_recipe_delete', result)
    end

    local legacyMaterials = {}
    for index = 1, #recipe.materials do
        legacyMaterials[index] = recipe.materials[index].name
    end

    local success, result = pcall(MySQL.update.await, [[
        INSERT INTO `item_recipes` (`item_name`, `item_label`, `materials`, `created_by`)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            `item_label` = VALUES(`item_label`),
            `materials` = VALUES(`materials`),
            `created_by` = VALUES(`created_by`),
            `updated_at` = CURRENT_TIMESTAMP
    ]], {
        definition.name,
        definition.label,
        json.encode(legacyMaterials),
        definition.ownerJob,
    })

    return success, success and nil or databaseError('legacy_recipe_save', result)
end
