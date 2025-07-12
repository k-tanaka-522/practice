# 1.1 VPC基礎

## 🎯 このステップで学ぶこと

AWSの基礎となるVPC（Virtual Private Cloud）を作成します。まずはシンプルにVPCとInternet Gatewayだけを作成し、CloudFormationの基本的な使い方を習得します。

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

### 1. テンプレートの検証

```bash
# CloudFormationテンプレートの検証
aws cloudformation validate-template \
  --template-body file://cloudformation/templates/main-stack.yaml
```

### 2. スタックの作成

```bash
# メインスタックの作成
aws cloudformation create-stack \
  --stack-name aws-practice-vpc \
  --template-body file://cloudformation/templates/main-stack.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=aws-practice \
               ParameterKey=EnvironmentName,ParameterValue=dev
```

### 3. スタックの確認

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
```

## 📝 次のステップ

次は「1.2 サブネット追加」で、このVPCにサブネットを追加します。

---

**💰 コスト**: このステップではVPCとInternet Gatewayのみなので、ほとんどコストはかかりません。