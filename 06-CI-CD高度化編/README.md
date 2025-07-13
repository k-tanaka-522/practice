# 06-CI-CD高度化編

## 🚀 モジュール概要

**学習時間**: 10時間 | **レベル**: 中級〜上級 | **前提モジュール**: 02-03完了

このモジュールでは、**Infrastructure as Code (IaC) ファースト**のアプローチで、Webアプリケーションの構築からCI/CDパイプライン、運用監視まですべてをCloudFormationで自動化します。モジュール02-03の知識をベースに、実践的なDevOpsスキルを身につけ、本番環境での継続的デリバリーを実現します。

## 🔄 IaC ファーストアプローチ

従来の「手動構築→自動化」ではなく、**最初からすべてをコードで定義**します：

```yaml
学習フロー:
  1. IaCでWebアプリケーション構築
  2. CI/CDパイプラインの統合
  3. テスト自動化の実装
  4. 監視・運用の自動化
  5. すべてがコードで管理される状態
```

## 🎯 学習目標

### 主要スキル習得
- 🚀 **マルチステージパイプライン**: 開発・ステージング・本番環境の完全自動化
- 🧪 **包括的テスト自動化**: 単体・統合・E2E・セキュリティテストの統合
- 📊 **高度な監視とAPM**: 分散トレーシング、カスタムメトリクス、予防的アラート
- 🔄 **高度なデプロイ戦略**: Blue/Green、カナリア、フィーチャーフラグ
- 💰 **コスト最適化**: 自動スケーリング、リソース最適化、予算管理
- 🛡️ **セキュリティ統合**: SAST/DAST、脆弱性スキャン、コンプライアンス

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────────┐
│                      Source Control                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │   GitHub    │  │  GitLab     │  │ CodeCommit  │  │ Bitbucket│ │
│  │             │  │             │  │             │  │         │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CI/CD Pipeline                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │CodePipeline │  │  CodeBuild  │  │ CodeDeploy  │  │ Jenkins │ │
│  │             │  │             │  │             │  │         │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Test Automation                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │  Unit Tests │  │Integration  │  │  E2E Tests  │  │Security │ │
│  │    Jest     │  │   Tests     │  │  Selenium   │  │  Scans  │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Multi-Stage Deployment                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │Development  │  │   Staging   │  │ Production  │  │   DR    │ │
│  │Environment  │  │Environment  │  │Environment  │  │  Site   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              Monitoring & Observability                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │   X-Ray     │  │ CloudWatch  │  │Application  │  │  Cost   │ │
│  │  Tracing    │  │   Metrics   │  │  Insights   │  │Monitor  │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 📚 学習パス

### 6.1 自動化パイプライン（4時間）
- **6.1.1** [マルチステージビルド](6.1-自動化パイプライン/6.1.1-マルチステージビルド/README.md)
  - CodePipeline/GitHub Actions統合
  - マルチ環境デプロイメント
  - 承認ワークフロー
- **6.1.2** [テスト自動化](6.1-自動化パイプライン/6.1.2-テスト自動化/README.md)
  - テストピラミッド実装
  - 品質ゲート設定
  - テストレポート統合

### 6.2 高度なデプロイ戦略（3時間）
- **6.2.1** [Blue/Greenデプロイメント](6.2-高度なデプロイ戦略/6.2.1-BlueGreenデプロイ/README.md)
  - ECS/EC2でのBlue/Green実装
  - トラフィック切り替え戦略
  - 自動ロールバック
- **6.2.2** [カナリアリリース](6.2-高度なデプロイ戦略/6.2.2-カナリアリリース/README.md)
  - Lambda@Edgeでのカナリア
  - 段階的ロールアウト
  - メトリクスベース判定

### 6.3 モニタリングと最適化（3時間）
- **6.3.1** [APM実装](6.3-モニタリングと最適化/6.3.1-APM実装/README.md)
  - X-Ray分散トレーシング
  - カスタムダッシュボード
  - SLO/SLI設定
- **6.3.2** [コスト最適化](6.3-モニタリングと最適化/6.3.2-コスト最適化/README.md)
  - 自動リソース管理
  - 予算アラート
  - 使用量分析

## 🏗️ 前提条件

### 必須要件
- ✅ **モジュール02-03の知識**: Webアプリケーションの概念理解（実際の構築は不要）
- ✅ **AWSアカウント**: Administrator権限（学習用）
- ✅ **GitHubアカウント**: リポジトリとActions使用権限
- ✅ **開発環境**: Docker、Node.js、Python3インストール済み

### 🚀 IaC ファーストの利点

