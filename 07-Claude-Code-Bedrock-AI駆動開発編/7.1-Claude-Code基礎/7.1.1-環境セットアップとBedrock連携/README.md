# 7.1.1 環境セットアップとBedrock連携

## 概要
このセクションでは、Claude CodeをAmazon Bedrockと連携させるための環境構築を行います。IAMの設定から始まり、Claude Codeのインストール、Bedrockとの接続設定まで、ステップバイステップで解説します。

## 学習目標
- AWS IAMの適切な権限設定
- Claude Codeのインストールと基本設定
- Bedrockモデルへのアクセス設定
- 環境変数とコンフィグレーション

## 前提条件
- AWSアカウントが作成済み
- AWS CLIがインストール済み
- Node.js LTS版がインストール済み

## 手順

### Step 1: IAMポリシーの作成

#### 1.1 必要な権限の理解
Claude CodeがBedrockと連携するために必要な最小限の権限：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": [
        "arn:aws:bedrock:*:*:model/anthropic.claude-3-7-sonnet*",
        "arn:aws:bedrock:*:*:model/anthropic.claude-3-5-haiku*",
        "arn:aws:bedrock:*:*:model/anthropic.claude-opus-4*",
        "arn:aws:bedrock:*:*:model/anthropic.claude-sonnet-4*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:ListFoundationModels",
        "bedrock:GetFoundationModel"
      ],
      "Resource": "*"
    }
  ]
}
```

#### 1.2 CloudFormationテンプレートで作成

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Claude Code Bedrock Integration IAM Setup'

Resources:
  ClaudeCodeBedrockPolicy:
    Type: AWS::IAM::ManagedPolicy
    Properties:
      ManagedPolicyName: ClaudeCodeBedrockPolicy
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - bedrock:InvokeModel
              - bedrock:InvokeModelWithResponseStream
            Resource:
              - arn:aws:bedrock:*:*:model/anthropic.claude-3-7-sonnet*
              - arn:aws:bedrock:*:*:model/anthropic.claude-3-5-haiku*
              - arn:aws:bedrock:*:*:model/anthropic.claude-opus-4*
              - arn:aws:bedrock:*:*:model/anthropic.claude-sonnet-4*
          - Effect: Allow
            Action:
              - bedrock:ListFoundationModels
              - bedrock:GetFoundationModel
            Resource: '*'

  ClaudeCodeBedrockRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: ClaudeCodeBedrockRole
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${AWS::AccountId}:root'
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - !Ref ClaudeCodeBedrockPolicy

  ClaudeCodeBedrockUser:
    Type: AWS::IAM::User
    Properties:
      UserName: claude-code-bedrock-user
      ManagedPolicyArns:
        - !Ref ClaudeCodeBedrockPolicy

  ClaudeCodeBedrockAccessKey:
    Type: AWS::IAM::AccessKey
    Properties:
      UserName: !Ref ClaudeCodeBedrockUser

Outputs:
  AccessKeyId:
    Description: Access Key ID for Claude Code
    Value: !Ref ClaudeCodeBedrockAccessKey
  SecretAccessKey:
    Description: Secret Access Key for Claude Code
    Value: !GetAtt ClaudeCodeBedrockAccessKey.SecretAccessKey
    NoEcho: true
```

### Step 2: Bedrockモデルアクセスの有効化

#### 2.1 AWSコンソールでの設定
1. AWS Management Consoleにログイン
2. Amazon Bedrockサービスに移動
3. 左側メニューから「Model access」を選択
4. 以下のモデルへのアクセスをリクエスト：
   - Claude 3.7 Sonnet (必須)
   - Claude 3.5 Haiku (必須)
   - Claude 4 Opus (推奨)
   - Claude 4 Sonnet (推奨)

#### 2.2 AWS CLIでの確認
```bash
# 利用可能なモデルの確認
aws bedrock list-foundation-models \
  --region us-east-1 \
  --by-provider anthropic \
  --query "modelSummaries[*].[modelId,modelName]" \
  --output table
```

### Step 3: Claude Codeのインストール

#### 3.1 Node.jsの確認
```bash
# Node.jsバージョンの確認（LTS版推奨）
node --version
# v20.x.x 以上であることを確認

# npmバージョンの確認
npm --version
```

#### 3.2 Claude Codeのインストール
```bash
# グローバルインストール
npm install -g @anthropic-ai/claude-code

# インストール確認
claude-code --version
```

### Step 4: AWS認証情報の設定

