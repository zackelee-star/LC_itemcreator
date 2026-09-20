fx_version 'cerulean'
game 'gta5'

author 'LC'
description 'Qbox/QBCore item and consumable creator with live ox_inventory publishing'
version '1.6.5'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
}

client_scripts {
    'config/client.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/server.lua',
    'server/installer.js',
    'server/framework.lua',
    'server/storage.lua',
    'server/validation.lua',
    'server/publisher.lua',
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'installation/ox_inventory/lc_itemcreator_bridge.lua',
    'installation/ox_inventory/lc_itemcreator_bridge.client.lua',
    'installation/README.md',
}

escrow_ignore {
    'config/shared.lua',
    'config/client.lua',
    'config/server.lua',
    'installation/**',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'LC_consumables',
}
