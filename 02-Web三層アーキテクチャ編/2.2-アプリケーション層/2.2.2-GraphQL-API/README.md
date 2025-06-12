# 2.2.2 GraphQL-API

## 学習目標

このセクションでは、GraphQLを使用して効率的で柔軟なAPIを構築し、AWS AppSyncまたはLambda + Apollo Serverによる実装を通じて、モダンなAPI開発手法を習得します。

### 習得できるスキル
- GraphQL の基本概念とクエリ言語
- AWS AppSync による GraphQL API 構築
- Lambda + Apollo Server による GraphQL 実装
- リアルタイムサブスクリプション機能
- データソース統合（DynamoDB、RDS、HTTP）
- GraphQL スキーマ設計とベストプラクティス
- パフォーマンス最適化とキャッシュ戦略

## 前提知識

### 必須の知識
- GraphQL の基本概念
- RESTful API の理解（2.2.1セクション完了）
- JavaScript/TypeScript の基本構文
- AWS Lambda と DynamoDB の基本操作

### あると望ましい知識
- Apollo Client/Server の経験
- React/Vue.js でのデータフェッチング
- リアルタイム通信（WebSocket）の理解
- スキーマ駆動開発の概念

## アーキテクチャ概要

### AWS AppSync GraphQL アーキテクチャ

```
                     ┌─────────────────────┐
                     │    Client Apps      │
                     │ (Web/Mobile/React)  │
                     └─────────┬───────────┘
                               │ GraphQL Operations
                               │ (Query/Mutation/Subscription)
                               │
                     ┌─────────┼───────────┐
                     │         │           │
                     ▼         ▼           ▼
          ┌─────────────────────────────────────────┐
          │              CloudFront                 │
          │       (Global GraphQL CDN)              │
          │                                         │
          │  ┌─────────────────────────────────┐   │
          │  │      Cache Behaviors            │   │
          │  │   - GraphQL: Custom Headers    │   │
          │  │   - Schema: Long Cache          │   │
          │  └─────────────────────────────────┘   │
          └─────────────────┬───────────────────────┘
                            │
                            ▼
          ┌─────────────────────────────────────────┐
          │             AWS AppSync                 │
          │         (GraphQL Service)               │
          │                                         │
          │  ┌─────────────────────────────────┐   │
          │  │        GraphQL Schema           │   │
          │  │                                 │   │
          │  │  type User {                    │   │
          │  │    id: ID!                      │   │
          │  │    email: String!               │   │
          │  │    posts: [Post]                │   │
          │  │  }                              │   │
          │  │                                 │   │
          │  │  type Post {                    │   │
          │  │    id: ID!                      │   │
          │  │    title: String!               │   │
          │  │    author: User                 │   │
          │  │  }                              │   │
          │  │                                 │   │
          │  │  type Query {                   │   │
          │  │    getUser(id: ID!): User       │   │
          │  │    listPosts: [Post]            │   │
          │  │  }                              │   │
          │  │                                 │   │
          │  │  type Mutation {                │   │
          │  │    createUser(input: UserInput): User │   │
          │  │    createPost(input: PostInput): Post │   │
          │  │  }                              │   │
          │  │                                 │   │
          │  │  type Subscription {            │   │
          │  │    onCreatePost: Post           │   │
          │  │    onUpdateUser(id: ID!): User  │   │
          │  │  }                              │   │
          │  └─────────────────────────────────┘   │
          └─────────────────┬───────────────────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              ▼             ▼             ▼
    ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
    │   Direct        │ │ Lambda   │ │   HTTP          │
    │   DynamoDB      │ │Resolvers │ │   Data Source   │
    │   Resolvers     │ │          │ │                 │
    │                 │ │┌────────┐│ │ ┌─────────────┐ │
    │ ┌─────────────┐ │ ││Custom  ││ │ │   REST API  │ │
    │ │   Users     │ │ ││Business││ │ │   Services  │ │
    │ │   Table     │ │ ││Logic   ││ │ │             │ │
    │ │             │ │ │└────────┘│ │ └─────────────┘ │
    │ └─────────────┘ │ └──────────┘ └─────────────────┘
    │                 │      │              │
    │ ┌─────────────┐ │      │              │
    │ │   Posts     │ │      │              │
    │ │   Table     │ │      ▼              ▼
    │ │             │ │ ┌──────────┐ ┌─────────────────┐
    │ └─────────────┘ │ │Additional│ │   External      │
    └─────────────────┘ │DynamoDB  │ │   APIs          │
                        │Tables    │ │   (Microservices)│
                        └──────────┘ └─────────────────┘
                             │              │
                             ▼              ▼
          ┌─────────────────────────────────────────┐
          │            CloudWatch                   │
          │       (Monitoring & Logs)               │
          │                                         │
          │  ┌─────────────────────────────────┐   │
          │  │      GraphQL Metrics            │   │
          │  │   - Request Count               │   │
          │  │   - Error Rate                  │   │
          │  │   - Latency by Field            │   │
          │  │   - Subscription Connections    │   │
          │  └─────────────────────────────────┘   │
          └─────────────────────────────────────────┘
```

