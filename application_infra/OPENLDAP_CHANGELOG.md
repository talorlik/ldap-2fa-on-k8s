# OpenLDAP Helm Chart Changelog

All notable changes to the vendored OpenLDAP Helm chart are documented in this
file.

## [5.0.0] - 2026-02-22 — Vendored Chart for osixia/openldap

### Summary

The upstream **jp-gouin/helm-openldap** chart (v4.0.1) was vendored locally and
rewritten to work natively with the **osixia/openldap:1.5.0** container image.
The upstream chart was designed around Bitnami's OpenLDAP image, which has
different volume paths, environment variables, ports, and replication mechanisms.
Rather than layering overrides on top of the upstream chart, the entire chart was
forked into `application_infra/charts/openldap-stack-ha/` and rebuilt from
scratch for osixia compatibility.

### Motivation

The upstream chart relied on:

- **Bitnami/common** library chart for helpers, image rendering, labels, and
  ingress templates
- **Bitnami volume paths** (`/bitnami/openldap/`) that do not exist in osixia
- **Bitnami init containers** for TLS cert generation and volume permissions
- **Bitnami replication** via LDIF configmaps (`olcSyncRepl`, `olcServerID`)
- **Bitnami ports** (1389/1636) instead of standard LDAP ports (389/636)
- **Bitnami environment variables** for LDAP configuration

All of these are incompatible with osixia/openldap. Previous deployments worked
around these differences using `env:` overrides, `extraVolumeMounts`, and
`set_sensitive` Terraform blocks, creating fragile and hard-to-maintain
configuration. Vendoring the chart eliminates all of these workarounds.

### Chart Metadata

**Changed:**

- `Chart.yaml` version bumped from `4.0.1` to `5.0.0` (breaking change)
- `appVersion` set to `1.5.0` (osixia/openldap image version)
- Description updated to indicate vendored chart for osixia/openldap
- Subchart dependency `repository` fields set to `""` (local subcharts)

**Removed:**

- `bitnami/common` dependency (was `~1.x.x` from
  `https://charts.bitnami.com/bitnami`)

### Templates: `_helpers.tpl`

**Rewritten:**

- Completely rewritten from scratch; upstream file depended entirely on
  bitnami/common template functions

**Inlined from bitnami/common:**

- `openldap-stack-ha.image` — renders `registry/repository:tag` with ECR support
- `openldap-stack-ha.imagePullSecrets` — renders image pull secrets list
- `openldap-stack-ha.labels` — renders standard Kubernetes labels
- `openldap-stack-ha.tplvalues.render` — renders arbitrary values through `tpl()`

**Added:**

- `openldap-stack-ha.replicationHosts` — auto-computes
  `LDAP_REPLICATION_HOSTS` from StatefulSet ordinals and headless service DNS
  in the format `#HOSTNAME#ldap://<pod>.<headless>.<namespace>.svc.<cluster>:389`

**Removed:**

- All bitnami/common `include` calls (`common.images.image`,
  `common.images.pullSecrets`, `common.tplvalues.render`, `common.labels.standard`,
  `common.affinities.*`, `common.capabilities.ingress.apiVersion`)
- `openldap.olcSyncRepls` / `openldap.olcSyncRepls2` / `openldap.olcServerIDs`
  (Bitnami replication helpers)

---

### Templates: `statefulset.yaml`

**Changed:**

- Volume mounts rewritten for osixia paths:
  - `data` subPath → `/var/lib/ldap` (was `/bitnami/openldap/`)
  - `config` subPath → `/etc/ldap/slapd.d` (was not present)
  - `certs` subPath → `/container/service/slapd/assets/certs` (was not present)
- Container ports changed from `1389`/`1636` to `389`/`636`
- Probes use port `389` (was `1389`)
- Custom LDIF volume mounts directly to
  `/container/service/slapd/assets/config/bootstrap/ldif/custom`
  (was `/ldifs` with an `extraVolumeMounts` hack)
