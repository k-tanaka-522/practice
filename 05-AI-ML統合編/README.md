# AI-ML統合編

## 概要

このセクションでは、AWS Bedrockを中心としたAI/MLサービスを統合し、テキスト生成、チャットボット、RAGシステム、画像生成などの実用的なAI機能を実装します。Claude、GPT、Stable Diffusion等の最新モデルを活用した本格的なAIアプリケーション開発を学習します。

## 学習目標

- 🤖 **Amazon Bedrock**: 基盤モデルによるテキスト・画像生成
- 💬 **チャットボット**: Claude/GPTを使った対話AI
- 🔍 **RAGシステム**: 検索拡張生成による知識ベース活用
- 🎨 **画像生成**: Stable Diffusion等による画像AI
- 🚀 **MLOps**: モデル管理、デプロイ、監視

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────────┐
│                        AI Services Layer                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │   Bedrock   │  │ SageMaker   │  │  Textract   │  │ Polly   │ │
│  │ Foundation  │  │   Models    │  │   OCR/NLP   │  │  TTS    │ │
│  │   Models    │  │             │  │             │  │         │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Application Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │   Lambda    │  │ API Gateway │  │ EventBridge │  │   SQS   │ │
│  │ AI Functions│  │ AI Endpoints│  │   Events    │  │ Queues  │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Storage Layer                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │     S3      │  │  DynamoDB   │  │ OpenSearch  │  │  RDS    │ │
│  │ Documents   │  │ Chat History│  │ Vector DB   │  │Knowledge│ │
│  │  & Media    │  │             │  │             │  │  Base   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Frontend Layer                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │   React     │  │   Amplify   │  │  CloudFront │  │  Route  │ │
│  │   Chat UI   │  │   Hosting   │  │     CDN     │  │   53    │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 学習パス

### 5.1 Bedrock基礎
- **5.1.1** Bedrockセットアップとモデル選択
- **5.1.2** テキスト生成実装

### 5.2 AI機能実装
- **5.2.1** チャットボット作成
- **5.2.2** RAGシステム構築
- **5.2.3** 画像生成機能

### 5.3 高度なMLOps（拡張）
- **5.3.1** モデル評価と最適化
- **5.3.2** A/Bテストとモニタリング

## クイックスタート

### 前提条件

```bash
# AWS CLI確認
aws --version

# Python環境確認（AI/ML用）
python3 --version
pip3 install boto3 langchain

# Node.js確認（フロントエンド用）
node --version
npm install @aws-sdk/client-bedrock-runtime
```

### Bedrockモデルアクセス申請

```bash
# 使用可能モデルの確認
aws bedrock list-foundation-models --region us-east-1

# モデルアクセス申請（AWS Console経由）
echo "https://console.aws.amazon.com/bedrock/ でモデルアクセスを申請してください"
echo "主要モデル: Claude, Titan, Jurassic, Command, Llama"
```

### 全体デプロイ

```bash
# AI-ML統合基盤の一括デプロイ
./scripts/deploy-all-infrastructure.sh deploy-ai-ml

# 段階的デプロイ
./scripts/deploy-ai-ml.sh deploy-bedrock
./scripts/deploy-ai-ml.sh deploy-chatbot
./scripts/deploy-ai-ml.sh deploy-rag
./scripts/deploy-ai-ml.sh deploy-image-gen
```

## 学習コンテンツ詳細

### 🤖 5.1.1 Bedrockセットアップ

**学習内容:**
- Amazon Bedrockサービス概要
- 基盤モデルの種類と特徴
- プロビジョニングとセキュリティ設定
- コスト最適化戦略

**実装内容:**
- Bedrock IAMロール設定
- モデルアクセス権限管理
- VPCエンドポイント設定
- カスタムモデル統合準備

**主要技術:**
- Amazon Bedrock
- IAM Policy管理
- VPC Endpoints
- CloudWatch監視

### 📝 5.1.2 テキスト生成実装

**学習内容:**
- プロンプトエンジニアリング
- テキスト生成API統合
- ストリーミングレスポンス
- 品質評価とフィルタリング

