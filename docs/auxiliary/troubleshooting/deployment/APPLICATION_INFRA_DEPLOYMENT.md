# Application Infrastructure Deployment Troubleshooting

This document helps you find and fix failures when deploying ArgoCD and
OpenLDAP via the Application Infra Provisioning workflow or local Terraform.

## Finding the Actual Error

1. **GitHub Actions**
   - Open the failed run of **Application Infra Provisioning**.
   - Expand the step **"Provision application infrastructure"** (or
     **"Terraform plan"** if it fails at plan).
   - The last lines of the log show which resource failed and the
     Terraform/AWS/Kubernetes error.

2. **Local Terraform**
   - Run from `application_infra`:
     `terraform apply -var-file=variables.tfvars`.
   - Read the error message at the end of the output; it names the
     resource and the cause.

3. **Partial apply**
   - If apply fails partway through, run
     `terraform plan -var-file=variables.tfvars` again to see what
     remains and whether the same error would recur.

## ArgoCD Deployment Failures

### 1. EKS Capability Not Available or Permissions

**Symptom:** Error creating `aws_eks_capability.argocd` (e.g.
`InvalidParameterException`, `AccessDenied`, or "capability not supported").

**Causes and fixes:**

- **Region/feature:** ArgoCD EKS Capability may not be available in all
  regions. Confirm support in the target region and use a supported
  region (e.g. `us-east-1`).
- **Cluster:** Ensure the EKS cluster is created by **backend_infra**
  and the same account/region is used. `cluster_name` comes from
  backend_infra state; if that state is missing or wrong, fix
  backend_infra and backend configuration.
- **IAM:** The role used by Terraform (deployment account, or State
  account assuming deployment role) needs `eks:CreateCapability`,
  `eks:DescribeCapability`, and related EKS permissions. The ArgoCD
  module creates its own IAM role; ensure the account has permission
  to create IAM roles and that EKS can assume the capability role.
- **Capability role permissions:** The ArgoCD capability role has (1) AWS
  managed policy `AmazonEKSCapabilityArgoCD`, (2) a core integrations
  inline policy (EKS, Secrets Manager, CodeConnections, KMS), and (3)
  an optional supplemental policy for ECR and CodeCommit when enabled.
  ECR is enabled from the root via `argocd_enable_ecr_access`. See
  [ArgoCD IAM Policy
  Comparison](../../reference/ARGOCD_IAM_POLICY_COMPARISON.md) for
  details.

### 2. IAM Propagation / Access Entry Timing

**Symptom:** `aws_eks_capability.argocd` is created but a later step
fails with AccessDenied (e.g. when associating the access policy or
creating Kubernetes resources).

**Cause:** The capability and its access entry are created
asynchronously. The module waits 2 minutes for IAM and 5 minutes after
creating the capability; sometimes that is not enough.

**Fixes:**

- Re-run the workflow or `terraform apply`; the second run often
  succeeds once the access entry exists.
- If it persists, increase the wait in `variables.tfvars`:
  `argocd_wait_iam_propagation_duration = "3m"` and/or
  `argocd_wait_capability_ready_duration = "8m"` (defaults 2m and 5m).

### 3. Capability Stuck in CREATING with AccessDenied in Health

**Symptom:** `aws eks describe-capability` shows `"status": "CREATING"` and
`health.issues` contains an issue with `"code": "AccessDenied"` and message
like "High error rate in attempting to reach customer cluster. Check trust
policy and/or access entry permissions."

**Cause:** The access entry for the capability IAM role exists (created by
EKS when the capability is created), but the **access policy** that grants
cluster permissions (e.g. `AmazonEKSClusterAdminPolicy`) is not associated
yet, or association failed. Without it, the capability cannot reach the
cluster and stays in CREATING.

**Fixes:**

