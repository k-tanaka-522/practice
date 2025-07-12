# AWS AI駆動開発学習プロジェクト

## 🚀 プロジェクト概要

### プロジェクト名
**AWS AI-Driven Development Practice** - クラウドネイティブ×AI駆動開発の総合学習プラットフォーム


### ビジョン
AI技術とAWSクラウドインフラストラクチャを組み合わせた次世代の開発手法を、実践を通じて体系的に習得する包括的な学習プログラムです。

### ミッション
- 🏗️ **AWSの主要サービス**を実際に構築・運用しながら学習
- 🔄 **CI/CD パイプライン**の実装経験を獲得
- 🤖 **AI（Amazon Bedrock）**を活用した実用的なアプリケーション開発
- 📊 **Infrastructure as Code**の実践的な知識とスキルを習得

## 📚 学習コンテンツ

### 全7編・総学習時間約80時間

```
┌──────────────────────────────────────────────────────────────┐
│                    学習ロードマップ                            │
├──────────────────────────────────────────────────────────────┤
│ 01. 基礎インフラストラクチャー編                    [8時間] │
│ 02. Web三層アーキテクチャ編                        [12時間] │
│ 03. CRUDシステム実装編                             [10時間] │
│ 04. データ分析基盤編                               [12時間] │
│ 05. AI-ML統合編                                   [15時間] │
│ 06. CI-CD高度化編                                 [10時間] │
│ 07. Claude Code & Bedrock AI駆動開発編            [13時間] │
└──────────────────────────────────────────────────────────────┘
```

## 🗺️ 学習パス詳細

### [📖 01-基礎インフラストラクチャー編](01-基礎インフラストラクチャー編/README.md)
**学習時間**: 8時間 | **レベル**: 初級

AWSの基礎となるインフラストラクチャを構築します。
- 🔐 **IAMとセキュリティ**: ユーザー管理、ロール設計、セキュリティポリシー
- 🌐 **VPCネットワーク**: ネットワーク設計、サブネット、セキュリティグループ
- 🚀 **CI/CD連携**: GitHub ActionsとAWS連携
- 💻 **コンピューティング**: EC2、ECS、Lambda

**主要成果物**: IAM基盤、VPCネットワーク、GitHub Actions統合

### [🌐 02-Web三層アーキテクチャ編](02-Web三層アーキテクチャ編/README.md)
**学習時間**: 12時間 | **レベル**: 初級〜中級

モダンなWeb三層アーキテクチャを構築します。
- 🎨 **プレゼンテーション層**: 静的サイト（S3+CloudFront）、React/Next.js SPA
- ⚙️ **アプリケーション層**: REST API（API Gateway+Lambda）、GraphQL（AppSync）
- 💾 **データ層**: RDS（PostgreSQL）、DynamoDB、キャッシュ戦略

**主要成果物**: フルスタックWebアプリケーション、CDN配信、データベース設計

### [🔐 03-CRUDシステム実装編](03-CRUDシステム実装編/README.md)
**学習時間**: 10時間 | **レベル**: 中級

セキュアな認証システムと基本的なCRUD操作を実装します。
- 🛡️ **認証・認可**: Cognito User Pool、JWT トークン、MFA設定
- 📊 **CRUD操作**: データの作成・読み取り・更新・削除
- 📎 **ファイル操作**: S3アップロード、画像リサイズ処理
- ⚡ **リアルタイム**: WebSocket、Server-Sent Events

**主要成果物**: 認証付きCRUDシステム、ファイルアップロード機能

### [📊 04-データ分析基盤編](04-データ分析基盤編/README.md)
**学習時間**: 12時間 | **レベル**: 中級〜上級

リアルタイムデータ処理とビッグデータ分析基盤を構築します。
- 🌊 **データ収集**: Kinesis ストリーミング、EventBridge、IoT連携
- 🔄 **データ処理**: ETL/ELTパイプライン（Glue）、Lambda処理、品質管理
- 🏗️ **データ保存**: Data Lake（S3）、DWH（Redshift）、NoSQL（DynamoDB）
- 📈 **可視化**: QuickSight ダッシュボード、Athena クエリ、カスタムメトリクス

**主要成果物**: リアルタイムデータパイプライン、BI ダッシュボード

### [🤖 05-AI-ML統合編](05-AI-ML統合編/README.md)
**学習時間**: 15時間 | **レベル**: 上級

最新のAI技術を活用したアプリケーションを構築します。
- 🚀 **Amazon Bedrock**: 基盤モデル（Claude、GPT、Titan）の活用
- 💬 **チャットボット**: 対話AI、コンテキスト管理、多言語対応
- 🔍 **RAGシステム**: 検索拡張生成、ベクトルDB（OpenSearch）、知識ベース
- 🎨 **画像生成**: Stable Diffusion、画像編集、NSFW フィルタリング

**主要成果物**: AIチャットボット、RAGシステム、画像生成アプリ

### [🔧 06-CI-CD高度化編](06-CI-CD高度化編/README.md)
**学習時間**: 10時間 | **レベル**: 中級〜上級

