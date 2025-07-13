# 3.5-本格的なWebアプリ

これまでに実装した全機能を統合し、UI/UXを改善して完全なSNS風Webアプリケーションを完成させます。

## 学習目標

- 全機能の統合とテスト
- UI/UXの最適化
- パフォーマンス改善
- セキュリティ強化
- 本番運用への準備

## 最終成果物

### 機能一覧
- ✅ ユーザー認証・プロフィール管理
- ✅ 投稿作成・編集・削除 (CRUD)
- ✅ 画像アップロード・表示
- ✅ いいね・コメント機能
- ✅ フォロー・フォロワー機能
- ✅ リアルタイム通知
- ✅ タイムライン表示
- ✅ 検索機能
- ✅ レスポンシブデザイン

### 技術スタック
- **フロントエンド**: React.js, Bootstrap, WebSocket
- **バックエンド**: AWS Lambda, Node.js
- **データベース**: DynamoDB, PostgreSQL
- **ストレージ**: S3, CloudFront
- **リアルタイム**: API Gateway WebSocket
- **インフラ**: CloudFormation, VPC

## 実装手順

### Step 1: アプリケーション統合

#### 1-1. 統合プロジェクト構造
```
sns-web-app/
├── frontend/
│   ├── public/
│   │   ├── index.html
│   │   ├── manifest.json
│   │   └── sw.js (Service Worker)
│   ├── src/
│   │   ├── components/
│   │   │   ├── common/
│   │   │   ├── auth/
│   │   │   ├── posts/
│   │   │   ├── users/
│   │   │   └── notifications/
│   │   ├── pages/
│   │   ├── services/
│   │   ├── hooks/
│   │   ├── contexts/
│   │   ├── utils/
│   │   └── styles/
│   ├── package.json
│   └── Dockerfile
├── backend/
│   ├── src/
│   │   ├── auth/
│   │   ├── posts/
│   │   ├── users/
│   │   ├── upload/
│   │   ├── websocket/
│   │   ├── shared/
│   │   └── config/
│   ├── tests/
│   ├── package.json
│   └── Dockerfile
├── infrastructure/
│   ├── main.yaml (メインスタック)
│   ├── network.yaml
│   ├── database.yaml
│   ├── api.yaml
│   └── frontend.yaml
├── scripts/
│   ├── deploy.sh
│   ├── test.sh
│   └── seed-data.js
├── docs/
│   ├── API.md
│   ├── DEPLOYMENT.md
│   └── USER_GUIDE.md
└── docker-compose.yml
```

#### 1-2. メインアプリケーションコンポーネント

```jsx
// frontend/src/App.jsx
import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Container } from 'react-bootstrap';
import { AuthProvider } from './contexts/AuthContext';
import { WebSocketProvider } from './contexts/WebSocketContext';
import { NotificationProvider } from './contexts/NotificationContext';
import NavigationBar from './components/common/NavigationBar';
import Home from './pages/Home';
import Profile from './pages/Profile';
import Login from './pages/Login';
import Register from './pages/Register';
import Settings from './pages/Settings';
import NotFound from './pages/NotFound';
import LoadingSpinner from './components/common/LoadingSpinner';
import './styles/App.css';

function App() {
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // アプリケーション初期化
    initializeApp();
  }, []);

  const initializeApp = async () => {
    try {
      // Service Worker登録（PWA対応）
      if ('serviceWorker' in navigator) {
        await navigator.serviceWorker.register('/sw.js');
      }

      // 通知権限要求
      if ('Notification' in window && Notification.permission === 'default') {
        await Notification.requestPermission();
      }

      // 初期化完了
      setIsLoading(false);
    } catch (error) {
      console.error('App initialization failed:', error);
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return <LoadingSpinner />;
  }

  return (
    <AuthProvider>
      <WebSocketProvider>
        <NotificationProvider>
          <Router>
            <div className="App">
              <NavigationBar />
              <Container className="main-content py-4">
                <Routes>
                  <Route path="/" element={<Home />} />
                  <Route path="/login" element={<Login />} />
                  <Route path="/register" element={<Register />} />
                  <Route path="/profile/:userId?" element={<Profile />} />
                  <Route path="/settings" element={<Settings />} />
                  <Route path="/404" element={<NotFound />} />
                  <Route path="*" element={<Navigate to="/404" replace />} />
                </Routes>
              </Container>
            </div>
          </Router>
        </NotificationProvider>
      </WebSocketProvider>
    </AuthProvider>
  );
}

export default App;
```

