# 3.1-CRUD機能実装

SNS風アプリケーションの投稿システムにおける基本的なCRUD操作（Create, Read, Update, Delete）を実装します。

## 学習目標

- REST API設計の理解
- Express.jsでのAPI実装
- DynamoDBとの連携
- バリデーションとエラーハンドリング
- フロントエンドとの連携

## 機能要件

### 投稿機能
- 投稿の作成 (Create)
- 投稿の取得 (Read)
- 投稿の更新 (Update)
- 投稿の削除 (Delete)
- 投稿一覧の取得
- ユーザー別投稿取得

### データモデル

**Post (投稿)**
```json
{
  "postId": "string (UUID)",
  "userId": "string",
  "content": "string (1-280文字)",
  "imageUrl": "string (optional)",
  "createdAt": "string (ISO 8601)",
  "updatedAt": "string (ISO 8601)",
  "likesCount": "number",
  "commentsCount": "number",
  "tags": ["string"]
}
```

## アーキテクチャ

```
Frontend (React) → API Gateway → Lambda → DynamoDB
                                     ↓
                              CloudWatch Logs
```

## 実装手順

### Step 1: インフラストラクチャ構築

DynamoDBテーブルとLambda関数をCloudFormationで作成します。

```bash
# CloudFormationスタック作成
aws cloudformation create-stack \
  --stack-name sns-crud-api \
  --template-body file://cloudformation/crud-api.yaml \
  --capabilities CAPABILITY_IAM
```

### Step 2: バックエンドAPI実装

#### 2-1. プロジェクト構造
```
backend/
├── src/
│   ├── handlers/
│   │   ├── posts.js
│   │   └── health.js
│   ├── services/
│   │   └── postService.js
│   ├── models/
│   │   └── post.js
│   ├── utils/
│   │   ├── validator.js
│   │   ├── response.js
│   │   └── errors.js
│   └── config/
│       └── dynamodb.js
├── tests/
│   └── posts.test.js
├── package.json
└── serverless.yml
```

#### 2-2. DynamoDB設定

```javascript
// src/config/dynamodb.js
const AWS = require('aws-sdk');

const dynamodb = new AWS.DynamoDB.DocumentClient({
  region: process.env.AWS_REGION || 'ap-northeast-1'
});

const POSTS_TABLE = process.env.POSTS_TABLE || 'sns-posts';

module.exports = {
  dynamodb,
  POSTS_TABLE
};
```

#### 2-3. 投稿モデル

```javascript
// src/models/post.js
const { v4: uuidv4 } = require('uuid');

class Post {
  constructor(data) {
    this.postId = data.postId || uuidv4();
    this.userId = data.userId;
    this.content = data.content;
    this.imageUrl = data.imageUrl || null;
    this.createdAt = data.createdAt || new Date().toISOString();
    this.updatedAt = data.updatedAt || new Date().toISOString();
    this.likesCount = data.likesCount || 0;
    this.commentsCount = data.commentsCount || 0;
    this.tags = data.tags || [];
  }

  // バリデーション
  validate() {
    const errors = [];

    if (!this.userId) {
      errors.push('User ID is required');
    }

    if (!this.content || this.content.trim().length === 0) {
      errors.push('Content is required');
    }

    if (this.content && this.content.length > 280) {
      errors.push('Content must be 280 characters or less');
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }

  // DynamoDB用データ変換
  toDynamoDB() {
    return {
      postId: this.postId,
      userId: this.userId,
      content: this.content,
      imageUrl: this.imageUrl,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt,
      likesCount: this.likesCount,
      commentsCount: this.commentsCount,
      tags: this.tags
    };
  }
}

module.exports = Post;
```

#### 2-4. 投稿サービス

