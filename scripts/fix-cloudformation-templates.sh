#!/bin/bash
set -e

# Fix CloudFormation templates for deployment testing

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Fixing CloudFormation templates for testing...${NC}"

# Fix 1: VPC Network - Add missing parameter
echo -e "${YELLOW}Fixing VPC Network template...${NC}"
cat > "01-基礎インフラストラクチャー編/1.1-AWS環境セットアップ/1.1.2-VPCとネットワーク基礎/cloudformation/vpc-network.yaml" << 'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Description: |
  包括的なVPCネットワークインフラストラクチャのテンプレート
  
  このテンプレートは以下のリソースを作成します：
  - VPC (10.0.0.0/16)
  - パブリックサブネット x 2 (マルチAZ)
  - プライベートサブネット x 2 (マルチAZ)
  - データベースサブネット x 2 (マルチAZ)
  - インターネットゲートウェイ
  - NATゲートウェイ x 2 (高可用性)
  - ルートテーブルとアソシエーション
  - セキュリティグループ (Web、App、DB、Bastion)
  - VPCエンドポイント (S3、DynamoDB)
  - VPCフローログ
  - ネットワークACL

Parameters:
  EnvironmentName:
    Type: String
    Default: dev
    AllowedValues: [dev, staging, prod]
    Description: |
      環境名
      - dev: 開発環境（コスト最適化）
      - staging: ステージング環境
      - prod: 本番環境（高可用性）

  ProjectName:
    Type: String
    Default: vpc-network
    Description: リソース命名に使用するプロジェクト名

  VpcCidr:
    Type: String
    Default: 10.0.0.0/16
    AllowedPattern: ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$
    Description: |
      VPCのCIDRブロック
      推奨: 10.0.0.0/16 (65,536 IPアドレス)

  EnableNatGateway:
    Type: String
    Default: 'true'
    AllowedValues: ['true', 'false']
    Description: |
      NATゲートウェイの有効化
      - true: プライベートサブネットからインターネットアクセス可能
      - false: コスト削減（開発環境向け）

Conditions:
  # NATゲートウェイを作成するかどうか
  CreateNatGateway: !Equals [!Ref EnableNatGateway, 'true']
  
  # 本番環境かどうか（ログ保持期間などに影響）
  IsProduction: !Equals [!Ref EnvironmentName, 'prod']

