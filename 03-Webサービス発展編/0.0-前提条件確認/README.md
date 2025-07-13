# 0.0-前提条件確認

03-Webサービス発展編を始める前に、前提条件を確認し開発環境を準備します。

## 学習目標

- 02-Webアプリケーション基礎編の完了確認
- 開発環境の準備
- 必要なツールとライブラリの確認

## 前提条件チェック

### 1. 前モジュール完了確認

以下が完了していることを確認してください：

**02-Webアプリケーション基礎編の成果物:**
- ✅ Lambda関数の動作確認
- ✅ API Gatewayの動作確認
- ✅ DynamoDBテーブルの作成
- ✅ 簡単なWebページの表示
- ✅ CloudFormationスタックの作成

**確認コマンド:**
```bash
# AWSプロファイル確認
aws sts get-caller-identity

# 既存スタック確認
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE

# DynamoDBテーブル確認
aws dynamodb list-tables
```

### 2. 開発環境確認

**必要なソフトウェア:**
- ✅ Node.js 18.x以上
- ✅ npm または yarn
- ✅ Git
- ✅ AWS CLI v2
- ✅ Visual Studio Code (推奨)

**確認コマンド:**
```bash
# Node.js バージョン確認
node --version
# 18.0.0以上であることを確認

# npm バージョン確認
npm --version

# AWS CLI確認
aws --version

# Git確認
git --version
```

### 3. AWS設定確認

**IAM権限確認:**
```bash
# 権限テスト
aws iam get-user
aws lambda list-functions --max-items 1
aws apigateway get-rest-apis --limit 1
aws dynamodb list-tables --limit 1
aws s3 ls
aws rds describe-db-instances --max-records 1
```

**リージョン設定:**
```bash
# デフォルトリージョン確認
aws configure get region
# ap-northeast-1 (東京リージョン) 推奨
```

## 開発環境セットアップ

### 1. プロジェクトディレクトリ作成

```bash
# プロジェクトフォルダ作成
mkdir sns-web-app
cd sns-web-app

# ディレクトリ構造作成
mkdir -p {frontend,backend,infrastructure,docs}
```

### 2. Node.js プロジェクト初期化

```bash
# バックエンド初期化
cd backend
npm init -y

# 基本依存関係インストール
npm install express cors helmet morgan compression
npm install aws-sdk multer jsonwebtoken bcryptjs
npm install --save-dev nodemon jest supertest

# フロントエンド初期化
cd ../frontend
npm init -y
npm install react react-dom react-router-dom axios
npm install bootstrap react-bootstrap
npm install --save-dev @vitejs/plugin-react vite
```

### 3. 開発ツール設定

**VS Code拡張機能 (推奨):**
- AWS Toolkit
- ES7+ React/Redux/React-Native snippets
- Prettier - Code formatter
- ESLint
- GitLens
- Thunder Client (API testing)

**package.json スクリプト設定:**

```json
{
  "scripts": {
    "dev": "nodemon server.js",
    "start": "node server.js",
    "test": "jest",
    "build": "vite build",
    "preview": "vite preview"
  }
}
```

### 4. 環境設定ファイル

**.env.example:**
```env
# AWS設定
AWS_REGION=ap-northeast-1
AWS_PROFILE=default

# データベース設定
DYNAMODB_TABLE_POSTS=sns-posts
DYNAMODB_TABLE_USERS=sns-users

# S3設定
S3_BUCKET_NAME=sns-media-bucket
CLOUDFRONT_DOMAIN=your-cloudfront-domain

# API設定
API_BASE_URL=https://your-api-gateway-url
JWT_SECRET=your-jwt-secret

# 開発環境設定
NODE_ENV=development
PORT=3000
```

### 5. Git設定

```bash
# Git初期化
git init
git add .
git commit -m "Initial project setup"

# .gitignore設定
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
npm-debug.log*

# Environment variables
.env
.env.local
.env.production

# Build outputs
dist/
build/

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# AWS
.aws/

# Logs
logs/
*.log
EOF
```

## 前提知識確認

### JavaScript/Node.js
- ✅ ES6+ シンタックス (async/await, arrow functions, destructuring)
- ✅ Promise と非同期処理
- ✅ Express.js 基礎
- ✅ REST API 概念

### React.js
- ✅ コンポーネント作成
- ✅ useState, useEffect フック
- ✅ イベントハンドリング
- ✅ 条件付きレンダリング

### AWS サービス
- ✅ Lambda 基礎
- ✅ API Gateway 基礎
- ✅ DynamoDB 基礎
- ✅ S3 基礎概念
- ✅ CloudFormation 基礎

## 確認テスト

### 1. 簡単なExpressアプリ作成

```javascript
// test-server.js
const express = require('express');
const app = express();
const port = 3000;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'Server is running' });
});

app.listen(port, () => {
  console.log(`Test server running on port ${port}`);
});
```

**実行確認:**
```bash
node test-server.js
curl http://localhost:3000/health
```

### 2. AWS接続テスト

```javascript
// test-aws.js
const AWS = require('aws-sdk');

// DynamoDB接続テスト
const dynamodb = new AWS.DynamoDB.DocumentClient();

async function testDynamoDB() {
  try {
    const result = await dynamodb.scan({
      TableName: 'your-existing-table',
      Limit: 1
    }).promise();
    console.log('DynamoDB connection: OK');
  } catch (error) {
    console.log('DynamoDB connection: Failed', error.message);
  }
}

testDynamoDB();
```

### 3. 簡単なReactコンポーネント

```jsx
// TestComponent.jsx
import React, { useState } from 'react';

function TestComponent() {
  const [count, setCount] = useState(0);

  return (
    <div>
      <h1>Count: {count}</h1>
      <button onClick={() => setCount(count + 1)}>
        Increment
      </button>
    </div>
  );
}

export default TestComponent;
```

## チェックリスト

学習を開始する前に、以下がすべて完了していることを確認してください：

### 環境設定
- [ ] Node.js 18.x以上がインストール済み
- [ ] AWS CLI v2が設定済み
- [ ] 必要なIAM権限が付与済み
- [ ] 02モジュールのリソースが作成済み

### プロジェクト準備
- [ ] プロジェクトディレクトリが作成済み
- [ ] package.jsonが設定済み
- [ ] 基本的な依存関係がインストール済み
- [ ] 環境変数ファイルが準備済み

### 知識確認
- [ ] JavaScript ES6+の基本構文を理解
- [ ] React.jsの基本概念を理解
- [ ] REST APIの概念を理解
- [ ] AWS基本サービスを理解

### 動作確認
- [ ] 簡単なExpressサーバーが起動できる
- [ ] AWS SDKでリソースにアクセスできる
- [ ] Reactコンポーネントが作成できる

## トラブルシューティング

### よくある問題

**1. Node.jsバージョンが古い**
```bash
# nvm使用してNode.js更新
nvm install 18
nvm use 18
```

**2. AWS認証エラー**
```bash
# プロファイル再設定
aws configure
# または
aws configure --profile your-profile
```

**3. 権限エラー**
```bash
# 現在の権限確認
aws iam get-user
aws sts get-caller-identity
```

**4. ポート競合**
```bash
# 使用中ポート確認
lsof -i :3000
# プロセス終了
kill -9 <PID>
```

## 次のステップ

すべての前提条件が確認できたら、**3.1-CRUD機能実装**に進みます。

このセクションでは、投稿システムの基本的なCRUD操作を実装し、SNS風アプリケーションの基盤を構築します。

## 学習時間: 30分

- 環境確認: 10分
- セットアップ: 15分
- 動作テスト: 5分