**実装内容:**
- Lambda関数でのテキスト生成
- API Gateway統合
- レスポンスキャッシング
- 有害コンテンツフィルタ

**主要技術:**
- Bedrock Text Models（Claude, Titan）
- Lambda Streaming
- ElastiCache
- Content Moderation

### 💬 5.2.1 チャットボット作成

**学習内容:**
- 対話AI設計パターン
- コンテキスト管理
- 多言語対応
- 感情分析統合

**実装内容:**
- React チャットUI
- WebSocket リアルタイム通信
- 会話履歴管理（DynamoDB）
- 音声入出力統合

**主要技術:**
- Amazon Bedrock (Claude/GPT)
- API Gateway WebSocket
- DynamoDB Conversations
- Amazon Polly/Transcribe

### 🔍 5.2.2 RAGシステム構築

**学習内容:**
- 検索拡張生成（RAG）アーキテクチャ
- ベクトルデータベース設計
- 文書埋め込み生成
- コンテキスト検索最適化

**実装内容:**
- OpenSearch ベクトル検索
- 文書分割・埋め込み生成
- 類似度検索とランキング
- 知識ベース更新パイプライン

**主要技術:**
- Amazon OpenSearch Service
- Bedrock Embeddings (Titan)
- S3 Document Store
- Lambda Processing Pipeline

### 🎨 5.2.3 画像生成機能

**学習内容:**
- テキストから画像生成
- 画像編集とバリエーション
- スタイル転送
- NSFW フィルタリング

**実装内容:**
- Stable Diffusion統合
- 画像ギャラリー管理
- バッチ生成ジョブ
- 画像メタデータ管理

**主要技術:**
- Bedrock Image Models (Stable Diffusion)
- Amazon Rekognition
- S3 Image Storage
- SQS Queue Processing

## 🛠️ 実装例

### Bedrock Text Generation

```python
import boto3
import json
from typing import Dict, Any

class BedrockTextGenerator:
    def __init__(self, region_name: str = 'us-east-1'):
        self.bedrock = boto3.client('bedrock-runtime', region_name=region_name)
    
    def generate_text(
        self, 
        prompt: str, 
        model_id: str = 'anthropic.claude-3-sonnet-20240229-v1:0',
        max_tokens: int = 1000,
        temperature: float = 0.7
    ) -> Dict[str, Any]:
        """Generate text using Bedrock"""
        
        # Claude 3 format
        if 'claude-3' in model_id:
            body = {
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": max_tokens,
                "temperature": temperature,
                "messages": [
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            }
        # Titan format
        elif 'titan' in model_id:
            body = {
                "inputText": prompt,
                "textGenerationConfig": {
                    "maxTokenCount": max_tokens,
                    "temperature": temperature
                }
            }
        
        try:
            response = self.bedrock.invoke_model(
                modelId=model_id,
                body=json.dumps(body),
                contentType='application/json'
            )
            
            result = json.loads(response['body'].read())
            
            if 'claude-3' in model_id:
                generated_text = result['content'][0]['text']
            elif 'titan' in model_id:
                generated_text = result['results'][0]['outputText']
            
            return {
                'text': generated_text,
                'model_id': model_id,
                'tokens_used': result.get('usage', {}).get('output_tokens', 0)
            }
            
        except Exception as e:
            return {'error': str(e)}

# 使用例
generator = BedrockTextGenerator()
result = generator.generate_text(
    prompt="AWSのサーバーレスアーキテクチャについて簡潔に説明してください。",
    temperature=0.5
)
print(result['text'])
```

### RAG Implementation

