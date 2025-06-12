# 2.1.2 React-Next.js

## 学習目標

このセクションでは、React + Next.jsを使用してモダンなサーバーサイドレンダリング（SSR）とスタティックサイトジェネレーション（SSG）を活用したWebアプリケーションを構築し、AWS上での効率的なデプロイとスケーリングを実現する方法を習得します。

### 習得できるスキル
- Next.js プロジェクトのセットアップと設定
- サーバーサイドレンダリング（SSR）の実装
- スタティックサイトジェネレーション（SSG）の活用
- API Routes による簡易バックエンド構築
- AWS Amplify または Vercel でのデプロイ
- CloudFront + S3 での手動デプロイ戦略
- パフォーマンス最適化とSEO対策

## 前提知識

### 必須の知識
- JavaScript ES6+ の基本構文
- React の基本概念（コンポーネント、state、props）
- HTML/CSS の実装経験
- Node.js と npm/yarn の基本操作

### あると望ましい知識
- TypeScript の基本構文
- REST API の概念
- Git/GitHub の操作経験
- ウェブパフォーマンス最適化技術

## アーキテクチャ概要

### Next.js on AWS アーキテクチャ

```
                         ┌─────────────────────┐
                         │       Users         │
                         │    (Global)         │
                         └─────────┬───────────┘
                                   │
                         ┌─────────┼───────────┐
                         │         │           │
                         ▼         ▼           ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   CloudFront    │ │CloudFront│ │   CloudFront    │
          │   Edge Location │ │   Edge   │ │   Edge Location │
          │                 │ │ Location │ │                 │
          └─────────────────┘ └──────────┘ └─────────────────┘
                         │         │           │
                         └─────────┼───────────┘
                                   │
                                   ▼
              ┌─────────────────────────────────────┐
              │         CloudFront                  │
              │         Distribution                │
              │                                     │
              │  ┌─────────────────────────────┐   │
              │  │    Caching Strategies       │   │
              │  │  - Static Assets: 1 year   │   │
              │  │  - API Routes: No cache     │   │
              │  │  - Pages: Custom rules      │   │
              │  └─────────────────────────────┘   │
              └─────────────────┬───────────────────┘
                                │
                    ┌───────────┼───────────┐
                    │           │           │
                    ▼           ▼           ▼
       ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
       │   S3 Bucket     │ │ Lambda   │ │   API Gateway   │
       │ (Static Assets) │ │(SSR/API) │ │  (API Routes)   │
       │                 │ │          │ │                 │
       │ ┌─────────────┐ │ │┌────────┐│ │ ┌─────────────┐ │
       │ │    /_next/  │ │ ││Function││ │ │   /api/*    │ │
       │ │   static/   │ │ ││Handler ││ │ │   Routes    │ │
       │ │   public/   │ │ │└────────┘│ │ └─────────────┘ │
       │ └─────────────┘ │ └──────────┘ └─────────────────┘
       └─────────────────┘      │              │
                                │              │
                                ▼              ▼
              ┌─────────────────────────────────────┐
              │             DynamoDB                │
              │         (API Data Store)            │
              │                                     │
              │  ┌─────────────────────────────┐   │
              │  │       Tables                │   │
              │  │  - Users                    │   │
              │  │  - Posts                    │   │
              │  │  - Sessions                 │   │
              │  └─────────────────────────────┘   │
              └─────────────────────────────────────┘
```

### 主要コンポーネント
- **Next.js Application**: SSR/SSG対応Reactアプリケーション
- **S3 + CloudFront**: 静的アセットの配信
- **Lambda Functions**: サーバーサイド処理
- **API Gateway**: REST API エンドポイント
- **DynamoDB**: データストレージ

## ハンズオン手順

### ステップ1: Next.jsプロジェクトの初期設定

1. **プロジェクト作成**
```bash
cd /mnt/c/dev2/practice/02-Web三層アーキテクチャ編/2.1-プレゼンテーション層/2.1.2-React-Next.js/frontend
npx create-next-app@latest aws-nextjs-app --typescript --tailwind --eslint --app
cd aws-nextjs-app
```

