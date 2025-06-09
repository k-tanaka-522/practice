# CI-CD高度化編

## 概要

このセクションでは、本格的なDevOpsパイプラインと運用監視システムを構築します。マルチステージデプロイメント、テスト自動化、包括的な監視、コスト最適化まで、エンタープライズレベルのCI/CDプラクティスを学習します。

## 学習目標

- 🚀 **マルチステージパイプライン**: 開発・ステージング・本番環境の自動デプロイ
- 🧪 **テスト自動化**: 単体・統合・E2Eテストの完全自動化
- 📊 **APM実装**: アプリケーションパフォーマンス監視
- 💰 **コスト最適化**: リソース使用量監視と自動最適化
- 🛡️ **セキュリティ統合**: SAST/DAST、脆弱性スキャン

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

## 学習パス

### 6.1 自動化パイプライン
- **6.1.1** マルチステージビルド
- **6.1.2** テスト自動化

### 6.2 モニタリングと最適化
- **6.2.1** APM実装
- **6.2.2** コスト最適化

### 6.3 エンタープライズ機能（拡張）
- **6.3.1** セキュリティ統合
- **6.3.2** 災害復旧と可用性

## クイックスタート

### 前提条件

```bash
# AWS CLI確認
aws --version
aws sts get-caller-identity

# Docker確認（コンテナビルド用）
docker --version

# Node.js確認（テスト用）
node --version
npm --version

# GitHub CLI確認（リポジトリ連携用）
gh --version
```

### 全体デプロイ

```bash
# CI/CD基盤の一括デプロイ
./scripts/deploy-all-infrastructure.sh deploy-cicd

# 段階的デプロイ
./scripts/deploy-cicd.sh deploy-pipeline
./scripts/deploy-cicd.sh deploy-monitoring
./scripts/deploy-cicd.sh deploy-optimization
```

## 学習コンテンツ詳細

### 🚀 6.1.1 マルチステージビルド

**学習内容:**
- CI/CDパイプライン設計パターン
- マルチステージデプロイメント戦略
- ブランチ戦略とリリース管理
- カナリアデプロイメント

**実装内容:**
- CodePipeline マルチステージ構成
- CodeBuild プロジェクト設定
- CloudFormation デプロイ自動化
- 承認ワークフロー実装

**主要技術:**
- AWS CodePipeline
- AWS CodeBuild
- AWS CodeDeploy
- AWS CloudFormation

### 🧪 6.1.2 テスト自動化

**学習内容:**
- テスト戦略とピラミッド
- 単体テスト自動化
- 統合テスト実装
- E2Eテスト設計

**実装内容:**
- Jest/Mocha 単体テスト
- API統合テスト
- Selenium E2Eテスト
- テストレポート生成

**主要技術:**
- Jest/Mocha
- Selenium WebDriver
- TestCafe/Cypress
- SonarQube

### 📊 6.2.1 APM実装

**学習内容:**
- アプリケーション監視戦略
- 分散トレーシング
- カスタムメトリクス設計
- アラート設定

**実装内容:**
- AWS X-Ray 分散トレーシング
- CloudWatch カスタムダッシュボード
- Application Insights 設定
- パフォーマンスアラート

**主要技術:**
- AWS X-Ray
- AWS CloudWatch
- Application Insights
- AWS SNS

### 💰 6.2.2 コスト最適化

**学習内容:**
- コスト監視戦略
- リソース使用量分析
- 自動スケーリング設定
- 予算管理

**実装内容:**
- AWS Cost Explorer 連携
- 予算アラート設定
- 自動リソース停止
- コスト配分タグ

**主要技術:**
- AWS Cost Explorer
- AWS Budgets
- AWS Lambda
- AWS EventBridge

## 🏗️ 実装手順

### Step 1: マルチステージパイプライン構築

