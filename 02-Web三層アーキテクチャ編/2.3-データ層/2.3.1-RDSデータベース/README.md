# 2.3.1 RDSデータベース

## 学習目標

このセクションでは、Amazon RDSを使用したエンタープライズグレードのリレーショナルデータベース構築と運用を学習し、高可用性・セキュリティ・パフォーマンスを兼ね備えたデータ層の実装方法を習得します。

### 習得できるスキル
- RDS Multi-AZ構成による高可用性設計
- Read Replicaを活用した読み取り性能スケーリング
- Secrets Managerによる認証情報の安全管理
- Parameter Groups によるデータベースチューニング
- CloudWatch によるパフォーマンス監視と最適化
- バックアップ・復旧戦略の実装

## 前提知識

### 必須の知識
- SQL の基本構文（SELECT、INSERT、UPDATE、DELETE）
- リレーショナルデータベースの基本概念
- AWS VPC とネットワーク設計（1.1.2セクション完了）
- CloudFormation の基本操作（1.1.1セクション完了）

### あると望ましい知識
- PostgreSQL または MySQL の運用経験
- データベース設計とER図作成
- インデックス設計とクエリ最適化
- データベースセキュリティベストプラクティス

## アーキテクチャ概要

### エンタープライズRDSアーキテクチャ

```
                    ┌─────────────────────┐
                    │   Application       │
                    │     Servers         │
                    │                     │
                    │ ┌─────────────────┐ │
                    │ │  Connection     │ │
                    │ │  Pooling        │ │
                    │ │  (PgBouncer)    │ │
                    │ └─────────────────┘ │
                    └─────────┬───────────┘
                              │
                    ┌─────────┼───────────┐
                    │         │           │
                    ▼         ▼           ▼
    ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
    │   Secrets       │ │   VPC    │ │   CloudWatch    │
    │   Manager       │ │ Security │ │   Monitoring    │
    │                 │ │  Groups  │ │                 │
    │ ┌─────────────┐ │ │┌────────┐│ │ ┌─────────────┐ │
    │ │DB Password  │ │ ││App->DB ││ │ │Performance  │ │
    │ │Rotation     │ │ ││Rules   ││ │ │Insights     │ │
    │ └─────────────┘ │ │└────────┘│ │ └─────────────┘ │
    └─────────────────┘ └──────────┘ └─────────────────┘
                              │
                              ▼
    ┌─────────────────────────────────────────────────────────┐
    │                 Primary AZ (ap-northeast-1a)           │
    │                                                         │
    │  ┌─────────────────────────────────────────────────┐   │
    │  │              RDS Primary Instance                │   │
    │  │                                                  │   │
    │  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │   │
    │  │  │ PostgreSQL  │  │  Parameter  │  │  KMS     │ │   │
    │  │  │   Engine    │  │   Groups    │  │Encryption│ │   │
    │  │  │             │  │             │  │          │ │   │
    │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │┌────────┐│ │   │
    │  │  │ │Database │ │  │ │Tuned    │ │  ││Custom  ││ │   │
    │  │  │ │Schema   │ │  │ │Settings │ │  ││KMS Key ││ │   │
    │  │  │ └─────────┘ │  │ └─────────┘ │  │└────────┘│ │   │
    │  │  └─────────────┘  └─────────────┘  └──────────┘ │   │
    │  └─────────────────────────────────────────────────┘   │
    └─────────────────────────────────────────────────────────┘
                              │
                              │ Synchronous Replication
                              ▼
    ┌─────────────────────────────────────────────────────────┐
    │                Standby AZ (ap-northeast-1c)             │
    │                                                         │
    │  ┌─────────────────────────────────────────────────┐   │
    │  │              RDS Standby Instance               │   │
    │  │            (Multi-AZ Failover)                  │   │
    │  │                                                  │   │
    │  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │   │
    │  │  │ PostgreSQL  │  │  Automatic  │  │  Same    │ │   │
    │  │  │Mirror Image │  │  Failover   │  │  Storage │ │   │
    │  │  │             │  │ (1-2 min)   │  │          │ │   │
    │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │┌────────┐│ │   │
    │  │  │ │Same Data│ │  │ │DNS      │ │  ││Encrypted││ │   │
    │  │  │ │Content  │ │  │ │Endpoint │ │  ││Storage  ││ │   │
    │  │  │ └─────────┘ │  │ └─────────┘ │  │└────────┘│ │   │
    │  │  └─────────────┘  └─────────────┘  └──────────┘ │   │
    │  └─────────────────────────────────────────────────┘   │
    └─────────────────────────────────────────────────────────┘
                              │
                              │ Asynchronous Replication
                              ▼
    ┌─────────────────────────────────────────────────────────┐
    │              Read Replica (ap-northeast-1d)             │
    │                                                         │
    │  ┌─────────────────────────────────────────────────┐   │
    │  │           RDS Read Replica Instance             │   │
    │  │          (Read-only Performance)                │   │
    │  │                                                  │   │
    │  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │   │
    │  │  │ PostgreSQL  │  │Read-optimized│  │Separate  │ │   │
    │  │  │Read-only    │  │Configuration │  │Endpoint  │ │   │
    │  │  │             │  │             │  │          │ │   │
    │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │┌────────┐│ │   │
    │  │  │ │Reporting│ │  │ │Analytics│ │  ││Different││ │   │
    │  │  │ │Queries  │ │  │ │Workloads │ │  ││Instance ││ │   │
    │  │  │ └─────────┘ │  │ └─────────┘ │  │└────────┘│ │   │
    │  │  └─────────────┘  └─────────────┘  └──────────┘ │   │
    │  └─────────────────────────────────────────────────┘   │
    └─────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **RDS Primary Instance**: メイン読み書きデータベース
- **Multi-AZ Standby**: 高可用性のための同期スタンバイ
- **Read Replica**: 読み取り専用レプリカ（性能分散）
- **Secrets Manager**: パスワードローテーション管理
- **Parameter Groups**: データベース最適化設定
- **CloudWatch**: 包括的監視とアラート

## ハンズオン手順

### ステップ1: データベース設計と初期データ準備

1. **データベーススキーマ設計**
```sql
-- migrations/001_initial_schema.sql
-- ユーザー管理システムのデータベーススキーマ

