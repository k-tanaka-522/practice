# Web三層アーキテクチャ完全ガイド

## 🏗️ Web三層アーキテクチャとは

**Web三層アーキテクチャ**は、Webアプリケーションを3つの論理的な層に分けて設計するアーキテクチャパターンです。各層が独立して開発・運用でき、スケーラビリティと保守性を向上させます。

### 📊 三層構造の概要

```
┌─────────────────────────────────────────────────────────────────┐
│                    🎨 プレゼンテーション層                         │
│                  (Presentation Layer)                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   React     │  │ CloudFront  │  │   Route53   │             │
│  │     SPA     │  │     CDN     │  │     DNS     │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│        │                    │                    │             │
│        └────────────────────┼────────────────────┘             │
└─────────────────────────────┼─────────────────────────────────┘
                              │ HTTPS/REST API
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  ⚙️ アプリケーション層                           │
│                  (Application Layer)                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ API Gateway │  │   Lambda    │  │   Cognito   │             │
│  │   REST API  │  │  Functions  │  │    Auth     │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│        │                    │                    │             │
│        └────────────────────┼────────────────────┘             │
└─────────────────────────────┼─────────────────────────────────┘
                              │ Database API/Query
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    💾 データ層                                  │
│                    (Data Layer)                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  DynamoDB   │  │     RDS     │  │     S3      │             │
│  │   NoSQL     │  │   RDBMS     │  │ File Store  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 各層の役割と責任

### 1. 🎨 プレゼンテーション層 (Presentation Layer)

**役割**: ユーザーインターフェースとユーザー体験の提供

**責任**:
- ユーザーインターフェースの表示
- ユーザー入力の受け取り
- アプリケーション層への要求送信
- レスポンスの表示とエラーハンドリング

**AWSサービス**:
- **S3**: 静的ファイル（HTML, CSS, JS）のホスティング
- **CloudFront**: グローバルCDN配信、高速化
- **Route53**: ドメイン名解決、DNS管理

**実装例**:
```javascript
// React コンポーネント例
import React, { useState, useEffect } from 'react';
import { API } from 'aws-amplify';

const UserProfile = () => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchUserProfile();
  }, []);

  const fetchUserProfile = async () => {
    try {
      // アプリケーション層のAPIを呼び出し
      const userData = await API.get('userAPI', '/profile');
      setUser(userData);
    } catch (error) {
      console.error('Failed to fetch user profile:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="user-profile">
      {loading ? (
        <div>Loading...</div>
      ) : user ? (
        <div>
          <h2>{user.name}</h2>
          <p>{user.email}</p>
        </div>
      ) : (
        <div>Error loading profile</div>
      )}
    </div>
  );
};
```

### 2. ⚙️ アプリケーション層 (Application Layer)

**役割**: ビジネスロジックの実装と処理

**責任**:
- ビジネスルールの実装
- データの加工・変換
- 認証・認可の処理
- 外部サービスとの連携
- データ層へのアクセス制御

**AWSサービス**:
- **API Gateway**: RESTful API のエンドポイント提供
- **Lambda**: サーバーレス関数でビジネスロジック実装
- **Cognito**: ユーザー認証・認可
- **Step Functions**: 複雑なワークフロー管理

**実装例**:
```python
# Lambda関数例
import json
import boto3
from datetime import datetime

def lambda_handler(event, context):
    """
    ユーザープロフィール取得API
    """
    try:
        # 認証トークンの検証
        token = event['headers'].get('Authorization')
        user_id = verify_jwt_token(token)
        
        # ビジネスロジック: プロフィールデータの取得と加工
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table('Users')
        
        response = table.get_item(Key={'userId': user_id})
        user_data = response.get('Item')
        
        if not user_data:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'User not found'})
            }
        
        # データの加工（機密情報の除去など）
        safe_user_data = {
            'userId': user_data['userId'],
            'name': user_data['name'],
            'email': user_data['email'],
            'lastLogin': user_data.get('lastLogin'),
            'profileImage': user_data.get('profileImage')
        }
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(safe_user_data)
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def verify_jwt_token(token):
    """
    JWT トークンの検証とユーザーID取得
    """
    # Cognito JWT 検証ロジック
    # 実際の実装では cognito-idp を使用
    pass