#### 1-3. 認証コンテキスト

```jsx
// frontend/src/contexts/AuthContext.jsx
import React, { createContext, useContext, useState, useEffect } from 'react';
import { authApi } from '../services/authApi';

const AuthContext = createContext();

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [token, setToken] = useState(localStorage.getItem('auth_token'));

  useEffect(() => {
    if (token) {
      loadCurrentUser();
    } else {
      setLoading(false);
    }
  }, [token]);

  const loadCurrentUser = async () => {
    try {
      const userData = await authApi.getCurrentUser();
      setUser(userData);
    } catch (error) {
      console.error('Failed to load current user:', error);
      logout();
    } finally {
      setLoading(false);
    }
  };

  const login = async (credentials) => {
    try {
      const { user: userData, token: authToken } = await authApi.login(credentials);
      
      setUser(userData);
      setToken(authToken);
      localStorage.setItem('auth_token', authToken);
      
      return userData;
    } catch (error) {
      throw error;
    }
  };

  const register = async (userData) => {
    try {
      const { user: newUser, token: authToken } = await authApi.register(userData);
      
      setUser(newUser);
      setToken(authToken);
      localStorage.setItem('auth_token', authToken);
      
      return newUser;
    } catch (error) {
      throw error;
    }
  };

  const logout = () => {
    setUser(null);
    setToken(null);
    localStorage.removeItem('auth_token');
  };

  const updateUser = (updatedUser) => {
    setUser(updatedUser);
  };

  const value = {
    user,
    login,
    register,
    logout,
    updateUser,
    isAuthenticated: !!user,
    loading
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
```

#### 1-4. ナビゲーションバー

```jsx
// frontend/src/components/common/NavigationBar.jsx
import React, { useState } from 'react';
import { Navbar, Nav, Container, Dropdown, Form, InputGroup, Button } from 'react-bootstrap';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import { useNotification } from '../../contexts/NotificationContext';
import NotificationCenter from '../notifications/NotificationCenter';
import SearchBar from './SearchBar';

const NavigationBar = () => {
  const { user, logout, isAuthenticated } = useAuth();
  const { unreadCount } = useNotification();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/');
  };

  return (
    <Navbar bg="white" expand="lg" className="border-bottom sticky-top">
      <Container>
        <Navbar.Brand as={Link} to="/" className="fw-bold text-primary">
          📱 SNS App
        </Navbar.Brand>

        <Navbar.Toggle aria-controls="basic-navbar-nav" />
        <Navbar.Collapse id="basic-navbar-nav">
          {/* 検索バー */}
          <div className="mx-auto" style={{ width: '300px' }}>
            <SearchBar />
          </div>

          <Nav className="ms-auto align-items-center">
            {isAuthenticated ? (
              <>
                {/* ホーム */}
                <Nav.Link as={Link} to="/" className="nav-icon">
                  🏠 Home
                </Nav.Link>

                {/* 通知 */}
                <NotificationCenter userId={user.userId} />

                {/* ユーザーメニュー */}
                <Dropdown align="end">
                  <Dropdown.Toggle variant="outline-secondary" className="d-flex align-items-center">
                    <img
                      src={user.avatarUrl || '/default-avatar.png'}
                      alt={user.displayName}
                      className="rounded-circle me-2"
                      width="32"
                      height="32"
                    />
                    {user.displayName || user.username}
                  </Dropdown.Toggle>

                  <Dropdown.Menu>
                    <Dropdown.Item as={Link} to={`/profile/${user.userId}`}>
                      👤 My Profile
                    </Dropdown.Item>
                    <Dropdown.Item as={Link} to="/settings">
                      ⚙️ Settings
                    </Dropdown.Item>
                    <Dropdown.Divider />
                    <Dropdown.Item onClick={handleLogout}>
                      🚪 Logout
                    </Dropdown.Item>
                  </Dropdown.Menu>
                </Dropdown>
              </>
            ) : (
              <>
                <Nav.Link as={Link} to="/login">
                  Login
                </Nav.Link>
                <Button as={Link} to="/register" variant="primary" size="sm">
                  Sign Up
                </Button>
              </>
            )}
          </Nav>
        </Navbar.Collapse>
      </Container>
    </Navbar>
  );
};

export default NavigationBar;
```

#### 1-5. ホームページ