```yaml
従来のアプローチ（手動構築 → 自動化）:
  問題点:
    - モジュール02-03を先に手動構築 (4-6時間)
    - 手動作業のミス・不整合
    - 環境差異が発生しやすい
    - 学習時間の無駄

IaCファーストアプローチ（このモジュール）:
  利点:
    - すべてをコードで定義 (1-2時間)
    - ワンクリックデプロイ (10分)
    - 完全な再現性と一貫性
    - 本番レベルの品質を最初から
    - 真のDevOps/SREスキル習得
```

### 💡 学習の価値

このアプローチで学ぶことで：
- **即戦力**: 企業で求められる現代的なスキル
- **効率性**: 手動作業を排除した真の自動化
- **品質**: Infrastructure as Codeによる高品質な構築
- **実用性**: そのまま本番環境に適用可能

### 必須ツールのインストール

#### 1. AWS CLI
```bash
# macOS
brew install awscli

# Windows
winget install Amazon.AWSCLI

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

#### 2. GitHub CLI
```bash
# macOS
brew install gh

# Windows
winget install GitHub.cli

# Linux (Ubuntu/Debian)
sudo apt update
sudo apt install gh

# Linux (RHEL/CentOS)
sudo yum install gh
```

#### 3. その他の必須ツール
```bash
# Docker（コンテナビルド用）
# https://docs.docker.com/get-docker/

# Node.js（テスト用）
# https://nodejs.org/ - v16以上推奨

# Python3（スクリプト用）
# https://www.python.org/ - 3.8以上推奨
```

### 環境確認

```bash
# すべてのツールが正しくインストールされているか確認
aws --version
aws sts get-caller-identity

gh --version
gh auth status

docker --version
node --version
npm --version
python3 --version
```

## 🚀 実践的ハンズオン: リアルなチーム開発体験

### 🎯 実践シナリオ

**このリポジトリを自分のGitHubアカウントでforkし、実際のチーム開発環境を構築します**

```yaml
学習内容:
  - GitHub Actions完全実装
  - ブランチ戦略 (Git Flow)
  - マルチ環境デプロイ (dev/staging/prod)
  - プルリクエストベースのワークフロー
  - 自動テスト・承認フロー
  - 本番デプロイの承認制御
```

### Step 1: リポジトリセットアップ

```bash
# 1. このリポジトリをfork（GitHubのWebUIで）
# Fork: https://github.com/original-repo/ai-driven-development-practice

# 2. 自分のリポジトリをclone
git clone https://github.com/YOUR_USERNAME/ai-driven-development-practice.git
cd ai-driven-development-practice

# 3. ブランチ戦略セットアップ
git checkout -b develop
git push origin develop

git checkout -b staging  
git push origin staging

# main = production環境
# staging = ステージング環境  
# develop = 開発環境
```

### Step 2: GitHub認証とシークレット設定

```bash
# GitHub CLI認証
gh auth login
# ブラウザが開いて認証フローが開始されます

# 認証確認
gh auth status

# AWS認証情報をシークレットに設定
gh secret set AWS_ACCESS_KEY_ID --body "YOUR_ACCESS_KEY"
gh secret set AWS_SECRET_ACCESS_KEY --body "YOUR_SECRET_KEY"
gh secret set AWS_REGION --body "ap-northeast-1"
gh secret set AWS_ACCOUNT_ID --body "$(aws sts get-caller-identity --query Account --output text)"

# 環境別シークレット設定
gh secret set DEV_STACK_NAME --body "my-app-dev"
gh secret set STAGING_STACK_NAME --body "my-app-staging"  
gh secret set PROD_STACK_NAME --body "my-app-prod"

# Slack通知用（オプション）
# gh secret set SLACK_WEBHOOK --body "YOUR_SLACK_WEBHOOK_URL"

# 設定確認
gh secret list
```

### Step 3: GitHub Actions ワークフロー作成

```bash
# .github/workflows/ディレクトリ作成
mkdir -p .github/workflows

# メインのCI/CDワークフローを作成
cat > .github/workflows/cicd.yml << 'EOF'
name: 🚀 CI/CD Pipeline

on:
  push:
    branches: [develop, staging, main]
  pull_request:
    branches: [develop, staging, main]

env:
  AWS_REGION: ap-northeast-1

