# 1.1.3 GitHub ActionsとAWS連携

## 学習目標

このセクションでは、GitHub ActionsとAWSを連携させて、安全で効率的なCI/CDパイプラインを構築する方法を習得します。

### 習得できるスキル
- GitHub ActionsワークフローとAWSサービスの統合
- IAMロールを使用したセキュアな認証設定
- OpenID Connect (OIDC)による一時的な認証情報の取得
- CloudFormation、Lambda、S3へのデプロイ自動化
- セキュリティベストプラクティスの実装
- マルチ環境（dev/staging/prod）デプロイ戦略

## 前提知識

### 必須の知識
- GitとGitHubの基本操作
- IAMユーザー、ロール、ポリシーの理解（1.1.1セクション完了）
- AWS CLIの基本操作
- YAML形式の設定ファイル作成経験

### あると望ましい知識
- CI/CDの基本概念と用語
- GitHub Actionsの基本的なワークフロー作成経験
- Docker基礎知識
- シェルスクリプトの作成経験

## アーキテクチャ概要

### GitHub Actions → AWS統合アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                       GitHub Repository                     │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │    Developer    │  │      Code       │  │    Tests    │ │
│  │     Commits     │  │     Changes     │  │   & Linting │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│                              │                              │
│                              │ Git Push / PR               │
└──────────────────────────────┼──────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                    GitHub Actions                           │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │      Build      │  │      Test       │  │    Deploy   │  │
│  │   Workflow      │  │   Workflow      │  │  Workflow   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
│                              │                              │
│                              │ OIDC Authentication          │
└──────────────────────────────┼──────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                         AWS Account                         │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │    IAM OIDC     │  │   CloudFormation │  │    Lambda   │  │
│  │    Provider     │  │      Stacks      │  │  Functions  │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │    S3 Buckets   │  │   CloudWatch    │  │    ECR      │  │
│  │   (Artifacts)   │  │    Logs         │  │ Repositories │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **GitHub Actions**: ワークフロー実行エンジン
- **OIDC Provider**: 短期間の認証情報を提供
- **IAM Role**: GitHub Actionsに必要な権限を付与
- **CloudFormation**: インフラストラクチャのデプロイ
- **S3**: アーティファクトストレージ
- **CloudWatch**: ログとメトリクス監視

## ハンズオン手順

### ステップ1: AWS側のOIDCプロバイダー設定

1. **CloudFormationテンプレートの作成**
```bash
cd /mnt/c/dev2/practice/01-基礎インフラストラクチャー編/1.1-AWS環境セットアップ/1.1.3-GitHub-ActionsとAWS連携/cloudformation
```

2. **GitHub Actions用IAMロールの作成**
```yaml
# github-actions-iam.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'IAM resources for GitHub Actions integration'

Parameters:
  GitHubOrganization:
    Type: String
    Description: 'GitHub organization name'
  
  GitHubRepository:
    Type: String
    Description: 'GitHub repository name'
  
  ProjectName:
    Type: String
    Default: 'github-actions-integration'

Resources:
  GitHubOIDCProvider:
    Type: AWS::IAM::OIDCIdentityProvider
    Properties:
      Url: https://token.actions.githubusercontent.com
      ClientIdList:
        - sts.amazonaws.com
      ThumbprintList:
        - 6938fd4d98bab03faadb97b34396831e3780aea1

  GitHubActionsRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${ProjectName}-github-actions-role'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Federated: !Ref GitHubOIDCProvider
            Action: sts:AssumeRoleWithWebIdentity
            Condition:
              StringEquals:
                'token.actions.githubusercontent.com:aud': sts.amazonaws.com
              StringLike:
                'token.actions.githubusercontent.com:sub': 
                  - !Sub 'repo:${GitHubOrganization}/${GitHubRepository}:*'
      Policies:
        - PolicyName: GitHubActionsPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - cloudformation:CreateStack
                  - cloudformation:UpdateStack
                  - cloudformation:DeleteStack
                  - cloudformation:DescribeStacks
                  - cloudformation:ListStacks
                  - cloudformation:ValidateTemplate
                Resource: '*'
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:PutObject
                  - s3:DeleteObject
                  - s3:ListBucket
                Resource:
                  - !Sub '${ArtifactsBucket}/*'
                  - !Sub '${ArtifactsBucket}'
              - Effect: Allow
                Action:
                  - lambda:CreateFunction
                  - lambda:UpdateFunctionCode
                  - lambda:UpdateFunctionConfiguration
                  - lambda:GetFunction
                  - lambda:ListFunctions
                  - lambda:InvokeFunction
                Resource: '*'
              - Effect: Allow
                Action:
                  - iam:PassRole
                Resource: '*'
                Condition:
                  StringEquals:
                    'iam:PassedToService': lambda.amazonaws.com
              - Effect: Allow
                Action:
                  - logs:CreateLogGroup
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                  - logs:DescribeLogGroups
                  - logs:DescribeLogStreams
                Resource: '*'

  ArtifactsBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-artifacts-${AWS::AccountId}-${AWS::Region}'
      VersioningConfiguration:
        Status: Enabled
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      LifecycleConfiguration:
        Rules:
          - Id: DeleteOldArtifacts
            Status: Enabled
            ExpirationInDays: 30

Outputs:
  GitHubActionsRoleArn:
    Description: 'IAM Role ARN for GitHub Actions'
    Value: !GetAtt GitHubActionsRole.Arn
    Export:
      Name: !Sub '${AWS::StackName}-GitHubActionsRole'
  
  ArtifactsBucketName:
    Description: 'S3 Bucket for storing artifacts'
    Value: !Ref ArtifactsBucket
    Export:
      Name: !Sub '${AWS::StackName}-ArtifactsBucket'
```

