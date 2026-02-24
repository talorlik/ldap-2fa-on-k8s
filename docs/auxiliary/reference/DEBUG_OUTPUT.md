kubectl get pods -n ldap -o wide
NAME                                              READY   STATUS             RESTARTS      AGE    IP            NODE                  NOMINATED NODE   READINESS GATES
openldap-stack-ha-0                               0/1     CrashLoopBackOff   6 (31s ago)   7m3s   10.0.10.178   i-0c6e4d1213d59e235   <none>           <none>
openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9     1/1     Running            0             7m3s   10.0.10.177   i-0c6e4d1213d59e235   <none>           <none>
openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g   1/1     Running            0             7m3s   10.0.10.176   i-0c6e4d1213d59e235   <none>           <none>


aws eks describe-cluster \
  --name talo-tf-us-east-1-kc-prod \
  --region us-east-1 \
  --query 'cluster.{Status:status,Version:version,Endpoint:endpoint,Logging:logging}'
{
    "Status": "ACTIVE",
    "Version": "1.35",
    "Endpoint": "https://1FB473AA7070103C07DD9A056E034EAD.gr7.us-east-1.eks.amazonaws.com",
    "Logging": {
        "clusterLogging": [
            {
                "types": [
                    "api",
                    "audit",
                    "authenticator",
                    "controllerManager",
                    "scheduler"
                ],
                "enabled": true
            }
        ]
    }
}


aws eks list-compute --cluster-name talo-tf-us-east-1-kc-prod \
  --region us-east-1 2>/dev/null || \
aws eks describe-cluster --name talo-tf-us-east-1-kc-prod \
  --region us-east-1 --query 'cluster.computeConfig'
{
    "enabled": true,
    "nodePools": [
        "general-purpose"
    ],
    "nodeRoleArn": "arn:aws:iam::944880695150:role/talo-tf-us-east-1-kc-prod-eks-auto-20260224100206316400000001"
}


