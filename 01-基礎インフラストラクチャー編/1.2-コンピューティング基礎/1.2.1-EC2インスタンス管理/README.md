# 1.2.1 EC2インスタンス管理

## 学習目標

このセクションでは、Amazon EC2を活用したスケーラブルで高可用性のあるコンピューティング環境を構築し、Auto ScalingとLoad Balancerを組み合わせた本格的なWebアプリケーション基盤を学習します。

### 習得できるスキル
- EC2インスタンスのライフサイクル管理
- Auto Scaling Groupによる自動スケーリング
- Application Load Balancer（ALB）による負荷分散
- セキュリティグループとネットワーク設定
- CloudWatchによる監視とアラート設定
- Systems Managerによる運用自動化

## 前提知識

### 必須の知識
- VPCとネットワーク基礎（1.1.2セクション完了）
- Linux/Windowsの基本操作
- SSHとリモートアクセスの概念
- HTTPとWebサーバーの基礎知識

### あると望ましい知識
- シェルスクリプトの作成経験
- Webサーバー（Apache/Nginx）の設定経験
- ロードバランサーの基本概念
- CloudWatchの基本操作

## アーキテクチャ概要

### EC2マルチAZ構成

```
                                   ┌─────────────────┐
                                   │   Internet      │
                                   │   Gateway       │
                                   └─────────┬───────┘
                                             │
                          ┌──────────────────┼──────────────────┐
                          │                  │                  │
                          ▼                  ▼                  ▼
          ┌─────────────────────────────────────────────────────────┐
          │              Application Load Balancer                │
          │           (Multi-AZ Traffic Distribution)             │
          └─────────────────────┬───────────────────────────────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
              ▼                 ▼                 ▼
┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
│   Availability      │ │   Availability      │ │   Availability      │
│     Zone 1a         │ │     Zone 1c         │ │     Zone 1d         │
│                     │ │                     │ │                     │
│ ┌─────────────────┐ │ │ ┌─────────────────┐ │ │ ┌─────────────────┐ │
│ │  Public Subnet  │ │ │ │  Public Subnet  │ │ │ │  Public Subnet  │ │
│ │  (10.0.1.0/24)  │ │ │ │  (10.0.2.0/24)  │ │ │ │  (10.0.3.0/24)  │ │
│ │                 │ │ │ │                 │ │ │ │                 │ │
│ │ ┌─────────────┐ │ │ │ │ ┌─────────────┐ │ │ │ │ ┌─────────────┐ │ │
│ │ │    NAT      │ │ │ │ │ │    NAT      │ │ │ │ │ │    NAT      │ │ │
│ │ │   Gateway   │ │ │ │ │ │   Gateway   │ │ │ │ │ │   Gateway   │ │ │
│ │ └─────────────┘ │ │ │ │ └─────────────┘ │ │ │ │ └─────────────┘ │ │
│ └─────────────────┘ │ │ └─────────────────┘ │ │ └─────────────────┘ │
│                     │ │                     │ │                     │
│ ┌─────────────────┐ │ │ ┌─────────────────┐ │ │ ┌─────────────────┐ │
│ │ Private Subnet  │ │ │ │ Private Subnet  │ │ │ │ Private Subnet  │ │
│ │ (10.0.11.0/24)  │ │ │ │ (10.0.12.0/24)  │ │ │ │ (10.0.13.0/24)  │ │
│ │                 │ │ │ │                 │ │ │ │                 │ │
│ │ ┌─────────────┐ │ │ │ │ ┌─────────────┐ │ │ │ │ ┌─────────────┐ │ │
│ │ │   Web       │ │ │ │ │ │   Web       │ │ │ │ │ │   Web       │ │ │
│ │ │  Servers    │ │ │ │ │ │  Servers    │ │ │ │ │ │  Servers    │ │ │
│ │ │(Auto Scaling│ │ │ │ │ │(Auto Scaling│ │ │ │ │ │(Auto Scaling│ │ │
│ │ │   Group)    │ │ │ │ │ │   Group)    │ │ │ │ │ │   Group)    │ │ │
│ │ └─────────────┘ │ │ │ │ └─────────────┘ │ │ │ │ └─────────────┘ │ │
│ └─────────────────┘ │ │ └─────────────────┘ │ │ └─────────────────┘ │
└─────────────────────┘ └─────────────────────┘ └─────────────────────┘
```

### 主要コンポーネント
- **Application Load Balancer**: L7負荷分散とヘルスチェック
- **Auto Scaling Group**: 需要に応じた自動スケーリング
- **EC2インスタンス**: Webアプリケーションホスティング
- **Launch Template**: インスタンス設定のテンプレート化
- **CloudWatch**: メトリクス監視とアラート

## ハンズオン手順

### ステップ1: Launch Templateの作成

