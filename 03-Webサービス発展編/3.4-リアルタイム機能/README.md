# 3.4-リアルタイム機能

API Gateway WebSocketを使ったリアルタイム通信機能を実装し、ライブ通知やリアルタイムフィードを提供します。

## 学習目標

- WebSocket通信の理解
- API Gateway WebSocketの実装
- 接続管理とメッセージ配信
- リアルタイム通知システム
- スケーラブルな双方向通信

## 機能要件

### リアルタイム通知
- 新しいフォロワー通知
- いいね・コメント通知
- メンション通知
- ダイレクトメッセージ

### ライブフィード
- リアルタイム投稿更新
- オンライン状態表示
- タイピングインジケーター
- ライブカウント更新

### 接続管理
- WebSocket接続・切断処理
- 認証とセッション管理
- 接続状態の永続化
- 自動再接続機能

## アーキテクチャ

```
Frontend (WebSocket) ↔ API Gateway WebSocket ↔ Lambda
                                                   ↓
                              DynamoDB (接続管理) + SNS/SQS
                                                   ↓
                                        他のLambda関数 (通知配信)
```

## 実装手順

### Step 1: インフラストラクチャ構築

WebSocket API、Lambda関数、接続管理テーブルをCloudFormationで作成します。

```bash
# CloudFormationスタック作成
aws cloudformation create-stack \
  --stack-name sns-websocket \
  --template-body file://cloudformation/websocket.yaml \
  --capabilities CAPABILITY_IAM
```

### Step 2: バックエンド実装

#### 2-1. プロジェクト構造
```
backend/
├── src/
│   ├── websocket/
│   │   ├── handlers/
│   │   │   ├── connect.js
│   │   │   ├── disconnect.js
│   │   │   ├── message.js
│   │   │   └── broadcast.js
│   │   ├── services/
│   │   │   ├── connectionService.js
│   │   │   ├── notificationService.js
│   │   │   └── messageService.js
│   │   └── models/
│   │       ├── connection.js
│   │       └── notification.js
│   └── config/
│       └── websocket.js
```

#### 2-2. WebSocket設定

```javascript
// src/config/websocket.js
const AWS = require('aws-sdk');

const apiGatewayManagementApi = new AWS.ApiGatewayManagementApi({
  endpoint: process.env.WEBSOCKET_ENDPOINT
});

const dynamodb = new AWS.DynamoDB.DocumentClient({
  region: process.env.AWS_REGION || 'ap-northeast-1'
});

const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE;
const NOTIFICATIONS_TABLE = process.env.NOTIFICATIONS_TABLE;

module.exports = {
  apiGatewayManagementApi,
  dynamodb,
  CONNECTIONS_TABLE,
  NOTIFICATIONS_TABLE
};
```

#### 2-3. 接続管理モデル

