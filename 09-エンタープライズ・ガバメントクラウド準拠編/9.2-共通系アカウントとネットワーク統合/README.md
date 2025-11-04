# 9.2 共通系アカウントとネットワーク統合

## 🎯 このセクションで学ぶこと

**Transit Gateway を使ったマルチアカウント間のネットワーク統合**と、**共通系アカウントでの集約管理**を実践します。

### 学習目標

- 共通系アカウントの設計思想を理解する
- Transit Gateway の基礎と活用方法を学ぶ
- マルチアカウント間のVPC接続を実装する
- Direct Connect によるオンプレミス接続の基礎を学ぶ
- セキュリティ・ログ管理の集約を実装する

**学習時間**: 120分

## 🏗️ 共通系アカウントの設計思想

### なぜ共通系アカウントが必要か

```yaml
課題: マルチアカウント環境での管理の複雑さ
  - 各アカウントで個別にセキュリティ設定
  - 各アカウントで個別にログ管理
  - アカウント間のネットワーク接続が煩雑
  - オンプレミスとの接続が重複

解決: 共通系アカウントで集約管理
  - セキュリティ監視を一元化
  - ログを一箇所に集約
  - ネットワークハブとして機能
  - オンプレミス接続を共有
```

### 共通系アカウントの役割

```
┌─────────────────────────────────────────────────────────┐
│          Shared Account (共通系アカウント)              │
│                                                         │
│  ┌─────────────────┐  ┌─────────────────┐             │
│  │  Security Hub   │  │  GuardDuty      │             │
│  │  (セキュリティ)  │  │  (脅威検知)     │             │
│  └─────────────────┘  └─────────────────┘             │
│                                                         │
│  ┌─────────────────┐  ┌─────────────────┐             │
│  │  CloudTrail     │  │  CloudWatch     │             │
│  │  (監査ログ)      │  │  Logs (集約)    │             │
│  └─────────────────┘  └─────────────────┘             │
│                                                         │
│  ┌────────────────────────────────────┐                │
│  │       Transit Gateway              │                │
│  │       (ネットワークハブ)            │                │
│  │                                    │                │
│  │  ┌──────┐  ┌──────┐  ┌──────┐     │                │
│  │  │VPC A │  │VPC B │  │VPC C │     │                │
│  │  │      ├──┤      ├──┤      │     │                │
│  │  └──────┘  └──────┘  └──────┘     │                │
│  │       │                            │                │
│  │       └── Direct Connect ──→ オンプレ │              │
│  └────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────┘
```

### 機能別の責務

#### 1. セキュリティ管理

```yaml
実装内容:
  - Security Hub: 全アカウントのセキュリティ状況を可視化
  - GuardDuty: 全アカウントの脅威検知
  - Config: コンプライアンスチェック
  - IAM Access Analyzer: 外部アクセスの検出

メリット:
  - セキュリティチームの負荷軽減
  - 一貫したセキュリティポリシー適用
  - インシデント対応の迅速化
```

#### 2. ログ管理

```yaml
実装内容:
  - CloudTrail: 全アカウントのAPIコールログ
  - CloudWatch Logs: アプリケーションログ集約
  - VPC Flow Logs: ネットワークトラフィックログ
  - S3: ログの長期保存

メリット:
  - ログの検索・分析が容易
  - 監査対応が簡単
  - ストレージコストの最適化
```

#### 3. ネットワークハブ

```yaml
実装内容:
  - Transit Gateway: VPC間接続
  - Direct Connect Gateway: オンプレミス接続
  - Route 53 Resolver: DNS統合

メリット:
  - シンプルなネットワークトポロジー
  - スケーラブルな接続管理
  - オンプレミス接続の共有
```

## 🌐 Transit Gateway の基礎

### Transit Gateway とは

```
従来のVPC Peering:
┌─────┐    ┌─────┐
│VPC A├────┤VPC B│
└──┬──┘    └──┬──┘
   │          │
   └────┬─────┘
     ┌──▼──┐
     │VPC C│
     └─────┘

問題: N個のVPCを接続するには N×(N-1)/2 のPeering接続が必要
例: 10個のVPC → 45個のPeering接続
```

```
Transit Gateway:
        ┌─────────────┐
        │   Transit   │
        │   Gateway   │
        └─────────────┘
              │
    ┌─────────┼─────────┐
    │         │         │
┌───▼──┐  ┌──▼───┐  ┌──▼───┐
│VPC A │  │VPC B │  │VPC C │
└──────┘  └──────┘  └──────┘

メリット: N個のVPCでも N個のアタッチメントのみ
例: 10個のVPC → 10個のアタッチメント
```