```

### 3. 💾 データ層 (Data Layer)

**役割**: データの永続化と管理

**責任**:
- データの保存・取得・更新・削除
- データの整合性保証
- バックアップ・復旧
- パフォーマンス最適化

**AWSサービス**:
- **DynamoDB**: NoSQLデータベース、高速アクセス
- **RDS**: リレーショナルデータベース、ACID特性
- **S3**: オブジェクトストレージ、ファイル・画像保存
- **ElastiCache**: インメモリキャッシュ

**実装例**:
```python
# DynamoDB データアクセス層
import boto3
from boto3.dynamodb.conditions import Key
from datetime import datetime

class UserRepository:
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb')
        self.table = self.dynamodb.Table('Users')
    
    def create_user(self, user_data):
        """
        新規ユーザー作成
        """
        user_data['createdAt'] = datetime.utcnow().isoformat()
        user_data['updatedAt'] = datetime.utcnow().isoformat()
        
        try:
            self.table.put_item(
                Item=user_data,
                ConditionExpression='attribute_not_exists(userId)'
            )
            return user_data
        except ClientError as e:
            if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                raise ValueError('User already exists')
            raise
    
    def get_user(self, user_id):
        """
        ユーザー情報取得
        """
        response = self.table.get_item(Key={'userId': user_id})
        return response.get('Item')
    
    def update_user(self, user_id, updates):
        """
        ユーザー情報更新
        """
        updates['updatedAt'] = datetime.utcnow().isoformat()
        
        # DynamoDB の UpdateExpression を構築
        update_expression = "SET "
        expression_values = {}
        
        for key, value in updates.items():
            update_expression += f"{key} = :{key}, "
            expression_values[f":{key}"] = value
        
        update_expression = update_expression.rstrip(', ')
        
        return self.table.update_item(
            Key={'userId': user_id},
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_values,
            ReturnValues='ALL_NEW'
        )
```

## 🔄 データフローの例

### ユーザープロフィール表示の完全フロー

```
1. ユーザーがWebページにアクセス
   ┌─────────────────────────────────┐
   │ユーザー → CloudFront → S3       │ プレゼンテーション層
   │(React SPA を取得)                │
   └─────────────────────────────────┘
                    ↓

2. 認証されたAPI呼び出し
   ┌─────────────────────────────────┐
   │ブラウザ → API Gateway           │ 
   │(JWT token 付きでGETリクエスト)    │
   └─────────────────────────────────┘
                    ↓

3. ビジネスロジック実行
   ┌─────────────────────────────────┐
   │API Gateway → Lambda             │ アプリケーション層
   │→ Cognito (認証検証)             │
   │→ ビジネスロジック実行             │
   └─────────────────────────────────┘
                    ↓

4. データ取得
   ┌─────────────────────────────────┐
   │Lambda → DynamoDB                │ データ層
   │(ユーザーデータ取得)               │
   └─────────────────────────────────┘
                    ↓

5. レスポンス返却
   ┌─────────────────────────────────┐
   │DynamoDB → Lambda → API Gateway  │
   │→ ブラウザ (JSON レスポンス)       │
   └─────────────────────────────────┘
                    ↓

6. UI更新
   ┌─────────────────────────────────┐
   │React コンポーネントがデータ表示   │ プレゼンテーション層
   └─────────────────────────────────┘
