# 5.1.1 Bedrockセットアップ

## 学習目標

このセクションでは、Amazon Bedrockの基本的なセットアップと利用方法を習得し、生成AI機能をAWSアプリケーションに統合するための基盤を構築します。

### 習得できるスキル
- Amazon Bedrockサービスの理解と設定
- 基盤モデル（Foundation Models）のアクセス権限設定
- Bedrock APIの基本的な使用方法
- IAMロールとポリシーによるBedrockアクセス制御
- 基本的なテキスト生成機能の実装
- Bedrock利用時のコスト管理とモニタリング

## 前提知識

### 必須の知識
- AWSコンソールの基本操作
- IAMユーザー、ロール、ポリシーの理解（1.1.1セクション完了）
- REST APIの基本概念
- JSONデータ形式の理解

### あると望ましい知識
- Python或いはJavaScript/TypeScriptの基礎
- AWS SDKの使用経験
- 機械学習・AIの基本概念
- プロンプトエンジニアリングの基礎

## アーキテクチャ概要

### Amazon Bedrockアーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                    Amazon Bedrock Service                    │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Anthropic     │  │      AWS       │  │   Stability  │ │
│  │   Claude 3      │  │    Titan       │  │     AI      │ │
│  │   Models        │  │   Models       │  │   Models    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │     Meta        │  │    Cohere      │  │     AI21    │ │
│  │    Llama 2      │  │   Command      │  │   Jurassic  │ │
│  │   Models        │  │   Models       │  │   Models    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ API Calls
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Your Application                         │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Lambda        │  │      EC2       │  │   Frontend  │ │
│  │  Functions      │  │  Applications  │  │ Applications │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │               AWS SDK / Boto3                           │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **Amazon Bedrock**: サーバーレスで基盤モデルを提供するサービス
- **Foundation Models**: Claude 3、GPT、Titan等の大規模言語モデル
- **Model Access**: モデルごとのアクセス制御と利用許可設定
- **API Gateway**: 統一されたAPIインターフェース
- **IAM Integration**: きめ細かいアクセス制御

## ハンズオン手順

### ステップ1: Bedrockサービスの有効化

1. **利用可能リージョンの確認**
```bash
# Bedrockが利用可能なリージョン一覧
aws bedrock list-foundation-models --region us-east-1
```

2. **AWSコンソールでのセットアップ**
- AWS Management Consoleにログイン
- Amazon Bedrockサービスに移動
- 「Getting started」をクリック
- 利用規約への同意

### ステップ2: 基盤モデルへのアクセス設定

1. **モデルアクセスの設定画面へ移動**
   - Bedrockコンソール → 「Model access」
   - 「Manage model access」をクリック

2. **利用したいモデルの選択**
```text
推奨モデル（学習用）:
✓ Anthropic Claude 3 Haiku (軽量、高速)
✓ Anthropic Claude 3 Sonnet (バランス型)
✓ Amazon Titan Text G1 - Express (AWS純正)
✓ Amazon Titan Text G1 - Lite (コスト効率)
```

3. **アクセス申請の送信**
```bash
# CLI経由でのモデルアクセス確認
aws bedrock list-foundation-models \
  --region us-east-1 \
  --query 'modelSummaries[?modelLifecycle.status==`ACTIVE`].[modelId,modelName]' \
  --output table
```

### ステップ3: IAMロールとポリシーの設定