### 主要コンポーネント
- **AWS AppSync**: マネージド GraphQL サービス
- **GraphQL Schema**: データ構造とオペレーション定義
- **Resolvers**: データソースとのマッピング機能
- **Data Sources**: DynamoDB、Lambda、HTTP エンドポイント
- **Real-time Subscriptions**: WebSocket ベースのリアルタイム通信

## ハンズオン手順

### ステップ1: GraphQL スキーマ設計

1. **基本スキーマ定義**
```graphql
# graphql/schema.graphql
type User {
  id: ID!
  email: String!
  username: String!
  firstName: String
  lastName: String
  bio: String
  avatarUrl: String
  posts: [Post] @connection(name: "UserPosts")
  createdAt: AWSDateTime!
  updatedAt: AWSDateTime!
}

type Post {
  id: ID!
  title: String!
  content: String!
  excerpt: String
  status: PostStatus!
  author: User! @connection(name: "UserPosts")
  tags: [String]
  viewCount: Int
  createdAt: AWSDateTime!
  updatedAt: AWSDateTime!
}

enum PostStatus {
  DRAFT
  PUBLISHED
  ARCHIVED
}

input UserInput {
  email: String!
  username: String!
  firstName: String
  lastName: String
  bio: String
  avatarUrl: String
}

input PostInput {
  title: String!
  content: String!
  excerpt: String
  authorId: ID!
  tags: [String]
  status: PostStatus = DRAFT
}

input UpdateUserInput {
  id: ID!
  username: String
  firstName: String
  lastName: String
  bio: String
  avatarUrl: String
}

input UpdatePostInput {
  id: ID!
  title: String
  content: String
  excerpt: String
  tags: [String]
  status: PostStatus
}

# GraphQL Operations
type Query {
  # User queries
  getUser(id: ID!): User
  getUserByEmail(email: String!): User
  listUsers(limit: Int = 20, nextToken: String): UserConnection
  
  # Post queries
  getPost(id: ID!): Post
  listPosts(limit: Int = 20, nextToken: String): PostConnection
  listPostsByAuthor(authorId: ID!, limit: Int = 20, nextToken: String): PostConnection
  listPostsByStatus(status: PostStatus!, limit: Int = 20, nextToken: String): PostConnection
  
  # Search
  searchPosts(query: String!, limit: Int = 20): [Post]
}

type Mutation {
  # User mutations
  createUser(input: UserInput!): User
  updateUser(input: UpdateUserInput!): User
  deleteUser(id: ID!): User
  
  # Post mutations
  createPost(input: PostInput!): Post
  updatePost(input: UpdatePostInput!): Post
  deletePost(id: ID!): Post
  incrementPostViewCount(id: ID!): Post
}

type Subscription {
  # Real-time subscriptions
  onCreatePost(authorId: ID): Post
    @aws_subscribe(mutations: ["createPost"])
  
  onUpdatePost(id: ID): Post
    @aws_subscribe(mutations: ["updatePost"])
  
  onDeletePost(id: ID): Post
    @aws_subscribe(mutations: ["deletePost"])
  
  onCreateUser: User
    @aws_subscribe(mutations: ["createUser"])
}

# Connection types for pagination
type UserConnection {
  items: [User]
  nextToken: String
}

type PostConnection {
  items: [Post]
  nextToken: String
}

# Custom scalars
scalar AWSDateTime
scalar AWSJSON
scalar AWSEmail
scalar AWSURL
```

### ステップ2: AWS AppSync 実装

