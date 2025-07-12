# 1.1 VPC基礎

## 🎯 このステップで学ぶこと

AWSの基礎となるVPC（Virtual Private Cloud）を作成します。まずはシンプルにVPCとInternet Gatewayだけを作成し、CloudFormationの基本的な使い方を習得します。

### ネストスタックを使う理由

このプロジェクトでは**ネストスタック**を採用しています：

1. **再利用性**: 個別のテンプレート（VPC、サブネット、セキュリティグループ等）を他のプロジェクトでも再利用可能
2. **保守性**: 機能ごとにテンプレートを分割することで、変更時の影響範囲を限定
3. **段階的学習**: 各ステップで少しずつ機能を追加していく学習スタイルに適している
4. **実務での標準**: 実際の業務でも複雑なインフラは機能別に分割して管理する

ネストスタックを使用するため、テンプレートをS3にアップロードする手順が含まれます。

## 📋 作成するリソース

- **VPC**: 10.0.0.0/16 のネットワーク
- **Internet Gateway**: インターネット接続用ゲートウェイ

## 🏗️ アーキテクチャ図

```
┌─────────────────────────────────────┐
│            VPC                      │
│        (10.0.0.0/16)                │
│                                     │
│                                     │
│                                     │
│         ┌─────────────────┐         │
│         │ Internet Gateway │         │
│         └─────────────────┘         │
└─────────────────────────────────────┘
```

## 🚀 デプロイ手順

### 前提条件
- **実行ディレクトリ**: このREADMEがあるディレクトリ（`1.1-VPC基礎/`）から実行してください
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

### 3. スタックの作成

```bash
# メインスタックの作成
aws cloudformation create-stack \
  --stack-name aws-practice-vpc \
  --template-body file://cloudformation/main-stack.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=aws-practice \
               ParameterKey=EnvironmentName,ParameterValue=dev \
               ParameterKey=S3BucketName,ParameterValue=$BUCKET_NAME
```

### 4. スタックの確認

```bash
# スタックの状態確認
aws cloudformation describe-stacks \
  --stack-name aws-practice-vpc

# 作成されたVPCの確認
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=aws-practice-dev-vpc"
```

## 📊 確認事項

- [ ] VPCが正常に作成されている
- [ ] Internet Gatewayが作成されている
- [ ] Internet GatewayがVPCにアタッチされている
- [ ] 適切なタグが設定されている

## 💡 ポイント

1. **ネストしたスタック**: `main-stack.yaml`が`vpc-simple.yaml`を読み込む構造
2. **パラメータ**: プロジェクト名と環境名をパラメータ化
3. **アウトプット**: 次のステップで使用するためのExport値

## 🗑️ リソースの削除

```bash
# スタックの削除
aws cloudformation delete-stack \
  --stack-name aws-practice-vpc

# スタック削除の完了を待機
aws cloudformation wait stack-delete-complete \
  --stack-name aws-practice-vpc

# S3バケットを空にして削除
aws s3 rm "s3://$BUCKET_NAME" --recursive
aws s3 rb "s3://$BUCKET_NAME"
```

## 📝 次のステップ

次は「1.2 サブネット追加」で、このVPCにサブネットを追加します。

---

**💰 コスト**: このステップではVPCとInternet Gatewayのみなので、ほとんどコストはかかりません。