kubectl get events -A --sort-by='.lastTimestamp' | tail -50
ldap          7m46s       Normal    SuccessfullyReconciled    ingress/openldap-stack-ha-ltb-passwd                          Successfully reconciled
ldap          7m46s       Normal    SuccessfullyReconciled    ingress/openldap-stack-ha-phpldapadmin                        Successfully reconciled
default       7m46s       Normal    DisruptionBlocked         nodeclaim/general-purpose-jwblf                               Nodeclaim does not have an associated node
ldap          7m42s       Warning   FailedScheduling          pod/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9             no nodes available to schedule pods
ldap          7m42s       Warning   FailedScheduling          pod/openldap-stack-ha-0                                       no nodes available to schedule pods
ldap          7m42s       Warning   FailedScheduling          pod/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g           no nodes available to schedule pods
ldap          7m40s       Normal    WaitForPodScheduled       persistentvolumeclaim/data-openldap-stack-ha-0                waiting for pod openldap-stack-ha-0 to be scheduled
default       7m37s       Normal    NodeHasNoDiskPressure     node/i-0c6e4d1213d59e235                                      Node i-0c6e4d1213d59e235 status is now: NodeHasNoDiskPressure
default       7m37s       Normal    Starting                  node/i-0c6e4d1213d59e235                                      Starting kubelet.
default       7m37s       Normal    NodeAllocatableEnforced   node/i-0c6e4d1213d59e235                                      Updated Node Allocatable limit across pods
default       7m37s       Normal    NodeHasSufficientPID      node/i-0c6e4d1213d59e235                                      Node i-0c6e4d1213d59e235 status is now: NodeHasSufficientPID
default       7m37s       Normal    NodeHasSufficientMemory   node/i-0c6e4d1213d59e235                                      Node i-0c6e4d1213d59e235 status is now: NodeHasSufficientMemory
default       7m37s       Warning   InvalidDiskCapacity       node/i-0c6e4d1213d59e235                                      invalid capacity 0 on image filesystem
default       7m36s       Normal    Registered                nodeclaim/general-purpose-jwblf                               Status condition transitioned, Type: Registered, Status: Unknown -> True, Reason: Registered
default       7m36s       Normal    NodeRegistrationHealthy   nodepool/general-purpose                                      Status condition transitioned, Type: NodeRegistrationHealthy, Status: Unknown -> True, Reason: NodeRegistrationHealthy
default       7m35s       Normal    Synced                    node/i-0c6e4d1213d59e235                                      Node synced successfully
default       7m35s       Normal    Ready                     node/i-0c6e4d1213d59e235                                      Status condition transitioned, Type: Ready, Status: False -> True, Reason: KubeletReady, Message: kubelet is posting ready status
default       7m35s       Normal    NodeReady                 node/i-0c6e4d1213d59e235                                      Node i-0c6e4d1213d59e235 status is now: NodeReady
default       7m35s       Normal    RegisteredNode            node/i-0c6e4d1213d59e235                                      Node i-0c6e4d1213d59e235 event: Registered Node i-0c6e4d1213d59e235 in Controller
default       7m34s       Normal    Initialized               nodeclaim/general-purpose-jwblf                               Status condition transitioned, Type: Initialized, Status: Unknown -> True, Reason: Initialized
default       7m34s       Normal    Ready                     nodeclaim/general-purpose-jwblf                               Status condition transitioned, Type: Ready, Status: Unknown -> True, Reason: Ready
ldap          7m33s       Normal    Scheduled                 pod/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9             Successfully assigned ldap/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9 to i-0c6e4d1213d59e235
ldap          7m33s       Normal    Provisioning              persistentvolumeclaim/data-openldap-stack-ha-0                External provisioner is provisioning volume for claim "ldap/data-openldap-stack-ha-0"
ldap          7m33s       Normal    ExternalProvisioning      persistentvolumeclaim/data-openldap-stack-ha-0                Waiting for a volume to be created either by the external provisioner 'ebs.csi.eks.amazonaws.com' or manually by the system administrator. If volume creation is delayed, please verify that the provisioner is running and correctly registered.
ldap          7m33s       Normal    Scheduled                 pod/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g           Successfully assigned ldap/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g to i-0c6e4d1213d59e235
ldap          7m31s       Normal    ProvisioningSucceeded     persistentvolumeclaim/data-openldap-stack-ha-0                Successfully provisioned volume pvc-031b5928-5d2b-4bdf-a641-7cfeb5fbb507
ldap          7m30s       Normal    Scheduled                 pod/openldap-stack-ha-0                                       Successfully assigned ldap/openldap-stack-ha-0 to i-0c6e4d1213d59e235
ldap          7m28s       Normal    Pulling                   pod/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9             Pulling image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:ltb-passwd-5.2.3"
ldap          7m28s       Normal    SuccessfulAttachVolume    pod/openldap-stack-ha-0                                       AttachVolume.Attach succeeded for volume "pvc-031b5928-5d2b-4bdf-a641-7cfeb5fbb507"
ldap          7m28s       Normal    Pulling                   pod/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g           Pulling image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:phpldapadmin-0.9.0"
default       7m26s       Normal    DisruptionBlocked         node/i-0c6e4d1213d59e235                                      Node is nominated for a pending pod
ldap          7m20s       Normal    Pulled                    pod/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g           Successfully pulled image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:phpldapadmin-0.9.0" in 7.366s (7.366s including waiting). Image size: 108604559 bytes.
ldap          7m20s       Normal    Started                   pod/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g           Container started
ldap          7m20s       Normal    Created                   pod/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g           Container created
ldap          7m19s       Normal    Pulled                    pod/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9             Successfully pulled image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:ltb-passwd-5.2.3" in 8.31s (8.311s including waiting). Image size: 154030635 bytes.
ldap          7m19s       Normal    Created                   pod/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9             Container created
ldap          7m19s       Normal    Started                   pod/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9             Container started
ldap          7m19s       Normal    Pulling                   pod/openldap-stack-ha-0                                       Pulling image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:openldap-1.5.0"
ldap          7m19s       Warning   Unhealthy                 pod/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g           Readiness probe failed: Get "http://10.0.10.176:80/": dial tcp 10.0.10.176:80: connect: connection refused
ldap          7m18s       Warning   Unhealthy                 pod/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9             Readiness probe failed: Get "http://10.0.10.177:80/": dial tcp 10.0.10.177:80: connect: connection refused
ldap          7m15s       Normal    Pulled                    pod/openldap-stack-ha-0                                       Successfully pulled image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:openldap-1.5.0" in 4.715s (4.715s including waiting). Image size: 91665477 bytes.
ldap          7m8s        Normal    SuccessfullyReconciled    targetgroupbinding/k8s-ldap-openldap-b7d2405cf4               Successfully reconciled
ldap          7m7s        Normal    SuccessfullyReconciled    targetgroupbinding/k8s-ldap-openldap-8c8f042379               Successfully reconciled
ldap          5m36s       Warning   Unhealthy                 pod/openldap-stack-ha-0                                       Startup probe failed: dial tcp 10.0.10.178:389: connect: connection refused
default       106s        Normal    DisruptionBlocked         nodeclaim/general-purpose-jwblf                               Pdb prevents pod evictions (PodDisruptionBudget=[ldap/openldap-stack-ha])
default       86s         Normal    DisruptionBlocked         node/i-0c6e4d1213d59e235                                      Pdb prevents pod evictions (PodDisruptionBudget=[ldap/openldap-stack-ha])
ldap          81s         Normal    Created                   pod/openldap-stack-ha-0                                       Container created
ldap          81s         Normal    Started                   pod/openldap-stack-ha-0                                       Container started
ldap          81s         Normal    Pulled                    pod/openldap-stack-ha-0                                       Container image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:openldap-1.5.0" already present on machine and can be accessed by the pod
ldap          75s         Warning   BackOff                   pod/openldap-stack-ha-0                                       Back-off restarting failed container openldap-stack-ha in pod openldap-stack-ha-0_ldap(f26c2961-aa7b-4faf-ab7d-17c289e6e26a)


