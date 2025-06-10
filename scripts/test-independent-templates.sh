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
