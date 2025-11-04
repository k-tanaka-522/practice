# 9.3 ISMAP・ガバメントクラウド準拠要件

## 🎯 このセクションで学ぶこと

**AWS Well-Architected + 監査ログ要件**を実装します。

### 学習目標

- AWS Well-Architected セキュリティ柱の実践
- CloudTrail、Security Hub等の標準セキュリティサービス
- ISMAP準拠（= 監査ログをしっかり残す）
- 暗号化とアクセス制御（AWSベストプラクティス）

### 💡 重要なポイント

**ガバメントクラウド準拠 = AWSベストプラクティス + しっかり監査ログ**

特別なことはほとんどありません。普通のエンタープライズAWSのセキュリティです。

**学習時間**: 120分

## 🏛️ ガバメントクラウドとは

### 概要

```yaml
定義:
  政府情報システムの運用に適した
  クラウドサービス環境

目的:
  - システム運用の効率化
  - セキュリティの向上
  - コスト最適化
  - 標準化の推進

対象:
  - 国の行政機関
  - 地方自治体
  - 独立行政法人等
```

### 主要なクラウドサービス（2025年時点）

```yaml
認定事業者:
  - Amazon Web Services (AWS)
  - Google Cloud
  - Microsoft Azure
  - Oracle Cloud Infrastructure
  - さくらインターネット（さくらのクラウド）

特徴:
  - ISMAP登録済み
  - デジタル庁による一括調達
  - 政府標準セキュリティ要件を満たす
```

## 🔐 ISMAP（政府情報システムのためのセキュリティ評価制度）

### ISMAPとは

```yaml
正式名称:
  Information system Security Management
  and Assessment Program

目的:
  政府が求めるセキュリティ要求を
  満たすクラウドサービスの評価・登録

評価基準:
  - ISO/IEC 27017（クラウドセキュリティ）
  - 政府統一基準
  - ガバメントクラウド要件
```

### 機密性レベル

```yaml
レベル1（低）:
  - 公開情報
  - 影響度: 限定的
  - 例: 一般公開データ

レベル2（中）:
  - 機密性2情報
  - 影響度: 通常
  - 例: 個人情報（要配慮でない）

レベル3（高）★今回の対象:
  - 機密性3情報
  - 影響度: 重大
  - 例: マイナンバー、要配慮個人情報
```

## 📋 ISMAP機密性レベル3の主要要件

### 1. 監査ログ

```yaml
要件:
  必須:
    - すべてのAPIアクセスログ
    - 管理者操作ログ
    - 認証ログ
    - システムログ

  保存期間:
    - 最低1年間
    - 推奨3年間以上

  保護:
    - 改ざん防止
    - 削除防止
    - 暗号化保存
```

#### 実装: CloudTrail

```yaml
設定:
  - 全リージョンで有効化
  - 管理イベント: すべて記録
  - データイベント: S3/Lambda も記録
  - ログファイル検証: 有効
  - KMS暗号化: 有効
  - S3バケット:
      - バージョニング有効
      - MFA Delete有効
      - ライフサイクルポリシー設定
```

### 2. 暗号化

```yaml
保存時の暗号化:
  必須対象:
    - データベース（RDS, DynamoDB, DocumentDB）
    - ストレージ（S3, EBS, EFS）
    - バックアップ
    - スナップショット

  暗号化方式:
    - AES-256以上
    - AWS KMS推奨
    - カスタマーマスターキー（CMK）使用

転送時の暗号化:
  必須:
    - TLS 1.2以上
    - 古いプロトコル（SSL, TLS 1.0/1.1）無効化
```

### 3. アクセス制御

```yaml
IAM:
  - 最小権限の原則
  - MFA必須（特に管理者）
  - ルートユーザー使用禁止
  - アクセスキーの定期ローテーション
  - IAM Access Analyzer

ネットワーク:
  - プライベートサブネット活用
  - セキュリティグループ厳格化
  - NACLによる多層防御
  - VPC Flow Logs有効化

認証:
  - SSO推奨（AWS IAM Identity Center）
  - AD連携
  - 強力なパスワードポリシー
```

