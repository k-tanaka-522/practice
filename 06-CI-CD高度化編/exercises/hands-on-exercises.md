# 06-CI-CD高度化編 ハンズオン演習

## 概要

このドキュメントでは、CI/CD高度化編で学習した内容を実践的に身につけるための段階的な演習を提供します。各演習は実際のプロジェクトシナリオに基づいており、実務で必要となるスキルを習得できます。

## 前提条件

- ✅ **モジュール02-03完了**: Webアプリケーションが稼働中
- ✅ **GitHub リポジトリ**: ソースコード管理用
- ✅ **AWS アカウント**: 必要なサービスへのアクセス権限
- ✅ **開発環境**: Docker、Node.js、Python3がインストール済み

## 演習1: 基本的なCI/CDパイプライン構築 (2時間)

### 目標
モジュール02で構築したWebアプリケーションに基本的なCI/CDパイプラインを追加し、自動デプロイを実現する。

### 手順

#### Step 1: GitHub Actions設定

```bash
# 1. GitHubリポジトリの準備
cd ../02-Web三層アーキテクチャ編/my-web-app
mkdir -p .github/workflows

# 2. CI/CDワークフローファイルをコピー
cp ../../06-CI-CD高度化編/templates/github-actions/ci-cd-pipeline.yml .github/workflows/

# 3. シークレット設定
gh secret set AWS_ACCESS_KEY_ID --body "YOUR_ACCESS_KEY"
gh secret set AWS_SECRET_ACCESS_KEY --body "YOUR_SECRET_KEY"
gh secret set AWS_ACCOUNT_ID --body "$(aws sts get-caller-identity --query Account --output text)"
gh secret set AWS_REGION --body "ap-northeast-1"
```

#### Step 2: CodePipeline デプロイ

```bash
# 1. パラメータファイル作成
cat > parameters.json << EOF
[
  {"ParameterKey": "ApplicationName", "ParameterValue": "my-web-app"},
  {"ParameterKey": "GitHubRepo", "ParameterValue": "${GITHUB_USER}/my-web-app"},
  {"ParameterKey": "GitHubToken", "ParameterValue": "${GITHUB_TOKEN}"},
  {"ParameterKey": "NotificationEmail", "ParameterValue": "your-email@example.com"}
]
EOF

# 2. パイプライン作成
aws cloudformation create-stack \
  --stack-name my-web-app-pipeline \
  --template-body file://../../06-CI-CD高度化編/6.1-自動化パイプライン/6.1.1-マルチステージビルド/cloudformation/codepipeline-multistage.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
```

#### Step 3: 動作確認

```bash
# 1. 変更をコミット・プッシュ
echo "// CI/CD Test" >> src/app.js
git add -A
git commit -m "Add CI/CD pipeline"
git push origin main

# 2. パイプライン実行確認
aws codepipeline get-pipeline-state --name my-web-app-production-pipeline
```

### 検証ポイント
- [ ] GitHub Actionsが正常に実行される
- [ ] CodePipelineが自動トリガーされる
- [ ] 各ステージ（ビルド、テスト、デプロイ）が成功する
- [ ] アプリケーションが正常にデプロイされる

### トラブルシューティング

**問題**: GitHub Actionsが失敗する
```bash
# 解決策: ログを確認
gh run list
gh run view [RUN_ID]
```

**問題**: CodeBuildでビルドが失敗する
```bash
# 解決策: CloudWatch Logsを確認
aws logs describe-log-groups --log-group-name-prefix /aws/codebuild/
aws logs get-log-events --log-group-name [LOG_GROUP] --log-stream-name [STREAM]
```

## 演習2: テスト自動化の実装 (3時間)

### 目標
包括的なテスト戦略を実装し、品質ゲートを含むCI/CDパイプラインを構築する。

### 手順

#### Step 1: テストプロジェクト構造作成

```bash
# 1. テストディレクトリ構造
mkdir -p tests/{unit,integration,e2e,performance}

# 2. package.json にテストスクリプト追加
cat >> package.json << EOF
{
  "scripts": {
    "test:unit": "jest --coverage",
    "test:integration": "jest --config jest.integration.config.js",
    "test:e2e": "cypress run",
    "test:performance": "k6 run tests/performance/load-test.js",
    "test:all": "npm run test:unit && npm run test:integration && npm run test:e2e"
  },
  "devDependencies": {
    "jest": "^29.0.0",
    "cypress": "^12.0.0",
    "@testing-library/react": "^13.0.0",
    "supertest": "^6.0.0"
  }
}
EOF
```

