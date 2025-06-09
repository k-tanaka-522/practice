# AWS Cognito認証システム セキュリティベストプラクティス

## 概要

このドキュメントでは、AWS Cognitoを使用した認証システムの実装におけるセキュリティベストプラクティスについて説明します。

## 1. パスワードポリシー

### 実装済みのポリシー

```yaml
PasswordPolicy:
  MinimumLength: 12          # 12文字以上
  RequireUppercase: true     # 大文字必須
  RequireLowercase: true     # 小文字必須
  RequireNumbers: true       # 数字必須
  RequireSymbols: true       # 記号必須
  TemporaryPasswordValidityDays: 7  # 仮パスワードの有効期限
```

### 推奨事項

- **長さ**: NIST SP 800-63Bに基づき、最低12文字以上を推奨
- **複雑性**: 文字種の組み合わせより長さを重視
- **パスワード履歴**: 過去のパスワードの再利用を防ぐ
- **定期変更**: 定期的な変更を強制しない（侵害の兆候がない限り）

## 2. 多要素認証（MFA）

### 実装レベル

```yaml
MfaConfiguration: OPTIONAL  # 開発環境
# 本番環境では 'ON' を推奨
```

### MFAの種類

1. **TOTP（Time-based One-Time Password）**
   - Google Authenticator、Authyなどのアプリ使用
   - 実装済み: `SOFTWARE_TOKEN_MFA`

2. **SMS MFA**（非推奨）
   - SIMスワッピング攻撃のリスク
   - NIST SP 800-63Bでは非推奨

### ベストプラクティス

- 管理者アカウントには必須化
- ユーザーの利便性を考慮し、段階的に導入
- バックアップコードの提供

## 3. アカウントリカバリー

### 実装済みの設定

```yaml
AccountRecoverySetting:
  RecoveryMechanisms:
    - Name: verified_email
      Priority: 1
```

### セキュリティ考慮事項

- メールアドレスの事前検証が必須
- リカバリーコードの有効期限を短く設定
- リカバリー実行時の通知メール送信

## 4. 高度なセキュリティ機能

### Advanced Security Mode

```yaml
UserPoolAddOns:
  AdvancedSecurityMode: ENFORCED
```

このモードで有効になる機能：

1. **リスクベース認証**
   - 異常なログインパターンの検出
   - 新しいデバイスからのアクセス検知

2. **侵害された認証情報の保護**
   - 漏洩したパスワードのチェック
   - ブルートフォース攻撃の防御

3. **アダプティブ認証**
   - リスクレベルに応じた追加認証

## 5. トークン管理

### トークンの有効期限

```yaml
# Webクライアント
AccessTokenValidity: 60 minutes    # アクセストークン：60分
IdTokenValidity: 60 minutes        # IDトークン：60分
RefreshTokenValidity: 30 days      # リフレッシュトークン：30日

# サーバークライアント（より短い期限）
AccessTokenValidity: 30 minutes    # アクセストークン：30分
IdTokenValidity: 30 minutes        # IDトークン：30分
RefreshTokenValidity: 7 days       # リフレッシュトークン：7日
```

### トークン取り消し

```yaml
EnableTokenRevocation: true
```

- ログアウト時のトークン無効化
- セキュリティインシデント時の即座の無効化

## 6. 認証フロー

### 推奨される認証フロー

1. **SRP（Secure Remote Password）プロトコル**
   ```yaml
   - ALLOW_USER_SRP_AUTH
   ```
   - パスワードがネットワーク上を流れない
   - 最もセキュア

2. **USER_PASSWORD_AUTH**（簡易実装用）
   ```yaml
   - ALLOW_USER_PASSWORD_AUTH
   ```
   - HTTPS必須
   - 開発環境での使用に限定

### 避けるべき認証フロー

- `ALLOW_CUSTOM_AUTH`: 適切な実装が困難
- `ADMIN_NO_SRP_AUTH`: 管理者権限が必要で、SRPの利点なし

## 7. CORS設定

### 実装済みの設定