### ステップ2: GitHub Actionsワークフローの作成

1. **基本的なワークフロー設定**
```yaml
# .github/workflows/deploy.yml
name: Deploy to AWS

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  AWS_REGION: us-east-1
  PROJECT_NAME: github-actions-integration

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Run linting
        run: npm run lint

  validate-cloudformation:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Validate CloudFormation templates
        run: |
          for template in cloudformation/*.yaml; do
            echo "Validating $template"
            aws cloudformation validate-template --template-body file://$template
          done

  deploy-dev:
    runs-on: ubuntu-latest
    needs: [test, validate-cloudformation]
    if: github.ref == 'refs/heads/develop'
    environment: development
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Deploy to development
        run: |
          aws cloudformation deploy \
            --template-file cloudformation/main.yaml \
            --stack-name ${{ env.PROJECT_NAME }}-dev \
            --parameter-overrides EnvironmentName=dev \
            --capabilities CAPABILITY_NAMED_IAM \
            --no-fail-on-empty-changeset

  deploy-prod:
    runs-on: ubuntu-latest
    needs: [test, validate-cloudformation]
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Deploy to production
        run: |
          aws cloudformation deploy \
            --template-file cloudformation/main.yaml \
            --stack-name ${{ env.PROJECT_NAME }}-prod \
            --parameter-overrides EnvironmentName=prod \
            --capabilities CAPABILITY_NAMED_IAM \
            --no-fail-on-empty-changeset

      - name: Run smoke tests
        run: |
          # 本番環境の動作確認
          chmod +x scripts/smoke-tests.sh
          ./scripts/smoke-tests.sh
```

### ステップ3: Lambda関数のCI/CDパイプライン

1. **Lambda特化ワークフロー**
```yaml
# .github/workflows/lambda-deploy.yml
name: Deploy Lambda Functions

on:
  push:
    branches: [main]
    paths: ['src/lambda/**']

env:
  AWS_REGION: us-east-1

jobs:
  deploy-lambda:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Package Lambda functions
        run: |
          for function_dir in src/lambda/*/; do
            function_name=$(basename "$function_dir")
            echo "Packaging $function_name"
            
            cd "$function_dir"
            pip install -r requirements.txt -t .
            zip -r "../../../${function_name}.zip" .
            cd ../../..
            
            # Upload to S3
            aws s3 cp "${function_name}.zip" \
              s3://${{ secrets.ARTIFACTS_BUCKET }}/lambda/${function_name}.zip
            
            # Update Lambda function
            aws lambda update-function-code \
              --function-name "$function_name" \
              --s3-bucket "${{ secrets.ARTIFACTS_BUCKET }}" \
              --s3-key "lambda/${function_name}.zip"
          done
```

## 検証方法

### 1. OIDC認証のテスト
```bash
# GitHub Actions実行時のログで確認
# "Successfully configured AWS credentials" メッセージを確認
```