jobs:
  # 🧪 テスト・品質チェック
  test:
    name: 🧪 Test & Quality Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
          cache-dependency-path: '**/package-lock.json'
      
      - name: Install dependencies
        run: npm ci
        working-directory: 02-Webサービス基礎編/web
      
      - name: 🔍 Lint check
        run: npm run lint
        working-directory: 02-Webサービス基礎編/web
      
      - name: 🧪 Unit tests
        run: npm run test:unit -- --coverage
        working-directory: 02-Webサービス基礎編/web
      
      - name: 📊 Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./02-Webサービス基礎編/web/coverage/lcov.info

  # 🔒 セキュリティスキャン
  security:
    name: 🔒 Security Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: 🛡️ Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
      
      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

  # 🏗️ ビルド・デプロイ（develop環境）
  deploy-dev:
    name: 🏗️ Deploy to DEV
    runs-on: ubuntu-latest
    needs: [test, security]
    if: github.ref == 'refs/heads/develop' && github.event_name == 'push'
    environment: development
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: 🚀 Deploy CloudFormation
        run: |
          aws cloudformation deploy \
            --template-file 02-Webサービス基礎編/cloudformation/main-stack.yaml \
            --stack-name ${{ secrets.DEV_STACK_NAME }} \
            --parameter-overrides \
              Environment=dev \
              ProjectName=my-web-app \
            --capabilities CAPABILITY_NAMED_IAM \
            --tags Environment=dev Project=learning
      
      - name: 📋 Get deployment info
        run: |
          aws cloudformation describe-stacks \
            --stack-name ${{ secrets.DEV_STACK_NAME }} \
            --query 'Stacks[0].Outputs'

  # 🎭 ステージング環境デプロイ
  deploy-staging:
    name: 🎭 Deploy to STAGING
    runs-on: ubuntu-latest
    needs: [test, security]
    if: github.ref == 'refs/heads/staging' && github.event_name == 'push'
    environment: staging
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: 🧪 Integration tests first
        run: |
          # ステージング環境特有の統合テスト
          echo "Running integration tests..."
          npm run test:integration
        working-directory: 02-Webサービス基礎編/web
      
      - name: 🚀 Deploy to Staging
        run: |
          aws cloudformation deploy \
            --template-file 02-Webサービス基礎編/cloudformation/main-stack.yaml \
            --stack-name ${{ secrets.STAGING_STACK_NAME }} \
            --parameter-overrides \
              Environment=staging \
              ProjectName=my-web-app \
            --capabilities CAPABILITY_NAMED_IAM \
            --tags Environment=staging Project=learning

  # 🏭 本番環境デプロイ（手動承認必須）
  deploy-production:
    name: 🏭 Deploy to PRODUCTION
    runs-on: ubuntu-latest
    needs: [test, security]
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: production  # GitHub環境保護ルール適用
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: 🔍 Pre-deployment checks
        run: |
          echo "🔍 Performing pre-deployment safety checks..."
          # 本番前の最終チェック
          npm run test:e2e
        working-directory: 02-Webサービス基礎編/web
      
      - name: 🚀 Deploy to Production
        run: |
          aws cloudformation deploy \
            --template-file 02-Webサービス基礎編/cloudformation/main-stack.yaml \
            --stack-name ${{ secrets.PROD_STACK_NAME }} \
            --parameter-overrides \
              Environment=prod \
              ProjectName=my-web-app \
            --capabilities CAPABILITY_NAMED_IAM \
            --tags Environment=prod Project=learning
      
      - name: 🎉 Success notification
        if: success()
        run: |
          echo "🎉 Production deployment successful!"
          # Slack通知など
EOF
```

### Step 4: GitHub環境保護とブランチルール設定

```bash
# 本番環境保護設定（手動承認必須）
gh api repos/:owner/:repo/environments/production -X PUT --input - << 'EOF'
{
  "protection_rules": [
    {
      "type": "required_reviewers",
      "reviewers": [
        {"type": "User", "id": null}
      ]
    },
    {
      "type": "wait_timer", 
      "minutes": 5
    }
  ],
  "deployment_branch_policy": {
    "protected_branches": true,
    "custom_branch_policies": false
  }
}
EOF

# mainブランチ保護ルール
gh api repos/:owner/:repo/branches/main/protection -X PUT --input - << 'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["🧪 Test & Quality Check", "🔒 Security Scan"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

# staging/developブランチも同様に保護（オプション）
gh api repos/:owner/:repo/branches/staging/protection -X PUT --input - << 'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["🧪 Test & Quality Check", "🔒 Security Scan"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "restrictions": null
}
EOF
```

```bash
# GitHub連携設定
gh repo create my-web-app --public
gh secret set AWS_ACCOUNT_ID --body "$(aws sts get-caller-identity --query Account --output text)"
gh secret set AWS_REGION --body "ap-northeast-1"

# CI/CD基盤の一括デプロイ
./scripts/deploy-cicd.sh --config parameters/my-config.json deploy-all

# 個別デプロイ（オプション）
./scripts/deploy-cicd.sh deploy-pipeline    # パイプライン構築
./scripts/deploy-cicd.sh deploy-testing     # テスト自動化
./scripts/deploy-cicd.sh deploy-monitoring  # 監視設定
./scripts/deploy-cicd.sh deploy-optimization # 最適化設定
```

### Step 3: 動作確認

```bash
# パイプライン状態確認
./scripts/check-pipeline-status.sh

# テスト実行
npm run test:all

# 監視ダッシュボード確認
aws cloudformation describe-stacks \
  --stack-name cicd-monitoring-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`DashboardURL`].OutputValue' \
  --output text
