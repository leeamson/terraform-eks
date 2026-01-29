#!/bin/bash

# =============================================================================
# Script: setup-backend.sh
# Description: Creates S3 bucket and DynamoDB table for Terraform state
# Usage: ./setup-backend.sh <environment> <region>
# =============================================================================

set -e

ENV="${1:-dev}"
REGION="${2:-eu-west-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="terraform-state-${ACCOUNT_ID}-${ENV}"
DYNAMODB_TABLE="terraform-locks-${ENV}"

echo "🚀 Setting up Terraform backend for environment: $ENV"
echo "================================================"
echo "Region: $REGION"
echo "Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo ""

# Create S3 bucket
echo "Creating S3 bucket..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Bucket already exists"
else
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration '{
            "BlockPublicAcls": true,
            "IgnorePublicAcls": true,
            "BlockPublicPolicy": true,
            "RestrictPublicBuckets": true
        }'
    
    echo "✅ S3 bucket created"
fi

# Create DynamoDB table
echo "Creating DynamoDB table..."
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" 2>/dev/null; then
    echo "DynamoDB table already exists"
else
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION"
    
    echo "Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$REGION"
    
    echo "✅ DynamoDB table created"
fi

echo ""
echo "================================================"
echo "✅ Backend setup complete!"
echo ""
echo "Add this to your backend.tf:"
echo ""
cat << EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "eks-cluster/terraform.tfstate"
    region         = "$REGION"
    encrypt        = true
    dynamodb_table = "$DYNAMODB_TABLE"
  }
}
EOF
