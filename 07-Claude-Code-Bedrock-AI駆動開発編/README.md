# Claude Code & Bedrock AI駆動開発編

## 概要

このセクションでは、Claude Codeを活用したAI駆動開発の最前線を学習します。Amazon Bedrockとの連携により、コード生成、テスト作成、リファクタリング、ドキュメント作成の自動化を実現し、開発効率を飛躍的に向上させる手法を習得します。エンタープライズレベルでのAI駆動開発プロセスの設計と実装を学びます。

## 学習目標
- Claude Codeのセットアップと基本操作
- Amazon Bedrockとの連携設定
- AI駆動開発の実践的なワークフロー
- プロンプトキャッシングによるコスト最適化
- MCP（Model Context Protocol）を使用した高度な統合

## 前提条件
- AWSアカウントとBedrock利用権限
- Node.js（LTS版）がインストール済み
- AWS CLIの設定完了
- Claude 3.7 SonnetとClaude 3.5 Haikuへのアクセス権限

## セクション構成

### 7.1 Claude Code基礎（4時間）
- **7.1.1 環境セットアップとBedrock連携**（2時間）
- **7.1.2 基本的なAI駆動開発**（2時間）

### 7.2 実践的なAI開発（6時間）
- **7.2.1 大規模コードベースでの活用**（2時間）
- **7.2.2 プロンプトキャッシングとコスト最適化**（2時間）
- **7.2.3 MCPによる高度な統合**（2時間）

### 7.3 エンタープライズ向け実装（4時間）
- **7.3.1 セキュリティとコンプライアンス**（2時間）
- **7.3.2 チーム開発での活用**（2時間）

## 主な学習内容

### Claude Codeとは
- ターミナルベースのAIコーディングアシスタント
- 自然言語でコードベースと対話
- プロジェクト全体の理解と複雑なタスクの自動化

### Bedrockとの連携メリット
- **セキュリティ**: コードがAWS環境から出ない
- **コンプライアンス**: 規制要件への対応
- **コスト管理**: AWSの統合請求
- **スケーラビリティ**: 高いレート制限

### 使用するモデル
- **Claude 3.7 Sonnet**: 複雑なコード理解と生成
- **Claude 3.5 Haiku**: 軽量タスクでのコスト最適化
- **Claude 4 Opus/Sonnet**: 最新の高度なコーディング機能

## クイックスタート

### 1. Bedrockモデルアクセスの有効化
```bash
# AWS ConsoleでBedrockモデルアクセスを確認
# 必須: Claude 3.7 Sonnet, Claude 3.5 Haiku
# 推奨: Claude 4 Opus, Claude 4 Sonnet
```

### 2. Claude Codeのインストール
```bash
# Node.jsがインストールされていることを確認
node --version

# Claude Codeをグローバルインストール
npm install -g @anthropic-ai/claude-code
```

### 3. Bedrock連携の設定
```bash
# AWS認証情報の設定
aws configure

# 環境変数の設定
export CLAUDE_CODE_USE_BEDROCK=1
export ANTHROPIC_MODEL='us.anthropic.claude-3-7-sonnet-20250219-v1:0'

# または設定ファイルで永続化
claude config set --global env '{"CLAUDE_CODE_USE_BEDROCK": "true", "ANTHROPIC_MODEL": "us.anthropic.claude-3-7-sonnet-20250219-v1:0"}'
```

### 4. 動作確認
```bash
# Claude Codeを起動
claude-code

# ヘルプコマンドで動作確認
/help

# ステータス確認
/status
```

## 実践演習

### 演習1: 既存プロジェクトの理解
```bash
# プロジェクトディレクトリで起動
cd /path/to/your/project
claude-code

# プロジェクトの概要を聞く
"このプロジェクトの構造と主要な機能を説明してください"
```

### 演習2: コード生成とリファクタリング
```bash
# 新機能の実装
"ユーザー認証機能をJWTを使って実装してください"

# リファクタリング
"このコードをより効率的に書き直してください"
```

