#!/bin/bash
set -e

# Test all CloudFormation templates deployment and destruction

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
REGION="us-east-1"
ENVIRONMENT="dev"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Log file
LOG_FILE="cloudformation-test-$(date +%Y%m%d-%H%M%S).log"

echo -e "${BLUE}Starting CloudFormation Template Testing${NC}" | tee -a $LOG_FILE
echo "Region: $REGION" | tee -a $LOG_FILE
echo "Environment: $ENVIRONMENT" | tee -a $LOG_FILE
echo "Account ID: $ACCOUNT_ID" | tee -a $LOG_FILE
echo "Log file: $LOG_FILE" | tee -a $LOG_FILE
echo "-------------------------------------------" | tee -a $LOG_FILE

# Test results
TOTAL_TEMPLATES=0
DEPLOY_SUCCESS=0
DEPLOY_FAILED=0
DESTROY_SUCCESS=0
DESTROY_FAILED=0
SKIPPED=0

# Function to test a template
test_template() {
    local template_path=$1
    local stack_name=$2
    local capabilities=$3
    local parameters=$4
    
    TOTAL_TEMPLATES=$((TOTAL_TEMPLATES + 1))
    
    echo -e "\n${YELLOW}Testing: $template_path${NC}" | tee -a $LOG_FILE
    echo "Stack Name: $stack_name" | tee -a $LOG_FILE
    
    # Validate template first
    echo "Validating template..." | tee -a $LOG_FILE
    if aws cloudformation validate-template --template-body file://$template_path --region $REGION >> $LOG_FILE 2>&1; then
        echo -e "${GREEN}✓ Template validation passed${NC}" | tee -a $LOG_FILE
    else
        echo -e "${RED}✗ Template validation failed${NC}" | tee -a $LOG_FILE
        DEPLOY_FAILED=$((DEPLOY_FAILED + 1))
        SKIPPED=$((SKIPPED + 1))
        return 1
    fi
    
    # Check for dependencies that might not exist
    if [[ $template_path == *"vpc-network"* ]] || [[ $template_path == *"password-policy"* ]] || [[ $template_path == *"claude-code-iam"* ]] || [[ $template_path == *"common-tags"* ]]; then
        echo "This is a foundational template, proceeding with deployment..." | tee -a $LOG_FILE
    elif [[ $stack_name == *"with-dependencies"* ]]; then
        echo -e "${YELLOW}⚠ Skipping template with external dependencies${NC}" | tee -a $LOG_FILE
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi
    
    # Deploy stack
    echo "Deploying stack..." | tee -a $LOG_FILE
    local deploy_cmd="aws cloudformation create-stack --stack-name $stack_name --template-body file://$template_path --region $REGION"
    
    if [ -n "$capabilities" ]; then
        deploy_cmd="$deploy_cmd --capabilities $capabilities"
    fi
    
    if [ -n "$parameters" ]; then
        deploy_cmd="$deploy_cmd --parameters $parameters"
    fi
    
    if $deploy_cmd >> $LOG_FILE 2>&1; then
        echo "Waiting for stack creation..." | tee -a $LOG_FILE
        
        # Wait for stack creation with timeout
        local wait_count=0
        local max_wait=30  # 5 minutes (30 * 10 seconds)
        
        while [ $wait_count -lt $max_wait ]; do
            local stack_status=$(aws cloudformation describe-stacks --stack-name $stack_name --region $REGION --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "UNKNOWN")
            
            case $stack_status in
                CREATE_COMPLETE)
                    echo -e "${GREEN}✓ Stack deployed successfully${NC}" | tee -a $LOG_FILE
                    DEPLOY_SUCCESS=$((DEPLOY_SUCCESS + 1))
                    break
                    ;;
                CREATE_FAILED|ROLLBACK_COMPLETE|ROLLBACK_FAILED)
                    echo -e "${RED}✗ Stack deployment failed: $stack_status${NC}" | tee -a $LOG_FILE
                    DEPLOY_FAILED=$((DEPLOY_FAILED + 1))
                    
                    # Get failure reason
                    aws cloudformation describe-stack-events --stack-name $stack_name --region $REGION --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[LogicalResourceId,ResourceStatusReason]' --output table >> $LOG_FILE 2>&1
                    
                    # Try to delete the failed stack
                    echo "Attempting to delete failed stack..." | tee -a $LOG_FILE
                    aws cloudformation delete-stack --stack-name $stack_name --region $REGION >> $LOG_FILE 2>&1
                    
                    return 1
                    ;;
                CREATE_IN_PROGRESS)
                    echo -n "." 
                    sleep 10
                    wait_count=$((wait_count + 1))
                    ;;
                *)
                    echo "Unknown status: $stack_status" | tee -a $LOG_FILE
                    sleep 10
                    wait_count=$((wait_count + 1))
                    ;;
            esac
        done
        
        if [ $wait_count -eq $max_wait ]; then
            echo -e "${RED}✗ Stack deployment timed out${NC}" | tee -a $LOG_FILE
            DEPLOY_FAILED=$((DEPLOY_FAILED + 1))
            return 1
        fi
        
        # If deployment successful, wait a bit then destroy
        echo "Waiting 30 seconds before destruction..." | tee -a $LOG_FILE
        sleep 30
        
        # Destroy stack
        echo "Destroying stack..." | tee -a $LOG_FILE
        if aws cloudformation delete-stack --stack-name $stack_name --region $REGION >> $LOG_FILE 2>&1; then
            echo "Waiting for stack deletion..." | tee -a $LOG_FILE
            
            # Wait for deletion
            wait_count=0
            while [ $wait_count -lt $max_wait ]; do
                if ! aws cloudformation describe-stacks --stack-name $stack_name --region $REGION >> $LOG_FILE 2>&1; then
                    echo -e "${GREEN}✓ Stack destroyed successfully${NC}" | tee -a $LOG_FILE
                    DESTROY_SUCCESS=$((DESTROY_SUCCESS + 1))
                    return 0
                fi
                
                echo -n "."
                sleep 10
                wait_count=$((wait_count + 1))
            done
            
            echo -e "${RED}✗ Stack destruction timed out${NC}" | tee -a $LOG_FILE
            DESTROY_FAILED=$((DESTROY_FAILED + 1))
        else
            echo -e "${RED}✗ Stack destruction failed${NC}" | tee -a $LOG_FILE
            DESTROY_FAILED=$((DESTROY_FAILED + 1))
        fi
        
    else
        echo -e "${RED}✗ Stack deployment command failed${NC}" | tee -a $LOG_FILE
        DEPLOY_FAILED=$((DEPLOY_FAILED + 1))
        
        # Check if stack exists in any state
        if aws cloudformation describe-stacks --stack-name $stack_name --region $REGION >> $LOG_FILE 2>&1; then
            echo "Attempting to delete existing stack..." | tee -a $LOG_FILE
            aws cloudformation delete-stack --stack-name $stack_name --region $REGION >> $LOG_FILE 2>&1
        fi
    fi
}