### 4. セキュリティ監視

```yaml
必須サービス:
  - GuardDuty: 脅威検知
  - Security Hub: セキュリティ状況の可視化
  - Config: コンプライアンスチェック
  - Inspector: 脆弱性評価

運用:
  - リアルタイム監視
  - アラート即時通知
  - インシデント対応手順
```

### 💡 ガバメントクラウドでのセキュリティ統制

GCAS環境では、2種類のセキュリティ統制が実装されています：

```yaml
1. 予防的統制（Preventive Controls）:
   目的: セキュリティ違反を事前に防ぐ
   実装:
     - Service Control Policies (SCP)
     - IAMポリシー制限
     - セキュリティグループ設定
     - リソース作成制限

   参考: [予防的統制内容説明](https://guide.gcas.cloud.go.jp/aws/description-of-preventive-controls)

2. 発見的統制（Detective Controls）:
   目的: セキュリティ問題を検知・監視
   実装:
     - CloudTrail（全操作ログ）
     - GuardDuty（脅威検知）
     - Security Hub（統合監視）
     - Config（コンプライアンス監視）

   参考: [発見的統制内容説明](https://guide.gcas.cloud.go.jp/aws/description-of-detective-controls)
```

### 5. バックアップと事業継続

```yaml
バックアップ:
  - 自動バックアップ有効
  - 複数リージョン保存
  - 定期リストアテスト

災害対策:
  - Multi-AZ構成
  - リージョン間レプリケーション（重要システム）
  - RTO/RPO定義と遵守
```

## 🛠️ ハンズオン: セキュリティ基盤構築

### Step 1: CloudTrail 全リージョン有効化

```bash
# CloudTrailの作成（Organization Trail）
aws cloudformation create-stack \
  --stack-name ismap-cloudtrail \
  --template-body file://cloudformation/cloudtrail-organization.yaml \
  --parameters \
    ParameterKey=LogBucketName,ParameterValue=org-cloudtrail-logs-${ACCOUNT_ID} \
    ParameterKey=EnableLogFileValidation,ParameterValue=true \
    ParameterKey=EnableKMSEncryption,ParameterValue=true \
  --capabilities CAPABILITY_IAM

# 完了待機
aws cloudformation wait stack-create-complete \
  --stack-name ismap-cloudtrail
```

### Step 2: Security Hub 有効化

```bash
# Security Hubの有効化
aws securityhub enable-security-hub \
  --enable-default-standards

# CIS AWS Foundations Benchmark 有効化
aws securityhub batch-enable-standards \
  --standards-subscription-requests StandardsArn=arn:aws:securityhub:ap-northeast-1::standards/cis-aws-foundations-benchmark/v/1.4.0

# GuardDutyの統合
aws guardduty create-detector \
  --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES

# Configの有効化
aws configservice put-configuration-recorder \
  --configuration-recorder name=default,roleARN=arn:aws:iam::${ACCOUNT_ID}:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig \
  --recording-group allSupported=true,includeGlobalResourceTypes=true

aws configservice put-delivery-channel \
  --delivery-channel name=default,s3BucketName=config-bucket-${ACCOUNT_ID}

aws configservice start-configuration-recorder \
  --configuration-recorder-name default
```

### Step 3: KMS カスタマーマスターキー作成

```bash
# CMKの作成
aws cloudformation create-stack \
  --stack-name ismap-kms \
  --template-body file://cloudformation/kms-cmk.yaml \
  --parameters \
    ParameterKey=KeyAdministrators,ParameterValue="arn:aws:iam::${ACCOUNT_ID}:user/admin" \
  --capabilities CAPABILITY_IAM

# Key IDの取得
KMS_KEY_ID=$(aws cloudformation describe-stacks \
  --stack-name ismap-kms \
  --query 'Stacks[0].Outputs[?OutputKey==`KeyId`].OutputValue' \
  --output text)

echo "KMS Key ID: $KMS_KEY_ID"
```

### Step 4: セキュリティベースライン適用

