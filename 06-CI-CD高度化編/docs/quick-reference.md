# 06-CI-CD高度化編 クイックリファレンス

## 🚀 よく使用するコマンド

### デプロイメント

```bash
# 完全CI/CDデプロイ
./scripts/deploy-cicd.sh deploy-all

# 個別コンポーネントデプロイ
./scripts/deploy-cicd.sh deploy-pipeline
./scripts/deploy-cicd.sh deploy-testing
./scripts/deploy-cicd.sh deploy-monitoring
./scripts/deploy-cicd.sh deploy-optimization

# 状況確認
./scripts/deploy-cicd.sh status

# クリーンアップ
./scripts/deploy-cicd.sh cleanup
```

### テスト実行

```bash
# 全テスト実行
npm run test:all

# 個別テスト
npm run test:unit
npm run test:integration
npm run test:e2e
npm run test:performance

# カバレッジ付き単体テスト
npm run test:unit -- --coverage

# テスト監視モード
npm run test:unit -- --watch
```

### CodePipeline操作

```bash
# パイプライン状況確認
aws codepipeline get-pipeline-state --name my-web-app-production-pipeline

# パイプライン手動実行
aws codepipeline start-pipeline-execution --name my-web-app-production-pipeline

# パイプライン停止
aws codepipeline stop-pipeline-execution --pipeline-name my-web-app-production-pipeline --pipeline-execution-id [ID]
```

### Blue/Greenデプロイメント

```bash
# CodeDeployアプリケーション確認
aws deploy list-applications

# デプロイメント作成
aws deploy create-deployment \
  --application-name my-web-app-codedeploy \
  --deployment-group-name production \
  --deployment-config-name CodeDeployDefault.ECSAllAtOnceBlueGreen

# デプロイメント状況監視
aws deploy get-deployment --deployment-id [DEPLOYMENT_ID]

# デプロイメント停止（ロールバック）
aws deploy stop-deployment --deployment-id [DEPLOYMENT_ID] --auto-rollback-enabled
```

### 監視とログ

```bash
# CloudWatch Logs確認
aws logs describe-log-groups --log-group-name-prefix /aws/codebuild/
aws logs get-log-events --log-group-name [LOG_GROUP] --log-stream-name [STREAM]

# X-Rayトレース確認
aws xray get-trace-summaries --time-range-type TimeRangeByStartTime --start-time [START] --end-time [END]

# カスタムメトリクス送信
aws cloudwatch put-metric-data \
  --namespace "MyApp/Business" \
  --metric-data MetricName=UserCount,Value=100,Unit=Count
```

## 📋 設定ファイルテンプレート

### package.json テストスクリプト

```json
{
  "scripts": {
    "test": "jest",
    "test:unit": "jest --testPathPattern=unit --coverage",
    "test:integration": "jest --testPathPattern=integration",
    "test:e2e": "cypress run",
    "test:performance": "k6 run tests/performance/load-test.js",
    "test:security": "npm audit && snyk test",
    "test:all": "npm run test:unit && npm run test:integration && npm run test:e2e",
    "test:watch": "jest --watch",
    "lint": "eslint src/**/*.js",
    "format": "prettier --write src/**/*.js",
    "format:check": "prettier --check src/**/*.js"
  }
}
```

### GitHub Actions Secrets

```bash
# 必須シークレット
gh secret set AWS_ACCESS_KEY_ID --body "YOUR_ACCESS_KEY"
gh secret set AWS_SECRET_ACCESS_KEY --body "YOUR_SECRET_KEY"
gh secret set AWS_REGION --body "ap-northeast-1"
gh secret set AWS_ACCOUNT_ID --body "$(aws sts get-caller-identity --query Account --output text)"

# 通知用（オプション）
gh secret set SLACK_WEBHOOK_URL --body "https://hooks.slack.com/..."
gh secret set PAGERDUTY_ROUTING_KEY --body "YOUR_ROUTING_KEY"

# セキュリティスキャン用
gh secret set SONAR_TOKEN --body "YOUR_SONAR_TOKEN"
gh secret set SNYK_TOKEN --body "YOUR_SNYK_TOKEN"
```

### Dockerfile (マルチステージビルド)

```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Test stage
FROM node:18-alpine AS tester
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run test:unit
RUN npm run lint

# Production stage
FROM node:18-alpine AS production
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
USER node
CMD ["npm", "start"]
```

## 🔧 トラブルシューティング

### よくある問題と解決策

#### 1. GitHub Actions実行エラー