```javascript
// src/services/postService.js
const { dynamodb, POSTS_TABLE } = require('../config/dynamodb');
const Post = require('../models/post');

class PostService {
  // 投稿作成
  async createPost(postData) {
    const post = new Post(postData);
    const validation = post.validate();

    if (!validation.isValid) {
      throw new Error(`Validation failed: ${validation.errors.join(', ')}`);
    }

    const params = {
      TableName: POSTS_TABLE,
      Item: post.toDynamoDB()
    };

    await dynamodb.put(params).promise();
    return post;
  }

  // 投稿取得
  async getPost(postId) {
    const params = {
      TableName: POSTS_TABLE,
      Key: { postId }
    };

    const result = await dynamodb.get(params).promise();
    
    if (!result.Item) {
      throw new Error('Post not found');
    }

    return new Post(result.Item);
  }

  // 投稿一覧取得
  async getPosts(limit = 20, lastKey = null) {
    const params = {
      TableName: POSTS_TABLE,
      ScanIndexForward: false, // 新しい順
      Limit: limit
    };

    if (lastKey) {
      params.ExclusiveStartKey = lastKey;
    }

    const result = await dynamodb.scan(params).promise();

    return {
      posts: result.Items.map(item => new Post(item)),
      lastKey: result.LastEvaluatedKey
    };
  }

  // ユーザー別投稿取得
  async getPostsByUser(userId, limit = 20, lastKey = null) {
    const params = {
      TableName: POSTS_TABLE,
      IndexName: 'userId-createdAt-index',
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId
      },
      ScanIndexForward: false,
      Limit: limit
    };

    if (lastKey) {
      params.ExclusiveStartKey = lastKey;
    }

    const result = await dynamodb.query(params).promise();

    return {
      posts: result.Items.map(item => new Post(item)),
      lastKey: result.LastEvaluatedKey
    };
  }

  // 投稿更新
  async updatePost(postId, updateData) {
    const existingPost = await this.getPost(postId);
    
    // 更新可能フィールドのみ許可
    const allowedFields = ['content', 'imageUrl', 'tags'];
    const updates = {};
    
    Object.keys(updateData).forEach(key => {
      if (allowedFields.includes(key)) {
        updates[key] = updateData[key];
      }
    });

    updates.updatedAt = new Date().toISOString();

    const updateExpression = [];
    const expressionAttributeValues = {};
    const expressionAttributeNames = {};

    Object.keys(updates).forEach(key => {
      updateExpression.push(`#${key} = :${key}`);
      expressionAttributeNames[`#${key}`] = key;
      expressionAttributeValues[`:${key}`] = updates[key];
    });

    const params = {
      TableName: POSTS_TABLE,
      Key: { postId },
      UpdateExpression: `SET ${updateExpression.join(', ')}`,
      ExpressionAttributeNames: expressionAttributeNames,
      ExpressionAttributeValues: expressionAttributeValues,
      ReturnValues: 'ALL_NEW'
    };

    const result = await dynamodb.update(params).promise();
    return new Post(result.Attributes);
  }

  // 投稿削除
  async deletePost(postId) {
    const params = {
      TableName: POSTS_TABLE,
      Key: { postId },
      ReturnValues: 'ALL_OLD'
    };

    const result = await dynamodb.delete(params).promise();
    
    if (!result.Attributes) {
      throw new Error('Post not found');
    }

    return new Post(result.Attributes);
  }

  // いいね数更新
  async updateLikesCount(postId, increment = 1) {
    const params = {
      TableName: POSTS_TABLE,
      Key: { postId },
      UpdateExpression: 'ADD likesCount :increment',
      ExpressionAttributeValues: {
        ':increment': increment
      },
      ReturnValues: 'ALL_NEW'
    };

    const result = await dynamodb.update(params).promise();
    return new Post(result.Attributes);
  }
}

module.exports = new PostService();
```

#### 2-5. Lambda ハンドラー

```javascript
// src/handlers/posts.js
const postService = require('../services/postService');
const { createResponse, createErrorResponse } = require('../utils/response');

// 投稿作成
exports.createPost = async (event) => {
  try {
    const body = JSON.parse(event.body);
    const post = await postService.createPost(body);
    
    return createResponse(201, {
      message: 'Post created successfully',
      post: post
    });
  } catch (error) {
    console.error('Create post error:', error);
    return createErrorResponse(400, error.message);
  }
};

// 投稿取得
exports.getPost = async (event) => {
  try {
    const { postId } = event.pathParameters;
    const post = await postService.getPost(postId);
    
    return createResponse(200, { post });
  } catch (error) {
    console.error('Get post error:', error);
    if (error.message === 'Post not found') {
      return createErrorResponse(404, error.message);
    }
    return createErrorResponse(500, 'Internal server error');
  }
};

// 投稿一覧取得
exports.getPosts = async (event) => {
  try {
    const limit = parseInt(event.queryStringParameters?.limit || '20');
    const lastKey = event.queryStringParameters?.lastKey ? 
      JSON.parse(decodeURIComponent(event.queryStringParameters.lastKey)) : null;
    
    const result = await postService.getPosts(limit, lastKey);
    
    return createResponse(200, result);
  } catch (error) {
    console.error('Get posts error:', error);
    return createErrorResponse(500, 'Internal server error');
  }
};