```javascript
// src/websocket/models/connection.js
const { dynamodb, CONNECTIONS_TABLE } = require('../../config/websocket');

class Connection {
  constructor(data) {
    this.connectionId = data.connectionId;
    this.userId = data.userId;
    this.connectedAt = data.connectedAt || new Date().toISOString();
    this.lastHeartbeat = data.lastHeartbeat || new Date().toISOString();
    this.userAgent = data.userAgent;
    this.ipAddress = data.ipAddress;
    this.status = data.status || 'active';
    this.subscriptions = data.subscriptions || [];
  }

  static async create(connectionData) {
    const connection = new Connection(connectionData);
    
    const params = {
      TableName: CONNECTIONS_TABLE,
      Item: connection.toDynamoDB()
    };

    await dynamodb.put(params).promise();
    return connection;
  }

  static async findByConnectionId(connectionId) {
    const params = {
      TableName: CONNECTIONS_TABLE,
      Key: { connectionId }
    };

    const result = await dynamodb.get(params).promise();
    
    if (!result.Item) {
      return null;
    }

    return new Connection(result.Item);
  }

  static async findByUserId(userId) {
    const params = {
      TableName: CONNECTIONS_TABLE,
      IndexName: 'userId-index',
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId
      },
      FilterExpression: '#status = :status',
      ExpressionAttributeNames: {
        '#status': 'status'
      },
      ExpressionAttributeValues: {
        ':userId': userId,
        ':status': 'active'
      }
    };

    const result = await dynamodb.query(params).promise();
    return result.Items.map(item => new Connection(item));
  }

  static async getActiveConnections() {
    const params = {
      TableName: CONNECTIONS_TABLE,
      FilterExpression: '#status = :status',
      ExpressionAttributeNames: {
        '#status': 'status'
      },
      ExpressionAttributeValues: {
        ':status': 'active'
      }
    };

    const result = await dynamodb.scan(params).promise();
    return result.Items.map(item => new Connection(item));
  }

  async updateHeartbeat() {
    this.lastHeartbeat = new Date().toISOString();
    
    const params = {
      TableName: CONNECTIONS_TABLE,
      Key: { connectionId: this.connectionId },
      UpdateExpression: 'SET lastHeartbeat = :heartbeat',
      ExpressionAttributeValues: {
        ':heartbeat': this.lastHeartbeat
      }
    };

    await dynamodb.update(params).promise();
  }

  async addSubscription(subscription) {
    if (!this.subscriptions.includes(subscription)) {
      this.subscriptions.push(subscription);
      
      const params = {
        TableName: CONNECTIONS_TABLE,
        Key: { connectionId: this.connectionId },
        UpdateExpression: 'SET subscriptions = :subscriptions',
        ExpressionAttributeValues: {
          ':subscriptions': this.subscriptions
        }
      };

      await dynamodb.update(params).promise();
    }
  }

  async removeSubscription(subscription) {
    const index = this.subscriptions.indexOf(subscription);
    if (index > -1) {
      this.subscriptions.splice(index, 1);
      
      const params = {
        TableName: CONNECTIONS_TABLE,
        Key: { connectionId: this.connectionId },
        UpdateExpression: 'SET subscriptions = :subscriptions',
        ExpressionAttributeValues: {
          ':subscriptions': this.subscriptions
        }
      };

      await dynamodb.update(params).promise();
    }
  }

  async delete() {
    const params = {
      TableName: CONNECTIONS_TABLE,
      Key: { connectionId: this.connectionId }
    };

    await dynamodb.delete(params).promise();
  }

  async markInactive() {
    this.status = 'inactive';
    
    const params = {
      TableName: CONNECTIONS_TABLE,
      Key: { connectionId: this.connectionId },
      UpdateExpression: 'SET #status = :status',
      ExpressionAttributeNames: {
        '#status': 'status'
      },
      ExpressionAttributeValues: {
        ':status': this.status
      }
    };

    await dynamodb.update(params).promise();
  }

  toDynamoDB() {
    return {
      connectionId: this.connectionId,
      userId: this.userId,
      connectedAt: this.connectedAt,
      lastHeartbeat: this.lastHeartbeat,
      userAgent: this.userAgent,
      ipAddress: this.ipAddress,
      status: this.status,
      subscriptions: this.subscriptions
    };
  }

  toJSON() {
    return {
      connectionId: this.connectionId,
      userId: this.userId,
      connectedAt: this.connectedAt,
      lastHeartbeat: this.lastHeartbeat,
      status: this.status,
      subscriptions: this.subscriptions
    };
  }
}

module.exports = Connection;
```

#### 2-4. 接続管理サービス

