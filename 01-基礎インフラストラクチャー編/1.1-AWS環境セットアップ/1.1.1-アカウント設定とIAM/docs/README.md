# 1.1.1 アカウント設定とIAM

## 概要

このセクションでは、AWSアカウントのセキュアな設定とIAM（Identity and Access Management）による権限管理を学習します。セキュリティの基盤となる重要な設定を実装します。

## 学習目標

- 🔐 **IAMの基本概念**: ユーザー、グループ、ロール、ポリシー
- 🛡️ **セキュリティ設定**: パスワードポリシー、MFA、CloudTrail
- 📊 **監査とモニタリング**: ログ記録、アラート設定
- 🏗️ **Infrastructure as Code**: CloudFormationによる自動化

## IAM概念図

```
┌─────────────────────────────────────────────────────────┐
│                    AWS Account                          │
│                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │    Users    │    │   Groups    │    │    Roles    │  │
│  │             │───▶│             │    │             │  │
│  │  - Alice    │    │ - Admins    │    │ - EC2Role   │  │
│  │  - Bob      │    │ - Devs      │    │ - LambdaRole│  │
│  │  - Charlie  │    │ - ReadOnly  │    │ - CIRole    │  │
│  └─────────────┘    └─────────────┘    └─────────────┘  │
│          │                   │                   │      │
│          └───────────────────┼───────────────────┘      │
│                              ▼                          │
│                    ┌─────────────────┐                  │
│                    │    Policies     │                  │
│                    │                 │                  │
│                    │ - AdminAccess   │                  │
│                    │ - DeveloperRead │                  │
│                    │ - S3FullAccess  │                  │
│                    └─────────────────┘                  │
└─────────────────────────────────────────────────────────┘
```

## 実装アーキテクチャ

```
┌─────────────────────────────────────────────────────────┐
│                  Security Foundation                    │
│                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │ Password    │    │ CloudTrail  │    │ CloudWatch  │  │
│  │ Policy      │    │ Logging     │    │ Alarms      │  │
│  └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │ IAM Groups  │    │ Service     │    │ Cross-      │  │
│  │ & Policies  │    │ Roles       │    │ Account     │  │
│  └─────────────┘    └─────────────┘    └─────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 🚀 実装手順

### Step 1: 前提条件の確認

```bash
# AWS CLI バージョン確認
aws --version
# 2.13.0 以上が必要

# 現在のアカウント情報確認
aws sts get-caller-identity

# 管理者権限の確認
aws iam get-user
```

### Step 2: CloudFormationテンプレートのデプロイ

```bash
# プロジェクトディレクトリに移動
cd 01-基礎インフラストラクチャー編/1.1-AWS環境セットアップ/1.1.1-アカウント設定とIAM

# 全IAMリソースのデプロイ
aws cloudformation create-stack \
  --stack-name iam-foundation \
  --template-body file://cloudformation/master-stack.yaml \
  --parameters file://cloudformation/parameters/common-parameters.json \
  --capabilities CAPABILITY_NAMED_IAM

# デプロイ完了まで待機
aws cloudformation wait stack-create-complete \
  --stack-name iam-foundation
```

### Step 3: パスワードポリシーの設定

```bash
# パスワードポリシーの確認
aws iam get-account-password-policy

# カスタムポリシーの適用（CloudFormationで自動設定済み）
echo "パスワードポリシーが適用されました："
echo "- 最小長: 14文字"
echo "- 大文字、小文字、数字、記号が必要"
echo "- 過去12回のパスワード再利用禁止"
echo "- 90日で期限切れ"
```

### Step 4: CloudTrailの設定確認

```bash
# CloudTrailの状態確認
aws cloudtrail describe-trails

# ログの確認
aws logs describe-log-groups \
  --log-group-name-prefix "CloudTrail"
```

## 📚 学習コンテンツ

### IAMの基本概念

#### 1. ユーザー（Users）
実際の人や外部システムを表すエンティティ

```bash
# ユーザー一覧の確認
aws iam list-users

# 特定ユーザーの詳細
aws iam get-user --user-name alice

# ユーザーに付与されたポリシー確認
aws iam list-attached-user-policies --user-name alice
```

#### 2. グループ（Groups）
ユーザーをまとめて管理するためのコレクション

```bash
# グループ一覧の確認
aws iam list-groups