// ユーザー別投稿取得
exports.getPostsByUser = async (event) => {
  try {
    const { userId } = event.pathParameters;
    const limit = parseInt(event.queryStringParameters?.limit || '20');
    const lastKey = event.queryStringParameters?.lastKey ? 
      JSON.parse(decodeURIComponent(event.queryStringParameters.lastKey)) : null;
    
    const result = await postService.getPostsByUser(userId, limit, lastKey);
    
    return createResponse(200, result);
  } catch (error) {
    console.error('Get posts by user error:', error);
    return createErrorResponse(500, 'Internal server error');
  }
};

// 投稿更新
exports.updatePost = async (event) => {
  try {
    const { postId } = event.pathParameters;
    const body = JSON.parse(event.body);
    
    const post = await postService.updatePost(postId, body);
    
    return createResponse(200, {
      message: 'Post updated successfully',
      post: post
    });
  } catch (error) {
    console.error('Update post error:', error);
    if (error.message === 'Post not found') {
      return createErrorResponse(404, error.message);
    }
    return createErrorResponse(400, error.message);
  }
};

// 投稿削除
exports.deletePost = async (event) => {
  try {
    const { postId } = event.pathParameters;
    const post = await postService.deletePost(postId);
    
    return createResponse(200, {
      message: 'Post deleted successfully',
      post: post
    });
  } catch (error) {
    console.error('Delete post error:', error);
    if (error.message === 'Post not found') {
      return createErrorResponse(404, error.message);
    }
    return createErrorResponse(500, 'Internal server error');
  }
};

// いいね機能
exports.likePost = async (event) => {
  try {
    const { postId } = event.pathParameters;
    const post = await postService.updateLikesCount(postId, 1);
    
    return createResponse(200, {
      message: 'Post liked successfully',
      post: post
    });
  } catch (error) {
    console.error('Like post error:', error);
    return createErrorResponse(500, 'Internal server error');
  }
};
```

#### 2-6. ユーティリティ関数

```javascript
// src/utils/response.js
const createResponse = (statusCode, body, headers = {}) => {
  return {
    statusCode,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
      'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
      'Content-Type': 'application/json',
      ...headers
    },
    body: JSON.stringify(body)
  };
};

const createErrorResponse = (statusCode, message) => {
  return createResponse(statusCode, {
    error: true,
    message: message
  });
};

module.exports = {
  createResponse,
  createErrorResponse
};
```

### Step 3: フロントエンド実装

#### 3-1. Post コンポーネント

```jsx
// frontend/src/components/Post.jsx
import React, { useState } from 'react';
import { Card, Button, Badge } from 'react-bootstrap';
import { formatDistance } from 'date-fns';

const Post = ({ post, onLike, onDelete, onEdit, currentUserId }) => {
  const [isEditing, setIsEditing] = useState(false);
  const [editContent, setEditContent] = useState(post.content);

  const handleEdit = async () => {
    if (isEditing) {
      await onEdit(post.postId, { content: editContent });
      setIsEditing(false);
    } else {
      setIsEditing(true);
    }
  };

  const handleCancelEdit = () => {
    setEditContent(post.content);
    setIsEditing(false);
  };

  return (
    <Card className="mb-3">
      <Card.Body>
        <div className="d-flex justify-content-between align-items-start mb-2">
          <div>
            <h6 className="mb-1">@{post.userId}</h6>
            <small className="text-muted">
              {formatDistance(new Date(post.createdAt), new Date(), { addSuffix: true })}
            </small>
          </div>
          {currentUserId === post.userId && (
            <div>
              <Button 
                variant="outline-primary" 
                size="sm" 
                className="me-2"
                onClick={handleEdit}
              >
                {isEditing ? 'Save' : 'Edit'}
              </Button>
              {isEditing && (
                <Button 
                  variant="outline-secondary" 
                  size="sm" 
                  className="me-2"
                  onClick={handleCancelEdit}
                >
                  Cancel
                </Button>
              )}
              <Button 
                variant="outline-danger" 
                size="sm"
                onClick={() => onDelete(post.postId)}
              >
                Delete
              </Button>
            </div>
          )}
        </div>

        {isEditing ? (
          <textarea
            className="form-control"
            value={editContent}
            onChange={(e) => setEditContent(e.target.value)}
            rows={3}
            maxLength={280}
          />
        ) : (
          <Card.Text>{post.content}</Card.Text>
        )}

        {post.imageUrl && (
          <img 
            src={post.imageUrl} 
            alt="Post image" 
            className="img-fluid rounded mb-2"
            style={{ maxHeight: '300px' }}
          />
        )}

        {post.tags && post.tags.length > 0 && (
          <div className="mb-2">
            {post.tags.map((tag, index) => (
              <Badge key={index} bg="secondary" className="me-1">
                #{tag}
              </Badge>
            ))}
          </div>
        )}

        <div className="d-flex justify-content-between align-items-center">
          <Button 
            variant="outline-primary" 
            size="sm"
            onClick={() => onLike(post.postId)}
          >
            ❤️ {post.likesCount}
          </Button>
          <small className="text-muted">
            {post.commentsCount} comments
          </small>
        </div>
      </Card.Body>
    </Card>
  );
};

