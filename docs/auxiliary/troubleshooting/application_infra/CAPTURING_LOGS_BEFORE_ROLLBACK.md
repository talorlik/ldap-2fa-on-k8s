# Capturing OpenLDAP Logs Before Rollback

When the OpenLDAP Helm release is installed with `atomic: true` (default), a
failed install or upgrade triggers an automatic rollback and uninstall. Pods
and their logs are removed before you can run `kubectl logs`, making it
impossible to see why slapd failed (e.g. startup probe never passed).

## Option 1: Disable Atomic for Debugging (Recommended)

Set `openldap_helm_atomic = false` so that failed releases are left in place.
You can then inspect pods and capture logs before cleaning up manually.

### Steps

1. **Set the variable** (choose one):

   - In `application_infra/variables.tfvars` (for a persistent debug deploy):

     ```hcl
     openldap_helm_atomic = false
     ```

   - Or override at apply time (one-off):

     ```bash
     cd application_infra
     terraform apply -var="openldap_helm_atomic=false" -var-file=variables.tfvars
     ```

2. **Run apply.** If the OpenLDAP release fails, Terraform will still fail, but
   the release and pods will remain in the cluster.

3. **Capture logs** using the script or manually:

   ```bash
   ./scripts/capture-openldap-logs.sh
   ```

   Or manually:

   ```bash
   kubectl get pods -n ldap
   kubectl logs -n ldap openldap-stack-ha-0 --all-containers --tail=500
   kubectl describe pod -n ldap openldap-stack-ha-0
   ```

4. **Fix the issue**, then set `openldap_helm_atomic = true` again (or remove
   the override) and re-apply. Optionally uninstall the failed release first:

   ```bash
   helm uninstall openldap -n ldap
   ```

> [!WARNING]
> Do not leave `openldap_helm_atomic = false` in production tfvars long-term.
> Re-enable atomic after debugging so that future failed upgrades roll back
> cleanly.

## Option 2: Use the Log Capture Script (When Pods Still Exist)

The script `scripts/capture-openldap-logs.sh` dumps logs and describe output
for OpenLDAP-related resources in the `ldap` namespace. Use it when:

- You deployed with `openldap_helm_atomic = false` and the release failed, or
- You want a quick snapshot of current state (pods may be crash-looping).

It writes to a timestamped directory under `./openldap-logs/` (or
`OPENLDAP_LOGS_DIR` if set). Ensure `kubectl` is configured for the correct
cluster and that you have access to the `ldap` namespace.

## Why Network Policies Are Missing After a Failed Deploy

Network policies for the OpenLDAP namespace are created by Terraform only
**after** the Helm release succeeds (`module.network_policies` depends on
`helm_release.openldap`). If the release fails and is rolled back (atomic) or
left in a failed state, the network policy module never runs. Once OpenLDAP
starts successfully, the next apply will create the policies.

## Summary

- **See logs when deploy fails**: Set `openldap_helm_atomic = false`, apply,
  then run `capture-openldap-logs.sh` or `kubectl logs`.
- **Production behavior**: Keep `openldap_helm_atomic = true` (default).
