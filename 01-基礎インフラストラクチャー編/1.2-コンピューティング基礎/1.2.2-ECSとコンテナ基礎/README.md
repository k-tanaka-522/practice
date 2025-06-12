# 1.2.2 ECSとコンテナ基礎

## 学習目標

このセクションでは、Amazon ECS（Elastic Container Service）を使用してコンテナベースのアプリケーションを運用し、スケーラブルで管理しやすいマイクロサービスアーキテクチャを構築する方法を習得します。

### 習得できるスキル
- Docker基礎とコンテナ化技術の理解
- Amazon ECSクラスター管理
- Fargateによるサーバーレスコンテナ実行
- Application Load Balancerとの統合
- ECS Service Auto Scalingの設定
- CloudWatch Logsによるコンテナログ管理

## 前提知識

### 必須の知識
- EC2インスタンス管理（1.2.1セクション完了）
- VPCとネットワーク基礎（1.1.2セクション完了）
- Linuxの基本コマンド操作
- アプリケーション開発の基礎知識

### あると望ましい知識
- Dockerの基本操作経験
- マイクロサービスアーキテクチャの概念
- JSON設定ファイルの理解
- ロードバランサーの基本概念

## アーキテクチャ概要

### ECS Fargate アーキテクチャ

```
                            ┌─────────────────────┐
                            │   Application       │
                            │   Load Balancer     │
                            │                     │
                            │  ┌───────────────┐  │
                            │  │   Listener    │  │
                            │  │   Rules       │  │
                            │  └───────────────┘  │
                            └──────────┬──────────┘
                                       │
                 ┌─────────────────────┼─────────────────────┐
                 │                     │                     │
                 ▼                     ▼                     ▼
    ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
    │   ECS Service       │ │   ECS Service       │ │   ECS Service       │
    │   (Web Frontend)    │ │   (API Backend)     │ │   (Worker Service)  │
    │                     │ │                     │ │                     │
    │ ┌─────────────────┐ │ │ ┌─────────────────┐ │ │ ┌─────────────────┐ │
    │ │   Task 1        │ │ │ │   Task 1        │ │ │ │   Task 1        │ │
    │ │  ┌───────────┐  │ │ │ │  ┌───────────┐  │ │ │ │  ┌───────────┐  │ │
    │ │  │Container A│  │ │ │ │  │Container C│  │ │ │ │  │Container E│  │ │
    │ │  └───────────┘  │ │ │ │  └───────────┘  │ │ │ │  └───────────┘  │ │
    │ └─────────────────┘ │ │ └─────────────────┘ │ │ └─────────────────┘ │
    │                     │ │                     │ │                     │
    │ ┌─────────────────┐ │ │ ┌─────────────────┐ │ │ ┌─────────────────┐ │
    │ │   Task 2        │ │ │ │   Task 2        │ │ │ │   Task 2        │ │
    │ │  ┌───────────┐  │ │ │ │  ┌───────────┐  │ │ │ │  ┌───────────┐  │ │
    │ │  │Container B│  │ │ │ │  │Container D│  │ │ │ │  │Container F│  │ │
    │ │  └───────────┘  │ │ │ │  └───────────┘  │ │ │ │  └───────────┘  │ │
    │ └─────────────────┘ │ │ └─────────────────┘ │ │ └─────────────────┘ │
    └─────────────────────┘ └─────────────────────┘ └─────────────────────┘
                 │                     │                     │
                 │                     │                     │
                 ▼                     ▼                     ▼
    ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
    │   Private Subnet    │ │   Private Subnet    │ │   Private Subnet    │
    │   (AZ-1a)           │ │   (AZ-1c)           │ │   (AZ-1d)           │
    └─────────────────────┘ └─────────────────────┘ └─────────────────────┘
                                       │
                                       ▼
                            ┌─────────────────────┐
                            │   Amazon ECR        │
                            │   (Container        │
                            │    Registry)        │
                            └─────────────────────┘
```

### 主要コンポーネント
- **ECS Cluster**: コンテナインスタンスの論理グループ
- **ECS Service**: 継続的に実行されるタスクの管理
- **Task Definition**: コンテナ設定のテンプレート
- **Fargate**: サーバーレスコンテナ実行環境
- **Amazon ECR**: プライベートDockerレジストリ