- `envFrom` properly references `existingSecret` as a `secretRef` when set
- `env` section includes `LDAP_DOMAIN` from `ldapDomain` value
- `LDAP_REPLICATION_HOSTS` computed via the new helper template
- Uses `openldap-stack-ha.image` helper for image rendering (ECR support)

**Removed:**

- All init containers:
  - `init-tls-secret` (Bitnami TLS cert copying from secret to volume)
  - `init-volume-permissions` (Bitnami `chmod`/`chown` on `/bitnami`)
- Bitnami replication volume mounts (`configmap-replication`)
- Custom files volume mounts (`configmap-customfiles`)
- References to `bitnami` in volume names and mount paths

### Templates: `configmap-env.yaml`

**Rewritten:**

- Completely replaced with osixia-native environment variables
- Sets `LDAP_DOMAIN`, `LDAP_ORGANISATION`, `LDAP_TLS`, `LDAP_TLS_ENFORCE`,
  `LDAP_TLS_VERIFY_CLIENT`, `LDAP_TLS_CRT_FILENAME`, `LDAP_TLS_KEY_FILENAME`,
  `LDAP_TLS_CA_CRT_FILENAME`
- Sets `LDAP_REPLICATION` and conditional `LDAP_REPLICATION_HOSTS` (via helper)
- Supports additional env vars from `.Values.env` map

**Removed:**

- All Bitnami environment variables (`BITNAMI_DEBUG`, `LDAP_PORT_NUMBER`,
  `LDAP_ALLOW_ANON_BINDING`, etc.)

### Templates: `configmap-replication.yaml`

**Removed (entire file):**

- Bitnami LDIF-based replication configmap containing `olcSyncRepl`,
  `olcServerID`, `olcMirrorMode` directives
- Replaced by osixia-native `LDAP_REPLICATION_HOSTS` env var in
  `configmap-env.yaml`

### Templates: `configmap-customldif.yaml`

**Unchanged (kept):**

- Mounts custom LDIF files for directory bootstrapping
- Mount path set to osixia bootstrap path:
  `/container/service/slapd/assets/config/bootstrap/ldif/custom`

### Templates: `secret.yaml`

**Simplified:**

- Only creates secret when `existingSecret` is empty
- Contains `LDAP_ADMIN_PASSWORD` and `LDAP_CONFIG_PASSWORD` keys
- When `existingSecret` is set (Terraform-managed secret), the chart skips
  secret creation entirely

### Templates: `secret-ltb.yaml`

**Simplified:**

- Only creates LTB-passwd secret when `existingSecret` is empty
- Contains `LDAP_ADMIN_PASSWORD` key for LTB-passwd subchart bind password
- When `existingSecret` is set, LTB-passwd reads password from the
  Terraform-managed secret via `secretKeyRef`

### Templates: `service.yaml`

**Changed:**

- Ports changed from `1389`/`1636` to `389`/`636`
- Port names: `ldap` (389) and `ldaps` (636)

### Templates: `svc-headless.yaml`

**Changed:**

- Ports changed from `1389`/`1636` to `389`/`636`
- Port names: `ldap` (389) and `ldaps` (636)

### Templates Removed

The following upstream template files were deleted as they are not needed for the
osixia-based deployment:

- `configmap-replication.yaml` — Bitnami LDIF-based replication
- `configmap-customfiles.yaml` — Bitnami custom files support (unused)
- `tests/` — upstream test templates
- `NOTES.txt` — upstream chart notes
- `pod-disruption-budget.yaml` — not required for current deployment
- `.argo-workflow.yaml` — upstream CI workflow
- `CODE_OF_CONDUCT.md` — upstream community file
- `logo.png` — upstream branding

### `values.yaml` (Parent Chart)

**Rewritten:**

- Image defaults: `osixia/openldap:1.5.0` (was `bitnami/openldap`)
- Added `ldapDomain` and `ldapOrganisation` top-level values
- Added `existingSecret` field (empty = chart creates secret; set = use
  external secret)