-- 拡張機能の有効化
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- ユーザーテーブル
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone_number VARCHAR(20),
    date_of_birth DATE,
    profile_image_url TEXT,
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP WITH TIME ZONE
);

-- ユーザープロファイルテーブル
CREATE TABLE user_profiles (
    profile_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    bio TEXT,
    location VARCHAR(255),
    website_url TEXT,
    social_links JSONB,
    preferences JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 投稿テーブル
CREATE TABLE posts (
    post_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    excerpt VARCHAR(1000),
    slug VARCHAR(255) UNIQUE,
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    featured_image_url TEXT,
    tags TEXT[],
    metadata JSONB,
    view_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    published_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- コメントテーブル
CREATE TABLE comments (
    comment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID REFERENCES posts(post_id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    parent_comment_id UUID REFERENCES comments(comment_id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'hidden', 'deleted')),
    like_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- インデックス作成（パフォーマンス最適化）
-- ユーザーテーブル
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_active ON users(is_active);
CREATE INDEX idx_users_created_at ON users(created_at);

-- 投稿テーブル
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_status ON posts(status);
CREATE INDEX idx_posts_published_at ON posts(published_at DESC);
CREATE INDEX idx_posts_slug ON posts(slug);
CREATE INDEX idx_posts_tags ON posts USING GIN(tags);
CREATE INDEX idx_posts_metadata ON posts USING GIN(metadata);

-- コメントテーブル
CREATE INDEX idx_comments_post_id ON comments(post_id);
CREATE INDEX idx_comments_user_id ON comments(user_id);
CREATE INDEX idx_comments_parent_id ON comments(parent_comment_id);
CREATE INDEX idx_comments_created_at ON comments(created_at);

-- 複合インデックス（よく使われるクエリパターン用）
CREATE INDEX idx_posts_user_status_published ON posts(user_id, status, published_at DESC);
CREATE INDEX idx_comments_post_status_created ON comments(post_id, status, created_at);

-- トリガー関数（updated_at自動更新）
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- トリガー設定
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_profiles_updated_at 
    BEFORE UPDATE ON user_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_posts_updated_at 
    BEFORE UPDATE ON posts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_comments_updated_at 
    BEFORE UPDATE ON comments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- サンプルデータ挿入
INSERT INTO users (email, username, password_hash, first_name, last_name, is_verified) VALUES
('admin@example.com', 'admin', '$2b$12$sample_hash_for_admin', '管理', 'ユーザー', true),
('user1@example.com', 'user1', '$2b$12$sample_hash_for_user1', '田中', '太郎', true),
('user2@example.com', 'user2', '$2b$12$sample_hash_for_user2', '佐藤', '花子', true);

-- パフォーマンス分析ビュー
CREATE VIEW user_post_stats AS
SELECT 
    u.user_id,
    u.username,
    u.email,
    COUNT(p.post_id) as total_posts,
    COUNT(CASE WHEN p.status = 'published' THEN 1 END) as published_posts,
    SUM(p.view_count) as total_views,
    SUM(p.like_count) as total_likes,
    MAX(p.published_at) as last_published_at
FROM users u
LEFT JOIN posts p ON u.user_id = p.user_id
GROUP BY u.user_id, u.username, u.email;
```

### ステップ2: CloudFormationによるRDS構築

先ほど確認したCloudFormationテンプレート（rds-database.yaml）を使用してRDSインスタンスをデプロイします。

1. **DynamoDBテーブル作成（VPC事前準備）**
```yaml
# vpc-for-rds.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'VPC setup for RDS database'

Parameters:
  ProjectName:
    Type: String
    Default: 'rds-database'
  
  EnvironmentName:
    Type: String
    Default: 'dev'

Resources:
  # VPC
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-vpc'

  # Private Subnets for Database
  DatabaseSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.10.0/24
      AvailabilityZone: !Select [0, !GetAZs '']
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-db-subnet-1'

  DatabaseSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.11.0/24
      AvailabilityZone: !Select [1, !GetAZs '']
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-db-subnet-2'

  # Public Subnets for Application
  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.1.0/24
      AvailabilityZone: !Select [0, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-public-subnet-1'

  # Internet Gateway
  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-igw'

  InternetGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      InternetGatewayId: !Ref InternetGateway
      VpcId: !Ref VPC

  # Route Tables
  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-public-rt'

  DefaultPublicRoute:
    Type: AWS::EC2::Route
    DependsOn: InternetGatewayAttachment
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  PublicSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PublicRouteTable
      SubnetId: !Ref PublicSubnet1

Outputs:
  VpcId:
    Description: 'VPC ID'
    Value: !Ref VPC
    Export:
      Name: !Sub '${AWS::StackName}-VpcId'
  
  DatabaseSubnetIds:
    Description: 'Database Subnet IDs'
    Value: !Join [',', [!Ref DatabaseSubnet1, !Ref DatabaseSubnet2]]
    Export:
      Name: !Sub '${AWS::StackName}-DatabaseSubnetIds'
```

### ステップ3: アプリケーション統合とデータベース操作

1. **Python データベース接続クラス**
```python
# src/database/connection.py
import os
import json
import logging
import psycopg2
import boto3
from psycopg2.pool import ThreadedConnectionPool
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)

class DatabaseManager:
    """RDS PostgreSQL接続管理クラス"""
    
    def __init__(self):
        self.secret_arn = os.environ.get('DATABASE_SECRET_ARN')
        self.db_endpoint = os.environ.get('DATABASE_ENDPOINT')
        self.db_port = int(os.environ.get('DATABASE_PORT', 5432))
        self.db_name = os.environ.get('DATABASE_NAME')
        self.pool: Optional[ThreadedConnectionPool] = None
        self._initialize_connection_pool()
    
    def _get_secret(self) -> Dict[str, Any]:
        """Secrets ManagerからDB認証情報を取得"""
        try:
            secrets_client = boto3.client('secretsmanager')
            response = secrets_client.get_secret_value(SecretId=self.secret_arn)
            return json.loads(response['SecretString'])
        except Exception as e:
            logger.error(f"Failed to retrieve database secret: {e}")
            raise
    
    def _initialize_connection_pool(self):
        """接続プールの初期化"""
        try:
            secret = self._get_secret()
            
            self.pool = ThreadedConnectionPool(
                minconn=2,
                maxconn=20,
                host=self.db_endpoint,
                port=self.db_port,
                database=self.db_name,
                user=secret['username'],
                password=secret['password'],
                cursor_factory=RealDictCursor,
                # 接続オプション
                application_name='web-application',
                connect_timeout=10,
                options='-c timezone=UTC'
            )
            logger.info("Database connection pool initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize connection pool: {e}")
            raise
    
    @contextmanager
    def get_connection(self):
        """接続プールから接続を取得するコンテキストマネージャー"""
        conn = None
        try:
            conn = self.pool.getconn()
            yield conn
        except Exception as e:
            if conn:
                conn.rollback()
            logger.error(f"Database operation failed: {e}")
            raise
        finally:
            if conn:
                self.pool.putconn(conn)
    
    @contextmanager
    def get_cursor(self, commit=False):
        """カーソルを取得するコンテキストマネージャー"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            try:
                yield cursor
                if commit:
                    conn.commit()
            except Exception as e:
                conn.rollback()
                raise e
            finally:
                cursor.close()
    
    def health_check(self) -> bool:
        """データベース接続のヘルスチェック"""
        try:
            with self.get_cursor() as cursor:
                cursor.execute("SELECT 1")
                result = cursor.fetchone()
                return result[0] == 1
        except Exception as e:
            logger.error(f"Database health check failed: {e}")
            return False
    
    def close_all_connections(self):
        """全接続を閉じる"""
        if self.pool:
            self.pool.closeall()
            logger.info("All database connections closed")

# グローバルインスタンス
db_manager = DatabaseManager()
```

2. **データアクセスレイヤー（DAO）**
```python
# src/database/dao/user_dao.py
from typing import List, Optional, Dict, Any
from uuid import UUID
import logging
from ..connection import db_manager

logger = logging.getLogger(__name__)

class UserDAO:
    """ユーザーデータアクセスオブジェクト"""
    
    def create_user(self, user_data: Dict[str, Any]) -> Optional[str]:
        """新規ユーザー作成"""
        try:
            with db_manager.get_cursor(commit=True) as cursor:
                cursor.execute("""
                    INSERT INTO users (email, username, password_hash, first_name, last_name, phone_number)
                    VALUES (%(email)s, %(username)s, %(password_hash)s, %(first_name)s, %(last_name)s, %(phone_number)s)
                    RETURNING user_id
                """, user_data)
                
                result = cursor.fetchone()
                user_id = str(result['user_id'])
                logger.info(f"User created successfully: {user_id}")
                return user_id
                
        except Exception as e:
            logger.error(f"Failed to create user: {e}")
            raise
    
    def get_user_by_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        """ユーザーID によるユーザー取得"""
        try:
            with db_manager.get_cursor() as cursor:
                cursor.execute("""
                    SELECT 
                        u.*,
                        up.bio,
                        up.location,
                        up.website_url,
                        up.social_links,
                        up.preferences
                    FROM users u
                    LEFT JOIN user_profiles up ON u.user_id = up.user_id
                    WHERE u.user_id = %s AND u.is_active = true
                """, (user_id,))
                
                result = cursor.fetchone()
                return dict(result) if result else None
                
        except Exception as e:
            logger.error(f"Failed to get user by ID {user_id}: {e}")
            raise
    
    def get_user_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """メールアドレスによるユーザー取得"""
        try:
            with db_manager.get_cursor() as cursor:
                cursor.execute("""
                    SELECT * FROM users 
                    WHERE email = %s AND is_active = true
                """, (email,))
                
                result = cursor.fetchone()
                return dict(result) if result else None
                
        except Exception as e:
            logger.error(f"Failed to get user by email {email}: {e}")
            raise
    
    def update_user(self, user_id: str, update_data: Dict[str, Any]) -> bool:
        """ユーザー情報更新"""
        try:
            # 更新可能フィールドのフィルタリング
            allowed_fields = {
                'first_name', 'last_name', 'phone_number', 
                'profile_image_url', 'is_verified'
            }
            filtered_data = {k: v for k, v in update_data.items() if k in allowed_fields}
            
            if not filtered_data:
                return False
            
            # 動的UPDATE文生成
            set_clause = ', '.join([f"{field} = %({field})s" for field in filtered_data.keys()])
            query = f"UPDATE users SET {set_clause} WHERE user_id = %(user_id)s"
            
            filtered_data['user_id'] = user_id
            
            with db_manager.get_cursor(commit=True) as cursor:
                cursor.execute(query, filtered_data)
                rows_affected = cursor.rowcount
                
                logger.info(f"User {user_id} updated: {rows_affected} rows affected")
                return rows_affected > 0
                
        except Exception as e:
            logger.error(f"Failed to update user {user_id}: {e}")
            raise
    
    def list_users(self, limit: int = 50, offset: int = 0, filters: Optional[Dict] = None) -> List[Dict[str, Any]]:
        """ユーザー一覧取得（ページネーション対応）"""
        try:
            where_conditions = ["u.is_active = true"]
            params = {'limit': limit, 'offset': offset}
            
            # フィルター条件追加
            if filters:
                if filters.get('verified_only'):
                    where_conditions.append("u.is_verified = true")
                if filters.get('search_term'):
                    where_conditions.append("""
                        (u.username ILIKE %(search_term)s 
                         OR u.first_name ILIKE %(search_term)s 
                         OR u.last_name ILIKE %(search_term)s)
                    """)
                    params['search_term'] = f"%{filters['search_term']}%"
            
            where_clause = " AND ".join(where_conditions)
            
            with db_manager.get_cursor() as cursor:
                cursor.execute(f"""
                    SELECT 
                        u.user_id,
                        u.email,
                        u.username,
                        u.first_name,
                        u.last_name,
                        u.is_verified,
                        u.created_at,
                        u.last_login_at,
                        COUNT(p.post_id) as post_count
                    FROM users u
                    LEFT JOIN posts p ON u.user_id = p.user_id
                    WHERE {where_clause}
                    GROUP BY u.user_id
                    ORDER BY u.created_at DESC
                    LIMIT %(limit)s OFFSET %(offset)s
                """, params)
                
                results = cursor.fetchall()
                return [dict(row) for row in results]
                
        except Exception as e:
            logger.error(f"Failed to list users: {e}")
            raise
    
    def update_last_login(self, user_id: str) -> bool:
        """最終ログイン時刻更新"""
        try:
            with db_manager.get_cursor(commit=True) as cursor:
                cursor.execute("""
                    UPDATE users 
                    SET last_login_at = CURRENT_TIMESTAMP 
                    WHERE user_id = %s
                """, (user_id,))
                
                return cursor.rowcount > 0
                
        except Exception as e:
            logger.error(f"Failed to update last login for user {user_id}: {e}")
            raise
    
    def get_user_statistics(self) -> Dict[str, Any]:
        """ユーザー統計情報取得"""
        try:
            with db_manager.get_cursor() as cursor:
                cursor.execute("""
                    SELECT 
                        COUNT(*) as total_users,
                        COUNT(CASE WHEN is_verified THEN 1 END) as verified_users,
                        COUNT(CASE WHEN last_login_at > CURRENT_TIMESTAMP - INTERVAL '30 days' THEN 1 END) as active_users,
                        COUNT(CASE WHEN created_at > CURRENT_TIMESTAMP - INTERVAL '7 days' THEN 1 END) as new_users_week
                    FROM users 
                    WHERE is_active = true
                """)
                
                result = cursor.fetchone()
                return dict(result)
                
        except Exception as e:
            logger.error(f"Failed to get user statistics: {e}")
            raise

# グローバルインスタンス
user_dao = UserDAO()
```

### ステップ4: デプロイと初期設定

1. **デプロイスクリプト**
```bash
#!/bin/bash
# scripts/deploy-rds.sh

set -e

PROJECT_NAME="rds-database"
ENVIRONMENT="dev"
REGION="ap-northeast-1"

echo "Deploying RDS infrastructure..."

# VPCスタックデプロイ
echo "1. Deploying VPC stack..."
aws cloudformation deploy \
  --template-file cloudformation/vpc-for-rds.yaml \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-vpc \
  --parameter-overrides \
    ProjectName=${PROJECT_NAME} \
    EnvironmentName=${ENVIRONMENT} \
  --region ${REGION}

# VPC情報取得
VPC_ID=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-vpc \
  --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' \
  --output text)

SUBNET_IDS=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-vpc \
  --query 'Stacks[0].Outputs[?OutputKey==`DatabaseSubnetIds`].OutputValue' \
  --output text)

echo "VPC ID: $VPC_ID"
echo "Database Subnet IDs: $SUBNET_IDS"

# RDSスタックデプロイ
echo "2. Deploying RDS stack..."
aws cloudformation deploy \
  --template-file cloudformation/rds-database.yaml \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-rds \
  --parameter-overrides \
    ProjectName=${PROJECT_NAME} \
    EnvironmentName=${ENVIRONMENT} \
    VpcId=${VPC_ID} \
    DatabaseSubnetIds=${SUBNET_IDS} \
    DatabaseEngine=postgres \
    DatabaseInstanceClass=db.t3.micro \
    MultiAZ=false \
    CreateReadReplica=false \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ${REGION}

# データベース接続情報取得
DB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-rds \
  --query 'Stacks[0].Outputs[?OutputKey==`DatabaseEndpoint`].OutputValue' \
  --output text)

DB_SECRET_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-rds \
  --query 'Stacks[0].Outputs[?OutputKey==`DatabaseSecretArn`].OutputValue' \
  --output text)

echo "Deployment completed!"
echo "Database Endpoint: $DB_ENDPOINT"
echo "Secret ARN: $DB_SECRET_ARN"

# データベース初期化スクリプト実行
echo "3. Initializing database schema..."
python scripts/init_database.py \
  --endpoint "$DB_ENDPOINT" \
  --secret-arn "$DB_SECRET_ARN" \
  --sql-file migrations/001_initial_schema.sql

echo "Database deployment and initialization completed successfully!"
```

2. **データベース初期化スクリプト**
```python
# scripts/init_database.py
import argparse
import json
import boto3
import psycopg2
import logging
from pathlib import Path

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def get_database_credentials(secret_arn):
    """Secrets Managerからデータベース認証情報を取得"""
    secrets_client = boto3.client('secretsmanager')
    response = secrets_client.get_secret_value(SecretId=secret_arn)
    return json.loads(response['SecretString'])

def execute_sql_file(connection, sql_file_path):
    """SQLファイルを実行"""
    with open(sql_file_path, 'r', encoding='utf-8') as file:
        sql_content = file.read()
    
    # セミコロンで文分割して実行
    statements = [stmt.strip() for stmt in sql_content.split(';') if stmt.strip()]
    
    with connection.cursor() as cursor:
        for i, statement in enumerate(statements):
            try:
                logger.info(f"Executing statement {i+1}/{len(statements)}")
                cursor.execute(statement)
                connection.commit()
            except Exception as e:
                logger.error(f"Failed to execute statement {i+1}: {e}")
                logger.error(f"Statement: {statement[:100]}...")
                connection.rollback()
                raise

def main():
    parser = argparse.ArgumentParser(description='Initialize RDS database')
    parser.add_argument('--endpoint', required=True, help='RDS endpoint')
    parser.add_argument('--secret-arn', required=True, help='Secrets Manager ARN')
    parser.add_argument('--sql-file', required=True, help='SQL file to execute')
    parser.add_argument('--database', default='postgres', help='Database name')
    
    args = parser.parse_args()
    
    try:
        # 認証情報取得
        logger.info("Retrieving database credentials...")
        credentials = get_database_credentials(args.secret_arn)
        
        # データベース接続
        logger.info(f"Connecting to database at {args.endpoint}...")
        connection = psycopg2.connect(
            host=args.endpoint,
            port=5432,
            database=args.database,
            user=credentials['username'],
            password=credentials['password']
        )
        
        # SQLファイル実行
        logger.info(f"Executing SQL file: {args.sql_file}")
        execute_sql_file(connection, args.sql_file)
        
        logger.info("Database initialization completed successfully!")
        
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")
        exit(1)
    finally:
        if 'connection' in locals():
            connection.close()

if __name__ == '__main__':
    main()
```

## 検証方法

### 1. データベース接続テスト
```bash
# 接続テスト
python -c "
from src.database.connection import db_manager
print('Health check:', db_manager.health_check())
"
```

### 2. CRUD操作テスト
```python
# test_database_operations.py
from src.database.dao.user_dao import user_dao

# ユーザー作成テスト
user_data = {
    'email': 'test@example.com',
    'username': 'testuser',
    'password_hash': 'hashed_password',
    'first_name': 'Test',
    'last_name': 'User'
}

user_id = user_dao.create_user(user_data)
print(f"Created user ID: {user_id}")

# ユーザー取得テスト
user = user_dao.get_user_by_id(user_id)
print(f"Retrieved user: {user}")

# ユーザー一覧テスト
users = user_dao.list_users(limit=10)
print(f"Total users: {len(users)}")
```

### 3. パフォーマンス監視
```bash
# CloudWatchメトリクス確認
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=rds-database-dev-database \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Average
```

## トラブルシューティング

### よくある問題と解決策

#### 1. 接続タイムアウト
**症状**: データベース接続が頻繁にタイムアウト
**解決策**:
- セキュリティグループの確認
- 接続プール設定の最適化
- ネットワーク遅延の調査

#### 2. スロークエリ
**症状**: クエリ実行時間が長い
**解決策**:
```sql
-- スロークエリ特定
SELECT query, mean_time, calls, total_time
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;

-- インデックス使用状況確認
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

#### 3. 接続数上限
**症状**: too many connections エラー
**解決策**:
- 接続プール設定の見直し
- アプリケーション側の接続管理改善
- max_connections パラメータ調整

## 学習リソース

### AWS公式ドキュメント
- [Amazon RDS ユーザーガイド](https://docs.aws.amazon.com/rds/latest/userguide/)
- [RDS Performance Insights ユーザーガイド](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.html)
- [AWS Secrets Manager ユーザーガイド](https://docs.aws.amazon.com/secretsmanager/latest/userguide/)

### 追加学習教材
- [PostgreSQL 公式ドキュメント](https://www.postgresql.org/docs/)
- [Database Design Best Practices](https://aws.amazon.com/rds/mysql/resources/)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **VPC分離**: プライベートサブネット配置
2. **暗号化**: 保存時・転送時暗号化の実装
3. **アクセス制御**: IAMとSecrets Manager連携
4. **監査ログ**: CloudTrailとデータベースログ

### コスト最適化
1. **右サイジング**: ワークロードに適したインスタンス選択
2. **Reserved Instance**: 予測可能な負荷での活用
3. **ストレージ最適化**: GP3使用とAutoScaling
4. **バックアップ最適化**: 適切な保持期間設定

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatch監視とPerformance Insights
- **セキュリティの柱**: VPC・IAM・暗号化・Secrets Manager
- **信頼性の柱**: Multi-AZ・Read Replica・自動バックアップ
- **パフォーマンス効率の柱**: インスタンス最適化・パラメータチューニング
- **コスト最適化の柱**: リソース監視・予約インスタンス・自動スケーリング

## 次のステップ

### 推奨される学習パス
1. **2.3.2 DynamoDB**: NoSQLデータベース設計
2. **3.1.1 ユーザー管理システム**: 認証・認可機能実装
3. **3.1.2 データ操作API**: 高度なデータベース操作
4. **6.2.1 APM実装**: アプリケーション監視強化

### 発展的な機能
1. **Aurora Serverless**: オンデマンドスケーリング
2. **Database Migration**: 他DBMSからの移行
3. **Data API**: HTTP経由でのデータベースアクセス
4. **Query Insights**: 高度なパフォーマンス分析

### 実践プロジェクトのアイデア
1. **Eコマースプラットフォーム**: 複雑なリレーション設計
2. **CRM システム**: 大規模データ処理
3. **分析プラットフォーム**: Read Replica活用
4. **マルチテナントSaaS**: スキーマ分離設計