## ハンズオン手順

### ステップ1: ECRリポジトリとサンプルアプリケーション

1. **サンプルアプリケーションの作成**
```bash
cd /mnt/c/dev2/practice/01-基礎インフラストラクチャー編/1.2-コンピューティング基礎/1.2.2-ECSとコンテナ基礎/docker
```

2. **Node.js Webアプリケーション**
```javascript
// app.js
const express = require('express');
const os = require('os');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  const response = {
    message: 'Hello from ECS Container!',
    hostname: os.hostname(),
    platform: os.platform(),
    uptime: os.uptime(),
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
    version: process.env.APP_VERSION || '1.0.0'
  };
  
  res.json(response);
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}`);
});
```

3. **Dockerfile**
```dockerfile
# Dockerfile
FROM node:18-alpine

WORKDIR /app

# Package.json をコピーして依存関係をインストール
COPY package*.json ./
RUN npm ci --only=production

# アプリケーションコードをコピー
COPY . .

# 非rootユーザーを作成
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# ファイルの所有者を変更
RUN chown -R nodejs:nodejs /app
USER nodejs

# ポートを公開
EXPOSE 3000

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js

# アプリケーション起動
CMD ["node", "app.js"]
```

4. **package.json**
```json
{
  "name": "ecs-sample-app",
  "version": "1.0.0",
  "description": "Sample application for ECS deployment",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
```

### ステップ2: CloudFormationテンプレートでECSインフラ構築

1. **ECR Repository**
```yaml
# ecr-repository.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'ECR Repository for ECS containers'

Parameters:
  ProjectName:
    Type: String
    Default: 'ecs-container'
  
  EnvironmentName:
    Type: String
    Default: 'dev'

Resources:
  ECRRepository:
    Type: AWS::ECR::Repository
    Properties:
      RepositoryName: !Sub '${ProjectName}-${EnvironmentName}'
      ImageTagMutability: MUTABLE
      ImageScanningConfiguration:
        ScanOnPush: true
      LifecyclePolicy:
        LifecyclePolicyText: |
          {
            "rules": [
              {
                "rulePriority": 1,
                "description": "Keep last 10 images",
                "selection": {
                  "tagStatus": "tagged",
                  "tagPrefixList": ["latest"],
                  "countType": "imageCountMoreThan",
                  "countNumber": 10
                },
                "action": {
                  "type": "expire"
                }
              },
              {
                "rulePriority": 2,
                "description": "Delete untagged images older than 1 day",
                "selection": {
                  "tagStatus": "untagged",
                  "countType": "sinceImagePushed",
                  "countUnit": "days",
                  "countNumber": 1
                },
                "action": {
                  "type": "expire"
                }
              }
            ]
          }
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

Outputs:
  ECRRepositoryURI:
    Description: 'ECR Repository URI'
    Value: !GetAtt ECRRepository.RepositoryUri
    Export:
      Name: !Sub '${AWS::StackName}-ECRRepositoryURI'
  
  ECRRepositoryName:
    Description: 'ECR Repository Name'
    Value: !Ref ECRRepository
    Export:
      Name: !Sub '${AWS::StackName}-ECRRepositoryName'
```

2. **ECS Cluster and Services**
```yaml
# ecs-cluster.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'ECS Cluster with Fargate services'

Parameters:
  ProjectName:
    Type: String
    Default: 'ecs-container'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
  
  VpcId:
    Type: String
    Description: 'VPC ID for ECS cluster'
  
  PrivateSubnetIds:
    Type: CommaDelimitedList
    Description: 'List of private subnet IDs'
  
  PublicSubnetIds:
    Type: CommaDelimitedList
    Description: 'List of public subnet IDs for load balancer'
  
  ContainerImage:
    Type: String
    Description: 'Container image URI'
  
  DesiredCount:
    Type: Number
    Default: 2
    Description: 'Desired number of tasks'

Resources:
  # ECS Cluster
  ECSCluster:
    Type: AWS::ECS::Cluster
    Properties:
      ClusterName: !Sub '${ProjectName}-${EnvironmentName}-cluster'
      CapacityProviders:
        - FARGATE
        - FARGATE_SPOT
      DefaultCapacityProviderStrategy:
        - CapacityProvider: FARGATE
          Weight: 1
        - CapacityProvider: FARGATE_SPOT
          Weight: 4
      ClusterSettings:
        - Name: containerInsights
          Value: enabled
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # Task Definition
  TaskDefinition:
    Type: AWS::ECS::TaskDefinition
    Properties:
      Family: !Sub '${ProjectName}-${EnvironmentName}-task'
      NetworkMode: awsvpc
      RequiresCompatibilities:
        - FARGATE
      Cpu: 256
      Memory: 512
      ExecutionRoleArn: !GetAtt TaskExecutionRole.Arn
      TaskRoleArn: !GetAtt TaskRole.Arn
      ContainerDefinitions:
        - Name: !Sub '${ProjectName}-container'
          Image: !Ref ContainerImage
          Essential: true
          PortMappings:
            - ContainerPort: 3000
              Protocol: tcp
          Environment:
            - Name: NODE_ENV
              Value: !Ref EnvironmentName
            - Name: APP_VERSION
              Value: '1.0.0'
          LogConfiguration:
            LogDriver: awslogs
            Options:
              awslogs-group: !Ref LogGroup
              awslogs-region: !Ref AWS::Region
              awslogs-stream-prefix: ecs
          HealthCheck:
            Command:
              - CMD-SHELL
              - 'curl -f http://localhost:3000/health || exit 1'
            Interval: 30
            Timeout: 5
            Retries: 3
            StartPeriod: 60
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # ECS Service
  ECSService:
    Type: AWS::ECS::Service
    DependsOn: ALBListener
    Properties:
      ServiceName: !Sub '${ProjectName}-${EnvironmentName}-service'
      Cluster: !Ref ECSCluster
      TaskDefinition: !Ref TaskDefinition
      DesiredCount: !Ref DesiredCount
      LaunchType: FARGATE
      NetworkConfiguration:
        AwsvpcConfiguration:
          SecurityGroups:
            - !Ref ECSSecurityGroup
          Subnets: !Ref PrivateSubnetIds
          AssignPublicIp: DISABLED
      LoadBalancers:
        - ContainerName: !Sub '${ProjectName}-container'
          ContainerPort: 3000
          TargetGroupArn: !Ref TargetGroup
      ServiceRegistries:
        - RegistryArn: !GetAtt ServiceDiscovery.Arn
      DeploymentConfiguration:
        MaximumPercent: 200
        MinimumHealthyPercent: 50
        DeploymentCircuitBreaker:
          Enable: true
          Rollback: true
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # Application Load Balancer
  ApplicationLoadBalancer:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-alb'
      Type: application
      Scheme: internet-facing
      Subnets: !Ref PublicSubnetIds
      SecurityGroups:
        - !Ref ALBSecurityGroup
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  TargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-tg'
      Port: 3000
      Protocol: HTTP
      VpcId: !Ref VpcId
      TargetType: ip
      HealthCheckPath: /health
      HealthCheckIntervalSeconds: 30
      HealthCheckTimeoutSeconds: 5
      HealthyThresholdCount: 2
      UnhealthyThresholdCount: 3
      Matcher:
        HttpCode: 200
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  ALBListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      DefaultActions:
        - Type: forward
          TargetGroupArn: !Ref TargetGroup
      LoadBalancerArn: !Ref ApplicationLoadBalancer
      Port: 80
      Protocol: HTTP

  # Security Groups
  ECSSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: 'Security group for ECS tasks'
      VpcId: !Ref VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 3000
          ToPort: 3000
          SourceSecurityGroupId: !Ref ALBSecurityGroup
      SecurityGroupEgress:
        - IpProtocol: -1
          CidrIp: 0.0.0.0/0
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-ecs-sg'

  ALBSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: 'Security group for Application Load Balancer'
      VpcId: !Ref VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-alb-sg'

  # CloudWatch Log Group
  LogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/ecs/${ProjectName}-${EnvironmentName}'
      RetentionInDays: 30

  # Service Discovery
  ServiceDiscoveryNamespace:
    Type: AWS::ServiceDiscovery::PrivateDnsNamespace
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}.local'
      Vpc: !Ref VpcId

  ServiceDiscovery:
    Type: AWS::ServiceDiscovery::Service
    Properties:
      Name: !Sub '${ProjectName}-service'
      DnsConfig:
        DnsRecords:
          - Type: A
            TTL: 60
        NamespaceId: !Ref ServiceDiscoveryNamespace
      HealthCheckCustomConfig:
        FailureThreshold: 1

  # IAM Roles
  TaskExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ecs-tasks.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
      Policies:
        - PolicyName: ECRAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - ecr:GetAuthorizationToken
                  - ecr:BatchCheckLayerAvailability
                  - ecr:GetDownloadUrlForLayer
                  - ecr:BatchGetImage
                Resource: '*'

  TaskRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ecs-tasks.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: TaskPermissions
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                Resource: !GetAtt LogGroup.Arn

  # Auto Scaling
  AutoScalingTarget:
    Type: AWS::ApplicationAutoScaling::ScalableTarget
    Properties:
      ServiceNamespace: ecs
      ResourceId: !Sub 'service/${ECSCluster}/${ECSService.Name}'
      ScalableDimension: ecs:service:DesiredCount
      MinCapacity: 1
      MaxCapacity: 10
      RoleARN: !Sub 'arn:aws:iam::${AWS::AccountId}:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService'

  AutoScalingPolicy:
    Type: AWS::ApplicationAutoScaling::ScalingPolicy
    Properties:
      PolicyName: !Sub '${ProjectName}-${EnvironmentName}-scaling-policy'
      PolicyType: TargetTrackingScaling
      ScalingTargetId: !Ref AutoScalingTarget
      TargetTrackingScalingPolicyConfiguration:
        PredefinedMetricSpecification:
          PredefinedMetricType: ECSServiceAverageCPUUtilization
        TargetValue: 70.0
        ScaleOutCooldown: 300
        ScaleInCooldown: 300