**症状**: Workflow runs fail with permission errors
```bash
# 解決策
# 1. リポジトリ設定確認
gh repo view --json permissions

# 2. シークレット確認
gh secret list

# 3. ワークフロー権限設定
# .github/workflows/ci-cd.yml に追加:
permissions:
  contents: read
  security-events: write
  actions: write
```

#### 2. CodeBuild実行エラー

**症状**: Build fails in CodeBuild
```bash
# 解決策
# 1. ログ確認
aws logs describe-log-groups --log-group-name-prefix /aws/codebuild/

# 2. IAM権限確認
aws iam get-role-policy --role-name CodeBuildServiceRole --policy-name CodeBuildServiceRolePolicy

# 3. buildspec.yml 構文確認
aws codebuild validate-project --project your-project-name
```

#### 3. Blue/Greenデプロイエラー

**症状**: Deployment fails during traffic shifting
```bash
# 解決策
# 1. ヘルスチェック確認
curl -f http://your-green-environment/health

# 2. ターゲットグループ状況確認
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:...

# 3. 手動ロールバック
aws deploy stop-deployment --deployment-id d-XXXXXXXXX --auto-rollback-enabled
```

#### 4. テスト実行エラー

**症状**: Tests fail in CI environment but pass locally
```bash
# 解決策
# 1. 環境変数確認
printenv | grep TEST

# 2. テスト隔離確認
npm run test:unit -- --runInBand

# 3. メモリ不足チェック
node --max-old-space-size=4096 node_modules/.bin/jest
```

#### 5. 監視メトリクスが表示されない

**症状**: Custom metrics not appearing in CloudWatch
```bash
# 解決策
# 1. IAM権限確認
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::account:role/YourRole \
  --action-names cloudwatch:PutMetricData \
  --resource-arns "*"

# 2. メトリクス送信確認
aws logs filter-log-events \
  --log-group-name /aws/lambda/your-function \
  --filter-pattern "MetricData"

# 3. 名前空間確認
aws cloudwatch list-metrics --namespace "MyApp/Business"
```

## 📊 監視ダッシュボード重要メトリクス

### SLI/SLO定義

| メトリクス | SLI | SLO | アラート閾値 |
|------------|-----|-----|-------------|
| 可用性 | HTTP 200レスポンス率 | 99.9% | < 99.5% |
| レスポンス時間 | P95レスポンス時間 | < 500ms | > 750ms |
| エラー率 | HTTP 5XX率 | < 0.1% | > 0.5% |
| スループット | 1分間あたりリクエスト数 | - | 急激な変動 |

### 重要アラート設定

```bash
# 高エラー率アラーム
aws cloudwatch put-metric-alarm \
  --alarm-name "High-Error-Rate" \
  --alarm-description "Error rate exceeds 1%" \
  --metric-name "HTTPCode_Target_5XX_Count" \
  --namespace "AWS/ApplicationELB" \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2

# 低レスポンス時間アラーム
aws cloudwatch put-metric-alarm \
  --alarm-name "High-Response-Time" \
  --alarm-description "Response time exceeds 500ms" \
  --metric-name "TargetResponseTime" \
  --namespace "AWS/ApplicationELB" \
  --statistic Average \
  --period 300 \
  --threshold 0.5 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 3
```

## 🔄 定期メンテナンスタスク

### 日次
- [ ] パイプライン実行状況確認
- [ ] エラーログレビュー
- [ ] パフォーマンスメトリクス確認

### 週次
- [ ] セキュリティスキャン結果レビュー
- [ ] コストレポート確認
- [ ] テストカバレッジレビュー
- [ ] 障害対応手順確認

### 月次
- [ ] 依存関係更新
- [ ] インフラストラクチャレビュー
- [ ] キャパシティプランニング
- [ ] 災害復旧テスト

## 📞 サポートリソース

### ドキュメント
- [AWS CodePipeline ユーザーガイド](https://docs.aws.amazon.com/codepipeline/)
- [AWS CodeBuild ユーザーガイド](https://docs.aws.amazon.com/codebuild/)
- [AWS CodeDeploy ユーザーガイド](https://docs.aws.amazon.com/codedeploy/)
- [GitHub Actions ドキュメント](https://docs.github.com/actions)

### コミュニティ
- [AWS DevOps Blog](https://aws.amazon.com/blogs/devops/)
- [GitHub Community](https://github.community/)
- [Stack Overflow - AWS](https://stackoverflow.com/questions/tagged/aws)

### エマージェンシー連絡先
- AWS Support: [サポートケース作成](https://console.aws.amazon.com/support/)
- GitHub Support: [GitHub サポート](https://support.github.com/)

---

**💡 ヒント**: このリファレンスをブックマークして、日常的な運用作業で活用してください！