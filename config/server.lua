ServerConfig = {
    -- ACEは許可ジョブ外から開くための代替権限です。他ジョブの閲覧権限は付与しません。
    adminAce = 'admin',
    autoInstall = false,
    adminDefaultOwner = 'admin', -- 許可ジョブに就いていないACE管理者専用の管理範囲

    allowedJobs = {
        government = 1,
        shop1 = 4,
        shop2 = 4,
        shop3 = 4,
        shop4 = 4,
        shop5 = 4,
        shop6 = 4,
        shop7 = 4,
        shop8 = 4,
        shop9 = 4,
        shop10 = 4,
    },

    limits = {
        maxItemsPerJob = 250,
        maxMaterials = 10,
        -- ng-itemcreator互換: 1素材につき投入できるのは1個だけです。
        maxMaterialCount = 1,
        maxWeight = 100000,
        maxDescriptionLength = 500,
        maxDegradeMinutes = 525600,
        minUseDuration = 500,
        maxUseDuration = 30000,
        maxEffectDuration = 120000,
        maxAlcoholLevel = 5.0,
        statusDelta = 100,
        mutationCooldown = 1500,
    },

    image = {
        allowFileName = true,
        allowedHosts = {
            ['gazou1.dlup.by'] = true,
            ['r2.fivemanage.com'] = true,
        },
    },

    recipeCompatibility = {
        enabled = true,
        addOrUpdateEvent = 'LC_foodcraft:notifyRecipeAddedOrUpdated',
        deleteEvent = 'LC_foodcraft:notifyRecipeDeleted',
    },

    materialPoints = {
        autoWeightForUsable = true,
        enforceBudget = true,
        statusCosts = {
            hunger = 1,
            thirst = 1,
            stress = 1,
        },
        -- qbx_consumables形式のalcoholLevelを素材Pへ換算します（0.25 = 5P）。
        alcoholMultiplier = 20,
    },

    -- all: 全ステータス / category: カテゴリーごとにtrueの項目だけ編集可能。
    -- categoryモードでは未指定のカテゴリー・項目は不許可です。
    statusEditing = {
        mode = 'category',
        categories = {
            food = { hunger = true, thirst = true },
            drink = { hunger = true, thirst = true },
            alcohol = { thirst = true, stress = true },
            smoke = { stress = true },
        },
    },

    -- ng-itemcreator v2の素材設定を移植しています。
    -- pointsは効果へ割り振れるP、weightは完成品へ加算する1個あたりの重量(g)です。
    -- categoriesを省略すると全カテゴリー共通。指定時はtrueのカテゴリーのみ許可。
    -- categories = {} は全カテゴリー不許可。喫煙専用素材は { smoke = true } を指定。
    materials = {
        sugar          = { label = '砂糖',               points = 8,  weight = 20,  icon = '🧂', categories = { food = true, drink = true, alcohol = true } },
        flour          = { label = '小麦粉',             points = 8,  weight = 20,  icon = '🧂', categories = { food = true } },
        nori           = { label = '海苔',               points = 8,  weight = 20,  icon = '🧂', categories = { food = true } },
        tofu           = { label = '豆腐',               points = 8,  weight = 20,  icon = '🧂', categories = { food = true } },
        onion          = { label = 'たまねぎ',           points = 8,  weight = 20,  icon = '🧅', categories = { food = true } },
        boba           = { label = 'ボバ',               points = 8,  weight = 20,  icon = '🧂', categories = { drink = true, alcohol = true } },
        mint           = { label = 'ミント',             points = 8,  weight = 20,  icon = '🌿' },
        orange         = { label = 'オレンジ',           points = 8,  weight = 20,  icon = '🍊', categories = { food = true, drink = true, alcohol = true } },
        strawberry     = { label = 'いちご',             points = 8,  weight = 20,  icon = '🍓', categories = { food = true, drink = true, alcohol = true } },
        blueberry      = { label = 'ブルーベリー',       points = 8,  weight = 20,  icon = '🍇', categories = { food = true, drink = true, alcohol = true } },
        milk           = { label = 'ミルク',             points = 8,  weight = 20,  icon = '🥛', categories = { food = true, drink = true, alcohol = true } },
        sake           = { label = '酒',                 points = 8,  weight = 20,  icon = '🍺', categories = { alcohol = true } },
        noodles        = { label = '即席麺',             points = 8,  weight = 20,  icon = '🍜', categories = { food = true } },
        rice           = { label = '米',                 points = 8,  weight = 20,  icon = '🍚', categories = { food = true } },
        lettuce        = { label = 'レタス',             points = 8,  weight = 20,  icon = '🥬', categories = { food = true } },
        fooddrink      = { label = 'ドリンクの原液',     points = 8,  weight = 20,  icon = '🧃', categories = { drink = true, alcohol = true } },
        alcholdrink    = { label = 'アルコールの原液',   points = 8,  weight = 20,  icon = '🍺', categories = { alcohol = true } },
        melon          = { label = 'スイカ',             points = 13, weight = 25,  icon = '🍉', categories = { food = true, drink = true, alcohol = true } },
        watermelon     = { label = '新スイカ',           points = 13, weight = 25,  icon = '🍉', categories = { food = true, drink = true, alcohol = true } },
        pumpkin        = { label = 'かぼちゃ',           points = 13, weight = 25,  icon = '🎃', categories = { food = true } },
        melon2         = { label = 'メロン',             points = 17, weight = 25,  icon = '🍈', categories = { food = true, drink = true, alcohol = true } },
        wheat          = { label = '小麦',               points = 15, weight = 25,  icon = '🌾', categories = { food = true } },
        milkbottle     = { label = '生乳',               points = 14, weight = 23,  icon = '🥛', categories = { food = true, drink = true, alcohol = true } },
        raw_pork       = { label = '生肉',               points = 18, weight = 30,  icon = '🍖', categories = { food = true } },
        chicken_leg    = { label = '加工済みの鶏肉',     points = 22, weight = 25,  icon = '🍗', categories = { food = true } },
        meat           = { label = '牛肉',               points = 22, weight = 25,  icon = '🍖', categories = { food = true } },
        aquiver_milk   = { label = '新鮮な牛乳',         points = 25, weight = 50,  icon = '🥛', categories = { food = true, drink = true, alcohol = true } },
        aquiver_egg    = { label = '新鮮な卵',           points = 25, weight = 50,  icon = '🥚', categories = { food = true } },
        zander         = { label = 'ザンダー',           points = 25, weight = 50,  icon = '🐟', categories = { food = true } },
        sea_trout      = { label = 'シーバス',           points = 25, weight = 50,  icon = '🐟', categories = { food = true } },
        european_bass  = { label = 'ヨーロッパバス',     points = 25, weight = 50,  icon = '🐟', categories = { food = true } },
        grey_snapper   = { label = 'アカアマダイ',       points = 26, weight = 55,  icon = '🐟', categories = { food = true } },
        eel            = { label = 'ウナギ',             points = 27, weight = 58,  icon = '🐟', categories = { food = true } },
        giant_grouper  = { label = 'オオグルーパー',     points = 27, weight = 60,  icon = '🐟', categories = { food = true } },
        yellowfin_tuna = { label = 'キハダマグロ',       points = 27, weight = 60,  icon = '🐟', categories = { food = true } },
        pufferfish     = { label = 'フグ',               points = 30, weight = 65,  icon = '🐟', categories = { food = true } },
        seaturtle      = { label = 'ウミガメ',           points = 30, weight = 75,  icon = '🐢', categories = { food = true } },
        bluefin_tuna   = { label = 'クロマグロ',         points = 30, weight = 85,  icon = '🐟', categories = { food = true } },
        blueshark      = { label = 'ヨシキリザメ',       points = 30, weight = 100, icon = '🦈', categories = { food = true } },
    },
}
