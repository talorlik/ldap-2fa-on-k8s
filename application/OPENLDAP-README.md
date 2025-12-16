# OPENLDAP

 > The `openldap-stack-ha` chart deploys an OpenLDAP multi-master cluster plus
 optional phpLDAPadmin and LTB self-service password UIs. Below is a breakdown
 of what it creates and how all the values control it.

## 1. What the chart deploys

The chart's current image targets Bitnami's OpenLDAP image and supports Bitnami
OpenLDAP 2.x.([GitHub][1])

> [!NOTE]
> I had to override it in the code because it couldn't access that image.

### 1.1 Core OpenLDAP resources

From the chart README and a static analysis of rendered manifests:([GitHub][1])

1. StatefulSet

   - Kind: `StatefulSet`
   - Name pattern: `<release-name>-openldap`
   - Default `replicaCount` is 3, using multi-master replication.
   - Holds the main OpenLDAP containers plus any configured sidecars or
   initContainers.

2. ConfigMaps

   - `release-name-openldap-env`

     - Holds environment configuration for the Bitnami OpenLDAP
     container.([Datree][2])
   - Additional ConfigMaps are used when you set:

     - `customLdifFiles` (inline LDIF definitions, rendered into a ConfigMap).
     - `customLdifCm` (points to an existing ConfigMap you created).
     - `customSchemaFiles` (extra schema definitions).([GitHub][1])

3. Secrets

   - One Secret for OpenLDAP credentials when `global.existingSecret` is not
   set.

     - Expected keys if you use your own Secret: `LDAP_ADMIN_PASSWORD` and
     `LDAP_CONFIG_ADMIN_PASSWORD`.([GitHub][1])
   - One Secret for TLS if you enable `initTLSSecret.tls_enabled` and point
   `initTLSSecret.secret` at an existing Secret that has `tls.crt`,
   `tls.key`, `ca.crt`.([GitHub][1])

4. Services
   The presence and shape of services are controlled by the `service.*` and
   `serviceReadOnly.*` values.([GitHub][1])

   - Primary Service for the RW cluster:

     - Kind: `Service`
     - Type: `ClusterIP` by default (`service.type`).
     - Ports:

       - LDAP: `global.ldapPort` (default 389) if `service.enableLdapPort =
       true`.
       - LDAPS: `global.sslLdapPort` (default 636) if `service.enableSslLdapPort
       = true`.
     - Optional fields:

       - `service.clusterIP`, `service.loadBalancerIP`,
       - `service.externalIPs`,
       - `service.loadBalancerSourceRanges`,
       - `service.ipFamilyPolicy`,
       - `service.externalTrafficPolicy`.
   - Headless Service:

     - Exists because the values mention "service and headless service" for port
     toggles.([GitHub][1])
     - Used by the StatefulSet for stable DNS identities.
   - Read-only Service:

     - Controlled by `serviceReadOnly.*` values and exists when you have
     read-only replicas.([GitHub][1])

5. PersistentVolumeClaims (conditionally)

   - Only created if `persistence.enabled = true`.([GitHub][1])
   - PVC properties:

     - `persistence.storageClass`
     - `persistence.accessMode` (default `ReadWriteOnce`)
     - `persistence.size` (default `8Gi`)
     - `persistence.existingClaim` (if you want to reuse an existing PVC).

6. PodDisruptionBudget (conditionally)

   - Only created if `pdb.enabled = true`.([GitHub][1])
   - Controlled by:

     - `pdb.minAvailable`
     - `pdb.maxUnavailable`.

7. Misc pod-level constructs
   Applied to the StatefulSet pod template when you set the corresponding
   values:([GitHub][1])

   - Affinity / anti-affinity:

     - `podAffinityPreset`
     - `podAntiAffinityPreset`
     - `nodeAffinityPreset`
     - `affinity`
     - `nodeSelector`
     - `tolerations`
   - Security:

     - `podSecurityContext`
     - `containerSecurityContext`
     - `priorityClassName`
   - Extra containers and volumes:

     - `sidecars`
     - `initContainers`
     - `extraVolumes`
     - `extraVolumeMounts`
     - `volumePermissions` init-container.
   - Probes:

     - `customReadinessProbe`
     - `customLivenessProbe`
     - `customStartupProbe`.

8. Extra objects

   - `extraDeploy` allows you to inject arbitrary Kubernetes manifests that will
   be deployed along with the chart.([GitHub][1])

### 1.2 phpLDAPadmin subchart

