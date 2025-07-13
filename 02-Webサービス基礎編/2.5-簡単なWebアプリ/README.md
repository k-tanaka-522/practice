# 2.5 簡単なWebアプリ

## 🎯 学習目標

**React フロントエンドとAWSサービスの統合**により、完全に機能するWebアプリケーションを構築し、Web開発の全体像を理解します。

### このセクションで学ぶこと

1. **React アプリケーション構築**: コンポーネント設計とstate管理
2. **AWS SDK統合**: Cognito、API Gateway、S3との連携
3. **認証フロー実装**: ログイン・ログアウト・ユーザー状態管理
4. **CRUD機能統合**: データベース操作をUIに反映
5. **デプロイメント**: S3 + CloudFront での本番環境構築

## ⏰ 所要時間
**約1.5時間**

```
設計・準備     [20分] → React アプリ設計とコンポーネント構成
実装・統合     [50分] → フロントエンド開発とAWS連携
デプロイ・確認  [20分] → 本番デプロイと動作確認
```

## 📋 前提条件

- 2.4-データベース基礎の完了
- React の基本知識
- JavaScript ES6+ の理解
- npm/yarn の基本操作

## 🏗️ 構築するアーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                      User Browser                              │
└─────────────────────┬───────────────────────────────────────────┘
                      │ HTTPS
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                   CloudFront CDN                               │
│                   (Global Distribution)                        │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                     S3 Bucket                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │    React    │  │    CSS      │  │   Assets    │             │
│  │ App Bundle  │  │   Styles    │  │   Images    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Integrated Services                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Cognito   │  │ API Gateway │  │  DynamoDB   │             │
│  │    Auth     │  │   + Lambda  │  │   Database  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

## 📦 実装する機能

### 1. React アプリケーション構成

**主要コンポーネント**:
- `App.js`: ルートコンポーネント、認証状態管理
- `Auth/Login.js`: ログインフォーム
- `Auth/Signup.js`: ユーザー登録フォーム
- `Dashboard/Dashboard.js`: メインダッシュボード
- `Items/ItemList.js`: アイテム一覧表示
- `Items/ItemForm.js`: アイテム作成・編集フォーム

**状態管理**:
- React Context for 認証状態
- useState/useEffect for ローカル状態
- カスタムフック for API呼び出し

### 2. 機能一覧

- **認証機能**: サインアップ、ログイン、ログアウト
- **ダッシュボード**: ユーザー情報表示、統計情報
- **アイテム管理**: CRUD操作のUI実装
- **レスポンシブデザイン**: モバイル対応

### 3. AWS SDK 統合

- **@aws-sdk/client-cognito-identity-provider**: 認証
- **API呼び出し**: fetch API with JWT
- **エラーハンドリング**: 適切なエラー表示

## 🛠️ 実装手順

### Step 1: React アプリケーション初期化

```bash
# 作業ディレクトリに移動
cd 2.5-簡単なWebアプリ

# React アプリケーションの作成
npx create-react-app todo-app
cd todo-app

# 必要なライブラリのインストール
npm install @aws-sdk/client-cognito-identity-provider \
  react-router-dom \
  bootstrap \
  react-bootstrap
```

### Step 2: プロジェクト構成の確認

```bash
# プロジェクト構成
src/
├── components/
│   ├── Auth/
│   │   ├── Login.js
│   │   ├── Signup.js
│   │   └── AuthContext.js
│   ├── Dashboard/
│   │   └── Dashboard.js
│   ├── Items/
│   │   ├── ItemList.js
│   │   ├── ItemForm.js
│   │   └── ItemCard.js
│   └── Layout/
│       ├── Header.js
│       └── Navigation.js
├── services/
│   ├── authService.js
│   ├── apiService.js
│   └── config.js
├── hooks/
│   ├── useAuth.js
│   └── useItems.js
└── App.js
```

### Step 3: AWS設定ファイルの作成