```jsx
// frontend/src/pages/Home.jsx
import React, { useState, useEffect } from 'react';
import { Row, Col, Alert } from 'react-bootstrap';
import { useAuth } from '../contexts/AuthContext';
import PostForm from '../components/posts/PostForm';
import RealTimeFeed from '../components/posts/RealTimeFeed';
import TrendingSidebar from '../components/common/TrendingSidebar';
import WelcomeSection from '../components/common/WelcomeSection';
import { postApi } from '../services/postApi';

const Home = () => {
  const { user, isAuthenticated } = useAuth();
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (isAuthenticated) {
      loadTimeline();
    } else {
      loadPublicPosts();
    }
  }, [isAuthenticated]);

  const loadTimeline = async () => {
    try {
      setLoading(true);
      const timelinePosts = await postApi.getTimeline(user.userId);
      setPosts(timelinePosts);
    } catch (err) {
      setError('Failed to load timeline: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const loadPublicPosts = async () => {
    try {
      setLoading(true);
      const publicPosts = await postApi.getPublicPosts();
      setPosts(publicPosts);
    } catch (err) {
      setError('Failed to load posts: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handlePostCreated = (newPost) => {
    setPosts(prev => [newPost, ...prev]);
  };

  const handlePostsUpdate = () => {
    if (isAuthenticated) {
      loadTimeline();
    } else {
      loadPublicPosts();
    }
  };

  if (!isAuthenticated) {
    return <WelcomeSection onGetStarted={loadPublicPosts} />;
  }

  return (
    <Row>
      <Col lg={8}>
        {error && <Alert variant="danger">{error}</Alert>}
        
        {/* 投稿フォーム */}
        <PostForm 
          onPostCreated={handlePostCreated}
          currentUser={user}
        />

        {/* タイムライン */}
        <RealTimeFeed
          posts={posts}
          onPostsUpdate={handlePostsUpdate}
          currentUserId={user.userId}
          loading={loading}
        />
      </Col>

      <Col lg={4}>
        <TrendingSidebar />
      </Col>
    </Row>
  );
};

export default Home;
```

### Step 2: UI/UX改善

#### 2-1. カスタムCSSスタイル

```css
/* frontend/src/styles/App.css */
:root {
  --primary-color: #1da1f2;
  --secondary-color: #14171a;
  --background-color: #f7f9fa;
  --border-color: #e1e8ed;
  --text-color: #14171a;
  --text-muted: #657786;
  --success-color: #17bf63;
  --danger-color: #e0245e;
  --warning-color: #ffad1f;
}

/* グローバルスタイル */
body {
  background-color: var(--background-color);
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
  color: var(--text-color);
}

.main-content {
  min-height: calc(100vh - 76px);
}

/* カードスタイル */
.post-card {
  background: white;
  border: 1px solid var(--border-color);
  border-radius: 16px;
  transition: all 0.2s ease;
}

.post-card:hover {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

/* ボタンスタイル */
.btn-rounded {
  border-radius: 20px;
  font-weight: 600;
  padding: 8px 20px;
}

.btn-icon {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  border-radius: 50px;
  transition: all 0.2s ease;
}

.btn-icon:hover {
  transform: translateY(-1px);
}

/* ナビゲーション */
.nav-icon {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  border-radius: 20px;
  transition: background-color 0.2s ease;
}

.nav-icon:hover {
  background-color: var(--background-color);
}

/* 投稿スタイル */
.post-content {
  font-size: 1.1rem;
  line-height: 1.5;
  word-wrap: break-word;
}

.post-meta {
  color: var(--text-muted);
  font-size: 0.9rem;
}

.post-actions {
  display: flex;
  justify-content: space-around;
  padding: 8px 0;
  border-top: 1px solid var(--border-color);
  margin-top: 12px;
}

.post-action-btn {
  background: none;
  border: none;
  color: var(--text-muted);
  transition: color 0.2s ease;
  cursor: pointer;
}

.post-action-btn:hover {
  color: var(--primary-color);
}

.post-action-btn.liked {
  color: var(--danger-color);
}

/* 画像ギャラリー */
.image-gallery {
  display: grid;
  gap: 8px;
  margin: 12px 0;
  border-radius: 16px;
  overflow: hidden;
}

.image-gallery.single {
  grid-template-columns: 1fr;
}

.image-gallery.multiple {
  grid-template-columns: repeat(2, 1fr);
}

.gallery-image {
  width: 100%;
  height: 200px;
  object-fit: cover;
  cursor: pointer;
  transition: transform 0.2s ease;
}

.gallery-image:hover {
  transform: scale(1.02);
}

/* 通知スタイル */
.notification-item {
  padding: 12px;
  border-bottom: 1px solid var(--border-color);
  transition: background-color 0.2s ease;
}

.notification-item:hover {
  background-color: var(--background-color);
}

.notification-item.unread {
  background-color: rgba(29, 161, 242, 0.05);
  border-left: 3px solid var(--primary-color);
}

/* レスポンシブデザイン */
@media (max-width: 768px) {
  .main-content {
    padding: 0 12px;
  }
  
  .post-card {
    border-radius: 0;
    border-left: none;
    border-right: none;
  }
  
  .image-gallery.multiple {
    grid-template-columns: 1fr;
  }
}

/* アニメーション */
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}

.fade-in {
  animation: fadeIn 0.3s ease;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.pulse {
  animation: pulse 2s infinite;
}

/* ローディングスタイル */
.loading-skeleton {
  background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
  background-size: 200% 100%;
  animation: loading 1.5s infinite;
}

@keyframes loading {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

/* スクロールバー */
::-webkit-scrollbar {
  width: 6px;
}

::-webkit-scrollbar-track {
  background: var(--background-color);
}

::-webkit-scrollbar-thumb {
  background: var(--border-color);
  border-radius: 3px;
}

::-webkit-scrollbar-thumb:hover {
  background: var(--text-muted);
}
```