Outputs:
  ClusterName:
    Description: 'ECS Cluster name'
    Value: !Ref ECSCluster
    Export:
      Name: !Sub '${AWS::StackName}-ClusterName'
  
  ServiceName:
    Description: 'ECS Service name'
    Value: !GetAtt ECSService.Name
    Export:
      Name: !Sub '${AWS::StackName}-ServiceName'
  
  LoadBalancerDNS:
    Description: 'Application Load Balancer DNS name'
    Value: !GetAtt ApplicationLoadBalancer.DNSName
    Export:
      Name: !Sub '${AWS::StackName}-LoadBalancerDNS'
  
  ServiceDiscoveryArn:
    Description: 'Service Discovery service ARN'
    Value: !GetAtt ServiceDiscovery.Arn
    Export:
      Name: !Sub '${AWS::StackName}-ServiceDiscoveryArn'
```

### ステップ3: コンテナイメージのビルドとデプロイ

1. **Docker イメージのビルドとプッシュ**
```bash
# ECRログイン
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# イメージビルド
docker build -t ecs-container-dev .

# タグ付け
docker tag ecs-container-dev:latest $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ecs-container-dev:latest

# プッシュ
docker push $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ecs-container-dev:latest
```

2. **CloudFormationスタックのデプロイ**
```bash
# ECRリポジトリ作成
aws cloudformation create-stack \
  --stack-name ecs-container-dev-ecr \
  --template-body file://ecr-repository.yaml