1. **CloudFormation テンプレート**
```yaml
# cloudformation/appsync-api.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'AWS AppSync GraphQL API'

Parameters:
  ProjectName:
    Type: String
    Default: 'graphql-api'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
    AllowedValues: [dev, staging, prod]

Resources:
  # AppSync GraphQL API
  GraphQLApi:
    Type: AWS::AppSync::GraphQLApi
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-api'
      AuthenticationType: API_KEY
      AdditionalAuthenticationProviders:
        - AuthenticationType: AWS_IAM
        - AuthenticationType: AMAZON_COGNITO_USER_POOLS
          UserPoolConfig:
            UserPoolId: !Ref UserPool
            AwsRegion: !Ref AWS::Region
      LogConfig:
        CloudWatchLogsRoleArn: !GetAtt AppSyncLogsRole.Arn
        ExcludeVerboseContent: false
        FieldLogLevel: ALL
      XrayEnabled: true
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # API Key for development
  GraphQLApiKey:
    Type: AWS::AppSync::ApiKey
    Properties:
      ApiId: !GetAtt GraphQLApi.ApiId
      Description: 'API Key for GraphQL API'
      Expires: !Ref ApiKeyExpiration

  # GraphQL Schema
  GraphQLSchema:
    Type: AWS::AppSync::GraphQLSchema
    Properties:
      ApiId: !GetAtt GraphQLApi.ApiId
      Definition: |
        type User {
          id: ID!
          email: String!
          username: String!
          firstName: String
          lastName: String
          bio: String
          avatarUrl: String
          posts: [Post]
          createdAt: AWSDateTime!
          updatedAt: AWSDateTime!
        }

        type Post {
          id: ID!
          title: String!
          content: String!
          excerpt: String
          status: PostStatus!
          authorId: ID!
          author: User
          tags: [String]
          viewCount: Int
          createdAt: AWSDateTime!
          updatedAt: AWSDateTime!
        }

        enum PostStatus {
          DRAFT
          PUBLISHED
          ARCHIVED
        }

        input UserInput {
          email: String!
          username: String!
          firstName: String
          lastName: String
          bio: String
          avatarUrl: String
        }

        input PostInput {
          title: String!
          content: String!
          excerpt: String
          authorId: ID!
          tags: [String]
          status: PostStatus = DRAFT
        }

        type Query {
          getUser(id: ID!): User
          listUsers(limit: Int = 20, nextToken: String): UserConnection
          getPost(id: ID!): Post
          listPosts(limit: Int = 20, nextToken: String): PostConnection
        }

        type Mutation {
          createUser(input: UserInput!): User
          createPost(input: PostInput!): Post
          incrementPostViewCount(id: ID!): Post
        }

        type Subscription {
          onCreatePost: Post
          @aws_subscribe(mutations: ["createPost"])
        }

        type UserConnection {
          items: [User]
          nextToken: String
        }

        type PostConnection {
          items: [Post]
          nextToken: String
        }

  # DynamoDB Data Sources
  UsersDataSource:
    Type: AWS::AppSync::DataSource
    Properties:
      ApiId: !GetAtt GraphQLApi.ApiId
      Name: UsersDataSource
      Type: AMAZON_DYNAMODB
      ServiceRoleArn: !GetAtt AppSyncDynamoDBRole.Arn
      DynamoDBConfig:
        TableName: !Ref UsersTable
        AwsRegion: !Ref AWS::Region

  PostsDataSource:
    Type: AWS::AppSync::DataSource
    Properties:
      ApiId: !GetAtt GraphQLApi.ApiId
      Name: PostsDataSource
      Type: AMAZON_DYNAMODB
      ServiceRoleArn: !GetAtt AppSyncDynamoDBRole.Arn
      DynamoDBConfig:
        TableName: !Ref PostsTable
        AwsRegion: !Ref AWS::Region

  # Lambda Data Source for complex operations
  LambdaDataSource:
    Type: AWS::AppSync::DataSource
    Properties:
      ApiId: !GetAtt GraphQLApi.ApiId
      Name: LambdaDataSource
      Type: AWS_LAMBDA
      ServiceRoleArn: !GetAtt AppSyncLambdaRole.Arn
      LambdaConfig:
        LambdaFunctionArn: !GetAtt GraphQLResolverFunction.Arn

  # Resolvers
  GetUserResolver:
    Type: AWS::AppSync::Resolver
    Properties:
      ApiId: !GetAtt GraphQLApi.ApiId
      TypeName: Query
      FieldName: getUser
      DataSourceName: !GetAtt UsersDataSource.Name
      RequestMappingTemplate: |
        {
          "version": "2017-02-28",
          "operation": "GetItem",
          "key": {
            "id": $util.dynamodb.toDynamoDBJson($ctx.args.id)
          }
        }
      ResponseMappingTemplate: |
        $util.toJson($ctx.result)

  CreateUserResolver:
    Type: AWS::AppSync::Resolver
    Properties:
      ApiId: !GetAtt GraphQLApi.ApiId
      TypeName: Mutation
      FieldName: createUser
      DataSourceName: !GetAtt UsersDataSource.Name
      RequestMappingTemplate: |
        #set($id = $util.autoId())
        #set($now = $util.time.nowISO8601())
        {
          "version": "2017-02-28",
          "operation": "PutItem",
          "key": {
            "id": $util.dynamodb.toDynamoDBJson($id)
          },
          "attributeValues": {
            "id": $util.dynamodb.toDynamoDBJson($id),
            "email": $util.dynamodb.toDynamoDBJson($ctx.args.input.email),
            "username": $util.dynamodb.toDynamoDBJson($ctx.args.input.username),
            "firstName": $util.dynamodb.toDynamoDBJson($ctx.args.input.firstName),
            "lastName": $util.dynamodb.toDynamoDBJson($ctx.args.input.lastName),
            "bio": $util.dynamodb.toDynamoDBJson($ctx.args.input.bio),
            "avatarUrl": $util.dynamodb.toDynamoDBJson($ctx.args.input.avatarUrl),
            "createdAt": $util.dynamodb.toDynamoDBJson($now),
            "updatedAt": $util.dynamodb.toDynamoDBJson($now)
          },
          "condition": {
            "expression": "attribute_not_exists(id)"
          }
        }
      ResponseMappingTemplate: |
        $util.toJson($ctx.result)

  # Lambda Resolver for complex operations
  IncrementPostViewCountResolver:
    Type: AWS::AppSync::Resolver
    Properties:
      ApiId: !GetAtt GraphQLApi.ApiId
      TypeName: Mutation
      FieldName: incrementPostViewCount
      DataSourceName: !GetAtt LambdaDataSource.Name
      RequestMappingTemplate: |
        {
          "version": "2017-02-28",
          "operation": "Invoke",
          "payload": {
            "field": "incrementPostViewCount",
            "arguments": $util.toJson($ctx.args)
          }
        }
      ResponseMappingTemplate: |
        $util.toJson($ctx.result)

  # DynamoDB Tables
  UsersTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-${EnvironmentName}-users'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: id
          AttributeType: S
        - AttributeName: email
          AttributeType: S
      KeySchema:
        - AttributeName: id
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: email-index
          KeySchema:
            - AttributeName: email
              KeyType: HASH
          Projection:
            ProjectionType: ALL
      StreamSpecification:
        StreamViewType: NEW_AND_OLD_IMAGES

  PostsTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-${EnvironmentName}-posts'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: id
          AttributeType: S
        - AttributeName: authorId
          AttributeType: S
        - AttributeName: status
          AttributeType: S
        - AttributeName: createdAt
          AttributeType: S
      KeySchema:
        - AttributeName: id
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: author-index
          KeySchema:
            - AttributeName: authorId
              KeyType: HASH
            - AttributeName: createdAt
              KeyType: RANGE
          Projection:
            ProjectionType: ALL
        - IndexName: status-index
          KeySchema:
            - AttributeName: status
              KeyType: HASH
            - AttributeName: createdAt
              KeyType: RANGE
          Projection:
            ProjectionType: ALL

  # Lambda Function for complex resolvers
  GraphQLResolverFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-graphql-resolver'
      Runtime: nodejs18.x
      Handler: index.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        ZipFile: |
          const AWS = require('aws-sdk');
          const dynamodb = new AWS.DynamoDB.DocumentClient();
          
          exports.handler = async (event) => {
            const { field, arguments: args } = event;
            
            switch (field) {
              case 'incrementPostViewCount':
                return await incrementPostViewCount(args.id);
              default:
                throw new Error(`Unknown field: ${field}`);
            }
          };
          
          async function incrementPostViewCount(postId) {
            const params = {
              TableName: process.env.POSTS_TABLE,
              Key: { id: postId },
              UpdateExpression: 'ADD viewCount :inc SET updatedAt = :now',
              ExpressionAttributeValues: {
                ':inc': 1,
                ':now': new Date().toISOString()
              },
              ReturnValues: 'ALL_NEW'
            };
            
            const result = await dynamodb.update(params).promise();
            return result.Attributes;
          }
      Environment:
        Variables:
          POSTS_TABLE: !Ref PostsTable
      Timeout: 30

  # IAM Roles
  AppSyncDynamoDBRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: appsync.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: DynamoDBAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - dynamodb:GetItem
                  - dynamodb:PutItem
                  - dynamodb:UpdateItem
                  - dynamodb:DeleteItem
                  - dynamodb:Query
                  - dynamodb:Scan
                Resource:
                  - !GetAtt UsersTable.Arn
                  - !GetAtt PostsTable.Arn
                  - !Sub '${UsersTable.Arn}/index/*'
                  - !Sub '${PostsTable.Arn}/index/*'

  AppSyncLambdaRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: appsync.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: LambdaInvoke
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action: lambda:InvokeFunction
                Resource: !GetAtt GraphQLResolverFunction.Arn

Outputs:
  GraphQLApiEndpoint:
    Description: 'GraphQL API Endpoint'
    Value: !GetAtt GraphQLApi.GraphQLUrl
    Export:
      Name: !Sub '${AWS::StackName}-GraphQLEndpoint'
  
  GraphQLApiKey:
    Description: 'GraphQL API Key'
    Value: !GetAtt GraphQLApiKey.ApiKey
    Export:
      Name: !Sub '${AWS::StackName}-GraphQLApiKey'
```