### Transit Gateway の主要概念

#### 1. Attachments (アタッチメント)

```yaml
種類:
  - VPC Attachment: VPCを接続
  - VPN Attachment: VPN接続
  - Direct Connect Gateway Attachment: DC接続
  - Peering Attachment: 別リージョンのTGW接続

料金:
  - アタッチメント: $36/月
  - データ転送: $0.02/GB
```

#### 2. Route Tables (ルートテーブル)

```yaml
機能:
  - アタッチメント間のルーティング制御
  - セグメント分離（本番と開発の分離など）
  - ブラックホールルート（特定通信の遮断）

設計パターン:
  - Single Route Table: すべて相互接続
  - Segmented Route Tables: 環境別に分離
  - Isolated Route Tables: 完全分離
```

#### 3. Route Propagation (ルート伝播)

```yaml
機能:
  - VPCのCIDRを自動的にTGWルートテーブルに追加
  - 手動ルート追加の手間を削減

設定:
  - Propagation: 有効/無効
  - Static Routes: 手動追加ルート
```

## 📋 ハンズオン: Transit Gateway 構築

### アーキテクチャ

```
┌─────────────────── Shared Account ──────────────────────┐
│                                                          │
│  ┌─────────────── Transit Gateway ───────────────┐      │
│  │                                                │      │
│  │  Shared VPC (10.0.0.0/16)                     │      │
│  │  - セキュリティツール配置                      │      │
│  │  - 監視ツール配置                              │      │
│  │                                                │      │
│  └────────┬──────────────────────┬────────────────┘      │
│           │                      │                       │
└───────────┼──────────────────────┼───────────────────────┘
            │                      │
┌───────────▼───── App1 Account    │
│                                  │
│  App1 VPC (10.1.0.0/16)         │
│  - Application                   │
│  - Database                      │
│                                  │
└──────────────────────────────────┘
                                   │
┌──────────────────────────────────▼─ App2 Account
│
│  App2 VPC (10.2.0.0/16)
│  - Application
│  - Database
│
└──────────────────────────────────
```

### 前提条件

```bash
# 9.1で作成した環境
# - Management Account
# - Shared Account
# - OU構成

# 追加で必要なもの
# - Service Account（App1用）の作成
```

### Step 1: VPC の作成（各アカウント）

#### Shared Account での VPC 作成

```bash
# Shared Accountに切り替え（9.1で設定したAssumeRole）
# または、Shared AccountのAWS CLIプロファイルを使用

# CloudFormationスタック作成
cd cloudformation

aws cloudformation create-stack \
  --stack-name shared-vpc \
  --template-body file://shared-vpc.yaml \
  --parameters \
    ParameterKey=VpcCidr,ParameterValue=10.0.0.0/16 \
    ParameterKey=AvailabilityZone1,ParameterValue=ap-northeast-1a \
    ParameterKey=AvailabilityZone2,ParameterValue=ap-northeast-1c \
  --capabilities CAPABILITY_IAM

# スタック作成完了まで待機
aws cloudformation wait stack-create-complete \
  --stack-name shared-vpc

# VPC IDの取得
SHARED_VPC_ID=$(aws cloudformation describe-stacks \
  --stack-name shared-vpc \
  --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' \
  --output text)

echo "Shared VPC ID: $SHARED_VPC_ID"
```

#### App1 Account での VPC 作成

```bash
# App1 Accountに切り替え
# (AssumeRoleまたはプロファイル切り替え)

aws cloudformation create-stack \
  --stack-name app1-vpc \
  --template-body file://app-vpc.yaml \
  --parameters \
    ParameterKey=VpcCidr,ParameterValue=10.1.0.0/16 \
    ParameterKey=AvailabilityZone1,ParameterValue=ap-northeast-1a \
    ParameterKey=AvailabilityZone2,ParameterValue=ap-northeast-1c \
  --capabilities CAPABILITY_IAM

aws cloudformation wait stack-create-complete \
  --stack-name app1-vpc

APP1_VPC_ID=$(aws cloudformation describe-stacks \
  --stack-name app1-vpc \
  --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' \
  --output text)

echo "App1 VPC ID: $APP1_VPC_ID"
```

### Step 2: Transit Gateway の作成

