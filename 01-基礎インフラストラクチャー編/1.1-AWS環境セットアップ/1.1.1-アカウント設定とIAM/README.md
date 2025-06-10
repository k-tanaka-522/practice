# 1.1.1 AWSアカウント設定とIAM

このモジュールでは、AWSアカウントの初期設定とIAM (Identity and Access Management) の基本的な構成について学習します。

## 📋 前提条件

- AWSアカウントを作成済みであること
- AWS CLIがインストールされていること（v2.0以降推奨）
- 基本的なコマンドライン操作の知識

## 🎯 学習目標

このモジュールを完了すると、以下のことができるようになります：

1. AWSアカウントのセキュリティ設定を適切に行う
2. IAMユーザー、グループ、ロールの概念を理解し、実装する
3. 最小権限の原則に基づいたアクセス制御を設計する
4. MFA（多要素認証）を設定し、強制する
5. CloudFormationを使用してIAMリソースを管理する
6. IAMアクティビティを監視し、セキュリティアラートを設定する

## 📚 セクション構成

### 1. AWSアカウントの初期設定

#### 1.1 ルートユーザーの保護
- ルートユーザーのMFA設定
- ルートユーザーのアクセスキー削除
- 緊急時のみの使用に限定

#### 1.2 請求アラートの設定
```bash
# AWS CLIで請求アラートを有効化
aws ce put-anomaly-monitor \
    --anomaly-monitor '{
        "MonitorName": "SpendMonitor",
        "MonitorType": "DIMENSIONAL",
        "MonitorDimension": "SERVICE"
    }'
```

#### 1.3 リージョン設定
デフォルトリージョンの設定と、使用しないリージョンの無効化

### 2. CloudFormationによるIAM構成

#### 2.1 マスタースタックのデプロイ

```bash
# S3バケットの作成（テンプレート保存用）
aws s3 mb s3://aws-learning-cfn-templates

# テンプレートのアップロード
aws s3 sync ./cloudformation/ s3://aws-learning-cfn-templates/iam-setup/v1/

# マスタースタックのデプロイ
aws cloudformation create-stack \
    --stack-name aws-learning-iam-setup \
    --template-body file://cloudformation/master-stack.yaml \
    --parameters \
        ParameterKey=EnvironmentName,ParameterValue=dev \
        ParameterKey=ProjectName,ParameterValue=aws-learning \
        ParameterKey=TemplateBucketName,ParameterValue=aws-learning-cfn-templates \
    --capabilities CAPABILITY_NAMED_IAM
```

#### 2.2 スタック構成

マスタースタックは以下のネストされたスタックを管理します：

1. **password-policy.yaml** - アカウントのパスワードポリシー設定
2. **base-iam-roles.yaml** - 基本的なIAMロールとMFA強制ポリシー
3. **iam-groups-users.yaml** - IAMグループとサンプルユーザー
4. **service-roles.yaml** - AWSサービス用のロール
5. **iam-monitoring.yaml** - CloudTrailとセキュリティ監視

### 3. IAMベストプラクティス

#### 3.1 最小権限の原則
- 必要最小限の権限のみを付与
- 定期的な権限の見直し
- 使用されていない権限の削除

#### 3.2 グループベースの権限管理
```yaml
# グループ構成例
Administrators    # フルアクセス（MFA必須）
PowerUsers       # IAM以外のフルアクセス
Developers       # 開発環境のリソースアクセス
ReadOnly         # 読み取り専用アクセス
Billing          # 請求情報へのアクセス
Security         # セキュリティ監査アクセス
```

#### 3.3 MFA強制ポリシー
MFAが設定されていない場合、以下の操作のみ許可：
- MFAデバイスの設定
- 自身のパスワード変更
- アカウント情報の確認

### 4. セキュリティ監視

#### 4.1 CloudTrailによる監視
- 全IAMアクションの記録
- S3への長期保存
- CloudWatch Logsへのリアルタイム転送

#### 4.2 アラート設定
以下のイベントで通知：
- 不正なAPIコール
- ルートアカウントの使用
- IAMポリシーの変更
- 複数回のサインイン失敗

### 5. 初期ユーザーの作成

#### 5.1 管理者ユーザーの作成
```bash
# ユーザー作成
aws iam create-user --user-name admin-user

# グループへの追加
aws iam add-user-to-group \
    --user-name admin-user \
    --group-name aws-learning-dev-Administrators

# 初期パスワードの設定
aws iam create-login-profile \
    --user-name admin-user \
    --password 'InitialPassword123!' \
    --password-reset-required
```

#### 5.2 MFAの設定
1. AWSマネジメントコンソールにサインイン
2. IAM > ユーザー > セキュリティ認証情報
3. MFAデバイスの割り当て
4. 仮想MFAデバイス（Google Authenticator等）の設定

## 🔧 トラブルシューティング

### よくある問題

1. **MFA強制後にアクセスできない**
   - 一時的にMFA強制ポリシーをデタッチ
   - MFAを設定後、再度アタッチ

2. **CloudFormationスタックの削除エラー**
   - 依存関係の順序で削除
   - S3バケットは手動で空にしてから削除

3. **権限不足エラー**
   - AssumeRole権限の確認
   - 信頼関係（Trust Relationship）の確認

## 📊 コスト見積もり

このモジュールの月額コスト（推定）：
- CloudTrail: $2.00（最初のトレイル無料）
- S3ストレージ: $0.50（ログ保存）
- CloudWatch Logs: $0.50
- **合計: 約$3.00/月**

## 🧹 クリーンアップ

リソースを削除する場合：

```bash
# CloudFormationスタックの削除
aws cloudformation delete-stack --stack-name aws-learning-iam-setup

# S3バケットの削除（中身を空にしてから）
aws s3 rm s3://aws-learning-cfn-templates --recursive
aws s3 rb s3://aws-learning-cfn-templates
```

## 📝 次のステップ

このモジュールを完了したら、次は「1.1.2 VPCとネットワーク基礎」に進みます。

## 🔗 参考リンク

- [AWS IAMベストプラクティス](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS CloudFormation IAMリソース](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/AWS_IAM.html)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)