### ステップ3: React クライアント実装

1. **Apollo Client セットアップ**
```typescript
// src/graphql/apollo-client.ts
import { ApolloClient, InMemoryCache, createHttpLink, from } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';
import { onError } from '@apollo/client/link/error';

const httpLink = createHttpLink({
  uri: process.env.REACT_APP_GRAPHQL_ENDPOINT,
});

const authLink = setContext((_, { headers }) => {
  const token = localStorage.getItem('api-key');
  return {
    headers: {
      ...headers,
      'x-api-key': token || process.env.REACT_APP_GRAPHQL_API_KEY,
    }
  };
});

const errorLink = onError(({ graphQLErrors, networkError, operation, forward }) => {
  if (graphQLErrors) {
    graphQLErrors.forEach(({ message, locations, path }) => {
      console.error(
        `GraphQL error: Message: ${message}, Location: ${locations}, Path: ${path}`
      );
    });
  }

  if (networkError) {
    console.error(`Network error: ${networkError}`);
  }
});

export const apolloClient = new ApolloClient({
  link: from([errorLink, authLink, httpLink]),
  cache: new InMemoryCache({
    typePolicies: {
      User: {
        fields: {
          posts: {
            merge(existing = [], incoming) {
              return [...existing, ...incoming];
            },
          },
        },
      },
      Query: {
        fields: {
          listPosts: {
            keyArgs: [],
            merge(existing, incoming) {
              return {
                ...incoming,
                items: [...(existing?.items || []), ...(incoming?.items || [])],
              };
            },
          },
        },
      },
    },
  }),
  defaultOptions: {
    watchQuery: {
      errorPolicy: 'all',
    },
    query: {
      errorPolicy: 'all',
    },
  },
});
```