From the chart README and Datree analysis:([GitHub][1])

If `phpldapadmin.enabled = true` (default is true):

1. Deployment

   - Kind: `Deployment`
   - Name: `release-name-phpldapadmin`.
2. Service

   - Kind: `Service`
   - Type: usually `ClusterIP`, with a port 80 HTTP endpoint.
3. ConfigMap

   - Holds phpLDAPadmin configuration. Datree shows `kind: ConfigMap` for
   `release-name-phpldapadmin`.([Datree][2])
4. Ingress (conditionally)

   - Kind: `Ingress`
   - Created if you set `phpldapadmin.ingress.enabled = true`, with host/path
   from `phpldapadmin.ingress.hosts`, `phpldapadmin.ingress.path`
   etc.([GitHub][1])

### 1.3 LTB self-service password subchart (`ltb-passwd`)

If `ltb-passwd.enabled = true` (default true):([GitHub][1])

1. Deployment

   - Kind: `Deployment`
   - Name: `release-name-ltb-passwd`.
2. Service

   - Kind: `Service`
   - Type: `ClusterIP`, port 80 for the web UI.
3. ConfigMap

   - Holds app-level configuration (as seen in the vendored README snippet that
   includes `ldap.server`, `ldap.searchBase`, etc.).([OpenCloud Forge][3])
4. Ingress (conditionally)

   - Kind: `Ingress`
   - Created if `ltb-passwd.ingress.enabled = true`. Datree shows two Ingresses
   for ltb-passwd and phpLDAPadmin.([Datree][2])

## 2. Value space and behavior

The README lists the core values. I will walk through them by category and map
them to behavior.([GitHub][1])

### 2.1 Global section

Global values mostly affect credentials, ports and image sources.

1. `global.imageRegistry`

   - Overrides the registry used for all images (OpenLDAP and subcharts).
   - Use when you mirror images into a private registry.

2. `global.imagePullSecrets`

   - List of imagePullSecrets added to all pods.
   - Required when the registry needs authentication.

3. `global.ldapDomain`

   - Logical LDAP domain.
   - Can be:

     - Fully DN style: `dc=example,dc=org`
     - Simple domain: `example.org`
   - Used to generate the base DN and other configuration parameters.

4. `global.existingSecret`

   - Name of an existing Secret for credentials.
   - That Secret must contain:

     - `LDAP_ADMIN_PASSWORD`
     - `LDAP_CONFIG_ADMIN_PASSWORD`
   - If set, chart will not manage admin/config passwords itself.

5. `global.adminUser` / `global.adminPassword`

   - Admin user and password for the LDAP directory.
   - Passed to the Bitnami OpenLDAP container as env vars and/or referenced from
   Secret.

6. `global.configUser` / `global.configPassword`

   - Credentials for the configuration database (cn=config).
   - Used by OpenLDAP for configuration operations.

7. `global.ldapPort` / `global.sslLdapPort`

   - TCP ports used internally on the Service for LDAP and LDAPS.
   - Combined with `service.enableLdapPort` and `service.enableSslLdapPort` to
   expose them.

### 2.2 Application parameters (OpenLDAP core)

All of these apply to the OpenLDAP StatefulSet and its
configuration.([GitHub][1])

1. `replicaCount`

   - Number of multi-master replicas (pods) in the main StatefulSet.
   - Default is 3.
   - These replicas form the HA write cluster.

2. `readOnlyReplicaCount`

   - Number of read-only replicas.
   - Default 0.
   - When greater than 0, additional read-only pods are created and traffic can
   be routed to them via `serviceReadOnly.*` configuration.

3. `users`, `userPasswords`, `group`

   - Used for simple user/group bootstrap when you do not want to supply your
   own LDIF.
   - `users` and `userPasswords` are comma separated lists; the index pairing
   maps user to password.
   - `group` defines a group that the created users will belong to.
   - Cannot be used together with `customLdifFiles`.

4. `env`

   - Free-form list of key/value pairs mapped to environment variables on the
   OpenLDAP container.
   - Used to pass Bitnami-specific flags like `LDAP_SKIP_DEFAULT_TREE`, to
   control whether Bitnami creates its default demo tree, and so
   on.([GitHub][1])

5. `initTLSSecret.tls_enabled` / `initTLSSecret.secret`

   - `initTLSSecret.tls_enabled`:

     - Boolean flag enabling or disabling TLS/LDAPS using a custom certificate.
   - `initTLSSecret.secret`:

     - Name of the Secret that must contain `tls.key`, `tls.crt`, `ca.crt`.
   - When enabled, the pod init phase loads the certificate and configures
   OpenLDAP for LDAPS.

