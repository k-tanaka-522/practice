# 1.3 セキュリティグループ

## 🎯 このステップで学ぶこと

ステップ1・2で作成したVPCとサブネットに、セキュリティグループを追加します。ネットワークレベルのセキュリティ設定を学習します。

### ネストスタックを使う理由

このプロジェクトでは**ネストスタック**を採用しています：

1. **再利用性**: 個別のテンプレート（VPC、サブネット、セキュリティグループ等）を他のプロジェクトでも再利用可能
2. **保守性**: 機能ごとにテンプレートを分割することで、変更時の影響範囲を限定
3. **段階的学習**: 各ステップで少しずつ機能を追加していく学習スタイルに適している
4. **実務での標準**: 実際の業務でも複雑なインフラは機能別に分割して管理する

ネストスタックを使用するため、テンプレートをS3にアップロードする手順が含まれます。

## 📋 作成するリソース

- **Webサーバー用セキュリティグループ**: HTTP・HTTPS・SSH通信を許可
- **データベース用セキュリティグループ**: Webサーバーからのみアクセス可能

## 🏗️ アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────┐
│                      VPC (10.0.0.0/16)                     │
│                                                             │
│  ┌─────────────────────────┐  ┌─────────────────────────┐   │
│  │    Public Subnet        │  │    Private Subnet       │   │
│  │    (10.0.1.0/24)        │  │    (10.0.2.0/24)        │   │
│  │                         │  │                         │   │
│  │  ┌─────────────────┐    │  │  ┌─────────────────┐    │   │
│  │  │  Web Server     │    │  │  │   Database      │    │   │
│  │  │  Security Group │    │  │  │  Security Group │    │   │
│  │  │                 │    │  │  │                 │    │   │
│  │  │ HTTP:80 ←━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│  │  │ HTTPS:443 ←━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│  │  │ SSH:22 ←━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│  │  │                 │    │  │  │ MySQL:3306 ←━━━━━━━━━━━━━│
│  │  └─────────────────┘    │  │  │ (from Web SG only)  │   │
│  │                         │  │  └─────────────────┘    │   │
│  └─────────────────────────┘  └─────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 デプロイ手順

### 前提条件
- **実行ディレクトリ**: このREADMEがあるディレクトリ（`1.3-セキュリティグループ/`）から実行してください
- **AWS CLI**: 設定済みであること
- **権限**: CloudFormationとVPC作成権限があること

### 1. S3バケットの作成とテンプレートアップロード

```bash
# S3バケットの作成（バケット名は一意である必要があります）
BUCKET_NAME="aws-practice-cf-templates-$(date +%s)"
aws s3 mb "s3://$BUCKET_NAME"

# ネストスタックテンプレートをS3にアップロード
aws s3 cp cloudformation/templates/ "s3://$BUCKET_NAME/templates/" --recursive

# アップロード確認
aws s3 ls "s3://$BUCKET_NAME/templates/"
```

### 2. テンプレートの検証

```bash
# CloudFormationテンプレートの検証
aws cloudformation validate-template \
  --template-body file://cloudformation/main-stack.yaml
```

### 3. 前のステップのクリーンアップ (必要に応じて)

```bash
# 前のステップのスタックを削除 (必要に応じて)
aws cloudformation delete-stack --stack-name aws-practice-subnets
```

### 4. 新しいスタックの作成

```bash
# メインスタックの作成 (VPC + サブネット + セキュリティグループ)
aws cloudformation create-stack \
  --stack-name aws-practice-security \
  --template-body file://cloudformation/main-stack.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=aws-practice \
               ParameterKey=EnvironmentName,ParameterValue=dev \
               ParameterKey=S3BucketName,ParameterValue=$BUCKET_NAME
```

### 5. スタックの確認

```bash
# スタックの状態確認
aws cloudformation describe-stacks \
  --stack-name aws-practice-security

# 作成されたセキュリティグループの確認
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=aws-practice-dev-web-sg"
```

## 📊 確認事項

- [ ] Webサーバー用セキュリティグループが作成されている
- [ ] データベース用セキュリティグループが作成されている
- [ ] Webサーバー用SGにHTTP・HTTPS・SSH のインバウンドルールが設定されている
- [ ] データベース用SGにWebサーバーSGからのMySQL接続のみ許可されている

## 💡 ポイント

1. **ネストしたスタック**: `main-stack.yaml`が個別のテンプレートを読み込む構造
2. **段階的構築**: 既存のVPCとサブネットテンプレートを再利用
3. **セキュリティグループの参照**: データベースSGがWebサーバーSGを参照することで、Webサーバーからのみのアクセスを許可
4. **最小権限の原則**: 必要最小限のポートとプロトコルのみを許可
5. **ソースの指定**: 特定のセキュリティグループからのアクセスのみを許可

## 🧪 テスト

### セキュリティグループの確認

```bash
# Webサーバー用セキュリティグループの詳細確認
aws ec2 describe-security-groups \
  --group-names aws-practice-dev-web-sg \
  --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp]'

# データベース用セキュリティグループの詳細確認
aws ec2 describe-security-groups \
  --group-names aws-practice-dev-db-sg \
  --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,UserIdGroupPairs[0].GroupId]'
```

## 🚨 セキュリティの注意点

1. **SSH接続の制限**: 本番環境では SSH (22番ポート) を 0.0.0.0/0 に開放しないこと
2. **定期的な見直し**: セキュリティグループのルールを定期的に見直し、不要なルールを削除
3. **最小権限**: 必要最小限のアクセス権限のみを付与

## 🗑️ リソースの削除

```bash
# スタックの削除
aws cloudformation delete-stack \
  --stack-name aws-practice-security

# スタック削除の完了を待機
aws cloudformation wait stack-delete-complete \
  --stack-name aws-practice-security

# S3バケットを空にして削除
aws s3 rm "s3://$BUCKET_NAME" --recursive
aws s3 rb "s3://$BUCKET_NAME"
```

## 📝 次のステップ

次は「1.4 EC2インスタンス」でWebサーバーを構築します。

---

**💰 コスト**: セキュリティグループ自体は無料です。EC2インスタンスをテストで起動する場合は削除を忘れずに！
