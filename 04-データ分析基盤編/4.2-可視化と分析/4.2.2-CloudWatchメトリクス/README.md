# 4.2.2 CloudWatchメトリクス

## 学習目標

このセクションでは、Amazon CloudWatchを活用した包括的な監視・アラート・ダッシュボードシステムを構築し、アプリケーション・インフラ・ビジネスメトリクスの可視化と自動化された運用管理の実装方法を習得します。

### 習得できるスキル
- CloudWatch メトリクス・ログ・アラームの統合管理
- カスタムメトリクスとビジネスKPI監視
- CloudWatch Dashboards による統合監視画面構築
- CloudWatch Insights による高度なログ分析
- EventBridge を活用した自動化された対応フロー
- SLA/SLO 監視とアラート設計

## 前提知識

### 必須の知識
- CloudWatch の基本概念とメトリクス
- Lambda 関数の開発と運用（1.2.3セクション完了）
- DynamoDB の基本操作（2.3.2セクション完了）
- API Gateway の基本操作（2.2.1セクション完了）

### あると望ましい知識
- 可観測性（Observability）の基本概念
- SLI/SLO/SLA の設計原則
- 運用監視のベストプラクティス
- 統計学・データ分析の基礎知識

## アーキテクチャ概要

### 包括的監視・分析アーキテクチャ

```
                    ┌─────────────────────┐
                    │   Stakeholders      │
                    │ (DevOps/SRE/Biz)    │
                    │                     │
                    │ ┌─────────────────┐ │
                    │ │  Monitoring     │ │
                    │ │  Dashboards     │ │
                    │ │  (Executive/    │ │
                    │ │   Technical)    │ │
                    │ └─────────────────┘ │
                    └─────────┬───────────┘
                              │
                    ┌─────────┼───────────┐
                    │         │           │
                    ▼         ▼           ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   CloudWatch    │ │  Mobile  │ │   Slack/Teams   │
          │   Dashboards    │ │  Alerts  │ │   Integration   │
          └─────────┬───────┘ └────┬─────┘ └─────────┬───────┘
                    │              │                 │
                    └──────────────┼─────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │               Amazon CloudWatch                         │
          │                                                         │
          │  ┌─────────────────────────────────────────────────┐   │
          │  │             Metrics & Analytics                 │   │
          │  │                                                  │   │
          │  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │   │
          │  │  │   System    │  │  Business   │  │   SLO    │ │   │
          │  │  │  Metrics    │  │  Metrics    │  │ Metrics  │ │   │
          │  │  │             │  │             │  │          │ │   │
          │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │┌────────┐│ │   │
          │  │  │ │CPU/     │ │  │ │Revenue  │ │  ││Error   ││ │   │
          │  │  │ │Memory   │ │  │ │Orders   │ │  ││Rate    ││ │   │
          │  │  │ │Network  │ │  │ │Users    │ │  ││Latency ││ │   │
          │  │  │ └─────────┘ │  │ └─────────┘ │  │└────────┘│ │   │
          │  │  └─────────────┘  └─────────────┘  └──────────┘ │   │
          │  └─────────────────────────────────────────────────┘   │
          │                                                         │
          │  ┌─────────────────────────────────────────────────┐   │
          │  │               Logs & Insights                   │   │
          │  │                                                  │   │
          │  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │   │
          │  │  │Application  │  │    Access   │  │  Error   │ │   │
          │  │  │    Logs     │  │    Logs     │  │   Logs   │ │   │
          │  │  │             │  │             │  │          │ │   │
          │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │┌────────┐│ │   │
          │  │  │ │Lambda   │ │  │ │API GW   │ │  ││Lambda  ││ │   │
          │  │  │ │Logs     │ │  │ │Access   │ │  ││Errors  ││ │   │
          │  │  │ └─────────┘ │  │ └─────────┘ │  │└────────┘│ │   │
          │  │  └─────────────┘  └─────────────┘  └──────────┘ │   │
          │  └─────────────────────────────────────────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │               Alarms & Notifications                    │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │Threshold    │  │ Anomaly     │  │ Composite   │   │
          │  │Alarms       │  │ Detection   │  │ Alarms      │   │
          │  │             │  │             │  │             │   │
          │  │┌──────────┐ │  │┌──────────┐ │  │┌──────────┐ │   │
          │  ││Critical  │ │  ││ML-based  │ │  ││Service   │ │   │
          │  ││Warning   │ │  ││Anomaly   │ │  ││Health    │ │   │
          │  ││Info      │ │  ││Detection │ │  ││SLA       │ │   │
          │  │└──────────┘ │  │└──────────┘ │  │└──────────┘ │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────┬───────────────┬───────────────┬─────────────┘
                    │               │               │
                    ▼               ▼               ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │      SNS        │ │EventBridge│ │   Lambda        │
          │ (Notifications) │ │(Events)   │ │ (Auto-response) │
          │                 │ │          │ │                 │
          │ ┌─────────────┐ │ │┌────────┐ │ │ ┌─────────────┐ │
          │ │Email        │ │ ││Rules   │ │ │ │Auto-scaling │ │
          │ │SMS          │ │ ││Targets │ │ │ │Remediation  │ │
          │ │Slack        │ │ ││Filters │ │ │ │Escalation   │ │
          │ └─────────────┘ │ │└────────┘ │ │ └─────────────┘ │
          └─────────────────┘ └──────────┘ └─────────────────┘
                    │               │               │
                    ▼               ▼               ▼
          ┌─────────────────────────────────────────────────────────┐
          │              Data Sources & Targets                     │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │   AWS       │  │Application  │  │    Third    │   │
          │  │ Services    │  │  Services   │  │   Party     │   │
          │  │             │  │             │  │             │   │
          │  │┌──────────┐ │  │┌──────────┐ │  │┌──────────┐ │   │
          │  ││EC2       │ │  ││Custom    │ │  ││External  │ │   │
          │  ││Lambda    │ │  ││Apps      │ │  ││APIs      │ │   │
          │  ││RDS       │ │  ││Containers│ │  ││Services  │ │   │
          │  ││API GW    │ │  ││K8s       │ │  ││SaaS      │ │   │
          │  │└──────────┘ │  │└──────────┘ │  │└──────────┘ │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **CloudWatch Metrics**: システム・アプリケーション・ビジネスメトリクス
- **CloudWatch Logs**: 集約ログ管理と分析
- **CloudWatch Alarms**: 閾値・異常検知・複合アラーム
- **CloudWatch Dashboards**: カスタム監視ダッシュボード
- **CloudWatch Insights**: 高度なログ分析とクエリ
- **EventBridge**: イベント駆動自動化

## ハンズオン手順

### ステップ1: 包括的監視インフラストラクチャ構築

1. **CloudFormation 監視スタック**
```yaml
# cloudformation/monitoring-infrastructure.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Comprehensive monitoring and alerting infrastructure'