6. `initialSchema`

   - Comma separated list of schema names to seed into `LDAP_EXTRA_SCHEMAS`.
   - Default: `"cosine,inetorgperson,nis"`
   - Controls which standard schemas are loaded at bootstrap.

7. `customSchemaFiles`

   - Additional schema files to load, beyond `initialSchema`.
   - Typically represented as filename to content mapping in `values.yaml`.
   - Used to enable custom objectClasses and attributes.

8. `customLdifFiles`

   - Inline LDIF content used to bootstrap the directory tree.
   - Keys are filenames, values are LDIF contents.([HackMD][4])
   - If set, they override the default bootstrap LDIF shipped by Bitnami and the
   simple `users`/`group` bootstrap logic.

9. `customLdifCm`

   - Name of an existing ConfigMap that already contains LDIF files.
   - Mutually exclusive with `customLdifFiles`.

10. `customAcls`

    - Custom ACL configuration to replace default ACLs.
    - Used to harden or tune access rules beyond defaults.

11. Replication block

    - `replication.enabled`

      - Enables multi-master replication. Default `true`.
      - Disabling this effectively turns the cluster into a set of
      non-replicating pods with shared configuration, not a proper HA
      directory.
    - `replication.retry`

      - Retry period in seconds for replication operations, default `60`.
    - `replication.timeout`

      - Timeout in seconds for replication, default `1`.
    - `replication.starttls`

      - Mode of StartTLS for replication traffic, default `critical`.
    - `replication.tls_reqcert`

      - Overrides `tls_reqcert` parameter.
      - Default `never` and becomes more strict (for example `demand`) when TLS
      is enabled.
    - `replication.tls_cacert`

      - Overrides the path to the CA cert used by replication when TLS is
      enabled.
    - `replication.interval`

      - Interval string for replication scheduling, default `00:00:00:10`.
    - `replication.clusterName`

      - Cluster name for replication, default `"cluster.local"`.

### 2.3 phpLDAPadmin configuration

These values control the separate phpLDAPadmin deployment that provides a web
UI.([GitHub][1])

1. `phpldapadmin.enabled`

   - Boolean. Default `true`.
   - When false:

     - Deployment, Service and Ingress for phpLDAPadmin are not created.

2. `phpldapadmin.ingress`

   - Struct controlling Ingress for phpLDAPadmin:

     - `enabled`
     - `ingressClassName`
     - `annotations`
     - `hosts`
     - `path`
     - `tls`
   - Example in README:

     - Host: `phpldapadmin.local`
     - Path: `/`
     - TLS with secret `ssl-ldap-dedicated-tls`.([GitHub][1])

3. `phpldapadmin.env`

   - Map of environment variables passed into the phpLDAPadmin container.
   - Default includes:

     - `PHPLDAPADMIN_LDAP_CLIENT_TLS_REQCERT: "never"`
   - You extend this to set LDAP host, base DN, bind DN etc.
   - LDAP host must match `namespace.Appfullname` of the OpenLDAP Service
   according to the README.([GitHub][1])

### 2.4 LTB self-service password configuration (`ltb-passwd`)

Values for the password self-service UI.([GitHub][1])

1. `ltb-passwd.enabled`

   - Boolean. Default `true`.
   - Disables the Deployment, Service and Ingress when set to false.

2. `ltb-passwd.ingress`

   - Struct controlling Ingress for the self-service password UI, similar shape
   to phpLDAPadmin's ingress config:

     - `enabled`
     - `annotations`
     - `hosts`
     - `path`
     - `tls`

3. Additional subchart values (from the vendored README snippet):([OpenCloud
Forge][3])

   - `replicaCount`
   - `image.repository`, `image.tag`, `image.pullPolicy`
   - `service.type`, `service.port`
   - `ingress.enabled`, `ingress.host`, `ingress.tls`
   - `ldap.server`, `ldap.searchBase`, `ldap.bindDN`, `ldap.bindPWKey`,
   `ldap.existingSecret`
   - `env` list, for example:

     - `SECRETEKEY`
     - `LDAP_LOGIN_ATTRIBUTE`
       These values bind the web app to the OpenLDAP server and define how users
       authenticate to change their own passwords.

### 2.5 Kubernetes level parameters

These values shape how the core OpenLDAP pods and services behave on the
cluster.([GitHub][1])