```javascript
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
  'Access-Control-Allow-Methods': 'POST,OPTIONS'
};
```

### 本番環境での推奨設定

```javascript
const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://yourdomain.com',  // 特定のドメインのみ
  'Access-Control-Allow-Credentials': 'true',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'POST'
};
```

## 8. ログとモニタリング

### CloudTrail統合

Cognitoのすべての認証イベントをCloudTrailでログ記録：

- サインイン成功/失敗
- パスワードリセット
- MFAの有効化/無効化
- ユーザー属性の変更

### CloudWatch Metrics

監視すべきメトリクス：

1. **SignIn_Successes**: ログイン成功数
2. **SignIn_Failures**: ログイン失敗数
3. **TokenRefresh_Successes**: トークンリフレッシュ成功数
4. **AccountTakeOver_Risk**: アカウント乗っ取りリスク

### アラート設定例

```yaml
# ログイン失敗の急増
FailedLoginAlarm:
  MetricName: SignIn_Failures
  Threshold: 10
  Period: 300  # 5分間
  EvaluationPeriods: 1
```

## 9. Lambda トリガーのセキュリティ

### Pre Sign-up

```javascript
// メールドメイン制限の例
const allowedDomains = ['company.com', 'partner.com'];
const domain = email.split('@')[1];
if (!allowedDomains.includes(domain)) {
  throw new Error('Email domain not allowed');
}
```

### Post Authentication

```javascript
// ログイン履歴の記録
await dynamodb.put({
  TableName: process.env.LOGIN_HISTORY_TABLE,
  Item: {
    userId: userId,
    timestamp: new Date().toISOString(),
    sourceIp: event.request.userContextData?.sourceIp,
    userAgent: event.request.userContextData?.userAgent
  }
}).promise();
```

## 10. データ保護

### 保管時の暗号化

- Cognitoは自動的にユーザーデータを暗号化
- DynamoDBテーブルでSSE有効化

```yaml
SSESpecification:
  SSEEnabled: true
```

### 転送時の暗号化

- すべての通信でHTTPS必須
- TLS 1.2以上を使用

## 11. アクセス制御

### 最小権限の原則

Lambda実行ロールの例：

```yaml
Policies:
  - PolicyName: CognitoPolicy
    PolicyDocument:
      Statement:
        - Effect: Allow
          Action:
            - cognito-idp:AdminGetUser
            - cognito-idp:AdminUpdateUserAttributes
          Resource: !GetAtt UserPool.Arn
```

### API Gatewayの認可

```yaml
AuthorizationType: COGNITO_USER_POOLS
AuthorizerId: !Ref CognitoAuthorizer
```

## 12. セキュリティチェックリスト

### 開発環境

- [ ] パスワードポリシーの設定
- [ ] HTTPS通信の確認
- [ ] CORSの適切な設定
- [ ] ログの有効化

### ステージング環境

- [ ] MFAのテスト
- [ ] Advanced Securityの有効化
- [ ] 監視アラートの設定
- [ ] ペネトレーションテスト

### 本番環境

- [ ] MFAの必須化（該当する場合）
- [ ] CORS制限の厳格化
- [ ] WAFの設定
- [ ] 定期的なセキュリティ監査

## 13. インシデント対応

### 不正アクセスの兆候

1. 大量のログイン失敗
2. 異常な地域からのアクセス
3. 短時間での複数デバイスからのログイン

### 対応手順

1. **即座の対応**
   - 該当ユーザーの無効化
   - すべてのトークンの無効化

2. **調査**
   - CloudTrailログの確認
   - ログイン履歴の分析

3. **復旧**
   - パスワードリセットの強制
   - MFAの再設定

## まとめ

セキュリティは継続的なプロセスです。定期的に以下を実施してください：

1. セキュリティ設定の見直し
2. 新しい脅威への対応
3. ユーザー教育の実施
4. インシデント対応訓練

最新のセキュリティベストプラクティスについては、[AWS Security Best Practices](https://docs.aws.amazon.com/cognito/latest/developerguide/security.html)を参照してください。