export default Post;
```

#### 3-2. PostForm コンポーネント

```jsx
// frontend/src/components/PostForm.jsx
import React, { useState } from 'react';
import { Form, Button, Card, Alert } from 'react-bootstrap';

const PostForm = ({ onSubmit, isLoading }) => {
  const [content, setContent] = useState('');
  const [tags, setTags] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!content.trim()) {
      setError('Content is required');
      return;
    }

    if (content.length > 280) {
      setError('Content must be 280 characters or less');
      return;
    }

    try {
      const postData = {
        content: content.trim(),
        tags: tags.split(',').map(tag => tag.trim()).filter(tag => tag)
      };

      await onSubmit(postData);
      setContent('');
      setTags('');
      setError('');
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <Card className="mb-4">
      <Card.Body>
        <h5>Create New Post</h5>
        {error && <Alert variant="danger">{error}</Alert>}
        
        <Form onSubmit={handleSubmit}>
          <Form.Group className="mb-3">
            <Form.Control
              as="textarea"
              rows={3}
              placeholder="What's on your mind?"
              value={content}
              onChange={(e) => setContent(e.target.value)}
              maxLength={280}
            />
            <Form.Text className="text-muted">
              {content.length}/280 characters
            </Form.Text>
          </Form.Group>

          <Form.Group className="mb-3">
            <Form.Control
              type="text"
              placeholder="Tags (comma separated)"
              value={tags}
              onChange={(e) => setTags(e.target.value)}
            />
          </Form.Group>

          <Button 
            type="submit" 
            variant="primary"
            disabled={isLoading || !content.trim()}
          >
            {isLoading ? 'Posting...' : 'Post'}
          </Button>
        </Form>
      </Card.Body>
    </Card>
  );
};

export default PostForm;
```

#### 3-3. PostList コンポーネント

```jsx
// frontend/src/components/PostList.jsx
import React, { useState, useEffect } from 'react';
import { Container, Alert, Spinner, Button } from 'react-bootstrap';
import Post from './Post';
import PostForm from './PostForm';
import { postApi } from '../services/api';