本格的なDevOpsパイプラインと運用監視を実装します。
- 🚀 **マルチステージ**: 開発・ステージング・本番環境の自動デプロイ
- 🧪 **テスト自動化**: 単体・統合・E2Eテスト、品質ゲート
- 📊 **監視**: APM、カスタムメトリクス、アラート設定
- 💰 **コスト最適化**: 使用量監視、リソース最適化、自動スケーリング

**主要成果物**: 完全自動化CI/CDパイプライン、包括的監視システム

### [⚡ 07-Claude Code & Bedrock AI駆動開発編](07-Claude-Code-Bedrock-AI駆動開発編/README.md)
**学習時間**: 13時間 | **レベル**: 上級

Claude Codeを活用したAI駆動開発の最前線を学習します。
- 🔧 **Claude Code基礎**: 環境セットアップ、Bedrock連携、基本操作
- 🚀 **AI駆動開発**: コード生成、テスト作成、リファクタリング自動化
- 💰 **最適化**: プロンプトキャッシング、MCP活用、コスト効率化
- 🏢 **エンタープライズ**: チーム開発、セキュリティ、運用監視

**主要成果物**: AI駆動開発環境、自動化されたコード生成パイプライン

## 🚀 クイックスタート

### 1. 環境準備

```bash
# リポジトリのクローン
git clone https://github.com/YOUR_USERNAME/ai-driven-development-practice.git
cd ai-driven-development-practice

# AWS CLI の確認
aws --version
aws sts get-caller-identity

# 必要なツールの確認
node --version
python3 --version
docker --version
```

### 2. 全体デプロイ（ワンクリック）

```bash
# 全システム一括デプロイ
./scripts/deploy-all-infrastructure.sh deploy-all

# 段階的デプロイ
./scripts/deploy-all-infrastructure.sh deploy-foundation
./scripts/deploy-all-infrastructure.sh deploy-web
./scripts/deploy-all-infrastructure.sh deploy-crud
./scripts/deploy-all-infrastructure.sh deploy-data
./scripts/deploy-all-infrastructure.sh deploy-ai-ml
```

### 3. 動作確認

```bash
# システム状況確認
./scripts/deploy-all-infrastructure.sh status

# 統合テスト実行
./scripts/deploy-all-infrastructure.sh test
```

## 📋 前提条件

### 必要なスキル
- ✅ **基本的なプログラミング知識**（JavaScript/Python いずれか）
- ✅ **コマンドライン操作**の基礎
- ✅ **Git/GitHub**の基本操作
- ✅ **Web技術**の基礎理解（HTML/CSS/REST API）

### 必要なアカウント・ツール
- 🟦 **AWSアカウント**（無料利用枠推奨）
- 📱 **GitHubアカウント**
- 💻 **開発環境**（VSCode、AWS CLI、Docker等）
- 💰 **予算**：月額$50-100程度（学習後はリソース削除推奨）

### 詳細ガイド
- 📚 **[前提知識と事前準備](docs/前提知識と事前準備.md)** - 環境セットアップ詳細
- 🗺️ **[学習パスガイド](docs/学習パスガイド.md)** - レベル別学習順序

## 🎯 学習目標と成果物

### 技術スキル習得
```yaml
インフラストラクチャ:
  - VPC、EC2、ECS、Lambda設計・構築
  - RDS、DynamoDB、S3運用
  - セキュリティ設定（IAM、VPC、暗号化）

アプリケーション開発:
  - Web三層アーキテクチャ設計
  - RESTful API、GraphQL API実装
  - 認証・認可システム構築

DevOps/CI/CD:
  - GitHub Actions自動化パイプライン
  - Infrastructure as Code（CloudFormation）
  - 監視・ログ・アラート設定

AI/ML統合:
  - Amazon Bedrock活用
  - RAGシステム構築
  - プロンプトエンジニアリング
  - AI駆動開発プロセス
```

### 主要成果物

1. **🌐 フルスタックWebアプリケーション**
   - AI機能搭載（チャットボット、文書検索、画像生成）
   - 認証システム統合
   - リアルタイム機能

2. **🏗️ 再利用可能なインフラテンプレート**
   - CloudFormation テンプレート集
   - 環境別パラメータ設定
   - セキュリティベストプラクティス

3. **🔄 完全自動化CI/CDパイプライン**
   - マルチステージデプロイメント
   - 自動テスト・品質チェック
   - 監視・アラート統合

4. **📊 データ分析プラットフォーム**
   - リアルタイムデータ処理
   - BI ダッシュボード
   - 予測分析機能

## 📖 実装アーキテクチャ例

### システム全体図

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend Layer                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │   React     │  │ CloudFront  │  │   Amplify   │  │ Route53 │ │
│  │     SPA     │──│     CDN     │──│   Hosting   │──│   DNS   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     API Gateway Layer                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │     REST    │  │  WebSocket  │  │   GraphQL   │  │ Cognito │ │
│  │     API     │  │     API     │  │   AppSync   │  │  Auth   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Computing Layer                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │   Lambda    │  │     ECS     │  │    Step     │  │ Bedrock │ │
│  │ Functions   │  │  Fargate    │  │ Functions   │  │ AI/ML   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Data Layer                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │     RDS     │  │  DynamoDB   │  │      S3     │  │OpenSear │ │
│  │ PostgreSQL  │  │    NoSQL    │  │ Data Lake   │  │Vector DB│ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 💰 コスト管理