```javascript
// src/services/config.js
export const AWS_CONFIG = {
  region: 'us-east-1',
  userPoolId: 'YOUR_USER_POOL_ID',
  userPoolClientId: 'YOUR_USER_POOL_CLIENT_ID',
  apiBaseUrl: 'https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/dev'
};
```

### Step 4: アプリケーションの開発

```bash
# 開発サーバーの起動
npm start

# ブラウザで http://localhost:3000 を開く
```

## 💻 React コンポーネント実装例

### 1. 認証コンテキスト

```javascript
// src/components/Auth/AuthContext.js
import React, { createContext, useContext, useState, useEffect } from 'react';
import { authService } from '../../services/authService';

const AuthContext = createContext();

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const initAuth = async () => {
      try {
        const tokens = authService.getTokens();
        if (tokens) {
          const userInfo = await authService.getCurrentUser();
          setUser(userInfo);
        }
      } catch (error) {
        console.error('Auth initialization error:', error);
        authService.clearTokens();
      } finally {
        setLoading(false);
      }
    };

    initAuth();
  }, []);

  const login = async (email, password) => {
    try {
      setError(null);
      setLoading(true);
      const response = await authService.signIn(email, password);
      setUser(response.user);
      return response;
    } catch (error) {
      setError(error.message);
      throw error;
    } finally {
      setLoading(false);
    }
  };

  const signup = async (email, password, name) => {
    try {
      setError(null);
      setLoading(true);
      const response = await authService.signUp(email, password, name);
      return response;
    } catch (error) {
      setError(error.message);
      throw error;
    } finally {
      setLoading(false);
    }
  };

  const logout = () => {
    authService.signOut();
    setUser(null);
  };

  const value = {
    user,
    login,
    signup,
    logout,
    loading,
    error,
    isAuthenticated: !!user
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
```

### 2. ログインコンポーネント

```javascript
// src/components/Auth/Login.js
import React, { useState } from 'react';
import { Form, Button, Alert, Container, Card } from 'react-bootstrap';
import { useAuth } from './AuthContext';
import { useNavigate } from 'react-router-dom';

const Login = () => {
  const [formData, setFormData] = useState({
    email: '',
    password: ''
  });
  const [localError, setLocalError] = useState('');
  
  const { login, loading, error } = useAuth();
  const navigate = useNavigate();

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLocalError('');

    if (!formData.email || !formData.password) {
      setLocalError('Please fill in all fields');
      return;
    }

    try {
      await login(formData.email, formData.password);
      navigate('/dashboard');
    } catch (error) {
      setLocalError(error.message);
    }
  };

  return (
    <Container className="d-flex justify-content-center align-items-center min-vh-100">
      <Card style={{ width: '400px' }}>
        <Card.Body>
          <Card.Title className="text-center mb-4">ログイン</Card.Title>
          
          {(error || localError) && (
            <Alert variant="danger">
              {error || localError}
            </Alert>
          )}

          <Form onSubmit={handleSubmit}>
            <Form.Group className="mb-3">
              <Form.Label>メールアドレス</Form.Label>
              <Form.Control
                type="email"
                name="email"
                value={formData.email}
                onChange={handleChange}
                required
                placeholder="email@example.com"
              />
            </Form.Group>

            <Form.Group className="mb-3">
              <Form.Label>パスワード</Form.Label>
              <Form.Control
                type="password"
                name="password"
                value={formData.password}
                onChange={handleChange}
                required
                placeholder="パスワードを入力"
              />
            </Form.Group>

            <Button 
              variant="primary" 
              type="submit" 
              className="w-100"
              disabled={loading}
            >
              {loading ? 'ログイン中...' : 'ログイン'}
            </Button>
          </Form>

          <div className="text-center mt-3">
            <p>アカウントをお持ちでない方は <a href="/signup">こちら</a></p>
          </div>
        </Card.Body>
      </Card>
    </Container>
  );
};

export default Login;
```

### 3. アイテム一覧コンポーネント

