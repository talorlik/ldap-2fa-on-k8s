# EBS Module

This module creates Kubernetes storage resources for EBS (Elastic Block Store)
volumes in the EKS cluster.

## Purpose

The EBS module provides persistent storage capabilities for Kubernetes workloads
by creating:

- A **StorageClass** that defines how EBS volumes are provisioned
- A **PersistentVolumeClaim (PVC)** that can be used by pods to request storage

## Key Features

### EKS Auto Mode Integration

- **Built-in EBS CSI Driver**: EKS Auto Mode includes its own EBS CSI driver, so
no additional installation is required
- **Automatic IAM Permissions**: EKS Auto Mode handles IAM permissions
automatically - no need to attach `AmazonEBSCSIDriverPolicy` to the EKS Node IAM
Role

### StorageClass Configuration

- **Default Storage Class**: The StorageClass is marked as the default class for
the cluster
- **Provisioner**: Uses `ebs.csi.eks.amazonaws.com` (EKS Auto Mode provisioner)
- **Reclaim Policy**: Set to `Delete` - volumes are automatically deleted when
the PVC is deleted
- **Volume Binding Mode**: `WaitForFirstConsumer` - delays volume creation until
a pod actually needs it
- **Volume Type**: `gp3` (General Purpose SSD)
- **Encryption**: Enabled by default for security

### PersistentVolumeClaim

- **Access Mode**: `ReadWriteOnce` - allows a single node to mount the volume as
read-write
- **Storage Size**: Defaults to `1Gi` (configurable via module variables)
- **Wait Until Bound**: Set to `false` to prevent Terraform from hanging - the
PVC will bind when a pod requires it

## Important Notes

- In EKS Auto Mode, even with `ReadWriteOnce`, only one pod can access the
volume at a time
- The PVC will remain in `Pending` state until a pod that uses it is created
- Storage is provisioned dynamically when needed, not at PVC creation time

## Variables

- `env`: Deployment environment (e.g., prod, dev)
- `region`: AWS region
- `prefix`: Prefix added to all resource names
- `ebs_name`: Name for the EBS StorageClass
- `ebs_claim_name`: Name for the PersistentVolumeClaim

## Usage Example

```hcl
module "ebs" {
  source         = "./modules/ebs"
  env            = var.env
  region         = var.region
  prefix         = var.prefix
  ebs_name       = var.ebs_name
  ebs_claim_name = var.ebs_claim_name

  depends_on = [module.eks]
}
```

## References

- [AWS EKS Storage Class Parameters](https://docs.aws.amazon.com/eks/latest/userguide/create-storage-class.html)
- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