#### Step 2: 単体テスト実装

```javascript
// tests/unit/user.test.js
const { createUser, validateUser } = require('../../src/utils/user');

describe('User Utilities', () => {
  describe('createUser', () => {
    test('should create user with valid data', () => {
      const userData = {
        email: 'test@example.com',
        name: 'Test User'
      };
      
      const user = createUser(userData);
      
      expect(user).toHaveProperty('id');
      expect(user.email).toBe(userData.email);
      expect(user.name).toBe(userData.name);
    });

    test('should throw error for invalid email', () => {
      const userData = {
        email: 'invalid-email',
        name: 'Test User'
      };
      
      expect(() => createUser(userData)).toThrow('Invalid email');
    });
  });

  describe('validateUser', () => {
    test('should validate correct user data', () => {
      const user = {
        email: 'test@example.com',
        name: 'Test User'
      };
      
      expect(validateUser(user)).toBe(true);
    });
  });
});
```

#### Step 3: 統合テスト実装

```javascript
// tests/integration/api.test.js
const request = require('supertest');
const app = require('../../src/app');

describe('API Integration Tests', () => {
  describe('POST /api/users', () => {
    test('should create new user', async () => {
      const userData = {
        email: 'integration@example.com',
        name: 'Integration Test User'
      };

      const response = await request(app)
        .post('/api/users')
        .send(userData)
        .expect(201);

      expect(response.body).toHaveProperty('id');
      expect(response.body.email).toBe(userData.email);
    });

    test('should return 400 for invalid data', async () => {
      const response = await request(app)
        .post('/api/users')
        .send({ email: 'invalid' })
        .expect(400);

      expect(response.body).toHaveProperty('error');
    });
  });

  describe('GET /api/users', () => {
    test('should return user list', async () => {
      const response = await request(app)
        .get('/api/users')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });
});
```

#### Step 4: E2Eテスト実装

```javascript
// tests/e2e/user-flow.spec.js
describe('User Registration Flow', () => {
  beforeEach(() => {
    cy.visit('/');
  });

  it('should complete user registration', () => {
    // ホームページにアクセス
    cy.contains('Welcome').should('be.visible');
    
    // 登録ページに移動
    cy.get('[data-testid="register-button"]').click();
    
    // フォーム入力
    cy.get('[data-testid="email-input"]').type('e2e@example.com');
    cy.get('[data-testid="name-input"]').type('E2E Test User');
    cy.get('[data-testid="password-input"]').type('password123');
    
    // 登録実行
    cy.get('[data-testid="submit-button"]').click();
    
    // 成功確認
    cy.contains('Registration successful').should('be.visible');
    cy.url().should('include', '/dashboard');
  });

  it('should show validation errors for invalid input', () => {
    cy.get('[data-testid="register-button"]').click();
    
    // 無効なメール入力
    cy.get('[data-testid="email-input"]').type('invalid-email');
    cy.get('[data-testid="submit-button"]').click();
    
    // エラーメッセージ確認
    cy.contains('Invalid email format').should('be.visible');
  });
});
```

#### Step 5: パフォーマンステスト実装

```javascript
// tests/performance/load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 10 }, // 2分間で10ユーザーまで増加
    { duration: '5m', target: 10 }, // 5分間10ユーザーを維持
    { duration: '2m', target: 50 }, // 2分間で50ユーザーまで増加
    { duration: '5m', target: 50 }, // 5分間50ユーザーを維持
    { duration: '2m', target: 0 },  // 2分間で0ユーザーまで減少
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500'], // 95%のリクエストが500ms以下
    'http_req_failed': ['rate<0.1'],    // エラー率が10%以下
  },
};

export default function() {
  // ホームページアクセス
  let response = http.get(`${__ENV.BASE_URL}/`);
  check(response, {
    'homepage status is 200': (r) => r.status === 200,
    'homepage load time < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(1);

  // API エンドポイントテスト
  response = http.get(`${__ENV.BASE_URL}/api/health`);
  check(response, {
    'health check status is 200': (r) => r.status === 200,
  });

  sleep(1);

  // ユーザー作成API
  const payload = JSON.stringify({
    email: `user${Math.random()}@example.com`,
    name: 'Load Test User'
  });

  response = http.post(`${__ENV.BASE_URL}/api/users`, payload, {
    headers: { 'Content-Type': 'application/json' },
  });

  check(response, {
    'user creation status is 201': (r) => r.status === 201,
    'user creation time < 1000ms': (r) => r.timings.duration < 1000,
  });

  sleep(2);
}
```