```javascript
// src/components/Items/ItemList.js
import React, { useState, useEffect } from 'react';
import { Container, Row, Col, Button, Alert, Spinner } from 'react-bootstrap';
import ItemCard from './ItemCard';
import ItemForm from './ItemForm';
import { apiService } from '../../services/apiService';

const ItemList = () => {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [editingItem, setEditingItem] = useState(null);

  useEffect(() => {
    loadItems();
  }, []);

  const loadItems = async () => {
    try {
      setLoading(true);
      setError('');
      const response = await apiService.getItems();
      setItems(response.items || []);
    } catch (error) {
      setError('アイテムの読み込みに失敗しました');
      console.error('Load items error:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateItem = async (itemData) => {
    try {
      const response = await apiService.createItem(itemData);
      setItems([response.item, ...items]);
      setShowForm(false);
    } catch (error) {
      throw new Error('アイテムの作成に失敗しました');
    }
  };

  const handleUpdateItem = async (itemId, itemData) => {
    try {
      const response = await apiService.updateItem(itemId, itemData);
      setItems(items.map(item => 
        item.itemId === itemId ? response.item : item
      ));
      setEditingItem(null);
    } catch (error) {
      throw new Error('アイテムの更新に失敗しました');
    }
  };

  const handleDeleteItem = async (itemId) => {
    if (!window.confirm('このアイテムを削除しますか？')) {
      return;
    }

    try {
      await apiService.deleteItem(itemId);
      setItems(items.filter(item => item.itemId !== itemId));
    } catch (error) {
      setError('アイテムの削除に失敗しました');
    }
  };

  const handleEdit = (item) => {
    setEditingItem(item);
    setShowForm(true);
  };

  const handleCancelEdit = () => {
    setEditingItem(null);
    setShowForm(false);
  };

  if (loading) {
    return (
      <Container className="text-center mt-5">
        <Spinner animation="border" role="status">
          <span className="visually-hidden">読み込み中...</span>
        </Spinner>
      </Container>
    );
  }

  return (
    <Container className="mt-4">
      <Row className="mb-4">
        <Col>
          <div className="d-flex justify-content-between align-items-center">
            <h2>マイアイテム</h2>
            <Button 
              variant="primary" 
              onClick={() => setShowForm(true)}
              disabled={showForm}
            >
              新規作成
            </Button>
          </div>
        </Col>
      </Row>

      {error && (
        <Alert variant="danger" className="mb-4">
          {error}
        </Alert>
      )}

      {showForm && (
        <Row className="mb-4">
          <Col>
            <ItemForm
              item={editingItem}
              onSubmit={editingItem ? 
                (data) => handleUpdateItem(editingItem.itemId, data) : 
                handleCreateItem
              }
              onCancel={handleCancelEdit}
            />
          </Col>
        </Row>
      )}

      <Row>
        {items.length === 0 ? (
          <Col>
            <Alert variant="info" className="text-center">
              アイテムがありません。新規作成ボタンから作成してください。
            </Alert>
          </Col>
        ) : (
          items.map(item => (
            <Col key={item.itemId} md={6} lg={4} className="mb-3">
              <ItemCard
                item={item}
                onEdit={() => handleEdit(item)}
                onDelete={() => handleDeleteItem(item.itemId)}
              />
            </Col>
          ))
        )}
      </Row>
    </Container>
  );
};

export default ItemList;
```

### 4. API サービス

