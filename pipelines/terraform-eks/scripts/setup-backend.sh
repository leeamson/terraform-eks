#!/bin/bash

set -e

ENV="${1:-dev}"
REGION="${2:-eu-west-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="terraform-state-${ACCOUNT_ID}-${ENV}"
DYNAMODB_TABLE="terraform-locks-${ENV}"

echo "🚀 Setting up Terraform backend for: $ENV"
echo "Region: $REGION"
echo "Bucket: $BUCKET_NAME"
echo "DynamoDB: $DYNAMODB_TABLE"
echo ""

# Create S3 bucket
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "✅ Bucket already exists"
else
    echo "Creating S3 bucket..."
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME
