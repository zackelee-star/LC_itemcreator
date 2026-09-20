# LC_itemcreator

Qbox／QBCore・ox_inventory・LC_consumables対応のインゲームアイテム作成リソースです。

## 主な機能

- ジョブ・グレードまたはACE権限による作成UI
- 現在の管理ジョブに登録されたアイテムだけを表示・編集
- 登録一覧での商品画像サムネイル表示（外部URL・ox_inventory画像対応）
- アイテム基本情報、画像、重量、スタック、賞味期限
- Configで管理する賞味期限プリセットと期限切れ時の自動削除設定
- 変更できないジョブPrefixと半角英数字だけのアイテム名入力
- 食事・飲料・酒・喫煙・薬のアニメーションと効果
- アニメーションごとの固定使用時間と、動作に対応したProp選択
- カテゴリーに対応するアニメーションだけを表示・保存
- 酒ごとのアルコール加算値と過剰摂取可否
- 検索・並び替えに対応した素材選択UI（1素材につき1個）
- 素材P / 使用P / 残りP / 完成重量のリアルタイム表示
- Hunger / Thirst / Stressのスライダー設定
- 素材P上限のサーバー側検証と素材重量からの自動重量計算
- クラフト素材と旧`item_recipes`形式の互換同期
- ox_inventoryのサーバー・全接続クライアントへリアルタイム反映し、登録後の再ログイン時も個別同期
- DB、items.lua、ライブ一覧の反映失敗時ロールバック
- 無効化後の確認付き完全削除
- 複数人の同時編集による上書きを防ぐ更新競合検出

## 導入

### カテゴリー別の素材・ステータス設定

設定元は `config/server.lua` です。LC_itemcreatorとLC_businessの両方へ同じ編集ルールを配信し、保存時もサーバーで検証します。

```lua
statusEditing = {
    mode = 'category', -- 'all' にすると空腹・水分・ストレスを全カテゴリーで編集可能
    categories = {
        food = { hunger = true, thirst = true },
        drink = { hunger = true, thirst = true },
        alcohol = { thirst = true, stress = true },
        smoke = { stress = true },
    },
},
```

`category` モードでは未指定のカテゴリー・ステータスは編集不可です。`statusEditing` 自体を省略した旧configでは従来の全項目編集になります。アルコール加算値・過剰摂取は別設定で、アルコールカテゴリーのみです。素材Pの予算制限はどちらのモードでも従来どおり有効です。

各素材の既存設定へ `categories` を追加すると、その素材を使えるカテゴリーを指定できます。

```lua
flour = {
    label = '小麦粉', points = 8, weight = 20, icon = '🧂',
    categories = { food = true },
},
```

- `categories` を省略：全カテゴリー共通。
- `categories = { food = true, drink = true }`：食べ物・飲み物のみ。
- `categories = { smoke = true }`：喫煙のみ。
- `categories = {}`：すべて不許可。

同梱configは食材を食べ物、果物・乳製品等を食べ物／飲み物／アルコール、酒をアルコールへ分類しています。ミントは共通素材です。喫煙専用素材は、実際のインベントリ名を使って追加してください。`mode = 'all'` は素材の制限を解除しません。

カテゴリー変更で使えなくなる選択素材・効果は、確認画面で内容を表示します。キャンセルで元の設定を維持し、適用後も「保存して即時反映」を押すまでDBは変更しません。既存商品に許可外の設定がある場合は警告し、確認して解除するまで保存できません。設定変更だけで登録済み商品やクラフトレシピを一括変更することはありません。

変更後はLC_itemcreator、LC_businessの順で再起動し、画面を開き直してください。LC_businessの店舗別 `allowedCategories` は「店舗が扱えるカテゴリー」の制限として引き続き併用します。

### 基本手順

1. `installation/README.md`に従ってox_inventoryブリッジを導入します。
2. `config/shared.lua`の`SharedConfig.framework`を使用環境に合わせます。

```lua
-- Qbox
framework = 'qbx_core'

-- 旧QBCore
framework = 'qb-core'
```

`LC_consumables`側の`SharedConfig.framework`にも同じ値を設定してください。

3. `config/server.lua`の`allowedJobs`をサーバーの飲食店ジョブに合わせます。
4. 依存リソースより後に起動します。

Qbox環境:

```cfg
ensure ox_lib
ensure qbx_core
ensure oxmysql
ensure ox_inventory
ensure LC_consumables
ensure LC_itemcreator
```

旧QBCore環境:

```cfg
ensure ox_lib
ensure qb-core
ensure oxmysql
ensure ox_inventory
ensure LC_consumables
ensure LC_itemcreator
```

設定したフレームワークだけを起動してください。

5. 権限を持つプレイヤーがゲーム内で`/itemcreator`を実行します。

旧ng-itemcreatorの`ng-itemcreator:client:openItemUi`イベントも、新UIを開く互換入口として利用できます。

カテゴリーで「アルコール」を選択すると、アルコール加算値と過剰摂取ダメージの設定欄が表示されます。参考値としてqbx_consumablesのビールは`0.25`です。作成した値は即時にLC_consumablesへ反映され、死亡・ラストスタンド・ログアウト時に蓄積と酔い効果がリセットされます。