2. **package.json 依存関係設定**
```json
{
  "name": "aws-nextjs-app",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "export": "next export",
    "analyze": "cross-env ANALYZE=true next build"
  },
  "dependencies": {
    "@aws-sdk/client-dynamodb": "^3.400.0",
    "@aws-sdk/lib-dynamodb": "^3.400.0",
    "@next/bundle-analyzer": "^13.5.0",
    "next": "13.5.0",
    "react": "18.2.0",
    "react-dom": "18.2.0",
    "swr": "^2.2.0",
    "framer-motion": "^10.16.0",
    "lucide-react": "^0.290.0"
  },
  "devDependencies": {
    "@types/node": "20.8.0",
    "@types/react": "18.2.25",
    "@types/react-dom": "18.2.10",
    "autoprefixer": "10.4.16",
    "cross-env": "^7.0.3",
    "eslint": "8.50.0",
    "eslint-config-next": "13.5.0",
    "postcss": "8.4.31",
    "tailwindcss": "3.3.3",
    "typescript": "5.2.2"
  }
}
```

3. **Next.js設定ファイル**
```javascript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    appDir: true,
  },
  images: {
    domains: ['images.unsplash.com', 'via.placeholder.com'],
    formats: ['image/avif', 'image/webp'],
  },
  // Static export configuration for S3 deployment
  output: process.env.BUILD_STANDALONE === 'true' ? 'standalone' : undefined,
  trailingSlash: true,
  
  // Performance optimizations
  swcMinify: true,
  compiler: {
    removeConsole: process.env.NODE_ENV === 'production',
  },
  
  // Bundle analyzer
  webpack: (config, { isServer }) => {
    if (process.env.ANALYZE === 'true') {
      const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
      config.plugins.push(
        new BundleAnalyzerPlugin({
          analyzerMode: 'static',
          openAnalyzer: false,
          reportFilename: isServer
            ? '../analyze/server.html'
            : './analyze/client.html',
        })
      );
    }
    return config;
  },
  
  // Environment variables
  env: {
    CUSTOM_KEY: process.env.CUSTOM_KEY,
    AWS_REGION: process.env.AWS_REGION || 'ap-northeast-1',
  },
  
  // Headers for security
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'origin-when-cross-origin',
          },
        ],
      },
    ];
  },
  
  // Redirects
  async redirects() {
    return [
      {
        source: '/old-page',
        destination: '/new-page',
        permanent: true,
      },
    ];
  },
};

module.exports = nextConfig;
```

### ステップ2: アプリケーション構造の構築

1. **Layout Component**
```typescript
// app/layout.tsx
import './globals.css'
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import { Navigation } from '@/components/Navigation'
import { Footer } from '@/components/Footer'
import { Providers } from '@/components/Providers'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: {
    default: 'AWS Next.js App',
    template: '%s | AWS Next.js App'
  },
  description: 'Modern web application built with Next.js and deployed on AWS',
  keywords: ['Next.js', 'React', 'AWS', 'TypeScript'],
  authors: [{ name: 'Your Name' }],
  creator: 'Your Name',
  metadataBase: new URL('https://your-domain.com'),
  openGraph: {
    type: 'website',
    locale: 'ja_JP',
    url: 'https://your-domain.com',
    title: 'AWS Next.js App',
    description: 'Modern web application built with Next.js and deployed on AWS',
    siteName: 'AWS Next.js App',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'AWS Next.js App',
    description: 'Modern web application built with Next.js and deployed on AWS',
    creator: '@yourusername',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="ja" suppressHydrationWarning>
      <body className={inter.className}>
        <Providers>
          <div className="flex flex-col min-h-screen">
            <Navigation />
            <main className="flex-grow">
              {children}
            </main>
            <Footer />
          </div>
        </Providers>
      </body>
    </html>
  )
}
```

2. **ホームページコンポーネント**
```typescript
// app/page.tsx
import { Metadata } from 'next'
import { HeroSection } from '@/components/sections/HeroSection'
import { FeaturesSection } from '@/components/sections/FeaturesSection'
import { PerformanceSection } from '@/components/sections/PerformanceSection'
import { CTASection } from '@/components/sections/CTASection'

export const metadata: Metadata = {
  title: 'ホーム',
  description: 'AWS上で動作するNext.jsアプリケーションのデモサイト',
}

export default function HomePage() {
  return (
    <>
      <HeroSection />
      <FeaturesSection />
      <PerformanceSection />
      <CTASection />
    </>
  )
}
```