# Test Module 01 templates
echo -e "\n${BLUE}=== Testing Module 01 - 基礎インフラストラクチャー ===${NC}" | tee -a $LOG_FILE

# Common resources
test_template "shared-resources/cloudformation/templates/common-tags.yaml" \
    "test-common-tags-$ENVIRONMENT" \
    "" \
    ""

# IAM templates
test_template "01-基礎インフラストラクチャー編/1.1-AWS環境セットアップ/1.1.1-アカウント設定とIAM/cloudformation/password-policy.yaml" \
    "test-password-policy-$ENVIRONMENT" \
    "CAPABILITY_IAM" \
    ""

test_template "01-基礎インフラストラクチャー編/1.1-AWS環境セットアップ/1.1.1-アカウント設定とIAM/cloudformation/service-roles.yaml" \
    "test-service-roles-$ENVIRONMENT" \
    "CAPABILITY_NAMED_IAM" \
    ""

# VPC (independent)
test_template "01-基礎インフラストラクチャー編/1.1-AWS環境セットアップ/1.1.2-VPCとネットワーク基礎/cloudformation/vpc-network.yaml" \
    "test-vpc-network-$ENVIRONMENT" \
    "" \
    ""

# GitHub Actions IAM
test_template "01-基礎インフラストラクチャー編/1.1-AWS環境セットアップ/1.1.3-GitHub-ActionsとAWS連携/cloudformation/github-actions-iam.yaml" \
    "test-github-actions-$ENVIRONMENT" \
    "CAPABILITY_NAMED_IAM" \
    ""