1. **Check associated policies** (copy-paste commands in [Debug
   Commands - ArgoCD
   Debugging](../reference/DEBUG_COMMANDS.md#argocd-debugging)):

   ```bash
   aws eks list-associated-access-policies \
     --cluster-name <cluster-name> \
     --principal-arn arn:aws:iam::<account>:role/<argocd-role-name> \
     --region <region>
   ```

   If `AmazonEKSClusterAdminPolicy` (or the policy your module associates) is
   not listed, the association has not been applied.

2. **Re-run Terraform apply** so that
   `aws_eks_access_policy_association.argocd_capability_cluster_admin` runs
   (it depends on the capability and a propagation sleep). If the first apply
   failed or timed out before that resource, a second apply often succeeds.

3. **Increase wait durations** in `variables.tfvars` so the access entry and
   propagation are ready before association: e.g.
   `argocd_wait_capability_ready_duration = "8m"` and
   `argocd_wait_after_capability_propagation_duration = "1m"`, then re-apply.

**If policies are already associated** (e.g. `AmazonEKSClusterAdminPolicy` and
ArgoCD policies appear in `list-associated-access-policies`) but the capability
still shows AccessDenied in health:

- **Trust policy:** Ensure the capability IAM role has a trust policy allowing
  `capabilities.eks.amazonaws.com` to assume it (`sts:AssumeRole`,
  `sts:TagSession`). Check in IAM console or use the `aws iam get-role` command
  in [Debug Commands - ArgoCD Debugging](../reference/DEBUG_COMMANDS.md#argocd-debugging).
- **Wait and re-check:** Access and health can take a few minutes to
  propagate. Run `aws eks describe-capability` again after 5–10 minutes and
  check whether `status` becomes ACTIVE and `health.issues` clears.

### 4. Capability Already Exists (State Out of Sync)

**Symptom:** Apply fails with an error that the capability already exists, or
you cancelled the workflow after the capability was created in AWS but before
Terraform state was updated. Re-running apply tries to create the capability
again and conflicts with the existing one.

**Cause:** The capability exists in AWS but is not (or no longer) in Terraform
state, so Terraform tries to create it and AWS returns "already exists".

**Fix:** Import the existing capability into state. Run from the
**application_infra** directory (with the same backend and credentials you use
for apply). Replace cluster and capability names if yours differ. See [Debug
Commands](../reference/DEBUG_COMMANDS.md#argocd-debugging) for related AWS CLI
checks (capability status, access entry, policies).

```bash
cd application_infra

# Import ID format: cluster_name,capability_name
terraform import 'module.argocd[0].aws_eks_capability.argocd' \
  'talo-tf-us-east-1-kc-prod,talo-tf-us-east-1-argocd-prod'
```

After a successful import, run `terraform plan`; it should no longer show a
create for the capability. Then run `terraform apply` to create or update any
other resources (e.g. access policy association, ClusterRoleBinding, secret).
Releasing the Terraform state lock (if one was left by a cancelled run) may be
required before import or apply.

### 5. Assume-Role Script or Wrong Account When Querying Capability

**Symptom:** No Terraform failure, but ArgoCD outputs show empty
`argocd_server_url` or `argocd_capability_status`, or
`argocd_capability_error` contains `failed_to_assume_role` or
`describe_failed`.

**Cause:** The external data source that runs after the capability uses
`../scripts/assume-github-role.sh` to assume the deployment account
and then runs `aws eks describe-capability`. If the script is not
found, or `DEPLOYMENT_ROLE_ARN` / `EXTERNAL_ID` are missing (or wrong),
the describe call fails.

**Fixes:**

- **GitHub Actions:** Ensure repository secrets are set:
  `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN` or
  `AWS_PRODUCTION_ACCOUNT_ROLE_ARN`, and `AWS_ASSUME_EXTERNAL_ID`.
  The workflow exports these into the environment for the Terraform job.
- **Local:** Run with the same env vars the workflow would set (e.g.
  from `set-k8s-env.sh` or your own export of `DEPLOYMENT_ROLE_ARN`
  and `EXTERNAL_ID`). Ensure `scripts/assume-github-role.sh` is
  executable and that you run Terraform from the repo root or from
  `application_infra` so that `../scripts/assume-github-role.sh`
  resolves correctly.

Note: The external data source always exits 0 and returns errors in the
`error` JSON field, so Terraform apply does not fail on this. The
impact is missing server URL/status in outputs; ArgoCD itself can still
be deployed.

### 6. Kubernetes RBAC / ClusterRoleBinding

**Symptom:** Error creating
`kubernetes_manifest.argocd_application_controller_clusterrolebinding`
(or similar) with "forbidden" or "cannot list resource".

**Cause:** The Kubernetes provider is using credentials that do not have
cluster-admin (or sufficient) permissions, or the EKS access entry for
the ArgoCD capability is not ready yet.

**Fix:** Ensure the deployment account role (or the role assumed by the
Kubernetes provider) has sufficient EKS cluster access. Use the same
role/assumption as in a working backend_infra apply. If you use the
ArgoCD capability's access policy association, ensure the 5-minute (or
longer) wait has passed and retry.

## OpenLDAP Deployment Failures

### 1. Image Pull Errors (ECR / Wrong Image)

**Symptom:** Helm release `openldap` fails with `ErrImagePull` or
`ImagePullBackOff`; or Terraform fails with a Helm error about pulling
the image.

**Causes and fixes:**

- **Mirror step failed:** The workflow step **"Mirror Docker images to
  ECR"** must succeed. If it failed (e.g. Docker not available, no
  network, or ECR permissions missing), fix that step and re-run the
  workflow. OpenLDAP uses images from your ECR, not Docker Hub directly.
- **Wrong ECR URL or tag:** `ecr_registry` and `ecr_repository` come
  from **backend_infra** remote state. If backend_infra is not applied
  or state is wrong, the image value can be empty or incorrect. Ensure
  backend_infra is applied and that `application_infra`'s backend and
  workspace point at the same backend_infra state. Tags must match
  what `mirror-images-to-ecr.sh` pushes (e.g.
  `openldap_image_tag = "openldap-1.5.0"`).
- **Permissions:** The EKS node IAM role (or Pod identity) must have
  permission to pull from the ECR repository in the same account.

### 2. StorageClass or PVC

**Symptom:** OpenLDAP pods stuck in `Pending`; events show "waiting for
volume" or "no persistent volumes available".

**Cause:** OpenLDAP uses a StorageClass (e.g. `gp3-ldap`) and PVCs.
The StorageClass is created in the same Terraform run; EKS Auto Mode
may delay node/volume provisioning.

**Fixes:**

- Confirm the StorageClass exists: `kubectl get storageclass`.
- Check PVCs: `kubectl get pvc -n ldap`. If they are Pending, check
  `kubectl describe pvc -n ldap` and ensure the provisioner and node
  pool can satisfy the claim.
- If the cluster is new, allow time for the first consumer to trigger
  node creation; optionally increase the Helm release `timeout` in the
  OpenLDAP module (default 20 minutes).

### 3. Helm Timeout or Atomic Failure

**Symptom:** Terraform fails with a Helm error like "release failed" or
"timed out waiting for the condition".

**Cause:** The OpenLDAP release is installed with `atomic = true` and
`timeout = 1200` (20 minutes). If pods do not become ready in time
(e.g. slow image pull, PVC pending, or resource limits), Helm rolls back
and Terraform fails.

**Fixes:**

- Check pod status: `kubectl get pods -n ldap` and
  `kubectl describe pod -n ldap <pod>`.
- Address image pull or PVC issues as above. If the cluster is slow,
  increase `openldap_helm_timeout` in `variables.tfvars` (seconds; e.g.
  1800 for 30 minutes).
- After fixing the underlying issue, run `terraform apply` again; with
  `cleanup_on_fail = true` and `atomic = true`, the failed release is
  cleaned up and can be retried.

### 4. ALB / IngressClassParams CRD Not Ready

**Symptom:** OpenLDAP (or ALB) apply fails with an error about
IngressClassParams or "no matches for kind IngressClassParams".

**Cause:** OpenLDAP depends on the ALB module. The ALB module creates
IngressClassParams, which requires the EKS Auto Mode CRD. If the CRD is
not installed yet, the apply fails.

**Fix:** In `variables.tfvars` set `wait_for_crd = true` for initial
deployments. The ALB module then waits (e.g. 2 minutes) for the CRD
before creating IngressClassParams. After the cluster is stable, you
can set `wait_for_crd = false` to speed up later runs.

### 5. OpenLDAP Passwords Not Set

**Symptom:** Terraform fails during plan or apply with a error that
`openldap_admin_password` or `openldap_config_password` is not set or
is empty.

**Cause:** These variables must be set via environment (e.g.
`TF_VAR_openldap_admin_password`, `TF_VAR_openldap_config_password`)
or GitHub Secrets, not in `variables.tfvars`.

**Fix:** In GitHub Actions, set repository secrets
`TF_VAR_OPENLDAP_ADMIN_PASSWORD` and
`TF_VAR_OPENLDAP_CONFIG_PASSWORD`. The workflow maps them to the
lowercase `TF_VAR_*` variables. Locally, export the same env vars or use
a `.env` file that is loaded before Terraform.

### 6. OpenLDAP Container Crash-Loop (Back-off restarting)

**Symptom:** Events show "Back-off restarting failed container
openldap-stack-ha" for pod `openldap-stack-ha-0` (or other replicas).
phpldapadmin/ltb-passwd may show "Readiness probe failed: connection
refused" because LDAP is not up.

**Cause:** The osixia/openldap container (slapd) is exiting. The real
reason is in the container logs.

**Fixes:**

1. **Get the actual error:**
   - `kubectl logs -n ldap openldap-stack-ha-0 -c openldap-stack-ha
     --previous` (logs from the last failed run)
   - `kubectl describe pod -n ldap openldap-stack-ha-0` (state, events,
     restarts)
   - Look for slapd errors, permission denied on `/var/lib/ldap` or
     `/etc/ldap/slapd.d`, or replication/bootstrap failures.

2. **Common causes:**
   - **Volume permissions:** The EBS volume may have been created with
     wrong ownership. The osixia image runs as a non-root user; the
     data/config/certs subPaths must be writable. If you see "Permission
     denied" on data or config dirs, consider an init container to fix
     ownership or use a securityContext that matches the image user.
   - **Secret keys:** The secret must provide `LDAP_ADMIN_PASSWORD` and
     `LDAP_CONFIG_PASSWORD`. Confirm with `kubectl get secret -n ldap
     openldap-secret -o jsonpath='{.data}' | jq 'keys'`.
   - **Replication bootstrap:** With multiple replicas, pod-0 starts
     first; if logs show replication/sync errors, set
     `openldap_replica_count = 1` in `variables.tfvars` to validate a
     single node, then change to 3 and re-apply.

3. **After fixing:** Delete the pod so it is recreated with the same
   PVC, or fix the Helm values and run `terraform apply` / Helm upgrade
   again.

### 7. Karpenter Node Churn / "no nodes available"

**Symptom:** Events show "no nodes available to schedule pods" then
later "Successfully assigned" to a node; then that node is "Disrupting
Node: Empty" or "Instance is terminating". OpenLDAP (or other) pods are
evicted and cannot schedule if no other node exists.

**Cause:** Karpenter is consolidating nodes (replacing with fewer or
cheaper nodes). It may empty a node and terminate it while OpenLDAP is
still starting or unhealthy, leaving the workload with no node to run on.

**Fixes:**

1. **Stabilize OpenLDAP first:** Fix the OpenLDAP container crash (see
   section 6) so pods become Ready. Unhealthy or not-ready pods can make
   consolidation decisions worse.

2. **PodDisruptionBudget (PDB):** The OpenLDAP chart ships a PDB
   (`minAvailable: 1`) so voluntary disruptions (e.g. Karpenter
   consolidation) keep at least one OpenLDAP pod available. No extra
   step needed unless you customize the chart.

3. **Karpenter consolidation:** To reduce churn during rollout, you can
   temporarily relax or disable consolidation in the Karpenter
   NodePool (or default NodeClass), or set a longer
   `consolidationPolicy` delay so nodes are not emptied while pods are
   still starting.

4. **Re-run after node is back:** If the only node was terminated and
   pods are Pending, Karpenter will usually provision a new node when
   it sees unschedulable pods. Re-check `kubectl get pods -n ldap` and
   events after a minute; if a new node appears and pods schedule, fix
   the OpenLDAP crash; the chart's PDB will help avoid repeated churn.

## Tips for Smoother Deployment

- **First-time cluster:** Set `wait_for_crd = true` in `variables.tfvars`
  so the ALB module waits for the EKS Auto Mode CRD before creating
  IngressClassParams. Set to `false` after the cluster is stable to
  speed up later runs.
- **Mirror images first:** Ensure the workflow step "Mirror Docker images
  to ECR" (or local `mirror-images-to-ecr.sh`) runs and succeeds before
  Terraform apply. OpenLDAP, phpLDAPadmin, and ltb-passwd pull from ECR.
- **Helm timeout:** If the OpenLDAP release times out (e.g. on Karpenter
  with slow node provisioning), increase `openldap_helm_timeout` in
  `variables.tfvars` (seconds; default 1200). For example, set to 1800
  for 30 minutes.
- **OpenLDAP replica count:** For first deploy or small clusters, set
  `openldap_replica_count = 1` in `variables.tfvars` to reduce resource
  use and replication bootstrap issues; then change to 3 for HA.
- **Pre-deploy delay:** On first deploy you can set
  `openldap_pre_deploy_delay_seconds = 30` (or 60) so the cluster has
  time after ALB/StorageClass before the OpenLDAP Helm install. Set to
  0 after the cluster is stable.
- **ArgoCD waits:** If capability or RBAC steps fail, increase
  `argocd_wait_iam_propagation_duration` and/or
  `argocd_wait_capability_ready_duration` in `variables.tfvars` (e.g.
  "3m" and "8m").
- **OpenLDAP resources:** The chart sets requests and limits to 1Gi memory
  and 1 CPU (matching for predictable scheduling). For larger directories
  or higher load, override `resources` in the values template or use a
  Helm values override.
- **OpenLDAP startup and PDB:** The chart values extend the startup probe
  (failureThreshold 60, period 10s); the chart includes a
  PodDisruptionBudget (minAvailable: 1) to limit evictions during
  consolidation.

## Deployment Order (Summary)

Terraform applies resources in this general order:

1. **ArgoCD** (if `enable_argocd = true`): IAM role, namespace, 2m
   wait, EKS capability, 5m wait, then external data and Kubernetes
   resources (ClusterRole, ClusterRoleBinding, access policy
   association, cluster secret).
2. **StorageClass** and **ALB** (IngressClass/IngressClassParams;
   optional 2m wait if `wait_for_crd = true`).
3. **OpenLDAP**: namespace, secret, Helm release (and optional network
   policies). OpenLDAP depends on StorageClass, ALB, and (when ArgoCD
   is enabled) the ArgoCD module, so ArgoCD is always created first when
   both are enabled.
4. **Route53** and other resources that depend on OpenLDAP (e.g. ALB
   DNS).

A failure at step 1 can leave the capability or RBAC in a bad state;
re-run apply after fixing IAM/region/credentials. A failure at step 3
is often image pull or storage; fix ECR and StorageClass/PVC then
re-run.

## Quick Checks After a Failed Run

- **Backend state:** `terraform state list` (in `application_infra`)
  and confirm `module.argocd` and `module.openldap` (and their
  dependencies) are present or missing as expected.
- **ArgoCD (if enabled):** `terraform output argocd_capability_status`
  and `terraform output argocd_capability_error` to see if the
  capability is ACTIVE and whether the describe step reported an error.
- **Cluster access:** `kubectl get nodes` and `kubectl get ns ldap` to
  confirm the Kubernetes provider can reach the cluster and the ldap
  namespace exists.
- **Images:** In the deployment account, check ECR for the repository
  and tags used by the OpenLDAP Helm values (e.g. `openldap-1.5.0`).

If you have the exact Terraform or Helm error message from the failed
run, match it to the sections above for targeted fixes.

## Related Documentation

- [Troubleshooting Index](../INDEX.md)
- [Debug Commands](../reference/DEBUG_COMMANDS.md)
- [LDAP and Admin-Seed](../ldap_admin_seed/LDAP_ADMIN_SEED.md)
- [Cross-Account and DNS](../cross_account_dns/CROSS_ACCOUNT_AND_DNS.md)