1. **EC2設定テンプレートの定義**
```bash
cd /mnt/c/dev2/practice/01-基礎インフラストラクチャー編/1.2-コンピューティング基礎/1.2.1-EC2インスタンス管理/cloudformation
```

2. **Launch Template CloudFormationテンプレート**
```yaml
# launch-template.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'EC2 Launch Template for Auto Scaling'

Parameters:
  ProjectName:
    Type: String
    Default: 'ec2-management'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
    AllowedValues: [dev, staging, prod]
  
  InstanceType:
    Type: String
    Default: 't3.micro'
    AllowedValues: [t3.micro, t3.small, t3.medium, t3.large]
  
  KeyPairName:
    Type: String
    Description: 'Name of an existing EC2 KeyPair for SSH access'
  
  VpcId:
    Type: String
    Description: 'VPC ID where instances will be launched'

Resources:
  WebServerLaunchTemplate:
    Type: AWS::EC2::LaunchTemplate
    Properties:
      LaunchTemplateName: !Sub '${ProjectName}-${EnvironmentName}-web-server'
      LaunchTemplateData:
        ImageId: ami-0c55b159cbfafe1d0  # Amazon Linux 2 AMI (update as needed)
        InstanceType: !Ref InstanceType
        KeyName: !Ref KeyPairName
        SecurityGroupIds:
          - !Ref WebServerSecurityGroup
        IamInstanceProfile:
          Arn: !GetAtt EC2InstanceProfile.Arn
        UserData:
          Fn::Base64: !Sub |
            #!/bin/bash
            yum update -y
            yum install -y httpd aws-cli
            
            # Install CloudWatch agent
            wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
            rpm -U ./amazon-cloudwatch-agent.rpm
            
            # Configure web server
            systemctl start httpd
            systemctl enable httpd
            
            # Create sample web page
            cat <<EOF > /var/www/html/index.html
            <!DOCTYPE html>
            <html>
            <head>
                <title>EC2 Instance - ${EnvironmentName}</title>
                <style>
                    body { font-family: Arial, sans-serif; margin: 40px; }
                    .header { background-color: #232f3e; color: white; padding: 20px; }
                    .content { padding: 20px; }
                    .info { background-color: #f0f0f0; padding: 10px; margin: 10px 0; }
                </style>
            </head>
            <body>
                <div class="header">
                    <h1>EC2 Web Server - ${EnvironmentName}</h1>
                </div>
                <div class="content">
                    <h2>Instance Information</h2>
                    <div class="info">
                        <strong>Instance ID:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)
                    </div>
                    <div class="info">
                        <strong>Availability Zone:</strong> $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
                    </div>
                    <div class="info">
                        <strong>Instance Type:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-type)
                    </div>
                    <div class="info">
                        <strong>Private IP:</strong> $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
                    </div>
                    <div class="info">
                        <strong>Timestamp:</strong> $(date)
                    </div>
                </div>
            </body>
            </html>
            EOF
            
            # Start CloudWatch agent
            /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
              -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json -s
        TagSpecifications:
          - ResourceType: instance
            Tags:
              - Key: Name
                Value: !Sub '${ProjectName}-${EnvironmentName}-web-server'
              - Key: Environment
                Value: !Ref EnvironmentName
              - Key: Project
                Value: !Ref ProjectName

  WebServerSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: 'Security group for web servers'
      VpcId: !Ref VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          SourceSecurityGroupId: !Ref ALBSecurityGroup
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          SourceSecurityGroupId: !Ref ALBSecurityGroup
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 10.0.0.0/16  # VPC CIDR only
      SecurityGroupEgress:
        - IpProtocol: -1
          CidrIp: 0.0.0.0/0
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-web-sg'

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

  EC2Role:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
        - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
      Policies:
        - PolicyName: EC2BasicAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - ec2:DescribeInstances
                  - ec2:DescribeTags
                Resource: '*'

  EC2InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Roles:
        - !Ref EC2Role

Outputs:
  LaunchTemplateId:
    Description: 'Launch Template ID'
    Value: !Ref WebServerLaunchTemplate
    Export:
      Name: !Sub '${AWS::StackName}-LaunchTemplate'
  
  WebServerSecurityGroupId:
    Description: 'Web Server Security Group ID'
    Value: !Ref WebServerSecurityGroup
    Export:
      Name: !Sub '${AWS::StackName}-WebServerSG'
  
  ALBSecurityGroupId:
    Description: 'ALB Security Group ID'
    Value: !Ref ALBSecurityGroup
    Export:
      Name: !Sub '${AWS::StackName}-ALBSG'
```

### ステップ2: Auto Scaling Groupの設定