```

## 📋 学習コンテンツ詳細

### 🚀 6.1.1 マルチステージビルド

**学習内容:**
- CI/CDパイプライン設計パターン
- マルチステージデプロイメント戦略
- ブランチ戦略とGitFlow実装
- 環境別設定管理

**実装内容:**
- CodePipeline/GitHub Actions統合
- マルチ環境自動デプロイ
- 承認ワークフローとゲート
- アーティファクト管理

**ハンズオン演習:**
1. モジュール02のWebアプリにCI/CD追加
2. dev→staging→prodの3環境構築
3. 手動承認ゲートの実装
4. 自動ロールバック設定

**主要技術:**
- AWS CodePipeline / GitHub Actions
- AWS CodeBuild
- AWS CodeDeploy
- AWS Systems Manager

### 🧪 6.1.2 テスト自動化

**学習内容:**
- テストピラミッド戦略
- 継続的品質管理
- セキュリティテスト統合
- パフォーマンステスト

**実装内容:**
- モジュール03のCRUD APIテスト
- 認証フローのE2Eテスト
- 負荷テストとベンチマーク
- コードカバレッジ分析

**ハンズオン演習:**
1. CRUD操作の単体テスト作成
2. API統合テストスイート構築
3. Cypressでのユーザーフローテスト
4. JMeterでの負荷テスト実装

**主要技術:**
- Jest / Vitest
- Cypress / Playwright
- Apache JMeter / K6
- SonarQube / CodeGuru

### 🔄 6.2.1 Blue/Greenデプロイメント

**学習内容:**
- Blue/Green戦略の理解
- ゼロダウンタイムデプロイ
- トラフィック切り替え手法
- ロールバック戦略

**実装内容:**
- ECS Blue/Greenデプロイ
- ALBターゲットグループ切り替え
- Route 53重み付けルーティング
- 自動化されたヘルスチェック

**ハンズオン演習:**
1. モジュール02アプリのBlue/Green化
2. 自動切り替えスクリプト作成
3. ロールバックシナリオ実践
4. A/Bテスト実装

**主要技術:**
- AWS CodeDeploy
- Amazon ECS / EC2
- Application Load Balancer
- Route 53

### 🚦 6.2.2 カナリアリリース

**学習内容:**
- カナリアデプロイメント戦略
- 段階的ロールアウト
- メトリクスベース判定
- フィーチャーフラグ

**実装内容:**
- Lambda加重エイリアス
- API Gatewayカナリア設定
- CloudFront段階的配信
- 自動ロールバック条件

**ハンズオン演習:**
1. 10%→50%→100%の段階リリース
2. エラー率ベースの自動判定
3. フィーチャートグル実装
4. A/Bテストメトリクス収集

**主要技術:**
- AWS Lambda Aliases
- API Gateway Stages
- CloudWatch Alarms
- AWS AppConfig

### 📊 6.3.1 APM実装

**学習内容:**
- 分散トレーシング戦略
- SLO/SLI定義と監視
- カスタムメトリクス設計
- インシデント対応自動化

**実装内容:**
- X-Ray完全統合
- ビジネスメトリクス追跡
- 異常検知アラート
- 自動修復アクション

**ハンズオン演習:**
1. エンドツーエンドトレース実装
2. SLOダッシュボード作成
3. 予防的アラート設定
4. PagerDuty/Slack統合

**主要技術:**
- AWS X-Ray
- CloudWatch Synthetics
- CloudWatch Anomaly Detector
- AWS Systems Manager

### 💰 6.3.2 コスト最適化

**学習内容:**
- コスト可視化戦略
- リソース使用最適化
- 予算管理と予測
- FinOpsプラクティス

**実装内容:**
- タグベースコスト配分
- 自動スケーリング最適化
- スポットインスタンス活用
- 未使用リソース自動削除

**ハンズオン演習:**
1. コスト配分ダッシュボード構築
2. 開発環境の自動停止設定
3. リザーブドインスタンス分析
4. 月次コストレポート自動化

**主要技術:**
- AWS Cost Explorer
- AWS Budgets
- AWS Compute Optimizer
- AWS Trusted Advisor

## 🏗️ 実装手順

### Step 1: GitHub Actions パイプライン構築

```bash
# モジュール02-03のアプリケーションリポジトリに移動
cd ../02-Web三層アーキテクチャ編/my-web-app

