# ox_inventoryブリッジ導入手順

リアルタイム反映には、ox_inventoryのサーバー・クライアント双方の内部アイテム一覧を安全に更新するブリッジが必要です。

## 手動導入（推奨）

1. `installation/ox_inventory/lc_itemcreator_bridge.lua`を`ox_inventory/`直下へコピーします。
2. `installation/ox_inventory/lc_itemcreator_bridge.client.lua`を`ox_inventory/`直下へコピーします。
3. `ox_inventory/fxmanifest.lua`の末尾へ以下を追加します。

```lua
-- LC_ITEMCREATOR_INTEGRATION_BEGIN
server_script 'lc_itemcreator_bridge.lua'
client_script 'lc_itemcreator_bridge.client.lua'
-- LC_ITEMCREATOR_INTEGRATION_END
```

4. 初回だけサーバーを再起動するか、メンテナンス中に`restart ox_inventory`を実行します。

以後、LC_itemcreatorで作成・更新したアイテムは再起動なしで反映されます。

## 自動導入

`config/server.lua`の`autoInstall`を`true`にすると、上記のコピーとmanifest追記を一度だけ試行します。既定値は安全のため`false`です。

- 既存ファイルは上書きしません。
- 同じmanifestマーカーを二重追加しません。
- 書き込みに失敗した場合は、この手動手順へ誘導します。
- 外部通信、テレメトリ、認証情報収集はありません。

ox_inventory更新でフォルダが置き換わった場合は、再度この手順を実施してください。
