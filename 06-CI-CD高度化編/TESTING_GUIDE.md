# 🧪 CI/CD高度化編 テスト実行ガイド

## 🎯 テスト目的

このガイドでは、06-CI-CD高度化編で学習する内容を実際にテストし、動作確認を行う手順を説明します。

## 📋 事前準備チェックリスト

### 必須ツールの確認
```bash
# すべてのツールがインストールされているかチェック
aws --version          # AWS CLI v2.x
gh --version          # GitHub CLI v2.x
docker --version      # Docker
node --version        # Node.js v16+
python3 --version     # Python 3.8+
```

### AWS認証の確認
```bash
# AWS認証情報とアカウント情報の確認
aws sts get-caller-identity

# 出力例:
# {
#     "UserId": "AIDA5BY233I3NI3VHY2JE",
#     "Account": "897167645238", 
#     "Arn": "arn:aws:iam::897167645238:user/your-user"
# }
```

### GitHub認証の設定
```bash
# GitHub CLIの認証
gh auth login

# 認証状況の確認
gh auth status
```

## 🔧 基本機能テスト

### 1. CloudFormationテンプレート検証
```bash
# メインスタックテンプレートの検証
aws cloudformation validate-template \
  --template-body file://02-Webサービス基礎編/cloudformation/main-stack.yaml

# 個別テンプレートの検証
aws cloudformation validate-template \
  --template-body file://02-Webサービス基礎編/cloudformation/templates/s3-cloudfront.yaml

aws cloudformation validate-template \
  --template-body file://02-Webサービス基礎編/cloudformation/templates/cognito.yaml
```

### 2. ローカルデプロイテスト
```bash
# S3バケット作成（テンプレート格納用）
BUCKET_NAME="test-cf-templates-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region ap-northeast-1

# テンプレートのアップロード
aws s3 cp 02-Webサービス基礎編/cloudformation/templates/ \
  s3://$BUCKET_NAME/templates/ --recursive

# テストスタックのデプロイ
STACK_NAME="test-web-stack-$(date +%s)"
aws cloudformation deploy \
  --template-file 02-Webサービス基礎編/cloudformation/main-stack.yaml \
  --stack-name $STACK_NAME \
  --parameter-overrides \
    Environment=dev \
    ProjectName=test-app \
    S3BucketName=$BUCKET_NAME \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1

# デプロイ状況確認
aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query 'Stacks[0].StackStatus'

# スタック出力の確認
aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query 'Stacks[0].Outputs'
```

### 3. クリーンアップ
```bash
# スタック削除
aws cloudformation delete-stack --stack-name $STACK_NAME
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME

# S3バケット削除
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME
```

## 🚀 GitHub Actions テスト

### 1. リポジトリのfork（学習者が実行）
```bash
# このリポジトリをGitHubでfork
# https://github.com/YOUR_USERNAME/ai-driven-development-practice をfork

# forkしたリポジトリをclone
git clone https://github.com/YOUR_USERNAME/ai-driven-development-practice.git
cd ai-driven-development-practice
```

### 2. シークレットの設定
```bash
# GitHub CLIでシークレットを設定
gh secret set AWS_ACCESS_KEY_ID --body "YOUR_ACCESS_KEY"
gh secret set AWS_SECRET_ACCESS_KEY --body "YOUR_SECRET_KEY"
gh secret set AWS_REGION --body "ap-northeast-1"
gh secret set AWS_ACCOUNT_ID --body "$(aws sts get-caller-identity --query Account --output text)"

# 設定確認
gh secret list
```

### 3. テストワークフローの実行
```bash
# testブランチを作成してpush
git checkout -b test
git add .github/workflows/test-deployment.yml
git commit -m "Add test deployment workflow"
git push origin test

# GitHub Actionsの実行状況確認
gh run list --branch test
```

## 📊 テスト結果の確認

### 成功ケース
- ✅ すべてのCloudFormationテンプレートが検証をパス
- ✅ デプロイが完了し、スタックが作成される
- ✅ GitHub Actionsワークフローが正常実行
- ✅ リソースのクリーンアップが完了

### 想定される問題と対処法

#### 1. 権限エラー
```
Error: User is not authorized to perform: cloudformation:CreateStack
```
**対処法**: IAMユーザーにAdministrator権限を付与

#### 2. S3バケット名重複
```
Error: BucketAlreadyExists
```
**対処法**: バケット名にタイムスタンプを追加（済み）

#### 3. CloudFrontデプロイ時間
```
Status: CREATE_IN_PROGRESS (10-15分継続)
```
**対処法**: 正常な動作。CloudFrontは時間がかかります

#### 4. GitHub CLI認証エラー
```
Error: You are not logged into any GitHub hosts
```
**対処法**: `gh auth login` で再認証

## 🎯 テスト完了の判定基準

以下すべてが完了すればテスト成功です：

1. ✅ **CloudFormationテンプレート検証**: すべてのテンプレートがValidate成功
2. ✅ **ローカルデプロイ**: テストスタックの作成・削除が完了
3. ✅ **GitHub Actions**: ワークフローが正常実行
4. ✅ **クリーンアップ**: テストリソースがすべて削除済み

## 🔄 継続的な改善

テスト実行中に発見した問題は以下に記録：

### 発見された問題
- [ ] 問題1: 
- [ ] 問題2:

### 改善提案
- [ ] 改善案1:
- [ ] 改善案2:

## 📞 サポート

テスト実行中に問題が発生した場合：

1. **GitHub Issues**: リポジトリのIssuesページで問題を報告
2. **ログ確認**: AWS CloudFormationイベントログを確認
3. **GitHub Actions**: Actions実行ログを詳細確認

---

**🎉 テストが成功したら、実際の学習フローに進みましょう！**