```bash
# GitHub リポジトリ設定
gh repo create my-cicd-project --public
gh repo clone my-cicd-project
cd my-cicd-project

# パイプライン作成
aws cloudformation create-stack \
  --stack-name my-cicd-pipeline \
  --template-body file://06-CI-CD高度化編/6.1-自動化パイプライン/6.1.1-マルチステージビルド/cloudformation/codepipeline-multistage.yaml \
  --parameters ParameterKey=GitHubRepo,ParameterValue=username/my-cicd-project \
               ParameterKey=GitHubToken,ParameterValue=your_github_token \
  --capabilities CAPABILITY_IAM
```

### Step 2: テスト自動化設定

```bash
# テストインフラ構築
aws cloudformation create-stack \
  --stack-name test-automation \
  --template-body file://06-CI-CD高度化編/6.1-自動化パイプライン/6.1.2-テスト自動化/cloudformation/test-infrastructure.yaml \
  --capabilities CAPABILITY_IAM

# テストスイート実行
npm install
npm run test:unit
npm run test:integration
npm run test:e2e
```

### Step 3: 監視システム構築

```bash
# APM監視設定
aws cloudformation create-stack \
  --stack-name apm-monitoring \
  --template-body file://06-CI-CD高度化編/6.2-モニタリングと最適化/6.2.1-APM実装/cloudformation/x-ray-monitoring.yaml \
  --parameters ParameterKey=AlertEmail,ParameterValue=your-email@example.com \
  --capabilities CAPABILITY_IAM
```

### Step 4: コスト最適化実装

```bash
# コスト監視設定
aws cloudformation create-stack \
  --stack-name cost-optimization \
  --template-body file://06-CI-CD高度化編/6.2-モニタリングと最適化/6.2.2-コスト最適化/cloudformation/cost-budgets.yaml \
  --parameters ParameterKey=MonthlyBudget,ParameterValue=1000 \
  --capabilities CAPABILITY_IAM
```

## 📋 buildspec.yml 例

### マルチステージビルド用

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

## 🧪 テスト戦略

### テストピラミッド実装

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

## 📊 監視とアラート

### カスタムメトリクス実装

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

## 💰 コスト最適化戦略

### 自動リソース管理

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

## 🛠️ デプロイメント戦略

### ブルーグリーンデプロイメント

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

## 📚 参考資料

### AWS ドキュメント
- [AWS DevOps Best Practices](https://aws.amazon.com/devops/)
- [CI/CD Pipeline on AWS](https://aws.amazon.com/getting-started/hands-on/set-up-ci-cd-pipeline/)
- [AWS Well-Architected Framework - DevOps](https://docs.aws.amazon.com/wellarchitected/latest/operational-excellence-pillar/)

### DevOps プラクティス
- [The DevOps Handbook](https://itrevolution.com/book/the-devops-handbook/)
- [Continuous Delivery](https://continuousdelivery.com/)
- [Site Reliability Engineering](https://sre.google/)

## 📈 次のステップ

完了後は以下に進んでください：

1. **[Claude Code & Bedrock編](../07-Claude-Code-Bedrock-AI駆動開発編/README.md)** - AI駆動開発
2. **実際のプロダクト適用** - 学習した技術の実運用
3. **高度な最適化** - 独自要件に応じたカスタマイズ

---

## 🎯 学習チェックリスト

### パイプライン構築
- [ ] マルチステージパイプライン設計
- [ ] 自動ビルド・テスト・デプロイ
- [ ] 承認ワークフロー実装
- [ ] 障害時ロールバック対応

### テスト自動化
- [ ] 単体テスト実装
- [ ] 統合テスト設定
- [ ] E2Eテスト自動化
- [ ] セキュリティテスト統合

### 監視・運用
- [ ] APM実装
- [ ] カスタムメトリクス設定
- [ ] アラート設定
- [ ] ダッシュボード作成

### 最適化
- [ ] コスト監視設定
- [ ] 自動リソース管理
- [ ] パフォーマンス最適化
- [ ] セキュリティ強化

**準備ができたら次のセクションへ進みましょう！**