1. **Auto Scaling設定**
```yaml
# auto-scaling.yaml  
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Auto Scaling Group with Application Load Balancer'

Parameters:
  ProjectName:
    Type: String
    Default: 'ec2-management'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
  
  LaunchTemplateId:
    Type: String
    Description: 'Launch Template ID'
  
  VpcId:
    Type: String
    Description: 'VPC ID'
  
  PublicSubnetIds:
    Type: CommaDelimitedList
    Description: 'List of public subnet IDs for load balancer'
  
  PrivateSubnetIds:
    Type: CommaDelimitedList
    Description: 'List of private subnet IDs for instances'
  
  MinSize:
    Type: Number
    Default: 1
    Description: 'Minimum number of instances'
  
  MaxSize:
    Type: Number
    Default: 3
    Description: 'Maximum number of instances'
  
  DesiredCapacity:
    Type: Number
    Default: 2
    Description: 'Desired number of instances'

Resources:
  ApplicationLoadBalancer:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-alb'
      Type: application
      Scheme: internet-facing
      Subnets: !Ref PublicSubnetIds
      SecurityGroups:
        - !ImportValue 
          Fn::Sub: '${ProjectName}-${EnvironmentName}-launch-template-ALBSG'
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-alb'

  TargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-tg'
      Port: 80
      Protocol: HTTP
      VpcId: !Ref VpcId
      HealthCheckPath: /
      HealthCheckIntervalSeconds: 30
      HealthCheckTimeoutSeconds: 5
      HealthyThresholdCount: 2
      UnhealthyThresholdCount: 3
      TargetType: instance
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-tg'

  ALBListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      DefaultActions:
        - Type: forward
          TargetGroupArn: !Ref TargetGroup
      LoadBalancerArn: !Ref ApplicationLoadBalancer
      Port: 80
      Protocol: HTTP

  AutoScalingGroup:
    Type: AWS::AutoScaling::AutoScalingGroup
    Properties:
      AutoScalingGroupName: !Sub '${ProjectName}-${EnvironmentName}-asg'
      LaunchTemplate:
        LaunchTemplateId: !Ref LaunchTemplateId
        Version: !GetAtt LaunchTemplateVersion.LatestVersionNumber
      MinSize: !Ref MinSize
      MaxSize: !Ref MaxSize
      DesiredCapacity: !Ref DesiredCapacity
      VPCZoneIdentifier: !Ref PrivateSubnetIds
      TargetGroupARNs:
        - !Ref TargetGroup
      HealthCheckType: ELB
      HealthCheckGracePeriod: 300
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-asg-instance'
          PropagateAtLaunch: true
        - Key: Environment
          Value: !Ref EnvironmentName
          PropagateAtLaunch: true

  LaunchTemplateVersion:
    Type: AWS::EC2::LaunchTemplate
    Properties:
      LaunchTemplateId: !Ref LaunchTemplateId

  # Auto Scaling Policies
  ScaleUpPolicy:
    Type: AWS::AutoScaling::ScalingPolicy
    Properties:
      AutoScalingGroupName: !Ref AutoScalingGroup
      PolicyType: TargetTrackingScaling
      TargetTrackingConfiguration:
        PredefinedMetricSpecification:
          PredefinedMetricType: ASGAverageCPUUtilization
        TargetValue: 70.0
        ScaleOutCooldown: 300
        ScaleInCooldown: 300

  # CloudWatch Alarms
  HighCPUAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${ProjectName}-${EnvironmentName}-high-cpu'
      AlarmDescription: 'High CPU utilization alarm'
      MetricName: CPUUtilization
      Namespace: AWS/EC2
      Statistic: Average
      Period: 300
      EvaluationPeriods: 2
      Threshold: 80
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: AutoScalingGroupName
          Value: !Ref AutoScalingGroup

Outputs:
  LoadBalancerDNS:
    Description: 'Application Load Balancer DNS name'
    Value: !GetAtt ApplicationLoadBalancer.DNSName
    Export:
      Name: !Sub '${AWS::StackName}-LoadBalancerDNS'
  
  AutoScalingGroupName:
    Description: 'Auto Scaling Group name'
    Value: !Ref AutoScalingGroup
    Export:
      Name: !Sub '${AWS::StackName}-AutoScalingGroup'
```

### ステップ3: デプロイとテスト

1. **スタックのデプロイ**
```bash
# Launch Template作成
aws cloudformation create-stack \
  --stack-name ec2-management-dev-launch-template \
  --template-body file://launch-template.yaml \
  --parameters ParameterKey=KeyPairName,ParameterValue=my-key-pair \
               ParameterKey=VpcId,ParameterValue=vpc-12345678 \
  --capabilities CAPABILITY_IAM

# Auto Scaling Group作成
aws cloudformation create-stack \
  --stack-name ec2-management-dev-auto-scaling \
  --template-body file://auto-scaling.yaml \
  --parameters ParameterKey=LaunchTemplateId,ParameterValue=lt-12345678 \
               ParameterKey=VpcId,ParameterValue=vpc-12345678 \
               ParameterKey=PublicSubnetIds,ParameterValue="subnet-12345678,subnet-87654321" \
               ParameterKey=PrivateSubnetIds,ParameterValue="subnet-abcdefgh,subnet-hgfedcba"
```