Resources:
  # ========================================
  # VPC
  # ========================================
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCidr
      EnableDnsHostnames: true  # DNSホスト名の解決を有効化
      EnableDnsSupport: true    # DNS解決を有効化
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-vpc'
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: !Ref ProjectName

  # ========================================
  # インターネットゲートウェイ
  # ========================================
  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-igw'
        - Key: Environment
          Value: !Ref EnvironmentName

  # IGWをVPCにアタッチ
  InternetGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      InternetGatewayId: !Ref InternetGateway
      VpcId: !Ref VPC

  # ========================================
  # パブリックサブネット（インターネット接続可能）
  # ========================================
  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [0, !GetAZs '']  # 最初のAZ
      CidrBlock: !Select [0, !Cidr [!Ref VpcCidr, 6, 8]]  # 10.0.0.0/24
      MapPublicIpOnLaunch: true  # 起動時にパブリックIPを自動割り当て
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-public-subnet-1'
        - Key: Type
          Value: Public
        - Key: Environment
          Value: !Ref EnvironmentName

  PublicSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [1, !GetAZs '']  # 2番目のAZ
      CidrBlock: !Select [1, !Cidr [!Ref VpcCidr, 6, 8]]  # 10.0.1.0/24
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-public-subnet-2'
        - Key: Type
          Value: Public
        - Key: Environment
          Value: !Ref EnvironmentName

  # ========================================
  # プライベートサブネット（NATゲートウェイ経由）
  # ========================================
  PrivateSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [0, !GetAZs '']
      CidrBlock: !Select [2, !Cidr [!Ref VpcCidr, 6, 8]]  # 10.0.2.0/24
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-private-subnet-1'
        - Key: Type
          Value: Private
        - Key: Environment
          Value: !Ref EnvironmentName

  PrivateSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [1, !GetAZs '']
      CidrBlock: !Select [3, !Cidr [!Ref VpcCidr, 6, 8]]  # 10.0.3.0/24
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-private-subnet-2'
        - Key: Type
          Value: Private
        - Key: Environment
          Value: !Ref EnvironmentName

  # ========================================
  # データベースサブネット（インターネット接続なし）
  # ========================================
  DatabaseSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [0, !GetAZs '']
      CidrBlock: !Select [4, !Cidr [!Ref VpcCidr, 6, 8]]  # 10.0.4.0/24
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-database-subnet-1'
        - Key: Type
          Value: Database
        - Key: Environment
          Value: !Ref EnvironmentName

  DatabaseSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [1, !GetAZs '']
      CidrBlock: !Select [5, !Cidr [!Ref VpcCidr, 6, 8]]  # 10.0.5.0/24
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-database-subnet-2'
        - Key: Type
          Value: Database
        - Key: Environment
          Value: !Ref EnvironmentName

  # ========================================
  # NATゲートウェイ（高可用性のため2つ）
  # ========================================
  # Elastic IPアドレス（NATゲートウェイ用）
  NatGateway1EIP:
    Type: AWS::EC2::EIP
    Condition: CreateNatGateway
    DependsOn: InternetGatewayAttachment  # IGWアタッチ後に作成
    Properties:
      Domain: vpc
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-nat1-eip'

  NatGateway2EIP:
    Type: AWS::EC2::EIP
    Condition: CreateNatGateway
    DependsOn: InternetGatewayAttachment
    Properties:
      Domain: vpc
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-nat2-eip'

  # NATゲートウェイ（各AZに1つずつ）
  NatGateway1:
    Type: AWS::EC2::NatGateway
    Condition: CreateNatGateway
    Properties:
      AllocationId: !GetAtt NatGateway1EIP.AllocationId
      SubnetId: !Ref PublicSubnet1  # パブリックサブネットに配置
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-nat-gateway-1'

  NatGateway2:
    Type: AWS::EC2::NatGateway
    Condition: CreateNatGateway
    Properties:
      AllocationId: !GetAtt NatGateway2EIP.AllocationId
      SubnetId: !Ref PublicSubnet2
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-nat-gateway-2'

  # ========================================
  # ルートテーブル
  # ========================================
  # パブリックルートテーブル
  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-public-routes'
        - Key: Environment
          Value: !Ref EnvironmentName

  # インターネットへのデフォルトルート
  DefaultPublicRoute:
    Type: AWS::EC2::Route
    DependsOn: InternetGatewayAttachment
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  # パブリックサブネットをルートテーブルに関連付け
  PublicSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PublicRouteTable
      SubnetId: !Ref PublicSubnet1

  PublicSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PublicRouteTable
      SubnetId: !Ref PublicSubnet2

  # プライベートルートテーブル（AZ1）
  PrivateRouteTable1:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-private-routes-1'
        - Key: Environment
          Value: !Ref EnvironmentName

  # NATゲートウェイ経由のデフォルトルート
  DefaultPrivateRoute1:
    Type: AWS::EC2::Route
    Condition: CreateNatGateway
    Properties:
      RouteTableId: !Ref PrivateRouteTable1
      DestinationCidrBlock: 0.0.0.0/0
      NatGatewayId: !Ref NatGateway1

  PrivateSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PrivateRouteTable1
      SubnetId: !Ref PrivateSubnet1

  # プライベートルートテーブル（AZ2）
  PrivateRouteTable2:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-private-routes-2'
        - Key: Environment
          Value: !Ref EnvironmentName

  DefaultPrivateRoute2:
    Type: AWS::EC2::Route
    Condition: CreateNatGateway
    Properties:
      RouteTableId: !Ref PrivateRouteTable2
      DestinationCidrBlock: 0.0.0.0/0
      NatGatewayId: !Ref NatGateway2

  PrivateSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PrivateRouteTable2
      SubnetId: !Ref PrivateSubnet2

  # データベース用ルートテーブル（インターネット接続なし）
  DatabaseRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-database-routes'
        - Key: Environment
          Value: !Ref EnvironmentName

  DatabaseSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref DatabaseRouteTable
      SubnetId: !Ref DatabaseSubnet1

  DatabaseSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref DatabaseRouteTable
      SubnetId: !Ref DatabaseSubnet2

  # ========================================
  # セキュリティグループ
  # ========================================
  # Webサーバー用セキュリティグループ
  WebServerSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub '${ProjectName}-${EnvironmentName}-web-sg'
      GroupDescription: |
        Webサーバー用セキュリティグループ
        - HTTP (80) とHTTPS (443) を全てのIPから許可
        - SSH (22) はBastionホストからのみ許可
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
          Description: HTTP from anywhere
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
          Description: HTTPS from anywhere
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          SourceSecurityGroupId: !Ref BastionSecurityGroup
          Description: SSH from bastion
      SecurityGroupEgress:
        - IpProtocol: -1
          CidrIp: 0.0.0.0/0
          Description: All outbound traffic
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-web-sg'
        - Key: Environment
          Value: !Ref EnvironmentName

  # アプリケーションサーバー用セキュリティグループ
  ApplicationSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub '${ProjectName}-${EnvironmentName}-app-sg'
      GroupDescription: |
        アプリケーションサーバー用セキュリティグループ
        - アプリケーションポート (8080) をWebサーバーから許可
        - SSH (22) はBastionホストからのみ許可
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 8080
          ToPort: 8080
          SourceSecurityGroupId: !Ref WebServerSecurityGroup
          Description: App port from web servers
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          SourceSecurityGroupId: !Ref BastionSecurityGroup
          Description: SSH from bastion
      SecurityGroupEgress:
        - IpProtocol: -1
          CidrIp: 0.0.0.0/0
          Description: All outbound traffic
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-app-sg'
        - Key: Environment
          Value: !Ref EnvironmentName

  # データベース用セキュリティグループ
  DatabaseSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub '${ProjectName}-${EnvironmentName}-db-sg'
      GroupDescription: |
        データベースサーバー用セキュリティグループ
        - MySQL (3306) とPostgreSQL (5432) をアプリケーションサーバーから許可
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 3306
          ToPort: 3306
          SourceSecurityGroupId: !Ref ApplicationSecurityGroup
          Description: MySQL from application servers
        - IpProtocol: tcp
          FromPort: 5432
          ToPort: 5432
          SourceSecurityGroupId: !Ref ApplicationSecurityGroup
          Description: PostgreSQL from application servers
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-db-sg'
        - Key: Environment
          Value: !Ref EnvironmentName

  # Bastionホスト用セキュリティグループ
  BastionSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub '${ProjectName}-${EnvironmentName}-bastion-sg'
      GroupDescription: |
        Bastionホスト（踏み台サーバー）用セキュリティグループ
        - SSH (22) を全てのIPから許可（本番環境では制限推奨）
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0  # 本番環境では特定のIPに制限
          Description: SSH from anywhere (restrict in production)
      SecurityGroupEgress:
        - IpProtocol: -1
          CidrIp: 0.0.0.0/0
          Description: All outbound traffic
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-bastion-sg'
        - Key: Environment
          Value: !Ref EnvironmentName

  # ========================================
  # RDS用データベースサブネットグループ
  # ========================================
  DatabaseSubnetGroup:
    Type: AWS::RDS::DBSubnetGroup
    Properties:
      DBSubnetGroupName: !Sub '${ProjectName}-${EnvironmentName}-db-subnet-group'
      DBSubnetGroupDescription: |
        RDSデータベース用のサブネットグループ
        マルチAZ配置のために複数のAZにまたがるサブネットを指定
      SubnetIds:
        - !Ref DatabaseSubnet1
        - !Ref DatabaseSubnet2
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-db-subnet-group'
        - Key: Environment
          Value: !Ref EnvironmentName

  # ========================================
  # VPCエンドポイント（プライベート接続）
  # ========================================
  # S3用VPCエンドポイント（ゲートウェイ型）
  S3VPCEndpoint:
    Type: AWS::EC2::VPCEndpoint
    Properties:
      VpcId: !Ref VPC
      ServiceName: !Sub 'com.amazonaws.${AWS::Region}.s3'
      VpcEndpointType: Gateway
      RouteTableIds:
        - !Ref PrivateRouteTable1
        - !Ref PrivateRouteTable2
        - !Ref DatabaseRouteTable

  # DynamoDB用VPCエンドポイント（ゲートウェイ型）
  DynamoDBVPCEndpoint:
    Type: AWS::EC2::VPCEndpoint
    Properties:
      VpcId: !Ref VPC
      ServiceName: !Sub 'com.amazonaws.${AWS::Region}.dynamodb'
      VpcEndpointType: Gateway
      RouteTableIds:
        - !Ref PrivateRouteTable1
        - !Ref PrivateRouteTable2

  # ========================================
  # VPCフローログ
  # ========================================
  # フローログ用IAMロール
  VPCFlowLogsRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: vpc-flow-logs.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/VPCFlowLogsDeliveryRolePolicy

  # CloudWatchロググループ
  VPCFlowLogsLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/aws/vpc/flowlogs/${ProjectName}-${EnvironmentName}'
      RetentionInDays: !If [IsProduction, 90, 7]  # 本番: 90日、その他: 7日

  # VPCフローログ
  VPCFlowLogs:
    Type: AWS::EC2::FlowLog
    Properties:
      ResourceType: VPC
      ResourceId: !Ref VPC
      TrafficType: ALL  # すべてのトラフィックを記録
      LogDestinationType: cloud-watch-logs
      LogGroupName: !Ref VPCFlowLogsLogGroup
      DeliverLogsPermissionArn: !GetAtt VPCFlowLogsRole.Arn
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-flow-logs'
        - Key: Environment
          Value: !Ref EnvironmentName

  # ========================================
  # ネットワークACL（追加のセキュリティレイヤー）
  # ========================================
  PublicNetworkAcl:
    Type: AWS::EC2::NetworkAcl
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${EnvironmentName}-public-nacl'
        - Key: Environment
          Value: !Ref EnvironmentName

  # インバウンドルール（すべて許可）
  PublicInboundRule:
    Type: AWS::EC2::NetworkAclEntry
    Properties:
      NetworkAclId: !Ref PublicNetworkAcl
      RuleNumber: 100
      Protocol: -1  # すべてのプロトコル
      RuleAction: allow
      CidrBlock: 0.0.0.0/0

  # アウトバウンドルール（すべて許可）
  PublicOutboundRule:
    Type: AWS::EC2::NetworkAclEntry
    Properties:
      NetworkAclId: !Ref PublicNetworkAcl
      RuleNumber: 100
      Protocol: -1
      Egress: true
      RuleAction: allow
      CidrBlock: 0.0.0.0/0

  # パブリックサブネットにNACLを関連付け
  PublicSubnetNetworkAclAssociation1:
    Type: AWS::EC2::SubnetNetworkAclAssociation
    Properties:
      SubnetId: !Ref PublicSubnet1
      NetworkAclId: !Ref PublicNetworkAcl

  PublicSubnetNetworkAclAssociation2:
    Type: AWS::EC2::SubnetNetworkAclAssociation
    Properties:
      SubnetId: !Ref PublicSubnet2
      NetworkAclId: !Ref PublicNetworkAcl

