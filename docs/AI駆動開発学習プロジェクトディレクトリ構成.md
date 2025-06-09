# AI駆動開発学習プロジェクト ディレクトリ構成

```
ai-driven-development-practice/
│
├── README.md                          # プロジェクト全体の説明
├── .github/
│   ├── workflows/
│   │   ├── deploy-infrastructure.yml   # インフラデプロイ用
│   │   ├── deploy-applications.yml     # アプリデプロイ用
│   │   ├── run-tests.yml              # テスト実行用
│   │   └── cleanup-resources.yml       # リソースクリーンアップ
│   └── ISSUE_TEMPLATE/
│       └── learning-progress.md        # 学習進捗管理用
│
├── scripts/
│   ├── setup/
│   │   ├── aws-cli-setup.sh          # AWS CLI初期設定
│   │   ├── create-oidc-provider.sh   # GitHub Actions OIDC設定
│   │   └── validate-environment.sh    # 環境検証スクリプト
│   └── cleanup/
│       └── delete-all-stacks.sh       # 全リソース削除
│
├── 01-infrastructure-basics/
│   ├── README.md                      # セクション概要
│   ├── 1.1-aws-setup/
│   │   ├── 1.1.1-account-iam/
│   │   │   ├── README.md              # IAM設定手順
│   │   │   ├── cloudformation/
│   │   │   │   ├── iam-roles.yaml    # IAMロール定義
│   │   │   │   └── iam-policies.yaml # IAMポリシー定義
│   │   │   └── docs/
│   │   │       ├── setup-guide.md     # セットアップガイド
│   │   │       └── best-practices.md  # ベストプラクティス
│   │   │
│   │   ├── 1.1.2-vpc-networking/
│   │   │   ├── README.md
│   │   │   ├── cloudformation/
│   │   │   │   ├── vpc-main.yaml     # VPC基本構成
│   │   │   │   ├── vpc-subnets.yaml  # サブネット定義
│   │   │   │   └── vpc-security.yaml # セキュリティグループ
│   │   │   ├── docs/
│   │   │   │   ├── network-design.md # ネットワーク設計書
│   │   │   │   └── troubleshoot.md   # トラブルシューティング
│   │   │   └── diagrams/
│   │   │       └── network-arch.png   # ネットワーク構成図
│   │   │
│   │   └── 1.1.3-github-aws-integration/
│   │       ├── README.md
│   │       ├── cloudformation/
│   │       │   └── github-oidc.yaml   # OIDC プロバイダー
│   │       └── docs/
│   │           └── setup-guide.md
│   │
│   └── 1.2-computing-basics/
│       ├── 1.2.1-ec2-management/
│       │   ├── README.md
│       │   ├── cloudformation/
│       │   │   ├── ec2-instance.yaml
│       │   │   └── ec2-autoscaling.yaml
│       │   ├── scripts/
│       │   │   └── user-data.sh       # EC2初期化スクリプト
│       │   └── docs/
│       │       └── ec2-guide.md
│       │
│       ├── 1.2.2-ecs-containers/
│       │   ├── README.md
│       │   ├── cloudformation/
│       │   │   ├── ecr-repository.yaml
│       │   │   ├── ecs-cluster.yaml
│       │   │   └── ecs-service.yaml
│       │   ├── docker/
│       │   │   ├── Dockerfile
│       │   │   └── docker-compose.yml
│       │   └── docs/
│       │       └── container-guide.md
│       │
│       └── 1.2.3-lambda-serverless/
│           ├── README.md
│           ├── cloudformation/
│           │   └── lambda-function.yaml
│           ├── src/
│           │   └── index.js           # Lambda関数コード
│           └── docs/
│               └── lambda-guide.md
│
├── 02-web-three-tier/
│   ├── README.md
│   ├── 2.1-presentation-layer/
│   │   ├── 2.1.1-static-hosting/
│   │   │   ├── README.md
│   │   │   ├── cloudformation/
│   │   │   │   ├── s3-bucket.yaml
│   │   │   │   ├── cloudfront.yaml
│   │   │   │   └── route53.yaml
│   │   │   ├── src/
│   │   │   │   ├── index.html
│   │   │   │   └── assets/
│   │   │   └── docs/
│   │   │       └── deployment-guide.md
│   │   │
│   │   └── 2.1.2-react-nextjs/
│   │       ├── README.md
│   │       ├── cloudformation/
│   │       │   └── amplify-app.yaml
│   │       ├── frontend/
│   │       │   ├── package.json
│   │       │   ├── next.config.js
│   │       │   └── src/
│   │       └── docs/
│   │           └── frontend-guide.md
│   │
│   ├── 2.2-application-layer/
│   │   ├── 2.2.1-rest-api/
│   │   │   ├── README.md
│   │   │   ├── cloudformation/
│   │   │   │   ├── alb.yaml
│   │   │   │   └── ecs-api-service.yaml
│   │   │   ├── api/
│   │   │   │   ├── package.json
│   │   │   │   └── src/
│   │   │   └── docs/
│   │   │       └── api-design.md
│   │   │
│   │   └── 2.2.2-graphql-api/
│   │       ├── README.md
│   │       ├── cloudformation/
│   │       │   └── appsync.yaml
│   │       ├── graphql/
│   │       │   ├── schema.graphql
│   │       │   └── resolvers/
│   │       └── docs/
│   │           └── graphql-guide.md
│   │
│   └── 2.3-data-layer/
│       ├── 2.3.1-rds-database/
│       │   ├── README.md
│       │   ├── cloudformation/
│       │   │   ├── rds-instance.yaml
│       │   │   └── rds-subnet-group.yaml
│       │   ├── migrations/
│       │   │   └── 001_initial_schema.sql
│       │   └── docs/
│       │       └── database-guide.md
│       │
│       └── 2.3.2-dynamodb/
│           ├── README.md
│           ├── cloudformation/
│           │   └── dynamodb-tables.yaml
│           └── docs/
│               └── nosql-guide.md
│
├── 03-crud-system/
│   ├── README.md
│   ├── 3.1-basic-crud/
│   │   ├── 3.1.1-user-management/
│   │   │   ├── README.md
│   │   │   ├── cloudformation/
│   │   │   │   └── cognito-userpool.yaml
│   │   │   ├── backend/
│   │   │   │   └── auth/
│   │   │   └── docs/
│   │   │       └── auth-flow.md
│   │   │
│   │   └── 3.1.2-data-api/
│   │       ├── README.md
│   │       ├── cloudformation/
│   │       │   └── api-gateway.yaml
│   │       ├── backend/
│   │       │   └── crud/
│   │       └── docs/
│   │           └── api-spec.md
│   │
│   └── 3.2-advanced-crud/
│       ├── 3.2.1-file-upload/
│       │   ├── README.md
│       │   ├── cloudformation/
│       │   │   └── s3-upload-bucket.yaml
│       │   ├── lambda/
│       │   │   └── image-processor/
│       │   └── docs/
│       │       └── upload-guide.md
│       │
│       └── 3.2.2-realtime-updates/
│           ├── README.md
│           ├── cloudformation/
│           │   └── websocket-api.yaml
│           └── docs/
│               └── websocket-guide.md
│
├── 04-data-analytics/
│   ├── README.md
│   ├── 4.1-data-collection/
│   │   ├── 4.1.1-kinesis-streaming/
│   │   │   ├── README.md
│   │   │   ├── cloudformation/
│   │   │   │   ├── kinesis-stream.yaml
│   │   │   │   └── kinesis-firehose.yaml
│   │   │   └── docs/
│   │   │       └── streaming-guide.md
│   │   │
│   │   └── 4.1.2-etl-pipeline/
│   │       ├── README.md
│   │       ├── cloudformation/
│   │       │   ├── glue-catalog.yaml
│   │       │   └── glue-jobs.yaml
│   │       ├── glue-scripts/
│   │       │   └── transform.py
│   │       └── docs/
│   │           └── etl-guide.md
│   │
│   └── 4.2-visualization/
│       ├── 4.2.1-quicksight/
│       │   ├── README.md
│       │   ├── cloudformation/
│       │   │   └── quicksight-dataset.yaml
│       │   └── docs/
│       │       └── dashboard-guide.md
│       │
│       └── 4.2.2-cloudwatch/
│           ├── README.md
│           ├── cloudformation/
│           │   └── cloudwatch-dashboard.yaml
│           └── docs/
│               └── monitoring-guide.md
│
├── 05-ai-ml-integration/
│   ├── README.md
│   ├── 5.1-bedrock-basics/
│   │   ├── 5.1.1-bedrock-setup/
│   │   │   ├── README.md
│   │   │   ├── cloudformation/
│   │   │   │   └── bedrock-permissions.yaml
│   │   │   └── docs/
│   │   │       └── bedrock-guide.md
│   │   │
│   │   └── 5.1.2-text-generation/
│   │       ├── README.md
│   │       ├── lambda/
│   │       │   └── text-generator/
│   │       └── docs/
│   │           └── prompt-engineering.md
│   │
│   └── 5.2-ai-features/
│       ├── 5.2.1-chatbot/
│       │   ├── README.md
│       │   ├── cloudformation/
│       │   │   └── chatbot-stack.yaml
│       │   ├── backend/
│       │   │   └── chatbot/
│       │   └── frontend/
│       │       └── chat-ui/
│       │
│       ├── 5.2.2-rag-system/
│       │   ├── README.md
│       │   ├── cloudformation/
│       │   │   ├── opensearch.yaml
│       │   │   └── rag-pipeline.yaml
│       │   ├── backend/
│       │   │   ├── embeddings/
│       │   │   └── retrieval/
│       │   └── docs/
│       │       └── rag-architecture.md
│       │
│       └── 5.2.3-image-generation/
│           ├── README.md
│           ├── lambda/
│           │   └── image-generator/
│           └── docs/
│               └── image-gen-guide.md
│
├── 06-cicd-advanced/
│   ├── README.md
│   ├── 6.1-automation-pipeline/
│   │   ├── 6.1.1-multi-stage-build/
│   │   │   ├── README.md
│   │   │   ├── cloudformation/
│   │   │   │   └── codepipeline.yaml
│   │   │   └── docs/
│   │   │       └── pipeline-guide.md
│   │   │
│   │   └── 6.1.2-test-automation/
│   │       ├── README.md
│   │       ├── tests/
│   │       │   ├── unit/
│   │       │   ├── integration/
│   │       │   └── e2e/
│   │       └── docs/
│   │           └── testing-strategy.md
│   │
│   └── 6.2-monitoring-optimization/
│       ├── 6.2.1-apm-implementation/
│       │   ├── README.md
│       │   ├── cloudformation/
│       │   │   └── xray-config.yaml
│       │   └── docs/
│       │       └── tracing-guide.md
│       │
│       └── 6.2.2-cost-optimization/
│           ├── README.md
│           ├── scripts/
│           │   └── cost-analyzer.py
│           └── docs/
│               └── cost-guide.md
│
├── shared-resources/
│   ├── cloudformation/
│   │   ├── parameters/              # 環境別パラメータ
│   │   │   ├── dev.json
│   │   │   ├── staging.json
│   │   │   └── prod.json
│   │   └── templates/               # 再利用可能なテンプレート
│   │       ├── vpc-template.yaml
│   │       └── ecs-template.yaml
│   ├── modules/                     # 共通モジュール
│   │   ├── auth/
│   │   ├── logging/
│   │   └── monitoring/
│   └── utilities/                   # ユーティリティスクリプト
│       ├── stack-deploy.sh
│       └── resource-tagger.py
│
└── docs/
    ├── architecture/                # アーキテクチャドキュメント
    │   ├── overview.md
    │   └── decision-records/
    ├── runbooks/                    # 運用手順書
    │   ├── deployment.md
    │   └── troubleshooting.md
    └── learning-path.md             # 学習パス全体のガイド
```