1. **CloudFormationテンプレートの作成**
```yaml
# bedrock-iam.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'IAM roles and policies for Amazon Bedrock'

Parameters:
  ProjectName:
    Type: String
    Default: 'AI-Learning'

Resources:
  BedrockExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${ProjectName}-Bedrock-Execution-Role'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service:
                - lambda.amazonaws.com
                - ec2.amazonaws.com
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: BedrockAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'bedrock:InvokeModel'
                  - 'bedrock:InvokeModelWithResponseStream'
                Resource:
                  - 'arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku-20240307-v1:0'
                  - 'arn:aws:bedrock:*::foundation-model/amazon.titan-text-express-v1'

  BedrockPowerUserPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub '${ProjectName}-Bedrock-PowerUser'
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - 'bedrock:ListFoundationModels'
              - 'bedrock:GetFoundationModel'
              - 'bedrock:InvokeModel'
              - 'bedrock:InvokeModelWithResponseStream'
            Resource: '*'
          - Effect: Allow
            Action:
              - 'bedrock:GetModelInvocationLoggingConfiguration'
              - 'bedrock:PutModelInvocationLoggingConfiguration'
            Resource: '*'
      Users:
        - !Ref DeveloperUser

  DeveloperUser:
    Type: AWS::IAM::User
    Properties:
      UserName: !Sub '${ProjectName}-Bedrock-Developer'
      Path: '/'
      Policies:
        - PolicyName: BedrockDeveloperAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'bedrock:InvokeModel'
                  - 'bedrock:ListFoundationModels'
                Resource: '*'
```

2. **スタックのデプロイ**
```bash
cd /mnt/c/dev2/practice/05-AI-ML統合編/5.1-Bedrock基礎/5.1.1-Bedrockセットアップ/cloudformation

aws cloudformation create-stack \
  --stack-name ai-learning-bedrock-iam \
  --template-body file://bedrock-iam.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=ProjectName,ParameterValue=AI-Learning
```

### ステップ4: 基本的なAPI呼び出しテスト

1. **Python SDKのセットアップ**
```bash
pip install boto3 botocore
```

2. **基本的なテキスト生成テスト**
```python
# test_bedrock.py
import boto3
import json
from botocore.exceptions import ClientError

def test_bedrock_claude():
    """Claude 3 Haikuモデルのテスト"""
    bedrock = boto3.client(
        service_name='bedrock-runtime',
        region_name='us-east-1'
    )
    
    model_id = 'anthropic.claude-3-haiku-20240307-v1:0'
    
    # プロンプトの準備
    prompt = """Human: AWSとAIについて50文字程度で説明してください。Assistant:

    try:
        body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1000,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": 0.7,
            "top_p": 0.9
        }
        
        response = bedrock.invoke_model(
            modelId=model_id,
            body=json.dumps(body)
        )
        
        response_body = json.loads(response["body"].read())
        text_response = response_body["content"][0]["text"]
        
        print(f"Prompt: {prompt}")
        print(f"Response: {text_response}")
        
        return text_response
        
    except ClientError as e:
        print(f"Error calling Bedrock: {e}")
        return None

def test_bedrock_titan():
    """Amazon Titan モデルのテスト"""
    bedrock = boto3.client(
        service_name="bedrock-runtime",
        region_name="us-east-1"
    )
    
    model_id = "amazon.titan-text-express-v1"
    
    prompt = "AWSのサーバーレスアーキテクチャについて簡潔に説明してください。"
    
    try:
        body = {
            "inputText": prompt,
            "textGenerationConfig": {
                "maxTokenCount": 500,
                "temperature": 0.7,
                "topP": 0.9,
                "stopSequences": []
            }
        }
        
        response = bedrock.invoke_model(
            modelId=model_id,
            body=json.dumps(body)
        )
        
        response_body = json.loads(response["body"].read())
        text_response = response_body["results"][0]["outputText"]
        
        print(f"Prompt: {prompt}")
        print(f"Response: {text_response}")
        
        return text_response
        
    except ClientError as e:
        print(f"Error calling Bedrock: {e}")
        return None

if __name__ == "__main__":
    print("=== Claude 3 Haiku Test ===")
    test_bedrock_claude()
    
    print("\n=== Amazon Titan Test ===")
    test_bedrock_titan()
```

3. **テスト実行**
```bash
python test_bedrock.py
```

### ステップ5: モニタリングとロギングの設定