3. **API Routes**
```typescript
// app/api/posts/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import { DynamoDBDocumentClient, ScanCommand, PutCommand } from '@aws-sdk/lib-dynamodb'

const client = new DynamoDBClient({
  region: process.env.AWS_REGION || 'ap-northeast-1',
})
const docClient = DynamoDBDocumentClient.from(client)

export async function GET() {
  try {
    const command = new ScanCommand({
      TableName: process.env.DYNAMODB_TABLE_NAME || 'Posts',
      Limit: 10,
    })
    
    const response = await docClient.send(command)
    
    return NextResponse.json({
      success: true,
      data: response.Items || [],
      count: response.Count || 0,
    })
  } catch (error) {
    console.error('Error fetching posts:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to fetch posts' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { title, content, author } = body

    // Validation
    if (!title || !content || !author) {
      return NextResponse.json(
        { success: false, error: 'Missing required fields' },
        { status: 400 }
      )
    }

    const post = {
      id: `post-${Date.now()}`,
      title,
      content,
      author,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    }

    const command = new PutCommand({
      TableName: process.env.DYNAMODB_TABLE_NAME || 'Posts',
      Item: post,
    })

    await docClient.send(command)

    return NextResponse.json({
      success: true,
      data: post,
    }, { status: 201 })
  } catch (error) {
    console.error('Error creating post:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to create post' },
      { status: 500 }
    )
  }
}
```

4. **Blog ページ（SSG）**
```typescript
// app/blog/page.tsx
import { Metadata } from 'next'
import { PostCard } from '@/components/PostCard'
import { generateStaticParams } from './generateStaticParams'

export const metadata: Metadata = {
  title: 'ブログ',
  description: 'AWS Next.jsアプリケーションのブログ記事一覧',
}

// Static Site Generation
export const revalidate = 3600 // 1時間ごとに再生成

async function getPosts() {
  // Static generation時のデータ取得
  if (process.env.NODE_ENV === 'development') {
    return [
      {
        id: '1',
        title: 'Next.js 13 App Directory の活用',
        excerpt: 'Next.js 13の新機能App Directoryを使った開発手法について',
        author: 'Developer',
        createdAt: '2023-10-01T00:00:00Z',
        slug: 'nextjs-13-app-directory',
      },
      {
        id: '2', 
        title: 'AWS上でのNext.jsデプロイ戦略',
        excerpt: 'Next.jsアプリケーションをAWS上に効率的にデプロイする方法',
        author: 'DevOps Engineer',
        createdAt: '2023-10-02T00:00:00Z',
        slug: 'nextjs-aws-deployment',
      },
    ]
  }

  // Production環境では実際のAPIから取得
  try {
    const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/posts`, {
      next: { revalidate: 3600 }
    })
    if (!response.ok) throw new Error('Failed to fetch posts')
    const data = await response.json()
    return data.data || []
  } catch (error) {
    console.error('Error fetching posts:', error)
    return []
  }
}

export default async function BlogPage() {
  const posts = await getPosts()

  return (
    <div className="container mx-auto px-4 py-12">
      <div className="max-w-4xl mx-auto">
        <header className="text-center mb-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            技術ブログ
          </h1>
          <p className="text-lg text-gray-600">
            AWS、Next.js、モダンWeb開発に関する記事をお届けします
          </p>
        </header>

        <div className="grid gap-8 md:grid-cols-2">
          {posts.map((post: any) => (
            <PostCard key={post.id} post={post} />
          ))}
        </div>

        {posts.length === 0 && (
          <div className="text-center py-12">
            <p className="text-gray-500">記事はまだありません。</p>
          </div>
        )}
      </div>
    </div>
  )
}
```

5. **コンポーネント例**
```typescript
// components/sections/HeroSection.tsx
'use client'

import { motion } from 'framer-motion'
import { ArrowRight, Zap, Shield, Globe } from 'lucide-react'
import Link from 'next/link'

