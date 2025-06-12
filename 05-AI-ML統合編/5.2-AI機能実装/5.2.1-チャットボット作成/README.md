# 5.2.1 チャットボット作成

## 学習目標

このセクションでは、Amazon Bedrockを活用したインタラクティブなチャットボットを構築し、リアルタイムでAIとやり取りできるWebアプリケーションを開発します。

### 習得できるスキル
- Bedrock APIを使用したコンバセーショナルAIの実装
- WebSocketまたはServer-Sent Eventsによるリアルタイム通信
- Reactベースのチャット UI の構築
- チャット履歴の管理とコンテキスト保持
- ストリーミングレスポンスの処理
- プロンプトエンジニアリングの実践
- AI応答のフィルタリングとセーフティ機能

## 前提知識

### 必須の知識
- Amazon Bedrockの基本設定（5.1.1セクション完了）
- React/Next.jsの基礎知識
- REST APIの実装経験
- WebSocketまたはSSEの基本概念
- LambdaとAPI Gatewayの理解

### あると望ましい知識
- TypeScriptの基礎
- プロンプトエンジニアリングの基本
- UX/UIデザインの基礎
- リアルタイムアプリケーションの開発経験

## アーキテクチャ概要

### チャットボットアーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend (React)                        │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Chat UI       │  │   Message       │  │   Settings  │ │
│  │  Component      │  │   History       │  │   Panel     │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│                              │                              │
│                              │ WebSocket / SSE              │
└──────────────────────────────┼──────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────┐
│                    API Gateway                              │
│                              │                              │
│  ┌─────────────────┐        │        ┌─────────────────┐   │
│  │   WebSocket     │        │        │      REST       │   │
│  │    Route        │        │        │     Routes      │   │
│  └─────────────────┘        │        └─────────────────┘   │
└──────────────────────────────┼──────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────┐
│                       Lambda Functions                      │
│                              │                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Chat Handler  │  │   Message       │  │   Session   │ │
│  │   (Streaming)   │  │   Processor     │  │   Manager   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│                              │                              │
└──────────────────────────────┼──────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────┐
│                    Amazon Bedrock                           │
│                              │                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Claude 3      │  │   Titan Text    │  │   Model     │ │
│  │   Models        │  │   Models        │  │   Selection │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────┐
│                       DynamoDB                              │
│                              │                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Chat Sessions │  │   Message       │  │    User     │ │
│  │     Table       │  │   History       │  │ Preferences │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **Chat UI**: レスポンシブなチャットインターフェース
- **WebSocket Handler**: リアルタイム通信の管理
- **Message Processor**: プロンプト処理とレスポンス生成
- **Session Manager**: チャット履歴とコンテキスト管理
- **Safety Filter**: 不適切なコンテンツのフィルタリング

## ハンズオン手順

### ステップ1: バックエンドAPIの構築

1. **Lambda関数のセットアップ**
```bash
cd /mnt/c/dev2/practice/05-AI-ML統合編/5.2-AI機能実装/5.2.1-チャットボット作成/backend
mkdir chatbot && cd chatbot
```

