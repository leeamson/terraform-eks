#!/bin/bash

# =============================================================================
# Script: create-terraform-eks-project.sh
# Description: Creates complete Terraform EKS project with GitHub Actions CI/CD
# Usage: ./create-terraform-eks-project.sh [project-name]
# =============================================================================

set -e

# Project name (default or from argument)
PROJECT_NAME="${1:-terraform-eks-project}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Terraform EKS Project Generator with GitHub Actions       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Project Name: ${BLUE}$PROJECT_NAME${NC}"
echo ""

# =============================================================================
# CREATE DIRECTORY STRUCTURE
# =============================================================================

print_header "Creating Directory Structure"

mkdir -p "$PROJECT_NAME/.github/workflows"
mkdir -p "$PROJECT_NAME/environments/dev"
mkdir -p "$PROJECT_NAME/environments/staging"
mkdir -p "$PROJECT_NAME/environments/prod"
mkdir -p "$PROJECT_NAME/modules/vpc"
mkdir -p "$PROJECT_NAME/modules/eks"
mkdir -p "$PROJECT_NAME/modules/monitoring"
mkdir -p "$PROJECT_NAME/scripts"

print_status "Directory structure created"

# =============================================================================
# GITHUB ACTIONS WORKFLOWS
# =============================================================================

print_header "Creating GitHub Actions Workflows"

# -----------------------------------------------------------------------------
# terraform-plan.yml
# -----------------------------------------------------------------------------
cat > "$PROJECT_NAME/.github/workflows/terraform-plan.yml" << 'EOF'
# =============================================================================
# Terraform Plan Workflow
# Triggers on Pull Requests to validate and plan changes
# =============================================================================

name: 'Terraform Plan'

on:
  pull_request:
    branches:
      - main
      - develop
    paths:
      - 'environments/**'
      - 'modules/**'
      - '.github/workflows/terraform-*.yml'

env:
  TF_LOG: INFO
  AWS_REGION: eu-west-1

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  # ===========================================================================
  # Detect Changed Environments
  # ===========================================================================
  detect-changes:
    name: 'Detect Changes'
    runs-on: ubuntu-latest
    outputs:
      dev: ${{ steps.filter.outputs.dev }}
      staging: ${{ steps.filter.outputs.staging }}
      prod: ${{ steps.filter.outputs.prod }}
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Detect changed environments
        uses: dorny/paths-filter@v2
        id: filter
        with:
          filters: |
            dev:
              - 'environments/dev/**'
              - 'modules/**'
            staging:
              - 'environments/staging/**'
              - 'modules/**'
            prod:
              - 'environments/prod/**'
              - 'modules/**'

  # ===========================================================================
  # Terraform Plan - Dev
  # ===========================================================================
  plan-dev:
    name: 'Plan - Dev'
    needs: detect-changes
    if: needs.detect-changes.outputs.dev == 'true'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: environments/dev

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0
          terraform_wrapper: false

      - name: Terraform Format
        id: fmt
        run: terraform fmt -check -recursive ../../
        continue-on-error: true

      - name: Terraform Init
        id: init
        run: terraform init -input=false

      - name: Terraform Validate
        id: validate
        run: terraform validate -no-color

      - name: Terraform Plan
        id: plan
        run: |
          terraform plan -input=false -no-color -out=tfplan \
            -var="grafana_admin_password=${{ secrets.GRAFANA_ADMIN_PASSWORD }}" \
            2>&1 | tee plan_output.txt
        continue-on-error: true

      - name: Upload Plan
        uses: actions/upload-artifact@v4
        with:
          name: tfplan-dev
          path: environments/dev/tfplan
          retention-days: 5

      - name: Post Plan to PR
        uses: actions/github-script@v7
        if: github.event_name == 'pull_request'
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const fs = require('fs');
            const planOutput = fs.readFileSync('environments/dev/plan_output.txt', 'utf8');
            const maxLength = 65000;
            const truncatedPlan = planOutput.length > maxLength 
              ? planOutput.substring(0, maxLength) + '\n\n... (truncated)'
              : planOutput;
            
            const output = `## Terraform Plan - \`dev\`
            
            #### Format: \`${{ steps.fmt.outcome }}\`
            #### Init: \`${{ steps.init.outcome }}\`
            #### Validate: \`${{ steps.validate.outcome }}\`
            #### Plan: \`${{ steps.plan.outcome }}\`
            
            <details>
            <summary>Show Plan</summary>
            
            \`\`\`terraform
            ${truncatedPlan}
            \`\`\`
            
            </details>
            
            *Pushed by: @${{ github.actor }}, Action: \`${{ github.event_name }}\`*`;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });

      - name: Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1

  # ===========================================================================
  # Terraform Plan - Staging
  # ===========================================================================
  plan-staging:
    name: 'Plan - Staging'
    needs: detect-changes
    if: needs.detect-changes.outputs.staging == 'true'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: environments/staging

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0
          terraform_wrapper: false

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Validate
        run: terraform validate -no-color

      - name: Terraform Plan
        id: plan
        run: |
          terraform plan -input=false -no-color -out=tfplan \
            -var="grafana_admin_password=${{ secrets.GRAFANA_ADMIN_PASSWORD }}" \
            2>&1 | tee plan_output.txt
        continue-on-error: true

      - name: Upload Plan
        uses: actions/upload-artifact@v4
        with:
          name: tfplan-staging
          path: environments/staging/tfplan
          retention-days: 5

      - name: Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1

  # ===========================================================================
  # Terraform Plan - Prod
  # ===========================================================================
  plan-prod:
    name: 'Plan - Prod'
    needs: detect-changes
    if: needs.detect-changes.outputs.prod == 'true'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: environments/prod

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0
          terraform_wrapper: false

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Validate
        run: terraform validate -no-color

      - name: Terraform Plan
        id: plan
        run: |
          terraform plan -input=false -no-color -out=tfplan \
            -var="grafana_admin_password=${{ secrets.GRAFANA_ADMIN_PASSWORD }}" \
            2>&1 | tee plan_output.txt
        continue-on-error: true

      - name: Upload Plan
        uses: actions/upload-artifact@v4
        with:
          name: tfplan-prod
          path: environments/prod/tfplan
          retention-days: 5

      - name: Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1

  # ===========================================================================
  # Security Scan
  # ===========================================================================
  security-scan:
    name: 'Security Scan'
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.3
        with:
          soft_fail: true

      - name: Run checkov
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: .
          framework: terraform
          soft_fail: true
          output_format: cli