# Lambda functions (independent)
test_template "01-基礎インフラストラクチャー編/1.2-コンピューティング基礎/1.2.3-Lambda関数デプロイ/cloudformation/lambda-functions.yaml" \
    "test-lambda-functions-$ENVIRONMENT" \
    "CAPABILITY_IAM" \
    "ParameterKey=VpcId,ParameterValue= ParameterKey=PrivateSubnetIds,ParameterValue="

echo -e "\n${BLUE}=== Testing Module 02 - Web三層アーキテクチャ ===${NC}" | tee -a $LOG_FILE

# Static website (independent)
test_template "02-Web三層アーキテクチャ編/2.1-プレゼンテーション層/2.1.1-静的サイトホスティング/cloudformation/static-website.yaml" \
    "test-static-website-$ENVIRONMENT" \
    "" \
    ""

# DynamoDB (independent)
test_template "02-Web三層アーキテクチャ編/2.3-データ層/2.3.2-DynamoDB/cloudformation/dynamodb-tables.yaml" \
    "test-dynamodb-$ENVIRONMENT" \
    "CAPABILITY_IAM" \
    ""

echo -e "\n${BLUE}=== Testing Module 03 - CRUDシステム ===${NC}" | tee -a $LOG_FILE

# Cognito User Pool Simple (independent)
test_template "03-CRUDシステム実装編/3.1-基本CRUD/3.1.1-ユーザー管理システム/cloudformation/cognito-user-pool-simple.yaml" \
    "test-cognito-simple-$ENVIRONMENT" \
    "" \
    ""

echo -e "\n${BLUE}=== Testing Module 07 - Claude Code ===${NC}" | tee -a $LOG_FILE

# Claude Code IAM
test_template "07-Claude-Code-Bedrock-AI駆動開発編/7.1-Claude-Code基礎/7.1.1-環境セットアップとBedrock連携/cloudformation/claude-code-iam.yaml" \
    "test-claude-code-$ENVIRONMENT" \
    "CAPABILITY_NAMED_IAM" \
    ""

# Templates with dependencies (marked for manual testing)
echo -e "\n${YELLOW}=== Templates with Dependencies (Skipped) ===${NC}" | tee -a $LOG_FILE
echo "The following templates require existing resources and should be tested manually:" | tee -a $LOG_FILE
echo "- EC2 instances (requires VPC and KeyPair)" | tee -a $LOG_FILE
echo "- ECS cluster (requires VPC and subnets)" | tee -a $LOG_FILE
echo "- RDS database (requires VPC and subnets)" | tee -a $LOG_FILE
echo "- REST API Gateway (requires VPC for Lambda)" | tee -a $LOG_FILE
echo "- GraphQL API (requires Cognito User Pool)" | tee -a $LOG_FILE
echo "- Next.js deployment (requires GitHub token)" | tee -a $LOG_FILE
echo "- File upload system (complex dependencies)" | tee -a $LOG_FILE

# Summary
echo -e "\n${BLUE}=== Test Summary ===${NC}" | tee -a $LOG_FILE
echo "Total templates tested: $TOTAL_TEMPLATES" | tee -a $LOG_FILE
echo -e "${GREEN}Deploy succeeded: $DEPLOY_SUCCESS${NC}" | tee -a $LOG_FILE
echo -e "${RED}Deploy failed: $DEPLOY_FAILED${NC}" | tee -a $LOG_FILE
echo -e "${GREEN}Destroy succeeded: $DESTROY_SUCCESS${NC}" | tee -a $LOG_FILE
echo -e "${RED}Destroy failed: $DESTROY_FAILED${NC}" | tee -a $LOG_FILE
echo -e "${YELLOW}Skipped (dependencies): $SKIPPED${NC}" | tee -a $LOG_FILE

echo -e "\nDetailed log saved to: $LOG_FILE" | tee -a $LOG_FILE

# Exit with error if any tests failed
if [ $DEPLOY_FAILED -gt 0 ] || [ $DESTROY_FAILED -gt 0 ]; then
    exit 1
fi

exit 0