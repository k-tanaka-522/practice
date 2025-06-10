# Web三層アーキテクチャ編

## 概要

このセクションでは、モダンなWeb三層アーキテクチャをAWS上で構築します。プレゼンテーション層、アプリケーション層、データ層の設計と実装を通じて、スケーラブルなWebアプリケーションの構築手法を学習します。

## 学習目標

- 🌐 **プレゼンテーション層**: 静的サイト、SPA、CDN
- ⚙️ **アプリケーション層**: REST API、GraphQL、マイクロサービス
- 💾 **データ層**: RDS、DynamoDB、データモデリング
- 🔄 **統合**: 三層間の通信とセキュリティ
- 📊 **監視**: アプリケーション全体の監視とログ

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────┐ │
│  │   CloudFront    │  │      S3         │  │  Route  │ │
│  │      CDN        │──│  Static Site    │  │  53     │ │
│  └─────────────────┘  └─────────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│                  Application Layer                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────┐ │
│  │  API Gateway    │  │     Lambda      │  │   ECS   │ │
│  │  REST/GraphQL   │──│   Functions     │  │ Service │ │
│  └─────────────────┘  └─────────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│                     Data Layer                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────┐ │
│  │      RDS        │  │    DynamoDB     │  │ Redis   │ │
│  │   PostgreSQL    │  │    NoSQL DB     │  │ Cache   │ │
│  └─────────────────┘  └─────────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────┘
```

## 学習パス

### 2.1 プレゼンテーション層
- **2.1.1** 静的サイトホスティング（S3 + CloudFront）
- **2.1.2** React/Next.jsアプリケーション

### 2.2 アプリケーション層
- **2.2.1** REST API（API Gateway + Lambda）
- **2.2.2** GraphQL API（AppSync）

### 2.3 データ層
- **2.3.1** RDSデータベース（PostgreSQL）
- **2.3.2** DynamoDB（NoSQL）

## クイックスタート

### 前提条件

```bash
# AWS CLI確認
aws --version

# Node.js環境確認（フロントエンド用）
node --version
npm --version

# Docker確認（コンテナ用）
docker --version
```

### 全体デプロイ

```bash
# Web三層アーキテクチャの一括デプロイ
./scripts/deploy-all-infrastructure.sh deploy-web