```bash
# Shared Accountに切り替え

aws cloudformation create-stack \
  --stack-name transit-gateway \
  --template-body file://transit-gateway.yaml \
  --parameters \
    ParameterKey=AmazonSideAsn,ParameterValue=64512 \
  --capabilities CAPABILITY_IAM

aws cloudformation wait stack-create-complete \
  --stack-name transit-gateway

TGW_ID=$(aws cloudformation describe-stacks \
  --stack-name transit-gateway \
  --query 'Stacks[0].Outputs[?OutputKey==`TransitGatewayId`].OutputValue' \
  --output text)

echo "Transit Gateway ID: $TGW_ID"

# TGW IDを保存
echo "export TGW_ID=$TGW_ID" > tgw-id.env
```

### Step 3: VPC Attachments の作成

#### Shared VPC のアタッチメント

```bash
# Shared Account

aws cloudformation create-stack \
  --stack-name shared-tgw-attachment \
  --template-body file://tgw-attachment.yaml \
  --parameters \
    ParameterKey=TransitGatewayId,ParameterValue=$TGW_ID \
    ParameterKey=VpcId,ParameterValue=$SHARED_VPC_ID \
    ParameterKey=SubnetIds,ParameterValue="subnet-xxx,subnet-yyy" \
  --capabilities CAPABILITY_IAM

# 作成完了まで待機
aws cloudformation wait stack-create-complete \
  --stack-name shared-tgw-attachment
```

#### App1 VPC のアタッチメント（クロスアカウント）

```bash
# Step 3-1: Shared AccountでリソースシェアAを作成
# (App1 AccountにTGWを共有)

aws ram create-resource-share \
  --name "TGW-Share-App1" \
  --resource-arns "arn:aws:ec2:ap-northeast-1:${SHARED_ACCOUNT_ID}:transit-gateway/${TGW_ID}" \
  --principals "arn:aws:organizations::${MGMT_ACCOUNT_ID}:account/${APP1_ACCOUNT_ID}"

# Step 3-2: App1 Accountで招待を承認
# (App1 Accountに切り替え)

INVITATION_ARN=$(aws ram get-resource-share-invitations \
  --query 'resourceShareInvitations[0].resourceShareInvitationArn' \
  --output text)

aws ram accept-resource-share-invitation \
  --resource-share-invitation-arn $INVITATION_ARN

# Step 3-3: App1 AccountでVPC Attachmentを作成

aws cloudformation create-stack \
  --stack-name app1-tgw-attachment \
  --template-body file://tgw-attachment.yaml \
  --parameters \
    ParameterKey=TransitGatewayId,ParameterValue=$TGW_ID \
    ParameterKey=VpcId,ParameterValue=$APP1_VPC_ID \
    ParameterKey=SubnetIds,ParameterValue="subnet-aaa,subnet-bbb" \
  --capabilities CAPABILITY_IAM
```

### Step 4: ルート設定

```bash
# Shared Account: TGWルートテーブルの設定

# Attachmentの承認（クロスアカウントの場合）
TGW_ATTACHMENT_ID=$(aws ec2 describe-transit-gateway-attachments \
  --filters "Name=resource-id,Values=$APP1_VPC_ID" \
  --query 'TransitGatewayAttachments[0].TransitGatewayAttachmentId' \
  --output text)

aws ec2 accept-transit-gateway-vpc-attachment \
  --transit-gateway-attachment-id $TGW_ATTACHMENT_ID

# ルートの伝播を有効化
TGW_RT_ID=$(aws ec2 describe-transit-gateways \
  --transit-gateway-ids $TGW_ID \
  --query 'TransitGateways[0].Options.AssociationDefaultRouteTableId' \
  --output text)

aws ec2 enable-transit-gateway-route-table-propagation \
  --transit-gateway-route-table-id $TGW_RT_ID \
  --transit-gateway-attachment-id $TGW_ATTACHMENT_ID

# VPCルートテーブルの更新（Shared VPC）
SHARED_RT_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$SHARED_VPC_ID" "Name=tag:Name,Values=*Private*" \
  --query 'RouteTables[0].RouteTableId' \
  --output text)

aws ec2 create-route \
  --route-table-id $SHARED_RT_ID \
  --destination-cidr-block 10.1.0.0/16 \
  --transit-gateway-id $TGW_ID

# App1 VPC側も同様にルート追加
# (App1 Accountに切り替え)
APP1_RT_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$APP1_VPC_ID" "Name=tag:Name,Values=*Private*" \
  --query 'RouteTables[0].RouteTableId' \
  --output text)

aws ec2 create-route \
  --route-table-id $APP1_RT_ID \
  --destination-cidr-block 10.0.0.0/16 \
  --transit-gateway-id $TGW_ID
```