使用時間は`LC_consumables/config/shared.lua`のアニメーション設定で固定し、`LC_itemcreator`の利用者には表示しません。Prop一覧は選択中のアニメーションに対応するものだけへ自動で切り替わります。Propを追加する場合は、`LC_consumables`側の`config/shared.lua`と`config/client.lua`へ同じキーで登録してください。

賞味期限は`config/shared.lua`の`expiration.options`に登録したプリセットから選択します。`defaultMinutes`には、新規作成時に選択するプリセットの分数を指定してください。「期限切れ時に自動削除」をOFFにしても賞味期限は進行し、期限切れアイテムは所持品に残りますが使用できません。期限を無効にする場合は「賞味期限なし」を選択します。

カテゴリー、カテゴリーごとの許可アニメーション、アニメーションごとのPropは`LC_consumables`を正本として取得します。カテゴリーを変更すると対応するアニメーションだけに一覧が切り替わり、不正な組み合わせは`LC_itemcreator`と`LC_consumables`の両サーバーで拒否されます。

## 素材Pと重量

`config/server.lua`の`materials`で、素材ごとの表示名・素材P・重量・アイコンを設定できます。ng-itemcreatorと同様に、同じ素材は1種類につき1個だけ投入できます。消費アイテムの完成重量は選択素材の重量合計から自動計算され、使用Pが素材Pを超える定義はサーバー側で保存を拒否します。

使用PはHunger / Thirst / Stressの絶対値を合算します。アルコール商品では、これに`alcoholLevel × alcoholMultiplier`を加算します。既定値では`alcoholLevel = 0.25`が5Pです。換算率や各ステータスの消費率は`materialPoints`から変更できます。体力・アーマー効果と使用後返却アイテムは、飲食店ジョブ向けUIから登録できません。

どちらのフレームワークでも`ox_inventory/data/items.lua`をアイテム定義の正本にします。作成直後のアイテムを`QBCore.Shared.Items`から検索する旧QBリソースには即時同期されないため、新規のクラフト・消費処理はox_inventory exportを使用してください。

## フレームワーク互換性

- `SharedConfig.framework = 'qbx_core'`ではQboxのプレイヤー取得exportを使用します。
- `SharedConfig.framework = 'qb-core'`では`QBCore.Functions.GetPlayer`を使用します。
- 設定したフレームワークが起動していない場合や未対応の値の場合は、誤動作を避けるためリソース起動時に英語エラーを出して停止します。
- フレームワークを変更した場合は`LC_consumables`と`LC_itemcreator`の両方を再起動してください。

## ジョブ管理とアイテム名

一覧・新規作成・編集・有効化・削除は、プレイヤーが現在管理している1ジョブに限定されます。ACE管理者権限は許可ジョブ外から開くための代替権限としてだけ使用され、他ジョブの登録内容を一覧・編集する権限にはなりません。

アイテム名は`ジョブ名_`を変更できないPrefixとして表示し、利用者が入力する部分には半角小文字の英字と数字だけを使用できます。サーバー側でも同じ規則と所有ジョブを再検証します。

## 無効化と削除

無効化するとアイテム定義は残したまま、消費処理とレシピだけを停止できます。完全削除は無効化済みアイテムだけに許可され、確認後にDB、ox_inventoryの管理領域、LC_consumables登録、互換レシピから削除されます。所持中の同名アイテムには現在のランタイムだけ「削除済み」の安全な定義を保持するため、使用はできませんが、別スロットへの移動や地面へのドロップでox_inventoryエラーは発生しません。`items.lua`には残らず、サーバーまたはox_inventoryの再起動後に所持品から除外されます。削除前に必要な回収を行ってください。反映に失敗した場合はDBと定義を復元します。

## DB保存方針

アイテムはジョブ単位で管理し、個人識別情報や操作監査ログは保存しません。`revision`はDB通信を追加せず、同じジョブの複数人が同一アイテムを同時編集した場合の上書き防止にだけ使用します。画面上には表示されません。

旧バージョンの`owner_identifier`カラムと`lc_itemcreator_audit`テーブルを削除する自動マイグレーションは行いません。旧DBを使用している場合は、管理者が既存の`lc_itemcreator_items`・`lc_itemcreator_audit`を手動削除してからリソースを起動してください。

## レシピ互換

`recipeCompatibility.enabled = true`の場合、従来の`item_recipes`テーブルへ素材名を同期し、以下の既存イベントを発火します。

- `LC_foodcraft:notifyRecipeAddedOrUpdated`
- `LC_foodcraft:notifyRecipeDeleted`

新しい数量付き形式は`GetRecipe` / `GetAllRecipes` exportの`material_data`から取得できます。旧小文字export名も利用できます。

## セキュリティ

- 権限、所有ジョブ、接頭辞、効果値、素材、素材P上限、画像URLをすべてサーバー側で検証します。
- 管理者権限を持つプレイヤーでも、現在の管理ジョブ以外は閲覧・変更できません。
- 任意のLuaコードやexport名はUIから登録できません。
- 画像を外部からダウンロードしません。
- 自動インストールは既定OFFで、ox_inventory以外へ書き込みません。

## 配布時の注意

内部仕様書はリソースフォルダ外に配置しており、このフォルダを配布用にzip化しても仕様書は含まれません。