#### Step 6: テスト基盤デプロイ

```bash
# 1. テスト自動化スタック作成
aws cloudformation create-stack \
  --stack-name my-web-app-test-automation \
  --template-body file://../../06-CI-CD高度化編/6.1-自動化パイプライン/6.1.2-テスト自動化/cloudformation/test-automation.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=my-web-app \
               ParameterKey=EnvironmentName,ParameterValue=test \
               ParameterKey=NotificationEmail,ParameterValue=your-email@example.com \
  --capabilities CAPABILITY_IAM

# 2. テスト実行
npm install
npm run test:all
```

### 検証ポイント
- [ ] 単体テストが80%以上のカバレッジを達成
- [ ] 統合テストがAPIエンドポイントを網羅
- [ ] E2Eテストが主要ユーザーフローをカバー
- [ ] パフォーマンステストが品質基準を満たす
- [ ] テストレポートがS3に自動アップロード

### 品質ゲート設定

```yaml
# .github/workflows/quality-gate.yml
name: Quality Gate

on:
  pull_request:
    branches: [main]

jobs:
  quality-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run unit tests with coverage
        run: npm run test:unit
      
      - name: Check coverage threshold
        run: |
          COVERAGE=$(npm run test:unit --silent | grep -o '[0-9]*\.[0-9]*%' | head -1 | sed 's/%//')
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% is below threshold 80%"
            exit 1
          fi
      
      - name: Run integration tests
        run: npm run test:integration
      
      - name: Security audit
        run: npm audit --audit-level high
```

## 演習3: Blue/Greenデプロイメント実装 (2時間)

### 目標
ゼロダウンタイムでアプリケーションを更新できるBlue/Greenデプロイメントを実装する。

### 手順

#### Step 1: Blue/Green基盤構築

```bash
# 1. VPC情報取得
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=my-web-app-vpc" --query 'Vpcs[0].VpcId' --output text)
PRIVATE_SUBNET_1=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=*private*" --query 'Subnets[0].SubnetId' --output text)
PRIVATE_SUBNET_2=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=*private*" --query 'Subnets[1].SubnetId' --output text)
PUBLIC_SUBNET_1=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=*public*" --query 'Subnets[0].SubnetId' --output text)
PUBLIC_SUBNET_2=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=*public*" --query 'Subnets[1].SubnetId' --output text)

# 2. パラメータファイル作成
cat > blue-green-params.json << EOF
[
  {"ParameterKey": "ApplicationName", "ParameterValue": "my-web-app"},
  {"ParameterKey": "VpcId", "ParameterValue": "$VPC_ID"},
  {"ParameterKey": "PrivateSubnetIds", "ParameterValue": "$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2"},
  {"ParameterKey": "PublicSubnetIds", "ParameterValue": "$PUBLIC_SUBNET_1,$PUBLIC_SUBNET_2"},
  {"ParameterKey": "NotificationEmail", "ParameterValue": "your-email@example.com"}
]
EOF

# 3. Blue/Greenスタック作成
aws cloudformation create-stack \
  --stack-name my-web-app-blue-green \
  --template-body file://../../06-CI-CD高度化編/6.2-高度なデプロイ戦略/6.2.1-BlueGreenデプロイ/cloudformation/blue-green-ecs.yaml \
  --parameters file://blue-green-params.json \
  --capabilities CAPABILITY_NAMED_IAM
```

#### Step 2: デプロイメント設定