const PostList = () => {
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [posting, setPosting] = useState(false);
  const [error, setError] = useState('');
  const [lastKey, setLastKey] = useState(null);
  const [hasMore, setHasMore] = useState(true);

  // 仮のユーザーID (実際は認証システムから取得)
  const currentUserId = 'demo-user';

  useEffect(() => {
    loadPosts();
  }, []);

  const loadPosts = async (isLoadMore = false) => {
    try {
      setLoading(!isLoadMore);
      const response = await postApi.getPosts(20, isLoadMore ? lastKey : null);
      
      if (isLoadMore) {
        setPosts(prev => [...prev, ...response.posts]);
      } else {
        setPosts(response.posts);
      }
      
      setLastKey(response.lastKey);
      setHasMore(!!response.lastKey);
    } catch (err) {
      setError('Failed to load posts: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleCreatePost = async (postData) => {
    try {
      setPosting(true);
      const newPost = await postApi.createPost({
        ...postData,
        userId: currentUserId
      });
      setPosts(prev => [newPost, ...prev]);
    } catch (err) {
      throw new Error('Failed to create post: ' + err.message);
    } finally {
      setPosting(false);
    }
  };

  const handleLikePost = async (postId) => {
    try {
      const updatedPost = await postApi.likePost(postId);
      setPosts(prev => prev.map(post => 
        post.postId === postId ? updatedPost : post
      ));
    } catch (err) {
      setError('Failed to like post: ' + err.message);
    }
  };

  const handleEditPost = async (postId, updateData) => {
    try {
      const updatedPost = await postApi.updatePost(postId, updateData);
      setPosts(prev => prev.map(post => 
        post.postId === postId ? updatedPost : post
      ));
    } catch (err) {
      setError('Failed to update post: ' + err.message);
    }
  };

  const handleDeletePost = async (postId) => {
    if (!window.confirm('Are you sure you want to delete this post?')) {
      return;
    }

    try {
      await postApi.deletePost(postId);
      setPosts(prev => prev.filter(post => post.postId !== postId));
    } catch (err) {
      setError('Failed to delete post: ' + err.message);
    }
  };

  if (loading && posts.length === 0) {
    return (
      <Container className="text-center py-5">
        <Spinner animation="border" />
        <p>Loading posts...</p>
      </Container>
    );
  }

  return (
    <Container className="py-4">
      <h1 className="mb-4">SNS Feed</h1>
      
      {error && <Alert variant="danger">{error}</Alert>}
      
      <PostForm onSubmit={handleCreatePost} isLoading={posting} />
      
      {posts.length === 0 ? (
        <Alert variant="info">No posts yet. Be the first to post!</Alert>
      ) : (
        <>
          {posts.map(post => (
            <Post
              key={post.postId}
              post={post}
              onLike={handleLikePost}
              onEdit={handleEditPost}
              onDelete={handleDeletePost}
              currentUserId={currentUserId}
            />
          ))}
          
          {hasMore && (
            <div className="text-center">
              <Button 
                variant="outline-primary"
                onClick={() => loadPosts(true)}
                disabled={loading}
              >
                {loading ? 'Loading...' : 'Load More'}
              </Button>
            </div>
          )}
        </>
      )}
    </Container>
  );
};

export default PostList;
```

#### 3-4. API サービス

```javascript
// frontend/src/services/api.js
const API_BASE_URL = process.env.REACT_APP_API_BASE_URL || 'https://your-api-gateway-url';

class PostAPI {
  async request(endpoint, options = {}) {
    const url = `${API_BASE_URL}${endpoint}`;
    const config = {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers
      },
      ...options
    };

    const response = await fetch(url, config);
    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.message || `HTTP error! status: ${response.status}`);
    }

    return data;
  }

  async createPost(postData) {
    const response = await this.request('/posts', {
      method: 'POST',
      body: JSON.stringify(postData)
    });
    return response.post;
  }

  async getPosts(limit = 20, lastKey = null) {
    let endpoint = `/posts?limit=${limit}`;
    if (lastKey) {
      endpoint += `&lastKey=${encodeURIComponent(JSON.stringify(lastKey))}`;
    }
    return await this.request(endpoint);
  }

  async getPost(postId) {
    const response = await this.request(`/posts/${postId}`);
    return response.post;
  }

  async getPostsByUser(userId, limit = 20, lastKey = null) {
    let endpoint = `/users/${userId}/posts?limit=${limit}`;
    if (lastKey) {
      endpoint += `&lastKey=${encodeURIComponent(JSON.stringify(lastKey))}`;
    }
    return await this.request(endpoint);
  }

  async updatePost(postId, updateData) {
    const response = await this.request(`/posts/${postId}`, {
      method: 'PUT',
      body: JSON.stringify(updateData)
    });
    return response.post;
  }

  async deletePost(postId) {
    const response = await this.request(`/posts/${postId}`, {
      method: 'DELETE'
    });
    return response.post;
  }

  async likePost(postId) {
    const response = await this.request(`/posts/${postId}/like`, {
      method: 'POST'
    });
    return response.post;
  }
}

export const postApi = new PostAPI();
```

### Step 4: テスト実装

#### 4-1. バックエンドテスト

```javascript
// backend/tests/posts.test.js
const postService = require('../src/services/postService');
const Post = require('../src/models/post');

// モックDynamoDB
jest.mock('../src/config/dynamodb', () => ({
  dynamodb: {
    put: jest.fn(),
    get: jest.fn(),
    scan: jest.fn(),
    query: jest.fn(),
    update: jest.fn(),
    delete: jest.fn()
  },
  POSTS_TABLE: 'test-posts'
}));

const { dynamodb } = require('../src/config/dynamodb');