### Step 5: 接続確認

```bash
# Shared VPC内のEC2インスタンスから
# App1 VPC内のEC2インスタンスへpingテスト

# App1のプライベートIPを確認
APP1_PRIVATE_IP="10.1.1.10"  # 例

# Shared VPCのインスタンスにSSH接続して
ping $APP1_PRIVATE_IP

# 成功すれば、Transit Gateway経由で通信できている
```

## 🔗 Direct Connect 接続（概要）

### Direct Connect とは

```yaml
定義:
  AWSとオンプレミス間の専用線接続

メリット:
  - 安定した帯域
  - レイテンシの削減
  - インターネット経由より安全
  - データ転送コストの削減

料金:
  - ポート料金: $0.30/時間（1Gbps）
  - データ転送（アウト）: $0.024/GB
```

### 💡 ガバメントクラウドでの実装

GCAS環境では、閉域接続が標準です：

```yaml
ネットワーク構成:
  接続方式:
    - Direct Connect（専用線）
    - Transit Gateway経由でVPC接続
    - 閉域ネットワークで完結

重要な設計ポイント:
  - CIDR重複を避ける
    → 異なるVPCやオンプレで同じIPアドレス範囲は使えない
    → 必要に応じてNAT変換

  - Transit Gateway共有
    → Resource Access Managerでアカウント間共有
    → ネットワークアカウントで一元管理

参考: [GCAS ネットワーク接続方法](https://guide.gcas.cloud.go.jp/aws/how-to-connect-network)
```

### Transit Gateway との統合

```
オンプレミス
    │
    │ Direct Connect (1Gbps)
    │
    ▼
┌─────────────────┐
│  Direct Connect │
│   Gateway       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Transit Gateway │  ◄──── Shared Account
└────────┬────────┘
         │
    ┌────┼────┐
    │    │    │
  VPC1 VPC2 VPC3  ◄──── 各Service Account

メリット:
  - 1つのDirect Connectで全VPCに接続
  - コスト効率的
  - 管理が簡単
```

### 構築手順（概要）

```bash
# 1. Direct Connect接続の作成（AWS管理コンソール）
# 2. Virtual Interface (VIF) の作成
# 3. Direct Connect Gateway の作成

aws directconnect create-direct-connect-gateway \
  --direct-connect-gateway-name "MyDCGateway" \
  --amazon-side-asn 64512

# 4. Transit Gateway への関連付け

DCGW_ID="<Direct-Connect-Gateway-ID>"

aws directconnect create-direct-connect-gateway-association \
  --direct-connect-gateway-id $DCGW_ID \
  --gateway-id $TGW_ID \
  --add-allowed-prefixes cidr=10.0.0.0/8

# 5. オンプレミス側ルーター設定（BGP）
```

## 💰 コスト

### このセクションのコスト

```yaml
Transit Gateway:
  - TGW本体: 無料
  - VPC Attachment × 3: $36 × 3 = $108/月
  - データ転送: $0.02/GB

Direct Connect（オプション）:
  - ポート（1Gbps）: $0.30/h = $216/月
  - データ転送: $0.024/GB

学習環境の月額: 約$108-150/月
```

## 📝 まとめ

### 学んだこと

- ✅ 共通系アカウントの設計思想
- ✅ Transit Gateway の基礎と実装
- ✅ マルチアカウント間のネットワーク統合
- ✅ クロスアカウント VPC Attachment
- ✅ Direct Connect 接続の概要

### 次のステップ

**[9.3 ISMAP・ガバメントクラウド準拠要件](../9.3-ISMAPガバメントクラウド準拠要件/README.md)** に進んで、セキュリティとコンプライアンス要件を学びます。

## 📚 参考資料

- [AWS Transit Gateway](https://docs.aws.amazon.com/vpc/latest/tgw/)
- [AWS Direct Connect](https://docs.aws.amazon.com/directconnect/)
- [RAM (Resource Access Manager)](https://docs.aws.amazon.com/ram/)

---

**次へ**: [9.3 ISMAP・ガバメントクラウド準拠要件](../9.3-ISMAPガバメントクラウド準拠要件/README.md)