```javascript
// src/websocket/services/connectionService.js
const { apiGatewayManagementApi } = require('../../config/websocket');
const Connection = require('../models/connection');

class ConnectionService {
  async handleConnection(event) {
    const { connectionId } = event.requestContext;
    const { sourceIp, userAgent } = event.requestContext.identity;
    
    // URLパラメータからユーザーIDを取得
    const userId = event.queryStringParameters?.userId;
    
    if (!userId) {
      throw new Error('User ID is required for connection');
    }

    // 既存接続をクリーンアップ
    await this.cleanupUserConnections(userId);

    // 新しい接続を作成
    const connection = await Connection.create({
      connectionId,
      userId,
      userAgent,
      ipAddress: sourceIp
    });

    console.log(`WebSocket connected: ${connectionId} for user ${userId}`);
    
    // 接続成功メッセージを送信
    await this.sendMessage(connectionId, {
      type: 'connection',
      status: 'connected',
      connectionId,
      timestamp: new Date().toISOString()
    });

    return connection;
  }

  async handleDisconnection(event) {
    const { connectionId } = event.requestContext;
    
    const connection = await Connection.findByConnectionId(connectionId);
    if (connection) {
      await connection.delete();
      console.log(`WebSocket disconnected: ${connectionId}`);
    }
  }

  async sendMessage(connectionId, message) {
    try {
      const params = {
        ConnectionId: connectionId,
        Data: JSON.stringify(message)
      };

      await apiGatewayManagementApi.postToConnection(params).promise();
    } catch (error) {
      if (error.statusCode === 410) {
        // 接続が無効な場合は削除
        console.log(`Stale connection detected: ${connectionId}`);
        const connection = await Connection.findByConnectionId(connectionId);
        if (connection) {
          await connection.delete();
        }
      } else {
        console.error(`Failed to send message to ${connectionId}:`, error);
        throw error;
      }
    }
  }

  async broadcastToUser(userId, message) {
    const connections = await Connection.findByUserId(userId);
    
    const sendPromises = connections.map(connection => 
      this.sendMessage(connection.connectionId, message)
        .catch(error => {
          console.error(`Failed to send to connection ${connection.connectionId}:`, error);
        })
    );

    await Promise.allSettled(sendPromises);
  }

  async broadcastToSubscribers(subscription, message) {
    const connections = await Connection.getActiveConnections();
    
    const subscribedConnections = connections.filter(conn => 
      conn.subscriptions.includes(subscription)
    );

    const sendPromises = subscribedConnections.map(connection => 
      this.sendMessage(connection.connectionId, message)
        .catch(error => {
          console.error(`Failed to send to connection ${connection.connectionId}:`, error);
        })
    );

    await Promise.allSettled(sendPromises);
  }

  async cleanupUserConnections(userId) {
    const existingConnections = await Connection.findByUserId(userId);
    
    for (const connection of existingConnections) {
      try {
        // 接続がまだ有効かチェック
        await this.sendMessage(connection.connectionId, { type: 'ping' });
      } catch (error) {
        if (error.statusCode === 410) {
          // 無効な接続は削除
          await connection.delete();
        }
      }
    }
  }

  async cleanupStaleConnections() {
    const connections = await Connection.getActiveConnections();
    const staleThreshold = Date.now() - (5 * 60 * 1000); // 5分

    for (const connection of connections) {
      const lastHeartbeat = new Date(connection.lastHeartbeat).getTime();
      
      if (lastHeartbeat < staleThreshold) {
        try {
          await this.sendMessage(connection.connectionId, { type: 'ping' });
        } catch (error) {
          if (error.statusCode === 410) {
            await connection.delete();
            console.log(`Cleaned up stale connection: ${connection.connectionId}`);
          }
        }
      }
    }
  }

  async getOnlineUsers() {
    const connections = await Connection.getActiveConnections();
    const onlineUsers = [...new Set(connections.map(conn => conn.userId))];
    return onlineUsers;
  }

  async getUserConnectionCount(userId) {
    const connections = await Connection.findByUserId(userId);
    return connections.length;
  }
}

module.exports = new ConnectionService();
```

#### 2-5. 通知サービス