#### 2-2. レスポンシブコンポーネント

```jsx
// frontend/src/components/common/ResponsiveLayout.jsx
import React from 'react';
import { Container, Row, Col } from 'react-bootstrap';
import { useMediaQuery } from '../../hooks/useMediaQuery';

const ResponsiveLayout = ({ 
  leftSidebar, 
  mainContent, 
  rightSidebar, 
  showSidebars = true 
}) => {
  const isMobile = useMediaQuery('(max-width: 768px)');
  const isTablet = useMediaQuery('(max-width: 992px)');

  if (isMobile) {
    return (
      <Container fluid className="px-0">
        {mainContent}
      </Container>
    );
  }

  if (isTablet) {
    return (
      <Container>
        <Row>
          <Col lg={8}>
            {mainContent}
          </Col>
          <Col lg={4}>
            {rightSidebar}
          </Col>
        </Row>
      </Container>
    );
  }

  return (
    <Container>
      <Row>
        {showSidebars && leftSidebar && (
          <Col xl={3} lg={2} className="d-none d-lg-block">
            {leftSidebar}
          </Col>
        )}
        <Col xl={showSidebars ? 6 : 8} lg={showSidebars ? 8 : 10}>
          {mainContent}
        </Col>
        {showSidebars && rightSidebar && (
          <Col xl={3} lg={2} className="d-none d-lg-block">
            {rightSidebar}
          </Col>
        )}
      </Row>
    </Container>
  );
};

export default ResponsiveLayout;
```

### Step 3: パフォーマンス最適化

#### 3-1. React最適化

```jsx
// frontend/src/hooks/useVirtualScroll.js
import { useState, useEffect, useMemo } from 'react';

export const useVirtualScroll = (items, itemHeight, containerHeight) => {
  const [scrollTop, setScrollTop] = useState(0);

  const visibleItems = useMemo(() => {
    const startIndex = Math.floor(scrollTop / itemHeight);
    const endIndex = Math.min(
      startIndex + Math.ceil(containerHeight / itemHeight) + 1,
      items.length
    );

    return {
      startIndex,
      endIndex,
      items: items.slice(startIndex, endIndex),
      totalHeight: items.length * itemHeight,
      offsetY: startIndex * itemHeight
    };
  }, [items, itemHeight, containerHeight, scrollTop]);

  return {
    visibleItems,
    onScroll: (e) => setScrollTop(e.target.scrollTop)
  };
};
```