2. **GraphQL Operations**
```typescript
// src/graphql/operations.ts
import { gql } from '@apollo/client';

// Fragments
export const USER_FRAGMENT = gql`
  fragment UserFields on User {
    id
    email
    username
    firstName
    lastName
    bio
    avatarUrl
    createdAt
    updatedAt
  }
`;

export const POST_FRAGMENT = gql`
  fragment PostFields on Post {
    id
    title
    content
    excerpt
    status
    authorId
    tags
    viewCount
    createdAt
    updatedAt
  }
`;

// Queries
export const GET_USER = gql`
  ${USER_FRAGMENT}
  query GetUser($id: ID!) {
    getUser(id: $id) {
      ...UserFields
      posts {
        ...PostFields
      }
    }
  }
  ${POST_FRAGMENT}
`;

export const LIST_USERS = gql`
  ${USER_FRAGMENT}
  query ListUsers($limit: Int, $nextToken: String) {
    listUsers(limit: $limit, nextToken: $nextToken) {
      items {
        ...UserFields
      }
      nextToken
    }
  }
`;

export const LIST_POSTS = gql`
  ${POST_FRAGMENT}
  ${USER_FRAGMENT}
  query ListPosts($limit: Int, $nextToken: String) {
    listPosts(limit: $limit, nextToken: $nextToken) {
      items {
        ...PostFields
        author {
          ...UserFields
        }
      }
      nextToken
    }
  }