describe('PostService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createPost', () => {
    it('should create a valid post', async () => {
      const postData = {
        userId: 'test-user',
        content: 'Test post content'
      };

      dynamodb.put.mockReturnValue({
        promise: () => Promise.resolve({})
      });

      const result = await postService.createPost(postData);

      expect(result).toBeInstanceOf(Post);
      expect(result.userId).toBe(postData.userId);
      expect(result.content).toBe(postData.content);
      expect(result.postId).toBeDefined();
      expect(dynamodb.put).toHaveBeenCalledTimes(1);
    });

    it('should reject post without content', async () => {
      const postData = {
        userId: 'test-user',
        content: ''
      };

      await expect(postService.createPost(postData))
        .rejects.toThrow('Validation failed');
    });

    it('should reject post with content too long', async () => {
      const postData = {
        userId: 'test-user',
        content: 'a'.repeat(281)
      };

      await expect(postService.createPost(postData))
        .rejects.toThrow('Validation failed');
    });
  });

  describe('getPost', () => {
    it('should return post when found', async () => {
      const mockPost = {
        postId: 'test-id',
        userId: 'test-user',
        content: 'Test content',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        likesCount: 0,
        commentsCount: 0,
        tags: []
      };

      dynamodb.get.mockReturnValue({
        promise: () => Promise.resolve({ Item: mockPost })
      });

      const result = await postService.getPost('test-id');

      expect(result).toBeInstanceOf(Post);
      expect(result.postId).toBe(mockPost.postId);
      expect(dynamodb.get).toHaveBeenCalledWith({
        TableName: 'test-posts',
        Key: { postId: 'test-id' }
      });
    });

    it('should throw error when post not found', async () => {
      dynamodb.get.mockReturnValue({
        promise: () => Promise.resolve({})
      });

      await expect(postService.getPost('non-existent'))
        .rejects.toThrow('Post not found');
    });
  });
});

// フロントエンドテスト用のサンプル
describe('Post Model', () => {
  it('should create valid post instance', () => {
    const postData = {
      userId: 'test-user',
      content: 'Test content'
    };

    const post = new Post(postData);
    const validation = post.validate();

    expect(validation.isValid).toBe(true);
    expect(validation.errors).toHaveLength(0);
  });

  it('should validate required fields', () => {
    const post = new Post({});
    const validation = post.validate();

    expect(validation.isValid).toBe(false);
    expect(validation.errors).toContain('User ID is required');
    expect(validation.errors).toContain('Content is required');
  });
});
```

### Step 5: デプロイと動作確認

#### 5-1. バックエンドデプロイ

```bash
# 依存関係インストール
cd backend
npm install

# Lambda関数をZIPパッケージ化
npm run build

# CloudFormationでデプロイ
aws cloudformation deploy \
  --template-file cloudformation/crud-api.yaml \
  --stack-name sns-crud-api \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    Environment=dev
```

#### 5-2. フロントエンドデプロイ

```bash
# フロントエンド準備
cd frontend
npm install

# 環境変数設定
echo "REACT_APP_API_BASE_URL=https://your-api-gateway-url" > .env

# ビルドとテスト
npm run build
npm test

# S3にデプロイ (オプション)
aws s3 sync build/ s3://your-frontend-bucket/
```

#### 5-3. 動作確認

```bash
# API テスト
curl -X POST https://your-api-gateway-url/posts \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user",
    "content": "Hello, world! This is my first post.",
    "tags": ["hello", "world"]
  }'

# 投稿一覧取得
curl https://your-api-gateway-url/posts

# 特定投稿取得
curl https://your-api-gateway-url/posts/{POST_ID}
```

## API エンドポイント

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/posts` | 投稿作成 |
| GET | `/posts` | 投稿一覧取得 |
| GET | `/posts/{postId}` | 特定投稿取得 |
| PUT | `/posts/{postId}` | 投稿更新 |
| DELETE | `/posts/{postId}` | 投稿削除 |
| POST | `/posts/{postId}/like` | いいね |
| GET | `/users/{userId}/posts` | ユーザー別投稿取得 |

## トラブルシューティング

### よくある問題

**1. CORS エラー**
- API GatewayでCORS設定を確認
- Lambdaレスポンスヘッダーを確認

**2. DynamoDB 権限エラー**
- Lambda実行ロールにDynamoDB権限を付与
- テーブル名の環境変数を確認

**3. バリデーションエラー**
- リクエストボディの形式を確認
- 文字数制限を確認

**4. フロントエンド接続エラー**
- API Gateway URLを確認
- ネットワーク設定を確認

## 次のステップ

CRUD機能が完成したら、**3.2-ファイルアップロード**に進みます。

次のセクションでは、S3を使った画像アップロード機能を実装し、投稿に画像を添付できるようにします。

## 学習時間: 2時間

- 設計・準備: 30分
- バックエンド実装: 60分
- フロントエンド実装: 45分
- テスト・確認: 15分