```jsx
// frontend/src/components/posts/VirtualizedPostList.jsx
import React, { useRef, useEffect } from 'react';
import { useVirtualScroll } from '../../hooks/useVirtualScroll';
import Post from './Post';

const VirtualizedPostList = ({ posts, currentUserId, onPostUpdate }) => {
  const containerRef = useRef();
  const ITEM_HEIGHT = 200; // 投稿の推定高さ
  const CONTAINER_HEIGHT = 600;

  const { visibleItems, onScroll } = useVirtualScroll(
    posts,
    ITEM_HEIGHT,
    CONTAINER_HEIGHT
  );

  return (
    <div
      ref={containerRef}
      style={{ height: CONTAINER_HEIGHT, overflow: 'auto' }}
      onScroll={onScroll}
    >
      <div style={{ height: visibleItems.totalHeight, position: 'relative' }}>
        <div
          style={{
            transform: `translateY(${visibleItems.offsetY}px)`,
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0
          }}
        >
          {visibleItems.items.map((post, index) => (
            <div key={post.postId} style={{ height: ITEM_HEIGHT }}>
              <Post
                post={post}
                currentUserId={currentUserId}
                onUpdate={onPostUpdate}
              />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default VirtualizedPostList;
```

#### 3-2. Service Worker (PWA対応)

```javascript
// frontend/public/sw.js
const CACHE_NAME = 'sns-app-v1';
const urlsToCache = [
  '/',
  '/static/js/bundle.js',
  '/static/css/main.css',
  '/default-avatar.png',
  '/manifest.json'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(urlsToCache))
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        // キャッシュがあれば返す
        if (response) {
          return response;
        }
        return fetch(event.request);
      }
    )
  );
});

// プッシュ通知処理
self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {};
  
  const options = {
    body: data.body || 'New notification',
    icon: '/notification-icon.png',
    badge: '/badge-icon.png',
    tag: data.tag || 'default',
    data: data.data || {}
  };

  event.waitUntil(
    self.registration.showNotification(data.title || 'SNS App', options)
  );
});

// 通知クリック処理
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  event.waitUntil(
    clients.openWindow(event.notification.data.url || '/')
  );
});
```

### Step 4: セキュリティ強化

#### 4-1. CSP (Content Security Policy)

```html
<!-- frontend/public/index.html -->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <link rel="icon" href="%PUBLIC_URL%/favicon.ico" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="theme-color" content="#1da1f2" />
  
  <!-- Security Headers -->
  <meta http-equiv="Content-Security-Policy" content="
    default-src 'self';
    script-src 'self' 'unsafe-inline' 'unsafe-eval' https://apis.google.com;
    style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
    font-src 'self' https://fonts.gstatic.com;
    img-src 'self' data: https:;
    connect-src 'self' wss: https:;
    frame-src 'self' https:;
    object-src 'none';
    base-uri 'self';
    form-action 'self';
  ">
  
  <meta name="description" content="SNS風Webアプリケーション" />
  <link rel="apple-touch-icon" href="%PUBLIC_URL%/logo192.png" />
  <link rel="manifest" href="%PUBLIC_URL%/manifest.json" />
  
  <title>SNS App</title>
</head>
<body>
  <noscript>このアプリケーションを実行するにはJavaScriptが必要です。</noscript>
  <div id="root"></div>
</body>
</html>
```

#### 4-2. 入力検証とサニタイゼーション

```javascript
// frontend/src/utils/security.js
import DOMPurify from 'dompurify';

export const sanitizeInput = (input) => {
  return DOMPurify.sanitize(input, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a'],
    ALLOWED_ATTR: ['href']
  });
};

export const validateInput = {
  email: (email) => {
    const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return regex.test(email);
  },
  
  username: (username) => {
    const regex = /^[a-zA-Z0-9_]{3,20}$/;
    return regex.test(username);
  },
  
  password: (password) => {
    // 最低8文字、英数字を含む
    const regex = /^(?=.*[a-zA-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$/;
    return regex.test(password);
  },
  
  postContent: (content) => {
    return content && content.trim().length > 0 && content.length <= 280;
  }
};

export const escapeHtml = (text) => {
  const map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  };
  
  return text.replace(/[&<>"']/g, (m) => map[m]);
};
```

### Step 5: デプロイメント

#### 5-1. メインCloudFormationテンプレート