# ========================================
# 出力値（他のスタックから参照可能）
# ========================================
Outputs:
  # VPC情報
  VPCId:
    Description: VPC ID
    Value: !Ref VPC
    Export:
      Name: !Sub '${AWS::StackName}-VPC-ID'

  VPCCidr:
    Description: VPC CIDR Block
    Value: !Ref VpcCidr
    Export:
      Name: !Sub '${AWS::StackName}-VPC-CIDR'

  # サブネット情報
  PublicSubnets:
    Description: List of public subnets
    Value: !Join [',', [!Ref PublicSubnet1, !Ref PublicSubnet2]]
    Export:
      Name: !Sub '${AWS::StackName}-PublicSubnets'

  PrivateSubnets:
    Description: List of private subnets
    Value: !Join [',', [!Ref PrivateSubnet1, !Ref PrivateSubnet2]]
    Export:
      Name: !Sub '${AWS::StackName}-PrivateSubnets'

  DatabaseSubnets:
    Description: List of database subnets
    Value: !Join [',', [!Ref DatabaseSubnet1, !Ref DatabaseSubnet2]]
    Export:
      Name: !Sub '${AWS::StackName}-DatabaseSubnets'

  # RDS用サブネットグループ
  DatabaseSubnetGroup:
    Description: Database subnet group
    Value: !Ref DatabaseSubnetGroup
    Export:
      Name: !Sub '${AWS::StackName}-DatabaseSubnetGroup'

  # セキュリティグループ
  WebServerSecurityGroup:
    Description: Web server security group
    Value: !Ref WebServerSecurityGroup
    Export:
      Name: !Sub '${AWS::StackName}-WebServerSG'

  ApplicationSecurityGroup:
    Description: Application security group
    Value: !Ref ApplicationSecurityGroup
    Export:
      Name: !Sub '${AWS::StackName}-ApplicationSG'

  DatabaseSecurityGroup:
    Description: Database security group
    Value: !Ref DatabaseSecurityGroup
    Export:
      Name: !Sub '${AWS::StackName}-DatabaseSG'

  BastionSecurityGroup:
    Description: Bastion security group
    Value: !Ref BastionSecurityGroup
    Export:
      Name: !Sub '${AWS::StackName}-BastionSG'

  # ゲートウェイ情報
  InternetGateway:
    Description: Internet Gateway
    Value: !Ref InternetGateway
    Export:
      Name: !Sub '${AWS::StackName}-InternetGateway'

  NatGateway1:
    Condition: CreateNatGateway
    Description: NAT Gateway 1
    Value: !Ref NatGateway1
    Export:
      Name: !Sub '${AWS::StackName}-NatGateway1'

  NatGateway2:
    Condition: CreateNatGateway
    Description: NAT Gateway 2
    Value: !Ref NatGateway2
    Export:
      Name: !Sub '${AWS::StackName}-NatGateway2'