`;

// Mutations
export const CREATE_USER = gql`
  ${USER_FRAGMENT}
  mutation CreateUser($input: UserInput!) {
    createUser(input: $input) {
      ...UserFields
    }
  }
`;

export const CREATE_POST = gql`
  ${POST_FRAGMENT}
  mutation CreatePost($input: PostInput!) {
    createPost(input: $input) {
      ...PostFields
    }
  }
`;

export const INCREMENT_POST_VIEW_COUNT = gql`
  ${POST_FRAGMENT}
  mutation IncrementPostViewCount($id: ID!) {
    incrementPostViewCount(id: $id) {
      ...PostFields
    }
  }
`;

// Subscriptions
export const ON_CREATE_POST = gql`
  ${POST_FRAGMENT}
  ${USER_FRAGMENT}
  subscription OnCreatePost {
    onCreatePost {
      ...PostFields
      author {
        ...UserFields
      }
    }
  }
`;
```

3. **React Hooks の実装**
```typescript
// src/hooks/useGraphQL.ts
import { useQuery, useMutation, useSubscription } from '@apollo/client';
import {
  GET_USER,
  LIST_USERS,
  LIST_POSTS,
  CREATE_USER,
  CREATE_POST,
  INCREMENT_POST_VIEW_COUNT,
  ON_CREATE_POST,
} from '../graphql/operations';

// Users Hooks
export function useUser(id: string) {
  return useQuery(GET_USER, {
    variables: { id },
    skip: !id,
  });
}

export function useUsers(limit = 20) {
  return useQuery(LIST_USERS, {
    variables: { limit },
  });
}

export function useCreateUser() {
  return useMutation(CREATE_USER, {
    update(cache, { data }) {
      if (data?.createUser) {
        cache.modify({
          fields: {
            listUsers(existing) {
              const newUserRef = cache.writeFragment({
                data: data.createUser,
                fragment: USER_FRAGMENT,
              });
              return {
                ...existing,
                items: [newUserRef, ...existing.items],
              };
            },
          },
        });
      }
    },
  });
}

// Posts Hooks
export function usePosts(limit = 20) {
  return useQuery(LIST_POSTS, {
    variables: { limit },
  });
}

export function useCreatePost() {
  return useMutation(CREATE_POST, {
    update(cache, { data }) {
      if (data?.createPost) {
        cache.modify({
          fields: {
            listPosts(existing) {
              const newPostRef = cache.writeFragment({
                data: data.createPost,
                fragment: POST_FRAGMENT,
              });
              return {
                ...existing,
                items: [newPostRef, ...existing.items],
              };
            },
          },
        });
      }
    },
  });
}

export function useIncrementPostViewCount() {
  return useMutation(INCREMENT_POST_VIEW_COUNT);
}

// Subscription Hooks
export function usePostSubscription() {
  return useSubscription(ON_CREATE_POST, {
    onSubscriptionData: ({ client, subscriptionData }) => {
      if (subscriptionData.data?.onCreatePost) {
        client.cache.modify({
          fields: {
            listPosts(existing) {
              const newPostRef = client.cache.writeFragment({
                data: subscriptionData.data.onCreatePost,
                fragment: POST_FRAGMENT,
              });
              return {
                ...existing,
                items: [newPostRef, ...existing.items],
              };
            },
          },
        });
      }
    },
  });
}
```

### ステップ4: デプロイとテスト

1. **デプロイスクリプト**
```bash
#!/bin/bash
# scripts/deploy-graphql.sh

set -e

PROJECT_NAME="graphql-api"
ENVIRONMENT="dev"
REGION="ap-northeast-1"

echo "Deploying GraphQL API infrastructure..."

# AppSync API デプロイ
aws cloudformation deploy \
  --template-file cloudformation/appsync-api.yaml \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-appsync \
  --parameter-overrides \
    ProjectName=${PROJECT_NAME} \
    EnvironmentName=${ENVIRONMENT} \
  --capabilities CAPABILITY_IAM \
  --region ${REGION}

# GraphQL エンドポイント取得
GRAPHQL_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-appsync \
  --query 'Stacks[0].Outputs[?OutputKey==`GraphQLApiEndpoint`].OutputValue' \
  --output text)

API_KEY=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-appsync \
  --query 'Stacks[0].Outputs[?OutputKey==`GraphQLApiKey`].OutputValue' \
  --output text)

echo "Deployment completed!"
echo "GraphQL Endpoint: ${GRAPHQL_ENDPOINT}"
echo "API Key: ${API_KEY}"

# 環境変数ファイル作成
cat > .env.local << EOF
REACT_APP_GRAPHQL_ENDPOINT=${GRAPHQL_ENDPOINT}
REACT_APP_GRAPHQL_API_KEY=${API_KEY}
EOF

echo "Environment variables saved to .env.local"
```