1. **CloudWatch メトリクスの設定**
```yaml
# monitoring.yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: "Bedrock monitoring and logging setup"

Resources:
  BedrockLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: /aws/bedrock/model-invocations
      RetentionInDays: 30

  BedrockModelInvocationAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: Bedrock-High-Error-Rate
      AlarmDescription: "High error rate in Bedrock model invocations"
      MetricName: ModelInvocationErrors
      Namespace: AWS/Bedrock
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 10
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - \!Ref BedrockAlarmTopic

  BedrockAlarmTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: bedrock-alarms
      DisplayName: "Bedrock Monitoring Alerts"
```

## 検証方法

### 1. 基本機能テスト
```bash
# 利用可能モデルの確認
aws bedrock list-foundation-models --region us-east-1

# モデルアクセス状況の確認
aws bedrock get-model-invocation-logging-configuration --region us-east-1
```

### 2. Python SDKでのテスト
```python
# requirements.txt
boto3>=1.34.0
botocore>=1.34.0

# pip install -r requirements.txt
```

### 3. API呼び出しの検証
```python
# api_test.py
import time
import boto3
from botocore.exceptions import ClientError

def test_model_availability():
    """モデルの利用可能性をテスト"""
    bedrock = boto3.client("bedrock", region_name="us-east-1")
    
    try:
        models = bedrock.list_foundation_models()
        print("Available models:")
        for model in models["modelSummaries"]:
            if model["modelLifecycle"]["status"] == "ACTIVE":
                print(f"- {model[modelId]}: {model[modelName]}")
    except ClientError as e:
        print(f"Error: {e}")

def test_rate_limits():
    """レート制限のテスト"""
    bedrock = boto3.client("bedrock-runtime", region_name="us-east-1")
    
    for i in range(5):
        try:
            start_time = time.time()
            
            response = bedrock.invoke_model(
                modelId="anthropic.claude-3-haiku-20240307-v1:0",
                body=json.dumps({
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 100,
                    "messages": [{"role": "user", "content": f"Test {i}"}]
                })
            )
            
            end_time = time.time()
            print(f"Request {i}: {end_time - start_time:.2f}s")
            
        except ClientError as e:
            print(f"Request {i} failed: {e}")
        
        time.sleep(1)  # 1秒待機

if __name__ == "__main__":
    test_model_availability()
    test_rate_limits()
```

## トラブルシューティング

### よくある問題と解決策

#### 1. モデルアクセス拒否エラー
**症状**: `ValidationException: The provided model identifier is invalid`
**原因**: モデルへのアクセス権限が付与されていない
**解決策**:
```bash
# モデルアクセス状況を確認
aws bedrock list-foundation-models --region us-east-1 --query "modelSummaries[?contains(modelId, claude)]"

# Bedrockコンソールでモデルアクセスを申請
# https://console.aws.amazon.com/bedrock/
```

#### 2. リージョンエラー
**症状**: `EndpointConnectionError: Could not connect to the endpoint URL`
**原因**: Bedrockが利用できないリージョンでアクセス
**解決策**:
```python
# 利用可能リージョンの確認
BEDROCK_REGIONS = [
    "us-east-1",      # バージニア北部
    "us-west-2",      # オレゴン
    "ap-southeast-1", # シンガポール
    "ap-northeast-1", # 東京
    "eu-west-1"       # アイルランド
]

# 東京リージョンでの設定例
bedrock = boto3.client("bedrock-runtime", region_name="ap-northeast-1")
```

#### 3. IAM権限エラー
**症状**: `AccessDeniedException: User is not authorized to perform`
**解決策**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:ListFoundationModels",
        "bedrock:GetFoundationModel"
      ],
      "Resource": "*"
    }
  ]
}
```

#### 4. レート制限エラー
**症状**: `ThrottlingException: Rate exceeded`
**解決策**:
```python
import time
from botocore.exceptions import ClientError