```javascript
// src/websocket/services/notificationService.js
const { dynamodb, NOTIFICATIONS_TABLE } = require('../../config/websocket');
const connectionService = require('./connectionService');
const { v4: uuidv4 } = require('uuid');

class NotificationService {
  async createNotification(notificationData) {
    const notification = {
      notificationId: uuidv4(),
      userId: notificationData.userId,
      type: notificationData.type,
      title: notificationData.title,
      message: notificationData.message,
      data: notificationData.data || {},
      isRead: false,
      createdAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString() // 30日後
    };

    // DynamoDBに保存
    const params = {
      TableName: NOTIFICATIONS_TABLE,
      Item: notification
    };

    await dynamodb.put(params).promise();

    // リアルタイム配信
    await this.sendNotificationToUser(notification.userId, notification);

    return notification;
  }

  async sendNotificationToUser(userId, notification) {
    const message = {
      type: 'notification',
      data: notification
    };

    await connectionService.broadcastToUser(userId, message);
  }

  async sendFollowNotification(followerId, followedId) {
    // フォロワー情報取得（実際の実装では User モデルから取得）
    const followerInfo = { username: 'follower_user' }; // プレースホルダー

    await this.createNotification({
      userId: followedId,
      type: 'follow',
      title: 'New Follower',
      message: `${followerInfo.username} started following you`,
      data: {
        followerId,
        followerUsername: followerInfo.username
      }
    });
  }

  async sendLikeNotification(postId, likerId, postOwnerId) {
    if (likerId === postOwnerId) return; // 自分の投稿は通知しない

    // ライカー情報取得
    const likerInfo = { username: 'liker_user' }; // プレースホルダー

    await this.createNotification({
      userId: postOwnerId,
      type: 'like',
      title: 'Post Liked',
      message: `${likerInfo.username} liked your post`,
      data: {
        postId,
        likerId,
        likerUsername: likerInfo.username
      }
    });
  }

  async sendCommentNotification(postId, commentId, commenterId, postOwnerId) {
    if (commenterId === postOwnerId) return; // 自分の投稿は通知しない

    // コメンター情報取得
    const commenterInfo = { username: 'commenter_user' }; // プレースホルダー

    await this.createNotification({
      userId: postOwnerId,
      type: 'comment',
      title: 'New Comment',
      message: `${commenterInfo.username} commented on your post`,
      data: {
        postId,
        commentId,
        commenterId,
        commenterUsername: commenterInfo.username
      }
    });
  }

  async sendMentionNotification(postId, authorId, mentionedUserId) {
    if (authorId === mentionedUserId) return; // 自分は通知しない

    // 著者情報取得
    const authorInfo = { username: 'author_user' }; // プレースホルダー

    await this.createNotification({
      userId: mentionedUserId,
      type: 'mention',
      title: 'You were mentioned',
      message: `${authorInfo.username} mentioned you in a post`,
      data: {
        postId,
        authorId,
        authorUsername: authorInfo.username
      }
    });
  }

  async getUserNotifications(userId, limit = 20, lastKey = null) {
    const params = {
      TableName: NOTIFICATIONS_TABLE,
      IndexName: 'userId-createdAt-index',
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId
      },
      ScanIndexForward: false, // 新しい順
      Limit: limit
    };

    if (lastKey) {
      params.ExclusiveStartKey = lastKey;
    }

    const result = await dynamodb.query(params).promise();
    
    return {
      notifications: result.Items,
      lastKey: result.LastEvaluatedKey
    };
  }

  async markNotificationAsRead(notificationId, userId) {
    const params = {
      TableName: NOTIFICATIONS_TABLE,
      Key: {
        notificationId,
        userId
      },
      UpdateExpression: 'SET isRead = :isRead',
      ExpressionAttributeValues: {
        ':isRead': true
      },
      ConditionExpression: 'attribute_exists(notificationId)'
    };

    await dynamodb.update(params).promise();
  }

  async markAllNotificationsAsRead(userId) {
    const notifications = await this.getUserNotifications(userId, 100);
    
    const updatePromises = notifications.notifications
      .filter(n => !n.isRead)
      .map(n => this.markNotificationAsRead(n.notificationId, userId));

    await Promise.allSettled(updatePromises);
  }

  async getUnreadCount(userId) {
    const params = {
      TableName: NOTIFICATIONS_TABLE,
      IndexName: 'userId-createdAt-index',
      KeyConditionExpression: 'userId = :userId',
      FilterExpression: 'isRead = :isRead',
      ExpressionAttributeValues: {
        ':userId': userId,
        ':isRead': false
      },
      Select: 'COUNT'
    };

    const result = await dynamodb.query(params).promise();
    return result.Count;
  }

  // リアルタイムブロードキャスト
  async broadcastPostUpdate(postData) {
    const message = {
      type: 'post_update',
      data: postData
    };

    // 全体フィードを購読しているユーザーに配信
    await connectionService.broadcastToSubscribers('global_feed', message);
  }

  async broadcastUserStatusUpdate(userId, status) {
    const message = {
      type: 'user_status',
      data: {
        userId,
        status,
        timestamp: new Date().toISOString()
      }
    };

    // ユーザーステータスを購読しているユーザーに配信
    await connectionService.broadcastToSubscribers(`user_status_${userId}`, message);
  }

  async broadcastTypingIndicator(chatId, userId, isTyping) {
    const message = {
      type: 'typing_indicator',
      data: {
        chatId,
        userId,
        isTyping,
        timestamp: new Date().toISOString()
      }
    };

    // 特定のチャットを購読しているユーザーに配信
    await connectionService.broadcastToSubscribers(`chat_${chatId}`, message);
  }
}

module.exports = new NotificationService();
```

#### 2-6. WebSocket ハンドラー

```javascript
// src/websocket/handlers/connect.js
const connectionService = require('../services/connectionService');
const { createResponse, createErrorResponse } = require('../../utils/response');

exports.handler = async (event) => {
  try {
    console.log('WebSocket connection request:', JSON.stringify(event, null, 2));
    
    await connectionService.handleConnection(event);
    
    return createResponse(200, { message: 'Connected successfully' });
  } catch (error) {
    console.error('WebSocket connection error:', error);
    return createErrorResponse(403, error.message);
  }
};
```

