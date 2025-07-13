# 06-CI-CD高度化編

## 🚀 モジュール概要

**学習時間**: 10時間 | **レベル**: 中級〜上級 | **前提モジュール**: 02-03完了

このモジュールでは、モジュール02-03で構築したWebアプリケーションに対して、エンタープライズレベルのCI/CDパイプラインと運用監視システムを実装します。実践的なDevOpsスキルを身につけ、本番環境での継続的デリバリーを実現します。

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
- ✅ **モジュール02-03完了**: Webアプリケーションが構築済み
- ✅ **AWSアカウント**: CodePipeline、CodeBuild等のアクセス権限
- ✅ **GitHubアカウント**: リポジトリとActions使用権限
- ✅ **開発環境**: Docker、Node.js、Python3インストール済み

### 環境確認

```bash
# AWS CLI確認
aws --version
aws sts get-caller-identity

# Docker確認（コンテナビルド用）
docker --version

# Node.js確認（テスト用）
node --version  # v16以上推奨
npm --version

# Python確認（スクリプト用）
python3 --version  # 3.8以上推奨

# GitHub CLI確認（リポジトリ連携用）
gh --version
gh auth status
```

## 🚀 クイックスタート

### Step 1: 基盤セットアップ

```bash
# モジュール02-03のアプリケーションスタック確認
aws cloudformation describe-stacks \
  --stack-name web-app-stack \
  --query 'Stacks[0].Outputs'

# CI/CD用のパラメータ設定
cp parameters/example.json parameters/my-config.json
# parameters/my-config.jsonを編集して環境に合わせる
```

### Step 2: CI/CDパイプライン構築

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