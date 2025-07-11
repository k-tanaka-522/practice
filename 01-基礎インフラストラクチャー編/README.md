# 基礎インフラストラクチャー編

## 🎯 概要

このセクションでは、AWSの基礎インフラストラクチャーを段階的に学習します。VPCから始めて、最終的にWebアプリケーションを支える完全なインフラストラクチャーを構築します。

## 📚 学習目標

- 🌐 **VPCネットワーク**: ネットワーク設計、サブネット、セキュリティ
- 💻 **コンピューティング**: EC2、ロードバランサー、Auto Scaling
- 🗃️ **データベース**: RDSを使用したデータ層の構築
- 📊 **Infrastructure as Code**: CloudFormationの段階的学習

## 🏗️ 最終アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                       │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │  Public Subnet  │  │ Private Subnet  │                      │
│  │                 │  │                 │                      │
│  │  ┌───────────┐  │  │  ┌───────────┐  │                      │
│  │  │    ALB    │  │  │  │    EC2    │  │                      │
│  │  │           │  │  │  │  (WebApp) │  │                      │
│  │  └───────────┘  │  │  └───────────┘  │                      │
│  └─────────────────┘  └─────────────────┘                      │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │   DB Subnet     │  │   DB Subnet     │                      │
│  │                 │  │                 │                      │
│  │  ┌───────────┐  │  │  ┌───────────┐  │                      │
│  │  │    RDS    │  │  │  │    RDS    │  │                      │
│  │  │ (Primary) │  │  │  │ (Standby) │  │                      │
│  │  └───────────┘  │  │  └───────────┘  │                      │
│  └─────────────────┘  └─────────────────┘                      │
└─────────────────────────────────────────────────────────────────┘
```

## 📋 学習パス

### 1.1 VPC基礎（1時間）
- VPCとInternet Gatewayの作成
- CloudFormationの基本的な使い方
- ネットワークの基礎概念

### 1.2 サブネット追加（1時間）
- パブリック・プライベートサブネットの作成
- ルートテーブルの設定
- 段階的なネットワーク設計

### 1.3 セキュリティグループ（1時間）
- ネットワークセキュリティの基礎
- セキュリティグループの設定
- 最小権限の原則

### 1.4 EC2インスタンス（1時間）
- Webサーバーの構築
- Auto Scalingの設定
- インスタンス管理の基礎

### 1.5 ロードバランサー（1時間）
- Application Load Balancerの設定
- 高可用性の実現
- ヘルスチェック設定

### 1.6 RDSデータベース（1時間）
- データベースの構築
- Multi-AZ設定
- Webアプリケーションの完成

## 🚀 クイックスタート

### 前提条件
- AWSアカウント
- AWS CLI設定済み
- CloudFormationの基本知識

### 学習の進め方

1. **各ステップで完結**: 各ステップで作成→確認→削除を繰り返す
2. **段階的な理解**: 前のステップの理解を前提に次に進む
3. **実践重視**: 実際にリソースを作成して動作を確認

### 開始手順

```bash
# 1. 最初はVPC基礎から開始
cd 1.1-VPC基礎

# 2. README.mdを読んで学習内容を確認
cat README.md

# 3. CloudFormationでデプロイ
aws cloudformation create-stack \
  --stack-name aws-practice-vpc \
  --template-body file://cloudformation/main-stack.yaml
```

## 💡 学習のポイント

1. **デプロイ・デストロイサイクル**: 各ステップで作成→確認→削除
2. **コスト管理**: 不要なリソースはすぐに削除
3. **セキュリティ**: 各ステップでセキュリティベストプラクティスを学習
4. **高可用性**: Multi-AZ設計の重要性を理解

## 🔄 学習フロー

```
1.1 VPC基礎 → 1.2 サブネット追加 → 1.3 セキュリティグループ
     ↓              ↓                    ↓
  VPC作成        サブネット作成        セキュリティ設定
     ↓              ↓                    ↓
1.4 EC2インスタンス → 1.5 ロードバランサー → 1.6 RDSデータベース
     ↓              ↓                    ↓
  Web層構築      負荷分散設定          データ層構築
```

## 📊 コスト管理

| ステップ | 主なコスト | 概算（1時間） |
|----------|-----------|-------------|
| 1.1-1.3 | ネットワーク | 無料 |
| 1.4 | EC2 | $0.01-0.05 |
| 1.5 | ALB | $0.02-0.03 |
| 1.6 | RDS | $0.05-0.10 |

**💡 コスト削減Tips**
- 各ステップ完了後にリソースを削除
- t3.micro等の小さなインスタンスを使用
- 学習時間を区切って進める

## 🎯 学習完了後のスキル

このモジュール完了後、以下のスキルを習得できます：

- ✅ CloudFormationによるInfrastructure as Code
- ✅ VPCネットワーク設計
- ✅ セキュリティグループ設計
- ✅ EC2とAuto Scalingの基礎
- ✅ ロードバランサーの設定
- ✅ RDSデータベースの構築
- ✅ 高可用性アーキテクチャーの理解

---

**🚀 次のステップ**: 02-Web三層アーキテクチャ編でWebアプリケーションの本格的な構築を学習します。