EOF

print_status "Created terraform-plan.yml"

# -----------------------------------------------------------------------------
# terraform-apply.yml
# -----------------------------------------------------------------------------
cat > "$PROJECT_NAME/.github/workflows/terraform-apply.yml" << 'EOF'
# =============================================================================
# Terraform Apply Workflow
# Triggers on merge to main branch or manual dispatch
# =============================================================================

name: 'Terraform Apply'

on:
  push:
    branches:
      - main
    paths:
      - 'environments/**'
      - 'modules/**'
  
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod
      action:
        description: 'Action to perform'
        required: true
        type: choice
        options:
          - plan
          - apply
        default: plan

env:
  TF_LOG: INFO
  AWS_REGION: eu-west-1

permissions:
  contents: read
  id-token: write

jobs:
  # ===========================================================================
  # Detect Changed Environments (for push events)
  # ===========================================================================
  detect-changes:
    name: 'Detect Changes'
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    outputs:
      dev: ${{ steps.filter.outputs.dev }}
      staging: ${{ steps.filter.outputs.staging }}
      prod: ${{ steps.filter.outputs.prod }}
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Detect changed environments
        uses: dorny/paths-filter@v2
        id: filter
        with:
          filters: |
            dev:
              - 'environments/dev/**'
              - 'modules/**'
            staging:
              - 'environments/staging/**'
              - 'modules/**'
            prod:
              - 'environments/prod/**'
              - 'modules/**'

  # ===========================================================================
  # Apply - Dev (Auto on push)
  # ===========================================================================
  apply-dev:
    name: 'Apply - Dev'
    needs: detect-changes
    if: github.event_name == 'push' && needs.detect-changes.outputs.dev == 'true'
    runs-on: ubuntu-latest
    environment:
      name: dev
      url: ${{ steps.get-url.outputs.url }}
    defaults:
      run:
        working-directory: environments/dev

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Apply
        run: |
          terraform apply -auto-approve -input=false \
            -var="grafana_admin_password=${{ secrets.GRAFANA_ADMIN_PASSWORD }}"

      - name: Get Outputs
        id: get-url
        run: |
          echo "url=$(terraform output -raw eks_cluster_endpoint 2>/dev/null || echo 'N/A')" >> $GITHUB_OUTPUT

  # ===========================================================================
  # Apply - Staging (Auto on push, requires approval)
  # ===========================================================================
  apply-staging:
    name: 'Apply - Staging'
    needs: [detect-changes, apply-dev]
    if: |
      always() && 
      github.event_name == 'push' && 
      needs.detect-changes.outputs.staging == 'true' &&
      (needs.apply-dev.result == 'success' || needs.apply-dev.result == 'skipped')
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: ${{ steps.get-url.outputs.url }}
    defaults:
      run:
        working-directory: environments/staging

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Apply
        run: |
          terraform apply -auto-approve -input=false \
            -var="grafana_admin_password=${{ secrets.GRAFANA_ADMIN_PASSWORD }}"

      - name: Get Outputs
        id: get-url
        run: |
          echo "url=$(terraform output -raw eks_cluster_endpoint 2>/dev/null || echo 'N/A')" >> $GITHUB_OUTPUT

  # ===========================================================================
  # Apply - Prod (Auto on push, requires approval)
  # ===========================================================================
  apply-prod:
    name: 'Apply - Prod'
    needs: [detect-changes, apply-staging]
    if: |
      always() && 
      github.event_name == 'push' && 
      needs.detect-changes.outputs.prod == 'true' &&
      (needs.apply-staging.result == 'success' || needs.apply-staging.result == 'skipped')
    runs-on: ubuntu-latest
    environment:
      name: prod
      url: ${{ steps.get-url.outputs.url }}
    defaults:
      run:
        working-directory: environments/prod

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Apply
        run: |
          terraform apply -auto-approve -input=false \
            -var="grafana_admin_password=${{ secrets.GRAFANA_ADMIN_PASSWORD }}"

      - name: Get Outputs
        id: get-url
        run: |
          echo "url=$(terraform output -raw eks_cluster_endpoint 2>/dev/null || echo 'N/A')" >> $GITHUB_OUTPUT

  # ===========================================================================
  # Manual Deployment
  # ===========================================================================
  manual-deploy:
    name: 'Manual - ${{ github.event.inputs.environment }}'
    if: github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    environment:
      name: ${{ github.event.inputs.environment }}
    defaults:
      run:
        working-directory: environments/${{ github.event.inputs.environment }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Plan
        if: github.event.inputs.action == 'plan'
        run: |
          terraform plan -input=false \
            -var="grafana_admin_password=${{ secrets.GRAFANA_ADMIN_PASSWORD }}"

      - name: Terraform Apply
        if: github.event.inputs.action == 'apply'
        run: |
          terraform apply -auto-approve -input=false \
            -var="grafana_admin_password=${{ secrets.GRAFANA_ADMIN_PASSWORD }}"

      - name: Show Outputs
        if: github.event.inputs.action == 'apply'
        run: terraform output
EOF

print_status "Created terraform-apply.yml"

# -----------------------------------------------------------------------------
# terraform-destroy.yml
# -----------------------------------------------------------------------------
cat > "$PROJECT_NAME/.github/workflows/terraform-destroy.yml" << 'EOF'
# =============================================================================
# Terraform Destroy Workflow
# Manual trigger only with required confirmation
# =============================================================================

name: 'Terraform Destroy'

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to destroy'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod
      confirm:
        description: 'Type environment name to confirm destruction'
        required: true
        type: string

env:
  TF_LOG: INFO
  AWS_REGION: eu-west-1

permissions:
  contents: read
  id-token: write

jobs:
  # ===========================================================================
  # Validation
  # ===========================================================================
  validate:
    name: 'Validate Destruction Request'
    runs-on: ubuntu-latest
    
    steps:
      - name: Validate confirmation
        run: |
          if [ "${{ github.event.inputs.confirm }}" != "${{ github.event.inputs.environment }}" ]; then
            echo "❌ Confirmation does not match environment name!"
            echo "Expected: ${{ github.event.inputs.environment }}"
            echo "Got: ${{ github.event.inputs.confirm }}"
            exit 1
          fi
          echo "✅ Confirmation validated"

  # ===========================================================================
  # Terraform Destroy
  # ===========================================================================
  terraform-destroy:
    name: 'Destroy - ${{ github.event.inputs.environment }}'
    needs: validate
    runs-on: ubuntu-latest
    environment:
      name: ${{ github.event.inputs.environment }}-destroy
    defaults:
      run:
        working-directory: environments/${{ github.event.inputs.environment }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Destroy Plan
        run: |
          terraform plan -destroy -input=false \
            -var="grafana_admin_password=${{ secrets.GRAFANA_ADMIN_PASSWORD }}"

      - name: Terraform Destroy
        run: |
          terraform destroy -auto-approve -input=false \
            -var="grafana_admin_password=${{ secrets.GRAFANA_ADMIN_PASSWORD }}"

      - name: Cleanup Complete
        run: |
          echo "✅ Environment ${{ github.event.inputs.environment }} has been destroyed"
EOF

print_status "Created terraform-destroy.yml"

# -----------------------------------------------------------------------------
# terraform-drift.yml
# -----------------------------------------------------------------------------
cat > "$PROJECT_NAME/.github/workflows/terraform-drift.yml" << 'EOF'
# =============================================================================
# Terraform Drift Detection
# Scheduled workflow to detect configuration drift
# =============================================================================

name: 'Terraform Drift Detection'

on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM UTC
  
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to check (leave empty for all)'
        required: false
        type: choice
        options:
          - ''
          - dev
          - staging
          - prod

env:
  TF_LOG: INFO
  AWS_REGION: eu-west-1

permissions:
  contents: read
  issues: write
  id-token: write

jobs:
  # ===========================================================================
  # Drift Detection - Dev
  # ===========================================================================
  drift-dev:
    name: 'Drift - Dev'
    runs-on: ubuntu-latest
    if: github.event.inputs.environment == '' || github.event.inputs.environment == 'dev'
    defaults:
      run:
        working-directory: environments/dev

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0
          terraform_wrapper: false

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Plan (Drift Detection)
        id: plan
        run: |
          set +e
          terraform plan -input=false -detailed-exitcode -no-color \
            -var="grafana_admin_password=${{ secrets.GRAFANA_ADMIN_PASSWORD }}" \
            2>&1 | tee plan_output.txt
          echo "exitcode=$?" >> $GITHUB_OUTPUT
        continue-on-error: true

      - name: Check for Drift
        id: drift
        run: |
          if [ "${{ steps.plan.outputs.exitcode }}" == "2" ]; then
            echo "drift=true" >> $GITHUB_OUTPUT
            echo "⚠️ Drift detected in dev!"
          else
            echo "drift=false" >> $GITHUB_OUTPUT
            echo "✅ No drift in dev"
          fi

      - name: Create Issue on Drift
        if: steps.drift.outputs.drift == 'true'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const planOutput = fs.readFileSync('environments/dev/plan_output.txt', 'utf8');
            
            const title = `🚨 Terraform Drift Detected - dev`;
            const body = `## Drift Detection Report
            
            **Environment:** \`dev\`
            **Detected:** ${new Date().toISOString()}
            **Workflow:** [Run #${{ github.run_number }}](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }})
            
            ### Plan Output
            
            <details>
            <summary>Show Details</summary>
            
            \`\`\`
            ${planOutput.substring(0, 60000)}
            \`\`\`
            
            </details>
            
            ### Action Required
            
            Please review the drift and either:
            1. Apply the Terraform configuration to remediate
            2. Update the Terraform code to match the current state
            3. Investigate manual changes made outside of Terraform
            `;
            
            const issues = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: 'open',
              labels: 'drift,dev'
            });
            
            if (issues.data.length === 0) {
              await github.rest.issues.create({
                owner: context.repo.owner,
                repo: context.repo.repo,
                title: title,
                body: body,
                labels: ['drift', 'dev', 'terraform']
              });
            }

  # ===========================================================================
  # Drift Detection - Staging
  # ===========================================================================
  drift-staging:
    name: 'Drift - Staging'
    runs-on: ubuntu-latest
    if: github.event.inputs.environment == '' || github.event.inputs.environment == 'staging'
    defaults:
      run:
        working-directory: environments/staging

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0
          terraform_wrapper: false

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Plan (Drift Detection)
        id: plan
        run: |
          set +e
          terraform plan -input=false -detailed-exitcode -no-color \
            -var="grafana_admin_password=${{ secrets.GRAFANA_ADMIN_PASSWORD }}" \
            2>&1 | tee plan_output.txt
          echo "exitcode=$?" >> $GITHUB_OUTPUT
        continue-on-error: true

      - name: Check for Drift
        id: drift
        run: |
          if [ "${{ steps.plan.outputs.exitcode }}" == "2" ]; then
            echo "drift=true" >> $GITHUB_OUTPUT
          else
            echo "drift=false" >> $GITHUB_OUTPUT
          fi

      - name: Create Issue on Drift
        if: steps.drift.outputs.drift == 'true'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const planOutput = fs.readFileSync('environments/staging/plan_output.txt', 'utf8');
            
            const title = `🚨 Terraform Drift Detected - staging`;
            const body = `## Drift Detection Report\n\n**Environment:** staging\n**Detected:** ${new Date().toISOString()}\n\n<details>\n<summary>Plan Output</summary>\n\n\`\`\`\n${planOutput.substring(0, 60000)}\n\`\`\`\n</details>`;
            
            const issues = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: 'open',
              labels: 'drift,staging'
            });
            
            if (issues.data.length === 0) {
              await github.rest.issues.create({
                owner: context.repo.owner,
                repo: context.repo.repo,
                title: title,
                body: body,
                labels: ['drift', 'staging', 'terraform']
              });
            }

  # ===========================================================================
  # Drift Detection - Prod
  # ===========================================================================
  drift-prod:
    name: 'Drift - Prod'
    runs-on: ubuntu-latest
    if: github.event.inputs.environment == '' || github.event.inputs.environment == 'prod'
    defaults:
      run:
        working-directory: environments/prod

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.0
          terraform_wrapper: false

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Plan (Drift Detection)
        id: plan
        run: |
          set +e
          terraform plan -input=false -detailed-exitcode -no-color \
            -var="grafana_admin_password=${{ secrets.GRAFANA_ADMIN_PASSWORD }}" \
            2>&1 | tee plan_output.txt
          echo "exitcode=$?" >> $GITHUB_OUTPUT
        continue-on-error: true

      - name: Check for Drift
        id: drift
        run: |
          if [ "${{ steps.plan.outputs.exitcode }}" == "2" ]; then
            echo "drift=true" >> $GITHUB_OUTPUT
          else
            echo "drift=false" >> $GITHUB_OUTPUT
          fi

      - name: Create Issue on Drift
        if: steps.drift.outputs.drift == 'true'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const planOutput = fs.readFileSync('environments/prod/plan_output.txt', 'utf8');
            
            const title = `🚨 Terraform Drift Detected - prod`;
            const body = `## Drift Detection Report\n\n**Environment:** prod\n**Detected:** ${new Date().toISOString()}\n\n<details>\n<summary>Plan Output</summary>\n\n\`\`\`\n${planOutput.substring(0, 60000)}\n\`\`\`\n</details>`;
            
            const issues = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: 'open',
              labels: 'drift,prod'
            });
            
            if (issues.data.length === 0) {
              await github.rest.issues.create({
                owner: context.repo.owner,
                repo: context.repo.repo,
                title: title,
                body: body,
                labels: ['drift', 'prod', 'terraform']
              });
            }
