# 1.1.2 VPCとネットワーク基礎

## 学習目標

このセクションでは、AWSの基盤となるネットワークサービスを理解し、実際に構築できるようになることを目指します。

### 習得できるスキル
- Amazon VPC（Virtual Private Cloud）の設計と構築
- サブネット、ルートテーブル、インターネットゲートウェイの設定
- セキュリティグループとネットワークACLによるセキュリティ制御
- NATゲートウェイを使用したプライベートサブネットからのインターネット接続
- VPCピアリングとVPCエンドポイントの活用

## 前提知識

### 必須の知識
- TCP/IPネットワークの基本概念（IPアドレス、サブネット、ルーティング）
- AWSコンソールの基本操作
- CloudFormationの基礎（1.1.1セクション完了）

### あると望ましい知識
- CIDR記法の理解
- OSI参照モデルの基礎知識
- 従来のオンプレミスネットワーク構成の経験

## アーキテクチャ概要

### 構築するネットワーク構成

```
┌─────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                    │
│                                                             │
│  ┌─────────────────────┐    ┌─────────────────────┐      │
│  │  Public Subnet 1a    │    │  Public Subnet 1c    │      │
│  │  (10.0.1.0/24)      │    │  (10.0.2.0/24)      │      │
│  │                     │    │                     │      │
│  │  ┌─────────────┐   │    │  ┌─────────────┐   │      │
│  │  │    Web      │   │    │  │    Web      │   │      │
│  │  │  Server     │   │    │  │  Server     │   │      │
│  │  └─────────────┘   │    │  └─────────────┘   │      │
│  └──────────┬──────────┘    └──────────┬──────────┘      │
│             │                           │                  │
│  ┌──────────┴──────────┐    ┌──────────┴──────────┐      │
│  │  Private Subnet 1a   │    │  Private Subnet 1c   │      │
│  │  (10.0.11.0/24)     │    │  (10.0.12.0/24)     │      │
│  │                     │    │                     │      │
│  │  ┌─────────────┐   │    │  ┌─────────────┐   │      │
│  │  │    App      │   │    │  │    App      │   │      │
│  │  │  Server     │   │    │  │  Server     │   │      │
│  │  └─────────────┘   │    │  └─────────────┘   │      │
│  └─────────────────────┘    └─────────────────────┘      │
│                                                             │
│        Internet Gateway              NAT Gateway            │
└─────────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **VPC**: 論理的に分離されたプライベートネットワーク空間
- **サブネット**: VPC内のIPアドレス範囲の分割
- **インターネットゲートウェイ**: VPCとインターネット間の通信を可能にする
- **NATゲートウェイ**: プライベートサブネットからのアウトバウンド通信を可能にする
- **ルートテーブル**: ネットワークトラフィックの経路を定義

## ハンズオン手順

### ステップ1: VPCの作成

1. **CloudFormationテンプレートの作成**
```bash
cd /mnt/c/dev2/practice/01-基礎インフラストラクチャー編/1.1-AWS環境セットアップ/1.1.2-VPCとネットワーク基礎/cloudformation
```

2. **基本VPCテンプレートの実装**
```yaml
# vpc-base.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Basic VPC Configuration for Learning Project'

Parameters:
  ProjectName:
    Type: String
    Default: 'AI-Learning'
    Description: 'Project name for resource naming'

Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-VPC'
```

3. **スタックのデプロイ**
```bash
aws cloudformation create-stack \
  --stack-name ai-learning-vpc \
  --template-body file://vpc-base.yaml \
  --parameters ParameterKey=ProjectName,ParameterValue=AI-Learning
