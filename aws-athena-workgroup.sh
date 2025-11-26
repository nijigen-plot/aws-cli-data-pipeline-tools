#!/bin/bash

# ===============================================
# Athena ワークグループ設定抽出スクリプト
# 必要なもの: AWS CLI, jq (JSONプロセッサ)
# ===============================================

echo "--- 🛠️ Athena ワークグループ設定の確認を開始します ---"
echo ""

# jqがインストールされているか確認
if ! command -v jq &> /dev/null
then
    echo "❌ エラー: jq コマンドが見つかりません。インストールしてください。"
    echo "  (例: sudo apt install jq または brew install jq)"
    exit 1
fi

# list-work-groupsを実行し、すべてのワークグループ名を抽出
WORKGROUP_NAMES=$(aws athena list-work-groups --query 'WorkGroups[].Name' --output text)

if [ -z "$WORKGROUP_NAMES" ]; then
    echo "⚠️ ワークグループが見つかりませんでした。"
    exit 0
fi

# ヘッダーの出力
printf "%-30s | %-8s | %-60s | %-10s\n" "ワークグループ名" "状態" "S3結果出力先 (OutputLocation)" "暗号化"
printf "%s\n" "--------------------------------|----------|--------------------------------------------------------------|------------"

# 抽出した名前をループ処理
for WG_NAME in $WORKGROUP_NAMES; do
    # ワークグループの詳細情報を取得
    WG_INFO=$(aws athena get-work-group --work-group "$WG_NAME" --output json 2>/dev/null)

    # 必要な情報を jq で抽出
    STATE=$(echo "$WG_INFO" | jq -r '.WorkGroup.State')

    # Configurationが存在するか確認し、存在しなければ "-" を設定
    if echo "$WG_INFO" | jq -e '.WorkGroup.Configuration' &>/dev/null; then

        # S3 Output Location の抽出
        OUTPUT_LOCATION=$(echo "$WG_INFO" | jq -r '.WorkGroup.Configuration.ResultConfiguration.OutputLocation // "未設定"')

        # 暗号化オプションの抽出
        ENCRYPTION=$(echo "$WG_INFO" | jq -r '.WorkGroup.Configuration.ResultConfiguration.EncryptionConfiguration.EncryptionOption // "なし"')

    else
        OUTPUT_LOCATION="設定なし (Default使用)"
        ENCRYPTION="なし"
    fi

    # 結果の出力
    printf "%-30s | %-8s | %-60s | %-10s\n" "$WG_NAME" "$STATE" "$OUTPUT_LOCATION" "$ENCRYPTION"
done

echo ""
echo "--- ✅ 設定の抽出を完了しました ---"