```javascript
// src/websocket/handlers/disconnect.js
const connectionService = require('../services/connectionService');
const { createResponse } = require('../../utils/response');

exports.handler = async (event) => {
  try {
    console.log('WebSocket disconnection request:', JSON.stringify(event, null, 2));
    
    await connectionService.handleDisconnection(event);
    
    return createResponse(200, { message: 'Disconnected successfully' });
  } catch (error) {
    console.error('WebSocket disconnection error:', error);
    // 切断時はエラーでも200を返す
    return createResponse(200, { message: 'Disconnected' });
  }
};
```

```javascript
// src/websocket/handlers/message.js
const connectionService = require('../services/connectionService');
const notificationService = require('../services/notificationService');
const Connection = require('../models/connection');
const { createResponse, createErrorResponse } = require('../../utils/response');

exports.handler = async (event) => {
  try {
    const { connectionId } = event.requestContext;
    let body;
    
    try {
      body = JSON.parse(event.body);
    } catch (error) {
      throw new Error('Invalid JSON in message body');
    }

    const connection = await Connection.findByConnectionId(connectionId);
    if (!connection) {
      throw new Error('Connection not found');
    }

    // メッセージタイプに応じて処理
    switch (body.type) {
      case 'heartbeat':
        await handleHeartbeat(connection);
        break;
        
      case 'subscribe':
        await handleSubscribe(connection, body.subscription);
        break;
        
      case 'unsubscribe':
        await handleUnsubscribe(connection, body.subscription);
        break;
        
      case 'message':
        await handleDirectMessage(connection, body);
        break;
        
      case 'typing':
        await handleTypingIndicator(connection, body);
        break;
        
      default:
        throw new Error(`Unknown message type: ${body.type}`);
    }

    return createResponse(200, { message: 'Message processed successfully' });
  } catch (error) {
    console.error('WebSocket message error:', error);
    return createErrorResponse(400, error.message);
  }
};

async function handleHeartbeat(connection) {
  await connection.updateHeartbeat();
  
  await connectionService.sendMessage(connection.connectionId, {
    type: 'heartbeat_ack',
    timestamp: new Date().toISOString()
  });
}

async function handleSubscribe(connection, subscription) {
  await connection.addSubscription(subscription);
  
  await connectionService.sendMessage(connection.connectionId, {
    type: 'subscription_ack',
    subscription,
    status: 'subscribed'
  });
}

async function handleUnsubscribe(connection, subscription) {
  await connection.removeSubscription(subscription);
  
  await connectionService.sendMessage(connection.connectionId, {
    type: 'subscription_ack',
    subscription,
    status: 'unsubscribed'
  });
}

async function handleDirectMessage(connection, messageData) {
  const { recipientId, content, chatId } = messageData;
  
  if (!recipientId || !content) {
    throw new Error('Recipient ID and content are required for direct messages');
  }

  // メッセージを受信者に送信
  const message = {
    type: 'direct_message',
    data: {
      senderId: connection.userId,
      recipientId,
      content,
      chatId,
      timestamp: new Date().toISOString()
    }
  };

  await connectionService.broadcastToUser(recipientId, message);
}

async function handleTypingIndicator(connection, typingData) {
  const { chatId, isTyping } = typingData;
  
  if (!chatId) {
    throw new Error('Chat ID is required for typing indicators');
  }

  await notificationService.broadcastTypingIndicator(
    chatId,
    connection.userId,
    isTyping
  );
}
```

### Step 3: フロントエンド実装

#### 3-1. WebSocket クライアント

