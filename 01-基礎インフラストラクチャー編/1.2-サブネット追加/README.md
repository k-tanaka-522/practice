# 1.2 サブネット追加

## 🎯 このステップで学ぶこと

ステップ1で作成したVPCに、パブリックサブネットとプライベートサブネットを追加します。ルートテーブルの設定方法も学習します。

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

### 1. 前のステップのクリーンアップ (必要に応じて)

```bash
# 前のステップのスタックを削除 (必要に応じて)
aws cloudformation delete-stack --stack-name aws-practice-dev-step1
```

### 2. 新しいスタックの作成

```bash
# メインスタックの作成 (VPC + サブネット)
aws cloudformation create-stack \
  --stack-name aws-practice-dev-step2 \
  --template-body file://cloudformation/templates/main-stack.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=aws-practice \
               ParameterKey=EnvironmentName,ParameterValue=dev
```

### 3. スタックの確認

```bash
# スタックの状態確認
aws cloudformation describe-stacks \
  --stack-name aws-practice-dev-step2

# 作成されたサブネットの確認
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$(aws cloudformation describe-stacks --stack-name aws-practice-dev-step2 --query 'Stacks[0].Outputs[?OutputKey==`VPCId`].OutputValue' --output text)"
```

## 📊 確認事項

- [ ] パブリックサブネットが作成されている
- [ ] プライベートサブネットが作成されている
- [ ] パブリックルートテーブルが作成されている
- [ ] プライベートルートテーブルが作成されている
- [ ] パブリックサブネットのルートテーブルにインターネットゲートウェイへのルートが設定されている

## 💡 ポイント

1. **段階的構築**: 既存のVPCテンプレートを再利用
2. **パラメータ連携**: VPCのIDやIGWのIDを次のテンプレートに渡す
3. **ルートテーブル**: パブリックサブネットだけがインターネットにアクセス可能

## 🧪 テスト

### パブリックサブネットのテスト

```bash
# パブリックサブネットにテスト用EC2インスタンスを起動
aws ec2 run-instances \
  --image-id ami-0d52744d6551d851e \
  --instance-type t2.micro \
  --subnet-id $(aws cloudformation describe-stacks --stack-name aws-practice-dev-step2 --query 'Stacks[0].Outputs[?OutputKey==`PublicSubnetId`].OutputValue' --output text) \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test-public-instance}]'
```

## 🗑️ リソースの削除

```bash
# スタックの削除
aws cloudformation delete-stack \
  --stack-name aws-practice-dev-step2
```

## 📝 次のステップ

次は「1.3 セキュリティグループ」でネットワークセキュリティを設定します。

---

**💰 コスト**: このステップでもサブネットやルートテーブルは無料です。EC2インスタンスをテストで起動した場合は削除を忘れずに！