export function HeroSection() {
  return (
    <section className="relative bg-gradient-to-br from-blue-600 via-purple-600 to-indigo-700 text-white overflow-hidden">
      <div className="absolute inset-0 bg-black opacity-20"></div>
      
      <div className="relative container mx-auto px-4 py-24 lg:py-32">
        <div className="max-w-4xl mx-auto text-center">
          <motion.h1
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="text-5xl lg:text-7xl font-bold mb-6 leading-tight"
          >
            Next.js on AWS
            <span className="block text-transparent bg-clip-text bg-gradient-to-r from-yellow-400 to-orange-500">
              モダンWeb開発
            </span>
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="text-xl lg:text-2xl mb-10 text-gray-200 leading-relaxed"
          >
            サーバーサイドレンダリング、スタティックサイトジェネレーション、
            <br />
            そしてAWSの強力なインフラストラクチャを組み合わせた最高のパフォーマンス
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.4 }}
            className="flex flex-col sm:flex-row gap-4 justify-center mb-16"
          >
            <Link href="/demo" className="bg-white text-blue-600 px-8 py-4 rounded-lg font-semibold text-lg hover:bg-gray-100 transition-colors flex items-center justify-center">
              デモを見る
              <ArrowRight className="ml-2 h-5 w-5" />
            </Link>
            <Link href="/docs" className="border-2 border-white text-white px-8 py-4 rounded-lg font-semibold text-lg hover:bg-white hover:text-blue-600 transition-colors">
              ドキュメント
            </Link>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.6 }}
            className="grid grid-cols-1 md:grid-cols-3 gap-8 text-center"
          >
            <div className="flex flex-col items-center">
              <div className="bg-white bg-opacity-20 rounded-full p-4 mb-4">
                <Zap className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-semibold mb-2">高速パフォーマンス</h3>
              <p className="text-gray-200">SSG/SSRによる最適化</p>
            </div>
            <div className="flex flex-col items-center">
              <div className="bg-white bg-opacity-20 rounded-full p-4 mb-4">
                <Shield className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-semibold mb-2">セキュア</h3>
              <p className="text-gray-200">AWS WAF & CloudFront</p>
            </div>
            <div className="flex flex-col items-center">
              <div className="bg-white bg-opacity-20 rounded-full p-4 mb-4">
                <Globe className="h-8 w-8" />
              </div>
              <h3 className="text-xl font-semibold mb-2">グローバル配信</h3>
              <p className="text-gray-200">200+ エッジロケーション</p>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  )
}
```

### ステップ3: AWS環境構築

1. **CloudFormation テンプレート**
```yaml
# cloudformation/nextjs-infrastructure.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Next.js application infrastructure on AWS'

Parameters:
  ProjectName:
    Type: String
    Default: 'nextjs-app'
  
  EnvironmentName:
    Type: String
    Default: 'prod'
    AllowedValues: [dev, staging, prod]