EOF

print_status "Created terraform-drift.yml"

# =============================================================================
# ENVIRONMENT FILES - Function to create environment
# =============================================================================

create_environment() {
    local ENV_NAME=$1
    local ENV_PATH="$PROJECT_NAME/environments/$ENV_NAME"
    
    print_info "Creating $ENV_NAME environment..."

    # -------------------------------------------------------------------------
    # main.tf
    # -------------------------------------------------------------------------
    cat > "$ENV_PATH/main.tf" << EOF
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

#──────────────────────────────────────────────────────────────────────────────
# PROVIDERS
#──────────────────────────────────────────────────────────────────────────────

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

#──────────────────────────────────────────────────────────────────────────────
# DATA SOURCES - EXISTING VPC
#──────────────────────────────────────────────────────────────────────────────

data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  id    = var.existing_vpc_id
}

locals {
  vpc_id     = var.use_existing_vpc ? data.aws_vpc.existing[0].id : module.vpc[0].vpc_id
  subnet_ids = var.use_existing_vpc ? var.existing_subnet_ids : module.vpc[0].subnet_ids
}

#──────────────────────────────────────────────────────────────────────────────
# VPC MODULE
#──────────────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"
  count  = var.use_existing_vpc ? 0 : 1

  vpc_name           = var.vpc_name
  vpc_cidr           = var.vpc_cidr
  subnet_cidrs       = var.subnet_cidrs
  availability_zones = var.availability_zones
}