2. **チャット処理Lambda関数の作成**
```python
# lambda_function.py
import json
import boto3
import uuid
from datetime import datetime
from botocore.exceptions import ClientError

bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """メインのチャット処理ハンドラー"""
    try:
        # リクエストの解析
        body = json.loads(event['body'])
        user_message = body.get('message', '')
        session_id = body.get('session_id', str(uuid.uuid4()))
        model_id = body.get('model_id', 'anthropic.claude-3-haiku-20240307-v1:0')
        
        # メッセージ履歴の取得
        chat_history = get_chat_history(session_id)
        
        # プロンプトの構築
        prompt = build_conversation_prompt(chat_history, user_message)
        
        # Bedrockへのリクエスト
        response = invoke_bedrock_model(model_id, prompt)
        
        # レスポンスの保存
        save_message(session_id, user_message, response, 'user')
        save_message(session_id, response, '', 'assistant')
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, GET, OPTIONS'
            },
            'body': json.dumps({
                'response': response,
                'session_id': session_id,
                'timestamp': datetime.now().isoformat()
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }

def get_chat_history(session_id, limit=10):
    """チャット履歴を取得"""
    table = dynamodb.Table('ChatHistory')
    
    try:
        response = table.query(
            KeyConditionExpression='session_id = :session_id',
            ExpressionAttributeValues={
                ':session_id': session_id
            },
            ScanIndexForward=False,  # 最新から取得
            Limit=limit
        )
        
        # 時系列順に並び替え
        return sorted(response['Items'], key=lambda x: x['timestamp'])
        
    except ClientError as e:
        print(f"DynamoDB error: {e}")
        return []

def build_conversation_prompt(chat_history, new_message):
    """会話履歴を含むプロンプトを構築"""
    conversation = []
    
    # システムプロンプト
    system_prompt = """あなたは親切で知識豊富なAIアシスタントです。
以下のガイドラインに従って回答してください：

1. 丁寧で分かりやすい日本語で回答する
2. 技術的な質問には具体的な例を含める
3. 不確実な情報については正直に伝える
4. 危険または不適切な内容には応答しない
5. 簡潔でありながら有用な情報を提供する"""
    
    conversation.append(f"System: {system_prompt}")
    
    # 履歴の追加
    for msg in chat_history:
        role = "Human" if msg['role'] == 'user' else "Assistant"
        conversation.append(f"{role}: {msg['message']}")
    
    # 新しいメッセージの追加
    conversation.append(f"Human: {new_message}")
    conversation.append("Assistant:")
    
    return "\n\n".join(conversation)

def invoke_bedrock_model(model_id, prompt):
    """Bedrockモデルを呼び出し"""
    try:
        if 'claude' in model_id.lower():
            return invoke_claude_model(model_id, prompt)
        elif 'titan' in model_id.lower():
            return invoke_titan_model(model_id, prompt)
        else:
            raise ValueError(f"Unsupported model: {model_id}")
            
    except ClientError as e:
        print(f"Bedrock error: {e}")
        return "申し訳ございません。現在AIサービスに問題が発生しています。"

def invoke_claude_model(model_id, prompt):
    """Claude モデルの呼び出し"""
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
    
    response_body = json.loads(response['body'].read())
    return response_body['content'][0]['text']

def invoke_titan_model(model_id, prompt):
    """Titan モデルの呼び出し"""
    body = {
        "inputText": prompt,
        "textGenerationConfig": {
            "maxTokenCount": 1000,
            "temperature": 0.7,
            "topP": 0.9,
            "stopSequences": ["Human:", "Assistant:"]
        }
    }
    
    response = bedrock.invoke_model(
        modelId=model_id,
        body=json.dumps(body)
    )
    
    response_body = json.loads(response['body'].read())
    return response_body['results'][0]['outputText'].strip()

def save_message(session_id, message, response, role):
    """メッセージをDynamoDBに保存"""
    table = dynamodb.Table('ChatHistory')
    
    item = {
        'session_id': session_id,
        'timestamp': datetime.now().isoformat(),
        'message_id': str(uuid.uuid4()),
        'message': message,
        'role': role,
        'response': response
    }
    
    try:
        table.put_item(Item=item)
    except ClientError as e:
        print(f"Failed to save message: {e}")
```

### ステップ2: ストリーミングレスポンスの実装

