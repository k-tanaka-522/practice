# 3.3-データベース発展

RDS PostgreSQLを使った関係データベース設計と実装を学び、より複雑なデータ構造とリレーションシップを扱います。

## 学習目標

- 関係データベース設計の理解
- ER図作成とテーブル設計
- SQLクエリの最適化
- データマイグレーション
- リレーショナルデータの扱い

## 機能要件

### データモデル設計
- ユーザー管理機能の拡張
- フォロー・フォロワー関係
- いいね・コメント機能
- タグ機能の拡張
- 分析用データ収集

### データベース機能
- ACID特性の活用
- トランザクション処理
- インデックス最適化
- 複雑なJOINクエリ
- パフォーマンス監視

## データベース設計

### ER図

```
Users ||--o{ Posts : creates
Users ||--o{ Comments : writes
Users ||--o{ Likes : gives
Users ||--o{ Follows : follows
Users ||--o{ Follows : followed_by
Posts ||--o{ Comments : has
Posts ||--o{ Likes : receives
Posts ||--o{ PostTags : has
Tags ||--o{ PostTags : used_in
```

### テーブル設計

#### 1. users テーブル
```sql
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(100),
    bio TEXT,
    avatar_url TEXT,
    website_url TEXT,
    location VARCHAR(100),
    birthdate DATE,
    is_verified BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    privacy_settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

#### 2. posts テーブル
```sql
CREATE TABLE posts (
    post_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    content TEXT NOT NULL CHECK (char_length(content) <= 280),
    image_urls TEXT[],
    reply_to_post_id UUID REFERENCES posts(post_id),
    is_repost BOOLEAN DEFAULT false,
    original_post_id UUID REFERENCES posts(post_id),
    visibility VARCHAR(20) DEFAULT 'public' CHECK (visibility IN ('public', 'followers', 'private')),
    location_data JSONB,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

#### 3. follows テーブル
```sql
CREATE TABLE follows (
    follow_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    followed_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'blocked', 'muted')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(follower_id, followed_id),
    CHECK (follower_id != followed_id)
);
```

#### 4. likes テーブル
```sql
CREATE TABLE likes (
    like_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, post_id)
);
```

#### 5. comments テーブル
```sql
CREATE TABLE comments (
    comment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    parent_comment_id UUID REFERENCES comments(comment_id),
    content TEXT NOT NULL CHECK (char_length(content) <= 280),
    image_url TEXT,
    is_edited BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

#### 6. tags テーブル
```sql
CREATE TABLE tags (
    tag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    usage_count INTEGER DEFAULT 0,
    is_trending BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

#### 7. post_tags テーブル
```sql
CREATE TABLE post_tags (
    post_id UUID NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags(tag_id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (post_id, tag_id)
);
```

## 実装手順

### Step 1: インフラストラクチャ構築

RDS PostgreSQLとVPC環境をCloudFormationで作成します。

```bash
# CloudFormationスタック作成
aws cloudformation create-stack \
  --stack-name sns-database \
  --template-body file://cloudformation/database.yaml \
  --capabilities CAPABILITY_IAM
```

### Step 2: データベース接続設定

#### 2-1. データベース設定

```javascript
// src/config/database.js
const { Pool } = require('pg');

// RDS接続設定
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 20, // コネクションプール最大数
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// 接続テスト
pool.on('connect', () => {
  console.log('Connected to PostgreSQL database');
});

pool.on('error', (err) => {
  console.error('Unexpected error on idle client', err);
});

module.exports = pool;
```

#### 2-2. マイグレーション管理

```javascript
// src/database/migrations/001_create_users_table.sql
-- ユーザーテーブル作成
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(100),
    bio TEXT,
    avatar_url TEXT,
    website_url TEXT,
    location VARCHAR(100),
    birthdate DATE,
    is_verified BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    privacy_settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- インデックス作成
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);

-- 更新時刻自動更新用トリガー
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

```javascript
// src/database/migrator.js
const fs = require('fs').promises;
const path = require('path');
const pool = require('../config/database');

class DatabaseMigrator {
  constructor() {
    this.migrationsPath = path.join(__dirname, 'migrations');
  }

  async createMigrationsTable() {
    const query = `
      CREATE TABLE IF NOT EXISTS migrations (
        id SERIAL PRIMARY KEY,
        migration_name VARCHAR(255) UNIQUE NOT NULL,
        executed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `;
    await pool.query(query);
  }

  async getExecutedMigrations() {
    const result = await pool.query(
      'SELECT migration_name FROM migrations ORDER BY id'
    );
    return result.rows.map(row => row.migration_name);
  }

  async getMigrationFiles() {
    const files = await fs.readdir(this.migrationsPath);
    return files
      .filter(file => file.endsWith('.sql'))
      .sort();
  }

  async executeMigration(migrationFile) {
    const filePath = path.join(this.migrationsPath, migrationFile);
    const sql = await fs.readFile(filePath, 'utf8');
    
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(sql);
      await client.query(
        'INSERT INTO migrations (migration_name) VALUES ($1)',
        [migrationFile]
      );
      await client.query('COMMIT');
      console.log(`Migration executed: ${migrationFile}`);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async runMigrations() {
    await this.createMigrationsTable();
    
    const executedMigrations = await this.getExecutedMigrations();
    const migrationFiles = await this.getMigrationFiles();
    
    const pendingMigrations = migrationFiles.filter(
      file => !executedMigrations.includes(file)
    );

    if (pendingMigrations.length === 0) {
      console.log('No pending migrations');
      return;
    }

    console.log(`Running ${pendingMigrations.length} migrations...`);
    
    for (const migration of pendingMigrations) {
      await this.executeMigration(migration);
    }
    
    console.log('All migrations completed');
  }
}

module.exports = DatabaseMigrator;
```

### Step 3: データアクセス層実装

#### 3-1. ユーザーモデル

```javascript
// src/models/User.js
const pool = require('../config/database');

class User {
  constructor(data) {
    this.userId = data.user_id;
    this.username = data.username;
    this.email = data.email;
    this.displayName = data.display_name;
    this.bio = data.bio;
    this.avatarUrl = data.avatar_url;
    this.websiteUrl = data.website_url;
    this.location = data.location;
    this.birthdate = data.birthdate;
    this.isVerified = data.is_verified;
    this.isActive = data.is_active;
    this.privacySettings = data.privacy_settings;
    this.createdAt = data.created_at;
    this.updatedAt = data.updated_at;
  }

  static async create(userData) {
    const query = `
      INSERT INTO users (username, email, display_name, bio, avatar_url)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *
    `;
    
    const values = [
      userData.username,
      userData.email,
      userData.displayName,
      userData.bio,
      userData.avatarUrl
    ];

    const result = await pool.query(query, values);
    return new User(result.rows[0]);
  }

  static async findById(userId) {
    const query = 'SELECT * FROM users WHERE user_id = $1 AND is_active = true';
    const result = await pool.query(query, [userId]);
    
    if (result.rows.length === 0) {
      return null;
    }
    
    return new User(result.rows[0]);
  }

  static async findByUsername(username) {
    const query = 'SELECT * FROM users WHERE username = $1 AND is_active = true';
    const result = await pool.query(query, [username]);
    
    if (result.rows.length === 0) {
      return null;
    }
    
    return new User(result.rows[0]);
  }

  static async findByEmail(email) {
    const query = 'SELECT * FROM users WHERE email = $1 AND is_active = true';
    const result = await pool.query(query, [email]);
    
    if (result.rows.length === 0) {
      return null;
    }
    
    return new User(result.rows[0]);
  }

  async update(updateData) {
    const fields = [];
    const values = [];
    let paramCount = 0;

    Object.keys(updateData).forEach(key => {
      if (updateData[key] !== undefined) {
        const dbKey = this.camelToSnake(key);
        fields.push(`${dbKey} = $${++paramCount}`);
        values.push(updateData[key]);
      }
    });

    if (fields.length === 0) {
      return this;
    }

    values.push(this.userId);
    const query = `
      UPDATE users 
      SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $${values.length}
      RETURNING *
    `;

    const result = await pool.query(query, values);
    const updatedUser = new User(result.rows[0]);
    
    // 現在のインスタンスを更新
    Object.assign(this, updatedUser);
    return this;
  }

  async delete() {
    const query = 'UPDATE users SET is_active = false WHERE user_id = $1';
    await pool.query(query, [this.userId]);
    this.isActive = false;
  }

  async getFollowers(limit = 20, offset = 0) {
    const query = `
      SELECT u.*, f.created_at as followed_at
      FROM users u
      JOIN follows f ON u.user_id = f.follower_id
      WHERE f.followed_id = $1 AND f.status = 'active' AND u.is_active = true
      ORDER BY f.created_at DESC
      LIMIT $2 OFFSET $3
    `;
    
    const result = await pool.query(query, [this.userId, limit, offset]);
    return result.rows.map(row => ({
      ...new User(row),
      followedAt: row.followed_at
    }));
  }

  async getFollowing(limit = 20, offset = 0) {
    const query = `
      SELECT u.*, f.created_at as followed_at
      FROM users u
      JOIN follows f ON u.user_id = f.followed_id
      WHERE f.follower_id = $1 AND f.status = 'active' AND u.is_active = true
      ORDER BY f.created_at DESC
      LIMIT $2 OFFSET $3
    `;
    
    const result = await pool.query(query, [this.userId, limit, offset]);
    return result.rows.map(row => ({
      ...new User(row),
      followedAt: row.followed_at
    }));
  }

  async getFollowerCount() {
    const query = `
      SELECT COUNT(*) as count
      FROM follows f
      JOIN users u ON f.follower_id = u.user_id
      WHERE f.followed_id = $1 AND f.status = 'active' AND u.is_active = true
    `;
    
    const result = await pool.query(query, [this.userId]);
    return parseInt(result.rows[0].count);
  }

  async getFollowingCount() {
    const query = `
      SELECT COUNT(*) as count
      FROM follows f
      JOIN users u ON f.followed_id = u.user_id
      WHERE f.follower_id = $1 AND f.status = 'active' AND u.is_active = true
    `;
    
    const result = await pool.query(query, [this.userId]);
    return parseInt(result.rows[0].count);
  }

  async isFollowing(targetUserId) {
    const query = `
      SELECT 1 FROM follows 
      WHERE follower_id = $1 AND followed_id = $2 AND status = 'active'
    `;
    
    const result = await pool.query(query, [this.userId, targetUserId]);
    return result.rows.length > 0;
  }

  camelToSnake(str) {
    return str.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);
  }

  toJSON() {
    return {
      userId: this.userId,
      username: this.username,
      email: this.email,
      displayName: this.displayName,
      bio: this.bio,
      avatarUrl: this.avatarUrl,
      websiteUrl: this.websiteUrl,
      location: this.location,
      birthdate: this.birthdate,
      isVerified: this.isVerified,
      isActive: this.isActive,
      privacySettings: this.privacySettings,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt
    };
  }
}

module.exports = User;
```

#### 3-2. 投稿モデル（拡張版）

```javascript
// src/models/Post.js
const pool = require('../config/database');
const User = require('./User');

class Post {
  constructor(data) {
    this.postId = data.post_id;
    this.userId = data.user_id;
    this.content = data.content;
    this.imageUrls = data.image_urls || [];
    this.replyToPostId = data.reply_to_post_id;
    this.isRepost = data.is_repost;
    this.originalPostId = data.original_post_id;
    this.visibility = data.visibility;
    this.locationData = data.location_data;
    this.metadata = data.metadata || {};
    this.createdAt = data.created_at;
    this.updatedAt = data.updated_at;
    
    // 集計データ
    this.likesCount = data.likes_count || 0;
    this.commentsCount = data.comments_count || 0;
    this.repostsCount = data.reposts_count || 0;
    
    // ユーザー情報
    this.user = data.username ? new User(data) : null;
  }

  static async create(postData) {
    const query = `
      INSERT INTO posts (user_id, content, image_urls, reply_to_post_id, 
                        is_repost, original_post_id, visibility, location_data, metadata)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *
    `;
    
    const values = [
      postData.userId,
      postData.content,
      postData.imageUrls || [],
      postData.replyToPostId || null,
      postData.isRepost || false,
      postData.originalPostId || null,
      postData.visibility || 'public',
      postData.locationData || null,
      postData.metadata || {}
    ];

    const result = await pool.query(query, values);
    return new Post(result.rows[0]);
  }

  static async findById(postId, currentUserId = null) {
    const query = `
      SELECT 
        p.*,
        u.username, u.display_name, u.avatar_url, u.is_verified,
        COALESCE(l.likes_count, 0) as likes_count,
        COALESCE(c.comments_count, 0) as comments_count,
        COALESCE(r.reposts_count, 0) as reposts_count,
        CASE WHEN ul.user_id IS NOT NULL THEN true ELSE false END as is_liked_by_user
      FROM posts p
      JOIN users u ON p.user_id = u.user_id
      LEFT JOIN (
        SELECT post_id, COUNT(*) as likes_count
        FROM likes
        GROUP BY post_id
      ) l ON p.post_id = l.post_id
      LEFT JOIN (
        SELECT post_id, COUNT(*) as comments_count
        FROM comments
        GROUP BY post_id
      ) c ON p.post_id = c.post_id
      LEFT JOIN (
        SELECT original_post_id, COUNT(*) as reposts_count
        FROM posts
        WHERE is_repost = true
        GROUP BY original_post_id
      ) r ON p.post_id = r.original_post_id
      LEFT JOIN likes ul ON p.post_id = ul.post_id AND ul.user_id = $2
      WHERE p.post_id = $1 AND u.is_active = true
    `;
    
    const result = await pool.query(query, [postId, currentUserId]);
    
    if (result.rows.length === 0) {
      return null;
    }
    
    const post = new Post(result.rows[0]);
    post.isLikedByUser = result.rows[0].is_liked_by_user;
    return post;
  }

  static async findByUser(userId, limit = 20, offset = 0, currentUserId = null) {
    const query = `
      SELECT 
        p.*,
        u.username, u.display_name, u.avatar_url, u.is_verified,
        COALESCE(l.likes_count, 0) as likes_count,
        COALESCE(c.comments_count, 0) as comments_count,
        COALESCE(r.reposts_count, 0) as reposts_count,
        CASE WHEN ul.user_id IS NOT NULL THEN true ELSE false END as is_liked_by_user
      FROM posts p
      JOIN users u ON p.user_id = u.user_id
      LEFT JOIN (
        SELECT post_id, COUNT(*) as likes_count
        FROM likes
        GROUP BY post_id
      ) l ON p.post_id = l.post_id
      LEFT JOIN (
        SELECT post_id, COUNT(*) as comments_count
        FROM comments
        GROUP BY post_id
      ) c ON p.post_id = c.post_id
      LEFT JOIN (
        SELECT original_post_id, COUNT(*) as reposts_count
        FROM posts
        WHERE is_repost = true
        GROUP BY original_post_id
      ) r ON p.post_id = r.original_post_id
      LEFT JOIN likes ul ON p.post_id = ul.post_id AND ul.user_id = $4
      WHERE p.user_id = $1 AND u.is_active = true
      ORDER BY p.created_at DESC
      LIMIT $2 OFFSET $3
    `;
    
    const result = await pool.query(query, [userId, limit, offset, currentUserId]);
    
    return result.rows.map(row => {
      const post = new Post(row);
      post.isLikedByUser = row.is_liked_by_user;
      return post;
    });
  }

  static async getTimeline(userId, limit = 20, offset = 0) {
    const query = `
      SELECT 
        p.*,
        u.username, u.display_name, u.avatar_url, u.is_verified,
        COALESCE(l.likes_count, 0) as likes_count,
        COALESCE(c.comments_count, 0) as comments_count,
        COALESCE(r.reposts_count, 0) as reposts_count,
        CASE WHEN ul.user_id IS NOT NULL THEN true ELSE false END as is_liked_by_user
      FROM posts p
      JOIN users u ON p.user_id = u.user_id
      LEFT JOIN follows f ON p.user_id = f.followed_id
      LEFT JOIN (
        SELECT post_id, COUNT(*) as likes_count
        FROM likes
        GROUP BY post_id
      ) l ON p.post_id = l.post_id
      LEFT JOIN (
        SELECT post_id, COUNT(*) as comments_count
        FROM comments
        GROUP BY post_id
      ) c ON p.post_id = c.post_id
      LEFT JOIN (
        SELECT original_post_id, COUNT(*) as reposts_count
        FROM posts
        WHERE is_repost = true
        GROUP BY original_post_id
      ) r ON p.post_id = r.original_post_id
      LEFT JOIN likes ul ON p.post_id = ul.post_id AND ul.user_id = $1
      WHERE (f.follower_id = $1 OR p.user_id = $1) 
        AND f.status = 'active' 
        AND u.is_active = true
        AND p.visibility IN ('public', 'followers')
      ORDER BY p.created_at DESC
      LIMIT $2 OFFSET $3
    `;
    
    const result = await pool.query(query, [userId, limit, offset]);
    
    return result.rows.map(row => {
      const post = new Post(row);
      post.isLikedByUser = row.is_liked_by_user;
      return post;
    });
  }

  async update(updateData) {
    const fields = [];
    const values = [];
    let paramCount = 0;

    const allowedFields = ['content', 'image_urls', 'visibility', 'location_data', 'metadata'];
    
    Object.keys(updateData).forEach(key => {
      const dbKey = this.camelToSnake(key);
      if (allowedFields.includes(dbKey) && updateData[key] !== undefined) {
        fields.push(`${dbKey} = $${++paramCount}`);
        values.push(updateData[key]);
      }
    });

    if (fields.length === 0) {
      return this;
    }

    values.push(this.postId);
    const query = `
      UPDATE posts 
      SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP
      WHERE post_id = $${values.length}
      RETURNING *
    `;

    const result = await pool.query(query, values);
    const updatedPost = new Post(result.rows[0]);
    
    Object.assign(this, updatedPost);
    return this;
  }

  async delete() {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      // 関連データも削除
      await client.query('DELETE FROM likes WHERE post_id = $1', [this.postId]);
      await client.query('DELETE FROM comments WHERE post_id = $1', [this.postId]);
      await client.query('DELETE FROM post_tags WHERE post_id = $1', [this.postId]);
      await client.query('DELETE FROM posts WHERE post_id = $1', [this.postId]);
      
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async like(userId) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      // すでにいいねしているかチェック
      const existingLike = await client.query(
        'SELECT 1 FROM likes WHERE user_id = $1 AND post_id = $2',
        [userId, this.postId]
      );
      
      if (existingLike.rows.length > 0) {
        await client.query('ROLLBACK');
        throw new Error('Already liked');
      }
      
      // いいね追加
      await client.query(
        'INSERT INTO likes (user_id, post_id) VALUES ($1, $2)',
        [userId, this.postId]
      );
      
      await client.query('COMMIT');
      this.likesCount++;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async unlike(userId) {
    const result = await pool.query(
      'DELETE FROM likes WHERE user_id = $1 AND post_id = $2 RETURNING *',
      [userId, this.postId]
    );
    
    if (result.rows.length > 0) {
      this.likesCount = Math.max(0, this.likesCount - 1);
    }
  }

  async getTags() {
    const query = `
      SELECT t.* FROM tags t
      JOIN post_tags pt ON t.tag_id = pt.tag_id
      WHERE pt.post_id = $1
      ORDER BY t.name
    `;
    
    const result = await pool.query(query, [this.postId]);
    return result.rows;
  }

  async addTags(tagNames) {
    if (!tagNames || tagNames.length === 0) return;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      for (const tagName of tagNames) {
        // タグが存在しない場合は作成
        const tagResult = await client.query(
          `INSERT INTO tags (name) VALUES ($1) 
           ON CONFLICT (name) DO UPDATE SET usage_count = tags.usage_count + 1
           RETURNING tag_id`,
          [tagName.toLowerCase()]
        );
        
        const tagId = tagResult.rows[0].tag_id;
        
        // 投稿とタグの関連付け
        await client.query(
          `INSERT INTO post_tags (post_id, tag_id) VALUES ($1, $2)
           ON CONFLICT DO NOTHING`,
          [this.postId, tagId]
        );
      }
      
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  camelToSnake(str) {
    return str.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);
  }

  toJSON() {
    return {
      postId: this.postId,
      userId: this.userId,
      content: this.content,
      imageUrls: this.imageUrls,
      replyToPostId: this.replyToPostId,
      isRepost: this.isRepost,
      originalPostId: this.originalPostId,
      visibility: this.visibility,
      locationData: this.locationData,
      metadata: this.metadata,
      likesCount: this.likesCount,
      commentsCount: this.commentsCount,
      repostsCount: this.repostsCount,
      isLikedByUser: this.isLikedByUser,
      user: this.user?.toJSON(),
      createdAt: this.createdAt,
      updatedAt: this.updatedAt
    };
  }
}

module.exports = Post;
```

### Step 4: サービス層実装

#### 4-1. ユーザーサービス

```javascript
// src/services/userService.js
const User = require('../models/User');
const pool = require('../config/database');

class UserService {
  async createUser(userData) {
    // ユーザー名とメールの重複チェック
    const existingUser = await User.findByUsername(userData.username) ||
                         await User.findByEmail(userData.email);
    
    if (existingUser) {
      throw new Error('Username or email already exists');
    }

    return await User.create(userData);
  }

  async getUserProfile(userId, currentUserId = null) {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('User not found');
    }

    // プロフィール情報を拡張
    const profile = user.toJSON();
    
    // フォロー数を取得
    profile.followersCount = await user.getFollowerCount();
    profile.followingCount = await user.getFollowingCount();
    
    // 現在のユーザーとの関係
    if (currentUserId && currentUserId !== userId) {
      profile.isFollowing = await user.isFollowing(currentUserId);
      profile.isFollowedBy = await User.findById(currentUserId).then(
        currentUser => currentUser?.isFollowing(userId)
      );
    }

    return profile;
  }

  async followUser(followerId, followedId) {
    if (followerId === followedId) {
      throw new Error('Cannot follow yourself');
    }

    const follower = await User.findById(followerId);
    const followed = await User.findById(followedId);
    
    if (!follower || !followed) {
      throw new Error('User not found');
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      // すでにフォローしているかチェック
      const existingFollow = await client.query(
        'SELECT 1 FROM follows WHERE follower_id = $1 AND followed_id = $2',
        [followerId, followedId]
      );
      
      if (existingFollow.rows.length > 0) {
        await client.query('ROLLBACK');
        throw new Error('Already following');
      }
      
      // フォロー関係を作成
      await client.query(
        'INSERT INTO follows (follower_id, followed_id) VALUES ($1, $2)',
        [followerId, followedId]
      );
      
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async unfollowUser(followerId, followedId) {
    const result = await pool.query(
      'DELETE FROM follows WHERE follower_id = $1 AND followed_id = $2 RETURNING *',
      [followerId, followedId]
    );
    
    if (result.rows.length === 0) {
      throw new Error('Not following this user');
    }
  }

  async searchUsers(query, limit = 20, offset = 0) {
    const searchQuery = `
      SELECT user_id, username, display_name, avatar_url, bio, is_verified
      FROM users
      WHERE (username ILIKE $1 OR display_name ILIKE $1) 
        AND is_active = true
      ORDER BY 
        CASE WHEN username ILIKE $1 THEN 1 ELSE 2 END,
        username
      LIMIT $2 OFFSET $3
    `;
    
    const searchTerm = `%${query}%`;
    const result = await pool.query(searchQuery, [searchTerm, limit, offset]);
    
    return result.rows.map(row => new User(row));
  }

  async getUserStats(userId) {
    const query = `
      SELECT 
        u.user_id,
        COUNT(DISTINCT p.post_id) as posts_count,
        COUNT(DISTINCT f1.follow_id) as followers_count,
        COUNT(DISTINCT f2.follow_id) as following_count,
        COUNT(DISTINCT l.like_id) as total_likes_received
      FROM users u
      LEFT JOIN posts p ON u.user_id = p.user_id
      LEFT JOIN follows f1 ON u.user_id = f1.followed_id AND f1.status = 'active'
      LEFT JOIN follows f2 ON u.user_id = f2.follower_id AND f2.status = 'active'
      LEFT JOIN likes l ON p.post_id = l.post_id
      WHERE u.user_id = $1 AND u.is_active = true
      GROUP BY u.user_id
    `;
    
    const result = await pool.query(query, [userId]);
    
    if (result.rows.length === 0) {
      throw new Error('User not found');
    }
    
    const stats = result.rows[0];
    return {
      postsCount: parseInt(stats.posts_count),
      followersCount: parseInt(stats.followers_count),
      followingCount: parseInt(stats.following_count),
      totalLikesReceived: parseInt(stats.total_likes_received)
    };
  }
}

module.exports = new UserService();
```

### Step 5: フロントエンド統合

#### 5-1. UserProfile コンポーネント

```jsx
// frontend/src/components/UserProfile.jsx
import React, { useState, useEffect } from 'react';
import { Card, Button, Row, Col, Badge, Spinner, Alert } from 'react-bootstrap';
import { userApi } from '../services/userApi';
import PostList from './PostList';

const UserProfile = ({ userId, currentUserId }) => {
  const [user, setUser] = useState(null);
  const [posts, setPosts] = useState([]);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [followLoading, setFollowLoading] = useState(false);

  useEffect(() => {
    loadUserData();
  }, [userId]);

  const loadUserData = async () => {
    try {
      setLoading(true);
      const [userProfile, userPosts, userStats] = await Promise.all([
        userApi.getUserProfile(userId, currentUserId),
        userApi.getUserPosts(userId, currentUserId),
        userApi.getUserStats(userId)
      ]);

      setUser(userProfile);
      setPosts(userPosts);
      setStats(userStats);
    } catch (err) {
      setError('Failed to load user data: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleFollow = async () => {
    try {
      setFollowLoading(true);
      if (user.isFollowing) {
        await userApi.unfollowUser(userId);
        setUser(prev => ({
          ...prev,
          isFollowing: false,
          followersCount: prev.followersCount - 1
        }));
      } else {
        await userApi.followUser(userId);
        setUser(prev => ({
          ...prev,
          isFollowing: true,
          followersCount: prev.followersCount + 1
        }));
      }
    } catch (err) {
      setError('Failed to update follow status: ' + err.message);
    } finally {
      setFollowLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="text-center py-5">
        <Spinner animation="border" />
        <p>Loading profile...</p>
      </div>
    );
  }

  if (error) {
    return <Alert variant="danger">{error}</Alert>;
  }

  return (
    <div>
      {/* プロフィールヘッダー */}
      <Card className="mb-4">
        <Card.Body>
          <Row className="align-items-center">
            <Col md={3} className="text-center">
              <img
                src={user.avatarUrl || '/default-avatar.png'}
                alt={user.displayName}
                className="rounded-circle mb-3"
                style={{ width: '120px', height: '120px', objectFit: 'cover' }}
              />
            </Col>
            
            <Col md={9}>
              <div className="d-flex justify-content-between align-items-start mb-2">
                <div>
                  <h2 className="mb-1">
                    {user.displayName || user.username}
                    {user.isVerified && (
                      <Badge bg="primary" className="ms-2">
                        ✓ Verified
                      </Badge>
                    )}
                  </h2>
                  <p className="text-muted mb-2">@{user.username}</p>
                </div>
                
                {currentUserId !== userId && (
                  <Button
                    variant={user.isFollowing ? 'outline-primary' : 'primary'}
                    onClick={handleFollow}
                    disabled={followLoading}
                  >
                    {followLoading ? 'Loading...' : 
                     user.isFollowing ? 'Unfollow' : 'Follow'}
                  </Button>
                )}
              </div>
              
              {user.bio && (
                <p className="mb-3">{user.bio}</p>
              )}
              
              <div className="d-flex gap-4 mb-3">
                {user.location && (
                  <span className="text-muted">
                    📍 {user.location}
                  </span>
                )}
                {user.websiteUrl && (
                  <a 
                    href={user.websiteUrl} 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="text-decoration-none"
                  >
                    🔗 Website
                  </a>
                )}
                <span className="text-muted">
                  📅 Joined {new Date(user.createdAt).toLocaleDateString()}
                </span>
              </div>
              
              <Row className="text-center">
                <Col xs={3}>
                  <strong>{stats?.postsCount || 0}</strong>
                  <br />
                  <small className="text-muted">Posts</small>
                </Col>
                <Col xs={3}>
                  <strong>{user.followingCount || 0}</strong>
                  <br />
                  <small className="text-muted">Following</small>
                </Col>
                <Col xs={3}>
                  <strong>{user.followersCount || 0}</strong>
                  <br />
                  <small className="text-muted">Followers</small>
                </Col>
                <Col xs={3}>
                  <strong>{stats?.totalLikesReceived || 0}</strong>
                  <br />
                  <small className="text-muted">Likes</small>
                </Col>
              </Row>
            </Col>
          </Row>
        </Card.Body>
      </Card>

      {/* 投稿一覧 */}
      <h4>Posts</h4>
      <PostList 
        posts={posts} 
        currentUserId={currentUserId}
        onPostUpdate={loadUserData}
      />
    </div>
  );
};

export default UserProfile;
```

### Step 6: CloudFormationテンプレート

CloudFormationテンプレートは別ファイルで実装済みです。

### Step 7: テストと最適化

#### 7-1. データベーステスト

```javascript
// backend/tests/database.test.js
const pool = require('../src/config/database');
const User = require('../src/models/User');
const Post = require('../src/models/Post');

describe('Database Models', () => {
  beforeAll(async () => {
    // テスト用データベース準備
    await pool.query('BEGIN');
  });

  afterAll(async () => {
    // テストデータクリーンアップ
    await pool.query('ROLLBACK');
    await pool.end();
  });

  describe('User Model', () => {
    test('should create and retrieve user', async () => {
      const userData = {
        username: 'testuser',
        email: 'test@example.com',
        displayName: 'Test User'
      };

      const user = await User.create(userData);
      expect(user.username).toBe(userData.username);
      expect(user.userId).toBeDefined();

      const retrieved = await User.findById(user.userId);
      expect(retrieved.username).toBe(userData.username);
    });

    test('should handle follow relationships', async () => {
      const user1 = await User.create({
        username: 'user1',
        email: 'user1@example.com'
      });

      const user2 = await User.create({
        username: 'user2',
        email: 'user2@example.com'
      });

      // フォロー前
      const isFollowing = await user1.isFollowing(user2.userId);
      expect(isFollowing).toBe(false);

      // フォロー実行は別のサービスで実装
    });
  });
});
```

#### 7-2. パフォーマンス最適化

```sql
-- 追加インデックス作成
CREATE INDEX CONCURRENTLY idx_posts_user_created ON posts(user_id, created_at DESC);
CREATE INDEX CONCURRENTLY idx_posts_visibility_created ON posts(visibility, created_at DESC);
CREATE INDEX CONCURRENTLY idx_follows_follower_status ON follows(follower_id, status);
CREATE INDEX CONCURRENTLY idx_follows_followed_status ON follows(followed_id, status);
CREATE INDEX CONCURRENTLY idx_likes_post_user ON likes(post_id, user_id);
CREATE INDEX CONCURRENTLY idx_comments_post_created ON comments(post_id, created_at);

-- パーティショニング（大規模データ用）
-- 月別パーティション例
CREATE TABLE posts_y2024m01 PARTITION OF posts
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

## API エンドポイント

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/users/{userId}` | ユーザープロフィール取得 |
| PUT | `/users/{userId}` | プロフィール更新 |
| POST | `/users/{userId}/follow` | フォロー |
| DELETE | `/users/{userId}/follow` | アンフォロー |
| GET | `/users/{userId}/followers` | フォロワー一覧 |
| GET | `/users/{userId}/following` | フォロー中一覧 |
| GET | `/users/{userId}/stats` | ユーザー統計 |
| GET | `/timeline` | タイムライン取得 |

## 次のステップ

データベース機能が完成したら、**3.4-リアルタイム機能**に進みます。

次のセクションでは、WebSocket APIを使ったリアルタイム通信機能を実装します。

## 学習時間: 2時間

- 設計・準備: 30分
- データベース実装: 60分
- フロントエンド実装: 45分
- テスト・最適化: 15分