```javascript
// frontend/src/services/websocketService.js
class WebSocketService {
  constructor() {
    this.ws = null;
    this.connectionId = null;
    this.userId = null;
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 5;
    this.reconnectInterval = 1000;
    this.heartbeatInterval = null;
    this.eventListeners = new Map();
  }

  connect(userId) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      console.log('WebSocket already connected');
      return Promise.resolve();
    }

    return new Promise((resolve, reject) => {
      this.userId = userId;
      const wsUrl = `${process.env.REACT_APP_WEBSOCKET_URL}?userId=${userId}`;
      
      console.log('Connecting to WebSocket:', wsUrl);
      this.ws = new WebSocket(wsUrl);

      this.ws.onopen = (event) => {
        console.log('WebSocket connected');
        this.reconnectAttempts = 0;
        this.startHeartbeat();
        this.emit('connected', event);
        resolve();
      };

      this.ws.onmessage = (event) => {
        try {
          const message = JSON.parse(event.data);
          this.handleMessage(message);
        } catch (error) {
          console.error('Failed to parse WebSocket message:', error);
        }
      };

      this.ws.onclose = (event) => {
        console.log('WebSocket disconnected:', event.code, event.reason);
        this.stopHeartbeat();
        this.emit('disconnected', event);
        
        if (!event.wasClean && this.reconnectAttempts < this.maxReconnectAttempts) {
          this.scheduleReconnect();
        }
      };

      this.ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        this.emit('error', error);
        reject(error);
      };
    });
  }

  disconnect() {
    if (this.ws) {
      this.stopHeartbeat();
      this.ws.close(1000, 'Client disconnecting');
      this.ws = null;
    }
  }

  send(message) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    } else {
      console.warn('WebSocket not connected, cannot send message:', message);
    }
  }

  subscribe(subscription) {
    this.send({
      type: 'subscribe',
      subscription
    });
  }

  unsubscribe(subscription) {
    this.send({
      type: 'unsubscribe',
      subscription
    });
  }

  sendDirectMessage(recipientId, content, chatId) {
    this.send({
      type: 'message',
      recipientId,
      content,
      chatId
    });
  }

  sendTypingIndicator(chatId, isTyping) {
    this.send({
      type: 'typing',
      chatId,
      isTyping
    });
  }

  startHeartbeat() {
    this.heartbeatInterval = setInterval(() => {
      this.send({ type: 'heartbeat' });
    }, 30000); // 30秒間隔
  }

  stopHeartbeat() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
  }

  scheduleReconnect() {
    setTimeout(() => {
      this.reconnectAttempts++;
      console.log(`Reconnecting attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts}`);
      this.connect(this.userId).catch(() => {
        // エラーは既に onclose で処理される
      });
    }, this.reconnectInterval * Math.pow(2, this.reconnectAttempts)); // 指数バックオフ
  }

  handleMessage(message) {
    console.log('WebSocket message received:', message);

    switch (message.type) {
      case 'connection':
        this.connectionId = message.connectionId;
        this.emit('connection_established', message);
        break;
        
      case 'notification':
        this.emit('notification', message.data);
        break;
        
      case 'post_update':
        this.emit('post_update', message.data);
        break;
        
      case 'user_status':
        this.emit('user_status', message.data);
        break;
        
      case 'direct_message':
        this.emit('direct_message', message.data);
        break;
        
      case 'typing_indicator':
        this.emit('typing_indicator', message.data);
        break;
        
      case 'heartbeat_ack':
        // ハートビート確認 - 特に処理不要
        break;
        
      case 'subscription_ack':
        this.emit('subscription_ack', message);
        break;
        
      default:
        console.warn('Unknown message type:', message.type);
    }
  }

  // イベントリスナー管理
  on(event, callback) {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, []);
    }
    this.eventListeners.get(event).push(callback);
  }

  off(event, callback) {
    if (this.eventListeners.has(event)) {
      const listeners = this.eventListeners.get(event);
      const index = listeners.indexOf(callback);
      if (index > -1) {
        listeners.splice(index, 1);
      }
    }
  }

  emit(event, data) {
    if (this.eventListeners.has(event)) {
      this.eventListeners.get(event).forEach(callback => {
        try {
          callback(data);
        } catch (error) {
          console.error(`Error in event listener for ${event}:`, error);
        }
      });
    }
  }

  isConnected() {
    return this.ws && this.ws.readyState === WebSocket.OPEN;
  }
}

export const websocketService = new WebSocketService();
```

#### 3-2. 通知コンポーネント