1. **WebSocketハンドラーの作成**
```python
# websocket_handler.py
import json
import boto3
from botocore.exceptions import ClientError

bedrock = boto3.client('bedrock-runtime')
apigateway = boto3.client('apigatewaymanagementapi')

def lambda_handler(event, context):
    """WebSocket接続ハンドラー"""
    route_key = event.get('requestContext', {}).get('routeKey')
    connection_id = event.get('requestContext', {}).get('connectionId')
    
    if route_key == '$connect':
        return handle_connect(connection_id)
    elif route_key == '$disconnect':
        return handle_disconnect(connection_id)
    elif route_key == 'sendMessage':
        return handle_message(event, connection_id)
    
    return {'statusCode': 400}

def handle_connect(connection_id):
    """WebSocket接続処理"""
    print(f"Client connected: {connection_id}")
    return {'statusCode': 200}

def handle_disconnect(connection_id):
    """WebSocket切断処理"""
    print(f"Client disconnected: {connection_id}")
    return {'statusCode': 200}

def handle_message(event, connection_id):
    """メッセージ処理とストリーミングレスポンス"""
    try:
        body = json.loads(event['body'])
        message = body.get('message', '')
        model_id = body.get('model_id', 'anthropic.claude-3-haiku-20240307-v1:0')
        
        # ストリーミングレスポンスの開始
        stream_response(connection_id, message, model_id)
        
        return {'statusCode': 200}
        
    except Exception as e:
        send_message(connection_id, {
            'type': 'error',
            'message': f'Error: {str(e)}'
        })
        return {'statusCode': 500}

def stream_response(connection_id, user_message, model_id):
    """ストリーミングでレスポンスを送信"""
    try:
        # Claude 3のストリーミング呼び出し
        body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1000,
            "messages": [
                {
                    "role": "user",
                    "content": user_message
                }
            ],
            "temperature": 0.7
        }
        
        response = bedrock.invoke_model_with_response_stream(
            modelId=model_id,
            body=json.dumps(body)
        )
        
        # ストリーミング開始の通知
        send_message(connection_id, {
            'type': 'stream_start',
            'message': 'AI is thinking...'
        })
        
        # ストリームの処理
        full_response = ""
        for event in response['body']:
            chunk = json.loads(event['chunk']['bytes'])
            
            if chunk['type'] == 'content_block_delta':
                text_chunk = chunk['delta']['text']
                full_response += text_chunk
                
                # チャンクを送信
                send_message(connection_id, {
                    'type': 'stream_chunk',
                    'chunk': text_chunk,
                    'full_response': full_response
                })
        
        # ストリーミング完了の通知
        send_message(connection_id, {
            'type': 'stream_complete',
            'final_response': full_response
        })
        
    except Exception as e:
        send_message(connection_id, {
            'type': 'error',
            'message': f'Streaming error: {str(e)}'
        })

def send_message(connection_id, message):
    """WebSocketでメッセージを送信"""
    try:
        apigateway.post_to_connection(
            ConnectionId=connection_id,
            Data=json.dumps(message)
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'GoneException':
            print(f"Connection {connection_id} is no longer available")
        else:
            print(f"Failed to send message: {e}")
```

### ステップ3: フロントエンドの構築