- TLS section uses osixia field names (`certFilename`, `keyFilename`,
  `caFilename`)
- Replication section uses osixia-native `clusterName` and syncprov settings
  (not Bitnami LDIF)
- Added `global` section to pass `ldapDomain` and `existingSecret` to subcharts
- Persistence defaults preserved (8Gi, ReadWriteOnce)
- Probes use osixia defaults (port 389)
- Added `customLdifFiles` example section (commented out)

**Removed:**

- All Bitnami-specific values (`bitnami.debug`, `image.repository:
  bitnami/openldap`, `containerPorts.ldap: 1389`, `containerPorts.ldaps: 1636`,
  `initTLSSecret`, `volumePermissions`, etc.)

### Subchart: `phpldapadmin`

**Changed:**

- `_helpers.tpl` rewritten with self-contained helpers (no bitnami/common
  dependency)
- `ingress.yaml` uses hardcoded `networking.k8s.io/v1` API version (K8s 1.35)
  instead of bitnami capability lookups
- `configmap.yaml` builds LDAP host URI from parent chart's fullname and
  `global.ldapDomain`; uses `tpl()` + Go template escaping for safe rendering
- `deployment.yaml` uses inlined image helper and simplified volume mounts

**Removed:**

- All `bitnami/common` include calls

### Subchart: `ltb-passwd`

**Changed:**

- `_helpers.tpl` rewritten with self-contained helpers (no bitnami/common
  dependency)
- `ingress.yaml` uses hardcoded `networking.k8s.io/v1` API version (K8s 1.35)
- `deployment.yaml` reads LDAP admin password from `global.existingSecret` via
  `secretKeyRef` (when set), falling back to chart-created secret
- LDAP host computed from parent chart's fullname

**Removed:**

- All `bitnami/common` include calls

### Terraform Module (`modules/openldap/main.tf`)

**Changed:**

- `helm_release.openldap.chart` now uses local path
  `${path.module}/../../charts/openldap-stack-ha` instead of remote repository
- Removed `repository` and `version` attributes from `helm_release`
- Removed all `set_sensitive` blocks (passwords now flow through
  `existingSecret` in the values template)

**Removed:**

- `var.helm_chart_repository` — no longer needed (local chart)
- `var.helm_chart_version` — no longer needed (local chart)
- `var.helm_chart_name` — no longer needed (local chart)

### Values Template (`helm/openldap-values.tpl.yaml`)

**Simplified:**

- Removed `env.LDAP_DOMAIN` override block (chart now sets `LDAP_DOMAIN` from
  `ldapDomain` value natively)
- Removed `extraVolumeMounts` hack for custom LDIF mounting (chart mounts to
  osixia bootstrap path natively)
- Removed `image.registry`/`image.repository`/`image.tag` port overrides (chart
  defaults are now correct)
- Added `global` section to pass `ldapDomain` and `existingSecret` to subcharts
- Reduced from ~144 lines to ~119 lines

### Files Removed from Repository

- `charts/openldap-stack-ha/charts/common/` — entire bitnami/common library
  chart directory
- `charts/openldap-stack-ha/templates/configmap-replication.yaml`
- `charts/openldap-stack-ha/templates/configmap-customfiles.yaml`
- `charts/openldap-stack-ha/templates/NOTES.txt`
- `charts/openldap-stack-ha/templates/tests/`
- `charts/openldap-stack-ha/templates/pod-disruption-budget.yaml`
- `charts/openldap-stack-ha/.argo-workflow.yaml`
- `charts/openldap-stack-ha/CODE_OF_CONDUCT.md`
- `charts/openldap-stack-ha/logo.png`

### Verification

After applying changes:

```bash
# Validate chart renders correctly
helm template test application_infra/charts/openldap-stack-ha \
  -f application_infra/helm/openldap-values.tpl.yaml

# Validate Terraform configuration
cd application_infra && terraform validate
```

Both commands pass without errors.