2. **GraphQL テストクエリ**
```bash
#!/bin/bash
# scripts/test-graphql.sh

ENDPOINT="$1"
API_KEY="$2"

if [ -z "$ENDPOINT" ] || [ -z "$API_KEY" ]; then
    echo "Usage: $0 <graphql-endpoint> <api-key>"
    exit 1
fi

echo "Testing GraphQL API at: $ENDPOINT"

# ユーザー作成テスト
echo "1. Creating user..."
CREATE_USER_QUERY='{
  "query": "mutation CreateUser($input: UserInput!) { createUser(input: $input) { id email username firstName lastName createdAt } }",
  "variables": {
    "input": {
      "email": "test@example.com",
      "username": "testuser",
      "firstName": "Test",
      "lastName": "User",
      "bio": "GraphQL test user"
    }
  }
}'

USER_RESPONSE=$(curl -s -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "$CREATE_USER_QUERY")

echo "User creation response: $USER_RESPONSE"

# ユーザーID抽出
USER_ID=$(echo "$USER_RESPONSE" | jq -r '.data.createUser.id')
echo "Created user ID: $USER_ID"

# ユーザー取得テスト
echo "2. Getting user..."
GET_USER_QUERY="{
  \"query\": \"query GetUser(\$id: ID!) { getUser(id: \$id) { id email username firstName lastName bio createdAt } }\",
  \"variables\": {
    \"id\": \"$USER_ID\"
  }
}"

GET_USER_RESPONSE=$(curl -s -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "$GET_USER_QUERY")

echo "Get user response: $GET_USER_RESPONSE"

# ポスト作成テスト
echo "3. Creating post..."
CREATE_POST_QUERY="{
  \"query\": \"mutation CreatePost(\$input: PostInput!) { createPost(input: \$input) { id title content authorId status createdAt } }\",
  \"variables\": {
    \"input\": {
      \"title\": \"GraphQL Test Post\",
      \"content\": \"This is a test post created via GraphQL API\",
      \"excerpt\": \"A test post\",
      \"authorId\": \"$USER_ID\",
      \"tags\": [\"test\", \"graphql\"],
      \"status\": \"PUBLISHED\"
    }
  }
}"

POST_RESPONSE=$(curl -s -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "$CREATE_POST_QUERY")

echo "Post creation response: $POST_RESPONSE"

# ポスト一覧取得テスト
echo "4. Listing posts..."
LIST_POSTS_QUERY='{
  "query": "query ListPosts($limit: Int) { listPosts(limit: $limit) { items { id title excerpt authorId status createdAt } nextToken } }",
  "variables": {
    "limit": 10
  }
}'

LIST_RESPONSE=$(curl -s -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "$LIST_POSTS_QUERY")

echo "List posts response: $LIST_RESPONSE"

echo "GraphQL API testing completed!"
```

## 検証方法

### 1. GraphQL Playground/GraphiQL
```bash
# GraphQL クエリ実行環境のセットアップ
npm install -g graphql-playground-cli
graphql-playground --endpoint "$GRAPHQL_ENDPOINT" --headers '{"x-api-key": "'$API_KEY'"}'
```

### 2. パフォーマンステスト
```javascript
// performance-test.js
const { ApolloClient, InMemoryCache, gql, createHttpLink } = require('@apollo/client');
const fetch = require('cross-fetch');

const client = new ApolloClient({
  link: createHttpLink({
    uri: process.env.GRAPHQL_ENDPOINT,
    fetch,
    headers: {
      'x-api-key': process.env.API_KEY,
    },
  }),
  cache: new InMemoryCache(),
});

async function performanceTest() {
  const start = Date.now();
  
  // 並列クエリ実行
  const promises = Array.from({ length: 10 }, () =>
    client.query({
      query: gql`
        query {
          listPosts(limit: 5) {
            items {
              id
              title
              author {
                username
              }
            }
          }
        }
      `,
    })
  );
  
  await Promise.all(promises);
  
  const end = Date.now();
  console.log(`10 parallel queries completed in ${end - start}ms`);
}

performanceTest().catch(console.error);
```