1. **React チャットコンポーネント**
```tsx
// components/ChatBot.tsx
'use client';

import React, { useState, useEffect, useRef } from 'react';
import { Send, Bot, User, Settings, Download, Trash2 } from 'lucide-react';

interface Message {
  id: string;
  content: string;
  sender: 'user' | 'bot';
  timestamp: Date;
  isStreaming?: boolean;
}

interface ChatBotProps {
  apiEndpoint: string;
  webSocketUrl?: string;
}

export default function ChatBot({ apiEndpoint, webSocketUrl }: ChatBotProps) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [sessionId, setSessionId] = useState('');
  const [selectedModel, setSelectedModel] = useState('anthropic.claude-3-haiku-20240307-v1:0');
  const [ws, setWs] = useState<WebSocket | null>(null);
  
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // 初期化
  useEffect(() => {
    setSessionId(generateSessionId());
    
    // WebSocket接続（利用可能な場合）
    if (webSocketUrl) {
      initializeWebSocket();
    }
    
    // 初期メッセージ
    addMessage({
      id: '1',
      content: 'こんにちは！何でもお気軽にお聞きください。',
      sender: 'bot',
      timestamp: new Date()
    });
    
    return () => {
      ws?.close();
    };
  }, []);

  // メッセージが更新されたらスクロール
  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const initializeWebSocket = () => {
    if (!webSocketUrl) return;
    
    const websocket = new WebSocket(webSocketUrl);
    
    websocket.onopen = () => {
      console.log('WebSocket connected');
      setWs(websocket);
    };
    
    websocket.onmessage = (event) => {
      const data = JSON.parse(event.data);
      handleWebSocketMessage(data);
    };
    
    websocket.onclose = () => {
      console.log('WebSocket disconnected');
      setWs(null);
    };
    
    websocket.onerror = (error) => {
      console.error('WebSocket error:', error);
    };
  };

  const handleWebSocketMessage = (data: any) => {
    switch (data.type) {
      case 'stream_start':
        // ストリーミング開始
        const streamingMessage: Message = {
          id: generateMessageId(),
          content: '',
          sender: 'bot',
          timestamp: new Date(),
          isStreaming: true
        };
        setMessages(prev => [...prev, streamingMessage]);
        break;
        
      case 'stream_chunk':
        // ストリーミングチャンク
        setMessages(prev => 
          prev.map(msg => 
            msg.isStreaming 
              ? { ...msg, content: data.full_response }
              : msg
          )
        );
        break;
        
      case 'stream_complete':
        // ストリーミング完了
        setMessages(prev => 
          prev.map(msg => 
            msg.isStreaming 
              ? { ...msg, content: data.final_response, isStreaming: false }
              : msg
          )
        );
        setIsLoading(false);
        break;
        
      case 'error':
        console.error('WebSocket error:', data.message);
        setIsLoading(false);
        break;
    }
  };

  const sendMessage = async () => {
    if (!inputMessage.trim()) return;
    
    const userMessage: Message = {
      id: generateMessageId(),
      content: inputMessage,
      sender: 'user',
      timestamp: new Date()
    };
    
    addMessage(userMessage);
    setInputMessage('');
    setIsLoading(true);
    
    try {
      if (ws && ws.readyState === WebSocket.OPEN) {
        // WebSocket経由でストリーミング
        ws.send(JSON.stringify({
          message: inputMessage,
          session_id: sessionId,
          model_id: selectedModel
        }));
      } else {
        // REST API経由
        await sendMessageREST(inputMessage);
      }
    } catch (error) {
      console.error('Error sending message:', error);
      addMessage({
        id: generateMessageId(),
        content: 'エラーが発生しました。もう一度お試しください。',
        sender: 'bot',
        timestamp: new Date()
      });
      setIsLoading(false);
    }
  };

  const sendMessageREST = async (message: string) => {
    const response = await fetch(apiEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message,
        session_id: sessionId,
        model_id: selectedModel
      })
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    
    addMessage({
      id: generateMessageId(),
      content: data.response,
      sender: 'bot',
      timestamp: new Date()
    });
    
    setIsLoading(false);
  };

  const addMessage = (message: Message) => {
    setMessages(prev => [...prev, message]);
  };

  const clearChat = () => {
    setMessages([]);
    setSessionId(generateSessionId());
    addMessage({
      id: '1',
      content: 'チャットがクリアされました。新しい会話を始めましょう！',
      sender: 'bot',
      timestamp: new Date()
    });
  };

  const exportChat = () => {
    const chatContent = messages
      .map(msg => `[${msg.timestamp.toLocaleTimeString()}] ${msg.sender}: ${msg.content}`)
      .join('\n');
    
    const blob = new Blob([chatContent], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `chat-${sessionId}.txt`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const generateSessionId = () => {
    return Math.random().toString(36).substring(2, 15);
  };

  const generateMessageId = () => {
    return Math.random().toString(36).substring(2, 15);
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  return (
    <div className="flex flex-col h-screen max-w-4xl mx-auto bg-white shadow-lg">
      {/* ヘッダー */}
      <div className="bg-blue-600 text-white p-4 flex justify-between items-center">
        <h1 className="text-xl font-semibold flex items-center">
          <Bot className="mr-2" size={24} />
          AI チャットボット
        </h1>
        <div className="flex items-center space-x-2">
          <select
            value={selectedModel}
            onChange={(e) => setSelectedModel(e.target.value)}
            className="bg-blue-700 text-white rounded px-2 py-1 text-sm"
          >
            <option value="anthropic.claude-3-haiku-20240307-v1:0">Claude 3 Haiku</option>
            <option value="anthropic.claude-3-sonnet-20240229-v1:0">Claude 3 Sonnet</option>
            <option value="amazon.titan-text-express-v1">Titan Text Express</option>
          </select>
          <button
            onClick={exportChat}
            className="p-2 hover:bg-blue-700 rounded"
            title="チャットをエクスポート"
          >
            <Download size={20} />
          </button>
          <button
            onClick={clearChat}
            className="p-2 hover:bg-blue-700 rounded"
            title="チャットをクリア"
          >
            <Trash2 size={20} />
          </button>
        </div>
      </div>

      {/* メッセージ一覧 */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((message) => (
          <div
            key={message.id}
            className={`flex ${
              message.sender === 'user' ? 'justify-end' : 'justify-start'
            }`}
          >
            <div
              className={`max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
                message.sender === 'user'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-200 text-gray-800'
              }`}
            >
              <div className="flex items-start space-x-2">
                {message.sender === 'bot' && (
                  <Bot size={16} className="mt-1 flex-shrink-0" />
                )}
                {message.sender === 'user' && (
                  <User size={16} className="mt-1 flex-shrink-0" />
                )}
                <div className="flex-1">
                  <p className="text-sm">
                    {message.content}
                    {message.isStreaming && (
                      <span className="animate-pulse">...</span>
                    )}
                  </p>
                  <p className="text-xs opacity-70 mt-1">
                    {message.timestamp.toLocaleTimeString()}
                  </p>
                </div>
              </div>
            </div>
          </div>
        ))}
        
        {isLoading && (
          <div className="flex justify-start">
            <div className="bg-gray-200 text-gray-800 max-w-xs lg:max-w-md px-4 py-2 rounded-lg">
              <div className="flex items-center space-x-2">
                <Bot size={16} />
                <div className="flex space-x-1">
                  <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
                  <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{animationDelay: '0.1s'}}></div>
                  <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{animationDelay: '0.2s'}}></div>
                </div>
              </div>
            </div>
          </div>
        )}
        
        <div ref={messagesEndRef} />
      </div>

      {/* 入力エリア */}
      <div className="border-t p-4">
        <div className="flex space-x-2">
          <input
            ref={inputRef}
            type="text"
            value={inputMessage}
            onChange={(e) => setInputMessage(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="メッセージを入力してください..."
            className="flex-1 border border-gray-300 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={isLoading}
          />
          <button
            onClick={sendMessage}
            disabled={isLoading || !inputMessage.trim()}
            className="bg-blue-600 text-white p-2 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Send size={20} />
          </button>
        </div>
      </div>
    </div>
  );
}
```