## 各ディレクトリの説明

### ルートレベル
- **README.md**: プロジェクト全体の概要、学習目標、前提条件
- **.github/**: CI/CDワークフローとIssueテンプレート
- **scripts/**: 環境セットアップとクリーンアップ用スクリプト

### 各学習ユニット（01-06）
- **README.md**: そのセクションの学習目標と概要
- **cloudformation/**: インフラ定義ファイル
- **docs/**: 詳細なドキュメントとガイド
- **src/**, **backend/**, **frontend/**: 実際のアプリケーションコード
- **tests/**: テストコード

### 共有リソース
- **shared-resources/**: 複数のユニットで使用する共通コンポーネント
- **docs/**: プロジェクト全体に関わるドキュメント

## ファイル命名規則

### CloudFormationテンプレート
- `{リソース名}-{目的}.yaml`
- 例: `vpc-main.yaml`, `ecs-service.yaml`

### ドキュメント
- `{トピック}-guide.md`: 実装ガイド
- `{トピック}-spec.md`: 仕様書
- `troubleshoot.md`: トラブルシューティング

### スクリプト
- `{動作}-{対象}.sh`: シェルスクリプト
- `{機能}.py`: Pythonスクリプト

## 使用方法

1. **順次学習**: 01から順番に進める
2. **選択学習**: 興味のあるトピックから始める
3. **プロジェクト作成**: 学んだ内容を組み合わせて独自プロジェクトを作成

各ユニットは独立して動作するよう設計されていますが、前のユニットの知識を前提とする場合があります。