# ECSクラスター作成
aws cloudformation create-stack \
  --stack-name ecs-container-dev-cluster \
  --template-body file://ecs-cluster.yaml \
  --parameters ParameterKey=VpcId,ParameterValue=vpc-12345678 \
               ParameterKey=PrivateSubnetIds,ParameterValue="subnet-123,subnet-456" \
               ParameterKey=PublicSubnetIds,ParameterValue="subnet-789,subnet-012" \
               ParameterKey=ContainerImage,ParameterValue=$ECR_URI:latest \
  --capabilities CAPABILITY_IAM
```

## 検証方法

### 1. ECSサービスの健全性確認
```bash
# クラスター情報確認
aws ecs describe-clusters --clusters ecs-container-dev-cluster

# サービス状態確認
aws ecs describe-services \
  --cluster ecs-container-dev-cluster \
  --services ecs-container-dev-service

# タスク一覧確認
aws ecs list-tasks --cluster ecs-container-dev-cluster \
  --service-name ecs-container-dev-service
```

### 2. ロードバランサー経由でのアクセステスト
```bash
# ALB DNS名取得
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name ecs-container-dev-cluster \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
  --output text)

# アプリケーション動作確認
curl http://$ALB_DNS
curl http://$ALB_DNS/health
```

### 3. Auto Scalingテスト
```bash
# CPUメトリクス確認
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=ecs-container-dev-service \
               Name=ClusterName,Value=ecs-container-dev-cluster \
  --start-time 2023-01-01T00:00:00Z \
  --end-time 2023-01-01T23:59:59Z \
  --period 300 \
  --statistics Average