# GitHub Actions ワークフロー作成
mkdir -p .github/workflows
cp ../../06-CI-CD高度化編/templates/github-actions/* .github/workflows/

# シークレット設定
gh secret set AWS_ACCOUNT_ID --body "$(aws sts get-caller-identity --query Account --output text)"
gh secret set AWS_REGION --body "ap-northeast-1"
gh secret set ECR_REPOSITORY --body "my-web-app"

# プッシュしてワークフロー起動
git add .
git commit -m "Add CI/CD pipeline"
git push origin main
```

### Step 2: CodePipeline マルチステージ構築

```bash
# パラメータファイル準備
cat > parameters.json << EOF
[
  {"ParameterKey": "ApplicationName", "ParameterValue": "my-web-app"},
  {"ParameterKey": "GitHubRepo", "ParameterValue": "${GITHUB_USER}/my-web-app"},
  {"ParameterKey": "GitHubToken", "ParameterValue": "${GITHUB_TOKEN}"}
]
EOF

# パイプライン作成
aws cloudformation create-stack \
  --stack-name my-web-app-pipeline \
  --template-body file://06-CI-CD高度化編/6.1-自動化パイプライン/6.1.1-マルチステージビルド/cloudformation/codepipeline-multistage.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 3: テスト自動化実装

```bash
# テストプロジェクトセットアップ
cd tests
npm init -y
npm install --save-dev jest @types/jest supertest cypress

# テスト構造作成
mkdir -p unit integration e2e performance security

# テストスクリプト設定
cat > package.json << EOF
{
  "scripts": {
    "test:unit": "jest unit --coverage",
    "test:integration": "jest integration",
    "test:e2e": "cypress run",
    "test:performance": "k6 run performance/load-test.js",
    "test:security": "npm audit && snyk test",
    "test:all": "npm run test:unit && npm run test:integration && npm run test:e2e"
  }
}
EOF

# CI/CDパイプラインにテスト統合
aws cloudformation update-stack \
  --stack-name test-automation-stack \
  --template-body file://06-CI-CD高度化編/6.1-自動化パイプライン/6.1.2-テスト自動化/cloudformation/test-automation.yaml \
  --capabilities CAPABILITY_IAM
```

### Step 4: Blue/Greenデプロイメント設定

```bash
# ECS Blue/Greenデプロイ設定
aws cloudformation create-stack \
  --stack-name blue-green-deployment \
  --template-body file://06-CI-CD高度化編/6.2-高度なデプロイ戦略/6.2.1-BlueGreenデプロイ/cloudformation/blue-green-ecs.yaml \
  --parameters ParameterKey=ApplicationName,ParameterValue=my-web-app \
  --capabilities CAPABILITY_NAMED_IAM

# デプロイメントテスト
./scripts/test-blue-green-deployment.sh
```

### Step 5: 包括的監視システム構築

```bash
# X-Ray統合
aws cloudformation create-stack \
  --stack-name apm-monitoring \
  --template-body file://06-CI-CD高度化編/6.3-モニタリングと最適化/6.3.1-APM実装/cloudformation/x-ray-monitoring.yaml \
  --parameters ParameterKey=ApplicationName,ParameterValue=my-web-app \
               ParameterKey=AlertEmail,ParameterValue=your-email@example.com \
  --capabilities CAPABILITY_IAM

# カスタムダッシュボード作成
./scripts/create-custom-dashboard.sh --app-name my-web-app
```

### Step 6: コスト最適化とFinOps実装

```bash
# コスト最適化スタック作成
aws cloudformation create-stack \
  --stack-name cost-optimization \
  --template-body file://06-CI-CD高度化編/6.3-モニタリングと最適化/6.3.2-コスト最適化/cloudformation/cost-optimization.yaml \
  --parameters ParameterKey=MonthlyBudget,ParameterValue=500 \
               ParameterKey=Environment,ParameterValue=production \
  --capabilities CAPABILITY_IAM

# 自動スケジューラー設定
./scripts/setup-resource-scheduler.sh --env dev --stop-time "19:00" --start-time "08:00"
```

## 📋 実装例とテンプレート

### GitHub Actions ワークフロー例

```yaml
# .github/workflows/ci-cd-pipeline.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  AWS_REGION: ap-northeast-1
  ECR_REPOSITORY: my-web-app

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: |
          npm run test:unit -- --coverage
          npm run test:integration
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage/lcov.info
  
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
      
      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
  
  build-and-push:
    needs: [test, security-scan]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build and push image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
  
  deploy-staging:
    needs: build-and-push
    runs-on: ubuntu-latest
    environment: staging
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to staging
        run: |
          aws ecs update-service \
            --cluster staging-cluster \
            --service my-web-app \
            --force-new-deployment
  
  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to production
        run: |
          aws deploy create-deployment \
            --application-name my-web-app \
            --deployment-group-name production \
            --deployment-config-name CodeDeployDefault.ECSBlueGreen
```

### CodeBuild buildspec.yml 例

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}
  
  build:
    commands:
      - echo Build started on `date`
      - echo Installing dependencies...
      - npm ci
      - echo Running linting...
      - npm run lint
      - echo Running unit tests...
      - npm run test:unit
      - echo Running security scan...
      - npm audit --audit-level moderate
      - echo Building the Docker image...
      - docker build -t $IMAGE_REPO_NAME:$IMAGE_TAG .
      - docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $REPOSITORY_URI:$IMAGE_TAG
  
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker image...
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - echo Writing image definitions file...
      - printf '[{"name":"app","imageUri":"%s"}]' $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json
      - echo Generating deployment artifacts...
      - zip -r deployment.zip infrastructure/ scripts/ imagedefinitions.json

artifacts:
  files:
    - imagedefinitions.json
    - deployment.zip
    - infrastructure/**/*
  name: BuildArtifact