```python
import boto3
import json
from typing import List, Dict
from opensearchpy import OpenSearch, RequestsHttpConnection
from aws_requests_auth.aws_auth import AWSRequestsAuth

class RAGSystem:
    def __init__(self, opensearch_endpoint: str, region: str = 'us-east-1'):
        self.region = region
        self.bedrock = boto3.client('bedrock-runtime', region_name=region)
        
        # OpenSearch client setup
        credentials = boto3.Session().get_credentials()
        awsauth = AWSRequestsAuth(credentials, region, 'es')
        
        self.opensearch = OpenSearch(
            hosts=[{'host': opensearch_endpoint, 'port': 443}],
            http_auth=awsauth,
            use_ssl=True,
            verify_certs=True,
            connection_class=RequestsHttpConnection
        )
    
    def generate_embedding(self, text: str) -> List[float]:
        """Generate embedding using Bedrock Titan"""
        body = {
            "inputText": text
        }
        
        response = self.bedrock.invoke_model(
            modelId='amazon.titan-embed-text-v1',
            body=json.dumps(body),
            contentType='application/json'
        )
        
        result = json.loads(response['body'].read())
        return result['embedding']
    
    def search_documents(self, query: str, k: int = 5) -> List[Dict]:
        """Search for relevant documents"""
        query_embedding = self.generate_embedding(query)
        
        search_body = {
            "size": k,
            "query": {
                "knn": {
                    "content_vector": {
                        "vector": query_embedding,
                        "k": k
                    }
                }
            },
            "_source": ["content", "title", "metadata"]
        }
        
        response = self.opensearch.search(
            index="knowledge-base",
            body=search_body
        )
        
        return [hit['_source'] for hit in response['hits']['hits']]
    
    def generate_answer(self, question: str, context: List[Dict]) -> str:
        """Generate answer using retrieved context"""
        context_text = "\n\n".join([doc['content'] for doc in context])
        
        prompt = f"""以下のコンテキストを参考に、質問に回答してください。

コンテキスト:
{context_text}

質問: {question}

回答:"""
        
        body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1000,
            "temperature": 0.3,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        }
        
        response = self.bedrock.invoke_model(
            modelId='anthropic.claude-3-sonnet-20240229-v1:0',
            body=json.dumps(body),
            contentType='application/json'
        )
        
        result = json.loads(response['body'].read())
        return result['content'][0]['text']
    
    def answer_question(self, question: str) -> Dict[str, Any]:
        """Main RAG pipeline"""
        # 1. Search for relevant documents
        relevant_docs = self.search_documents(question)
        
        # 2. Generate answer using context
        answer = self.generate_answer(question, relevant_docs)
        
        return {
            'answer': answer,
            'sources': relevant_docs,
            'num_sources': len(relevant_docs)
        }

# 使用例
rag = RAGSystem('your-opensearch-endpoint.region.es.amazonaws.com')
result = rag.answer_question("AWS Lambdaの料金体系について教えてください")
print(result['answer'])
```

### Image Generation

```python
import boto3
import json
import base64
from typing import Dict, Any

class BedrockImageGenerator:
    def __init__(self, region_name: str = 'us-east-1'):
        self.bedrock = boto3.client('bedrock-runtime', region_name=region_name)
        self.s3 = boto3.client('s3')
    
    def generate_image(
        self,
        prompt: str,
        negative_prompt: str = "",
        style: str = "photographic",
        width: int = 1024,
        height: int = 1024,
        cfg_scale: float = 7.0,
        steps: int = 30,
        seed: int = None
    ) -> Dict[str, Any]:
        """Generate image using Stable Diffusion"""
        
        body = {
            "text_prompts": [
                {
                    "text": prompt,
                    "weight": 1.0
                }
            ],
            "cfg_scale": cfg_scale,
            "width": width,
            "height": height,
            "steps": steps,
            "style_preset": style
        }
        
        if negative_prompt:
            body["text_prompts"].append({
                "text": negative_prompt,
                "weight": -1.0
            })
        
        if seed:
            body["seed"] = seed
        
        try:
            response = self.bedrock.invoke_model(
                modelId='stability.stable-diffusion-xl-v1',
                body=json.dumps(body),
                contentType='application/json'
            )
            
            result = json.loads(response['body'].read())
            
            # Get the generated image
            image_data = result['artifacts'][0]['base64']
            
            return {
                'image_base64': image_data,
                'seed': result['artifacts'][0].get('seed'),
                'finish_reason': result['artifacts'][0].get('finishReason')
            }
            
        except Exception as e:
            return {'error': str(e)}
    
    def save_image_to_s3(
        self, 
        image_base64: str, 
        bucket_name: str, 
        key: str
    ) -> str:
        """Save generated image to S3"""
        image_bytes = base64.b64decode(image_base64)
        
        self.s3.put_object(
            Bucket=bucket_name,
            Key=key,
            Body=image_bytes,
            ContentType='image/png'
        )
        
        return f"s3://{bucket_name}/{key}"

# 使用例
generator = BedrockImageGenerator()
result = generator.generate_image(
    prompt="A beautiful sunset over Mount Fuji, digital art style",
    negative_prompt="blurry, low quality",
    style="digital-art"
)

if 'image_base64' in result:
    s3_url = generator.save_image_to_s3(
        result['image_base64'],
        'my-ai-images-bucket',
        f'generated/{datetime.now().isoformat()}.png'
    )
    print(f"Image saved to: {s3_url}")
```

