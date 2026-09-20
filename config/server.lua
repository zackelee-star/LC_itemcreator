ServerConfig = {
    -- ACEは許可ジョブ外から開くための代替権限です。他ジョブの閲覧権限は付与しません。
    adminAce = 'admin',
    autoInstall = false,
    adminDefaultOwner = 'admin', -- 許可ジョブに就いていないACE管理者専用の管理範囲

    allowedJobs = {
        government = 1,
        shop1 = 3,
        shop2 = 3,
        shop3 = 3,
        shop4 = 3,
        shop5 = 3,
        shop6 = 3,
        shop7 = 3,
        shop8 = 3,
        shop9 = 3,
        shop10 = 3,
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
        -- 基準値は0P。上下どちらへの調整も、基準値との差の絶対値×倍率で計算します。
        alcoholBaseLevel = 1.0,
        -- 0.05の調整で1P（例: 0.25は15P、1.0は0P、2.0は20P）。
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
       --パレットタウン設定--
       foodmaterial_a  = { label = '料理キットA',             points = 25,  weight = 100,  icon = '🍜', categories = { food = true, drink = true, } },
       foodmaterial_b  = { label = '料理キットB',             points = 40,  weight = 150,  icon = '🍜', categories = { food = true, drink = true, } },
       foodmaterial_c  = { label = '料理キットC',             points = 50,  weight = 200,  icon = '🍜', categories = { food = true, drink = true, } },
       alcoholkit_a    = { label = 'アルコールキットA',        points = 25,  weight = 100,  icon = '🍺', categories = { alcohol = true } },
       alcoholkit_b    = { label = 'アルコールキットB',        points = 40,  weight = 150,  icon = '🍺', categories = { alcohol = true } },
       alcoholkit_c    = { label = 'アルコールキットC',        points = 50,  weight = 200,  icon = '🍺', categories = { alcohol = true } },
       cigarettekit_a  = { label = 'シガレットキットA',        points = 25,  weight = 100,  icon = '🌿', categories = { smoke = true } },
       cigarettekit_b  = { label = 'シガレットキットB',        points = 40,  weight = 150,  icon = '🌿', categories = { smoke = true } },
       cigarettekit_c  = { label = 'シガレットキットC',        points = 50,  weight = 200,  icon = '🌿', categories = { smoke = true } },
       --
       -- vegetables      = { label = '野菜',              points = 5,  weight = 20,  icon = '🥬', categories = { food = true, drink = true, smoke = true } },
       -- fruit           = { label = 'フルーツ',          points = 5,  weight = 20,  icon = '🍊', categories = { food = true, drink = true, smoke = true} },
       -- processed_meat  = { label = '加工肉',            points = 5,  weight = 20,  icon = '🍖', categories = { food = true,  } },
       -- seafood         = { label = '海産物',            points = 5,  weight = 20,  icon = '🐟', categories = { food = true,  } },
       -- seasoning       = { label = '調味料',            points = 5,  weight = 20,  icon = '🧂', categories = { food = true, drink = true, smoke = true  } },
       -- fooddrink       = { label = 'ドリンクの原液',     points = 5,  weight = 20,  icon = '🧃', categories = { drink = true, alcohol = true } },
       -- alcholdrink     = { label = 'アルコールの原液',   points = 5,  weight = 20,  icon = '🍺', categories = { drink = true, alcohol = true } },
       -- tabaco          = { label = 'たばこの葉',         points = 15,  weight = 20,  icon = '🌿', categories = { smoke = true  } },
       -- rolling_paper   = { label = 'ローリングペーパー',  points = 10,  weight = 20,  icon = '🌿', categories = { smoke = true  } },

        -- pumpkin        = { label = 'かぼちゃ',           points = 20, weight = 25,  icon = '🎃', categories = { food = true, smoke = true } },
        -- melon2         = { label = 'メロン',             points = 20, weight = 25,  icon = '🍈', categories = { food = true, drink = true, alcohol = true } },
        -- wheat          = { label = '小麦',               points = 23, weight = 25,  icon = '🌾', categories = { food = true, smoke = true } },
        -- milkbottle     = { label = '生乳',               points = 20, weight = 23,  icon = '🥛', categories = { drink = true, alcohol = true } },
        -- raw_pork       = { label = '生肉',               points = 25, weight = 30,  icon = '🍖', categories = { food = true } },
        -- chicken_leg    = { label = '加工済みの鶏肉',      points = 25, weight = 25,  icon = '🍗', categories = { food = true } },
        -- meat           = { label = '牛肉',               points = 25, weight = 25,  icon = '🍖', categories = { food = true } },
        -- aquiver_milk   = { label = '新鮮な牛乳',         points = 30, weight = 50,  icon = '🥛', categories = { drink = true, alcohol = true } },
        -- aquiver_egg    = { label = '新鮮な卵',           points = 30, weight = 50,  icon = '🥚', categories = { food = true, smoke = true } },

    },
}