reports:
  test-reports:
    files:
      - 'coverage/lcov.info'
      - 'test-results.xml'
    base-directory: .
  security-reports:
    files:
      - 'security-scan-results.json'
    base-directory: .
```

## 🧪 テスト戦略とベストプラクティス

### 包括的テストピラミッド

```javascript
// 単体テスト例 (Jest)
describe('UserService', () => {
  let userService;
  
  beforeEach(() => {
    userService = new UserService();
  });
  
  describe('createUser', () => {
    it('should create a new user with valid data', async () => {
      const userData = {
        email: 'test@example.com',
        name: 'Test User'
      };
      
      const result = await userService.createUser(userData);
      
      expect(result).toHaveProperty('id');
      expect(result.email).toBe(userData.email);
    });
    
    it('should throw error with invalid email', async () => {
      const userData = {
        email: 'invalid-email',
        name: 'Test User'
      };
      
      await expect(userService.createUser(userData))
        .rejects.toThrow('Invalid email format');
    });
  });
});

// 統合テスト例
describe('API Integration Tests', () => {
  let app;
  
  beforeAll(async () => {
    app = await createTestApp();
  });
  
  afterAll(async () => {
    await app.close();
  });
  
  describe('POST /users', () => {
    it('should create user and return 201', async () => {
      const response = await request(app)
        .post('/users')
        .send({
          email: 'test@example.com',
          name: 'Test User'
        })
        .expect(201);
      
      expect(response.body).toHaveProperty('id');
    });
  });
});

// E2Eテスト例 (Selenium)
const { Builder, By, until } = require('selenium-webdriver');

describe('User Registration Flow', () => {
  let driver;
  
  beforeAll(async () => {
    driver = await new Builder().forBrowser('chrome').build();
  });
  
  afterAll(async () => {
    await driver.quit();
  });
  
  it('should complete user registration', async () => {
    await driver.get('http://localhost:3000/register');
    
    await driver.findElement(By.id('email')).sendKeys('test@example.com');
    await driver.findElement(By.id('password')).sendKeys('password123');
    await driver.findElement(By.id('submit')).click();
    
    await driver.wait(until.elementLocated(By.id('success-message')), 5000);
    
    const successMessage = await driver.findElement(By.id('success-message')).getText();
    expect(successMessage).toContain('Registration successful');
  });
});
```

## 📊 高度な監視とオブザーバビリティ

### 分散トレーシングとカスタムメトリクス

```python
# Lambda関数でのカスタムメトリクス
import boto3
import time
from datetime import datetime

cloudwatch = boto3.client('cloudwatch')

def send_business_metrics(event, context):
    # ビジネスメトリクス
    cloudwatch.put_metric_data(
        Namespace='MyApp/Business',
        MetricData=[
            {
                'MetricName': 'UserRegistrations',
                'Value': get_user_registrations_count(),
                'Unit': 'Count',
                'Dimensions': [
                    {
                        'Name': 'Environment',
                        'Value': os.environ['ENVIRONMENT']
                    }
                ]
            },
            {
                'MetricName': 'Revenue',
                'Value': get_daily_revenue(),
                'Unit': 'None',
                'Dimensions': [
                    {
                        'Name': 'Environment',
                        'Value': os.environ['ENVIRONMENT']
                    }
                ]
            }
        ]
    )
    
    # パフォーマンスメトリクス
    start_time = time.time()
    process_business_logic()
    processing_time = (time.time() - start_time) * 1000
    
    cloudwatch.put_metric_data(
        Namespace='MyApp/Performance',
        MetricData=[
            {
                'MetricName': 'ProcessingTime',
                'Value': processing_time,
                'Unit': 'Milliseconds'
            }
        ]
    )

def get_user_registrations_count():
    # DynamoDBから本日の登録者数を取得
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('Users')
    
    today = datetime.now().strftime('%Y-%m-%d')
    
    response = table.scan(
        FilterExpression='created_date = :date',
        ExpressionAttributeValues={':date': today}
    )
    
    return response['Count']
