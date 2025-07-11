# 1.3 セキュリティグループ

## 🎯 このステップで学ぶこと

ステップ1・2で作成したVPCとサブネットに、セキュリティグループを追加します。ネットワークレベルのセキュリティ設定を学習します。

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

### 1. 前のステップのクリーンアップ (必要に応じて)

```bash
# 前のステップのスタックを削除 (必要に応じて)
aws cloudformation delete-stack --stack-name aws-practice-subnets
```

### 2. 新しいスタックの作成

```bash
# メインスタックの作成 (VPC + サブネット + セキュリティグループ)
aws cloudformation create-stack \
  --stack-name aws-practice-security \
  --template-body file://cloudformation/main-stack.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=aws-practice \
               ParameterKey=EnvironmentName,ParameterValue=dev
```

### 3. スタックの確認

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

1. **セキュリティグループの参照**: データベースSGがWebサーバーSGを参照することで、Webサーバーからのみのアクセスを許可
2. **最小権限の原則**: 必要最小限のポートとプロトコルのみを許可
3. **ソースの指定**: 特定のセキュリティグループからのアクセスのみを許可

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
```

## 📝 次のステップ

次は「1.4 EC2インスタンス」でWebサーバーを構築します。

---

**💰 コスト**: セキュリティグループ自体は無料です。EC2インスタンスをテストで起動する場合は削除を忘れずに！