### ステップ4: CloudFormationによるデプロイ

1. **インフラストラクチャテンプレート**
```yaml
# chatbot-infrastructure.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Chatbot infrastructure with Bedrock integration'

Parameters:
  ProjectName:
    Type: String
    Default: 'AI-Learning-Chatbot'

Resources:
  # DynamoDB Tables
  ChatHistoryTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-ChatHistory'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: session_id
          AttributeType: S
        - AttributeName: timestamp
          AttributeType: S
      KeySchema:
        - AttributeName: session_id
          KeyType: HASH
        - AttributeName: timestamp
          KeyType: RANGE
      TimeToLiveSpecification:
        AttributeName: ttl
        Enabled: true
      Tags:
        - Key: Project
          Value: !Ref ProjectName

  # Lambda Execution Role
  ChatbotLambdaRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${ProjectName}-Lambda-Role'
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
        - PolicyName: ChatbotAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - bedrock:InvokeModel
                  - bedrock:InvokeModelWithResponseStream
                Resource:
                  - !Sub 'arn:aws:bedrock:${AWS::Region}::foundation-model/*'
              - Effect: Allow
                Action:
                  - dynamodb:GetItem
                  - dynamodb:PutItem
                  - dynamodb:Query
                  - dynamodb:UpdateItem
                Resource:
                  - !GetAtt ChatHistoryTable.Arn
              - Effect: Allow
                Action:
                  - execute-api:ManageConnections
                Resource:
                  - !Sub 'arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:*'

  # Lambda Functions
  ChatbotFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-ChatHandler'
      Runtime: python3.9
      Handler: lambda_function.lambda_handler
      Role: !GetAtt ChatbotLambdaRole.Arn
      Code:
        ZipFile: |
          # Lambda function code here
          def lambda_handler(event, context):
              return {'statusCode': 200, 'body': 'Hello from Lambda!'}
      Environment:
        Variables:
          CHAT_HISTORY_TABLE: !Ref ChatHistoryTable
          REGION: !Ref AWS::Region
      Timeout: 300

  WebSocketFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-WebSocketHandler'
      Runtime: python3.9
      Handler: websocket_handler.lambda_handler
      Role: !GetAtt ChatbotLambdaRole.Arn
      Code:
        ZipFile: |
          # WebSocket handler code here
          def lambda_handler(event, context):
              return {'statusCode': 200}
      Environment:
        Variables:
          CHAT_HISTORY_TABLE: !Ref ChatHistoryTable
          REGION: !Ref AWS::Region
      Timeout: 300

  # API Gateway
  ChatbotApi:
    Type: AWS::ApiGateway::RestApi
    Properties:
      Name: !Sub '${ProjectName}-API'
      Description: 'REST API for chatbot'
      EndpointConfiguration:
        Types:
          - REGIONAL

  ChatbotResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      RestApiId: !Ref ChatbotApi
      ParentId: !GetAtt ChatbotApi.RootResourceId
      PathPart: chat

  ChatbotMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref ChatbotApi
      ResourceId: !Ref ChatbotResource
      HttpMethod: POST
      AuthorizationType: NONE
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${ChatbotFunction.Arn}/invocations'

  # CORS Options Method
  ChatbotOptionsMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref ChatbotApi
      ResourceId: !Ref ChatbotResource
      HttpMethod: OPTIONS
      AuthorizationType: NONE
      Integration:
        Type: MOCK
        IntegrationResponses:
          - StatusCode: 200
            ResponseParameters:
              method.response.header.Access-Control-Allow-Headers: "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
              method.response.header.Access-Control-Allow-Methods: "'POST,OPTIONS'"
              method.response.header.Access-Control-Allow-Origin: "'*'"
        RequestTemplates:
          application/json: '{"statusCode": 200}'
      MethodResponses:
        - StatusCode: 200
          ResponseParameters:
            method.response.header.Access-Control-Allow-Headers: true
            method.response.header.Access-Control-Allow-Methods: true
            method.response.header.Access-Control-Allow-Origin: true

  # WebSocket API
  WebSocketApi:
    Type: AWS::ApiGatewayV2::Api
    Properties:
      Name: !Sub '${ProjectName}-WebSocket'
      ProtocolType: WEBSOCKET
      RouteSelectionExpression: '$request.body.action'

  WebSocketConnectRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref WebSocketApi
      RouteKey: $connect
      Target: !Sub 'integrations/${WebSocketConnectIntegration}'

  WebSocketDisconnectRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref WebSocketApi
      RouteKey: $disconnect
      Target: !Sub 'integrations/${WebSocketDisconnectIntegration}'

  WebSocketMessageRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref WebSocketApi
      RouteKey: sendMessage
      Target: !Sub 'integrations/${WebSocketMessageIntegration}'

  WebSocketConnectIntegration:
    Type: AWS::ApiGatewayV2::Integration
    Properties:
      ApiId: !Ref WebSocketApi
      IntegrationType: AWS_PROXY
      IntegrationUri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${WebSocketFunction.Arn}/invocations'

  WebSocketDisconnectIntegration:
    Type: AWS::ApiGatewayV2::Integration
    Properties:
      ApiId: !Ref WebSocketApi
      IntegrationType: AWS_PROXY
      IntegrationUri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${WebSocketFunction.Arn}/invocations'

  WebSocketMessageIntegration:
    Type: AWS::ApiGatewayV2::Integration
    Properties:
      ApiId: !Ref WebSocketApi
      IntegrationType: AWS_PROXY
      IntegrationUri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${WebSocketFunction.Arn}/invocations'

  # Deployments
  ApiDeployment:
    Type: AWS::ApiGateway::Deployment
    DependsOn:
      - ChatbotMethod
      - ChatbotOptionsMethod
    Properties:
      RestApiId: !Ref ChatbotApi
      StageName: prod

  WebSocketDeployment:
    Type: AWS::ApiGatewayV2::Deployment
    DependsOn:
      - WebSocketConnectRoute
      - WebSocketDisconnectRoute
      - WebSocketMessageRoute
    Properties:
      ApiId: !Ref WebSocketApi

  WebSocketStage:
    Type: AWS::ApiGatewayV2::Stage
    Properties:
      ApiId: !Ref WebSocketApi
      DeploymentId: !Ref WebSocketDeployment
      StageName: prod

  # Lambda Permissions
  LambdaApiGatewayPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref ChatbotFunction
      Action: lambda:InvokeFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub '${ChatbotApi}/*/POST/chat'

  WebSocketLambdaPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref WebSocketFunction
      Action: lambda:InvokeFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub 'arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${WebSocketApi}/*'

Outputs:
  ApiUrl:
    Description: 'REST API endpoint URL'
    Value: !Sub 'https://${ChatbotApi}.execute-api.${AWS::Region}.amazonaws.com/prod/chat'
    Export:
      Name: !Sub '${ProjectName}-ApiUrl'

  WebSocketUrl:
    Description: 'WebSocket API endpoint URL'
    Value: !Sub 'wss://${WebSocketApi}.execute-api.${AWS::Region}.amazonaws.com/prod'
    Export:
      Name: !Sub '${ProjectName}-WebSocketUrl'

  ChatHistoryTableName:
    Description: 'DynamoDB table name for chat history'
    Value: !Ref ChatHistoryTable
    Export:
      Name: !Sub '${ProjectName}-ChatHistoryTable'
```