kubectl get events -A --sort-by='.lastTimestamp' | tail -50
ldap          8m14s       Normal    SuccessfullyReconciled    ingress/openldap-stack-ha-ltb-passwd                          Successfully reconciled
ldap          8m14s       Normal    SuccessfullyReconciled    ingress/openldap-stack-ha-phpldapadmin                        Successfully reconciled
default       8m14s       Normal    DisruptionBlocked         nodeclaim/general-purpose-jwblf                               Nodeclaim does not have an associated node
ldap          8m10s       Warning   FailedScheduling          pod/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9             no nodes available to schedule pods
ldap          8m10s       Warning   FailedScheduling          pod/openldap-stack-ha-0                                       no nodes available to schedule pods
ldap          8m10s       Warning   FailedScheduling          pod/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g           no nodes available to schedule pods
ldap          8m8s        Normal    WaitForPodScheduled       persistentvolumeclaim/data-openldap-stack-ha-0                waiting for pod openldap-stack-ha-0 to be scheduled
default       8m5s        Normal    NodeHasNoDiskPressure     node/i-0c6e4d1213d59e235                                      Node i-0c6e4d1213d59e235 status is now: NodeHasNoDiskPressure
default       8m5s        Normal    Starting                  node/i-0c6e4d1213d59e235                                      Starting kubelet.
default       8m5s        Normal    NodeAllocatableEnforced   node/i-0c6e4d1213d59e235                                      Updated Node Allocatable limit across pods
default       8m5s        Normal    NodeHasSufficientPID      node/i-0c6e4d1213d59e235                                      Node i-0c6e4d1213d59e235 status is now: NodeHasSufficientPID
default       8m5s        Normal    NodeHasSufficientMemory   node/i-0c6e4d1213d59e235                                      Node i-0c6e4d1213d59e235 status is now: NodeHasSufficientMemory
default       8m5s        Warning   InvalidDiskCapacity       node/i-0c6e4d1213d59e235                                      invalid capacity 0 on image filesystem
default       8m4s        Normal    Registered                nodeclaim/general-purpose-jwblf                               Status condition transitioned, Type: Registered, Status: Unknown -> True, Reason: Registered
default       8m4s        Normal    NodeRegistrationHealthy   nodepool/general-purpose                                      Status condition transitioned, Type: NodeRegistrationHealthy, Status: Unknown -> True, Reason: NodeRegistrationHealthy
default       8m3s        Normal    Synced                    node/i-0c6e4d1213d59e235                                      Node synced successfully
default       8m3s        Normal    Ready                     node/i-0c6e4d1213d59e235                                      Status condition transitioned, Type: Ready, Status: False -> True, Reason: KubeletReady, Message: kubelet is posting ready status
default       8m3s        Normal    NodeReady                 node/i-0c6e4d1213d59e235                                      Node i-0c6e4d1213d59e235 status is now: NodeReady
default       8m3s        Normal    RegisteredNode            node/i-0c6e4d1213d59e235                                      Node i-0c6e4d1213d59e235 event: Registered Node i-0c6e4d1213d59e235 in Controller
default       8m2s        Normal    Initialized               nodeclaim/general-purpose-jwblf                               Status condition transitioned, Type: Initialized, Status: Unknown -> True, Reason: Initialized
default       8m2s        Normal    Ready                     nodeclaim/general-purpose-jwblf                               Status condition transitioned, Type: Ready, Status: Unknown -> True, Reason: Ready
ldap          8m1s        Normal    Scheduled                 pod/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9             Successfully assigned ldap/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9 to i-0c6e4d1213d59e235
ldap          8m1s        Normal    Provisioning              persistentvolumeclaim/data-openldap-stack-ha-0                External provisioner is provisioning volume for claim "ldap/data-openldap-stack-ha-0"
ldap          8m1s        Normal    ExternalProvisioning      persistentvolumeclaim/data-openldap-stack-ha-0                Waiting for a volume to be created either by the external provisioner 'ebs.csi.eks.amazonaws.com' or manually by the system administrator. If volume creation is delayed, please verify that the provisioner is running and correctly registered.
ldap          8m1s        Normal    Scheduled                 pod/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g           Successfully assigned ldap/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g to i-0c6e4d1213d59e235
ldap          7m59s       Normal    ProvisioningSucceeded     persistentvolumeclaim/data-openldap-stack-ha-0                Successfully provisioned volume pvc-031b5928-5d2b-4bdf-a641-7cfeb5fbb507
ldap          7m58s       Normal    Scheduled                 pod/openldap-stack-ha-0                                       Successfully assigned ldap/openldap-stack-ha-0 to i-0c6e4d1213d59e235
ldap          7m56s       Normal    Pulling                   pod/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9             Pulling image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:ltb-passwd-5.2.3"
ldap          7m56s       Normal    SuccessfulAttachVolume    pod/openldap-stack-ha-0                                       AttachVolume.Attach succeeded for volume "pvc-031b5928-5d2b-4bdf-a641-7cfeb5fbb507"
ldap          7m56s       Normal    Pulling                   pod/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g           Pulling image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:phpldapadmin-0.9.0"
default       7m54s       Normal    DisruptionBlocked         node/i-0c6e4d1213d59e235                                      Node is nominated for a pending pod
ldap          7m48s       Normal    Pulled                    pod/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g           Successfully pulled image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:phpldapadmin-0.9.0" in 7.366s (7.366s including waiting). Image size: 108604559 bytes.
ldap          7m48s       Normal    Started                   pod/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g           Container started
ldap          7m48s       Normal    Created                   pod/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g           Container created
ldap          7m47s       Normal    Pulled                    pod/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9             Successfully pulled image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:ltb-passwd-5.2.3" in 8.31s (8.311s including waiting). Image size: 154030635 bytes.
ldap          7m47s       Normal    Created                   pod/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9             Container created
ldap          7m47s       Normal    Started                   pod/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9             Container started
ldap          7m47s       Normal    Pulling                   pod/openldap-stack-ha-0                                       Pulling image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:openldap-1.5.0"
ldap          7m47s       Warning   Unhealthy                 pod/openldap-stack-ha-phpldapadmin-795f865b7b-fjk6g           Readiness probe failed: Get "http://10.0.10.176:80/": dial tcp 10.0.10.176:80: connect: connection refused
ldap          7m46s       Warning   Unhealthy                 pod/openldap-stack-ha-ltb-passwd-79d54bd5cd-rjnh9             Readiness probe failed: Get "http://10.0.10.177:80/": dial tcp 10.0.10.177:80: connect: connection refused
ldap          7m43s       Normal    Pulled                    pod/openldap-stack-ha-0                                       Successfully pulled image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:openldap-1.5.0" in 4.715s (4.715s including waiting). Image size: 91665477 bytes.
ldap          7m36s       Normal    SuccessfullyReconciled    targetgroupbinding/k8s-ldap-openldap-b7d2405cf4               Successfully reconciled
ldap          7m35s       Normal    SuccessfullyReconciled    targetgroupbinding/k8s-ldap-openldap-8c8f042379               Successfully reconciled
ldap          6m4s        Warning   Unhealthy                 pod/openldap-stack-ha-0                                       Startup probe failed: dial tcp 10.0.10.178:389: connect: connection refused
default       114s        Normal    DisruptionBlocked         node/i-0c6e4d1213d59e235                                      Pdb prevents pod evictions (PodDisruptionBudget=[ldap/openldap-stack-ha])
ldap          109s        Normal    Created                   pod/openldap-stack-ha-0                                       Container created
ldap          109s        Normal    Started                   pod/openldap-stack-ha-0                                       Container started
ldap          109s        Normal    Pulled                    pod/openldap-stack-ha-0                                       Container image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:openldap-1.5.0" already present on machine and can be accessed by the pod
ldap          17s         Warning   BackOff                   pod/openldap-stack-ha-0                                       Back-off restarting failed container openldap-stack-ha in pod openldap-stack-ha-0_ldap(f26c2961-aa7b-4faf-ab7d-17c289e6e26a)
default       13s         Normal    DisruptionBlocked         nodeclaim/general-purpose-jwblf                               Pdb prevents pod evictions (PodDisruptionBudget=[ldap/openldap-stack-ha])