1. `updateStrategy`

   - Overrides the StatefulSet `updateStrategy`.
   - Allows for `RollingUpdate` tuning or `OnDelete`.

2. `kubeVersion`

   - Explicit Kubernetes version override for Helm's capabilities logic.
   - Useful when Helm cannot detect the server version (for example in certain
   CI contexts).

3. `nameOverride`, `fullnameOverride`

   - Control how the base resource name is constructed.
   - `nameOverride` partially overrides the chart's name.
   - `fullnameOverride` fully overrides the computed release name.

4. `commonLabels`

   - Applied to all created resources in addition to default labels.
   - Useful for global selectors or ownership tags.

5. `clusterDomain`

   - Cluster DNS suffix, default `cluster.local`.
   - Used when composing hostnames for replication and for generated URLs.

6. `extraDeploy`

   - Raw YAML snippets that Helm applies along with the chart.
   - Enables you to attach extra objects (for example NetworkPolicy,
   ServiceMonitor) without forking the chart.

7. `service.*` and `serviceReadOnly.*`
   Both sets have similar keys:([GitHub][1])

   - `annotations`
   - `externalIPs`
   - `enableLdapPort`
   - `enableSslLdapPort`
   - `ldapPortNodePort`, `sslLdapPortNodePort`
   - `clusterIP`
   - `loadBalancerIP`
   - `loadBalancerSourceRanges`
   - `type`
   - `ipFamilyPolicy`
   - `externalTrafficPolicy`
     They directly control how the Services for the main and read-only LDAP
     endpoints are exposed.

8. Persistence block

   - `persistence.enabled`
   - `persistence.storageClass`
   - `persistence.existingClaim`
   - `persistence.accessMode`
   - `persistence.size`
     These define whether PVCs exist and how they are sized and bound.

9. Probes and container overrides

   - `customReadinessProbe`, `customLivenessProbe`, `customStartupProbe`

     - When set, these fully replace the default probe configs in the
     StatefulSet.
   - `command`, `args`

     - Override the container entrypoint and arguments.
   - `resources`

     - CPU/memory requests and limits for the OpenLDAP containers.
     - Datree shows that by default requests and limits are empty.([Datree][2])

10. Security and scheduling knobs

    - `podSecurityContext`
    - `containerSecurityContext`
    - `podLabels`, `podAnnotations`
    - `podAffinityPreset`, `podAntiAffinityPreset`
    - `nodeAffinityPreset`, `affinity`
    - `nodeSelector`
    - `tolerations`
    - `priorityClassName`
    - `sidecars`, `initContainers`
    - `volumePermissions`
      These do not create new resource kinds but alter how the pods inside the
      existing StatefulSet behave and where they schedule.

## 3. Net effect on a default install

If you run:

```bash
helm repo add helm-openldap https://jp-gouin.github.io/helm-openldap/
helm install my-release helm-openldap/openldap-stack-ha
```

with the default values, the chart will:([GitHub][1])

1. Create a StatefulSet with 3 OpenLDAP pods with multi-master replication.
2. Create at least one ConfigMap for OpenLDAP env configuration.
3. Create at least one Secret for credentials (unless you point to an existing
one).
4. Create internal Services for LDAP and LDAPS, plus a headless Service for the
StatefulSet.
5. Not create any PVCs, because `persistence.enabled` defaults to `false`.
6. Create a Deployment, Service, ConfigMap and (if enabled) an Ingress for
phpLDAPadmin.
7. Create a Deployment, Service, ConfigMap and (if enabled) an Ingress for
ltb-passwd.

All other values progressively refine this baseline: toggling TLS, controlling
replication, deciding whether the UIs exist, and tuning how the pods are
scheduled and exposed.

[1]: https://github.com/jp-gouin/helm-openldap "GitHub - jp-gouin/helm-openldap:
Helm chart of Openldap in High availability with multi-master replication and
PhpLdapAdmin and Ltb-Passwd"
[2]: https://www.datree.io/helm-chart/openldap-jp-gouin "Openldap Helm Chart |
Datree"
[3]:
https://www.o-forge.io/core/oc-k8s/commit/ba9a971964794bb0f930c7caba69aa4dc73f4d7f.diff?utm_source=chatgpt.com
"https://www.o-forge.io/core/oc-k8s/commit/ba9a9719..."
[4]:
https://hackmd.io/%40tsungjung411/r1Yg3rE9lx?utm_medium=rec&utm_source=chatgpt.com
"在Kubernetes 上部署OpenLDAP 的詳細教學"