#──────────────────────────────────────────────────────────────────────────────
# EKS MODULE
#──────────────────────────────────────────────────────────────────────────────

module "eks" {
  source = "../../modules/eks"

  cluster_name             = var.cluster_name
  cluster_version          = var.cluster_version
  vpc_id                   = local.vpc_id
  subnet_ids               = local.subnet_ids
  control_plane_subnet_ids = local.subnet_ids
  eks_managed_node_groups  = var.eks_managed_node_groups

  create_kms_key              = var.create_kms_key
  create_cloudwatch_log_group = var.create_cloudwatch_log_group
}

#──────────────────────────────────────────────────────────────────────────────
# MONITORING MODULE
#──────────────────────────────────────────────────────────────────────────────

module "monitoring" {
  source = "../../modules/monitoring"
  count  = var.enable_monitoring ? 1 : 0

  depends_on = [module.eks]

  namespace              = var.monitoring_namespace
  environment            = var.environment
  release_name           = var.monitoring_release_name
  chart_version          = var.monitoring_chart_version
  grafana_admin_password = var.grafana_admin_password
  grafana_service_type   = var.grafana_service_type
}
EOF

    # -------------------------------------------------------------------------
    # variables.tf
    # -------------------------------------------------------------------------
    cat > "$ENV_PATH/variables.tf" << 'EOF'