```yaml
# appspec.yml (Blue/Green用)
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: "my-web-app-container"
          ContainerPort: 80
        PlatformVersion: "LATEST"
        NetworkConfiguration:
          AwsvpcConfiguration:
            Subnets:
              - "subnet-12345678"
              - "subnet-87654321"
            SecurityGroups:
              - "sg-12345678"
            AssignPublicIp: "DISABLED"

Hooks:
  - BeforeInstall: "Lambda:arn:aws:lambda:region:account:function:BeforeInstallHook"
  - AfterInstall: "Lambda:arn:aws:lambda:region:account:function:AfterInstallHook"
  - AfterAllowTestTraffic: "Lambda:arn:aws:lambda:region:account:function:HealthCheckHook"
  - BeforeAllowTraffic: "Lambda:arn:aws:lambda:region:account:function:BeforeAllowTrafficHook"
  - AfterAllowTraffic: "Lambda:arn:aws:lambda:region:account:function:AfterAllowTrafficHook"
```

#### Step 3: ヘルスチェック実装

```python
# health-check-hook.py
import boto3
import requests
import json

def lambda_handler(event, context):
    """
    Blue/Green デプロイメント用ヘルスチェック
    """
    codedeploy = boto3.client('codedeploy')
    
    deployment_id = event['DeploymentId']
    lifecycle_event_hook_execution_id = event['LifecycleEventHookExecutionId']
    
    try:
        # Green環境のヘルスチェック
        test_url = "http://internal-alb-green.amazonaws.com/health"
        response = requests.get(test_url, timeout=10)
        
        if response.status_code == 200:
            health_data = response.json()
            
            # 詳細ヘルスチェック
            checks = [
                health_data.get('database', False),
                health_data.get('cache', False),
                health_data.get('external_api', False),
                response.elapsed.total_seconds() < 2.0  # レスポンス時間チェック
            ]
            
            if all(checks):
                status = 'Succeeded'
                print("All health checks passed")
            else:
                status = 'Failed'
                print(f"Health check failed: {health_data}")
        else:
            status = 'Failed'
            print(f"Health check returned {response.status_code}")
            
    except Exception as e:
        status = 'Failed'
        print(f"Health check failed with exception: {str(e)}")
    
    # CodeDeployに結果を報告
    codedeploy.put_lifecycle_event_hook_execution_status(
        deploymentId=deployment_id,
        lifecycleEventHookExecutionId=lifecycle_event_hook_execution_id,
        status=status
    )
    
    return {'statusCode': 200, 'body': f'Health check {status}'}
```

#### Step 4: デプロイメント実行

```bash
# 1. 新しいバージョンのアプリケーションをビルド
docker build -t my-web-app:v2 .
docker tag my-web-app:v2 $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/my-web-app:v2
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/my-web-app:v2

# 2. CodeDeploy デプロイメント実行
aws deploy create-deployment \
  --application-name my-web-app-codedeploy \
  --deployment-group-name production \
  --deployment-config-name CodeDeployDefault.ECSAllAtOnceBlueGreen \
  --description "Blue/Green deployment v2"

# 3. デプロイメント状況監視
DEPLOYMENT_ID=$(aws deploy list-deployments --application-name my-web-app-codedeploy --query 'deployments[0]' --output text)
aws deploy get-deployment --deployment-id $DEPLOYMENT_ID
```

### 検証ポイント
- [ ] Blue環境が正常に稼働している
- [ ] Green環境が正常にデプロイされる
- [ ] ヘルスチェックが成功する
- [ ] トラフィックが段階的に切り替わる
- [ ] ロールバックが正常に動作する

### トラフィック切り替えテスト

```bash
#!/bin/bash
# test-traffic-switching.sh

# ALBのDNS名取得
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name my-web-app-blue-green \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
  --output text | sed 's|http://||')

echo "Testing traffic switching..."

# トラフィック切り替え前後でのレスポンス確認
for i in {1..20}; do
  VERSION=$(curl -s http://$ALB_DNS/version | jq -r '.version')
  echo "Request $i: Version $VERSION"
  sleep 1
done
```

## 演習4: 包括的監視システム構築 (2時間)

### 目標
アプリケーションパフォーマンス監視（APM）とビジネスメトリクスを含む包括的な監視システムを構築する。

### 手順

#### Step 1: 監視基盤デプロイ

```bash
# 1. 監視スタック作成
aws cloudformation create-stack \
  --stack-name my-web-app-monitoring \
  --template-body file://../../06-CI-CD高度化編/6.3-モニタリングと最適化/6.3.1-APM実装/cloudformation/comprehensive-monitoring.yaml \
  --parameters ParameterKey=ApplicationName,ParameterValue=my-web-app \
               ParameterKey=Environment,ParameterValue=production \
               ParameterKey=AlertEmail,ParameterValue=your-email@example.com \
  --capabilities CAPABILITY_IAM
```