## 📊 コスト最適化

### Bedrock使用量監視

```python
import boto3
from datetime import datetime, timedelta

def monitor_bedrock_costs():
    ce = boto3.client('ce')
    
    # 過去30日のBedrock使用量
    response = ce.get_cost_and_usage(
        TimePeriod={
            'Start': (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d'),
            'End': datetime.now().strftime('%Y-%m-%d')
        },
        Granularity='DAILY',
        Metrics=['BlendedCost'],
        GroupBy=[
            {
                'Type': 'DIMENSION',
                'Key': 'SERVICE'
            }
        ],
        Filter={
            'Dimensions': {
                'Key': 'SERVICE',
                'Values': ['Amazon Bedrock']
            }
        }
    )
    
    total_cost = 0
    for day in response['ResultsByTime']:
        day_cost = float(day['Total']['BlendedCost']['Amount'])
        total_cost += day_cost
        print(f"{day['TimePeriod']['Start']}: ${day_cost:.2f}")
    
    print(f"Total Bedrock cost (30 days): ${total_cost:.2f}")
    
    # アラート（$100超過）
    if total_cost > 100:
        send_cost_alert(total_cost)

def send_cost_alert(cost: float):
    sns = boto3.client('sns')
    sns.publish(
        TopicArn='arn:aws:sns:us-east-1:123456789012:bedrock-cost-alerts',
        Message=f'Bedrock cost exceeded $100: ${cost:.2f}',
        Subject='High Bedrock Cost Alert'
    )
```

### モデル使用量最適化

```python
# キャッシュ戦略でコスト削減
import hashlib
import redis

class CachedBedrockClient:
    def __init__(self):
        self.bedrock = BedrockTextGenerator()
        self.cache = redis.Redis(host='your-elasticache-endpoint')
        self.cache_ttl = 3600  # 1時間
    
    def generate_with_cache(self, prompt: str, **kwargs) -> Dict[str, Any]:
        # キャッシュキー生成
        cache_key = hashlib.md5(
            f"{prompt}_{json.dumps(kwargs, sort_keys=True)}".encode()
        ).hexdigest()
        
        # キャッシュから取得試行
        cached_result = self.cache.get(cache_key)
        if cached_result:
            return json.loads(cached_result)
        
        # 新規生成
        result = self.bedrock.generate_text(prompt, **kwargs)
        
        # キャッシュに保存
        self.cache.setex(
            cache_key, 
            self.cache_ttl, 
            json.dumps(result)
        )
        
        return result
```

## 🔍 監視とログ

### AI アプリケーション監視

```python
import boto3
from datetime import datetime

def log_ai_interaction(
    user_id: str,
    interaction_type: str,
    input_data: Dict,
    output_data: Dict,
    model_id: str,
    cost_estimate: float = None
):
    """AI相互作用のログ記録"""
    
    cloudwatch = boto3.client('cloudwatch')
    dynamodb = boto3.resource('dynamodb')
    
    # CloudWatch カスタムメトリクス
    cloudwatch.put_metric_data(
        Namespace='AI/Application',
        MetricData=[
            {
                'MetricName': 'Interactions',
                'Value': 1,
                'Unit': 'Count',
                'Dimensions': [
                    {
                        'Name': 'InteractionType',
                        'Value': interaction_type
                    },
                    {
                        'Name': 'ModelId',
                        'Value': model_id
                    }
                ]
            }
        ]
    )
    
    # DynamoDB詳細ログ
    table = dynamodb.Table('ai-interaction-logs')
    table.put_item(
        Item={
            'interaction_id': f"{user_id}_{int(datetime.now().timestamp())}",
            'user_id': user_id,
            'timestamp': datetime.now().isoformat(),
            'interaction_type': interaction_type,
            'model_id': model_id,
            'input_tokens': len(str(input_data).split()),
            'output_tokens': len(str(output_data).split()),
            'cost_estimate': cost_estimate or 0,
            'success': 'error' not in output_data
        }
    )
```