```bash
# セキュリティベースラインスタック
aws cloudformation create-stack \
  --stack-name ismap-security-baseline \
  --template-body file://cloudformation/security-baseline.yaml \
  --parameters \
    ParameterKey=RequireMFA,ParameterValue=true \
    ParameterKey=PasswordMinLength,ParameterValue=14 \
    ParameterKey=PasswordRequireSymbols,ParameterValue=true \
    ParameterKey=PasswordRequireNumbers,ParameterValue=true \
  --capabilities CAPABILITY_IAM
```

### Step 5: VPC Flow Logs 有効化

```bash
# すべてのVPCでFlow Logsを有効化
for VPC_ID in $(aws ec2 describe-vpcs --query 'Vpcs[*].VpcId' --output text); do
  aws ec2 create-flow-logs \
    --resource-type VPC \
    --resource-ids $VPC_ID \
    --traffic-type ALL \
    --log-destination-type cloud-watch-logs \
    --log-group-name "/aws/vpc/flowlogs/${VPC_ID}" \
    --deliver-logs-permission-arn "arn:aws:iam::${ACCOUNT_ID}:role/VPCFlowLogsRole"

  echo "Flow Logs enabled for VPC: $VPC_ID"
done
```

## 📊 コンプライアンスチェック

### AWS Config ルール

```yaml
推奨ルール:
  - cloudtrail-enabled
  - encrypted-volumes
  - rds-encryption-enabled
  - s3-bucket-public-read-prohibited
  - s3-bucket-public-write-prohibited
  - s3-bucket-ssl-requests-only
  - iam-password-policy
  - mfa-enabled-for-iam-console-access
  - root-account-mfa-enabled
```

### 自動修復

```bash
# Config Rulesの一括作成
aws cloudformation create-stack \
  --stack-name ismap-config-rules \
  --template-body file://cloudformation/config-rules.yaml \
  --capabilities CAPABILITY_IAM

# 自動修復の設定例（S3パブリックアクセスブロック）
aws configservice put-remediation-configurations \
  --remediation-configurations \
    ConfigRuleName=s3-bucket-public-read-prohibited,TargetType=SSM_DOCUMENT,TargetIdentifier=AWS-PublishSNSNotification,TargetVersion=1,Automatic=true
```

## 💰 コスト

```yaml
CloudTrail: $2/月（100,000イベント）
GuardDuty: $4.60/月（基本料金）
Security Hub: $0.0010/チェック
Config: $2/月（記録項目）
KMS: $1/月/CMK

ISMAP準拠の追加コスト: 約$20-50/月
```

## 📝 チェックリスト

### ISMAP機密性レベル3準拠

- [ ] CloudTrail 全リージョン有効化
- [ ] ログファイル検証有効化
- [ ] KMS暗号化（すべてのデータ）
- [ ] MFA必須化（管理者）
- [ ] Security Hub有効化
- [ ] GuardDuty有効化
- [ ] Config有効化
- [ ] VPC Flow Logs有効化
- [ ] IAM Access Analyzer
- [ ] パスワードポリシー強化
- [ ] バックアップ自動化
- [ ] Multi-AZ構成

## 📚 参考資料

### 🏛️ ガバメントクラウド公式ガイド（必読）
- **[GCAS AWS利用ガイド](https://guide.gcas.cloud.go.jp/aws)** ⭐最重要
  - デジタル庁公式のAWS利用ガイドライン
  - セキュリティ技術要件の詳細
  - ネットワーク設計、監査ログ、暗号化の実装指針
- [GCAS 全般的なガイド](https://guide.gcas.cloud.go.jp/)
- [ISMAP公式サイト](https://www.ipa.go.jp/security/ismap/)
- [政府情報システムのためのセキュリティ評価制度](https://www.nisc.go.jp/)

### 💡 活用のヒント
Claude Codeで実装を進める際は、以下のように指示すると効果的です：
```
「https://guide.gcas.cloud.go.jp/aws のガイドラインに準拠して、
 CloudTrailとSecurity Hubの設定を実装してください」
```

---

**次へ**: [9.4 実践ケーススタディ1: 役所設備管理システム](../9.4-実践ケーススタディ1-役所設備管理/README.md)
