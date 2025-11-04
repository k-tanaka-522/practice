# 9.1 単一→マルチアカウント移行の考え方

## 🎯 このセクションで学ぶこと

**なぜマルチアカウント構成が実務で必要なのか**を理解し、AWS Organizations を使った基本的なマルチアカウント環境を構築します。

### 学習目標

- 単一アカウントの限界と課題を理解する
- マルチアカウント戦略の利点を体験する
- AWS Organizations の基礎を学ぶ
- アカウント分離戦略（アプリ別、環境別）を理解する
- 実際にマルチアカウント環境を構築する

**学習時間**: 90分

## 📚 なぜ01-08編は単一アカウントだったのか

### 学習と実務の違い

```yaml
01-08編（学習フェーズ）:
  目的: AWSサービスの基本を理解する
  重視: 迅速な理解と実装
  構成: 単一アカウント
  理由:
    - セットアップが簡単
    - アカウント管理の複雑さを避ける
    - サービスそのものの学習に集中
    - 初心者でも理解しやすい

実務（このセクション以降）:
  目的: 本番環境で運用できるシステムを構築
  重視: セキュリティ、運用性、スケーラビリティ
  構成: マルチアカウント
  理由:
    - セキュリティ境界の明確化
    - 障害の影響範囲の限定
    - コスト配分の明確化
    - 権限管理の簡素化
```

## 🚫 単一アカウントの限界

### 実務で直面する課題

#### 1. セキュリティ境界が曖昧

```
単一アカウントの場合:
┌─────────────────────────────────────┐
│     Single AWS Account              │
│                                     │
│  開発環境  ステージング  本番環境    │
│     ↓          ↓         ↓         │
│  全て同じアカウント内に存在         │
│                                     │
│  問題:                              │
│  - 開発者が本番リソースを見れる     │
│  - 誤操作で本番に影響する可能性     │
│  - セキュリティ設定が複雑化         │
└─────────────────────────────────────┘
```

#### 2. 障害の影響範囲が広い

```
例: IAM設定ミス
  → 単一アカウント: 全環境が影響を受ける
  → マルチアカウント: 影響は1アカウントに限定

例: リソース制限到達
  → 単一アカウント: 全環境でリソース作成不可
  → マルチアカウント: 他のアカウントは影響なし
```

#### 3. コスト配分が困難

```
単一アカウントの請求:
  総額: $10,000/月

  内訳がわからない:
  - どのプロジェクトでいくら使ったか？
  - 開発環境と本番環境の比率は？
  - どのチームが予算超過している？

  → タグで分類しても限界がある
```

#### 4. 権限管理が複雑化

```yaml
単一アカウントでの権限管理:
  開発者A:
    - 開発環境: フルアクセス必要
    - ステージング: 読み取りのみ
    - 本番: アクセス不要

  → 複雑なIAMポリシーが必要
  → ポリシーの数が膨大になる
  → ミスが発生しやすい
```

## ✅ マルチアカウントの利点

### 実務で得られるメリット

```
┌─────────────────────────────────────────────────────────┐
│           AWS Organizations                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │   Shared    │  │  Dev Account│  │ Prod Account│    │
│  │  Account    │  │             │  │             │    │
│  │             │  │             │  │             │    │
│  │ - Security  │  │ - App1 Dev  │  │ - App1 Prod │    │
│  │ - Logs      │  │ - Testing   │  │ - 本番運用  │    │
│  │ - Network   │  │             │  │             │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
│                                                         │
│  利点:                                                  │
│  ✅ 完全に分離されたセキュリティ境界                    │
│  ✅ 障害の影響は1アカウントに限定                       │
│  ✅ アカウント単位で明確なコスト配分                    │
│  ✅ シンプルな権限管理                                  │
└─────────────────────────────────────────────────────────┘
```

### 具体的なメリット

#### 1. セキュリティの向上

```yaml
アカウント分離による保護:
  - 本番環境は独立したアカウント
  - 開発者は本番アカウントにアクセスできない
  - クロスアカウントロールで必要最小限のアクセス
  - セキュリティ監視は共通系アカウントで集約
```