```

### アラート設定例

```yaml
# CloudWatch Alarms
HighErrorRateAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: HighErrorRate
    AlarmDescription: Error rate exceeded threshold
    MetricName: 4XXError
    Namespace: AWS/ApiGateway
    Statistic: Sum
    Period: 300
    EvaluationPeriods: 2
    Threshold: 10
    ComparisonOperator: GreaterThanThreshold
    AlarmActions:
      - !Ref SNSTopic
    Dimensions:
      - Name: ApiName
        Value: !Ref ApiGateway

LowUserActivityAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: LowUserActivity
    AlarmDescription: User activity is below normal
    MetricName: UserRegistrations
    Namespace: MyApp/Business
    Statistic: Sum
    Period: 3600
    EvaluationPeriods: 1
    Threshold: 5
    ComparisonOperator: LessThanThreshold
    TreatMissingData: breaching
    AlarmActions:
      - !Ref SNSTopic
```

## 💰 FinOpsとコスト最適化

### 自動化されたコスト管理

```python
# Lambda関数による自動リソース停止
import boto3
from datetime import datetime, time

def auto_stop_resources(event, context):
    ec2 = boto3.client('ec2')
    rds = boto3.client('rds')
    
    # 開発環境のEC2インスタンスを夜間停止
    if is_night_time() and is_weekday():
        dev_instances = ec2.describe_instances(
            Filters=[
                {'Name': 'tag:Environment', 'Values': ['dev']},
                {'Name': 'instance-state-name', 'Values': ['running']}
            ]
        )
        
        for reservation in dev_instances['Reservations']:
            for instance in reservation['Instances']:
                ec2.stop_instances(InstanceIds=[instance['InstanceId']])
                print(f"Stopped instance: {instance['InstanceId']}")
    
    # 開発環境のRDSインスタンスを停止
    if is_night_time():
        dev_databases = rds.describe_db_instances()
        
        for db in dev_databases['DBInstances']:
            if has_tag(db['DBInstanceArn'], 'Environment', 'dev'):
                if db['DBInstanceStatus'] == 'available':
                    rds.stop_db_instance(
                        DBInstanceIdentifier=db['DBInstanceIdentifier']
                    )
                    print(f"Stopped RDS: {db['DBInstanceIdentifier']}")

def is_night_time():
    current_hour = datetime.now().hour
    return current_hour >= 22 or current_hour <= 6

def is_weekday():
    return datetime.now().weekday() < 5

def has_tag(resource_arn, tag_key, tag_value):
    # タグチェック実装
    pass
```

### コスト監視ダッシュボード

```python
# コスト分析Lambda関数
import boto3
import json
from datetime import datetime, timedelta

def analyze_costs(event, context):
    ce = boto3.client('ce')
    sns = boto3.client('sns')
    
    # 過去30日のコスト取得
    end_date = datetime.now().strftime('%Y-%m-%d')
    start_date = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
    
    response = ce.get_cost_and_usage(
        TimePeriod={
            'Start': start_date,
            'End': end_date
        },
        Granularity='DAILY',
        Metrics=['BlendedCost'],
        GroupBy=[
            {
                'Type': 'DIMENSION',
                'Key': 'SERVICE'
            }
        ]
    )
    
    # コスト分析
    total_cost = 0
    service_costs = {}
    
    for result in response['ResultsByTime']:
        for group in result['Groups']:
            service = group['Keys'][0]
            cost = float(group['Metrics']['BlendedCost']['Amount'])
            total_cost += cost
            
            if service not in service_costs:
                service_costs[service] = 0
            service_costs[service] += cost
    
    # 予算超過アラート
    monthly_budget = 1000  # $1000予算
    if total_cost > monthly_budget * 0.8:  # 80%到達時アラート
        send_cost_alert(total_cost, monthly_budget, service_costs)
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'total_cost': total_cost,
            'service_breakdown': service_costs
        })
    }

def send_cost_alert(current_cost, budget, breakdown):
    message = f"""
    AWS Cost Alert!
    
    Current monthly cost: ${current_cost:.2f}
    Budget: ${budget:.2f}
    Usage: {(current_cost/budget)*100:.1f}%
    
    Top 5 services by cost:
    """
    
    sorted_services = sorted(breakdown.items(), key=lambda x: x[1], reverse=True)[:5]
    for service, cost in sorted_services:
        message += f"\n- {service}: ${cost:.2f}"
    
    sns.publish(
        TopicArn=os.environ['COST_ALERT_TOPIC'],
        Message=message,
        Subject='AWS Cost Alert - Budget Threshold Reached'
    )
```

## 🛠️ 高度なデプロイメント戦略

### Blue/Greenデプロイメント実装

```yaml
# CodeDeploy設定
BlueGreenDeployment:
  Type: AWS::CodeDeploy::Application
  Properties:
    ApplicationName: !Sub '${ProjectName}-${EnvironmentName}-app'
    ComputePlatform: ECS

