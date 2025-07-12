# 1.2 サブネット追加

## 🎯 このステップで学ぶこと

ステップ1で作成したVPCに、パブリックサブネットとプライベートサブネットを追加します。ルートテーブルの設定方法も学習します。

### ネストスタックを使う理由

このプロジェクトでは**ネストスタック**を採用しています：

1. **再利用性**: 個別のテンプレート（VPC、サブネット、セキュリティグループ等）を他のプロジェクトでも再利用可能
2. **保守性**: 機能ごとにテンプレートを分割することで、変更時の影響範囲を限定
3. **段階的学習**: 各ステップで少しずつ機能を追加していく学習スタイルに適している
4. **実務での標準**: 実際の業務でも複雑なインフラは機能別に分割して管理する

ネストスタックを使用するため、テンプレートをS3にアップロードする手順が含まれます。

## 📋 作成するリソース

- **パブリックサブネット**: 10.0.1.0/24 (インターネットからアクセス可能)
- **プライベートサブネット**: 10.0.2.0/24 (インターネットからアクセス不可)
- **ルートテーブル**: パブリック用・プライベート用
- **ルート**: パブリックサブネットからインターネットへのルート

## 🏗️ アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────┐
│                      VPC (10.0.0.0/16)                     │
│                                                             │
│  ┌─────────────────────────┐  ┌─────────────────────────┐   │
│  │    Public Subnet        │  │    Private Subnet       │   │
│  │    (10.0.1.0/24)        │  │    (10.0.2.0/24)        │   │
│  │                         │  │                         │   │
│  │  ┌─────────────────┐    │  │                         │   │
│  │  │  Route Table    │    │  │  ┌─────────────────┐    │   │
│  │  │  (Public)       │    │  │  │  Route Table    │    │   │
│  │  │                 │    │  │  │  (Private)      │    │   │
│  │  │ 0.0.0.0/0 → IGW │    │  │  │                 │    │   │
│  │  └─────────────────┘    │  │  └─────────────────┘    │   │
│  └─────────────────────────┘  └─────────────────────────┘   │
│                                                             │
│           ┌─────────────────────────────────────┐           │
│           │         Internet Gateway            │           │
│           └─────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 デプロイ手順

### 前提条件
- **実行ディレクトリ**: このREADMEがあるディレクトリ（`1.2-サブネット追加/`）から実行してください
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
aws cloudformation delete-stack --stack-name aws-practice-vpc
```

### 4. 新しいスタックの作成

```bash
# メインスタックの作成 (VPC + サブネット)
aws cloudformation create-stack \
  --stack-name aws-practice-subnets \
  --template-body file://cloudformation/main-stack.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=aws-practice \
               ParameterKey=EnvironmentName,ParameterValue=dev \
               ParameterKey=S3BucketName,ParameterValue=$BUCKET_NAME
```

### 5. スタックの確認

```bash
# スタックの状態確認
aws cloudformation describe-stacks \
  --stack-name aws-practice-subnets

# 作成されたサブネットの確認
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$(aws cloudformation describe-stacks --stack-name aws-practice-subnets --query 'Stacks[0].Outputs[?OutputKey==`VPCId`].OutputValue' --output text)"
```

## 📊 確認事項

- [ ] パブリックサブネットが作成されている
- [ ] プライベートサブネットが作成されている
- [ ] パブリックルートテーブルが作成されている
- [ ] プライベートルートテーブルが作成されている
- [ ] パブリックサブネットのルートテーブルにインターネットゲートウェイへのルートが設定されている

## 💡 ポイント

1. **ネストしたスタック**: `main-stack.yaml`が個別のテンプレートを読み込む構造
2. **段階的構築**: 既存のVPCテンプレートを再利用
3. **パラメータ連携**: VPCのIDやIGWのIDを次のテンプレートに渡す
4. **ルートテーブル**: パブリックサブネットだけがインターネットにアクセス可能

## 🧪 テスト

### パブリックサブネットのテスト

```bash
# パブリックサブネットにテスト用EC2インスタンスを起動
aws ec2 run-instances \
  --image-id ami-0d52744d6551d851e \
  --instance-type t2.micro \
  --subnet-id $(aws cloudformation describe-stacks --stack-name aws-practice-subnets --query 'Stacks[0].Outputs[?OutputKey==`PublicSubnetId`].OutputValue' --output text) \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test-public-instance}]'
```

## 🗑️ リソースの削除

```bash
# スタックの削除
aws cloudformation delete-stack \
  --stack-name aws-practice-subnets

# スタック削除の完了を待機
aws cloudformation wait stack-delete-complete \
  --stack-name aws-practice-subnets

# S3バケットを空にして削除
aws s3 rm "s3://$BUCKET_NAME" --recursive
aws s3 rb "s3://$BUCKET_NAME"
```

## 📝 次のステップ

次は「1.3 セキュリティグループ」でネットワークセキュリティを設定します。

---

**💰 コスト**: このステップでもサブネットやルートテーブルは無料です。EC2インスタンスをテストで起動した場合は削除を忘れずに！