2. **動作確認**
```bash
# ロードバランサーのDNS名取得
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name ec2-management-dev-auto-scaling \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
  --output text)

# Web アプリケーションの動作確認
curl http://$ALB_DNS
```

## 検証方法

### 1. インスタンスの健全性確認
```bash
# Auto Scaling Group内のインスタンス確認
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ec2-management-dev-asg

# インスタンスの状態確認
aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=ec2-management-dev-asg" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]'
```

### 2. ロードバランサーのヘルスチェック
```bash
# ターゲットグループの健全性確認
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:region:account:targetgroup/name/id
```

### 3. スケーリング動作テスト
```bash
# CPU負荷テスト（インスタンス内で実行）
sudo yum install -y stress
stress --cpu 2 --timeout 600s  # 10分間CPU負荷をかける

# Auto Scalingの動作確認
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name ec2-management-dev-asg
```

## トラブルシューティング

### よくある問題と解決策

#### 1. インスタンスがヘルスチェックに失敗
**症状**: インスタンスがUnhealthy状態
**解決策**:
- セキュリティグループでHTTP(80)ポートが開放されているか確認
- ヘルスチェックパス(`/`)にアクセス可能か確認
- UserDataスクリプトが正常に実行されているか確認

#### 2. Auto Scalingが動作しない
**症状**: CPU使用率が高いのにスケールアウトしない
**解決策**:
```bash
# CloudWatchメトリクスの確認
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=ec2-management-dev-asg \
  --start-time 2023-01-01T00:00:00Z \
  --end-time 2023-01-01T23:59:59Z \
  --period 300 \
  --statistics Average
```

#### 3. ロードバランサーにアクセスできない
**症状**: ALB DNS名にアクセスしてもタイムアウト
**解決策**:
- ALBセキュリティグループでインターネットからのアクセスが許可されているか確認
- パブリックサブネットにALBが配置されているか確認
- インターネットゲートウェイとルートテーブルの設定確認

## 学習リソース

### AWS公式ドキュメント
- [Amazon EC2 ユーザーガイド](https://docs.aws.amazon.com/ec2/latest/userguide/)
- [Auto Scaling ユーザーガイド](https://docs.aws.amazon.com/autoscaling/ec2/userguide/)
- [Elastic Load Balancing ユーザーガイド](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)

### 追加学習教材
- [EC2 Instance Connect を使用した SSH 接続](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Connect-using-EC2-Instance-Connect.html)
- [Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **最小権限の原則**: 必要最小限のセキュリティグループルール
2. **プライベート配置**: Webサーバーはプライベートサブネットに配置
3. **パッチ管理**: Systems Manager Patch Managerの活用
4. **監査ログ**: CloudTrailでのAPI呼び出し記録

### コスト最適化
1. **適切なインスタンスタイプ**: ワークロードに応じたサイズ選択
2. **Spot Instance**: 開発環境でのコスト削減
3. **スケジュールベーススケーリング**: 予測可能な負荷パターンの活用
4. **リザーブドインスタンス**: 本番環境での長期割引

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatchによる監視と自動復旧
- **セキュリティの柱**: VPC分離とセキュリティグループ
- **信頼性の柱**: Multi-AZ配置と自動スケーリング
- **パフォーマンス効率の柱**: Auto Scalingによる動的リソース調整
- **コスト最適化の柱**: 需要に応じたリソース利用

## 次のステップ

### 推奨される学習パス
1. **1.2.2 ECSとコンテナ基礎**: コンテナベースの実行環境
2. **1.2.3 Lambda関数デプロイ**: サーバーレスコンピューティング
3. **2.1.1 静的サイトホスティング**: フロントエンドとの組み合わせ
4. **6.2.1 APM実装**: アプリケーション監視の強化

### 発展的な機能
1. **Spot Fleet**: コスト効率的なスケーリング
2. **Predictive Scaling**: 機械学習ベースの予測スケーリング
3. **混合インスタンスポリシー**: 複数インスタンスタイプの組み合わせ
4. **Blue-Green デプロイ**: ゼロダウンタイムデプロイメント

### 実践プロジェクトのアイデア
1. **3層Webアプリケーション**: ALB + EC2 + RDS構成
2. **マイクロサービス基盤**: 複数のサービス用Auto Scaling Group
3. **CI/CDパイプライン統合**: コード変更時の自動デプロイ
4. **災害復旧システム**: Cross-Region での冗長化