```yaml
# infrastructure/main.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'SNS風アプリケーション - メインスタック'

Parameters:
  Environment:
    Type: String
    Default: dev
    AllowedValues: [dev, staging, prod]
  
  ProjectName:
    Type: String
    Default: sns-app

  DatabasePassword:
    Type: String
    NoEcho: true
    MinLength: 8

Resources:
  # ネットワークスタック
  NetworkStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub 'https://s3.amazonaws.com/${TemplatesBucket}/network.yaml'
      Parameters:
        Environment: !Ref Environment
        ProjectName: !Ref ProjectName

  # データベーススタック
  DatabaseStack:
    Type: AWS::CloudFormation::Stack
    DependsOn: NetworkStack
    Properties:
      TemplateURL: !Sub 'https://s3.amazonaws.com/${TemplatesBucket}/database.yaml'
      Parameters:
        Environment: !Ref Environment
        ProjectName: !Ref ProjectName
        DatabasePassword: !Ref DatabasePassword

  # APIスタック
  ApiStack:
    Type: AWS::CloudFormation::Stack
    DependsOn: DatabaseStack
    Properties:
      TemplateURL: !Sub 'https://s3.amazonaws.com/${TemplatesBucket}/api.yaml'
      Parameters:
        Environment: !Ref Environment
        ProjectName: !Ref ProjectName

  # WebSocketスタック
  WebSocketStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub 'https://s3.amazonaws.com/${TemplatesBucket}/websocket.yaml'
      Parameters:
        Environment: !Ref Environment
        ProjectName: !Ref ProjectName

  # フロントエンドスタック
  FrontendStack:
    Type: AWS::CloudFormation::Stack
    DependsOn: [ApiStack, WebSocketStack]
    Properties:
      TemplateURL: !Sub 'https://s3.amazonaws.com/${TemplatesBucket}/frontend.yaml'
      Parameters:
        Environment: !Ref Environment
        ProjectName: !Ref ProjectName

Outputs:
  ApplicationURL:
    Description: 'Application URL'
    Value: !GetAtt FrontendStack.Outputs.CloudFrontURL
  
  ApiUrl:
    Description: 'API Gateway URL'
    Value: !GetAtt ApiStack.Outputs.ApiUrl
  
  WebSocketUrl:
    Description: 'WebSocket URL'
    Value: !GetAtt WebSocketStack.Outputs.WebSocketUrl
```

#### 5-2. デプロイスクリプト

```bash
#!/bin/bash
# scripts/deploy.sh

set -e

ENVIRONMENT=${1:-dev}
PROJECT_NAME="sns-app"
REGION="ap-northeast-1"

echo "🚀 Deploying SNS App to $ENVIRONMENT environment..."

# S3バケット作成（CloudFormationテンプレート用）
TEMPLATES_BUCKET="${PROJECT_NAME}-cf-templates-${ENVIRONMENT}"
aws s3 mb s3://$TEMPLATES_BUCKET --region $REGION || true

# CloudFormationテンプレートをアップロード
echo "📤 Uploading CloudFormation templates..."
aws s3 sync infrastructure/ s3://$TEMPLATES_BUCKET/ --delete

# バックエンドビルド
echo "🔧 Building backend..."
cd backend
npm ci
npm run build
npm run test
cd ..

# フロントエンドビルド
echo "🔧 Building frontend..."
cd frontend
npm ci
npm run build
npm run test
cd ..

# CloudFormationスタックデプロイ
echo "☁️ Deploying CloudFormation stacks..."

# データベースパスワード生成
DB_PASSWORD=$(openssl rand -base64 32)

aws cloudformation deploy \
  --template-file infrastructure/main.yaml \
  --stack-name "${PROJECT_NAME}-${ENVIRONMENT}" \
  --parameter-overrides \
    Environment=$ENVIRONMENT \
    ProjectName=$PROJECT_NAME \
    DatabasePassword=$DB_PASSWORD \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --region $REGION

# Lambda関数更新
echo "⚡ Updating Lambda functions..."
for function in $(aws lambda list-functions --query "Functions[?contains(FunctionName, '${PROJECT_NAME}-${ENVIRONMENT}')].FunctionName" --output text --region $REGION); do
  echo "Updating $function..."
  cd backend
  zip -r ../function.zip . -x "*.git*" "node_modules/.cache/*" "tests/*"
  cd ..
  aws lambda update-function-code \
    --function-name $function \
    --zip-file fileb://function.zip \
    --region $REGION
  rm function.zip
done

# フロントエンドデプロイ
echo "🌐 Deploying frontend..."
FRONTEND_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name "${PROJECT_NAME}-${ENVIRONMENT}" \
  --query "Stacks[0].Outputs[?OutputKey=='FrontendBucket'].OutputValue" \
  --output text --region $REGION)

aws s3 sync frontend/build/ s3://$FRONTEND_BUCKET/ --delete

# CloudFrontキャッシュ無効化
DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
  --stack-name "${PROJECT_NAME}-${ENVIRONMENT}" \
  --query "Stacks[0].Outputs[?OutputKey=='CloudFrontDistributionId'].OutputValue" \
  --output text --region $REGION)

aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*" \
  --region $REGION

echo "✅ Deployment completed successfully!"

# アプリケーションURLを表示
APP_URL=$(aws cloudformation describe-stacks \
  --stack-name "${PROJECT_NAME}-${ENVIRONMENT}" \
  --query "Stacks[0].Outputs[?OutputKey=='ApplicationURL'].OutputValue" \
  --output text --region $REGION)

echo "🌍 Application URL: $APP_URL"
```