## 検証方法

### 1. バックエンドAPIのテスト
```bash
# REST APIの動作確認
curl -X POST https://your-api-endpoint/prod/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "こんにちは",
    "session_id": "test-session-123",
    "model_id": "anthropic.claude-3-haiku-20240307-v1:0"
  }'
```

### 2. WebSocket接続のテスト
```javascript
// ブラウザの開発者ツールで実行
const ws = new WebSocket('wss://your-websocket-endpoint/prod');
ws.onopen = () => console.log('Connected');
ws.onmessage = (event) => console.log('Received:', JSON.parse(event.data));
ws.send(JSON.stringify({
  action: 'sendMessage',
  message: 'テストメッセージ'
}));
```

### 3. フロントエンドの動作確認
- チャット画面の表示
- メッセージの送受信
- ストリーミングレスポンス
- モデル切り替え
- チャット履歴の保持
- エクスポート機能

## トラブルシューティング

### よくある問題と解決策

#### 1. Bedrockモデルアクセスエラー
**症状**: "Access denied for model" エラー
**解決策**:
```bash
# モデルアクセス権限の確認
aws bedrock list-foundation-models --region us-east-1
aws bedrock get-model-invocation-logging-configuration
```

#### 2. WebSocket接続失敗
**症状**: WebSocket接続が確立されない
**解決策**:
- API Gateway WebSocketのルート設定確認
- Lambda関数の権限設定確認
- CloudWatch Logsでエラー詳細確認