DeploymentGroup:
  Type: AWS::CodeDeploy::DeploymentGroup
  Properties:
    ApplicationName: !Ref BlueGreenDeployment
    DeploymentGroupName: !Sub '${ProjectName}-${EnvironmentName}-dg'
    ServiceRoleArn: !GetAtt CodeDeployRole.Arn
    BlueGreenDeploymentConfiguration:
      DeploymentReadyOption:
        ActionOnTimeout: CONTINUE_DEPLOYMENT
      GreenFleetProvisioningOption:
        Action: COPY_AUTO_SCALING_GROUP
      TerminateBlueInstancesOnDeploymentSuccess:
        Action: TERMINATE
        TerminationWaitTimeInMinutes: 5
```

### カナリアデプロイメント

```yaml
# Lambda Alias設定によるカナリアデプロイ
LambdaAlias:
  Type: AWS::Lambda::Alias
  Properties:
    FunctionName: !Ref LambdaFunction
    FunctionVersion: !GetAtt LambdaVersion.Version
    Name: live
    RoutingConfig:
      AdditionalVersionWeights:
        - FunctionVersion: !GetAtt LambdaVersion.Version
          FunctionWeight: 0.1  # 10%のトラフィックを新バージョンに
```

## 🔗 モジュール間の統合

### モジュール02-03との連携
- Webアプリケーションの自動デプロイ
- CRUD APIのテスト自動化
- 認証システムのセキュリティテスト
- ファイルアップロード機能の負荷テスト

### モジュール08への準備
- 運用監視基盤の確立
- インシデント対応プロセス
- SRE実践の基礎
- オブザーバビリティ文化

## 📚 参考資料とリソース

### 必読ドキュメント
- 📖 [AWS DevOps ホワイトペーパー](https://aws.amazon.com/devops/)
- 🔧 [GitHub Actions ベストプラクティス](https://docs.github.com/actions)
- 📊 [SRE ワークブック](https://sre.google/workbook/table-of-contents/)
- 💡 [FinOps Foundation](https://www.finops.org/)

### 推奨書籍
- 「The DevOps Handbook」- Gene Kim他
- 「Accelerate」- Nicole Forsgren他
- 「Site Reliability Engineering」- Google
- 「Cloud FinOps」- J.R. Storment他

### コミュニティとサポート
- AWS DevOps Blog
- GitHub Community
- CNCF Slack
- FinOps Slack

## 📈 次のステップ

### このモジュール完了後

1. **🤖 [07-Claude Code & Bedrock AI駆動開発編](../07-Claude-Code-Bedrock-AI駆動開発編/README.md)**
   - AI活用開発プロセス
   - 自動コード生成とレビュー
   - インテリジェントな運用

2. **🔧 08-運用とSRE編（次期リリース）**
   - プロダクション運用
   - SREプラクティス
   - 大規模システム管理

3. **🎯 実プロジェクトへの適用**
   - 学習内容の実装
   - カスタマイズと最適化
   - チーム展開

---

## 🎯 スキルチェックリスト

### 基礎スキル（必須）
- [ ] GitHub Actions/CodePipelineでのCI/CD構築
- [ ] マルチ環境へのデプロイメント管理
- [ ] 基本的なテスト自動化（単体・統合）
- [ ] CloudWatchでの基本監視

### 中級スキル（推奨）
- [ ] Blue/Greenデプロイメント実装
- [ ] E2Eテストとパフォーマンステスト
- [ ] X-Rayでの分散トレーシング
- [ ] コスト可視化とアラート

### 上級スキル（発展）
- [ ] カナリアリリースと段階的ロールアウト
- [ ] セキュリティテストの完全統合
- [ ] SLO/SLIベースの監視
- [ ] FinOps実践とコスト最適化

### プロジェクト成果物
- [ ] 完全自動化されたCI/CDパイプライン
- [ ] 包括的なテストスイート
- [ ] プロダクション級の監視システム
- [ ] コスト最適化の仕組み

## 🏁 モジュール完了基準

以下をすべて達成したら、このモジュールは完了です：

1. ✅ モジュール02-03のアプリケーションにCI/CD実装
2. ✅ 3つの環境（dev/staging/prod）への自動デプロイ
3. ✅ テストカバレッジ80%以上達成
4. ✅ Blue/Greenまたはカナリアデプロイ実装
5. ✅ 包括的な監視ダッシュボード構築
6. ✅ コスト削減20%以上の実現

---

<div align="center">

**🚀 DevOpsマスターへの道のり - 実践あるのみ！ 🚀**

[![Next Module](https://img.shields.io/badge/Next-07--AI駆動開発編-blue?style=for-the-badge)](../07-Claude-Code-Bedrock-AI駆動開発編/README.md)
[![Previous Module](https://img.shields.io/badge/Previous-05--AI--ML統合編-orange?style=for-the-badge)](../05-AI-ML統合編/README.md)

</div>