Parameters:
  ProjectName:
    Type: String
    Default: 'monitoring-demo'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
    AllowedValues: [dev, staging, prod]
  
  NotificationEmail:
    Type: String
    Description: 'Email address for alerts'
    Default: 'admin@example.com'
  
  SlackWebhookUrl:
    Type: String
    Description: 'Slack webhook URL for notifications'
    Default: 'https://hooks.slack.com/services/...'
    NoEcho: true

Conditions:
  IsProduction: !Equals [!Ref EnvironmentName, 'prod']

Resources:
  # SNS Topics for Alerts
  CriticalAlertsTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: !Sub '${ProjectName}-${EnvironmentName}-critical-alerts'
      DisplayName: 'Critical System Alerts'
      KmsMasterKeyId: alias/aws/sns

  WarningAlertsTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: !Sub '${ProjectName}-${EnvironmentName}-warning-alerts'
      DisplayName: 'Warning System Alerts'

  InfoAlertsTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: !Sub '${ProjectName}-${EnvironmentName}-info-alerts'
      DisplayName: 'Informational Alerts'

  # Email Subscriptions
  CriticalEmailSubscription:
    Type: AWS::SNS::Subscription
    Properties:
      Protocol: email
      TopicArn: !Ref CriticalAlertsTopic
      Endpoint: !Ref NotificationEmail

  # Lambda for Slack Integration
  SlackNotificationFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-slack-notifier'
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt SlackNotificationRole.Arn
      Environment:
        Variables:
          SLACK_WEBHOOK_URL: !Ref SlackWebhookUrl
          ENVIRONMENT: !Ref EnvironmentName
      Code:
        ZipFile: |
          import json
          import urllib3
          import os
          
          def lambda_handler(event, context):
              webhook_url = os.environ['SLACK_WEBHOOK_URL']
              environment = os.environ['ENVIRONMENT']
              
              # Parse SNS message
              message = json.loads(event['Records'][0]['Sns']['Message'])
              
              # Format Slack message
              slack_message = {
                  "text": f"🚨 Alert in {environment.upper()}",
                  "attachments": [
                      {
                          "color": get_color(message.get('NewStateValue', 'UNKNOWN')),
                          "fields": [
                              {
                                  "title": "Alarm Name",
                                  "value": message.get('AlarmName', 'Unknown'),
                                  "short": True
                              },
                              {
                                  "title": "State",
                                  "value": message.get('NewStateValue', 'Unknown'),
                                  "short": True
                              },
                              {
                                  "title": "Reason",
                                  "value": message.get('NewStateReason', 'No reason provided'),
                                  "short": False
                              }
                          ]
                      }
                  ]
              }
              
              # Send to Slack
              http = urllib3.PoolManager()
              response = http.request(
                  'POST',
                  webhook_url,
                  body=json.dumps(slack_message),
                  headers={'Content-Type': 'application/json'}
              )
              
              return {
                  'statusCode': 200,
                  'body': json.dumps('Message sent to Slack')
              }
          
          def get_color(state):
              colors = {
                  'ALARM': 'danger',
                  'OK': 'good',
                  'INSUFFICIENT_DATA': 'warning'
              }
              return colors.get(state, '#439FE0')
      Timeout: 30

  # SNS Subscription for Slack
  SlackSubscription:
    Type: AWS::SNS::Subscription
    Properties:
      Protocol: lambda
      TopicArn: !Ref CriticalAlertsTopic
      Endpoint: !GetAtt SlackNotificationFunction.Arn

  # Lambda Permission for SNS
  SlackNotificationPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref SlackNotificationFunction
      Action: lambda:InvokeFunction
      Principal: sns.amazonaws.com
      SourceArn: !Ref CriticalAlertsTopic

  # CloudWatch Dashboard
  MonitoringDashboard:
    Type: AWS::CloudWatch::Dashboard
    Properties:
      DashboardName: !Sub '${ProjectName}-${EnvironmentName}-monitoring'
      DashboardBody: !Sub |
        {
          "widgets": [
            {
              "type": "metric",
              "x": 0,
              "y": 0,
              "width": 12,
              "height": 6,
              "properties": {
                "metrics": [
                  ["AWS/Lambda", "Duration", "FunctionName", "user-management-api"],
                  [".", "Errors", ".", "."],
                  [".", "Invocations", ".", "."]
                ],
                "period": 300,
                "stat": "Average",
                "region": "${AWS::Region}",
                "title": "Lambda Function Metrics",
                "yAxis": {
                  "left": {
                    "min": 0
                  }
                }
              }
            },
            {
              "type": "metric",
              "x": 12,
              "y": 0,
              "width": 12,
              "height": 6,
              "properties": {
                "metrics": [
                  ["AWS/ApiGateway", "Count", "ApiName", "data-api"],
                  [".", "Latency", ".", "."],
                  [".", "4XXError", ".", "."],
                  [".", "5XXError", ".", "."]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "${AWS::Region}",
                "title": "API Gateway Metrics"
              }
            },
            {
              "type": "metric",
              "x": 0,
              "y": 6,
              "width": 24,
              "height": 6,
              "properties": {
                "metrics": [
                  ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", "main-table"],
                  [".", "ConsumedWriteCapacityUnits", ".", "."],
                  [".", "ThrottledRequests", ".", "."]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "${AWS::Region}",
                "title": "DynamoDB Performance"
              }
            }
          ]
        }

  # Custom Metrics Lambda Function
  CustomMetricsFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-custom-metrics'
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt CustomMetricsRole.Arn
      Environment:
        Variables:
          ENVIRONMENT: !Ref EnvironmentName
          PROJECT_NAME: !Ref ProjectName
      Code:
        ZipFile: |
          import boto3
          import json
          import os
          from datetime import datetime
          
          cloudwatch = boto3.client('cloudwatch')
          
          def lambda_handler(event, context):
              namespace = f"{os.environ['PROJECT_NAME']}/{os.environ['ENVIRONMENT']}"
              
              # Business metrics simulation
              metrics = [
                  {
                      'MetricName': 'ActiveUsers',
                      'Value': 150.0,
                      'Unit': 'Count',
                      'Dimensions': [
                          {
                              'Name': 'Environment',
                              'Value': os.environ['ENVIRONMENT']
                          }
                      ]
                  },
                  {
                      'MetricName': 'OrdersProcessed',
                      'Value': 25.0,
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
                      'Value': 12500.0,
                      'Unit': 'None',
                      'Dimensions': [
                          {
                              'Name': 'Environment',
                              'Value': os.environ['ENVIRONMENT']
                          }
                      ]
                  }
              ]
              
              # Send metrics to CloudWatch
              cloudwatch.put_metric_data(
                  Namespace=namespace,
                  MetricData=metrics
              )
              
              return {
                  'statusCode': 200,
                  'body': json.dumps('Custom metrics sent successfully')
              }
      Timeout: 60

  # EventBridge Rule for Custom Metrics
  CustomMetricsSchedule:
    Type: AWS::Events::Rule
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-custom-metrics-schedule'
      Description: 'Trigger custom metrics collection every 5 minutes'
      ScheduleExpression: 'rate(5 minutes)'
      State: ENABLED
      Targets:
        - Arn: !GetAtt CustomMetricsFunction.Arn
          Id: 'CustomMetricsTarget'

  # Permission for EventBridge to invoke Lambda
  CustomMetricsPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref CustomMetricsFunction
      Action: lambda:InvokeFunction
      Principal: events.amazonaws.com
      SourceArn: !GetAtt CustomMetricsSchedule.Arn

  # CloudWatch Alarms
  HighErrorRateAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${ProjectName}-${EnvironmentName}-high-error-rate'
      AlarmDescription: 'High error rate detected'
      MetricName: Errors
      Namespace: AWS/Lambda
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 5
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: FunctionName
          Value: !Ref CustomMetricsFunction
      AlarmActions:
        - !Ref CriticalAlertsTopic
      OKActions:
        - !Ref InfoAlertsTopic

  HighLatencyAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${ProjectName}-${EnvironmentName}-high-latency'
      AlarmDescription: 'High latency detected in API Gateway'
      MetricName: Latency
      Namespace: AWS/ApiGateway
      Statistic: Average
      Period: 300
      EvaluationPeriods: 3
      Threshold: 2000
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref WarningAlertsTopic

  # Anomaly Detection
  LambdaDurationAnomalyDetector:
    Type: AWS::CloudWatch::AnomalyDetector
    Properties:
      MetricName: Duration
      Namespace: AWS/Lambda
      Stat: Average
      Dimensions:
        - Name: FunctionName
          Value: !Ref CustomMetricsFunction

  LambdaDurationAnomalyAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${ProjectName}-${EnvironmentName}-lambda-duration-anomaly'
      AlarmDescription: 'Anomaly detected in Lambda duration'
      ComparisonOperator: LessThanLowerOrGreaterThanUpperThreshold
      EvaluationPeriods: 2
      Metrics:
        - Id: m1
          MetricStat:
            Metric:
              MetricName: Duration
              Namespace: AWS/Lambda
              Dimensions:
                - Name: FunctionName
                  Value: !Ref CustomMetricsFunction
            Period: 300
            Stat: Average
        - Id: ad1
          AnomalyDetector:
            MetricMathAnomalyDetector:
              MetricDataQueries:
                - Id: m1
                  MetricStat:
                    Metric:
                      MetricName: Duration
                      Namespace: AWS/Lambda
                      Dimensions:
                        - Name: FunctionName
                          Value: !Ref CustomMetricsFunction
                    Period: 300
                    Stat: Average
      ThresholdMetricId: ad1
      AlarmActions:
        - !Ref WarningAlertsTopic

  # Composite Alarm for Service Health
  ServiceHealthCompositeAlarm:
    Type: AWS::CloudWatch::CompositeAlarm
    Properties:
      AlarmName: !Sub '${ProjectName}-${EnvironmentName}-service-health'
      AlarmDescription: 'Overall service health composite alarm'
      AlarmRule: !Sub |
        ALARM("${HighErrorRateAlarm}") OR
        ALARM("${HighLatencyAlarm}")
      AlarmActions:
        - !Ref CriticalAlertsTopic
      OKActions:
        - !Ref InfoAlertsTopic

  # IAM Roles
  SlackNotificationRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

  CustomMetricsRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: CloudWatchMetricsAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - cloudwatch:PutMetricData
                Resource: '*'

Outputs:
  DashboardURL:
    Description: 'CloudWatch Dashboard URL'
    Value: !Sub 'https://${AWS::Region}.console.aws.amazon.com/cloudwatch/home?region=${AWS::Region}#dashboards:name=${MonitoringDashboard}'
    Export:
      Name: !Sub '${AWS::StackName}-DashboardURL'
  
  CriticalAlertsTopic:
    Description: 'SNS Topic for critical alerts'
    Value: !Ref CriticalAlertsTopic
    Export:
      Name: !Sub '${AWS::StackName}-CriticalAlerts'
```

### ステップ2: 高度なログ分析とInsights実装

1. **CloudWatch Insights クエリライブラリ**
```javascript
// src/monitoring/cloudwatch-insights.js
const AWS = require('aws-sdk');

class CloudWatchInsights {
    constructor(region = 'ap-northeast-1') {
        this.cloudwatchlogs = new AWS.CloudWatchLogs({ region });
    }

    /**
     * 事前定義されたクエリライブラリ
     */
    getQueryLibrary() {
        return {
            // エラー分析クエリ
            errorAnalysis: {
                name: 'Error Analysis',
                query: `
                    fields @timestamp, @message, @requestId
                    | filter @message like /ERROR/
                    | stats count() by bin(5m)
                    | sort @timestamp desc
                `,
                description: 'エラーの時系列分析'
            },

            // レイテンシ分析
            latencyAnalysis: {
                name: 'Latency Analysis',
                query: `
                    fields @timestamp, @duration, @requestId
                    | filter @type = "REPORT"
                    | stats avg(@duration), max(@duration), min(@duration) by bin(5m)
                    | sort @timestamp desc
                `,
                description: 'Lambda関数のレイテンシ分析'
            },

            // APIアクセスパターン分析
            apiAccessPatterns: {
                name: 'API Access Patterns',
                query: `
                    fields @timestamp, @message
                    | parse @message '"ip":"*"' as sourceIP
                    | parse @message '"path":"*"' as path
                    | parse @message '"method":"*"' as method
                    | parse @message '"status":*,' as status
                    | filter method = "POST"
                    | stats count() by sourceIP, path
                    | sort count desc
                    | limit 20
                `,
                description: 'APIアクセスパターンとトップIP分析'
            },

            // ユーザー行動分析
            userBehaviorAnalysis: {
                name: 'User Behavior Analysis',
                query: `
                    fields @timestamp, @message
                    | parse @message '"userId":"*"' as userId
                    | parse @message '"action":"*"' as action
                    | filter ispresent(userId)
                    | stats count() by userId, action
                    | sort count desc
                    | limit 50
                `,
                description: 'ユーザー行動とアクション分析'
            },

            // エラー根本原因分析
            errorRootCause: {
                name: 'Error Root Cause Analysis',
                query: `
                    fields @timestamp, @message, @requestId
                    | filter @message like /ERROR/ or @message like /Exception/
                    | parse @message /(?<errorType>\\w+Exception)/
                    | parse @message /(?<errorMessage>"message":"[^"]*")/
                    | stats count() by errorType, errorMessage
                    | sort count desc
                `,
                description: 'エラータイプ別根本原因分析'
            },

            // パフォーマンス・ボトルネック分析
            performanceBottleneck: {
                name: 'Performance Bottleneck Analysis',
                query: `
                    fields @timestamp, @duration, @message, @requestId
                    | filter @type = "REPORT"
                    | filter @duration > 1000
                    | sort @duration desc
                    | limit 100
                `,
                description: 'パフォーマンス・ボトルネック分析（1秒以上）'
            },

            // セキュリティ異常検知
            securityAnomalies: {
                name: 'Security Anomalies',
                query: `
                    fields @timestamp, @message
                    | parse @message '"ip":"*"' as sourceIP
                    | parse @message '"status":*,' as status
                    | filter status >= 400
                    | stats count() by sourceIP, status
                    | sort count desc
                    | limit 20
                `,
                description: 'セキュリティ異常・不正アクセス検知'
            },

            // ビジネスメトリクス分析
            businessMetrics: {
                name: 'Business Metrics Analysis',
                query: `
                    fields @timestamp, @message
                    | parse @message '"eventType":"*"' as eventType
                    | parse @message '"amount":*,' as amount
                    | filter eventType = "order_completed"
                    | stats sum(amount), count() by bin(1h)
                    | sort @timestamp desc
                `,
                description: '時間別売上・注文数分析'
            },

            // リアルタイム監視
            realTimeMonitoring: {
                name: 'Real-time Monitoring',
                query: `
                    fields @timestamp, @message
                    | filter @timestamp > now() - 15m
                    | parse @message '"level":"*"' as logLevel
                    | stats count() by logLevel, bin(1m)
                    | sort @timestamp desc
                `,
                description: '直近15分のリアルタイム監視'
            }
        };
    }

    /**
     * Insights クエリ実行
     */
    async executeQuery(logGroupName, queryString, startTime, endTime, limit = 10000) {
        const params = {
            logGroupName: logGroupName,
            queryString: queryString,
            startTime: startTime,
            endTime: endTime,
            limit: limit
        };

        try {
            // クエリ開始
            const startQueryResult = await this.cloudwatchlogs.startQuery(params).promise();
            const queryId = startQueryResult.queryId;

            // クエリ結果待ち
            let queryResult;
            let status = 'Running';
            
            while (status === 'Running') {
                await this.sleep(2000); // 2秒待機
                queryResult = await this.cloudwatchlogs.getQueryResults({
                    queryId: queryId
                }).promise();
                status = queryResult.status;
            }

            if (status === 'Complete') {
                return {
                    success: true,
                    results: queryResult.results,
                    statistics: queryResult.statistics
                };
            } else {
                throw new Error(`Query failed with status: ${status}`);
            }

        } catch (error) {
            console.error('CloudWatch Insights query error:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    /**
     * 事前定義クエリ実行
     */
    async executePreDefinedQuery(queryName, logGroupName, hours = 24) {
        const queries = this.getQueryLibrary();
        const query = queries[queryName];
        
        if (!query) {
            throw new Error(`Query ${queryName} not found`);
        }

        const endTime = new Date();
        const startTime = new Date(endTime.getTime() - (hours * 60 * 60 * 1000));

        return await this.executeQuery(
            logGroupName,
            query.query,
            startTime.getTime(),
            endTime.getTime()
        );
    }

    /**
     * 複数ロググループ横断クエリ
     */
    async executeMultiLogGroupQuery(logGroupNames, queryString, hours = 24) {
        const endTime = new Date();
        const startTime = new Date(endTime.getTime() - (hours * 60 * 60 * 1000));

        const params = {
            logGroupNames: logGroupNames,
            queryString: queryString,
            startTime: startTime.getTime(),
            endTime: endTime.getTime()
        };

        try {
            const startQueryResult = await this.cloudwatchlogs.startQuery(params).promise();
            const queryId = startQueryResult.queryId;

            let queryResult;
            let status = 'Running';
            
            while (status === 'Running') {
                await this.sleep(2000);
                queryResult = await this.cloudwatchlogs.getQueryResults({
                    queryId: queryId
                }).promise();
                status = queryResult.status;
            }

            return {
                success: status === 'Complete',
                results: queryResult.results,
                statistics: queryResult.statistics
            };

        } catch (error) {
            console.error('Multi log group query error:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    /**
     * アラート生成用のクエリ
     */
    async generateAlertQuery(logGroupName, hours = 1) {
        const alertQueries = {
            highErrorRate: `
                fields @timestamp, @message
                | filter @message like /ERROR/
                | stats count() as errorCount by bin(5m)
                | sort @timestamp desc
                | limit 12
            `,
            
            slowResponses: `
                fields @timestamp, @duration
                | filter @type = "REPORT" and @duration > 5000
                | stats count() as slowRequests by bin(5m)
                | sort @timestamp desc
                | limit 12
            `,
            
            unusualTraffic: `
                fields @timestamp, @message
                | parse @message '"ip":"*"' as sourceIP
                | stats count() as requests by sourceIP, bin(5m)
                | sort requests desc
                | limit 20
            `
        };

        const results = {};
        
        for (const [alertType, query] of Object.entries(alertQueries)) {
            try {
                const result = await this.executeQuery(
                    logGroupName,
                    query,
                    Date.now() - (hours * 60 * 60 * 1000),
                    Date.now()
                );
                results[alertType] = result;
            } catch (error) {
                console.error(`Error executing ${alertType} query:`, error);
                results[alertType] = { success: false, error: error.message };
            }
        }

        return results;
    }

    /**
     * レポート生成
     */
    async generateDailyReport(logGroupName) {
        const queries = this.getQueryLibrary();
        const report = {
            generatedAt: new Date().toISOString(),
            logGroup: logGroupName,
            sections: {}
        };

        // 各種分析の実行
        for (const [queryName, queryConfig] of Object.entries(queries)) {
            try {
                console.log(`Executing ${queryName}...`);
                const result = await this.executePreDefinedQuery(queryName, logGroupName, 24);
                
                report.sections[queryName] = {
                    title: queryConfig.name,
                    description: queryConfig.description,
                    success: result.success,
                    resultCount: result.success ? result.results.length : 0,
                    data: result.success ? result.results.slice(0, 50) : null, // 上位50件
                    error: result.success ? null : result.error
                };
                
                // レート制限対策
                await this.sleep(1000);
                
            } catch (error) {
                console.error(`Error in ${queryName}:`, error);
                report.sections[queryName] = {
                    title: queryConfig.name,
                    description: queryConfig.description,
                    success: false,
                    error: error.message
                };
            }
        }

        return report;
    }

    /**
     * ヘルパーメソッド: スリープ
     */
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    /**
     * 結果をCSV形式でエクスポート
     */
    exportToCSV(results, filename) {
        if (!results || results.length === 0) {
            return null;
        }

        // ヘッダー作成
        const headers = results[0].map(field => field.field);
        let csv = headers.join(',') + '\n';

        // データ行追加
        results.forEach(row => {
            const values = row.map(field => {
                // CSV用にエスケープ
                let value = field.value || '';
                if (value.includes(',') || value.includes('"') || value.includes('\n')) {
                    value = '"' + value.replace(/"/g, '""') + '"';
                }
                return value;
            });
            csv += values.join(',') + '\n';
        });

        return csv;
    }
}

module.exports = CloudWatchInsights;
```

### ステップ3: SLA/SLO監視とビジネスメトリクス

1. **SLA/SLO 監視システム**
```javascript
// src/monitoring/sla-slo-monitor.js
const AWS = require('aws-sdk');

class SLAMonitor {
    constructor(region = 'ap-northeast-1') {
        this.cloudwatch = new AWS.CloudWatch({ region });
        this.sns = new AWS.SNS({ region });
    }

    /**
     * SLA/SLO 定義
     */
    getSLADefinitions() {
        return {
            // サービス可用性 SLA
            availability: {
                name: 'Service Availability',
                target: 99.9, // 99.9%
                measurement: 'percentage',
                period: 'monthly',
                description: 'サービス全体の可用性',
                thresholds: {
                    critical: 99.0,
                    warning: 99.5
                }
            },

            // API レスポンス時間 SLO
            apiResponseTime: {
                name: 'API Response Time',
                target: 500, // 500ms
                measurement: 'milliseconds',
                period: 'daily',
                percentile: 95,
                description: 'API応答時間の95パーセンタイル',
                thresholds: {
                    critical: 2000,
                    warning: 1000
                }
            },

            // エラー率 SLO
            errorRate: {
                name: 'Error Rate',
                target: 0.1, // 0.1%
                measurement: 'percentage',
                period: 'daily',
                description: 'エラー率',
                thresholds: {
                    critical: 1.0,
                    warning: 0.5
                }
            },

            // スループット SLO
            throughput: {
                name: 'API Throughput',
                target: 1000, // 1000 requests/min
                measurement: 'requests_per_minute',
                period: 'hourly',
                description: 'API処理能力',
                thresholds: {
                    critical: 500,
                    warning: 750
                }
            }
        };
    }

    /**
     * SLA メトリクス計算
     */
    async calculateSLAMetrics(startTime, endTime) {
        const metrics = {};
        const slaDefinitions = this.getSLADefinitions();

        for (const [slaName, config] of Object.entries(slaDefinitions)) {
            try {
                let metricValue;
                
                switch (slaName) {
                    case 'availability':
                        metricValue = await this.calculateAvailability(startTime, endTime);
                        break;
                    case 'apiResponseTime':
                        metricValue = await this.calculateResponseTime(startTime, endTime, config.percentile);
                        break;
                    case 'errorRate':
                        metricValue = await this.calculateErrorRate(startTime, endTime);
                        break;
                    case 'throughput':
                        metricValue = await this.calculateThroughput(startTime, endTime);
                        break;
                }

                metrics[slaName] = {
                    ...config,
                    currentValue: metricValue,
                    target: config.target,
                    status: this.evaluateSLAStatus(metricValue, config),
                    compliance: this.calculateCompliance(metricValue, config),
                    timestamp: new Date().toISOString()
                };

            } catch (error) {
                console.error(`Error calculating ${slaName}:`, error);
                metrics[slaName] = {
                    ...config,
                    error: error.message,
                    status: 'ERROR'
                };
            }
        }

        return metrics;
    }

    /**
     * 可用性計算
     */
    async calculateAvailability(startTime, endTime) {
        const params = {
            MetricName: '5XXError',
            Namespace: 'AWS/ApiGateway',
            StartTime: startTime,
            EndTime: endTime,
            Period: 300,
            Statistics: ['Sum']
        };

        const errorData = await this.cloudwatch.getMetricStatistics(params).promise();
        
        // 総リクエスト数取得
        params.MetricName = 'Count';
        const totalData = await this.cloudwatch.getMetricStatistics(params).promise();

        const totalErrors = errorData.Datapoints.reduce((sum, point) => sum + point.Sum, 0);
        const totalRequests = totalData.Datapoints.reduce((sum, point) => sum + point.Sum, 0);

        if (totalRequests === 0) return 100;

        const availability = ((totalRequests - totalErrors) / totalRequests) * 100;
        return Math.round(availability * 100) / 100;
    }

    /**
     * レスポンス時間計算（パーセンタイル）
     */
    async calculateResponseTime(startTime, endTime, percentile = 95) {
        const params = {
            MetricDataQueries: [
                {
                    Id: 'latency_percentile',
                    MetricStat: {
                        Metric: {
                            Namespace: 'AWS/ApiGateway',
                            MetricName: 'Latency'
                        },
                        Period: 300,
                        Stat: `p${percentile}`
                    }
                }
            ],
            StartTime: startTime,
            EndTime: endTime
        };

        const result = await this.cloudwatch.getMetricData(params).promise();
        
        if (result.MetricDataResults[0].Values.length === 0) return null;
        
        const values = result.MetricDataResults[0].Values;
        return Math.round(values.reduce((sum, val) => sum + val, 0) / values.length);
    }

    /**
     * エラー率計算
     */
    async calculateErrorRate(startTime, endTime) {
        const errorParams = {
            MetricName: '4XXError',
            Namespace: 'AWS/ApiGateway',
            StartTime: startTime,
            EndTime: endTime,
            Period: 300,
            Statistics: ['Sum']
        };

        const error4xx = await this.cloudwatch.getMetricStatistics(errorParams).promise();
        
        errorParams.MetricName = '5XXError';
        const error5xx = await this.cloudwatch.getMetricStatistics(errorParams).promise();
        
        errorParams.MetricName = 'Count';
        const total = await this.cloudwatch.getMetricStatistics(errorParams).promise();

        const totalErrors = 
            error4xx.Datapoints.reduce((sum, point) => sum + point.Sum, 0) +
            error5xx.Datapoints.reduce((sum, point) => sum + point.Sum, 0);
        
        const totalRequests = total.Datapoints.reduce((sum, point) => sum + point.Sum, 0);

        if (totalRequests === 0) return 0;

        const errorRate = (totalErrors / totalRequests) * 100;
        return Math.round(errorRate * 1000) / 1000;
    }

    /**
     * スループット計算
     */
    async calculateThroughput(startTime, endTime) {
        const params = {
            MetricName: 'Count',
            Namespace: 'AWS/ApiGateway',
            StartTime: startTime,
            EndTime: endTime,
            Period: 60, // 1分間隔
            Statistics: ['Sum']
        };

        const result = await this.cloudwatch.getMetricStatistics(params).promise();
        
        if (result.Datapoints.length === 0) return 0;
        
        const totalRequests = result.Datapoints.reduce((sum, point) => sum + point.Sum, 0);
        const totalMinutes = result.Datapoints.length;
        
        return Math.round(totalRequests / totalMinutes);
    }

    /**
     * SLA ステータス評価
     */
    evaluateSLAStatus(currentValue, config) {
        if (currentValue === null || currentValue === undefined) {
            return 'NO_DATA';
        }

        const { target, thresholds } = config;
        const isHigherBetter = config.name.includes('Availability') || config.name.includes('Throughput');

        if (isHigherBetter) {
            if (currentValue >= target) return 'OK';
            if (currentValue >= thresholds.warning) return 'WARNING';
            if (currentValue >= thresholds.critical) return 'CRITICAL';
            return 'BREACH';
        } else {
            if (currentValue <= target) return 'OK';
            if (currentValue <= thresholds.warning) return 'WARNING';
            if (currentValue <= thresholds.critical) return 'CRITICAL';
            return 'BREACH';
        }
    }

    /**
     * コンプライアンス計算
     */
    calculateCompliance(currentValue, config) {
        if (currentValue === null || currentValue === undefined) {
            return null;
        }

        const { target } = config;
        const isHigherBetter = config.name.includes('Availability') || config.name.includes('Throughput');

        if (isHigherBetter) {
            return Math.min(100, (currentValue / target) * 100);
        } else {
            return Math.max(0, (1 - (currentValue / target)) * 100);
        }
    }

    /**
     * SLA レポート生成
     */
    async generateSLAReport(period = 'daily') {
        const now = new Date();
        let startTime, endTime;

        switch (period) {
            case 'hourly':
                startTime = new Date(now.getTime() - 60 * 60 * 1000);
                endTime = now;
                break;
            case 'daily':
                startTime = new Date(now.getTime() - 24 * 60 * 60 * 1000);
                endTime = now;
                break;
            case 'weekly':
                startTime = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
                endTime = now;
                break;
            case 'monthly':
                startTime = new Date(now.getFullYear(), now.getMonth(), 1);
                endTime = now;
                break;
            default:
                throw new Error(`Unsupported period: ${period}`);
        }

        const metrics = await this.calculateSLAMetrics(startTime, endTime);
        
        const report = {
            period: period,
            startTime: startTime.toISOString(),
            endTime: endTime.toISOString(),
            generatedAt: new Date().toISOString(),
            metrics: metrics,
            summary: this.generateSummary(metrics)
        };

        return report;
    }

    /**
     * サマリー生成
     */
    generateSummary(metrics) {
        const summary = {
            totalSLAs: Object.keys(metrics).length,
            compliantSLAs: 0,
            warningSLAs: 0,
            breachedSLAs: 0,
            overallHealth: 'UNKNOWN'
        };

        let healthScore = 0;
        let validMetrics = 0;

        for (const metric of Object.values(metrics)) {
            if (metric.status === 'ERROR' || metric.status === 'NO_DATA') continue;
            
            validMetrics++;
            
            switch (metric.status) {
                case 'OK':
                    summary.compliantSLAs++;
                    healthScore += 100;
                    break;
                case 'WARNING':
                    summary.warningSLAs++;
                    healthScore += 70;
                    break;
                case 'CRITICAL':
                case 'BREACH':
                    summary.breachedSLAs++;
                    healthScore += 30;
                    break;
            }
        }

        if (validMetrics > 0) {
            const avgHealth = healthScore / validMetrics;
            if (avgHealth >= 90) summary.overallHealth = 'EXCELLENT';
            else if (avgHealth >= 75) summary.overallHealth = 'GOOD';
            else if (avgHealth >= 60) summary.overallHealth = 'WARNING';
            else summary.overallHealth = 'CRITICAL';
        }

        return summary;
    }

    /**
     * SLA 違反アラート送信
     */
    async sendSLAAlert(slaName, metric, topicArn) {
        const message = {
            alertType: 'SLA_VIOLATION',
            slaName: slaName,
            currentValue: metric.currentValue,
            target: metric.target,
            status: metric.status,
            compliance: metric.compliance,
            timestamp: new Date().toISOString()
        };

        const params = {
            TopicArn: topicArn,
            Subject: `SLA Alert: ${metric.name} - ${metric.status}`,
            Message: JSON.stringify(message, null, 2),
            MessageAttributes: {
                alertType: {
                    DataType: 'String',
                    StringValue: 'SLA_VIOLATION'
                },
                severity: {
                    DataType: 'String',
                    StringValue: metric.status
                }
            }
        };

        try {
            await this.sns.publish(params).promise();
            console.log(`SLA alert sent for ${slaName}`);
        } catch (error) {
            console.error('Error sending SLA alert:', error);
            throw error;
        }
    }

    /**
     * カスタムメトリクス送信
     */
    async sendCustomMetric(namespace, metricName, value, unit = 'None', dimensions = []) {
        const params = {
            Namespace: namespace,
            MetricData: [
                {
                    MetricName: metricName,
                    Value: value,
                    Unit: unit,
                    Dimensions: dimensions,
                    Timestamp: new Date()
                }
            ]
        };

        try {
            await this.cloudwatch.putMetricData(params).promise();
            console.log(`Custom metric sent: ${metricName} = ${value}`);
        } catch (error) {
            console.error('Error sending custom metric:', error);
            throw error;
        }
    }
}

module.exports = SLAMonitor;
```

### ステップ4: 自動化されたインシデント対応

1. **インシデント対応自動化**
```javascript
// src/monitoring/incident-response.js
const AWS = require('aws-sdk');
const SLAMonitor = require('./sla-slo-monitor');

class IncidentResponseAutomation {
    constructor(region = 'ap-northeast-1') {
        this.lambda = new AWS.Lambda({ region });
        this.sns = new AWS.SNS({ region });
        this.cloudwatch = new AWS.CloudWatch({ region });
        this.applicationAutoScaling = new AWS.ApplicationAutoScaling({ region });
        this.slaMonitor = new SLAMonitor(region);
    }

    /**
     * インシデント対応フロー定義
     */
    getIncidentResponseFlows() {
        return {
            // 高エラー率対応
            highErrorRate: {
                name: 'High Error Rate Response',
                triggers: ['ERROR_RATE_HIGH', 'SLA_BREACH_ERROR_RATE'],
                severity: 'CRITICAL',
                automatedActions: [
                    'enableDetailedLogging',
                    'scaleUpResources',
                    'notifyOnCallTeam',
                    'createIncidentTicket'
                ],
                rollbackActions: [
                    'revertToLastKnownGood',
                    'isolateFailingComponents'
                ]
            },

            // 高レイテンシ対応
            highLatency: {
                name: 'High Latency Response',
                triggers: ['LATENCY_HIGH', 'SLA_BREACH_RESPONSE_TIME'],
                severity: 'WARNING',
                automatedActions: [
                    'scaleUpResources',
                    'enableCaching',
                    'optimizeQueries',
                    'notifyDevTeam'
                ]
            },

            // リソース枯渇対応
            resourceExhaustion: {
                name: 'Resource Exhaustion Response',
                triggers: ['CPU_HIGH', 'MEMORY_HIGH', 'DISK_FULL'],
                severity: 'CRITICAL',
                automatedActions: [
                    'scaleUpResources',
                    'clearTemporaryFiles',
                    'restartServices',
                    'notifyInfraTeam'
                ]
            },

            // セキュリティインシデント対応
            securityIncident: {
                name: 'Security Incident Response',
                triggers: ['SUSPICIOUS_ACTIVITY', 'INTRUSION_DETECTED'],
                severity: 'CRITICAL',
                automatedActions: [
                    'blockSuspiciousIPs',
                    'enableDetailedLogging',
                    'isolateAffectedResources',
                    'notifySecurityTeam',
                    'initiateForensics'
                ]
            }
        };
    }

    /**
     * インシデント検知とトリガー
     */
    async handleIncidentTrigger(eventSource, eventDetail) {
        console.log('Processing incident trigger:', { eventSource, eventDetail });

        const incidentType = this.classifyIncident(eventSource, eventDetail);
        const responseFlow = this.getIncidentResponseFlows()[incidentType];

        if (!responseFlow) {
            console.log('No response flow found for incident type:', incidentType);
            return;
        }

        const incident = {
            id: this.generateIncidentId(),
            type: incidentType,
            severity: responseFlow.severity,
            startTime: new Date().toISOString(),
            status: 'ACTIVE',
            source: eventSource,
            details: eventDetail,
            actions: []
        };

        // 自動対応アクション実行
        for (const action of responseFlow.automatedActions) {
            try {
                const actionResult = await this.executeAction(action, incident);
                incident.actions.push({
                    action: action,
                    result: actionResult,
                    timestamp: new Date().toISOString(),
                    status: 'SUCCESS'
                });
            } catch (error) {
                console.error(`Action ${action} failed:`, error);
                incident.actions.push({
                    action: action,
                    error: error.message,
                    timestamp: new Date().toISOString(),
                    status: 'FAILED'
                });
            }
        }

        // インシデント記録
        await this.recordIncident(incident);
        
        return incident;
    }

    /**
     * インシデント分類
     */
    classifyIncident(eventSource, eventDetail) {
        const alarmName = eventDetail.alarmName || '';
        const metricName = eventDetail.metricName || '';

        if (alarmName.includes('error') || metricName.includes('Error')) {
            return 'highErrorRate';
        }
        
        if (alarmName.includes('latency') || metricName.includes('Duration')) {
            return 'highLatency';
        }
        
        if (alarmName.includes('cpu') || alarmName.includes('memory')) {
            return 'resourceExhaustion';
        }
        
        if (alarmName.includes('security') || alarmName.includes('suspicious')) {
            return 'securityIncident';
        }

        return 'highErrorRate'; // デフォルト
    }

    /**
     * 自動対応アクション実行
     */
    async executeAction(actionName, incident) {
        console.log(`Executing action: ${actionName}`);

        switch (actionName) {
            case 'enableDetailedLogging':
                return await this.enableDetailedLogging();
            
            case 'scaleUpResources':
                return await this.scaleUpResources();
            
            case 'notifyOnCallTeam':
                return await this.notifyOnCallTeam(incident);
            
            case 'notifyDevTeam':
                return await this.notifyDevTeam(incident);
            
            case 'notifyInfraTeam':
                return await this.notifyInfraTeam(incident);
            
            case 'notifySecurityTeam':
                return await this.notifySecurityTeam(incident);
            
            case 'createIncidentTicket':
                return await this.createIncidentTicket(incident);
            
            case 'enableCaching':
                return await this.enableCaching();
            
            case 'blockSuspiciousIPs':
                return await this.blockSuspiciousIPs(incident);
            
            case 'revertToLastKnownGood':
                return await this.revertToLastKnownGood();
            
            default:
                throw new Error(`Unknown action: ${actionName}`);
        }
    }

    /**
     * 詳細ログ有効化
     */
    async enableDetailedLogging() {
        // Lambda関数の詳細ログ有効化
        const functions = await this.lambda.listFunctions().promise();
        
        for (const func of functions.Functions) {
            if (func.FunctionName.includes('api') || func.FunctionName.includes('user')) {
                await this.lambda.updateFunctionConfiguration({
                    FunctionName: func.FunctionName,
                    Environment: {
                        Variables: {
                            ...func.Environment?.Variables,
                            LOG_LEVEL: 'DEBUG'
                        }
                    }
                }).promise();
            }
        }

        return { message: 'Detailed logging enabled for API functions' };
    }

    /**
     * リソーススケールアップ
     */
    async scaleUpResources() {
        // Lambda同時実行数増加
        const functions = ['user-management-api', 'product-api'];
        const results = [];

        for (const functionName of functions) {
            try {
                await this.lambda.putReservedConcurrencyConfiguration({
                    FunctionName: functionName,
                    ReservedConcurrencyLimit: 100
                }).promise();

                results.push(`${functionName}: concurrency increased to 100`);
            } catch (error) {
                results.push(`${functionName}: failed to scale - ${error.message}`);
            }
        }

        return { message: 'Resource scaling completed', details: results };
    }

    /**
     * オンコールチーム通知
     */
    async notifyOnCallTeam(incident) {
        const message = {
            incident: incident,
            priority: 'CRITICAL',
            callToAction: 'Immediate response required',
            runbook: `https://wiki.example.com/runbooks/${incident.type}`
        };

        await this.sns.publish({
            TopicArn: process.env.ONCALL_TOPIC_ARN,
            Subject: `🚨 CRITICAL INCIDENT: ${incident.type}`,
            Message: JSON.stringify(message, null, 2),
            MessageAttributes: {
                priority: {
                    DataType: 'String',
                    StringValue: 'CRITICAL'
                },
                incidentType: {
                    DataType: 'String',
                    StringValue: incident.type
                }
            }
        }).promise();

        return { message: 'On-call team notified', topicArn: process.env.ONCALL_TOPIC_ARN };
    }

    /**
     * 開発チーム通知
     */
    async notifyDevTeam(incident) {
        const message = {
            incident: incident,
            priority: 'HIGH',
            suggestedActions: [
                'Review recent deployments',
                'Check application logs',
                'Verify database performance'
            ]
        };

        await this.sns.publish({
            TopicArn: process.env.DEV_TEAM_TOPIC_ARN,
            Subject: `⚠️ Performance Issue: ${incident.type}`,
            Message: JSON.stringify(message, null, 2)
        }).promise();

        return { message: 'Development team notified' };
    }

    /**
     * インフラチーム通知
     */
    async notifyInfraTeam(incident) {
        const message = {
            incident: incident,
            priority: 'HIGH',
            suggestedActions: [
                'Check system resources',
                'Review scaling policies',
                'Monitor infrastructure health'
            ]
        };

        await this.sns.publish({
            TopicArn: process.env.INFRA_TEAM_TOPIC_ARN,
            Subject: `🔧 Infrastructure Alert: ${incident.type}`,
            Message: JSON.stringify(message, null, 2)
        }).promise();

        return { message: 'Infrastructure team notified' };
    }

    /**
     * セキュリティチーム通知
     */
    async notifySecurityTeam(incident) {
        const message = {
            incident: incident,
            priority: 'CRITICAL',
            securityLevel: 'RED',
            requiredActions: [
                'Immediate investigation required',
                'Potential security breach',
                'Activate incident response protocol'
            ]
        };

        await this.sns.publish({
            TopicArn: process.env.SECURITY_TEAM_TOPIC_ARN,
            Subject: `🚨 SECURITY INCIDENT: ${incident.type}`,
            Message: JSON.stringify(message, null, 2),
            MessageAttributes: {
                securityLevel: {
                    DataType: 'String',
                    StringValue: 'RED'
                }
            }
        }).promise();

        return { message: 'Security team notified' };
    }

    /**
     * インシデントチケット作成
     */
    async createIncidentTicket(incident) {
        // 外部チケットシステム（Jira, ServiceNow等）との連携
        const ticketData = {
            title: `Incident: ${incident.type}`,
            description: `
                Incident ID: ${incident.id}
                Type: ${incident.type}
                Severity: ${incident.severity}
                Start Time: ${incident.startTime}
                
                Details: ${JSON.stringify(incident.details, null, 2)}
            `,
            priority: incident.severity,
            category: 'System Incident',
            assignee: 'oncall-team'
        };

        // 実際の実装では外部APIコール
        console.log('Creating incident ticket:', ticketData);
        
        return { 
            message: 'Incident ticket created',
            ticketId: `INC-${incident.id}`,
            ticketData: ticketData
        };
    }

    /**
     * キャッシュ有効化
     */
    async enableCaching() {
        // API Gatewayキャッシュ有効化のシミュレーション
        return { message: 'Caching enabled for critical API endpoints' };
    }

    /**
     * 不審なIP遮断
     */
    async blockSuspiciousIPs(incident) {
        // WAFルール更新のシミュレーション
        const suspiciousIPs = incident.details.suspiciousIPs || [];
        
        return { 
            message: 'Suspicious IPs blocked',
            blockedIPs: suspiciousIPs
        };
    }

    /**
     * 既知の良好な状態への復元
     */
    async revertToLastKnownGood() {
        // デプロイメント復元のシミュレーション
        return { message: 'Reverted to last known good deployment' };
    }

    /**
     * インシデント記録
     */
    async recordIncident(incident) {
        // インシデントログをCloudWatch Logsに記録
        console.log('Recording incident:', JSON.stringify(incident, null, 2));
        
        // メトリクス送信
        await this.slaMonitor.sendCustomMetric(
            'IncidentManagement',
            'IncidentCount',
            1,
            'Count',
            [
                { Name: 'IncidentType', Value: incident.type },
                { Name: 'Severity', Value: incident.severity }
            ]
        );
    }

    /**
     * インシデントID生成
     */
    generateIncidentId() {
        const timestamp = Date.now();
        const random = Math.random().toString(36).substring(2, 8);
        return `INC-${timestamp}-${random}`.toUpperCase();
    }

    /**
     * インシデント解決
     */
    async resolveIncident(incidentId, resolution) {
        const resolvedIncident = {
            id: incidentId,
            status: 'RESOLVED',
            endTime: new Date().toISOString(),
            resolution: resolution,
            resolvedBy: 'automation'
        };

        await this.recordIncident(resolvedIncident);
        
        return resolvedIncident;
    }
}

module.exports = IncidentResponseAutomation;
```

## 検証方法

### 1. メトリクス収集テスト
```bash
# カスタムメトリクス送信テスト
aws cloudwatch put-metric-data \
  --namespace "CustomApp/Business" \
  --metric-data MetricName=ActiveUsers,Value=100,Unit=Count

# メトリクス取得確認
aws cloudwatch get-metric-statistics \
  --namespace "CustomApp/Business" \
  --metric-name ActiveUsers \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

### 2. ログ分析テスト
```javascript
// CloudWatch Insights テスト
const insights = new CloudWatchInsights();

async function testLogAnalysis() {
    const logGroupName = '/aws/lambda/user-management-api';
    
    // エラー分析実行
    const errorAnalysis = await insights.executePreDefinedQuery(
        'errorAnalysis', 
        logGroupName, 
        24
    );
    console.log('Error Analysis:', errorAnalysis);
    
    // レイテンシ分析実行
    const latencyAnalysis = await insights.executePreDefinedQuery(
        'latencyAnalysis',
        logGroupName,
        24
    );
    console.log('Latency Analysis:', latencyAnalysis);
}

testLogAnalysis().catch(console.error);
```

### 3. SLA監視テスト
```javascript
// SLA監視テスト
const slaMonitor = new SLAMonitor();

async function testSLAMonitoring() {
    // 日次SLAレポート生成
    const report = await slaMonitor.generateSLAReport('daily');
    console.log('SLA Report:', JSON.stringify(report, null, 2));
    
    // 現在のSLAメトリクス確認
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    
    const metrics = await slaMonitor.calculateSLAMetrics(oneHourAgo, now);
    console.log('Current SLA Metrics:', metrics);
}

testSLAMonitoring().catch(console.error);
```

## トラブルシューティング

### よくある問題と解決策

#### 1. メトリクスデータの遅延
**症状**: CloudWatchメトリクスが反映されない
**解決策**:
- メトリクス送信の確認
- タイムスタンプの正確性確認
- 名前空間・ディメンションの検証

#### 2. アラーム誤報
**症状**: 不要なアラートが頻発
**解決策**:
```yaml
# アラーム設定の最適化
AlarmOptimized:
  Type: AWS::CloudWatch::Alarm
  Properties:
    EvaluationPeriods: 3  # 増加
    DatapointsToAlarm: 2   # 追加
    TreatMissingData: notBreaching
```

#### 3. ダッシュボードパフォーマンス
**症状**: ダッシュボード読み込みが遅い
**解決策**:
- メトリクス期間の最適化
- 不要なウィジェット削除
- キャッシュ活用

## 学習リソース

### AWS公式ドキュメント
- [Amazon CloudWatch ユーザーガイド](https://docs.aws.amazon.com/cloudwatch/latest/monitoring/)
- [CloudWatch Logs Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html)
- [CloudWatch アラーム](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)

### 追加学習教材
- [AWS Well-Architected Operational Excellence](https://wa.aws.amazon.com/wat.pillar.operationalExcellence.en.html)
- [SRE Workbook](https://sre.google/workbook/table-of-contents/)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **IAM最小権限**: CloudWatch操作の最小権限付与
2. **ログ暗号化**: CloudWatch Logsの暗号化有効化
3. **アクセス制御**: ダッシュボード・アラームのアクセス制御
4. **監査ログ**: CloudTrailによる監視操作記録

### コスト最適化
1. **ログ保持期間**: 適切な保持期間設定
2. **メトリクス頻度**: 必要最小限のメトリクス収集
3. **ダッシュボード最適化**: 効率的なウィジェット配置
4. **アラーム整理**: 不要なアラームの削除

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: 包括的監視・自動化・運用手順
- **セキュリティの柱**: ログ分析・異常検知・インシデント対応
- **信頼性の柱**: SLA監視・障害検知・自動復旧
- **パフォーマンス効率の柱**: メトリクス分析・最適化提案
- **コスト最適化の柱**: リソース使用量監視・最適化推奨

## 次のステップ

### 推奨される学習パス
1. **5.1.1 Bedrockセットアップ**: AI/ML監視統合
2. **6.1.1 マルチステージビルド**: CI/CD監視統合
3. **6.2.1 APM実装**: アプリケーション性能監視
4. **7.1.1 Claude Code基礎**: AI駆動開発監視

### 発展的な機能
1. **X-Ray統合**: 分散トレーシング
2. **Container Insights**: コンテナ監視
3. **Synthetics**: 合成監視
4. **RUM**: リアルユーザー監視

### 実践プロジェクトのアイデア
1. **統合監視プラットフォーム**: 全社監視システム
2. **予測分析システム**: 機械学習による異常予測
3. **自動化運用センター**: NoOps実現
4. **SREダッシュボード**: サイト信頼性エンジニアリング