```jsx
// frontend/src/components/NotificationCenter.jsx
import React, { useState, useEffect } from 'react';
import { Dropdown, Badge, ListGroup, Button } from 'react-bootstrap';
import { websocketService } from '../services/websocketService';
import { notificationApi } from '../services/notificationApi';

const NotificationCenter = ({ userId }) => {
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [show, setShow] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadNotifications();
    loadUnreadCount();

    // WebSocket通知リスナー
    const handleNotification = (notification) => {
      setNotifications(prev => [notification, ...prev]);
      setUnreadCount(prev => prev + 1);
      
      // ブラウザ通知
      if (Notification.permission === 'granted') {
        new Notification(notification.title, {
          body: notification.message,
          icon: '/notification-icon.png'
        });
      }
    };

    websocketService.on('notification', handleNotification);

    return () => {
      websocketService.off('notification', handleNotification);
    };
  }, [userId]);

  const loadNotifications = async () => {
    try {
      setLoading(true);
      const result = await notificationApi.getNotifications(userId);
      setNotifications(result.notifications);
    } catch (error) {
      console.error('Failed to load notifications:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadUnreadCount = async () => {
    try {
      const count = await notificationApi.getUnreadCount(userId);
      setUnreadCount(count);
    } catch (error) {
      console.error('Failed to load unread count:', error);
    }
  };

  const markAsRead = async (notificationId) => {
    try {
      await notificationApi.markAsRead(notificationId);
      setNotifications(prev => 
        prev.map(n => 
          n.notificationId === notificationId 
            ? { ...n, isRead: true }
            : n
        )
      );
      setUnreadCount(prev => Math.max(0, prev - 1));
    } catch (error) {
      console.error('Failed to mark notification as read:', error);
    }
  };

  const markAllAsRead = async () => {
    try {
      await notificationApi.markAllAsRead(userId);
      setNotifications(prev => 
        prev.map(n => ({ ...n, isRead: true }))
      );
      setUnreadCount(0);
    } catch (error) {
      console.error('Failed to mark all notifications as read:', error);
    }
  };

  const formatNotificationTime = (timestamp) => {
    const date = new Date(timestamp);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMins / 60);
    const diffDays = Math.floor(diffHours / 24);

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString();
  };

  const getNotificationIcon = (type) => {
    switch (type) {
      case 'follow': return '👤';
      case 'like': return '❤️';
      case 'comment': return '💬';
      case 'mention': return '📢';
      default: return '🔔';
    }
  };

  return (
    <Dropdown 
      show={show} 
      onToggle={setShow}
      align="end"
    >
      <Dropdown.Toggle 
        variant="outline-secondary" 
        id="notification-dropdown"
        className="position-relative"
      >
        🔔
        {unreadCount > 0 && (
          <Badge 
            bg="danger" 
            className="position-absolute top-0 start-100 translate-middle rounded-pill"
            style={{ fontSize: '0.6rem' }}
          >
            {unreadCount > 99 ? '99+' : unreadCount}
          </Badge>
        )}
      </Dropdown.Toggle>

      <Dropdown.Menu className="notification-menu" style={{ width: '350px', maxHeight: '400px', overflowY: 'auto' }}>
        <div className="d-flex justify-content-between align-items-center p-3 border-bottom">
          <h6 className="mb-0">Notifications</h6>
          {unreadCount > 0 && (
            <Button 
              variant="link" 
              size="sm" 
              onClick={markAllAsRead}
              className="p-0"
            >
              Mark all as read
            </Button>
          )}
        </div>

        {loading ? (
          <div className="text-center p-3">
            <div className="spinner-border spinner-border-sm" />
          </div>
        ) : notifications.length === 0 ? (
          <div className="text-center p-3 text-muted">
            No notifications yet
          </div>
        ) : (
          <ListGroup variant="flush">
            {notifications.slice(0, 10).map((notification) => (
              <ListGroup.Item
                key={notification.notificationId}
                className={`notification-item ${!notification.isRead ? 'unread' : ''}`}
                style={{ cursor: 'pointer' }}
                onClick={() => !notification.isRead && markAsRead(notification.notificationId)}
              >
                <div className="d-flex align-items-start">
                  <span className="me-2 fs-5">
                    {getNotificationIcon(notification.type)}
                  </span>
                  <div className="flex-grow-1">
                    <div className="fw-bold">{notification.title}</div>
                    <div className="text-muted small">{notification.message}</div>
                    <div className="text-muted small">
                      {formatNotificationTime(notification.createdAt)}
                    </div>
                  </div>
                  {!notification.isRead && (
                    <div 
                      className="bg-primary rounded-circle"
                      style={{ width: '8px', height: '8px' }}
                    />
                  )}
                </div>
              </ListGroup.Item>
            ))}
          </ListGroup>
        )}

        {notifications.length > 10 && (
          <div className="text-center p-2 border-top">
            <Button variant="link" size="sm">
              View all notifications
            </Button>
          </div>
        )}
      </Dropdown.Menu>
    </Dropdown>
  );
};

export default NotificationCenter;
```

#### 3-3. リアルタイムフィード