# 段階的デプロイ
./scripts/deploy-web-tier.sh deploy-presentation
./scripts/deploy-web-tier.sh deploy-application
./scripts/deploy-web-tier.sh deploy-data
```

## 学習コンテンツ詳細

### 🌐 2.1.1 静的サイトホスティング

**学習内容:**
- S3による静的サイトホスティング
- CloudFrontによるCDN配信
- Route 53によるカスタムドメイン
- HTTPS化とセキュリティ設定

**実装内容:**
- S3バケット設定とWebサイト配信
- CloudFrontディストリビューション
- SSL証明書の設定
- CDNキャッシュ戦略

**主要技術:**
- Amazon S3（Static Website Hosting）
- Amazon CloudFront（CDN）
- AWS Certificate Manager（SSL/TLS）
- Route 53（DNS）

### ⚛️ 2.1.2 React/Next.jsアプリケーション

**学習内容:**
- モダンなSPAの構築
- Next.jsによるSSR/SSG
- AWS Amplifyによるデプロイ
- API統合とステート管理

**実装内容:**
- React/Next.jsアプリケーション開発
- AWS Amplifyデプロイパイプライン
- APIクライアント実装
- 認証UI実装

**主要技術:**
- React.js/Next.js
- AWS Amplify
- TypeScript
- Tailwind CSS

### ⚙️ 2.2.1 REST API

**学習内容:**
- RESTful API設計原則
- API Gatewayによるエンドポイント管理
- Lambdaによるサーバーレス実装
- 認証・認可の実装

**実装内容:**
- API Gateway REST API構築
- Lambda関数による処理実装
- Cognito認証統合
- API仕様書（OpenAPI）

**主要技術:**
- Amazon API Gateway
- AWS Lambda
- Amazon Cognito
- OpenAPI 3.0

### 🔗 2.2.2 GraphQL API

**学習内容:**
- GraphQLの基本概念とメリット
- AWS AppSyncによるGraphQL API
- リアルタイム機能（Subscriptions）
-効率的なデータフェッチング

**実装内容:**
- AppSync GraphQL API設計
- Resolver実装（DynamoDB、Lambda）
- リアルタイム機能実装
- GraphQLクライアント統合

**主要技術:**
- AWS AppSync
- GraphQL
- DynamoDB Resolvers
- Lambda Resolvers

### 💾 2.3.1 RDSデータベース

**学習内容:**
- リレーショナルデータベース設計
- PostgreSQLによるデータモデリング
- RDSによるマネージドDB
- バックアップと高可用性

**実装内容:**
- RDS PostgreSQLクラスター構築
- データベーススキーマ設計
- セキュリティグループ設定
- 監視とアラート設定

**主要技術:**
- Amazon RDS（PostgreSQL）
- Multi-AZ配置
- Read Replica
- Aurora Serverless

### 🗄️ 2.3.2 DynamoDB

**学習内容:**
- NoSQLデータベース設計原則
- DynamoDBのパーティション設計
- インデックス戦略
- パフォーマンス最適化

**実装内容:**
- DynamoDBテーブル設計
- GSI/LSI実装
- キャッシュ戦略（DAX）
- DynamoDB Streams

**主要技術:**
- Amazon DynamoDB
- DynamoDB Accelerator（DAX）
- DynamoDB Streams
- Global Tables

## 🧪 動作確認とテスト

### アプリケーションテスト

```bash
# フロントエンドテスト
cd 02-Web三層アーキテクチャ編/2.1-プレゼンテーション層/2.1.2-React-Next.js/frontend
npm test
npm run build

# APIテスト
./scripts/test-web-api.sh

# データベーステスト
./scripts/test-database.sh
```

### パフォーマンステスト

```bash
# 負荷テスト
artillery run load-test-config.yml

# CDNキャッシュテスト
curl -I https://your-domain.com/
```

### セキュリティテスト

```bash
# OWASP ZAPスキャン
zap-baseline.py -t https://your-api-endpoint.com

# SSL Labs テスト
ssllabs-scan --host=your-domain.com
```

## 📊 監視とアラート

### CloudWatch ダッシュボード

**プレゼンテーション層:**
- CloudFront: リクエスト数、エラー率、キャッシュ効率
- S3: ダウンロード数、エラー

**アプリケーション層:**
- API Gateway: リクエスト数、レイテンシ、エラー率
- Lambda: 実行時間、エラー、同時実行数

**データ層:**
- RDS: CPU、メモリ、接続数、クエリ性能
- DynamoDB: 読み取り/書き込み容量、スロットリング

### アラート設定

```bash
# 高エラー率アラート
aws cloudwatch put-metric-alarm \
  --alarm-name "HighAPIErrorRate" \
  --metric-name "4XXError" \
  --namespace "AWS/ApiGateway"

# レスポンス時間アラート
aws cloudwatch put-metric-alarm \
  --alarm-name "HighLatency" \
  --metric-name "Latency" \
  --threshold 5000
```

## 💰 コスト最適化

### 段階的コスト削減

```yaml
# Development環境
CloudFront:
  PriceClass: PriceClass_100  # 北米・ヨーロッパのみ
RDS:
  InstanceClass: db.t3.micro
  MultiAZ: false
DynamoDB:
  BillingMode: PAY_PER_REQUEST

# Production環境
CloudFront:
  PriceClass: PriceClass_All  # 全世界
RDS:
  InstanceClass: db.r5.large
  MultiAZ: true