#### Step 2: アプリケーション監視コード追加

```javascript
// src/middleware/monitoring.js
const AWSXRay = require('aws-xray-sdk-core');
const AWS = require('aws-sdk');

// X-Ray設定
AWSXRay.config([AWSXRay.plugins.ECSPlugin]);
const cloudwatch = AWSXRay.captureAWSClient(new AWS.CloudWatch());

// カスタムメトリクス送信
function sendCustomMetric(metricName, value, unit = 'Count', dimensions = []) {
  const params = {
    Namespace: 'MyWebApp/Business',
    MetricData: [{
      MetricName: metricName,
      Value: value,
      Unit: unit,
      Dimensions: dimensions,
      Timestamp: new Date()
    }]
  };
  
  cloudwatch.putMetricData(params, (err, data) => {
    if (err) console.error('Error sending metric:', err);
    else console.log('Metric sent:', metricName, value);
  });
}

// ビジネスメトリクスミドルウェア
function businessMetricsMiddleware(req, res, next) {
  const startTime = Date.now();
  
  // レスポンス時に実行
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    
    // APIレスポンス時間
    sendCustomMetric('APIResponseTime', duration, 'Milliseconds', [
      { Name: 'Method', Value: req.method },
      { Name: 'Route', Value: req.route?.path || req.path }
    ]);
    
    // HTTPステータスコード別カウント
    sendCustomMetric(`HTTPStatus${Math.floor(res.statusCode / 100)}XX`, 1, 'Count');
    
    // ユーザー登録メトリクス
    if (req.path === '/api/users' && req.method === 'POST' && res.statusCode === 201) {
      sendCustomMetric('UserRegistrations', 1, 'Count');
    }
    
    // エラー追跡
    if (res.statusCode >= 400) {
      sendCustomMetric('APIErrors', 1, 'Count', [
        { Name: 'StatusCode', Value: res.statusCode.toString() },
        { Name: 'Route', Value: req.path }
      ]);
    }
  });
  
  next();
}

module.exports = {
  businessMetricsMiddleware,
  sendCustomMetric
};
```

#### Step 3: X-Ray統合

```javascript
// src/app.js
const AWSXRay = require('aws-xray-sdk-core');
const express = require('express');
const { businessMetricsMiddleware } = require('./middleware/monitoring');

const app = express();

// X-Ray トレーシング有効化
app.use(AWSXRay.express.openSegment('MyWebApp'));

// ビジネスメトリクス追跡
app.use(businessMetricsMiddleware);

// データベースクエリトレース
const mysql = AWSXRay.captureMySQL(require('mysql'));
const client = mysql.createConnection({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME
});

// カスタムサブセグメント例
app.get('/api/users/:id', async (req, res) => {
  const segment = AWSXRay.getSegment();
  const subsegment = segment.addNewSubsegment('GetUserDetails');
  
  try {
    subsegment.addAnnotation('userId', req.params.id);
    
    // データベースクエリ
    const user = await getUserById(req.params.id);
    
    if (user) {
      subsegment.addMetadata('user', { email: user.email });
      res.json(user);
    } else {
      subsegment.addAnnotation('userNotFound', true);
      res.status(404).json({ error: 'User not found' });
    }
  } catch (error) {
    subsegment.addError(error);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    subsegment.close();
  }
});

// X-Ray セグメント終了
app.use(AWSXRay.express.closeSegment());

module.exports = app;
```

#### Step 4: カスタムダッシュボード作成