### Step 6: 監視とログ

#### 6-1. CloudWatch ダッシュボード

```yaml
# monitoring/dashboard.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'SNS App - Monitoring Dashboard'

Parameters:
  ProjectName:
    Type: String
    Default: sns-app
  Environment:
    Type: String

Resources:
  ApplicationDashboard:
    Type: AWS::CloudWatch::Dashboard
    Properties:
      DashboardName: !Sub '${ProjectName}-${Environment}'
      DashboardBody: !Sub |
        {
          "widgets": [
            {
              "type": "metric",
              "properties": {
                "metrics": [
                  ["AWS/Lambda", "Invocations", "FunctionName", "${ProjectName}-create-post-${Environment}"],
                  ["AWS/Lambda", "Duration", "FunctionName", "${ProjectName}-create-post-${Environment}"],
                  ["AWS/Lambda", "Errors", "FunctionName", "${ProjectName}-create-post-${Environment}"]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "${AWS::Region}",
                "title": "Lambda Performance"
              }
            },
            {
              "type": "metric",
              "properties": {
                "metrics": [
                  ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", "${ProjectName}-posts-${Environment}"],
                  ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", "${ProjectName}-posts-${Environment}"]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "${AWS::Region}",
                "title": "DynamoDB Usage"
              }
            },
            {
              "type": "metric",
              "properties": {
                "metrics": [
                  ["AWS/CloudFront", "Requests", "DistributionId", "${CloudFrontDistributionId}"],
                  ["AWS/CloudFront", "BytesDownloaded", "DistributionId", "${CloudFrontDistributionId}"]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "CloudFront Traffic"
              }
            }
          ]
        }
```

## 最終確認とテスト

### 機能テストチェックリスト

- [ ] ユーザー登録・ログイン
- [ ] 投稿作成・編集・削除
- [ ] 画像アップロード・表示
- [ ] いいね・コメント機能
- [ ] フォロー・フォロワー機能
- [ ] リアルタイム通知
- [ ] 検索機能
- [ ] レスポンシブデザイン
- [ ] PWA機能（オフライン対応）

### パフォーマンステスト

- [ ] ページ読み込み時間 < 3秒
- [ ] 画像最適化確認
- [ ] CDN配信確認
- [ ] WebSocket接続安定性
- [ ] モバイル表示確認

### セキュリティテスト

- [ ] XSS対策確認
- [ ] CSRF対策確認
- [ ] 入力値検証確認
- [ ] 認証・認可確認
- [ ] HTTPS通信確認

## 学習成果

このモジュールを完了すると、以下のスキルが身につきます：

### 技術スキル
- フルスタックWebアプリケーション開発
- AWS サーバーレスアーキテクチャ
- リアルタイム通信実装
- データベース設計・最適化
- UI/UX設計・実装

### 実務スキル
- 要件定義から運用まで
- パフォーマンス最適化
- セキュリティ対策
- 監視・ログ設計
- CI/CD構築

## 次のステップ

このSNS風Webアプリケーションを基盤として、以下の拡張が可能です：

1. **04-モバイルアプリ開発編**: React Native/Flutterでモバイルアプリ化
2. **05-AI機能統合編**: Bedrock を使った AI 機能追加
3. **06-大規模運用編**: マイクロサービス化とスケーリング
4. **07-分析基盤編**: データ分析とレコメンデーション機能

## 学習時間: 2時間

- 機能統合: 45分
- UI/UX改善: 30分
- デプロイ・テスト: 30分
- ドキュメント作成: 15分

## 総学習時間: 10.5時間

全6セクションを通じて、本格的なWebサービス開発のスキルを体系的に習得できます。