#### 4.1 AWS CLIの設定
```bash
# AWS認証情報の設定
aws configure

# 以下を入力：
# AWS Access Key ID: [IAMで作成したアクセスキー]
# AWS Secret Access Key: [IAMで作成したシークレットキー]
# Default region name: us-east-1
# Default output format: json
```

#### 4.2 認証情報の確認
```bash
# 認証情報のテスト
aws sts get-caller-identity

# 出力例：
# {
#     "UserId": "AIDACKCEVSQ6C2EXAMPLE",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/claude-code-bedrock-user"
# }
```

### Step 5: Claude CodeのBedrock設定

#### 5.1 環境変数による設定
```bash
# Bedrock使用を有効化
export CLAUDE_CODE_USE_BEDROCK=1

# 使用するモデルの指定
export ANTHROPIC_MODEL='us.anthropic.claude-3-7-sonnet-20250219-v1:0'

# リージョンの指定（オプション）
export AWS_REGION='us-east-1'
```

#### 5.2 永続的な設定
```bash
# Claude Codeの設定ファイルで永続化
claude config set --global env '{
  "CLAUDE_CODE_USE_BEDROCK": "true",
  "ANTHROPIC_MODEL": "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
  "AWS_REGION": "us-east-1"
}'

# 設定の確認
claude config get --global
```

### Step 6: 動作確認

#### 6.1 Claude Codeの起動
```bash
# Claude Codeを起動
claude-code

# 成功すると以下のようなメッセージが表示される：
# Welcome to Claude Code!
# Connected to Amazon Bedrock
# Model: claude-3-7-sonnet
# Type /help for available commands
```

#### 6.2 基本的なテスト
```bash
# ヘルプコマンド
/help

# ステータス確認
/status

# 簡単な質問
"Hello, can you confirm you're running through Amazon Bedrock?"
```

### Step 7: プロンプトキャッシングの設定（オプション）

#### 7.1 キャッシング設定
```bash
# プロンプトキャッシングを有効化（デフォルト）
export DISABLE_PROMPT_CACHING=false

# キャッシングの状態確認
claude-code cache status
```

### Step 8: トラブルシューティング

#### 8.1 よくある問題と解決方法

**認証エラーの場合：**
```bash
# IAM権限の確認
aws bedrock invoke-model \
  --model-id anthropic.claude-3-7-sonnet-20250219-v1:0 \
  --region us-east-1 \
  --body '{"prompt": "\n\nHuman: Hello\n\nAssistant:", "max_tokens": 10}' \
  --cli-binary-format raw-in-base64-out \
  output.json
```

**モデルアクセスエラーの場合：**
```bash
# モデルアクセスの確認
aws bedrock get-foundation-model \
  --model-identifier anthropic.claude-3-7-sonnet-20250219-v1:0 \
  --region us-east-1
```

### Step 9: セキュリティのベストプラクティス

#### 9.1 認証情報の保護
```bash
# .envファイルを使用した場合
echo "CLAUDE_CODE_USE_BEDROCK=1" > .env
echo "ANTHROPIC_MODEL=us.anthropic.claude-3-7-sonnet-20250219-v1:0" >> .env

# .gitignoreに追加
echo ".env" >> .gitignore
```

#### 9.2 最小権限の原則
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel"
      ],
      "Resource": [
        "arn:aws:bedrock:us-east-1:*:model/anthropic.claude-3-7-sonnet-20250219-v1:0"
      ],
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": ["あなたのIPアドレス/32"]
        }
      }
    }
  ]
}
```

## 演習

### 演習1: IAMポリシーの作成
1. CloudFormationテンプレートを使用してIAMリソースを作成
2. 作成されたアクセスキーを安全に保管
3. AWS CLIで認証情報を設定

### 演習2: Claude Codeの設定
1. Claude Codeをインストール
2. Bedrock連携を設定
3. 動作確認を実施

### 演習3: トークン使用量の確認
```bash
# 簡単なプロンプトを実行
claude-code
> "Write a simple hello world in Python"

# 使用量を確認
claude-code usage --today
```

## まとめ
このセクションでは、Claude CodeをAmazon Bedrockと連携させるための環境構築を行いました。適切なIAM権限の設定、モデルアクセスの有効化、Claude Codeの設定まで、一連の手順を学習しました。

## 次のステップ
次のセクション「7.1.2 基本的なAI駆動開発」では、実際にClaude Codeを使ってコーディングタスクを実行する方法を学習します。
