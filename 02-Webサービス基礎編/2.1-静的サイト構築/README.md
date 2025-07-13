# 2.1 静的サイト構築

## 🎯 このステップで学ぶこと

**S3 + CloudFront + Route53を使った高性能な静的Webサイト**を構築します。CDN配信、SSL証明書、カスタムドメインまで、本格的なWeb配信基盤を学習します。

## 📋 作成するリソース

- **S3バケット**: 静的ファイルのホスティング
- **CloudFront**: グローバルCDN配信
- **Route53**: カスタムドメイン設定（オプション）
- **ACM証明書**: SSL/TLS証明書（オプション）

## 🏗️ アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────┐
│                    Users                                    │
│              (Global Access)                               │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                 CloudFront                                  │
│              (Global CDN)                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Tokyo     │  │   London    │  │  New York   │         │
│  │ Edge Server │  │ Edge Server │  │ Edge Server │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    S3 Bucket                                │
│                (ap-northeast-1)                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ index.html  │  │    CSS      │  │  JavaScript │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 デプロイ手順

### 前提条件
- **実行ディレクトリ**: このREADMEがあるディレクトリ（`2.1-静的サイト構築/`）から実行してください
- **AWS CLI**: 設定済みであること
- **権限**: S3、CloudFront、Route53の作成権限があること

### 1. S3バケットの作成とテンプレートアップロード

```bash
# S3バケットの作成（バケット名は一意である必要があります）
BUCKET_NAME="aws-practice-cf-templates-$(date +%s)"
aws s3 mb "s3://$BUCKET_NAME"

# ネストスタックテンプレートをS3にアップロード
aws s3 cp cloudformation/templates/ "s3://$BUCKET_NAME/templates/" --recursive

# アップロード確認
aws s3 ls "s3://$BUCKET_NAME/templates/"
```

### 2. テンプレートの検証

```bash
# CloudFormationテンプレートの検証
aws cloudformation validate-template \
  --template-body file://cloudformation/main-stack.yaml
```

### 3. 静的サイト用スタックの作成

```bash
# 静的サイトスタックの作成
aws cloudformation create-stack \
  --stack-name aws-practice-static-site \
  --template-body file://cloudformation/main-stack.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=aws-practice \
               ParameterKey=EnvironmentName,ParameterValue=dev \
               ParameterKey=S3BucketName,ParameterValue=$BUCKET_NAME
```

### 4. デプロイの確認

```bash
# スタックの状態確認
aws cloudformation describe-stacks \
  --stack-name aws-practice-static-site

# 作成されたS3バケットの確認
aws s3 ls | grep aws-practice

# CloudFrontディストリビューションの確認
aws cloudfront list-distributions \
  --query 'DistributionList.Items[?contains(Comment,`aws-practice`)].{Id:Id,DomainName:DomainName,Status:Status}'
```

### 5. サンプルWebサイトのアップロード

```bash
# サンプルHTMLファイルの作成とアップロード
WEBSITE_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name aws-practice-static-site \
  --query 'Stacks[0].Outputs[?OutputKey==`WebsiteBucketName`].OutputValue' \
  --output text)

# サンプルファイルをアップロード
aws s3 cp web/ "s3://$WEBSITE_BUCKET/" --recursive

# Webサイトの確認
CLOUDFRONT_URL=$(aws cloudformation describe-stacks \
  --stack-name aws-practice-static-site \
  --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' \
  --output text)

echo "Website URL: $CLOUDFRONT_URL"
```

## 📊 確認事項

- [ ] S3バケットが作成されている
- [ ] CloudFrontディストリビューションが作成されている
- [ ] WebサイトがCloudFront経由でアクセス可能
- [ ] HTTPSでアクセス可能
- [ ] 適切なキャッシュヘッダーが設定されている

## 💡 ポイント

1. **グローバル配信**: CloudFrontにより世界中から高速アクセス
2. **セキュリティ**: HTTPS通信の強制
3. **コスト効率**: S3の低コストストレージ + CDNキャッシュ
4. **スケーラビリティ**: 大量アクセスに自動対応

## 🧪 テスト

### パフォーマンステスト
```bash
# CloudFrontのキャッシュ動作確認
curl -I $CLOUDFRONT_URL

# レスポンス時間測定
time curl -s $CLOUDFRONT_URL > /dev/null
```

### セキュリティテスト
```bash
# HTTPS強制の確認
curl -I http://$(echo $CLOUDFRONT_URL | sed 's/https://')

# セキュリティヘッダーの確認
curl -I $CLOUDFRONT_URL | grep -E "(Strict-Transport-Security|X-Content-Type-Options)"
```

## 🗑️ リソースの削除

```bash
# Webサイトファイルの削除
aws s3 rm "s3://$WEBSITE_BUCKET" --recursive

# スタックの削除
aws cloudformation delete-stack \
  --stack-name aws-practice-static-site

# スタック削除の完了を待機
aws cloudformation wait stack-delete-complete \
  --stack-name aws-practice-static-site

# S3バケットを空にして削除
aws s3 rm "s3://$BUCKET_NAME" --recursive
aws s3 rb "s3://$BUCKET_NAME"
```

## 📝 次のステップ

次は「2.2 API基盤構築」で、この静的サイトからアクセスするAPIを構築します。

---

**💰 コスト**: S3ストレージ + CloudFront転送量。小規模サイトなら月額$1-5程度。