#### 2. 障害の影響を最小化

```yaml
障害の封じ込め:
  - App1で障害発生 → App2は影響なし
  - 開発環境で負荷テスト → 本番は影響なし
  - リソース制限到達 → 他アカウントは正常動作
```

#### 3. 明確なコスト配分

```yaml
アカウント別請求:
  - Dev Account: $1,000/月
  - Staging Account: $2,000/月
  - Prod Account: $7,000/月
  - Shared Account: $500/月

  → 一目瞭然！
```

#### 4. シンプルな権限管理

```yaml
アカウント単位の権限:
  - 開発者: Devアカウントの管理者
  - SRE: 全アカウントへのアクセス（AssumeRole）
  - 監査チーム: 読み取り専用アクセス

  → IAMポリシーがシンプルに！
```

## 🏗️ マルチアカウント戦略

### 推奨アカウント構成

```
┌─────────────────────────────────────────────────────────┐
│              Management Account                         │
│          (Organizations 管理専用)                       │
│                                                         │
│  - アカウント作成・削除                                 │
│  - 組織ポリシー管理                                     │
│  - 請求の集約                                           │
│  - ⚠️ ワークロードは配置しない                         │
└─────────────────────────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
┌───────▼──────┐ ┌──────▼──────┐ ┌─────▼────────┐
│   Shared     │ │   Service   │ │  Service     │
│   Account    │ │   Account 1 │ │  Account 2   │
│              │ │             │ │              │
│ - Security   │ │ - App1 Dev  │ │ - App2 Dev   │
│ - Logging    │ │ - App1 Stg  │ │ - App2 Stg   │
│ - Network    │ │ - App1 Prod │ │ - App2 Prod  │
│ - Monitoring │ │             │ │              │
└──────────────┘ └─────────────┘ └──────────────┘
```

### アカウント分離の考え方

#### パターン1: アプリケーション別

```yaml
適用ケース: 複数のアプリケーションを運用
構成:
  - App1 Account: 顧客管理システム
  - App2 Account: 在庫管理システム
  - App3 Account: 分析基盤

メリット:
  - アプリ間の完全分離
  - 独立したライフサイクル管理
  - コスト配分が明確
```

#### パターン2: 環境別

```yaml
適用ケース: 1つのアプリケーションで複数環境
構成:
  - Dev Account: 開発環境
  - Staging Account: ステージング環境
  - Prod Account: 本番環境

メリット:
  - 環境間の完全分離
  - 本番環境の保護
  - テスト環境での自由な実験
```

#### パターン3: ハイブリッド（推奨）

```yaml
適用ケース: 複数アプリ × 複数環境
構成:
  - Shared Account: 共通インフラ
  - App1-Prod Account: App1本番
  - App1-NonProd Account: App1開発・ステージング
  - App2-Prod Account: App2本番
  - App2-NonProd Account: App2開発・ステージング

メリット:
  - 本番環境の厳格な分離
  - 開発環境でのコスト最適化
  - 柔軟な運用
```

## 🛠️ AWS Organizations の基礎

### Organizations とは

AWS Organizations は、複数のAWSアカウントを一元管理するサービスです。

```
主要機能:
  1. アカウントの作成・管理
  2. 請求の統合（一括支払い）
  3. Service Control Policies (SCP) による制御
  4. アカウントのグループ化（OU: Organizational Unit）
```

### 💡 ガバメントクラウドでの実装

GCAS（ガバメントクラウド）では、以下の構成が標準です：

```yaml
デジタル庁による管理:
  - デジタル庁がOrganizationsを管理
  - 各府省・自治体はメンバーアカウント
  - デジタル庁が発行したOUに紐づく

セキュリティ制御:
  - SCPでセキュリティ違反操作を制限
  - 統一されたポリシー適用
  - コンプライアンス自動チェック
```