def invoke_with_retry(bedrock_client, **kwargs):
    """指数バックオフでリトライ"""
    max_retries = 3
    base_delay = 1
    
    for attempt in range(max_retries):
        try:
            return bedrock_client.invoke_model(**kwargs)
        except ClientError as e:
            if e.response["Error"]["Code"] == "ThrottlingException":
                if attempt < max_retries - 1:
                    delay = base_delay * (2 ** attempt)
                    print(f"Rate limited. Retrying in {delay}s...")
                    time.sleep(delay)
                    continue
            raise
```

### デバッグ手法
```python
# ログ設定の有効化
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# boto3のデバッグログを有効化
boto3.set_stream_logger("boto3", logging.DEBUG)
boto3.set_stream_logger("botocore", logging.DEBUG)
```

## 学習リソース

### AWS公式ドキュメント
- [Amazon Bedrock User Guide](https://docs.aws.amazon.com/bedrock/latest/userguide/)
- [Amazon Bedrock API Reference](https://docs.aws.amazon.com/bedrock/latest/APIReference/)
- [Bedrock Runtime API Reference](https://docs.aws.amazon.com/bedrock-runtime/latest/APIReference/)
- [Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)

### モデル固有ドキュメント
- [Anthropic Claude Models](https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-claude.html)
- [Amazon Titan Models](https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-titan.html)
- [Meta Llama 2 Models](https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-meta.html)

### 追加学習教材
- [Generative AI with Amazon Bedrock](https://aws.amazon.com/bedrock/generative-ai/)
- [Prompt Engineering Guide](https://www.promptingguide.ai/)
- [Responsible AI Best Practices](https://aws.amazon.com/machine-learning/responsible-ai/)

### ハンズオンワークショップ
- [Amazon Bedrock Workshop](https://github.com/aws-samples/amazon-bedrock-workshop)
- [Generative AI Use Cases](https://github.com/aws-samples/generative-ai-use-cases-jp)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **アクセス制御**
   - IAMロールベースのアクセス制御
   - 最小権限の原則
   - リソースレベルの権限設定

2. **データ保護**
   - 入力データの適切な処理
   - 機密情報の除去
   - 出力データの検証

3. **監査と遵守**
   - CloudTrailによるAPI呼び出しログ
   - データプライバシーの遵守
   - コンプライアンス要件の確認

4. **責任あるAI**
   - バイアスの検出と軽減
   - 有害コンテンツのフィルタリング
   - 透明性の確保

### コスト最適化
1. **モデル選択の最適化**
   - 用途に応じた適切なモデル選択
   - Haikuモデルによるコスト削減
   - オンデマンド価格の理解

2. **使用量の管理**
   - 入力トークン数の最適化
   - 出力トークン数の制限
   - 不要な呼び出しの削減

3. **モニタリングとアラート**
   - コスト異常検知の設定
   - 使用量ダッシュボードの活用
   - 予算アラートの設定

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatchによる監視とログ管理
- **セキュリティの柱**: IAMとデータ保護の実装
- **信頼性の柱**: エラーハンドリングとリトライ機構
- **パフォーマンス効率の柱**: 適切なモデル選択と最適化
- **コスト最適化の柱**: 使用量ベースの課金とモニタリング

## 次のステップ

### 推奨される学習パス
1. **5.1.2 テキスト生成実装**: より高度なテキスト生成機能
2. **5.2.1 チャットボット作成**: インタラクティブなAIアプリケーション
3. **5.2.2 RAGシステム構築**: 知識ベースを活用したAI
4. **5.2.3 画像生成機能**: マルチモーダルAI機能

### 発展的な機能
1. **ファインチューニング**: カスタムモデルの作成
2. **エージェント機能**: Function Callingの活用
3. **マルチモーダル**: テキスト・画像・音声の統合
4. **ストリーミング**: リアルタイム応答の実装

### 実践プロジェクトのアイデア
1. **文書要約システム**: 長文の自動要約
2. **質問応答システム**: FAQ自動応答
3. **コード生成アシスタント**: プログラミング支援
4. **創作支援ツール**: 小説・詩・ブログ執筆支援