```python
# scripts/create-dashboard.py
import boto3
import json

def create_custom_dashboard():
    cloudwatch = boto3.client('cloudwatch')
    
    dashboard_body = {
        "widgets": [
            {
                "type": "metric",
                "x": 0, "y": 0,
                "width": 12, "height": 6,
                "properties": {
                    "metrics": [
                        ["MyWebApp/Business", "UserRegistrations"],
                        [".", "APIErrors"],
                        [".", "HTTPStatus2XX"],
                        [".", "HTTPStatus4XX"],
                        [".", "HTTPStatus5XX"]
                    ],
                    "period": 300,
                    "stat": "Sum",
                    "region": "ap-northeast-1",
                    "title": "Business Metrics"
                }
            },
            {
                "type": "metric",
                "x": 12, "y": 0,
                "width": 12, "height": 6,
                "properties": {
                    "metrics": [
                        ["MyWebApp/Business", "APIResponseTime", "Method", "GET"],
                        [".", ".", ".", "POST"],
                        [".", ".", ".", "PUT"],
                        [".", ".", ".", "DELETE"]
                    ],
                    "period": 300,
                    "stat": "Average",
                    "region": "ap-northeast-1",
                    "title": "API Performance"
                }
            },
            {
                "type": "log",
                "x": 0, "y": 6,
                "width": 24, "height": 6,
                "properties": {
                    "query": "SOURCE '/aws/ecs/my-web-app' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20",
                    "region": "ap-northeast-1",
                    "title": "Recent Errors"
                }
            }
        ]
    }
    
    response = cloudwatch.put_dashboard(
        DashboardName='MyWebApp-Production-Dashboard',
        DashboardBody=json.dumps(dashboard_body)
    )
    
    print(f"Dashboard created: {response}")

if __name__ == "__main__":
    create_custom_dashboard()
```

### 検証ポイント
- [ ] X-Rayサービスマップが正常に表示される
- [ ] カスタムメトリクスがCloudWatchに送信される
- [ ] アラームが適切に設定される
- [ ] ダッシュボードがビジネスメトリクスを表示する
- [ ] ログ分析が機能する

## 演習5: コスト最適化とFinOps (1時間)

### 目標
自動化されたコスト監視とリソース最適化の仕組みを実装する。

### 手順

#### Step 1: コスト最適化基盤デプロイ

```bash
# 1. コスト最適化スタック作成
aws cloudformation create-stack \
  --stack-name my-web-app-cost-optimization \
  --template-body file://../../06-CI-CD高度化編/6.3-モニタリングと最適化/6.3.2-コスト最適化/cloudformation/cost-optimization.yaml \
  --parameters ParameterKey=ApplicationName,ParameterValue=my-web-app \
               ParameterKey=Environment,ParameterValue=production \
               ParameterKey=MonthlyBudget,ParameterValue=300 \
               ParameterKey=AlertEmail,ParameterValue=your-email@example.com \
  --capabilities CAPABILITY_IAM
```

#### Step 2: リソーススケジューラー設定

```python
# scripts/setup-resource-scheduler.py
import boto3
import json
from datetime import datetime

def setup_development_scheduler():
    """開発環境の自動停止スケジューラー設定"""
    
    events = boto3.client('events')
    
    # 夜間停止ルール (19:00 JST)
    stop_rule = events.put_rule(
        Name='dev-resources-stop',
        ScheduleExpression='cron(0 10 * * ? *)',  # 19:00 JST = 10:00 UTC
        Description='Stop development resources at night',
        State='ENABLED'
    )
    
    # 朝の開始ルール (8:00 JST)
    start_rule = events.put_rule(
        Name='dev-resources-start',
        ScheduleExpression='cron(0 23 * * SUN-THU *)',  # 8:00 JST = 23:00 UTC (previous day)
        Description='Start development resources in the morning',
        State='ENABLED'
    )
    
    print("Resource scheduler rules created")

def tag_resources_for_automation():
    """リソースに自動化用タグを追加"""
    
    ec2 = boto3.client('ec2')
    rds = boto3.client('rds')
    
    # EC2インスタンスにタグ追加
    instances = ec2.describe_instances(
        Filters=[
            {'Name': 'tag:Application', 'Values': ['my-web-app']},
            {'Name': 'tag:Environment', 'Values': ['development']}
        ]
    )
    
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            ec2.create_tags(
                Resources=[instance['InstanceId']],
                Tags=[
                    {'Key': 'AutoStop', 'Value': 'true'},
                    {'Key': 'Schedule', 'Value': 'business-hours'}
                ]
            )
    
    print("Resources tagged for automation")

if __name__ == "__main__":
    setup_development_scheduler()
    tag_resources_for_automation()
```

#### Step 3: コスト分析レポート作成