# グループメンバーの確認
aws iam get-group --group-name Administrators

# グループのポリシー確認
aws iam list-attached-group-policies --group-name Developers
```

#### 3. ロール（Roles）
AWSサービスや外部システムが一時的に使用する権限

```bash
# ロール一覧の確認
aws iam list-roles

# ロールの詳細確認
aws iam get-role --role-name EC2-AdminRole

# ロールの信頼関係確認
aws iam get-role --role-name EC2-AdminRole \
  --query 'Role.AssumeRolePolicyDocument'
```

#### 4. ポリシー（Policies）
権限を定義するJSONドキュメント

```bash
# カスタムポリシー一覧
aws iam list-policies --scope Local

# ポリシーの内容確認
aws iam get-policy-version \
  --policy-arn arn:aws:iam::123456789012:policy/DeveloperAccess \
  --version-id v1
```

## 🧪 ハンズオン演習

### 演習1: IAMユーザーの作成と設定

```bash
# 1. 新しいユーザーを作成
aws iam create-user --user-name test-developer

# 2. グループに追加
aws iam add-user-to-group \
  --user-name test-developer \
  --group-name Developers

# 3. 一時的なパスワードを設定
aws iam create-login-profile \
  --user-name test-developer \
  --password "TempPassword123!" \
  --password-reset-required

# 4. アクセスキーの作成（プログラマティックアクセス用）
aws iam create-access-key --user-name test-developer
```

### 演習2: カスタムポリシーの作成

```bash
# 1. S3読み取り専用ポリシーの作成
cat > s3-read-only-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-app-bucket",
        "arn:aws:s3:::my-app-bucket/*"
      ]
    }
  ]
}
EOF

# 2. ポリシーの作成
aws iam create-policy \
  --policy-name S3ReadOnlyAccess \
  --policy-document file://s3-read-only-policy.json

# 3. ユーザーにポリシーを添付
aws iam attach-user-policy \
  --user-name test-developer \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/S3ReadOnlyAccess
```

### 演習3: MFAデバイスの設定

```bash
# 1. 仮想MFAデバイスの作成
aws iam create-virtual-mfa-device \
  --virtual-mfa-device-name test-developer-mfa \
  --outfile /tmp/qr-code.png \
  --bootstrap-method QRCodePNG

# 2. MFAデバイスの有効化（認証アプリでQRコードを読み取り後）
# aws iam enable-mfa-device \
#   --user-name test-developer \
#   --serial-number arn:aws:iam::123456789012:mfa/test-developer-mfa \
#   --authentication-code-1 123456 \
#   --authentication-code-2 789012
```

## 🔍 セキュリティベストプラクティス

### 1. 最小権限の原則

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeImages"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "ap-northeast-1"
        }
      }
    }
  ]
}
```

### 2. 条件付きアクセス制御

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        },
        "IpAddress": {
          "aws:SourceIp": ["203.0.113.0/24", "198.51.100.0/24"]
        }
      }
    }
  ]
}
```

### 3. 時間ベースのアクセス制御

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "DateGreaterThan": {
          "aws:CurrentTime": "2024-01-01T00:00:00Z"
        },
        "DateLessThan": {
          "aws:CurrentTime": "2024-12-31T23:59:59Z"
        }
      }
    }
  ]
}
```

## 📊 監視とログ

### CloudTrailログの分析

```bash
# 最近のAPI呼び出し確認
aws logs filter-log-events \
  --log-group-name "CloudTrail/ManagementEvents" \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --filter-pattern "{ $.errorCode EXISTS }"

# ルートアカウントの使用確認
aws logs filter-log-events \
  --log-group-name "CloudTrail/ManagementEvents" \
  --filter-pattern "{ $.userIdentity.type = \"Root\" }"

# 失敗したログイン試行
aws logs filter-log-events \
  --log-group-name "CloudTrail/ManagementEvents" \
  --filter-pattern "{ $.eventName = \"ConsoleLogin\" && $.errorMessage EXISTS }"
```

### CloudWatchアラートの設定

```bash
# ルートアカウント使用のアラート作成
aws cloudwatch put-metric-alarm \
  --alarm-name "Root-Account-Usage" \
  --alarm-description "Alert when root account is used" \
  --metric-name "RootAccountUsage" \
  --namespace "CWLogs" \
  --statistic "Sum" \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --alarm-actions "arn:aws:sns:ap-northeast-1:123456789012:security-alerts"
```