DynamoDB:
  BillingMode: PROVISIONED
```

### 使用量監視

```bash
# 月次コストレポート
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-02-01 \
  --granularity MONTHLY \
  --metrics BlendedCost

# サービス別コスト
aws ce get-cost-and-usage \
  --group-by Type=DIMENSION,Key=SERVICE
```

## 🛠️ トラブルシューティング

### よくある問題

#### 1. CORS エラー

```javascript
// API GatewayでのCORS設定
const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://your-domain.com',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
};
```

#### 2. Lambda Cold Start

```yaml
# Provisioned Concurrency設定
ProvisionedConcurrencyConfig:
  ProvisionedConcurrencyUnits: 5

# 軽量ランタイム使用
Runtime: nodejs18.x
MemorySize: 512  # 適切なメモリサイズ
```

#### 3. DynamoDB スロットリング

```javascript
// 指数バックオフリトライ
const dynamoClient = new AWS.DynamoDB.DocumentClient({
  retryDelayOptions: {
    customBackoff: function(retryCount) {
      return Math.pow(2, retryCount) * 100;
    }
  }
});
```

## 🔧 カスタマイズポイント

### マルチテナント対応

```yaml
# テナント別リソース分離
S3Bucket: 
  BucketName: !Sub '${ProjectName}-${TenantId}-static'
DynamoDBTable:
  TableName: !Sub '${ProjectName}-${TenantId}-data'
```

### 地域展開

```yaml
# 複数リージョン対応
GlobalTable:
  Replicas:
    - Region: us-east-1
    - Region: eu-west-1
    - Region: ap-northeast-1
```

## 🧹 クリーンアップ

### リソース削除

```bash
# 段階的削除（依存関係考慮）
./scripts/deploy-web-tier.sh cleanup-data
./scripts/deploy-web-tier.sh cleanup-application
./scripts/deploy-web-tier.sh cleanup-presentation

# 一括削除
./scripts/deploy-all-infrastructure.sh cleanup-web
```

### データ保護

```bash
# RDSスナップショット作成
aws rds create-db-snapshot \
  --db-instance-identifier mydb \
  --db-snapshot-identifier mydb-final-snapshot

# DynamoDBバックアップ
aws dynamodb create-backup \
  --table-name MyTable \
  --backup-name MyTable-backup
```

## 📚 参考資料

### AWS ドキュメント
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Serverless Application Lens](https://docs.aws.amazon.com/wellarchitected/latest/serverless-applications-lens/)
- [Three-Tier Architecture](https://aws.amazon.com/architecture/3-tier/)

### ベストプラクティス
- [React Performance Best Practices](https://react.dev/learn/render-and-commit)
- [API Design Guidelines](https://restfulapi.net/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)

## 📈 次のステップ

完了後は以下に進んでください：

1. **[CRUDシステム実装編](../03-CRUDシステム実装編/README.md)** - 認証とデータ操作
2. **[データ分析基盤編](../04-データ分析基盤編/README.md)** - データパイプライン
3. **[AI-ML統合編](../05-AI-ML統合編/README.md)** - AI機能統合

---

## 🎯 学習チェックリスト

### プレゼンテーション層
- [ ] S3静的サイトホスティング設定
- [ ] CloudFront配信設定
- [ ] カスタムドメインとSSL設定
- [ ] React/Next.jsアプリケーション構築

### アプリケーション層
- [ ] API Gateway設定
- [ ] Lambda関数開発
- [ ] GraphQL API設計
- [ ] 認証・認可実装

### データ層
- [ ] RDSデータベース設計
- [ ] DynamoDBテーブル設計
- [ ] データモデリング
- [ ] パフォーマンス最適化

### 統合・運用
- [ ] 三層間統合テスト
- [ ] 監視・アラート設定
- [ ] セキュリティ設定
- [ ] パフォーマンス最適化

**準備ができたら次のセクションへ進みましょう！**