#──────────────────────────────────────────────────────────────────────────────
# GENERAL
#──────────────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

#──────────────────────────────────────────────────────────────────────────────
# VPC
#──────────────────────────────────────────────────────────────────────────────

variable "use_existing_vpc" {
  description = "Use existing VPC"
  type        = bool
  default     = false
}

variable "existing_vpc_id" {
  description = "Existing VPC ID"
  type        = string
  default     = ""
}

variable "existing_subnet_ids" {
  description = "Existing subnet IDs"
  type        = list(string)
  default     = []
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "main-vpc"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "Subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

#──────────────────────────────────────────────────────────────────────────────
# EKS
#──────────────────────────────────────────────────────────────────────────────

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "eks_managed_node_groups" {
  description = "EKS managed node groups"
  type        = any
}

variable "create_kms_key" {
  description = "Create KMS key"
  type        = bool
  default     = false
}

variable "create_cloudwatch_log_group" {
  description = "Create CloudWatch log group"
  type        = bool
  default     = false
}

#──────────────────────────────────────────────────────────────────────────────
# MONITORING
#──────────────────────────────────────────────────────────────────────────────

variable "enable_monitoring" {
  description = "Enable monitoring stack"
  type        = bool
  default     = false
}

variable "monitoring_namespace" {
  description = "Monitoring namespace"
  type        = string
  default     = "monitoring"
}

variable "monitoring_release_name" {
  description = "Monitoring release name"
  type        = string
  default     = "kube-prometheus-stack"
}

variable "monitoring_chart_version" {
  description = "Monitoring chart version"
  type        = string
  default     = "58.2.1"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "grafana_service_type" {
  description = "Grafana service type"
  type        = string
  default     = "ClusterIP"
}
EOF

    # -------------------------------------------------------------------------
    # outputs.tf
    # -------------------------------------------------------------------------
    cat > "$ENV_PATH/outputs.tf" << 'EOF'
#──────────────────────────────────────────────────────────────────────────────
# VPC OUTPUTS
#──────────────────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs"
  value       = local.subnet_ids
}

#──────────────────────────────────────────────────────────────────────────────
# EKS OUTPUTS
#──────────────────────────────────────────────────────────────────────────────

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_certificate_authority_data" {
  description = "EKS cluster CA data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "configure_kubectl" {
  description = "Configure kubectl command"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

#──────────────────────────────────────────────────────────────────────────────
# MONITORING OUTPUTS
#──────────────────────────────────────────────────────────────────────────────

output "monitoring_enabled" {
  description = "Monitoring enabled"
  value       = var.enable_monitoring
}

output "grafana_port_forward" {
  description = "Grafana port forward command"
  value       = var.enable_monitoring ? module.monitoring[0].grafana_port_forward_command : "Monitoring not enabled"
}
EOF

    # -------------------------------------------------------------------------
    # backend.tf
    # -------------------------------------------------------------------------
    cat > "$ENV_PATH/backend.tf" << EOF
terraform {
  backend "s3" {
    bucket         = "terraform-state-ACCOUNT_ID-${ENV_NAME}"  # UPDATE THIS
    key            = "eks-cluster/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-locks-${ENV_NAME}"
  }
}
EOF

    # -------------------------------------------------------------------------
    # terraform.tfvars
    # -------------------------------------------------------------------------
    case $ENV_NAME in
        dev)
            INSTANCE_TYPE="t3.medium"
            MIN_SIZE=1
            MAX_SIZE=3
            DESIRED_SIZE=2
            ;;
        staging)
            INSTANCE_TYPE="t3.large"
            MIN_SIZE=2
            MAX_SIZE=5
            DESIRED_SIZE=3
            ;;
        prod)
            INSTANCE_TYPE="m5.xlarge"
            MIN_SIZE=3
            MAX_SIZE=10
            DESIRED_SIZE=5
            ;;
    esac

    cat > "$ENV_PATH/terraform.tfvars" << EOF