```

### ステップ2: サブネットの構築

1. **パブリックサブネットの追加**
```yaml
  PublicSubnet1a:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.1.0/24
      AvailabilityZone: !Select [0, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-Public-Subnet-1a'
```

2. **プライベートサブネットの追加**
```yaml
  PrivateSubnet1a:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.11.0/24
      AvailabilityZone: !Select [0, !GetAZs '']
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-Private-Subnet-1a'
```

### ステップ3: インターネット接続の設定

1. **インターネットゲートウェイの作成**
```yaml
  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-IGW'

  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway
```

2. **NATゲートウェイの設定**
```yaml
  NATGateway1a:
    Type: AWS::EC2::NatGateway
    Properties:
      AllocationId: !GetAtt EIPForNAT1a.AllocationId
      SubnetId: !Ref PublicSubnet1a
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-NAT-GW-1a'
```

### ステップ4: セキュリティグループの設定

1. **Webサーバー用セキュリティグループ**
```yaml
  WebSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: 'Security group for web servers'
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-Web-SG'
```

## 検証方法

### 1. VPCの確認
```bash
# VPCの一覧表示
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=AI-Learning-VPC"

# サブネットの確認
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxxxx"
```

### 2. 接続性テスト
```bash
# EC2インスタンスを起動してテスト
aws ec2 run-instances \
  --image-id ami-xxxxxx \
  --instance-type t3.micro \
  --subnet-id subnet-xxxxxx \
  --security-group-ids sg-xxxxxx
```

### 3. ルーティングの確認
- パブリックサブネットからインターネットへの接続
- プライベートサブネットからNAT経由での接続
- サブネット間の通信

## トラブルシューティング

### よくある問題と解決策

#### 1. インターネットに接続できない
**症状**: パブリックサブネットのEC2インスタンスがインターネットに接続できない
**原因と解決策**:
- ルートテーブルの確認: 0.0.0.0/0 → IGWのルートが存在するか
- セキュリティグループ: アウトバウンドルールが適切に設定されているか
- NACLs: デフォルトで全て許可されているか

#### 2. プライベートサブネットからの接続失敗
**症状**: プライベートサブネットのインスタンスがインターネットに接続できない
**原因と解決策**:
- NATゲートウェイのステータス確認
- ルートテーブル: 0.0.0.0/0 → NAT GWのルートが存在するか
- NATゲートウェイのElastic IP確認

#### 3. サブネット間の通信不可
**症状**: 異なるサブネット間でpingが通らない
**原因と解決策**:
- セキュリティグループでICMPが許可されているか
- ルートテーブルでローカルルートが存在するか

### デバッグコマンド
```bash
# VPC Flow Logsの有効化
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-xxxxxx \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/flowlogs
```

## 学習リソース

### AWS公式ドキュメント
- [Amazon VPC ユーザーガイド](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [VPC のセキュリティのベストプラクティス](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [VPC の料金](https://aws.amazon.com/vpc/pricing/)

### 追加学習教材
- AWS Skill Builder: "Amazon VPC Basics"
- YouTube: AWS公式チャンネル "VPC Fundamentals"
- Hands-on Lab: "Build Your First Amazon VPC"

### 関連するAWS認定試験の出題範囲
- AWS Certified Solutions Architect - Associate
- AWS Certified SysOps Administrator - Associate

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **最小権限の原則**: 必要最小限のポートのみを開放
2. **多層防御**: セキュリティグループとNACLsの併用
3. **プライベートサブネットの活用**: データベースやアプリケーションサーバーは非公開に
4. **VPC Flow Logsの有効化**: 監査とトラブルシューティングのため

### コスト最適化
1. **NATゲートウェイ**: 時間課金のため、不要時は削除を検討
2. **Elastic IP**: 未使用のEIPは課金対象
3. **データ転送料**: リージョン間、AZ間の転送に注意
4. **VPCエンドポイント**: S3やDynamoDBへの通信コスト削減

### AWS Well-Architectedフレームワークとの関連
- **信頼性の柱**: Multi-AZ構成による高可用性
- **セキュリティの柱**: ネットワーク分離とアクセス制御
- **パフォーマンス効率の柱**: 適切なネットワーク設計
- **コスト最適化の柱**: 必要最小限のリソース使用

## 次のステップ

### 推奨される学習パス
1. **1.1.3 GitHub ActionsとAWS連携**: CI/CDパイプラインでのVPC活用
2. **1.2.1 EC2インスタンス管理**: 作成したVPC内でのコンピューティング
3. **2.3.1 RDSデータベース**: プライベートサブネットでのDB構築
4. **6.2.2 コスト最適化**: VPCリソースの最適化手法

### 発展的な学習
- Transit Gatewayを使用した大規模ネットワーク設計
- AWS PrivateLinkによるサービス間接続
- Site-to-Site VPNとDirect Connect
- IPv6対応VPCの構築

### 実践プロジェクトのアイデア
1. マルチリージョンVPC構成の設計
2. ハイブリッドクラウド環境の構築
3. コンテナ化されたアプリケーションのネットワーク設計
4. セキュアなAPI Gateway統合