Resources:
  # DynamoDB for API data
  PostsTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${ProjectName}-${EnvironmentName}-posts'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: id
          AttributeType: S
      KeySchema:
        - AttributeName: id
          KeyType: HASH
      StreamSpecification:
        StreamViewType: NEW_AND_OLD_IMAGES
      PointInTimeRecoverySpecification:
        PointInTimeRecoveryEnabled: true
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # S3 Bucket for static assets
  StaticAssetsBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-${EnvironmentName}-static-${AWS::AccountId}'
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      VersioningConfiguration:
        Status: Enabled
      LifecycleConfiguration:
        Rules:
          - Id: DeleteOldVersions
            Status: Enabled
            NoncurrentVersionExpirationInDays: 30

  # CloudFront Origin Access Control
  OriginAccessControl:
    Type: AWS::CloudFront::OriginAccessControl
    Properties:
      OriginAccessControlConfig:
        Name: !Sub '${ProjectName}-${EnvironmentName}-oac'
        OriginAccessControlOriginType: s3
        SigningBehavior: always
        SigningProtocol: sigv4

  # CloudFront Distribution
  CloudFrontDistribution:
    Type: AWS::CloudFront::Distribution
    Properties:
      DistributionConfig:
        Origins:
          - Id: S3Origin
            DomainName: !GetAtt StaticAssetsBucket.RegionalDomainName
            S3OriginConfig:
              OriginAccessIdentity: ''
            OriginAccessControlId: !Ref OriginAccessControl
          - Id: APIOrigin
            DomainName: !Sub '${RestApi}.execute-api.${AWS::Region}.amazonaws.com'
            CustomOriginConfig:
              HTTPPort: 443
              OriginProtocolPolicy: https-only
            OriginPath: !Sub '/${EnvironmentName}'
        Enabled: true
        DefaultRootObject: index.html
        DefaultCacheBehavior:
          TargetOriginId: S3Origin
          ViewerProtocolPolicy: redirect-to-https
          AllowedMethods: [GET, HEAD, OPTIONS]
          CachedMethods: [GET, HEAD]
          ForwardedValues:
            QueryString: false
            Cookies:
              Forward: none
          Compress: true
          DefaultTTL: 86400
          MaxTTL: 31536000
        CacheBehaviors:
          - PathPattern: '/api/*'
            TargetOriginId: APIOrigin
            ViewerProtocolPolicy: redirect-to-https
            AllowedMethods: [DELETE, GET, HEAD, OPTIONS, PATCH, POST, PUT]
            CachedMethods: [GET, HEAD]
            ForwardedValues:
              QueryString: true
              Headers: [Authorization, Content-Type]
              Cookies:
                Forward: all
            DefaultTTL: 0
            MaxTTL: 0
            MinTTL: 0
          - PathPattern: '/_next/static/*'
            TargetOriginId: S3Origin
            ViewerProtocolPolicy: redirect-to-https
            AllowedMethods: [GET, HEAD]
            CachedMethods: [GET, HEAD]
            ForwardedValues:
              QueryString: false
              Cookies:
                Forward: none
            Compress: true
            DefaultTTL: 31536000
            MaxTTL: 31536000
        PriceClass: PriceClass_100

  # API Gateway
  RestApi:
    Type: AWS::ApiGateway::RestApi
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-api'
      Description: 'API for Next.js application'
      EndpointConfiguration:
        Types:
          - REGIONAL

  # Lambda function for SSR
  SSRFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-ssr'
      Runtime: nodejs18.x
      Handler: index.handler
      Code:
        ZipFile: |
          exports.handler = async (event) => {
            return {
              statusCode: 200,
              headers: {
                'Content-Type': 'text/html',
              },
              body: '<html><body><h1>SSR Placeholder</h1></body></html>',
            };
          };
      Role: !GetAtt LambdaExecutionRole.Arn
      Environment:
        Variables:
          DYNAMODB_TABLE_NAME: !Ref PostsTable
          AWS_NODEJS_CONNECTION_REUSE_ENABLED: '1'
      Timeout: 30
      MemorySize: 512

  # Lambda execution role
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
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
                  - dynamodb:Scan
                  - dynamodb:Query
                Resource: !GetAtt PostsTable.Arn

Outputs:
  StaticAssetsBucketName:
    Description: 'S3 bucket for static assets'
    Value: !Ref StaticAssetsBucket
    Export:
      Name: !Sub '${AWS::StackName}-StaticAssetsBucket'
  
  CloudFrontDistributionId:
    Description: 'CloudFront distribution ID'
    Value: !Ref CloudFrontDistribution
    Export:
      Name: !Sub '${AWS::StackName}-CloudFrontDistribution'
  
  DynamoDBTableName:
    Description: 'DynamoDB table name'
    Value: !Ref PostsTable
    Export:
      Name: !Sub '${AWS::StackName}-DynamoDBTable'
```

### ステップ4: デプロイメント戦略

1. **ビルドスクリプト**
```bash
#!/bin/bash
# scripts/build.sh

set -e

PROJECT_NAME="nextjs-app"
ENVIRONMENT="prod"

echo "Building Next.js application..."

# Install dependencies
npm ci

# Build the application
npm run build

# For static export (S3 deployment)
if [ "$DEPLOYMENT_TARGET" = "s3" ]; then
  npm run export
  echo "Static export completed"
fi

echo "Build completed successfully"
```

2. **デプロイスクリプト**
```bash
#!/bin/bash
# scripts/deploy.sh

set -e

PROJECT_NAME="nextjs-app"
ENVIRONMENT="prod"
REGION="ap-northeast-1"

# Get infrastructure outputs
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-infrastructure \
  --query 'Stacks[0].Outputs[?OutputKey==`StaticAssetsBucketName`].OutputValue' \
  --output text)

DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT}-infrastructure \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
  --output text)

echo "Deploying to bucket: $BUCKET_NAME"

