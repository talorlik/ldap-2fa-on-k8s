# EKS Access Entry for Your User

This guide explains how to add an access entry for your IAM principal (user or
role) to an AWS EKS cluster so you can use `kubectl` and assume cluster admin.

Replace the example cluster name, principal ARN, profile, and region with your
own values.

## Option 1: Two-Step Process (Create + Associate Policy)

### Step 1: Create the Access Entry

```bash
aws --profile prod eks create-access-entry \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --principal-arn "arn:aws:iam::944880695150:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_a8174741a11614bc" \
  --region us-east-1
```

### Step 2: Associate the Cluster Admin Policy

```bash
aws --profile prod eks associate-access-policy \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --principal-arn "arn:aws:iam::944880695150:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_a8174741a11614bc" \
  --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy" \
  --access-scope type=cluster \
  --region us-east-1
```

## Option 2: Single Command (Create with Kubernetes Groups)

You can create the access entry with Kubernetes groups that provide admin
access:

```bash
aws --profile prod eks create-access-entry \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --principal-arn "arn:aws:iam::944880695150:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_a8174741a11614bc" \
  --kubernetes-groups system:masters \
  --region us-east-1
```

## Recommendation

> [!TIP]
> Prefer **Option 1** (two-step process with access policies) because:
>
> - It is the modern AWS-recommended approach
> - Access policies are managed by AWS and stay up-to-date
> - It is more explicit and easier to audit
> - It has better integration with AWS IAM
>
> The two-step process with `AmazonEKSClusterAdminPolicy` gives you full
> cluster admin permissions from scratch.

## Verification Commands

After either approach, verify the setup:

```bash
# Check the access entry was created
aws --profile prod eks describe-access-entry \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --principal-arn "arn:aws:iam::944880695150:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_a8174741a11614bc" \
  --region us-east-1
```

```bash
# Check associated policies (for Option 1)
aws --profile prod eks list-associated-access-policies \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --principal-arn "arn:aws:iam::944880695150:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_a8174741a11614bc" \
  --region us-east-1
```

```bash
# Test kubectl access
kubectl get nodes
kubectl auth can-i "*" "*" --all-namespaces
```
