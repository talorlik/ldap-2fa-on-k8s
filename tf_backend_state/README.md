# Terraform Backend State Infrastructure

This directory contains Terraform configuration to provision the AWS infrastructure needed to store Terraform state files remotely. This includes an S3 bucket for state storage and a DynamoDB table for state locking.

## Overview

This infrastructure creates:

- **S3 Bucket**: Stores Terraform state files with versioning enabled
- **DynamoDB Table**: Provides state locking to prevent concurrent modifications
- **Security**: Encrypted storage, private access, and IAM-based access control

The bucket name is dynamically generated based on your prefix and AWS account ID to ensure global uniqueness.

## Prerequisites

- AWS Account with appropriate permissions
- GitHub repository with Actions enabled
- Terraform >= 1.2.0 (for local execution)
- AWS Cli V2

## GitHub Repository Configuration

Before running the workflows, you need to configure the following in your GitHub repository:

### Required Secrets

Secrets are sensitive values that are encrypted and only accessible to workflows. Configure them at:
**Repository → Settings → Secrets and variables → Actions → Secrets**

1. `AWS_ACCESS_KEY_ID`

    - **Type**: Secret
    - **Description**: Your AWS access key ID for programmatic access
    - **How to get it**:
      1. Go to AWS IAM Console → Users → Your User → Security credentials
      2. Create access key (if you don't have one)
      3. Copy the Access key ID
    - **Used for**: Authenticating AWS API calls in GitHub Actions

2. `AWS_SECRET_ACCESS_KEY`

    - **Type**: Secret
    - **Description**: Your AWS secret access key (corresponds to the access key ID above)
    - **How to get it**: Same as above, copy the Secret access key (only shown once!)
    - **Used for**: Authenticating AWS API calls in GitHub Actions
    - **⚠️ Important**: Store this securely - it's only shown once when created

3. `GH_TOKEN`

    - **Type**: Secret
    - **Description**: GitHub Personal Access Token (PAT) with `repo` scope
    - **How to create it**:
      1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
      2. Click "Generate new token (classic)"
      3. Give it a descriptive name (e.g., "Terraform Backend State")
      4. Select scope: **`repo`** (Full control of private repositories)
      5. Click "Generate token" and copy it immediately
      6. Store it as a repository secret named `GH_TOKEN`
    - **Used for**: Creating/updating the `BACKEND_BUCKET_NAME` repository variable after provisioning
    - **Why needed**: The default `GITHUB_TOKEN` may not have permissions to write repository variables

### Required Variables

Variables are non-sensitive values that can be accessed by workflows. Configure them at:
**Repository → Settings → Secrets and variables → Actions → Variables**

1. `AWS_REGION`

    - **Type**: Variable
    - **Description**: AWS region where resources will be created
    - **Example values**: `us-east-1`, `us-west-2`, `eu-west-1`
    - **Used for**: Setting the AWS region for all operations
    - **⚠️ Important**: This should match the region in your `variables.tfvars` file

2. `BACKEND_PREFIX`

    - **Type**: Variable
    - **Description**: The prefix that will be created once the state file is saved in the bucket
    - **Example values**: `/backend_state/terraform.tfstate`
    - **Used for**: Setting the bucket prefix for all operations
    - **⚠️ Important**: Pay attention to the example given; the prefix must begin with a `/`

3. `BACKEND_BUCKET_NAME` (Auto-generated)

    - **Type**: Variable
    - **Description**: The dynamically generated S3 bucket name
    - **How it's created**: Automatically set by the provisioning workflow after the bucket is created
    - **Used for**: Other workflows that need to know the bucket name (e.g., destroying workflow)
    - **⚠️ Note**: You don't need to create this manually - it's created automatically

## Terraform Variables

Configure these in `variables.tfvars` before running:

1. `env`

    - **Type**: `string`
    - **Description**: Deployment environment identifier
    - **Example**: `"prod"`, `"dev"`, `"staging"`
    - **Used for**: Tagging resources and organizing by environment

2. `region`

    - **Type**: `string`
    - **Description**: AWS region for resource deployment
    - **Example**: `"us-east-1"`, `"us-west-2"`
    - **Used for**: Specifying where AWS resources are created
    - **⚠️ Important**: Should match `AWS_REGION` GitHub variable

3. `prefix`

    - **Type**: `string`
    - **Description**: Prefix added to all resource names for identification
    - **Example**: `"mycompany-tf"`, `"project-name"`
    - **Used for**: Creating unique names for all resources
    - **⚠️ Important**: Choose a unique prefix to avoid naming conflicts

4. `principal_arn`

    - **Type**: `string`
    - **Description**: AWS IAM principal (user or role) ARN that will have access to the resources
    - **Example**: `"arn:aws:iam::123456789012:user/myuser"` or `"arn:aws:iam::123456789012:role/myrole"`
    - **Used for**: Granting access to AWS to execute all needed operations.
    - **How to find it**:
      - For IAM User: AWS Console → IAM → Users → Your User → Summary → ARN
      - For IAM Role: AWS Console → IAM → Roles → Your Role → Summary → ARN

## How to Run

### Option 1: GitHub Actions (Recommended)

This is the recommended approach as it handles state file upload automatically.

#### Provisioning (Create Infrastructure)

1. **Configure your variables**:
   - Edit `variables.tfvars` with your values
   - Commit and push the changes

2. **Run the workflow**:
   - Go to GitHub → Actions tab
   - Select "TF Backend State Provisioning" workflow
   - Click "Run workflow" → "Run workflow"
   - The workflow will:
     - Validate Terraform configuration
     - Create the S3 bucket and DynamoDB table
     - Save the bucket and table names as repository variables
     - Upload the state file to S3

#### Destroying (Remove Infrastructure)

1. **Run the destroying workflow**:
   - Go to GitHub → Actions tab
   - Select "TF Backend State Destroying" workflow
   - Click "Run workflow" → "Run workflow"
   - The workflow will:
     - Download the state file from S3
     - Destroy all resources
     - ⚠️ **Warning**: This permanently deletes the S3 bucket and DynamoDB table

### Option 2: Local Execution

For local development or testing:

0. **If previously run via GitHub Actions → Download the current state**:

   ```bash
   cd tf_backend_state
   aws s3 cp s3://<bucket_name>/<prefix> ./terraform.tfstate
   ```

1. **Initialize Terraform**:

   ```bash
   # If not done in #0
   cd tf_backend_state

   terraform init
   ```

2. **Review the plan**:

   ```bash
   terraform plan -var-file="variables.tfvars" -out terraform.tfplan
   ```

3. **Apply the configuration**:

   ```bash
   terraform apply -auto-approve terraform.tfplan
   ```

4. **Get the bucket name** (for use in other workflows):

   ```bash
   terraform output bucket_name
   ```

5. **Destroy resources** (when done):

   ```bash
   terraform plan -var-file="variables.tfvars" -destroy -out terraform.tfplan

   terraform apply -auto-approve terraform.tfplan
   ```

## What Gets Created

### S3 Bucket

- **Name**: `{prefix}-{account-id}-s3-tfstate`
- **Features**:
  - Versioning enabled (allows recovery of previous state versions)
  - Encryption at rest (AES256)
  - Private access (no public access)
  - IAM-based access control
  - Force destroy enabled (allows bucket deletion even if not empty)

### DynamoDB Table

- **Name**: `{prefix}-terraform-lock-table`
- **Features**:
  - Pay-per-request billing mode
  - Hash key: `LockID` (string)
  - IAM-based access control
  - Used for Terraform state locking

### Security Features

- **S3 Bucket Policy**: Grants access only to the specified IAM principal
- **DynamoDB Resource Policy**: Grants access only to the specified IAM principal
- **Public Access Block**: Prevents any public access to the S3 bucket
- **Encryption**: All data encrypted at rest

## State File Management

### After Provisioning

- The state file is automatically uploaded to: `s3://{bucket-name}/{prefix}`
- The bucket name is saved as `BACKEND_BUCKET_NAME` repository variable
- The table name is saved as `BACKEND_DYNAMODB_TABLE_NAME` repository variable
- Both variablea are accessible to all workflows via `${{ vars.BACKEND_BUCKET_NAME }}` and `${{ vars.BACKEND_DYNAMODB_TABLE_NAME }}` respectively.

### State File Location

- **Path in S3**: `{prefix}`
- **Versioning**: Enabled, so you can recover previous versions if needed

## Troubleshooting

### "Resource not accessible by integration" error

- **Cause**: `GH_TOKEN` doesn't have proper permissions or doesn't exist
- **Solution**: Create a PAT with `repo` scope and store it as `GH_TOKEN` secret

### "Access Denied" when accessing S3

- **Cause**: The IAM principal specified in `principal_arn` doesn't match your AWS credentials
- **Solution**: Verify your `principal_arn` matches the IAM user/role you're using

### Bucket name conflicts

- **Cause**: Another account is using the same prefix
- **Solution**: Use a more unique prefix in `variables.tfvars`

### State file not found during destroy

- **Cause**: The state file wasn't uploaded or the bucket name variable is incorrect
- **Solution**: Verify `BACKEND_BUCKET_NAME` variable exists and contains the correct bucket name

## Important Notes

1. **State File**: The state file contains sensitive information. Never commit it to version control (it's in `.gitignore`).

2. **Bucket Deletion**: The bucket has `force_destroy = true`, meaning it can be deleted even if it contains files. Use with caution.

3. **Costs**:
   - S3: Minimal cost for storage (typically < $1/month for small projects)
   - DynamoDB: Pay-per-request, very low cost for occasional Terraform operations

4. **Backup**: State file versioning is enabled, so you can recover previous versions from the S3 console if needed.

5. **Multiple Environments**: If you need multiple environments (dev, staging, prod), you can:
   - Use different prefixes in `variables.tfvars`
   - Or create separate Terraform workspaces
   - Or use separate repositories/variables for each environment