## 🛠️ トラブルシューティング

### よくある問題と解決方法

#### 1. 権限エラー（AccessDenied）

```bash
# 問題の診断
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/testuser \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::mybucket/mykey

# 有効なポリシーの確認
aws iam list-attached-user-policies --user-name testuser
aws iam list-user-policies --user-name testuser
```

#### 2. MFA認証の問題

```bash
# MFAデバイスの状態確認
aws iam list-mfa-devices --user-name testuser

# MFAが必要なポリシーの確認
aws iam get-user-policy \
  --user-name testuser \
  --policy-name RequireMFA
```

#### 3. パスワードポリシー違反

```bash
# 現在のパスワードポリシー確認
aws iam get-account-password-policy

# ポリシー更新
aws iam update-account-password-policy \
  --minimum-password-length 12 \
  --require-symbols \
  --require-numbers \
  --require-uppercase-characters \
  --require-lowercase-characters
```

## 📈 コスト最適化

### IAMコスト分析

```bash
# IAM使用量の確認（無料）
aws iam get-account-summary

# CloudTrailのストレージコスト確認
aws s3 ls s3://your-cloudtrail-bucket --recursive --human-readable --summarize
```

### 不要なリソースの削除

```bash
# 未使用のアクセスキー確認
aws iam generate-credential-report
aws iam get-credential-report

# 未使用のユーザー確認
aws iam list-users --query 'Users[?PasswordLastUsed<`2023-01-01`]'
```

## 🧪 テストとバリデーション

### セキュリティテスト

```bash
# IAM設定の検証
./scripts/test-iam-security.sh

# パスワードポリシーのテスト
./scripts/test-password-policy.sh

# CloudTrail設定の確認
./scripts/test-cloudtrail.sh
```

### コンプライアンステスト

```bash
# CIS Benchmark準拠チェック
aws iam get-account-summary
aws iam list-users --query 'Users[?PasswordLastUsed==null]'
aws cloudtrail describe-trails --query 'trailList[?IsMultiRegionTrail==`false`]'
```

## 🔧 カスタマイズ

### 組織向けカスタマイズ

```yaml
# 複数部門のグループ設定
IAMGroups:
  - GroupName: Engineering
    ManagedPolicies:
      - arn:aws:iam::aws:policy/PowerUserAccess
  - GroupName: Finance
    ManagedPolicies:
      - arn:aws:iam::aws:policy/job-function/Billing
  - GroupName: Security
    ManagedPolicies:
      - arn:aws:iam::aws:policy/SecurityAudit
```

### 環境別設定

```yaml
# Development環境
MFARequired: false
PasswordMinLength: 8
SessionDuration: 3600

# Production環境
MFARequired: true
PasswordMinLength: 14
SessionDuration: 900
```

## 🧹 クリーンアップ

### テストリソースの削除

```bash
# テストユーザーの削除
aws iam remove-user-from-group \
  --user-name test-developer \
  --group-name Developers

aws iam delete-login-profile --user-name test-developer
aws iam delete-access-key \
  --user-name test-developer \
  --access-key-id AKIA...

aws iam delete-user --user-name test-developer

# CloudFormationスタックの削除
aws cloudformation delete-stack --stack-name iam-foundation
```

## 📚 参考資料

### 公式ドキュメント
- [IAM User Guide](https://docs.aws.amazon.com/IAM/latest/UserGuide/)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)

### セキュリティフレームワーク
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [ISO 27001 Controls](https://www.iso.org/isoiec-27001-information-security.html)

## 📝 まとめ

このセクションでは以下を学習しました：

1. **IAMの基本概念**とセキュリティ設計
2. **CloudFormation**による自動化
3. **セキュリティ監視**とアラート設定
4. **ベストプラクティス**の実装

次は「**1.1.2 VPCとネットワーク基礎**」でネットワーク設計を学習しましょう。

---

## 🎯 学習チェックリスト

- [ ] IAMユーザー、グループ、ロールの違いを理解
- [ ] ポリシーの作成と管理ができる
- [ ] MFA設定ができる
- [ ] CloudTrail設定を理解
- [ ] セキュリティベストプラクティスを適用できる
- [ ] 権限の最小化ができる
- [ ] 監視とアラート設定ができる
- [ ] トラブルシューティングができる