kubectl logs openldap-stack-ha-0 -n ldap --container openldap-stack-ha | head -100
***  INFO   | 2026-02-24 10:59:27 | CONTAINER_LOG_LEVEL = 3 (info)
***  INFO   | 2026-02-24 10:59:27 | Search service in CONTAINER_SERVICE_DIR = /container/service :
***  INFO   | 2026-02-24 10:59:27 | link /container/service/:ssl-tools/startup.sh to /container/run/startup/:ssl-tools
***  INFO   | 2026-02-24 10:59:27 | link /container/service/slapd/startup.sh to /container/run/startup/slapd
***  INFO   | 2026-02-24 10:59:27 | link /container/service/slapd/process.sh to /container/run/process/slapd/run
***  INFO   | 2026-02-24 10:59:27 | Environment files will be proccessed in this order :
Caution: previously defined variables will not be overriden.
/container/environment/99-default/default.startup.yaml
/container/environment/99-default/default.yaml

To see how this files are processed and environment variables values,
run this container with '--loglevel debug'
***  INFO   | 2026-02-24 10:59:27 | Running /container/run/startup/:ssl-tools...
***  INFO   | 2026-02-24 10:59:27 | Running /container/run/startup/slapd...
***  INFO   | 2026-02-24 10:59:27 | openldap user and group adjustments
***  INFO   | 2026-02-24 10:59:27 | get current openldap uid/gid info inside container
***  INFO   | 2026-02-24 10:59:27 | -------------------------------------
***  INFO   | 2026-02-24 10:59:27 | openldap GID/UID
***  INFO   | 2026-02-24 10:59:27 | -------------------------------------
***  INFO   | 2026-02-24 10:59:27 | User uid: 911
***  INFO   | 2026-02-24 10:59:27 | User gid: 911
***  INFO   | 2026-02-24 10:59:27 | uid/gid changed: false
***  INFO   | 2026-02-24 10:59:27 | -------------------------------------
***  INFO   | 2026-02-24 10:59:27 | updating file uid/gid ownership
chown: changing ownership of '/container/service/slapd/assets/config/bootstrap/ldif/custom/..2026_02_24_10_53_17.2802369171/01-init-ous.ldif': Read-only file system
chown: changing ownership of '/container/service/slapd/assets/config/bootstrap/ldif/custom/..2026_02_24_10_53_17.2802369171/02-init-groups.ldif': Read-only file system
chown: changing ownership of '/container/service/slapd/assets/config/bootstrap/ldif/custom/..2026_02_24_10_53_17.2802369171': Read-only file system
chown: changing ownership of '/container/service/slapd/assets/config/bootstrap/ldif/custom/..data': Read-only file system
chown: changing ownership of '/container/service/slapd/assets/config/bootstrap/ldif/custom/01-init-ous.ldif': Read-only file system
chown: changing ownership of '/container/service/slapd/assets/config/bootstrap/ldif/custom/02-init-groups.ldif': Read-only file system
chown: changing ownership of '/container/service/slapd/assets/config/bootstrap/ldif/custom': Read-only file system
***  ERROR  | 2026-02-24 10:59:28 | /container/run/startup/slapd failed with status 1