### 3. サブスクリプションテスト
```javascript
// subscription-test.js
const { ApolloClient, InMemoryCache, gql, split } = require('@apollo/client');
const { WebSocketLink } = require('@apollo/client/link/ws');
const { getMainDefinition } = require('@apollo/client/utilities');
const ws = require('ws');

const wsLink = new WebSocketLink({
  uri: process.env.GRAPHQL_WEBSOCKET_ENDPOINT,
  options: {
    reconnect: true,
    connectionParams: {
      'x-api-key': process.env.API_KEY,
    },
  },
  webSocketImpl: ws,
});

const client = new ApolloClient({
  link: wsLink,
  cache: new InMemoryCache(),
});

const subscription = client.subscribe({
  query: gql`
    subscription {
      onCreatePost {
        id
        title
        author {
          username
        }
      }
    }
  `,
});

subscription.subscribe({
  next: (data) => console.log('New post created:', data),
  error: (err) => console.error('Subscription error:', err),
});
```

## トラブルシューティング

### よくある問題と解決策

#### 1. N+1 問題
**症状**: 関連データ取得時のパフォーマンス低下
**解決策**:
```typescript
// DataLoader の実装
import DataLoader from 'dataloader';

const userLoader = new DataLoader(async (userIds) => {
  const users = await batchGetUsers(userIds);
  return userIds.map(id => users.find(user => user.id === id));
});

// Resolver での使用
const resolvers = {
  Post: {
    author: (post) => userLoader.load(post.authorId),
  },
};
```

#### 2. キャッシュ無効化
**症状**: 古いデータが表示される
**解決策**:
```typescript
// Apollo Client キャッシュ更新
const [createPost] = useMutation(CREATE_POST, {
  update(cache, { data }) {
    cache.evict({ fieldName: 'listPosts' });
    cache.gc();
  },
});
```

#### 3. サブスクリプション接続問題
**症状**: リアルタイム更新が動作しない
**解決策**:
- WebSocket接続の確認
- 認証情報の検証
- ネットワーク設定の確認

## 学習リソース

### 公式ドキュメント
- [AWS AppSync Developer Guide](https://docs.aws.amazon.com/appsync/)
- [GraphQL Official Documentation](https://graphql.org/learn/)
- [Apollo Client Documentation](https://www.apollographql.com/docs/react/)

### 追加学習教材
- [GraphQL Best Practices](https://graphql.org/learn/best-practices/)
- [Apollo Server Performance](https://www.apollographql.com/docs/apollo-server/performance/caching/)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **認証・認可**: Cognito User Pools統合
2. **スキーマ検証**: 入力データの厳密な検証
3. **クエリ複雑度制限**: 深いネストの防止
4. **レート制限**: API使用量の制御

### コスト最適化
1. **効率的なクエリ**: N+1問題の回避
2. **キャッシュ活用**: CloudFrontとApollo Client
3. **サブスクリプション管理**: 不要な接続の削除
4. **DynamoDB最適化**: 適切なキー設計

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatch監視とX-Rayトレーシング
- **セキュリティの柱**: 認証・認可・検証機能
- **信頼性の柱**: 自動スケーリングとフェイルオーバー
- **パフォーマンス効率の柱**: 効率的なデータ取得
- **コスト最適化の柱**: サーバーレスとキャッシュ

## 次のステップ

### 推奨される学習パス
1. **2.3.1 RDSデータベース**: リレーショナルデータとの統合
2. **3.1.1 ユーザー管理システム**: 認証機能強化
3. **3.2.2 リアルタイム更新**: サブスクリプション活用
4. **5.2.1 チャットボット作成**: AI機能との統合

### 発展的な機能
1. **Federation**: マイクロサービス統合
2. **Caching**: Redis統合とパフォーマンス向上
3. **Batch Processing**: 大量データ処理最適化
4. **Schema Stitching**: 複数スキーマの結合

### 実践プロジェクトのアイデア
1. **ソーシャルメディア**: リアルタイム投稿・コメント
2. **ブログプラットフォーム**: CMS機能付きGraphQL API
3. **Eコマース**: 商品検索・注文管理システム
4. **プロジェクト管理**: タスク・チーム協業ツール