```javascript
// src/services/apiService.js
import { authService } from './authService';
import { AWS_CONFIG } from './config';

class ApiService {
  constructor() {
    this.baseURL = AWS_CONFIG.apiBaseUrl;
  }

  async makeRequest(endpoint, options = {}) {
    const tokens = authService.getTokens();
    
    if (!tokens) {
      throw new Error('認証が必要です');
    }

    const url = `${this.baseURL}${endpoint}`;
    const config = {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${tokens.accessToken}`,
      },
      ...options,
    };

    try {
      const response = await fetch(url, config);
      
      if (response.status === 401) {
        // トークンが無効な場合
        authService.clearTokens();
        window.location.href = '/login';
        throw new Error('認証が無効です');
      }

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('API request error:', error);
      throw error;
    }
  }

  // アイテム関連API
  async getItems(params = {}) {
    const queryString = new URLSearchParams(params).toString();
    const endpoint = `/api/items${queryString ? `?${queryString}` : ''}`;
    return this.makeRequest(endpoint);
  }

  async createItem(itemData) {
    return this.makeRequest('/api/items', {
      method: 'POST',
      body: JSON.stringify(itemData),
    });
  }

  async updateItem(itemId, itemData) {
    return this.makeRequest(`/api/items/${itemId}`, {
      method: 'PUT',
      body: JSON.stringify(itemData),
    });
  }

  async deleteItem(itemId) {
    return this.makeRequest(`/api/items/${itemId}`, {
      method: 'DELETE',
    });
  }

  async getItem(itemId) {
    return this.makeRequest(`/api/items/${itemId}`);
  }
}

export const apiService = new ApiService();
```

## 📁 ファイル構成

```
2.5-簡単なWebアプリ/
├── README.md
├── todo-app/
│   ├── public/
│   │   ├── index.html
│   │   └── favicon.ico
│   ├── src/
│   │   ├── components/
│   │   │   ├── Auth/
│   │   │   │   ├── AuthContext.js
│   │   │   │   ├── Login.js
│   │   │   │   ├── Signup.js
│   │   │   │   └── ProtectedRoute.js
│   │   │   ├── Dashboard/
│   │   │   │   └── Dashboard.js
│   │   │   ├── Items/
│   │   │   │   ├── ItemList.js
│   │   │   │   ├── ItemForm.js
│   │   │   │   └── ItemCard.js
│   │   │   └── Layout/
│   │   │       ├── Header.js
│   │   │       └── Navigation.js
│   │   ├── services/
│   │   │   ├── authService.js
│   │   │   ├── apiService.js
│   │   │   └── config.js
│   │   ├── hooks/
│   │   │   ├── useAuth.js
│   │   │   └── useItems.js
│   │   ├── App.js
│   │   ├── App.css
│   │   └── index.js
│   ├── package.json
│   └── .env
├── cloudformation/
│   ├── main-stack.yaml
│   └── templates/
│       └── s3-hosting.yaml
└── docs/
    ├── deployment-guide.md
    └── user-guide.md
```

## 🚀 デプロイメント手順

### Step 1: プロダクションビルド

```bash
# Reactアプリのビルド
cd todo-app
npm run build

# ビルド成果物の確認
ls build/
```

### Step 2: S3バケットの準備

```bash
# S3バケットの作成（既存の静的サイトバケットを使用）
aws s3 cp build/ s3://your-website-bucket/ --recursive

# CloudFrontキャッシュの無効化
aws cloudfront create-invalidation \
  --distribution-id YOUR_DISTRIBUTION_ID \
  --paths "/*"
```

### Step 3: 本番環境での動作確認

```bash
# Webサイトへのアクセス
curl https://your-domain.com

# API エンドポイントの確認
curl https://your-api-domain/dev/api/items
```

## 🧪 統合テスト

### 1. ユーザージャーニーテスト

1. **新規ユーザー登録**
   - サインアップフォームの入力
   - メール確認の完了
   - 初回ログイン

2. **アイテム管理**
   - アイテムの作成
   - アイテム一覧の表示
   - アイテムの編集・削除

3. **認証フロー**
   - ログアウト・再ログイン
   - 保護されたページへのアクセス
   - セッション管理

### 2. レスポンシブテスト

```css
/* モバイル対応確認 */
@media (max-width: 768px) {
  .item-card {
    margin-bottom: 1rem;
  }
  
  .dashboard-stats {
    flex-direction: column;
  }
}
```

### 3. パフォーマンステスト

```javascript
// React DevTools Profilerでの測定
import { Profiler } from 'react';