```

## 🎯 三層アーキテクチャの利点

### 1. **関心の分離 (Separation of Concerns)**
- 各層が独立した責任を持つ
- 一つの層の変更が他の層に影響しにくい
- 専門分野ごとの開発が可能

### 2. **スケーラビリティ**
- 各層を独立してスケール可能
- ボトルネックとなる層のみ強化可能
- マイクロサービス化への移行が容易

### 3. **保守性**
- コードの役割が明確
- バグの影響範囲を限定化
- テストが書きやすい

### 4. **再利用性**
- APIを複数のフロントエンドで利用可能
- データ層は複数のアプリケーションから利用可能
- コンポーネントの再利用が促進

## 🚀 AWS での実装メリット

### **サーバーレス化による利点**

```yaml
従来の三層アーキテクチャ:
  プレゼンテーション: Webサーバー (Apache/Nginx)
  アプリケーション: アプリサーバー (Tomcat/Express)
  データ: データベースサーバー (MySQL/PostgreSQL)

AWS サーバーレス三層アーキテクチャ:
  プレゼンテーション: S3 + CloudFront
  アプリケーション: API Gateway + Lambda
  データ: DynamoDB / RDS Serverless
```

**メリット**:
- **コスト効率**: 使用分のみ課金
- **自動スケーリング**: トラフィック増加に自動対応
- **運用負荷軽減**: サーバー管理不要
- **高可用性**: AWSが自動的に冗長化
- **セキュリティ**: AWS のマネージドセキュリティ

## 🔧 実装時のベストプラクティス

### 1. **API 設計**
```http
# RESTful API 設計例
GET    /api/users/{id}      # ユーザー取得
POST   /api/users          # ユーザー作成
PUT    /api/users/{id}     # ユーザー更新
DELETE /api/users/{id}     # ユーザー削除

# エラーレスポンス統一
{
  "error": {
    "code": "USER_NOT_FOUND",
    "message": "指定されたユーザーが見つかりません",
    "details": {
      "userId": "user123"
    }
  }
}
```

### 2. **セキュリティ**
```yaml
プレゼンテーション層:
  - HTTPS通信の強制
  - CSP (Content Security Policy) 設定
  - XSS対策

アプリケーション層:
  - JWT トークン検証
  - API Rate Limiting
  - 入力値検証とサニタイゼーション

データ層:
  - 暗号化 (保存時・転送時)
  - アクセス制御 (IAM)
  - 監査ログ
```

### 3. **パフォーマンス最適化**
```yaml
プレゼンテーション層:
  - CDN キャッシュ戦略
  - 画像・JS・CSS の圧縮
  - Lazy Loading

アプリケーション層:
  - Lambda Cold Start 対策
  - API レスポンスキャッシュ
  - 並列処理の活用

データ層:
  - DynamoDB インデックス設計
  - クエリ最適化
  - キャッシュ戦略 (ElastiCache)
```

## 📚 学習の進め方

### **段階的な学習アプローチ**

```
Phase 1: 基礎理解 (2.1-2.2)
├── 静的サイトをS3で配信
├── 基本的なAPI作成
└── 三層の概念理解

Phase 2: 認証追加 (2.3)
├── Cognito User Pool 設定
├── JWT認証の実装
└── セキュリティ強化

Phase 3: データ管理 (2.4)
├── DynamoDB 基礎
├── CRUD操作実装
└── データ設計パターン

Phase 4: 統合 (2.5)
├── 全層の統合
├── エラーハンドリング
└── ユーザー体験向上
```

### **実践的な課題**

1. **TODOアプリの構築**
   - ユーザー登録・ログイン
   - TODOの作成・更新・削除
   - リアルタイム同期

2. **ブログシステム**
   - 記事の投稿・編集
   - コメント機能
   - ファイルアップロード

3. **ECサイトの基礎**
   - 商品カタログ
   - ショッピングカート
   - 注文管理

## 🎓 まとめ

Web三層アーキテクチャは、現代のWebアプリケーション開発における基本中の基本です。AWSのサーバーレスサービスを活用することで、従来よりも簡単に、かつ高性能・高可用性なシステムを構築できます。

このガイドを参考に、実際に手を動かしながら三層アーキテクチャの理解を深めていきましょう！

---

**次のステップ**: [2.1-静的サイト構築](../2.1-静的サイト構築/README.md) から実際の構築を始めましょう。