EOF

echo -e "${GREEN}✓ VPC Network template updated with detailed comments${NC}"

# Create test script for independent templates
echo -e "${YELLOW}Creating simplified test script...${NC}"
cat > scripts/test-independent-templates.sh << 'EOF'
#!/bin/bash
set -e

# Test independent CloudFormation templates only

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ENVIRONMENT="test"
TIMESTAMP=$(date +%Y%m%d%H%M%S)

echo -e "${BLUE}Testing Independent CloudFormation Templates${NC}"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"

# Array of templates to test
declare -a TEMPLATES=(
    "shared-resources/cloudformation/templates/common-tags.yaml|test-common-tags-${TIMESTAMP}|"
    "01-基礎インフラストラクチャー編/1.1-AWS環境セットアップ/1.1.1-アカウント設定とIAM/cloudformation/password-policy.yaml|test-password-policy-${TIMESTAMP}|CAPABILITY_IAM"
    "01-基礎インフラストラクチャー編/1.1-AWS環境セットアップ/1.1.1-アカウント設定とIAM/cloudformation/service-roles.yaml|test-service-roles-${TIMESTAMP}|CAPABILITY_NAMED_IAM"
    "01-基礎インフラストラクチャー編/1.1-AWS環境セットアップ/1.1.2-VPCとネットワーク基礎/cloudformation/vpc-network.yaml|test-vpc-${TIMESTAMP}|"
    "01-基礎インフラストラクチャー編/1.1-AWS環境セットアップ/1.1.3-GitHub-ActionsとAWS連携/cloudformation/github-actions-iam.yaml|test-github-${TIMESTAMP}|CAPABILITY_NAMED_IAM"
    "02-Web三層アーキテクチャ編/2.1-プレゼンテーション層/2.1.1-静的サイトホスティング/cloudformation/static-website.yaml|test-static-${TIMESTAMP}|"
    "02-Web三層アーキテクチャ編/2.3-データ層/2.3.2-DynamoDB/cloudformation/dynamodb-tables.yaml|test-dynamodb-${TIMESTAMP}|CAPABILITY_IAM"
    "03-CRUDシステム実装編/3.1-基本CRUD/3.1.1-ユーザー管理システム/cloudformation/cognito-user-pool-simple.yaml|test-cognito-${TIMESTAMP}|"
    "07-Claude-Code-Bedrock-AI駆動開発編/7.1-Claude-Code基礎/7.1.1-環境セットアップとBedrock連携/cloudformation/claude-code-iam.yaml|test-claude-${TIMESTAMP}|CAPABILITY_NAMED_IAM"
)