#──────────────────────────────────────────────────────────────────────────────
# General Configuration
#──────────────────────────────────────────────────────────────────────────────
aws_region   = "eu-west-1"
environment  = "${ENV_NAME}"
project_name = "eks-project"

#──────────────────────────────────────────────────────────────────────────────
# VPC Configuration
#──────────────────────────────────────────────────────────────────────────────
use_existing_vpc = true
existing_vpc_id  = "vpc-XXXXXXXXX"  # UPDATE THIS

existing_subnet_ids = [
  "subnet-XXXXXXXXX",  # UPDATE THIS
  "subnet-XXXXXXXXX",
  "subnet-XXXXXXXXX"
]

# If creating new VPC (set use_existing_vpc = false)
vpc_name           = "${ENV_NAME}-vpc"
vpc_cidr           = "10.0.0.0/16"
subnet_cidrs       = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

#──────────────────────────────────────────────────────────────────────────────
# EKS Configuration
#──────────────────────────────────────────────────────────────────────────────
cluster_name    = "eks-cluster-${ENV_NAME}"
cluster_version = "1.31"

create_kms_key              = false
create_cloudwatch_log_group = false

eks_managed_node_groups = {
  general = {
    ami_type       = "AL2023_x86_64_STANDARD"
    instance_types = ["${INSTANCE_TYPE}"]
    min_size       = ${MIN_SIZE}
    max_size       = ${MAX_SIZE}
    desired_size   = ${DESIRED_SIZE}
    
    labels = {
      Environment = "${ENV_NAME}"
    }
  }
}