```

## トラブルシューティング

### よくある問題と解決策

#### 1. タスクが起動しない
**症状**: タスクがPENDING状態のまま
**解決策**:
```bash
# タスクの詳細エラー確認
aws ecs describe-tasks \
  --cluster ecs-container-dev-cluster \
  --tasks <task-arn> \
  --include TAGS

# CloudWatchロググループ確認
aws logs describe-log-streams \
  --log-group-name /ecs/ecs-container-dev
```

#### 2. コンテナヘルスチェック失敗
**症状**: タスクが継続的に再起動
**解決策**:
- ヘルスチェックエンドポイント(`/health`)が正常に応答しているか確認
- コンテナのポート設定とセキュリティグループの整合性確認
- CloudWatchログでアプリケーションエラー確認

#### 3. ロードバランサーからアクセスできない
**症状**: ALBのDNSにアクセスしても503エラー
**解決策**:
```bash
# ターゲットグループの健全性確認
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# セキュリティグループルール確認
aws ec2 describe-security-groups \
  --group-ids <security-group-id>
```

## 学習リソース

### AWS公式ドキュメント
- [Amazon ECS 開発者ガイド](https://docs.aws.amazon.com/ecs/latest/developerguide/)
- [AWS Fargate ユーザーガイド](https://docs.aws.amazon.com/AmazonECS/latest/userguide/what-is-fargate.html)
- [Amazon ECR ユーザーガイド](https://docs.aws.amazon.com/ecr/latest/userguide/)

### 追加学習教材
- [Docker Documentation](https://docs.docker.com/)
- [ECS Workshop](https://ecsworkshop.com/)
- [AWS Containers Blog](https://aws.amazon.com/blogs/containers/)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **最小権限IAMロール**: タスクに必要最小限の権限のみ付与
2. **プライベートネットワーク**: コンテナはプライベートサブネットで実行
3. **イメージスキャン**: ECRでの脆弱性スキャン有効化
4. **シークレット管理**: AWS Secrets Managerまたは Parameter Store使用

### コスト最適化
1. **Fargate Spot**: 開発環境での利用
2. **適切なリソース配分**: CPU・メモリの最適化
3. **Auto Scaling**: 需要に応じたスケーリング
4. **ログ保持期間**: CloudWatch Logsの適切な設定

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: Container Insights・CloudWatchによる監視
- **セキュリティの柱**: タスクレベルIAMロールとネットワーク分離
- **信頼性の柱**: Multi-AZ配置とヘルスチェック
- **パフォーマンス効率の柱**: Fargateの自動リソース管理
- **コスト最適化の柱**: サーバーレス実行とSpotインスタンス

## 次のステップ

### 推奨される学習パス
1. **1.2.3 Lambda関数デプロイ**: サーバーレスアーキテクチャとの比較
2. **2.2.1 REST-API**: ECSでのAPI構築
3. **3.1.2 データ操作API**: マイクロサービス実装
4. **6.1.1 マルチステージビルド**: Container CI/CD

### 発展的な機能
1. **ECS Exec**: 本番コンテナへの安全なアクセス
2. **サービスメッシュ**: AWS App Meshによるサービス間通信
3. **Blue-Green デプロイ**: CodeDeployとの統合
4. **マルチリージョン展開**: グローバル負荷分散

### 実践プロジェクトのアイデア
1. **マイクロサービスアーキテクチャ**: 複数サービスの協調動作
2. **API Gateway + ECS**: サーバーレスゲートウェイと組み合わせ
3. **データ処理パイプライン**: バッチ処理のコンテナ化
4. **CI/CD パイプライン**: GitHub ActionsによるContainer デプロイ