const onRenderCallback = (id, phase, actualDuration) => {
  console.log('Component:', id, 'Phase:', phase, 'Duration:', actualDuration);
};

<Profiler id="ItemList" onRender={onRenderCallback}>
  <ItemList />
</Profiler>
```

## 📊 アプリケーション機能

### 1. 実装済み機能

- ✅ **ユーザー認証**: サインアップ・ログイン・ログアウト
- ✅ **アイテム管理**: CRUD操作の完全実装
- ✅ **レスポンシブデザイン**: モバイル・タブレット対応
- ✅ **エラーハンドリング**: 適切なエラー表示とユーザーフィードバック
- ✅ **ローディング状態**: 非同期処理の視覚的フィードバック

### 2. 今後の拡張ポイント

- 🔄 **リアルタイム更新**: WebSocket or SSE
- 📸 **ファイルアップロード**: S3 presigned URL
- 🔍 **検索・フィルタ**: 高度な検索機能
- 📱 **PWA対応**: オフライン機能、プッシュ通知
- 🎨 **UI/UX改善**: アニメーション、テーマ切り替え

## 💰 コスト試算

### 月間利用想定
- ユーザー数: 100人
- ページビュー: 10,000回/月
- データ転送: 1GB/月

### 予想コスト
```
S3 ホスティング: $0.50
CloudFront: $1.00
DynamoDB: $1.75
API Gateway + Lambda: $5.25
Cognito: $0.55

合計: 約 $9.05/月
```

## 🚀 完成した成果物

このセクションの完了により、以下が完成します：

### **フルスタックWebアプリケーション**

1. **フロントエンド**: React SPA
   - モダンなUI/UX
   - レスポンシブデザイン
   - 認証機能統合

2. **バックエンド**: サーバーレスAPI
   - REST API (API Gateway + Lambda)
   - ユーザー認証 (Cognito)
   - データ永続化 (DynamoDB)

3. **インフラストラクチャ**: CloudFormation
   - Infrastructure as Code
   - 環境分離 (dev/prod)
   - 自動デプロイメント

### **獲得スキル**

- ✅ Web三層アーキテクチャの理解
- ✅ サーバーレス開発の基礎
- ✅ AWS主要サービスの実践的利用
- ✅ 認証・認可の実装
- ✅ NoSQLデータベース設計
- ✅ フロントエンド・バックエンド連携

## 🧹 リソースのクリーンアップ

学習完了後、以下のコマンドでリソースを削除：

```bash
# 全てのCloudFormationスタックの削除
aws cloudformation delete-stack --stack-name database-basics
aws cloudformation delete-stack --stack-name auth-system
aws cloudformation delete-stack --stack-name api-foundation

# S3バケットの中身を削除
aws s3 rm s3://your-website-bucket/ --recursive
aws s3 rm s3://your-cf-bucket/ --recursive

# バケット自体の削除
aws s3 rb s3://your-website-bucket/
aws s3 rb s3://your-cf-bucket/
```

## 📚 参考資料

- [React Documentation](https://reactjs.org/docs/)
- [AWS SDK for JavaScript](https://docs.aws.amazon.com/sdk-for-javascript/)
- [React Bootstrap](https://react-bootstrap.github.io/)
- [Create React App](https://create-react-app.dev/)
- [AWS Amplify for Frontend](https://docs.amplify.aws/)

## 🎉 完了おめでとうございます！

**02-Webサービス基礎編の全セクションが完了しました！**

### 次のステップ

1. **03-CRUD システム実装編**: より複雑なWebアプリケーションの構築
2. **ポートフォリオプロジェクト**: 学習したスキルを活用した独自プロジェクト
3. **AWS認定資格**: AWS Developer Associate の挑戦

---

**🎯 目標達成**: Web開発の基礎をマスターし、実際に動作するWebアプリケーションの構築完了！