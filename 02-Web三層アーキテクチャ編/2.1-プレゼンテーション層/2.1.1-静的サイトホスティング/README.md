# 2.1.1 静的サイトホスティング

## 学習目標

このセクションでは、Amazon S3とCloudFrontを活用してスケーラブルで高パフォーマンスな静的Webサイトホスティング環境を構築し、グローバル配信とセキュリティ対策を実装する方法を習得します。

### 習得できるスキル
- S3による静的ウェブサイトホスティング設定
- CloudFrontによるCDN配信と最適化
- Route 53によるドメイン管理とDNS設定
- SSL/TLS証明書の自動管理（ACM連携）
- オリジンアクセスアイデンティティ（OAI）によるセキュリティ強化
- キャッシュ戦略とパフォーマンス最適化

## 前提知識

### 必須の知識
- HTML/CSS/JavaScriptの基本知識
- HTTPとHTTPSの理解
- DNS基本概念
- AWS基本サービス（S3、CloudFront）の概要

### あると望ましい知識
- Webパフォーマンス最適化技術
- CDNの仕組みと効果
- SSL/TLS証明書の概念
- ドメイン登録・管理経験

## アーキテクチャ概要

### CloudFront + S3 グローバル配信アーキテクチャ

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
     │   (Tokyo)       │ │(Singapore│ │   (US-East)     │
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
              │  │    Caching Behaviors        │   │
              │  │  - HTML: 24 hours          │   │
              │  │  - CSS/JS: 1 year          │   │
              │  │  - Images: 1 year          │   │
              │  └─────────────────────────────┘   │
              └─────────────────┬───────────────────┘
                                │
                                ▼
              ┌─────────────────────────────────────┐
              │             AWS WAF                 │
              │         (Web Security)              │
              │                                     │
              │  ┌─────────────────────────────┐   │
              │  │    Security Rules           │   │
              │  │  - Rate Limiting            │   │
              │  │  - Geographic Filtering     │   │
              │  │  - SQL Injection Protection │   │
              │  └─────────────────────────────┘   │
              └─────────────────┬───────────────────┘
                                │
                                ▼
              ┌─────────────────────────────────────┐
              │           S3 Bucket                 │
              │        (Static Website)             │
              │                                     │
              │  ┌─────────────────────────────┐   │
              │  │     Web Content             │   │
              │  │  - index.html               │   │
              │  │  - assets/css/              │   │
              │  │  - assets/js/               │   │
              │  │  - assets/images/           │   │
              │  │  - error.html               │   │
              │  └─────────────────────────────┘   │
              └─────────────────────────────────────┘
                                │
                                ▼
              ┌─────────────────────────────────────┐
              │        Route 53                     │
              │    (DNS Management)                 │
              │                                     │
              │  ┌─────────────────────────────┐   │
              │  │    DNS Records              │   │
              │  │  - A Record (Alias)         │   │
              │  │  - AAAA Record (IPv6)       │   │
              │  │  - CNAME (www subdomain)    │   │
              │  └─────────────────────────────┘   │
              └─────────────────────────────────────┘
```

### 主要コンポーネント
- **S3 Bucket**: 静的ファイルストレージとウェブサイトホスティング
- **CloudFront**: グローバルCDN配信とキャッシュ最適化
- **Route 53**: ドメイン管理とDNSルーティング
- **AWS Certificate Manager**: SSL/TLS証明書自動管理
- **AWS WAF**: Web Application Firewall（セキュリティ保護）

## ハンズオン手順

### ステップ1: S3バケットとウェブサイト設定

1. **サンプルWebサイトファイルの作成**
```bash
cd /mnt/c/dev2/practice/02-Web三層アーキテクチャ編/2.1-プレゼンテーション層/2.1.1-静的サイトホスティング/src/assets
```

2. **index.html（メインページ）**
```html
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AWS静的サイトホスティング - デモサイト</title>
    <link rel="stylesheet" href="assets/css/style.css">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@300;400;500;700&display=swap" rel="stylesheet">
</head>
<body>
    <header class="header">
        <nav class="navbar">
            <div class="container">
                <div class="nav-brand">
                    <h1>AWS Static Site</h1>
                </div>
                <ul class="nav-menu">
                    <li><a href="#home">ホーム</a></li>
                    <li><a href="#features">特徴</a></li>
                    <li><a href="#architecture">アーキテクチャ</a></li>
                    <li><a href="#contact">お問い合わせ</a></li>
                </ul>
            </div>
        </nav>
    </header>

    <main>
        <section id="home" class="hero">
            <div class="container">
                <div class="hero-content">
                    <h2>AWS CloudFront + S3による<br>高速静的サイトホスティング</h2>
                    <p>グローバルCDN配信で世界中のユーザーに高速なWebサイト体験を提供</p>
                    <div class="hero-stats">
                        <div class="stat">
                            <span class="stat-number" id="loadTime">0.8</span>
                            <span class="stat-label">秒</span>
                            <span class="stat-desc">平均読み込み時間</span>
                        </div>
                        <div class="stat">
                            <span class="stat-number" id="cacheHit">95</span>
                            <span class="stat-label">%</span>
                            <span class="stat-desc">キャッシュヒット率</span>
                        </div>
                        <div class="stat">
                            <span class="stat-number" id="availability">99.9</span>
                            <span class="stat-label">%</span>
                            <span class="stat-desc">可用性</span>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <section id="features" class="features">
            <div class="container">
                <h2>主要機能</h2>
                <div class="features-grid">
                    <div class="feature-card">
                        <div class="feature-icon">🚀</div>
                        <h3>高速配信</h3>
                        <p>CloudFrontの200以上のエッジロケーションから最適な場所でコンテンツを配信</p>
                    </div>
                    <div class="feature-card">
                        <div class="feature-icon">🔒</div>
                        <h3>セキュリティ</h3>
                        <p>AWS WAFとSSL/TLS暗号化でWebサイトを包括的に保護</p>
                    </div>
                    <div class="feature-card">
                        <div class="feature-icon">💰</div>
                        <h3>コスト効率</h3>
                        <p>従量課金制で無駄なコストを削減、使った分だけお支払い</p>
                    </div>
                    <div class="feature-card">
                        <div class="feature-icon">⚡</div>
                        <h3>自動スケーリング</h3>
                        <p>トラフィック急増時も自動的にスケールして可用性を維持</p>
                    </div>
                </div>
            </div>
        </section>

        <section id="architecture" class="architecture">
            <div class="container">
                <h2>アーキテクチャ構成</h2>
                <div class="arch-diagram">
                    <div class="arch-component">
                        <div class="component-box user">
                            <span>👥 ユーザー</span>
                        </div>
                    </div>
                    <div class="arch-arrow">↓</div>
                    <div class="arch-component">
                        <div class="component-box route53">
                            <span>🌐 Route 53</span>
                            <small>DNS管理</small>
                        </div>
                    </div>
                    <div class="arch-arrow">↓</div>
                    <div class="arch-component">
                        <div class="component-box cloudfront">
                            <span>⚡ CloudFront</span>
                            <small>CDN配信</small>
                        </div>
                    </div>
                    <div class="arch-arrow">↓</div>
                    <div class="arch-component">
                        <div class="component-box s3">
                            <span>📦 S3 Bucket</span>
                            <small>静的ファイル</small>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    </main>

    <footer class="footer">
        <div class="container">
            <p>&copy; 2024 AWS Static Site Demo. Powered by Amazon Web Services.</p>
            <div class="footer-info">
                <span id="buildInfo">Build: <span id="buildTime"></span></span>
                <span id="regionInfo">Region: <span id="region">ap-northeast-1</span></span>
            </div>
        </div>
    </footer>

    <script src="assets/js/main.js"></script>
</body>
</html>
```

3. **CSS（スタイルファイル）**
```css
/* assets/css/style.css */
:root {
    --primary-color: #ff9900;
    --secondary-color: #232f3e;
    --text-color: #333;
    --bg-color: #f8f9fa;
    --white: #ffffff;
    --border-color: #e9ecef;
    --shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    --gradient-bg: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Noto Sans JP', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    line-height: 1.6;
    color: var(--text-color);
    background-color: var(--bg-color);
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 20px;
}

/* Header */
.header {
    background-color: var(--white);
    box-shadow: var(--shadow);
    position: sticky;
    top: 0;
    z-index: 1000;
}

.navbar {
    padding: 1rem 0;
}

.navbar .container {
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.nav-brand h1 {
    color: var(--primary-color);
    font-size: 1.8rem;
    font-weight: 700;
}

.nav-menu {
    display: flex;
    list-style: none;
    gap: 2rem;
}

.nav-menu a {
    text-decoration: none;
    color: var(--text-color);
    font-weight: 500;
    transition: color 0.3s ease;
}

.nav-menu a:hover {
    color: var(--primary-color);
}

/* Hero Section */
.hero {
    background: var(--gradient-bg);
    color: var(--white);
    padding: 5rem 0;
    text-align: center;
}

.hero-content h2 {
    font-size: 3rem;
    margin-bottom: 1rem;
    font-weight: 700;
}

.hero-content p {
    font-size: 1.2rem;
    margin-bottom: 3rem;
    opacity: 0.9;
}

.hero-stats {
    display: flex;
    justify-content: center;
    gap: 3rem;
    margin-top: 3rem;
}

.stat {
    text-align: center;
}

.stat-number {
    display: block;
    font-size: 3rem;
    font-weight: 700;
    color: var(--white);
}

.stat-label {
    font-size: 1.2rem;
    opacity: 0.8;
}

.stat-desc {
    display: block;
    font-size: 0.9rem;
    opacity: 0.7;
    margin-top: 0.5rem;
}

/* Features Section */
.features {
    padding: 5rem 0;
    background-color: var(--white);
}

.features h2 {
    text-align: center;
    font-size: 2.5rem;
    margin-bottom: 3rem;
    color: var(--secondary-color);
}

.features-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 2rem;
}

.feature-card {
    padding: 2rem;
    border-radius: 10px;
    box-shadow: var(--shadow);
    text-align: center;
    transition: transform 0.3s ease;
}

.feature-card:hover {
    transform: translateY(-5px);
}

.feature-icon {
    font-size: 3rem;
    margin-bottom: 1rem;
}

.feature-card h3 {
    color: var(--secondary-color);
    margin-bottom: 1rem;
    font-size: 1.5rem;
}

.feature-card p {
    color: #666;
    line-height: 1.6;
}

/* Architecture Section */
.architecture {
    padding: 5rem 0;
    background-color: var(--bg-color);
}

.architecture h2 {
    text-align: center;
    font-size: 2.5rem;
    margin-bottom: 3rem;
    color: var(--secondary-color);
}

.arch-diagram {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
}

.arch-component {
    display: flex;
    justify-content: center;
}

.component-box {
    background-color: var(--white);
    padding: 1.5rem 2rem;
    border-radius: 10px;
    box-shadow: var(--shadow);
    text-align: center;
    min-width: 200px;
    transition: all 0.3s ease;
}

.component-box:hover {
    transform: scale(1.05);
}

.component-box span {
    display: block;
    font-weight: 600;
    font-size: 1.1rem;
}

.component-box small {
    color: #666;
    font-size: 0.9rem;
}

.arch-arrow {
    font-size: 2rem;
    color: var(--primary-color);
    font-weight: bold;
}

/* Component Colors */
.user { border-left: 4px solid #28a745; }
.route53 { border-left: 4px solid #ff9900; }
.cloudfront { border-left: 4px solid #0066cc; }
.s3 { border-left: 4px solid #dc3545; }

/* Footer */
.footer {
    background-color: var(--secondary-color);
    color: var(--white);
    padding: 2rem 0;
    text-align: center;
}

.footer-info {
    margin-top: 1rem;
    display: flex;
    justify-content: center;
    gap: 2rem;
    font-size: 0.9rem;
    opacity: 0.8;
}

/* Responsive Design */
@media (max-width: 768px) {
    .nav-menu {
        display: none;
    }
    
    .hero-content h2 {
        font-size: 2rem;
    }
    
    .hero-stats {
        flex-direction: column;
        gap: 1.5rem;
    }
    
    .footer-info {
        flex-direction: column;
        gap: 0.5rem;
    }
}

/* Performance Optimizations */
.hero-content {
    will-change: transform;
}

.feature-card, .component-box {
    backface-visibility: hidden;
}

/* Loading Animation */
@keyframes fadeInUp {
    from {
        opacity: 0;
        transform: translateY(30px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}

.feature-card {
    animation: fadeInUp 0.6s ease forwards;
}

.feature-card:nth-child(1) { animation-delay: 0.1s; }
.feature-card:nth-child(2) { animation-delay: 0.2s; }
.feature-card:nth-child(3) { animation-delay: 0.3s; }
.feature-card:nth-child(4) { animation-delay: 0.4s; }
```

4. **JavaScript（インタラクティブ機能）**
```javascript
// assets/js/main.js
document.addEventListener('DOMContentLoaded', function() {
    // Build time display
    const buildTime = new Date().toLocaleString('ja-JP');
    const buildTimeElement = document.getElementById('buildTime');
    if (buildTimeElement) {
        buildTimeElement.textContent = buildTime;
    }

    // Smooth scrolling for navigation links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });

    // Animate statistics on scroll
    const observerOptions = {
        threshold: 0.5,
        rootMargin: '0px 0px -100px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                animateStats();
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    const statsSection = document.querySelector('.hero-stats');
    if (statsSection) {
        observer.observe(statsSection);
    }

    function animateStats() {
        const stats = [
            { element: 'loadTime', target: 0.8, duration: 2000 },
            { element: 'cacheHit', target: 95, duration: 2500 },
            { element: 'availability', target: 99.9, duration: 3000 }
        ];

        stats.forEach(stat => {
            const element = document.getElementById(stat.element);
            if (element) {
                animateNumber(element, 0, stat.target, stat.duration);
            }
        });
    }

    function animateNumber(element, start, end, duration) {
        const range = end - start;
        const startTime = performance.now();

        function updateNumber(currentTime) {
            const elapsed = currentTime - startTime;
            const progress = Math.min(elapsed / duration, 1);
            
            // Easing function (ease-out)
            const easeOut = 1 - Math.pow(1 - progress, 3);
            const current = start + (range * easeOut);
            
            if (end < 10) {
                element.textContent = current.toFixed(1);
            } else {
                element.textContent = Math.floor(current);
            }

            if (progress < 1) {
                requestAnimationFrame(updateNumber);
            }
        }

        requestAnimationFrame(updateNumber);
    }

    // CloudFront performance metrics simulation
    function updatePerformanceMetrics() {
        const metrics = {
            responseTime: Math.random() * 200 + 50, // 50-250ms
            throughput: Math.random() * 1000 + 500,  // 500-1500 requests/sec
            errorRate: Math.random() * 0.1           // 0-0.1%
        };

        // Log metrics for debugging
        console.log('Performance Metrics:', metrics);
        
        // In a real application, these would be sent to CloudWatch
        if (window.AWS && window.AWS.CloudWatch) {
            // Send custom metrics to CloudWatch
            sendCustomMetrics(metrics);
        }
    }

    // Simulate sending metrics to CloudWatch
    function sendCustomMetrics(metrics) {
        // This would be implemented with AWS SDK
        console.log('Sending metrics to CloudWatch:', metrics);
    }

    // Update metrics every 30 seconds
    setInterval(updatePerformanceMetrics, 30000);

    // Initial performance check
    const perfData = performance.getEntriesByType('navigation')[0];
    if (perfData) {
        console.log('Page Load Performance:', {
            domContentLoaded: perfData.domContentLoadedEventEnd - perfData.domContentLoadedEventStart,
            loadComplete: perfData.loadEventEnd - perfData.loadEventStart,
            domProcessing: perfData.domComplete - perfData.domLoading
        });
    }

    // Service Worker registration for caching (if supported)
    if ('serviceWorker' in navigator) {
        window.addEventListener('load', () => {
            navigator.serviceWorker.register('/sw.js')
                .then(registration => {
                    console.log('SW registered: ', registration);
                })
                .catch(registrationError => {
                    console.log('SW registration failed: ', registrationError);
                });
        });
    }
});

// Error boundary for JavaScript errors
window.addEventListener('error', function(event) {
    console.error('JavaScript Error:', event.error);
    
    // In production, send errors to CloudWatch Logs
    if (window.AWS && window.AWS.CloudWatchLogs) {
        // Send error to CloudWatch
        console.log('Error would be sent to CloudWatch Logs');
    }
});

// Performance observer for Core Web Vitals
if ('PerformanceObserver' in window) {
    const observer = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
            console.log(`${entry.name}: ${entry.value}`);
        }
    });
    
    observer.observe({ entryTypes: ['measure', 'navigation'] });
}
```

### ステップ2: CloudFormation テンプレートでS3とCloudFront構築

1. **S3 + CloudFront + Route 53 統合テンプレート**
```yaml
# cloudformation/static-website.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Complete static website hosting with S3, CloudFront, Route 53, and ACM'

Parameters:
  ProjectName:
    Type: String
    Default: 'static-website'
    Description: 'Project name for resource naming'
  
  EnvironmentName:
    Type: String
    Default: 'prod'
    AllowedValues: [dev, staging, prod]
    Description: 'Environment name'
  
  DomainName:
    Type: String
    Description: 'Domain name for the website (e.g., example.com)'
    AllowedPattern: '^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\..*$'
  
  CreateHostedZone:
    Type: String
    Default: 'false'
    AllowedValues: ['true', 'false']
    Description: 'Whether to create a new Route 53 hosted zone'

Conditions:
  ShouldCreateHostedZone: !Equals [!Ref CreateHostedZone, 'true']
  IsProduction: !Equals [!Ref EnvironmentName, 'prod']

Resources:
  # S3 Bucket for static website hosting
  WebsiteBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-${EnvironmentName}-website-${AWS::AccountId}'
      WebsiteConfiguration:
        IndexDocument: index.html
        ErrorDocument: error.html
      VersioningConfiguration:
        Status: !If [IsProduction, Enabled, Suspended]
      LifecycleConfiguration:
        Rules:
          - Id: DeleteIncompleteMultipartUploads
            Status: Enabled
            AbortIncompleteMultipartUpload:
              DaysAfterInitiation: 1
          - Id: DeleteOldVersions
            Status: !If [IsProduction, Enabled, Disabled]
            NoncurrentVersionExpirationInDays: 30
      NotificationConfiguration:
        CloudWatchConfigurations:
          - Event: s3:ObjectCreated:*
            CloudWatchConfiguration:
              LogGroupName: !Ref WebsiteLogGroup
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # S3 Bucket Policy for CloudFront access
  WebsiteBucketPolicy:
    Type: AWS::S3::BucketPolicy
    Properties:
      Bucket: !Ref WebsiteBucket
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Sid: AllowCloudFrontServicePrincipal
            Effect: Allow
            Principal:
              Service: cloudfront.amazonaws.com
            Action: s3:GetObject
            Resource: !Sub '${WebsiteBucket}/*'
            Condition:
              StringEquals:
                'AWS:SourceArn': !Sub 'arn:aws:cloudfront::${AWS::AccountId}:distribution/${CloudFrontDistribution}'

  # Origin Access Control for CloudFront
  OriginAccessControl:
    Type: AWS::CloudFront::OriginAccessControl
    Properties:
      OriginAccessControlConfig:
        Name: !Sub '${ProjectName}-${EnvironmentName}-oac'
        OriginAccessControlOriginType: s3
        SigningBehavior: always
        SigningProtocol: sigv4

  # SSL Certificate
  SSLCertificate:
    Type: AWS::CertificateManager::Certificate
    Properties:
      DomainName: !Ref DomainName
      SubjectAlternativeNames:
        - !Sub 'www.${DomainName}'
      ValidationMethod: DNS
      DomainValidationOptions:
        - DomainName: !Ref DomainName
          HostedZoneId: !If [ShouldCreateHostedZone, !Ref HostedZone, !Ref ExistingHostedZone]
        - DomainName: !Sub 'www.${DomainName}'
          HostedZoneId: !If [ShouldCreateHostedZone, !Ref HostedZone, !Ref ExistingHostedZone]
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # WAF Web ACL for CloudFront
  WebACL:
    Type: AWS::WAFv2::WebACL
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-waf'
      Scope: CLOUDFRONT
      DefaultAction:
        Allow: {}
      Rules:
        - Name: RateLimitRule
          Priority: 1
          Statement:
            RateBasedStatement:
              Limit: 10000
              AggregateKeyType: IP
          Action:
            Block: {}
          VisibilityConfig:
            SampledRequestsEnabled: true
            CloudWatchMetricsEnabled: true
            MetricName: RateLimitRule
        - Name: SQLInjectionRule
          Priority: 2
          Statement:
            SqliMatchStatement:
              FieldToMatch:
                QueryString: {}
              TextTransformations:
                - Priority: 0
                  Type: URL_DECODE
                - Priority: 1
                  Type: HTML_ENTITY_DECODE
          Action:
            Block: {}
          VisibilityConfig:
            SampledRequestsEnabled: true
            CloudWatchMetricsEnabled: true
            MetricName: SQLInjectionRule
      VisibilityConfig:
        SampledRequestsEnabled: true
        CloudWatchMetricsEnabled: true
        MetricName: !Sub '${ProjectName}-${EnvironmentName}-waf'
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # CloudFront Distribution
  CloudFrontDistribution:
    Type: AWS::CloudFront::Distribution
    Properties:
      DistributionConfig:
        Origins:
          - Id: S3Origin
            DomainName: !GetAtt WebsiteBucket.RegionalDomainName
            S3OriginConfig:
              OriginAccessIdentity: ''
            OriginAccessControlId: !Ref OriginAccessControl
        Enabled: true
        HttpVersion: http2
        DefaultRootObject: index.html
        Aliases:
          - !Ref DomainName
          - !Sub 'www.${DomainName}'
        DefaultCacheBehavior:
          AllowedMethods:
            - DELETE
            - GET
            - HEAD
            - OPTIONS
            - PATCH
            - POST
            - PUT
          CachedMethods:
            - GET
            - HEAD
          TargetOriginId: S3Origin
          ForwardedValues:
            QueryString: false
            Cookies:
              Forward: none
          ViewerProtocolPolicy: redirect-to-https
          MinTTL: 0
          DefaultTTL: !If [IsProduction, 86400, 300]  # 1 day prod, 5 min dev
          MaxTTL: !If [IsProduction, 31536000, 86400]  # 1 year prod, 1 day dev
          Compress: true
        CacheBehaviors:
          - PathPattern: '/assets/css/*'
            TargetOriginId: S3Origin
            ViewerProtocolPolicy: redirect-to-https
            AllowedMethods: [GET, HEAD]
            CachedMethods: [GET, HEAD]
            ForwardedValues:
              QueryString: false
              Cookies:
                Forward: none
            DefaultTTL: 31536000  # 1 year
            MaxTTL: 31536000
            MinTTL: 31536000
            Compress: true
          - PathPattern: '/assets/js/*'
            TargetOriginId: S3Origin
            ViewerProtocolPolicy: redirect-to-https
            AllowedMethods: [GET, HEAD]
            CachedMethods: [GET, HEAD]
            ForwardedValues:
              QueryString: false
              Cookies:
                Forward: none
            DefaultTTL: 31536000
            MaxTTL: 31536000
            MinTTL: 31536000
            Compress: true
          - PathPattern: '/assets/images/*'
            TargetOriginId: S3Origin
            ViewerProtocolPolicy: redirect-to-https
            AllowedMethods: [GET, HEAD]
            CachedMethods: [GET, HEAD]
            ForwardedValues:
              QueryString: false
              Cookies:
                Forward: none
            DefaultTTL: 31536000
            MaxTTL: 31536000
            MinTTL: 31536000
            Compress: true
        CustomErrorResponses:
          - ErrorCode: 403
            ResponseCode: 200
            ResponsePagePath: /index.html
            ErrorCachingMinTTL: 300
          - ErrorCode: 404
            ResponseCode: 200
            ResponsePagePath: /index.html
            ErrorCachingMinTTL: 300
        PriceClass: !If [IsProduction, PriceClass_All, PriceClass_100]
        ViewerCertificate:
          AcmCertificateArn: !Ref SSLCertificate
          SslSupportMethod: sni-only
          MinimumProtocolVersion: TLSv1.2_2021
        WebACLId: !GetAtt WebACL.Arn
        Logging:
          Bucket: !GetAtt LoggingBucket.DomainName
          IncludeCookies: false
          Prefix: cloudfront-logs/
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # S3 Bucket for CloudFront logs
  LoggingBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${ProjectName}-${EnvironmentName}-cloudfront-logs-${AWS::AccountId}'
      LifecycleConfiguration:
        Rules:
          - Id: DeleteLogs
            Status: Enabled
            ExpirationInDays: !If [IsProduction, 90, 30]
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true

  # Route 53 Hosted Zone (if creating new)
  HostedZone:
    Type: AWS::Route53::HostedZone
    Condition: ShouldCreateHostedZone
    Properties:
      Name: !Ref DomainName
      HostedZoneConfig:
        Comment: !Sub 'Hosted zone for ${ProjectName} ${EnvironmentName}'
      HostedZoneTags:
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # DNS Records
  DNSRecord:
    Type: AWS::Route53::RecordSet
    Properties:
      HostedZoneId: !If [ShouldCreateHostedZone, !Ref HostedZone, !Ref ExistingHostedZone]
      Name: !Ref DomainName
      Type: A
      AliasTarget:
        DNSName: !GetAtt CloudFrontDistribution.DomainName
        HostedZoneId: Z2FDTNDATAQYW2  # CloudFront hosted zone ID
        EvaluateTargetHealth: false

  WWWDNSRecord:
    Type: AWS::Route53::RecordSet
    Properties:
      HostedZoneId: !If [ShouldCreateHostedZone, !Ref HostedZone, !Ref ExistingHostedZone]
      Name: !Sub 'www.${DomainName}'
      Type: A
      AliasTarget:
        DNSName: !GetAtt CloudFrontDistribution.DomainName
        HostedZoneId: Z2FDTNDATAQYW2
        EvaluateTargetHealth: false

  # CloudWatch Log Group for website events
  WebsiteLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/aws/s3/${ProjectName}-${EnvironmentName}-website'
      RetentionInDays: !If [IsProduction, 90, 30]

Outputs:
  WebsiteBucketName:
    Description: 'S3 Bucket for website hosting'
    Value: !Ref WebsiteBucket
    Export:
      Name: !Sub '${AWS::StackName}-WebsiteBucket'
  
  CloudFrontDistributionId:
    Description: 'CloudFront Distribution ID'
    Value: !Ref CloudFrontDistribution
    Export:
      Name: !Sub '${AWS::StackName}-CloudFrontDistribution'
  
  CloudFrontDomainName:
    Description: 'CloudFront Distribution Domain Name'
    Value: !GetAtt CloudFrontDistribution.DomainName
    Export:
      Name: !Sub '${AWS::StackName}-CloudFrontDomain'
  
  WebsiteURL:
    Description: 'Website URL'
    Value: !Sub 'https://${DomainName}'
    Export:
      Name: !Sub '${AWS::StackName}-WebsiteURL'
  
  SSLCertificateArn:
    Description: 'SSL Certificate ARN'
    Value: !Ref SSLCertificate
    Export:
      Name: !Sub '${AWS::StackName}-SSLCertificate'
```

### ステップ3: デプロイとファイル同期

1. **CloudFormationデプロイ**
```bash
# スタック作成
aws cloudformation create-stack \
  --stack-name static-website-prod \
  --template-body file://cloudformation/static-website.yaml \
  --parameters ParameterKey=DomainName,ParameterValue=your-domain.com \
               ParameterKey=CreateHostedZone,ParameterValue=true \
  --capabilities CAPABILITY_IAM
```

2. **ファイル同期スクリプト**
```bash
#!/bin/bash
# scripts/deploy-website.sh

set -e

PROJECT_NAME="static-website"
ENVIRONMENT="prod"
REGION="us-east-1"

# Get bucket name from CloudFormation
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT} \
  --query 'Stacks[0].Outputs[?OutputKey==`WebsiteBucketName`].OutputValue' \
  --output text)

DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT} \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
  --output text)

echo "Deploying to bucket: $BUCKET_NAME"

# Sync files to S3 with appropriate cache headers
aws s3 sync src/ s3://$BUCKET_NAME/ \
  --delete \
  --exclude "*.DS_Store" \
  --exclude "*.git/*" \
  --cache-control "public, max-age=31536000" \
  --metadata-directive REPLACE

# Set specific cache headers for HTML files
aws s3 cp src/index.html s3://$BUCKET_NAME/index.html \
  --cache-control "public, max-age=0, must-revalidate" \
  --content-type "text/html"

aws s3 cp src/error.html s3://$BUCKET_NAME/error.html \
  --cache-control "public, max-age=0, must-revalidate" \
  --content-type "text/html"

# Invalidate CloudFront cache
echo "Invalidating CloudFront cache..."
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*"

echo "Deployment complete!"
echo "Website URL: https://$(aws cloudformation describe-stacks \
  --stack-name ${PROJECT_NAME}-${ENVIRONMENT} \
  --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' \
  --output text)"
```

## 検証方法

### 1. ウェブサイト動作確認
```bash
# DNS解決確認
nslookup your-domain.com

# HTTPSアクセステスト
curl -I https://your-domain.com

# パフォーマンステスト
curl -w "@curl-format.txt" -o /dev/null -s https://your-domain.com
```

### 2. CloudFrontキャッシュ効果確認
```bash
# キャッシュヒット確認
curl -I https://your-domain.com/assets/css/style.css | grep -i x-cache

# 異なるエッジロケーションからのテスト
for region in us-east-1 eu-west-1 ap-northeast-1; do
  aws cloudfront get-distribution --id $DISTRIBUTION_ID --region $region
done
```

### 3. セキュリティテスト
```bash
# SSL証明書確認
openssl s_client -connect your-domain.com:443 -servername your-domain.com

# WAFルール動作確認
curl -X GET "https://your-domain.com/?id=1' OR '1'='1"  # SQL Injection test
```

## トラブルシューティング

### よくある問題と解決策

#### 1. DNS設定エラー
**症状**: ドメインにアクセスできない
**解決策**:
- Route 53レコード設定確認
- DNSプロパゲーション待機（最大48時間）
- ネームサーバー設定確認

#### 2. SSL証明書検証失敗
**症状**: HTTPS接続エラー
**解決策**:
```bash
# 証明書ステータス確認
aws acm describe-certificate --certificate-arn $CERT_ARN

# DNS検証レコード確認
aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID
```

#### 3. CloudFrontキャッシュ問題
**症状**: 更新が反映されない
**解決策**:
```bash
# キャッシュ無効化
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*"

# キャッシュ動作確認
curl -I https://your-domain.com | grep -i x-cache
```

## 学習リソース

### AWS公式ドキュメント
- [Amazon S3 Static Website Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [Amazon CloudFront Developer Guide](https://docs.aws.amazon.com/cloudfront/latest/developerguide/)
- [AWS Certificate Manager User Guide](https://docs.aws.amazon.com/acm/latest/userguide/)

### 追加学習教材
- [Web Performance Best Practices](https://web.dev/performance/)
- [CloudFront Caching Strategies](https://aws.amazon.com/cloudfront/features/)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **OAC使用**: S3バケットへの直接アクセス防止
2. **WAF設定**: 一般的なWeb攻撃からの保護
3. **HTTPS強制**: 全通信の暗号化
4. **適切なCORS設定**: クロスオリジンリクエスト制御

### コスト最適化
1. **適切なキャッシュ設定**: データ転送量削減
2. **価格クラス選択**: 不要なエッジロケーション除外
3. **ログ保持期間**: 必要最小限の設定
4. **リクエスト最適化**: 不要なリクエスト削減

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatchによる監視と自動化
- **セキュリティの柱**: WAF・SSL/TLS・OAC
- **信頼性の柱**: グローバル配信と冗長性
- **パフォーマンス効率の柱**: CDNキャッシングと圧縮
- **コスト最適化の柱**: 効率的なキャッシュ戦略

## 次のステップ

### 推奨される学習パス
1. **2.1.2 React-Next.js**: 動的フロントエンド開発
2. **2.2.1 REST-API**: バックエンドAPI連携
3. **6.1.1 マルチステージビルド**: CI/CD統合
4. **6.2.1 APM実装**: パフォーマンス監視

### 発展的な機能
1. **Lambda@Edge**: リアルタイム処理
2. **Progressive Web Apps**: オフライン機能
3. **AMP対応**: モバイル最適化
4. **多言語対応**: 国際化実装

### 実践プロジェクトのアイデア
1. **ポートフォリオサイト**: 個人・企業サイト構築
2. **ランディングページ**: マーケティングサイト
3. **ドキュメントサイト**: 技術文書・API仕様
4. **ブログプラットフォーム**: 静的サイトジェネレーター活用