# Test results
PASSED=0
FAILED=0

# Test each template
for template_info in "${TEMPLATES[@]}"; do
    IFS='|' read -r template_path stack_name capabilities <<< "$template_info"
    
    echo -e "\n${YELLOW}Testing: $template_path${NC}"
    
    # Validate template
    if aws cloudformation validate-template --template-body file://$template_path --region $REGION > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Validation passed${NC}"
        
        # Deploy stack
        deploy_cmd="aws cloudformation create-stack --stack-name $stack_name --template-body file://$template_path --region $REGION"
        
        if [ -n "$capabilities" ]; then
            deploy_cmd="$deploy_cmd --capabilities $capabilities"
        fi
        
        if $deploy_cmd > /dev/null 2>&1; then
            echo "Waiting for deployment..."
            
            # Wait for completion
            if aws cloudformation wait stack-create-complete --stack-name $stack_name --region $REGION 2>/dev/null; then
                echo -e "${GREEN}✓ Deployment successful${NC}"
                
                # Delete stack
                aws cloudformation delete-stack --stack-name $stack_name --region $REGION > /dev/null 2>&1
                echo "Deleting stack..."
                
                if aws cloudformation wait stack-delete-complete --stack-name $stack_name --region $REGION 2>/dev/null; then
                    echo -e "${GREEN}✓ Deletion successful${NC}"
                    PASSED=$((PASSED + 1))
                else
                    echo -e "${RED}✗ Deletion failed${NC}"
                    FAILED=$((FAILED + 1))
                fi
            else
                echo -e "${RED}✗ Deployment failed${NC}"
                FAILED=$((FAILED + 1))
                # Try to clean up
                aws cloudformation delete-stack --stack-name $stack_name --region $REGION > /dev/null 2>&1
            fi
        else
            echo -e "${RED}✗ Stack creation failed${NC}"
            FAILED=$((FAILED + 1))
        fi
    else
        echo -e "${RED}✗ Validation failed${NC}"
        FAILED=$((FAILED + 1))
    fi
done

# Summary
echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

exit $FAILED
EOF

chmod +x scripts/test-independent-templates.sh

echo -e "${GREEN}✓ Test script created${NC}"
echo -e "${BLUE}Templates have been updated with detailed Japanese comments!${NC}"