参考: [GCAS アカウント構造説明](https://guide.gcas.cloud.go.jp/aws/description-of-account-structure/)

### 組織構造の設計

```
Root (ルート)
│
├── Management OU
│   └── Management Account
│
├── Security OU
│   ├── Shared Account (セキュリティ・ログ)
│   └── Audit Account (監査専用)
│
├── Infrastructure OU
│   └── Network Account (ネットワークハブ)
│
├── Production OU
│   ├── App1-Prod Account
│   └── App2-Prod Account
│
└── Non-Production OU
    ├── App1-Dev Account
    ├── App2-Dev Account
    └── Sandbox Account
```

### Service Control Policies (SCP)

組織全体またはOU単位でのアクセス制御

```yaml
例: 本番環境での制限
Production OU に適用:
  - リージョン制限: ap-northeast-1 のみ許可
  - ルートユーザー使用禁止
  - CloudTrail 無効化禁止
  - 特定のインスタンスタイプのみ許可

例: 開発環境での制限
Non-Production OU に適用:
  - 高額インスタンスの起動禁止
  - 深夜帯のリソース起動禁止（コスト削減）
```

## 📋 ハンズオン: マルチアカウント環境構築

### 前提条件

```bash
# AWS CLI 設定確認
aws --version
aws sts get-caller-identity

# Organizations 管理権限が必要
# または、ルートアカウントでの作業
```

### Step 1: AWS Organizations の有効化

```bash
# Organizations を有効化
aws organizations create-organization \
  --feature-set ALL

# 組織情報の確認
aws organizations describe-organization
```

### Step 2: Organizational Unit (OU) の作成

```bash
# ルートIDの取得
ROOT_ID=$(aws organizations list-roots --query 'Roots[0].Id' --output text)

# Security OU 作成
SECURITY_OU_ID=$(aws organizations create-organizational-unit \
  --parent-id $ROOT_ID \
  --name Security \
  --query 'OrganizationalUnit.Id' \
  --output text)

# Production OU 作成
PROD_OU_ID=$(aws organizations create-organizational-unit \
  --parent-id $ROOT_ID \
  --name Production \
  --query 'OrganizationalUnit.Id' \
  --output text)

# Non-Production OU 作成
NONPROD_OU_ID=$(aws organizations create-organizational-unit \
  --parent-id $ROOT_ID \
  --name Non-Production \
  --query 'OrganizationalUnit.Id' \
  --output text)

echo "Security OU: $SECURITY_OU_ID"
echo "Production OU: $PROD_OU_ID"
echo "Non-Production OU: $NONPROD_OU_ID"
```

### Step 3: 新しいアカウントの作成

```bash
# Shared Account 作成（Security OU配下）
aws organizations create-account \
  --email shared-account@example.com \
  --account-name "Shared Account" \
  --role-name OrganizationAccountAccessRole

# アカウント作成状況の確認
aws organizations list-create-account-status \
  --states IN_PROGRESS

# 作成完了まで待機（数分かかる）
# 完了後、アカウントIDを確認
SHARED_ACCOUNT_ID=$(aws organizations list-accounts \
  --query 'Accounts[?Name==`Shared Account`].Id' \
  --output text)

echo "Shared Account ID: $SHARED_ACCOUNT_ID"

# SharedアカウントをSecurity OUに移動
aws organizations move-account \
  --account-id $SHARED_ACCOUNT_ID \
  --source-parent-id $ROOT_ID \
  --destination-parent-id $SECURITY_OU_ID
```

### Step 4: Service Control Policy (SCP) の作成

```bash
# リージョン制限ポリシーの作成
cat > region-restriction-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "ap-northeast-1",
            "us-east-1"
          ]
        }
      }
    }
  ]
}
EOF

# SCPの作成
POLICY_ID=$(aws organizations create-policy \
  --content file://region-restriction-policy.json \
  --description "Allow only Tokyo and N.Virginia regions" \
  --name RegionRestriction \
  --type SERVICE_CONTROL_POLICY \
  --query 'Policy.PolicySummary.Id' \
  --output text)

# Production OUにポリシーを適用
aws organizations attach-policy \
  --policy-id $POLICY_ID \
  --target-id $PROD_OU_ID

echo "Region restriction policy attached to Production OU"
```

### Step 5: クロスアカウントロールの設定

```bash
# Shared Account への AssumeRole 設定
# Management Account から Shared Account にスイッチできるようにする

cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MANAGEMENT_ACCOUNT_ID:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "unique-external-id-12345"
        }
      }
    }
  ]
}
EOF

# Management Account ID を取得して置換
MGMT_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
sed -i "s/MANAGEMENT_ACCOUNT_ID/$MGMT_ACCOUNT_ID/g" trust-policy.json

echo "Cross-account role configuration prepared"
echo "Next: Apply this in the Shared Account"
```

## 📊 アーキテクチャ図

### 今回構築した環境

```
┌─────────────────────────────────────────────────────────┐
│           AWS Organizations                             │
│  ┌───────────────────────────────────────────────────┐  │
│  │        Management Account                         │  │
│  │        (既存のアカウント)                         │  │
│  └───────────────────────────────────────────────────┘  │
│                        │                                │
│       ┌────────────────┼────────────────┐               │
│       │                │                │               │
│  ┌────▼─────┐    ┌────▼──────┐   ┌────▼─────────┐    │
│  │ Security │    │Production │   │Non-Production│    │
│  │    OU    │    │    OU     │   │      OU      │    │
│  │          │    │           │   │              │    │
│  │ [Shared  │    │  (空)     │   │   (空)       │    │
│  │ Account] │    │           │   │              │    │
│  └──────────┘    └───────────┘   └──────────────┘    │
│                                                        │
│  SCP適用:                                              │
│  - Production OU: リージョン制限                       │
└────────────────────────────────────────────────────────┘
```

## 🔍 動作確認

### Organizations の確認

```bash
# 組織の詳細表示
aws organizations describe-organization

# すべてのアカウントを表示
aws organizations list-accounts

# OU の一覧表示
aws organizations list-organizational-units-for-parent \
  --parent-id $ROOT_ID

# SCP の確認
aws organizations list-policies \
  --filter SERVICE_CONTROL_POLICY
```

### クロスアカウントアクセスのテスト

```bash
# Shared Account にスイッチ
aws sts assume-role \
  --role-arn "arn:aws:iam::$SHARED_ACCOUNT_ID:role/OrganizationAccountAccessRole" \
  --role-session-name "test-session" \
  --external-id "unique-external-id-12345"

# 返却された一時クレデンシャルを使用
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."

# Shared Account で操作できることを確認
aws sts get-caller-identity
```

## 💰 コスト

### このセクションのコスト

```yaml
AWS Organizations: 無料
アカウント作成: 無料
SCP適用: 無料

総コスト: $0/月
```

## 📝 まとめ

### 学んだこと

- ✅ 単一アカウントの限界と課題
- ✅ マルチアカウント戦略の利点
- ✅ AWS Organizations の基礎
- ✅ OU（Organizational Unit）の設計
- ✅ Service Control Policies (SCP)
- ✅ クロスアカウントアクセス

### 次のステップ

**[9.2 共通系アカウントとネットワーク統合](../9.2-共通系アカウントとネットワーク統合/README.md)** に進んで、Transit Gateway によるネットワーク統合を学びます。

## 📚 参考資料

- [AWS Organizations 公式ドキュメント](https://docs.aws.amazon.com/organizations/)
- [AWS Multi-Account Strategy](https://aws.amazon.com/organizations/getting-started/best-practices/)
- [Service Control Policies](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)

## 🧹 クリーンアップ

学習完了後、不要なアカウントを削除する場合：

```bash
# アカウント削除（注意: 90日間の猶予期間あり）
aws organizations remove-account-from-organization \
  --account-id $SHARED_ACCOUNT_ID

# OU削除（アカウントが空の場合のみ）
aws organizations delete-organizational-unit \
  --organizational-unit-id $NONPROD_OU_ID

# Organizations自体の削除
aws organizations delete-organization
```

⚠️ **注意**: アカウント削除は慎重に行ってください。次のセクションで使用します。

---

**次へ**: [9.2 共通系アカウントとネットワーク統合](../9.2-共通系アカウントとネットワーク統合/README.md)