## 🛡️ セキュリティベストプラクティス

### コンテンツフィルタリング

```python
import boto3
import re
from typing import Dict, List

class ContentModerator:
    def __init__(self):
        self.comprehend = boto3.client('comprehend')
        self.rekognition = boto3.client('rekognition')
    
    def moderate_text(self, text: str) -> Dict[str, Any]:
        """テキストコンテンツの安全性チェック"""
        
        # 有害語句チェック
        harmful_patterns = [
            r'暴力',
            r'差別',
            r'個人情報',
            # その他のパターン
        ]
        
        flags = []
        for pattern in harmful_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                flags.append(f'harmful_content: {pattern}')
        
        # AWS Comprehend 有害性検出
        try:
            response = self.comprehend.detect_toxic_content(
                TextSegments=[{'Text': text}],
                LanguageCode='ja'
            )
            
            for result in response['ResultList']:
                for label in result['Labels']:
                    if label['Score'] > 0.7:  # 閾値
                        flags.append(f'toxic: {label["Name"]}')
        
        except Exception as e:
            flags.append(f'moderation_error: {str(e)}')
        
        return {
            'is_safe': len(flags) == 0,
            'flags': flags,
            'confidence': 1.0 - (len(flags) * 0.2)
        }
    
    def moderate_image(self, image_bytes: bytes) -> Dict[str, Any]:
        """画像コンテンツの安全性チェック"""
        
        try:
            response = self.rekognition.detect_moderation_labels(
                Image={'Bytes': image_bytes},
                MinConfidence=70
            )
            
            flags = []
            for label in response['ModerationLabels']:
                flags.append(f"{label['Name']}: {label['Confidence']:.1f}%")
            
            return {
                'is_safe': len(flags) == 0,
                'flags': flags
            }
            
        except Exception as e:
            return {
                'is_safe': False,
                'flags': [f'moderation_error: {str(e)}']
            }
```

## 📚 参考資料

### AWS ドキュメント
- [Amazon Bedrock User Guide](https://docs.aws.amazon.com/bedrock/)
- [Generative AI on AWS](https://aws.amazon.com/generative-ai/)
- [MLOps on AWS](https://aws.amazon.com/machine-learning/mlops/)

### AI/ML学習リソース
- [Prompt Engineering Guide](https://www.promptingguide.ai/)
- [LangChain Documentation](https://python.langchain.com/)
- [Hugging Face Transformers](https://huggingface.co/transformers/)

## 📈 次のステップ

完了後は以下に進んでください：

1. **[CI-CD高度化編](../06-CI-CD高度化編/README.md)** - MLOps パイプライン
2. **[Claude Code & Bedrock編](../07-Claude-Code-Bedrock-AI駆動開発編/README.md)** - AI駆動開発
3. **独自AIアプリケーション開発** - 学習した技術の応用

---

## 🎯 学習チェックリスト

### Bedrock基礎
- [ ] Bedrockセットアップとモデルアクセス
- [ ] テキスト生成API実装
- [ ] プロンプトエンジニアリング
- [ ] コスト監視設定

### AI機能実装
- [ ] チャットボット作成（UI + バックエンド）
- [ ] RAGシステム構築（ベクトル検索）
- [ ] 画像生成機能実装
- [ ] コンテンツモデレーション

### 統合・運用
- [ ] セキュリティ設定
- [ ] パフォーマンス最適化
- [ ] 監視・ログ設定
- [ ] A/Bテスト実装

**準備ができたら次のセクションへ進みましょう！**