### 2. デプロイメントテスト
```bash
# ローカルでのCloudFormation検証
aws cloudformation validate-template \
  --template-body file://cloudformation/github-actions-iam.yaml

# スタックデプロイのテスト
aws cloudformation create-stack \
  --stack-name test-github-actions \
  --template-body file://cloudformation/github-actions-iam.yaml \
  --parameters ParameterKey=GitHubOrganization,ParameterValue=your-org \
               ParameterKey=GitHubRepository,ParameterValue=your-repo \
  --capabilities CAPABILITY_NAMED_IAM
```

### 3. セキュリティテスト
```bash
# IAMロールの権限確認
aws iam get-role --role-name github-actions-integration-github-actions-role

# AssumeRole条件の確認
aws iam get-role-policy \
  --role-name github-actions-integration-github-actions-role \
  --policy-name GitHubActionsPolicy
```

## トラブルシューティング

### よくある問題と解決策

#### 1. OIDC認証エラー
**症状**: "Error: Could not assume role with OIDC"
**解決策**:
- GitHubリポジトリ名とOrganization名の確認
- IAMロールの信頼ポリシーでの条件設定確認
- OIDCプロバイダーのThumbprintの最新性確認

#### 2. CloudFormation権限エラー
**症状**: "AccessDenied: User is not authorized to perform cloudformation:CreateStack"
**解決策**:
```yaml
# IAMロールに必要な権限を追加
- Effect: Allow
  Action:
    - cloudformation:*
    - iam:CreateRole
    - iam:AttachRolePolicy
    - iam:PassRole
  Resource: '*'
```

#### 3. S3アクセスエラー
**症状**: "NoSuchBucket: The specified bucket does not exist"
**解決策**:
- S3バケット名の一意性確認
- GitHub SecretsのARTIFACTS_BUCKET設定確認

### デバッグのベストプラクティス
```yaml
# GitHub Actionsでのデバッグステップ追加
- name: Debug AWS credentials
  run: |
    aws sts get-caller-identity
    aws sts get-session-token --duration-seconds 900

- name: Debug environment
  run: |
    echo "GitHub Actor: ${{ github.actor }}"
    echo "GitHub Repository: ${{ github.repository }}"
    echo "GitHub Ref: ${{ github.ref }}"
```

## 学習リソース

### AWS公式ドキュメント
- [GitHub Actions と AWS の統合](https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/id_roles_providers_oidc.html)
- [IAM OpenID Connect アイデンティティプロバイダー](https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [CloudFormation ユーザーガイド](https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/)

### GitHub公式ドキュメント
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [OpenID Connect in GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS での OIDC の設定](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

### 追加学習教材
- [GitHub Actions Workshop](https://github.com/githubtraining/github-actions-course)
- [AWS DevOps Learning Path](https://aws.amazon.com/devops/learning/)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **最小権限の原則**: 必要最小限の権限のみ付与
2. **条件付きアクセス**: 特定のリポジトリとブランチからのみアクセス許可
3. **シークレット管理**: GitHub Secretsでの認証情報管理
4. **ログ監視**: CloudTrailでのAPI呼び出し監視

### コスト最適化
1. **リソース管理**: 開発環境リソースの自動削除
2. **アーティファクト管理**: S3ライフサイクルポリシーでの古いファイル削除
3. **実行最適化**: 不要なワークフロー実行の回避

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: 自動化されたデプロイメントとモニタリング
- **セキュリティの柱**: OIDC認証と最小権限アクセス
- **信頼性の柱**: 自動テストと段階的デプロイメント
- **パフォーマンス効率の柱**: 効率的なCI/CDパイプライン
- **コスト最適化の柱**: リソースの適切な管理と削除

## 次のステップ

### 推奨される学習パス
1. **1.2.1 EC2インスタンス管理**: GitHub ActionsからのEC2デプロイ
2. **1.2.3 Lambda関数デプロイ**: サーバーレスCI/CD
3. **6.1.1 マルチステージビルド**: 高度なパイプライン構築
4. **6.1.2 テスト自動化**: テスト統合の強化

### 発展的な機能
1. **マルチ環境管理**: 環境固有の設定とデプロイ戦略
2. **Blue-Greenデプロイ**: ゼロダウンタイムデプロイメント
3. **カナリアデプロイ**: 段階的なリリース戦略
4. **モニタリング統合**: デプロイ後の自動監視

### 実践プロジェクトのアイデア
1. **フルスタックアプリケーションCI/CD**: React + Lambda + DynamoDB
2. **マイクロサービスデプロイ**: 複数サービスの協調デプロイ
3. **インフラストラクチャCI/CD**: Infrastructure as Code の自動化
4. **セキュリティ統合**: 脆弱性スキャンと自動修正