### 演習3: デバッグとトラブルシューティング
```bash
# エラーの解決
"このエラーメッセージの原因と解決方法を教えてください"

# パフォーマンス改善
"このコードのパフォーマンスを改善する方法を提案してください"
```

## プロンプトキャッシングの活用

### 設定方法
```bash
# プロンプトキャッシングを有効化（デフォルト）
export DISABLE_PROMPT_CACHING=false

# 無効化する場合
export DISABLE_PROMPT_CACHING=true
```

### 効果的な使い方
- 大規模コードベースの繰り返し分析
- 長時間のセッションでのコスト削減
- レスポンス時間の短縮

## MCPの活用

### MCP（Model Context Protocol）とは
- 外部ツールとデータソースの統合
- カスタマイズ可能なAI機能
- 組織固有のベストプラクティスの適用

### 設定例
```javascript
// MCP設定ファイル
{
  "servers": {
    "file-system": {
      "command": "mcp-server-filesystem",
      "args": ["--root", "/path/to/project"]
    },
    "aws-docs": {
      "command": "mcp-server-aws-docs"
    }
  }
}
```

## コスト管理のベストプラクティス

### トークン使用量の監視
```bash
# 使用量の確認
claude-code usage

# 月次レポートの生成
claude-code report --monthly
```

### 最適化のヒント
1. **軽量タスクにはHaikuモデルを使用**
2. **プロンプトキャッシングの活用**
3. **不要な長いコンテキストの削除**
4. **バッチ処理の活用**

## トラブルシューティング

### よくある問題と解決方法

#### 認証エラー
```bash
# AWS認証情報の確認
aws sts get-caller-identity

# IAM権限の確認
aws bedrock list-foundation-models --region us-east-1
```

#### モデルアクセスエラー
- BedrockコンソールでClaude 3.7 SonnetとClaude 3.5 Haikuへのアクセスを確認
- リージョンの設定が正しいか確認

#### レート制限
- Bedrockのレート制限を確認
- 必要に応じてクォータの引き上げリクエスト

## セキュリティとコンプライアンス

### ベストプラクティス
1. **IAMロールの最小権限原則**
2. **VPCエンドポイントの使用**
3. **CloudTrailでの監査ログ**
4. **機密データの取り扱い注意**

### 企業向け設定
```bash
# プライベートエンドポイントの使用
export BEDROCK_ENDPOINT_URL="https://vpce-xxx.bedrock.us-east-1.vpce.amazonaws.com"

# ログ記録の有効化
export CLAUDE_CODE_LOG_LEVEL="info"
export CLAUDE_CODE_LOG_FILE="/var/log/claude-code.log"
```

## 実践プロジェクト

### プロジェクト1: CI/CDパイプラインの自動生成
1. 既存プロジェクトの分析
2. GitHub Actionsワークフローの生成
3. テストとデプロイメントの自動化

### プロジェクト2: レガシーコードのモダナイゼーション
1. コードベースの理解
2. リファクタリング計画の作成
3. 段階的な実装

### プロジェクト3: AIエージェントの構築
1. 要件の定義
2. アーキテクチャ設計
3. 実装とテスト

## まとめ

Claude CodeとAmazon Bedrockの組み合わせは、エンタープライズグレードのAI駆動開発を実現します。このモジュールで学んだスキルを活用することで、開発生産性を大幅に向上させることができます。

このコンテンツもすべてclaude code で出力しました。

## 次のステップ
- より高度なプロンプトエンジニアリング
- カスタムMCPサーバーの開発
- チーム全体でのAI駆動開発の導入

## 参考リソース
- [AWS Community: Claude Code on Amazon Bedrock Quick Setup Guide](https://community.aws/content/2tXkZKrZzlrlu0KfH8gST5Dkppq/claude-code-on-amazon-bedrock-quick-setup-guide)
- [AWS Blog: Supercharge your development with Claude Code and Amazon Bedrock](https://aws.amazon.com/blogs/machine-learning/supercharge-your-development-with-claude-code-and-amazon-bedrock-prompt-caching/)
- [Anthropic Documentation: Claude on Amazon Bedrock](https://docs.anthropic.com/en/api/claude-on-amazon-bedrock)
