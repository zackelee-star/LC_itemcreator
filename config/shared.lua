SharedConfig = {
    debug = false,
    -- Supported values: 'qbx_core' or 'qb-core'.
    framework = 'qbx_core',
    command = 'itemcreator',

    itemTypes = {
        normal = '通常アイテム',
        usable = '消費アイテム',
    },

    effectPresets = {
        none = 'なし',
        alcohol = '酔い',
        psychotropic = '幻覚',
        caffeine = 'カフェイン',
    },

    -- ox_inventoryのdegradeへ渡す賞味期限（分）です。
    -- Item Creator上では、ここに登録した値だけを選択できます。
    expiration = {
        defaultMinutes = 0,
        options = {
            { label = '1時間', minutes = 60 },
            { label = '3時間', minutes = 180 },
            { label = '6時間', minutes = 360 },
            { label = '12時間', minutes = 720 },
            { label = '24時間', minutes = 1440 },
            { label = '48時間（2日）', minutes = 2880 },
            { label = '72時間（3日）', minutes = 4320 },
            { label = '168時間（1週間）', minutes = 10080 },
            { label = '賞味期限なし', minutes = 0 },
        },
    },
}