```python
# scripts/cost-analysis.py
import boto3
import json
from datetime import datetime, timedelta

def generate_cost_report():
    """コスト分析レポート生成"""
    
    ce = boto3.client('ce')
    
    # 過去30日のコストデータ取得
    end_date = datetime.now().strftime('%Y-%m-%d')
    start_date = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
    
    # サービス別コスト
    service_costs = ce.get_cost_and_usage(
        TimePeriod={'Start': start_date, 'End': end_date},
        Granularity='MONTHLY',
        Metrics=['BlendedCost'],
        GroupBy=[{'Type': 'DIMENSION', 'Key': 'SERVICE'}]
    )
    
    # アプリケーション別コスト
    app_costs = ce.get_cost_and_usage(
        TimePeriod={'Start': start_date, 'End': end_date},
        Granularity='DAILY',
        Metrics=['BlendedCost'],
        GroupBy=[{'Type': 'TAG', 'Key': 'Application'}]
    )
    
    # レポート生成
    report = {
        'period': f"{start_date} to {end_date}",
        'service_breakdown': {},
        'application_costs': {},
        'recommendations': []
    }
    
    # サービス別集計
    for result in service_costs['ResultsByTime']:
        for group in result['Groups']:
            service = group['Keys'][0]
            cost = float(group['Metrics']['BlendedCost']['Amount'])
            report['service_breakdown'][service] = cost
    
    # 推奨事項生成
    if report['service_breakdown'].get('Amazon Elastic Compute Cloud - Compute', 0) > 50:
        report['recommendations'].append(
            "EC2 costs are high. Consider using Reserved Instances or Spot Instances."
        )
    
    if report['service_breakdown'].get('Amazon Relational Database Service', 0) > 30:
        report['recommendations'].append(
            "RDS costs are significant. Review instance sizes and consider Aurora Serverless."
        )
    
    # S3に保存
    s3 = boto3.client('s3')
    bucket_name = 'my-web-app-production-cost-reports'
    key = f"reports/{datetime.now().strftime('%Y/%m')}/cost-analysis.json"
    
    s3.put_object(
        Bucket=bucket_name,
        Key=key,
        Body=json.dumps(report, indent=2)
    )
    
    print(f"Cost report saved to s3://{bucket_name}/{key}")
    return report

if __name__ == "__main__":
    report = generate_cost_report()
    print(json.dumps(report, indent=2))
```

### 検証ポイント
- [ ] 予算アラートが正常に設定される
- [ ] コストレポートが自動生成される
- [ ] 開発リソースが自動停止される
- [ ] 最適化推奨事項が提示される
- [ ] コストダッシュボードが機能する

## 最終検証チェックリスト

### 全体システム確認
- [ ] CI/CDパイプラインが正常に動作する
- [ ] テストが自動実行され、品質ゲートが機能する
- [ ] Blue/Greenデプロイメントでゼロダウンタイム更新が可能
- [ ] 包括的な監視が実装され、アラートが機能する
- [ ] コスト最適化が自動化されている

### パフォーマンス確認
- [ ] APIレスポンス時間が要件を満たす（95%が500ms以下）
- [ ] エラー率が1%以下を維持
- [ ] 自動スケーリングが適切に動作する
- [ ] リソース使用率が最適化されている

### セキュリティ確認
- [ ] セキュリティテストがパイプラインに統合されている
- [ ] 脆弱性スキャンが定期実行される
- [ ] 最小権限の原則が適用されている
- [ ] 監査ログが適切に記録される

### 運用確認
- [ ] 障害時の自動復旧機能が動作する
- [ ] ロールバック手順が確立されている
- [ ] 監視ダッシュボードが見やすく構成されている
- [ ] アラート通知が適切に送信される

## 次のステップ

このハンズオン演習を完了したら、以下に進んでください：

1. **[07-Claude Code & Bedrock AI駆動開発編](../../07-Claude-Code-Bedrock-AI駆動開発編/README.md)** - AI技術を活用した次世代開発手法の学習

2. **実際のプロジェクトへの適用** - 学習した内容を実際のプロジェクトに適用し、継続的改善を実施

3. **高度な最適化** - 組織の要件に応じたカスタマイズと最適化

おめでとうございます！あなたは今、実践的なDevOpsスキルを身につけ、現代的なCI/CDパイプラインを構築・運用できるようになりました。