#──────────────────────────────────────────────────────────────────────────────
# Monitoring Configuration
#──────────────────────────────────────────────────────────────────────────────
enable_monitoring        = false
monitoring_namespace     = "monitoring"
monitoring_release_name  = "kube-prometheus-stack"
monitoring_chart_version = "58.2.1"
grafana_service_type     = "ClusterIP"

# grafana_admin_password is passed via CI/CD secrets
EOF

    print_status "Created $ENV_NAME environment"
}

# =============================================================================
# CREATE ALL ENVIRONMENTS
# =============================================================================

print_header "Creating Environment Configurations"

create_environment "dev"
create_environment "staging"
create_environment "prod"

# =============================================================================
# MODULES
# =============================================================================

print_header "Creating Modules"

# -----------------------------------------------------------------------------
# VPC Module
# -----------------------------------------------------------------------------
print_info "Creating VPC module..."

cat > "$PROJECT_NAME/modules/vpc/main.tf" << 'EOF'
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = true

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count = length(var.subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = var.map_public_ip

  tags = {
    Name                                        = "${var.vpc_name}-subnet-${count.index + 1}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.vpc_name}"     = "shared"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.vpc_name}-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.main.id
}
EOF

cat > "$PROJECT_NAME/modules/vpc/variables.tf" << 'EOF'
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "main-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames"
  type        = bool
  default     = true
}

variable "subnet_cidrs" {
  description = "List of subnet CIDRs"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "map_public_ip" {
  description = "Map public IP on launch"
  type        = bool
  default     = true
}
EOF

cat > "$PROJECT_NAME/modules/vpc/outputs.tf" << 'EOF'
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Subnet IDs"
  value       = aws_subnet.public[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}
EOF

print_status "Created VPC module"

# -----------------------------------------------------------------------------
# EKS Module
# -----------------------------------------------------------------------------
print_info "Creating EKS module..."

cat > "$PROJECT_NAME/modules/eks/main.tf" << 'EOF'
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  # Disable KMS and CloudWatch to avoid conflicts
  create_kms_key              = var.create_kms_key
  cluster_encryption_config   = var.create_kms_key ? {} : {}
  create_cloudwatch_log_group = var.create_cloudwatch_log_group
  cluster_enabled_log_types   = var.create_cloudwatch_log_group ? ["api", "audit", "authenticator"] : []

  cluster_addons = var.cluster_addons

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  eks_managed_node_groups = var.eks_managed_node_groups

  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  tags = var.tags
}
EOF

cat > "$PROJECT_NAME/modules/eks/variables.tf" << 'EOF'
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access"
  type        = bool
  default     = true
}

variable "create_kms_key" {
  description = "Create KMS key"
  type        = bool
  default     = false
}

variable "create_cloudwatch_log_group" {
  description = "Create CloudWatch log group"
  type        = bool
  default     = false
}