# Deploy static assets to S3
aws s3 sync out/ s3://$BUCKET_NAME/ \
  --delete \
  --exclude "*.DS_Store" \
  --cache-control "public, max-age=31536000, immutable"

# Set specific cache headers for HTML files
aws s3 cp out/index.html s3://$BUCKET_NAME/index.html \
  --cache-control "public, max-age=0, must-revalidate" \
  --content-type "text/html"

# Invalidate CloudFront cache
echo "Invalidating CloudFront cache..."
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*"

echo "Deployment completed successfully"
```

## 検証方法

### 1. ローカル開発環境
```bash
# 開発サーバー起動
npm run dev

# ビルドテスト
npm run build

# 本番環境テスト
npm start
```

### 2. パフォーマンス測定
```bash
# Lighthouse CI
npm install -g @lhci/cli
lhci autorun

# Core Web Vitals確認
npx web-vitals-cli https://your-domain.com
```

### 3. SEO確認
```bash
# robots.txt確認
curl https://your-domain.com/robots.txt

# サイトマップ確認
curl https://your-domain.com/sitemap.xml

# 構造化データ確認
curl -s https://your-domain.com | grep -o 'application/ld+json'
```

## トラブルシューティング

### よくある問題と解決策

#### 1. ハイドレーションエラー
**症状**: クライアントとサーバーの内容不一致
**解決策**:
```typescript
// suppressHydrationWarning の使用
<div suppressHydrationWarning>
  {typeof window !== 'undefined' && <ClientOnlyComponent />}
</div>

// 動的インポート
const DynamicComponent = dynamic(() => import('./ClientComponent'), {
  ssr: false
})
```

#### 2. API Routes接続エラー
**症状**: API呼び出しが失敗
**解決策**:
```typescript
// 環境変数の確認
const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000'

// エラーハンドリング
try {
  const response = await fetch(`${apiUrl}/api/posts`)
  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`)
  }
  const data = await response.json()
} catch (error) {
  console.error('API call failed:', error)
}
```

#### 3. 画像最適化エラー
**症状**: Next.js Image コンポーネントエラー
**解決策**:
```javascript
// next.config.js
module.exports = {
  images: {
    domains: ['your-domain.com'],
    loader: 'custom',
    loaderFile: './my-loader.js',
  },
}
```

## 学習リソース

### 公式ドキュメント
- [Next.js Documentation](https://nextjs.org/docs)
- [React Documentation](https://react.dev/)
- [AWS Amplify Hosting](https://docs.aws.amazon.com/amplify/latest/userguide/)

### 追加学習教材
- [Next.js Learn Course](https://nextjs.org/learn)
- [React Server Components](https://react.dev/blog/2023/03/22/react-labs-what-we-have-been-working-on-march-2023)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **環境変数管理**: 機密情報の適切な管理
2. **CSP設定**: Content Security Policy実装
3. **認証・認可**: NextAuth.js等の活用
4. **HTTPS強制**: 全通信の暗号化

### コスト最適化
1. **静的生成**: SSGによる配信コスト削減
2. **キャッシュ戦略**: CloudFrontキャッシュ最適化
3. **画像最適化**: WebP/AVIF使用
4. **Bundle分析**: 不要なライブラリ削除

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatchによる監視
- **セキュリティの柱**: WAF・IAM・VPC分離
- **信頼性の柱**: Multi-AZ配置とフェイルオーバー
- **パフォーマンス効率の柱**: SSG・CDN・画像最適化
- **コスト最適化の柱**: 従量課金とリソース最適化

## 次のステップ

### 推奨される学習パス
1. **2.2.1 REST-API**: バックエンドAPI統合
2. **3.1.1 ユーザー管理システム**: 認証機能実装
3. **5.2.1 チャットボット作成**: AI機能統合
4. **6.1.1 マルチステージビルド**: CI/CD強化

### 発展的な機能
1. **International Routing**: 多言語対応
2. **Middleware**: リクエスト処理カスタマイズ
3. **Edge Runtime**: エッジでの処理最適化
4. **Analytics**: パフォーマンス分析

### 実践プロジェクトのアイデア
1. **企業サイト**: コーポレートサイト構築
2. **Eコマース**: ショッピングサイト
3. **ブログプラットフォーム**: CMS機能付きブログ
4. **ダッシュボード**: 管理画面・分析ツール