***  INFO   | 2026-02-24 10:59:28 | Killing all processes...


kubectl describe pod openldap-stack-ha-0 -n ldap | grep -A 20 "Events:"
Events:
  Type     Reason                  Age                    From                     Message
  ----     ------                  ----                   ----                     -------
  Normal   Nominated               9m3s                   eks-auto-mode/compute    Pod should schedule on: nodeclaim/general-purpose-jwblf
  Warning  FailedScheduling        8m54s (x4 over 9m4s)   default-scheduler        no nodes available to schedule pods
  Normal   Scheduled               8m42s                  default-scheduler        Successfully assigned ldap/openldap-stack-ha-0 to i-0c6e4d1213d59e235
  Normal   SuccessfulAttachVolume  8m40s                  attachdetach-controller  AttachVolume.Attach succeeded for volume "pvc-031b5928-5d2b-4bdf-a641-7cfeb5fbb507"
  Normal   Pulling                 8m31s                  kubelet                  spec.containers{openldap-stack-ha}: Pulling image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:openldap-1.5.0"
  Normal   Pulled                  8m27s                  kubelet                  spec.containers{openldap-stack-ha}: Successfully pulled image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:openldap-1.5.0" in 4.715s (4.715s including waiting). Image size: 91665477 bytes.
  Warning  Unhealthy               6m48s                  kubelet                  spec.containers{openldap-stack-ha}: Startup probe failed: dial tcp 10.0.10.178:389: connect: connection refused
  Normal   Created                 2m33s (x7 over 8m27s)  kubelet                  spec.containers{openldap-stack-ha}: Container created
  Normal   Started                 2m33s (x7 over 8m26s)  kubelet                  spec.containers{openldap-stack-ha}: Container started
  Normal   Pulled                  2m33s (x6 over 8m24s)  kubelet                  spec.containers{openldap-stack-ha}: Container image "944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:openldap-1.5.0" already present on machine and can be accessed by the pod
  Warning  BackOff                 61s (x19 over 8m23s)   kubelet                  spec.containers{openldap-stack-ha}: Back-off restarting failed container openldap-stack-ha in pod openldap-stack-ha-0_ldap(f26c2961-aa7b-4faf-ab7d-17c289e6e26a)