```jsx
// frontend/src/components/RealTimeFeed.jsx
import React, { useState, useEffect } from 'react';
import { Alert, Badge } from 'react-bootstrap';
import { websocketService } from '../services/websocketService';
import PostList from './PostList';

const RealTimeFeed = ({ posts, onPostsUpdate, currentUserId }) => {
  const [newPostsCount, setNewPostsCount] = useState(0);
  const [onlineUsers, setOnlineUsers] = useState([]);
  const [connectionStatus, setConnectionStatus] = useState('disconnected');

  useEffect(() => {
    // WebSocket接続
    if (currentUserId) {
      connectWebSocket();
    }

    return () => {
      websocketService.disconnect();
    };
  }, [currentUserId]);

  const connectWebSocket = async () => {
    try {
      setConnectionStatus('connecting');
      await websocketService.connect(currentUserId);
      setConnectionStatus('connected');

      // グローバルフィードを購読
      websocketService.subscribe('global_feed');

      // イベントリスナー設定
      setupEventListeners();
    } catch (error) {
      setConnectionStatus('failed');
      console.error('Failed to connect WebSocket:', error);
    }
  };

  const setupEventListeners = () => {
    // 接続状態の監視
    websocketService.on('connected', () => {
      setConnectionStatus('connected');
    });

    websocketService.on('disconnected', () => {
      setConnectionStatus('disconnected');
    });

    websocketService.on('error', () => {
      setConnectionStatus('error');
    });

    // 新しい投稿の通知
    websocketService.on('post_update', (postData) => {
      if (postData.userId !== currentUserId) {
        setNewPostsCount(prev => prev + 1);
      }
    });

    // ユーザーステータス更新
    websocketService.on('user_status', (statusData) => {
      setOnlineUsers(prev => {
        if (statusData.status === 'online') {
          return [...new Set([...prev, statusData.userId])];
        } else {
          return prev.filter(id => id !== statusData.userId);
        }
      });
    });
  };

  const loadNewPosts = () => {
    onPostsUpdate();
    setNewPostsCount(0);
  };

  const getConnectionStatusColor = () => {
    switch (connectionStatus) {
      case 'connected': return 'success';
      case 'connecting': return 'warning';
      case 'disconnected': return 'secondary';
      case 'failed':
      case 'error': return 'danger';
      default: return 'secondary';
    }
  };

  const getConnectionStatusText = () => {
    switch (connectionStatus) {
      case 'connected': return 'Live';
      case 'connecting': return 'Connecting...';
      case 'disconnected': return 'Offline';
      case 'failed': return 'Connection Failed';
      case 'error': return 'Error';
      default: return 'Unknown';
    }
  };

  return (
    <div>
      {/* 接続状態とリアルタイム情報 */}
      <div className="d-flex justify-content-between align-items-center mb-3">
        <div className="d-flex align-items-center gap-3">
          <Badge bg={getConnectionStatusColor()} className="d-flex align-items-center gap-1">
            <div 
              className={`rounded-circle ${connectionStatus === 'connected' ? 'bg-white' : ''}`}
              style={{ 
                width: '6px', 
                height: '6px',
                animation: connectionStatus === 'connected' ? 'pulse 2s infinite' : 'none'
              }}
            />
            {getConnectionStatusText()}
          </Badge>
          
          {onlineUsers.length > 0 && (
            <small className="text-muted">
              {onlineUsers.length} users online
            </small>
          )}
        </div>

        {newPostsCount > 0 && (
          <Alert 
            variant="info" 
            className="d-flex align-items-center justify-content-between py-2 px-3 mb-0"
            style={{ cursor: 'pointer' }}
            onClick={loadNewPosts}
          >
            <span>{newPostsCount} new post{newPostsCount > 1 ? 's' : ''}</span>
            <Badge bg="primary">Click to load</Badge>
          </Alert>
        )}
      </div>

      {/* 投稿リスト */}
      <PostList 
        posts={posts} 
        currentUserId={currentUserId}
        onPostUpdate={onPostsUpdate}
      />

      <style jsx>{`
        @keyframes pulse {
          0% { opacity: 1; }
          50% { opacity: 0.5; }
          100% { opacity: 1; }
        }
      `}</style>
    </div>
  );
};

export default RealTimeFeed;
```

## 次のステップ

リアルタイム機能が完成したら、**3.5-本格的なWebアプリ**に進みます。

次のセクションでは、すべての機能を統合し、UI/UXを改善して完全なSNS風Webアプリケーションを完成させます。

## 学習時間: 2時間

- 設計・準備: 30分
- バックエンド実装: 60分
- フロントエンド実装: 45分
- テスト・確認: 15分