### 予想コスト（月額）
```yaml
開発環境:
  - EC2 (t3.micro): $8-15
  - RDS (db.t3.micro): $15-25
  - Lambda: $5-10
  - S3: $5-10
  - その他: $10-20
  - 合計: $40-80/月

本番相当環境:
  - Auto Scaling: $50-100
  - Multi-AZ RDS: $30-60
  - Bedrock API: $20-50
  - その他: $20-40
  - 合計: $120-250/月
```

### コスト最適化機能
- 🔍 **リアルタイムコスト監視** - CloudWatch + SNS アラート
- ⏰ **自動停止スケジュール** - 開発環境の夜間・週末停止
- 🧹 **ワンクリッククリーンアップ** - 全リソース一括削除

## 🛡️ セキュリティ

### 実装済みセキュリティ機能
- 🔐 **IAM ベストプラクティス**: 最小権限・ロールベースアクセス
- 🛡️ **VPC セキュリティ**: プライベートサブネット・セキュリティグループ
- 🔒 **暗号化**: 保存時・転送時の暗号化
- 👤 **認証・認可**: Cognito + MFA設定
- 📊 **監査ログ**: CloudTrail + CloudWatch統合

## 📞 サポート・コミュニティ

### 質問・問題報告
- 🐛 **GitHub Issues**: バグ報告・機能要望
- 💬 **Discussions**: 学習相談・情報共有
- 📚 **Wiki**: FAQ・ナレッジベース

### 学習サポート
- ✅ **段階的なチェックポイント** - 各セクション完了確認
- 🔧 **詳細なトラブルシューティングガイド**
- 📖 **豊富な実装例とコード解説**

## 🗓️ 推奨学習スケジュール

### 集中学習（4週間）
```
Week 1: 基礎インフラ + Web三層（前半）
Week 2: Web三層（後半） + CRUD実装
Week 3: データ分析 + AI-ML統合（前半）
Week 4: AI-ML（後半） + CI-CD + Claude Code
```

### 週末学習（8週間）
```
Week 1-2: 基礎インフラストラクチャー
Week 3-4: Web三層アーキテクチャ
Week 5: CRUDシステム実装
Week 6: データ分析基盤
Week 7: AI-ML統合
Week 8: CI-CD + Claude Code
```

### 平日夜学習（12週間）
```
毎日1-2時間の継続学習
週末にまとめと実装確認
月1回の進捗レビュー
```

## 🏆 習得スキルレベル

完了時に到達できるスキルレベル：

```yaml
AWSアーキテクト:
  - ソリューションアーキテクト・アソシエイトレベル
  - セキュリティ専門知識レベル
  - DevOpsエンジニア・プロフェッショナルレベル

開発スキル:
  - フルスタック開発（初級〜中級）
  - API設計・実装（中級）
  - AI/ML統合開発（中級）

運用スキル:
  - CI/CD運用（中級）
  - 監視・ログ管理（中級）
  - コスト最適化（初級〜中級）
```

## 🚀 次のステップ

学習完了後の発展的な学習パス：

1. **🎓 AWS認定資格取得**
   - Solutions Architect Associate
   - Developer Associate
   - Machine Learning Specialty

2. **🔧 高度な技術習得**
   - Kubernetes (EKS)
   - マイクロサービス設計
   - イベント駆動アーキテクチャ

3. **🏢 エンタープライズ展開**
   - マルチアカウント戦略
   - コンプライアンス対応
   - 大規模システム設計

## 📞 お問い合わせ

- 📧 **Issues**: GitHub Issues で質問・バグ報告
- 💬 **Discussions**: 学習相談・情報交換
- 📖 **Wiki**: ドキュメント・FAQ

---

## ⭐ プロジェクトを開始する

準備ができましたか？まずは基礎から始めましょう！

**👉 [01-基礎インフラストラクチャー編](01-基礎インフラストラクチャー編/README.md) から学習を開始**

```bash
# 今すぐ始める
git clone https://github.com/YOUR_USERNAME/ai-driven-development-practice.git
cd ai-driven-development-practice
./scripts/deploy-all-infrastructure.sh deploy-foundation
```

**🎯 目標**: 80時間の学習で、AI時代のクラウドネイティブ開発者へ！

---

<div align="center">

**⚡ Start Your AI-Driven Development Journey Today! ⚡**

[![GitHub Stars](https://img.shields.io/github/stars/YOUR_USERNAME/ai-driven-development-practice?style=social)](https://github.com/YOUR_USERNAME/ai-driven-development-practice)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![AWS](https://img.shields.io/badge/AWS-Certified-orange.svg)](https://aws.amazon.com/)
[![Bedrock](https://img.shields.io/badge/Bedrock-AI-blue.svg)](https://aws.amazon.com/bedrock/)


</div>