#### 3. DynamoDB書き込みエラー
**症状**: チャット履歴が保存されない
**解決策**:
```bash
# テーブル存在確認
aws dynamodb describe-table --table-name AI-Learning-Chatbot-ChatHistory

# Lambda実行ロールの権限確認
aws iam get-role-policy --role-name AI-Learning-Chatbot-Lambda-Role --policy-name ChatbotAccess
```

### デバッグ手法
```python
# Lambda関数内でのログ出力
import logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")
    # 処理...
    logger.info(f"Response: {response}")
```

## 学習リソース

### AWS公式ドキュメント
- [Amazon Bedrock User Guide](https://docs.aws.amazon.com/bedrock/latest/userguide/)
- [API Gateway WebSocket APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/websocket-api.html)
- [DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/latest/developerguide/)

### 追加学習教材
- [Building Conversational AI with Amazon Bedrock](https://aws.amazon.com/blogs/machine-learning/)
- [WebSocket Real-time Applications](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)
- [React Chat Application Tutorial](https://reactjs.org/tutorial/tutorial.html)

### 関連するAWS認定試験
- AWS Certified Machine Learning - Specialty
- AWS Certified Solutions Architect - Professional

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **入力検証**: ユーザー入力の適切なサニタイズ
2. **レート制限**: API呼び出し頻度の制御
3. **認証・認可**: IAMロールとポリシーの最小権限設定
4. **コンテンツフィルタリング**: 不適切なコンテンツの検出と除去
5. **データ暗号化**: 転送時・保管時の暗号化

### コスト最適化
1. **Bedrockモデル選択**: 用途に応じた適切なモデル選択
2. **DynamoDB設定**: オンデマンドvs プロビジョニング済み
3. **Lambda最適化**: メモリとタイムアウト設定の調整
4. **API Gateway**: 不要なリクエストの削減

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatch Logsとメトリクスによる監視
- **セキュリティの柱**: IAMによるアクセス制御と暗号化
- **信頼性の柱**: エラーハンドリングと再試行メカニズム
- **パフォーマンス効率の柱**: 適切なコンピューティングリソース選択
- **コスト最適化の柱**: 使用量ベースの課金とリソース最適化

## 次のステップ

### 推奨される学習パス
1. **5.2.2 RAGシステム構築**: 知識ベースを活用した高度なチャットボット
2. **5.2.3 画像生成機能**: マルチモーダルAI機能の追加
3. **6.1.1 マルチステージビルド**: CI/CDパイプラインの構築
4. **6.2.1 APM実装**: アプリケーション監視の強化

### 発展的な機能
1. **マルチモーダル対応**: 画像・音声入力の処理
2. **パーソナライゼーション**: ユーザーごとの学習・カスタマイズ
3. **多言語対応**: 国際化とローカライゼーション
4. **音声合成**: テキスト読み上げ機能

### 実践プロジェクトのアイデア
1. **カスタマーサポートボット**: FAQ対応とエスカレーション機能
2. **学習アシスタント**: 質問応答と進捗管理
3. **コード生成アシスタント**: プログラミング支援機能
4. **創作支援ツール**: 文章・アイデア生成支援