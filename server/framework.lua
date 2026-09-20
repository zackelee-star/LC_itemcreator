ItemCreatorFramework = {}

local supportedFrameworks = {
    ['qbx_core'] = true,
    ['qb-core'] = true,
}

local minimumVersions = {
    ['qbx_core'] = '1.0.0',
    ['qb-core'] = '1.0.0',
}

local frameworkName
local QBCore

local function configuredFramework()
    local name = type(SharedConfig.framework) == 'string' and SharedConfig.framework or ''
    if not supportedFrameworks[name] then
        return nil, ("Unsupported framework '%s'. Use 'qbx_core' or 'qb-core'."):format(name)
    end
    return name
end

function ItemCreatorFramework.Initialize()
    local name, configError = configuredFramework()
    if not name then return false, configError end

    local state = GetResourceState(name)
    if state ~= 'started' then
        return false, ("Configured framework '%s' is not started (state: %s)."):format(name, state)
    end

    lib.checkDependency(name, minimumVersions[name], true)

    if name == 'qb-core' then
        QBCore = exports['qb-core']:GetCoreObject()
        if type(QBCore) ~= 'table' or type(QBCore.Functions) ~= 'table' then
            return false, 'Unable to acquire the qb-core object.'
        end
    end

    frameworkName = name
    return true
end

function ItemCreatorFramework.GetName()
    return frameworkName
end

function ItemCreatorFramework.GetPlayer(source)
    if frameworkName == 'qbx_core' then
        return exports.qbx_core:GetPlayer(source)
    end

    if frameworkName == 'qb-core' and QBCore then
        return QBCore.Functions.GetPlayer(source)
    end
end

RegisterNetEvent('QBCore:Server:UpdateObject', function()
    if frameworkName ~= 'qb-core' then return end
    QBCore = exports['qb-core']:GetCoreObject()
end)