variable "cluster_addons" {
  description = "Cluster addons"
  type        = map(any)
  default = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs"
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "Control plane subnet IDs"
  type        = list(string)
}

variable "eks_managed_node_groups" {
  description = "EKS managed node groups"
  type        = any
  default     = {}
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Enable cluster creator admin permissions"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
EOF

cat > "$PROJECT_NAME/modules/eks/outputs.tf" << 'EOF'
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS cluster version"
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster CA data"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "Cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}
EOF

print_status "Created EKS module"

# -----------------------------------------------------------------------------
# Monitoring Module
# -----------------------------------------------------------------------------
print_info "Creating Monitoring module..."

cat > "$PROJECT_NAME/modules/monitoring/main.tf" << 'EOF'
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      name       = var.namespace
      managed-by = "terraform"
    }
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = var.release_name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version
  namespace  = var.namespace

  depends_on = [kubernetes_namespace.monitoring]
  timeout    = var.helm_timeout

  values = [
    yamlencode({
      fullnameOverride = var.release_name

      prometheus = {
        enabled = var.prometheus_enabled
        prometheusSpec = {
          retention     = var.prometheus_retention
          resources     = var.prometheus_resources
          storageSpec = var.prometheus_storage_enabled ? {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class_name
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          } : null
        }
      }

      grafana = {
        enabled       = var.grafana_enabled
        adminUser     = var.grafana_admin_user
        adminPassword = var.grafana_admin_password
        service = {
          type = var.grafana_service_type
        }
        persistence = {
          enabled = var.grafana_persistence_enabled
          size    = var.grafana_storage_size
        }
      }

      alertmanager = {
        enabled = var.alertmanager_enabled
      }

      nodeExporter = {
        enabled = var.node_exporter_enabled
      }

      kubeStateMetrics = {
        enabled = var.kube_state_metrics_enabled
      }

      kubeControllerManager = { enabled = false }
      kubeScheduler         = { enabled = false }
      kubeEtcd              = { enabled = false }
    })
  ]
}
EOF

cat > "$PROJECT_NAME/modules/monitoring/variables.tf" << 'EOF'
variable "namespace" {
  type    = string
  default = "monitoring"
}

variable "create_namespace" {
  type    = bool
  default = true
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "release_name" {
  type    = string
  default = "kube-prometheus-stack"
}

variable "chart_version" {
  type    = string
  default = "58.2.1"
}

variable "helm_timeout" {
  type    = number
  default = 600
}

variable "storage_class_name" {
  type    = string
  default = "gp2"
}

variable "prometheus_enabled" {
  type    = bool
  default = true
}

variable "prometheus_retention" {
  type    = string
  default = "15d"
}

variable "prometheus_storage_enabled" {
  type    = bool
  default = true
}

variable "prometheus_storage_size" {
  type    = string
  default = "50Gi"
}

variable "prometheus_resources" {
  type = map(any)
  default = {
    requests = {
      cpu    = "250m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

variable "grafana_enabled" {
  type    = bool
  default = true
}

variable "grafana_admin_user" {
  type    = string
  default = "admin"
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "grafana_service_type" {
  type    = string
  default = "ClusterIP"
}

variable "grafana_persistence_enabled" {
  type    = bool
  default = true
}

variable "grafana_storage_size" {
  type    = string
  default = "10Gi"
}

variable "alertmanager_enabled" {
  type    = bool
  default = true
}

variable "node_exporter_enabled" {
  type    = bool
  default = true
}

variable "kube_state_metrics_enabled" {
  type    = bool
  default = true
}
EOF

cat > "$PROJECT_NAME/modules/monitoring/outputs.tf" << 'EOF'
output "namespace" {
  value = var.namespace
}

output "release_name" {
  value = helm_release.kube_prometheus_stack.name
}

output "grafana_port_forward_command" {
  value = "kubectl port-forward svc/${var.release_name}-grafana -n ${var.namespace} 3000:80"
}

output "prometheus_port_forward_command" {
  value = "kubectl port-forward svc/${var.release_name}-prometheus -n ${var.namespace} 9090:9090"
}

output "alertmanager_port_forward_command" {
  value = "kubectl port-forward svc/${var.release_name}-alertmanager -n ${var.namespace} 9093:9093"
}
EOF

print_status "Created Monitoring module"

# =============================================================================
# SCRIPTS
# =============================================================================

print_header "Creating Scripts"

# -----------------------------------------------------------------------------
# setup-backend.sh
# -----------------------------------------------------------------------------
cat > "$PROJECT_NAME/scripts/setup-backend.sh" << 'EOF'
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
