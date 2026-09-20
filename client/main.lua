local nuiOpen = false

local function setOpen(value, bootstrap)
    nuiOpen = value == true
    SetNuiFocus(nuiOpen, nuiOpen)
    SendNUIMessage({
        action = nuiOpen and 'open' or 'close',
        data = bootstrap,
    })
end

local function notify(message, notificationType)
    lib.notify({
        title = 'LC Item Creator',
        description = message,
        type = notificationType or 'inform',
        position = ClientConfig.notifyPosition,
    })
end

local function requestBootstrap()
    local response = lib.callback.await('LC_itemcreator:server:bootstrap', false)
    if not response or response.success ~= true then
        notify(response and response.message or 'データを取得できません。', 'error')
        return
    end

    return response.data
end

RegisterNetEvent('LC_itemcreator:client:open', function()
    local bootstrap = requestBootstrap()
    if not bootstrap then return end
    setOpen(true, bootstrap)
end)

-- 旧ng-itemcreatorのアイテムや外部リソースから開く場合の互換イベントです。
RegisterNetEvent('ng-itemcreator:client:openItemUi', function()
    TriggerEvent('LC_itemcreator:client:open')
end)

RegisterNUICallback('close', function(_, callback)
    setOpen(false)
    callback({ success = true })
end)

RegisterNUICallback('refresh', function(_, callback)
    local bootstrap = requestBootstrap()
    callback({ success = bootstrap ~= nil, data = bootstrap })
end)

RegisterNUICallback('save', function(data, callback)
    local response = lib.callback.await('LC_itemcreator:server:save', false, data)
    if response then notify(response.message, response.success and 'success' or 'error') end

    if response and response.success then
        response.data = requestBootstrap()
    end
    callback(response or { success = false, message = '応答がありません。' })
end)

RegisterNUICallback('setEnabled', function(data, callback)
    local response = lib.callback.await('LC_itemcreator:server:setEnabled', false, data)
    if response then notify(response.message, response.success and 'success' or 'error') end

    if response and response.success then
        response.data = requestBootstrap()
    end
    callback(response or { success = false, message = '応答がありません。' })
end)

RegisterNUICallback('delete', function(data, callback)
    local response = lib.callback.await('LC_itemcreator:server:delete', false, data)
    if response then notify(response.message, response.success and 'success' or 'error') end

    if response and response.success then
        response.data = requestBootstrap()
    end
    callback(response or { success = false, message = '応答がありません。' })
end)

RegisterNUICallback('escape', function(_, callback)
    setOpen(false)
    callback({ success = true })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and nuiOpen then
        SetNuiFocus(false, false)
    end
end)
