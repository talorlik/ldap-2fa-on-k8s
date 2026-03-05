# LDAP-2FA-ON-K8S - ARCHITECTURE DIAGRAM GENERATION AGENT (DRAW.IO)

## ROLE

You are a diagram-generation agent for this repository. Your job is to generate
accurate, consistent, automation-friendly **Draw.io** architecture diagrams for
the **ldap-2fa-on-k8s** project using:

- AWS Route53 for domain and hosted zone.
- AWS ACM for certificate.
- AWS VPC for networking.
- AWS EKS Auto Mode for compute/orchestration.
- AWS ALB for routing.
- OpenLDAP deployed on AWS EKS for user authorization.
- PostgreSQL deployed on AWS EKS as the database for users/groups.
- Redis deployed on AWS EKS for TTL tokens.
- Amazon S3 for Terraform state.
- AWS Secrets Manager for all secrets.
- GitHub Actions for CI/CD and Terraform execution.
- AWS Managed ArgoCD Capability for GitOps-based continuous delivery into the EKS.
- Terraform (official AWS Terraform modules) as the IaC source of truth.
- 2FA application to allow users to signup and login and manage their profiles.
- AWS SNS for SMS 2FA authentication.
- AWS SES for Email.

The system provides:

- **Centralized identity**: OpenLDAP (HA / multi-master replication) plus
**phpLDAPadmin** and **LTB self-service password** UIs.
- **2FA application**: split deployment (backend + frontend) with:
  - TOTP (Authenticator/QR) MFA
  - SMS MFA via AWS SNS (optional but supported)
- **Infrastructure as Code**: strict, layered Terraform roots:
  1) `tf_backend_state/`
  2) `backend_infra/`
  3) `application_infra/`
  4) `application/`
- **GitOps**: ArgoCD via **AWS EKS managed ArgoCD capability**, with ArgoCD
Applications for the 2FA backend and frontend.
- **Multi-account AWS**: State/DNS/secrets in a State account (Account A),
runtime infra and workloads in Deployment account(s) (Account B: dev/prod).

## OUTPUTS (DELIVERABLES)

### YOU MUST PRODUCE

- A Python script at `docs/architecture-diagrams/generated-python.py` that generates
diagrams using the `diagrams` Python library and Graphviz.
- Rendered diagram artifacts under `docs/architecture-diagrams/diagrams/` in these
formats: `.png`, `.dot`, `.drawio`.

Deliver **one unified architectural diagram** for the entire project (or a small
set of views: e.g. runtime, network, delivery; each view is one diagram spanning
the whole system). Terraform layers are for **data collection only**: run plan
per layer, collect `tfplan.json`, **parse and merge** into one model, then render
**one diagram** (or one per view). Do not produce one diagram per Terraform layer.

Your diagrams must reflect both:

- The **layered deployment model** (Terraform roots and their dependencies).
- The **runtime topology** (AWS networking + EKS workloads + external entrypoints).

## FILE STRUCTURE

```bash
docs/
  architecture-diagrams/
    venv/               # Python virtual environment
    diagrams/
        *.png           # Will be created upon execution
        *.dot           # Will be created upon execution
        *.drawio        # Will be created upon execution
    generated-python.py # Will be created upon execution
    requirements.txt    # Python package dependencies
    SETUP.md
    AGENT.md
    INSTRUCTIONS.md
```

## NON-NEGOTIABLE SECURITY RULES

- Do **not** expose LDAP (389/636) as internet-facing in any diagram.
- Do **not** place secret values, passwords, tokens, ExternalId, access keys,
private keys, or full connection strings, in diagram labels.
- Do **not** include internal account IDs unless already present in the repository
docs.
- Show cross-account boundaries explicitly and label the trust direction
(Account A -> Account B assume-role with ExternalId).
- Do **not** run `terraform apply`

## WORKING DIRECTORY AND REPOSITORY ISOLATION

**Do not modify the real repository.** All work must be done in an isolated copy
so the repository stays clean.

1. **Working copy:** At the start, copy the **entire repository** to
  `/tmp/ldap-2fa-on-k8s/`, **excluding** the following so the copy is lean and
  avoids IDE/version-control/sandbox issues:

    - `.git`
    - `.cursor`
    - `.vscode`
    - `**/.terraform/*`
    - `.terraform.lock.hcl`
    - `**/venv/`
  All steps (Terraform plan per layer, backend config, variables.tfvars,
  ci.auto.tfvars.json, generated-python.py, diagram generation) run **only** under
  `/tmp/ldap-2fa-on-k8s/`. Paths like "repository root" or "layer copy" mean
  within this working copy unless stated otherwise.

2. **Outputs written in working copy:** The Python script and diagram artifacts
  (`.png`, `.dot`, `.drawio`) are created under
  `/tmp/ldap-2fa-on-k8s/docs/architecture-diagrams/` (e.g. `generated-python.py`
  and `diagrams/` there).

3. **Copy back and cleanup:** When diagram generation is complete:
    - Copy `generated-python.py` from
      `/tmp/ldap-2fa-on-k8s/docs/architecture-diagrams/generated-python.py` to
      the repository at `docs/architecture-diagrams/generated-python.py`.
    - Copy all generated diagram files from
      `/tmp/ldap-2fa-on-k8s/docs/architecture-diagrams/diagrams/` to the
      repository at `docs/architecture-diagrams/diagrams/`.
    - Delete the entire working copy: `rm -rf /tmp/ldap-2fa-on-k8s/`.

No backend config, tfvars, plan outputs, or other artifacts from the process
may be written into the real repository; only the final `generated-python.py`
and the contents of `diagrams/` are copied back.

## DIAGRAM GENERATION WORKFLOW

0. CREATE WORKING COPY
    - Copy the entire repository to `/tmp/ldap-2fa-on-k8s/` **excluding**:
      `.git`, `.cursor`, `.vscode`, `**/.terraform/*`, `.terraform.lock.hcl`,
      `**/venv/`. Example with rsync from the repo root:

      ```bash
      rsync -a --exclude='.git' --exclude='.cursor' --exclude='.vscode' \
        --exclude='.terraform/' --exclude='.terraform.lock.hcl' --exclude='venv/' \
        . /tmp/ldap-2fa-on-k8s/
      ```

      All subsequent steps run from or under this directory; the real repository
      is not modified until the final copy-back step.

1. READ INPUTS:
    - `docs/architecture/ARCHITECTURE.md` (solution architecture and layer flow).
    - `README.md` (repo root), layer READMEs (`tf_backend_state/`, `backend_infra/`,
    `application_infra/`, `application/`), and application backend/frontend READMEs.
    - `WARP.md` (gotchas, invariants, naming, routing rules).
    - `repomix_output.md` (packed repo structure and key files).
    - Understand intended architecture and identify the four Terraform layers and
    their responsibilities.

2. DERIVE THE DIAGRAM SET
    - Produce one unified diagram (or a small set of views) for the entire
    project. Merge data from all four layers into a single model. Cover, at minimum:
      - NETWORK TOPOLOGY: VPC, subnets (public/private), NAT and internet egress,
      VPC endpoints, and traffic direction, etc.
      - HIGH-LEVEL RUNTIME TOPOLOGY: Users -> Route 53 -> ALB -> EKS (LDAP + 2FA).
      - DELIVERY AND CONTROL PLANE: GitHub Actions (Terraform) ->
      AWS (via OIDC assumed role) and ArgoCD -> EKS reconciliation.

3. GENERATE `generated-python.py`
    - **Input:** Terraform plan/state JSON from all four layers; parse and merge
    into one model.
    - **Output:** One unified diagram (or one function per view). Each diagram produces:
      - `diagrams/<name>.dot` (Graphviz source)
      - `diagrams/<name>.png` (rendered image)
    - Ensure `generated-python.py` writes output files to
      `docs/architecture-diagrams/diagrams/` (under the working copy when run
      from `/tmp/ldap-2fa-on-k8s/`).
    - Import required AWS components from `diagrams.aws.*`
    - Use proper icon names (e.g., `PublicIpAddresses` not `PublicIPAddresses`)
    - Configure graph attributes for layout:

      ```python
      graph_attr = {
          "splines": "ortho",  # Orthogonal lines
          "nodesep": "0.8",    # Node spacing
          "ranksep": "1.2",    # Rank spacing
          "fontsize": "14",
          "bgcolor": "white",
          "pad": "0.5"
      }
      ```

    - Use Cluster for logical grouping (VPCs, Subnets, Resource Groups)
    - Set different background colors for different tiers/clusters
    - Set output format: `outformat=["png", "dot"]`

4. RUN WITH GRAPHVIZ AVAILABLE

    Because `venv/` is not copied into the working copy, create a virtual
    environment and install dependencies in the working copy before running
    the script then run the diagram generator from the **working copy**:

    ```bash
    cd /tmp/ldap-2fa-on-k8s/docs/architecture-diagrams/
    python3 -m venv venv
    source venv/bin/activate
    ```

    ```bash
    pip install --config-settings="--global-option=build_ext" \
      --config-settings="--global-option=-I$(brew --prefix graphviz)/include/" \
      --config-settings="--global-option=-L$(brew --prefix graphviz)/lib/" \
      pygraphviz
    ```

    ```bash
    pip install diagrams graphviz graphviz2drawio
    ```

    ```bash
    python generated-python.py
    ```

5. CONVERT DOT TO DRAW.IO
    - After generating `.dot` files, convert each to `.drawio`.
    - Use a deterministic conversion approach (CLI tool or script) so regeneration
    is repeatable.
    - This happens automatically in the script using:

      ```python
      subprocess.run([
          "graphviz2drawio",
          "diagrams/<name>.dot",
          "-o",
          "diagrams/<name>.drawio"
      ], check=True)
      ```

6. VALIDATE OUTPUTS
    - Verify each diagram:
      - Uses correct AWS node classes and labels.
      - Uses tier coloring and group clusters consistently.
      - Avoids secret values and sensitive strings in labels.
      - Remains readable (avoid excessive node density by splitting into multiple
      diagrams/views).

7. COPY OUTPUTS TO REPOSITORY AND CLEANUP
    - Copy `generated-python.py` from
      `/tmp/ldap-2fa-on-k8s/docs/architecture-diagrams/generated-python.py` to
      `docs/architecture-diagrams/generated-python.py` in the repository.
    - Copy all files from
      `/tmp/ldap-2fa-on-k8s/docs/architecture-diagrams/diagrams/` to
      `docs/architecture-diagrams/diagrams/` in the repository.
    - Delete the working copy: `rm -rf /tmp/ldap-2fa-on-k8s/`.

## PARSING INFRASTRUCTURE-AS-CODE

### TERRAFORM PARSING

Use Terraform plan/state JSON as the primary parsing source. Avoid parsing raw `.tf`
files as the only source; module expansion and computed dependencies are not visible.

**Layer order (this project):** `tf_backend_state` -> `backend_infra` ->
`application_infra` -> `application`. In a real deployment, cross-layer data is
passed via Terraform remote state (S3). For diagram-only we do **not** use real
remote state; see "State backend settings (diagram-only)" below.

**State backend settings (diagram-only):**

We never use the real S3 backend or read real state. Do the following in the
working copy only:

- **Each layer's own state:** In each layer under `/tmp/ldap-2fa-on-k8s/`,
  change `backend "s3"` to `backend "local" {}` in `providers.tf` and remove
  S3-specific options (e.g. `encrypt`, `use_lockfile`). Run `terraform init`
  **without** `-backend-config=backend.hcl`. Terraform will use the local
  backend; state stays under the working copy (e.g. `terraform.tfstate` in the
  layer directory). No S3 is used.

- **Do not use backend.hcl for init when using local backend.** The
  `-backend-config=backend.hcl` pattern is for real runs with S3; for
  diagram-only, init uses only the `backend "local" {}` block in providers.tf.

- **Layers that read other layers' state (application_infra, application):**
  They use `data.local_file` to read `../backend_infra/backend.hcl` (and
  application also reads `../application_infra/backend.hcl`). That file must
  exist or Terraform will fail. In the working copy, create a minimal
  `backend.hcl` in the **referenced** layer's directory only:
  - `backend_infra/backend.hcl` (read by application_infra and application)
  - `application_infra/backend.hcl` (read by application)
  Use content that makes the parsing logic yield `backend_bucket = null` (e.g.
  `bucket = ""`, `key = ""`, `region = "us-east-1"`), so that
  `data.terraform_remote_state` has `count = 0` and no S3 read is attempted.
  Then supply the values that would have come from remote state via
  `ci.auto.tfvars.json` and variable overrides (e.g. `cluster_name` for
  application_infra).

1. COLLECT TERRAFORM JSON (data collection only; used to build one unified diagram)

    **Do not run `terraform apply`.** From the **working copy** root at
    `/tmp/ldap-2fa-on-k8s/`, run plan (or use existing state) per layer, then
    **merge** all plan/state JSON into a single model for the one project-wide
    diagram.

    **Prerequisites:** AWS CLI, `jq`, Terraform (version matching `.github/workflows`).
    Set: `PREFIX="${PREFIX:-ldap-2fa}"`, `ENV="${ENV:-prod}"`, `REGION="${REGION:-us-east-1}"`.
    GitHub Actions use `AWS_STATE_ACCOUNT_ROLE_ARN` (from GitHub secrets) to assume
    the state account role for S3 state; for diagram-only we use a **local**
    backend only (no S3, no assume-role required for state).

    **Diagram-only (local backend):** Within the working copy, each layer uses
    `backend "local" {}` and init is run without `-backend-config` (see "State
    backend settings (diagram-only)" above). Then run `terraform workspace select
    $REGION-$ENV` (or create it), `terraform plan -out=tfplan`, and
    `terraform show -json tfplan > tfplan.json`. All of this happens under
    `/tmp/ldap-2fa-on-k8s/`; the real repository is never modified.

    **Layers to process:** `tf_backend_state`, `backend_infra`, `application_infra`,
    `application`. All layer work (including ci.auto.tfvars.json and any backend
    or variable overrides) is done under `/tmp/ldap-2fa-on-k8s/` only. For
    diagram-only (no `terraform apply`), dependent layers have no real state to
    read; you must **simulate** each layer's outputs and pass them into the next
    layer via **ci.auto.tfvars.json** (or equivalent) in that layer's directory
    within the working copy.

    **Simulate outputs and feed next layer:**

    - After running `terraform plan` for a layer (in its copy), derive that layer's
      "outputs" either from the plan JSON (`planned_values.outputs` if present)
      or from a **placeholder table** of known output names and diagram-safe values.
    - Write a **ci.auto.tfvars.json** (or **ci.auto.tfvars**) **inside the copy**
      of the **next** layer, containing variable names and values that the next
      layer accepts (e.g. `cluster_name`, and any optional overrides for remote-state
      values where the repo supports them). Use placeholder values only (no real
      ARNs, IDs, or secrets).
    - Run the next layer's plan in its copy, using that tfvars so it does not depend
      on reading prior layer state (or so overrides are applied where supported).
    - Repeat in order: tf_backend_state -> backend_infra -> application_infra ->
      application.

    **Diagram-only workflow (mimic setup scripts):**

    Follow the same sequence as the layer provisioning scripts and workflows, but
    within the **working copy** at `/tmp/ldap-2fa-on-k8s/` and without
    `terraform apply`. Reference:

    - `backend_infra/setup-backend.sh`
    - `application_infra/setup-application-infra.sh`
    - `application/setup-application.sh`
    - `.github/workflows/00-tfstate_infra_*.yaml`, `01-backend_infra_*.yaml`,
      `02-application_infra_*.yaml`, `04-application_*.yaml`
    - **Build workflows (required even for local deployment):**
      `03-backend_build_push.yaml`, `03-frontend_build_push.yaml`

    Methodology to mirror:

    1. **State backend (diagram-only):** Do **not** use `-backend-config=backend.hcl`.
      In each layer under the working copy, set `backend "local" {}` in
      `providers.tf` (remove S3 block). Run `terraform init` with no backend config.
      For application_infra and application, create stub `backend.hcl` in
      referenced layers so `backend_bucket` is null and no remote state is read
      (see "State backend settings (diagram-only)" above).
    2. **variables.tfvars:** Update (in the working copy) `env`, `region`, `prefix`,
      and where applicable `deployment_account_role_arn`,
      `deployment_account_external_id`, `state_account_role_arn` with placeholder
      or diagram-only values (see setup scripts: sed/grep pattern for these keys).
    3. **Credentials:** For diagram-only you may use placeholder role ARNs in
      tfvars and skip real assume-role; or run with real credentials (still using
      local backend only, no S3).
    4. **Init and workspace:** Run `terraform init` (no `-backend-config`), then
      `terraform workspace select $REGION-$ENV` or `terraform workspace new $REGION-$ENV`.
    5. **Plan:** `terraform plan -var-file=variables.tfvars -out=tfplan` (and
      `-var-file=ci.auto.tfvars.json` if present). For application_infra and
      application, ensure the copy has the simulated prior-layer outputs in
      ci.auto.tfvars.json so plan can run without reading real remote state.
    6. **Capture and simulate:** Export or parse plan JSON; build the simulated
      outputs for the next layer and write them into the next layer copy's
      ci.auto.tfvars.json.
    7. **Application layer and image tags:** Before running the application layer
      plan, mimic the effect of 03-backend_build_push and 03-frontend_build_push
      (see "Build workflows and Helm values" below): set
      `TF_VAR_backend_image_tag` and `TF_VAR_frontend_image_tag` to diagram-safe
      placeholders, or pre-populate the Helm values.yaml files in the copy and
      run the same tag-extraction logic as 04-application_provisioning and
      setup-application.sh.

    **Simulated outputs (placeholder table for diagram-only):**

    Use these as the source for ci.auto.tfvars.json when the next layer cannot read
    real state. Omit any real secrets or account IDs; use placeholders like
    `placeholder-id`, `Z0PLACEHOLDER`, `arn:aws:iam::000000000000:role/placeholder`.

    - **backend_infra -> application_infra:** `cluster_name` (supported in
      application_infra; use e.g. `${prefix}-${region}-kc-${env}`). `ecr_registry`
      and `ecr_repository` are not currently overridable via variable; layer
      expects them from remote state.
    - **application_infra -> application:** storage_class_name, alb_*, argocd_*,
      ldap_* outputs are consumed from remote state; no variable overrides in repo
      today for diagram-only.

    Where the repo does not yet define variables for a remote-state value, you
    cannot fully run that layer's plan without real state; document that and use
    placeholders only where variables exist (e.g. application_infra `cluster_name`).

    **Build workflows and Helm values (mimic for diagram-only):**

    Two workflows must run even when deploying locally, and their outputs feed into
    Helm and Terraform. Mimic them so the application layer plan sees a consistent,
    "real" deployment shape without running `terraform apply` or Docker build/push.

    1. **03-backend_build_push** and **03-frontend_build_push**
        - In CI: use GitHub variable `ECR_REPOSITORY_NAME` (set by 01-backend_infra
          after apply from `terraform output -raw ecr_repository`), log in to ECR,
          build and push backend/frontend images, then **update** Helm values with
          the new image repository and tag:
          - `application/backend/helm/ldap-2fa-backend/values.yaml`:
            `image.repository`, `image.tag`
          - `application/frontend/helm/ldap-2fa-frontend/values.yaml`:
            `image.repository`, `image.tag`
        - Those values are what ArgoCD and the admin-seed Job use at deploy time.

    2. **How 04 and setup-application.sh use them**
        - Before running Terraform, the application provisioning workflow and
          `application/setup-application.sh` **read** the image tag from the same
          Helm values files (`grep` for `tag:` in each values.yaml), then export
          `TF_VAR_backend_image_tag` and `TF_VAR_frontend_image_tag`. Terraform
          requires both variables (non-empty, not `latest`) for the application
          layer (admin-seed Job and ArgoCD Application specs).

    3. **Diagram-only simulation (no apply, no build/push)**
        - Do **not** run 03-backend or 03-frontend. Simulate their effect so that
          when you run the **application** layer plan (in its copy), Terraform
          receives valid image tags and the plan succeeds.
        - **Option A (recommended):** When running `terraform plan` for the
          application layer, set `TF_VAR_backend_image_tag` and
          `TF_VAR_frontend_image_tag` to diagram-safe placeholders (e.g.
          `ldap-2fa-backend-diagram`, `ldap-2fa-frontend-diagram`). Do not use
          `latest`. This satisfies Terraform validation without touching Helm files.
        - **Option B (full mimic):** In the application layer **copy**, update the
          two Helm values files so that `image.repository` and `image.tag` are set
          to placeholders (e.g. `placeholder.ecr.region.amazonaws.com/repo` and
          `ldap-2fa-backend-diagram` / `ldap-2fa-frontend-diagram`). Then run the
          same extraction logic as 04/setup-application.sh (read tag from values.yaml
          and export TF_VAR_*). Option B mirrors the real pipeline end-to-end.
        - Ensure the application layer copy includes the backend and frontend Helm
          chart directories so that path-based reads (e.g.
          `backend/helm/ldap-2fa-backend/values.yaml` relative to the application
          root) resolve when using Option B.

2. EXTRACT RESOURCES AND DEPENDENCIES
    - Parse `resource_changes` and `planned_values` from **all** layer plan/state
    JSON files into a **single merged model** (one graph or dataset) that feeds
    the unified diagram.
    - Per layer: identify resources and key attributes (names, ARNs, IDs).
    - Derive edges from:
      - `depends_on` (explicit)
      - implicit dependencies via referenced attributes (when visible in JSON)
    - Collapse low-signal resources (tags, associations) unless they materially
    change topology.

3. MAP TERRAFORM TO DIAGRAM NODES
    - Use a resource-type mapping table to map Terraform resource types or
    module outputs to AWS diagram nodes.
    - Prefer service-level mapping (ALB, EKS, S3, Secrets Manager, PostgreSQL,
    Redis, SNS, SES) rather than every underlying resource.

4. MODEL CROSS-LAYER CONTRACTS
    - Treat **Terraform remote state (S3)** as the contract between layers.
    - In a layer-dependency view: one node per layer; show
    `application_infra` reading from `backend_infra` state, and `application`
    reading from `backend_infra` and `application_infra` state.
    - Do not model Secrets Manager as data-flow edges unless relevant to trust
    boundaries; show it as a shared dependency where used.

## COLOR CODING FOR TIERS

Use cluster background colors to make diagrams scannable. Apply tier colors
consistently across all diagrams.

### TIERS AND COLORS

- EDGE AND DNS (Route 53, Hosted Zone, ACM) - `#E3F2FD`
- INGRESS AND LOAD BALANCING (ALB, listeners, target groups) - `#E8EAF6`
- NETWORKING (VPC, subnets, route tables, NAT, IGW, endpoints) - `#E0F7FA`
- ORCHESTRATION AND COMPUTE (EKS Auto Mode, workloads, nodes/pods) - `#E8F5E9`
- PLATFORM AND GITOPS (ArgoCD, controllers, add-ons) - `#F3E5F5`
- DATA (PostgreSQL, Redis on EKS) - `#FFF3E0`
- STORAGE (S3 assets, EBS/EFS where applicable) - `#FFF8E1`
- SECURITY AND CONFIG (IAM roles, KMS, Secrets Manager) - `#FFEBEE`
- OBSERVABILITY (CloudWatch, logs/metrics endpoints) - `#ECEFF1`

### APPLY TO GROUP CLUSTERS

Use clusters to group by ACCOUNT, REGION, VPC, and SUBNET-TIER. Expand groupings
beyond "cluster" to fit this project:

- ACCOUNT GROUPING
  - `STATE ACCOUNT (A)` (Terraform state S3, Route53 hosted zone, Secrets Manager)
  - `DEPLOYMENT ACCOUNT (B)` (EKS, ALB, S3, Secrets Manager, workloads)

- REGION GROUPING
  - `REGION: <aws-region>` (all resources in the deployment region)

- VPC GROUPING
  - `VPC: <vpc-name>`
    - `PUBLIC SUBNETS` (ALB, IGW route)
    - `PRIVATE SUBNETS` (EKS data plane)

- EKS GROUPING
  - `EKS CLUSTER: <cluster-name>`
    - `NAMESPACE: argocd`
    - OpenLDAP stack namespaces (e.g. openldap, phpldapadmin, ltb-passwd)
    - `NAMESPACE: ldap-2fa-backend`, `NAMESPACE: ldap-2fa-frontend` (2FA app)

- CONTRACT GROUPING
  - `TERRAFORM STATE (S3)` (cross-layer outputs consumed via remote state)
  - `SECRETS MANAGER` (credentials, e.g. `github-role`, app secrets)

In `generated-python.py`, implement a single palette dict and apply it uniformly:

```python
TIER_COLORS = {
    "EDGE_DNS": "#E3F2FD",
    "INGRESS": "#E8EAF6",
    "NETWORK": "#E0F7FA",
    "COMPUTE": "#E8F5E9",
    "PLATFORM": "#F3E5F5",
    "DATA": "#FFF3E0",
    "STORAGE": "#FFF8E1",
    "SECURITY_CONFIG": "#FFEBEE",
    "OBSERVABILITY": "#ECEFF1",
}

def cluster_attrs(bg: str) -> dict:
    return {"style": "filled", "color": bg}
```

## COMMON AWS ICON IMPORTS

Use AWS node classes from the `diagrams` library as the only source of icon imports.
Validate node class names against the library's official node reference before
emitting code.

Minimal import set for this project:

```python
from diagrams import Cluster, Diagram, Edge

# EDGE / DNS / CERTS
from diagrams.aws.network import Route53, Route53HostedZone
from diagrams.aws.security import CertificateManager

# NETWORKING
from diagrams.aws.network import (
    VPC,
    InternetGateway,
    NATGateway,
    PublicSubnet,
    PrivateSubnet,
    RouteTable,
    VPCRouter,
    VPCGatewayEndpoint,
    VPCInterfaceEndpoint,
)

# INGRESS
from diagrams.aws.network import ELBApplicationLoadBalancer

# COMPUTE / ORCHESTRATION
from diagrams.aws.compute import EKS

# DATA (in-cluster PostgreSQL/Redis; use generic or RDS icon for DB)
from diagrams.aws.database import RDSPostgresqlInstance

# STORAGE
from diagrams.aws.storage import S3, EBS

# 2FA / MESSAGING (SMS, Email)
# from diagrams.aws.mobile import SNS  # if available
# from diagrams.aws.engagement import SES  # if available; else use generic node

# SECURITY / CONFIG
from diagrams.aws.security import IAMRole, KMS, SecretsManager

# OBSERVABILITY (OPTIONAL, WHEN USED IN DIAGRAMS)
from diagrams.aws.management import Cloudwatch
```

If a required service has no AWS node class in the library, use a `diagrams.generic`
node for that specific element only and label it explicitly
(for example: "ARGOCD (IN-CLUSTER)").

## DRAW.IO STYLE GUIDE (CONSISTENCY RULES)

- Use container grouping:

  - Outer containers for AWS accounts (Account A, Account B)
  - Nested container for VPC, then subnets, then EKS cluster
  - Nested containers for Kubernetes namespaces (e.g., `ldap`, `2fa-app`, `argocd`)
- Use a small, stable set of shapes:

  - Rectangles for services/resources
  - Rounded rectangles for workloads (Deployments/StatefulSets)
  - Cylinders for datastores (PostgreSQL, Redis)
  - Cloud icon or labeled box for AWS managed services (SNS, SES, Route53, ACM)
- Use consistent labels:

  - `Ingress (host/path)` for routing rules
  - `Service (ClusterIP)` for internal services
  - `Deployment`, `StatefulSet`, `PVC` for K8s primitives
- Keep text concise; prefer short labels + callouts for details.
- Avoid line crossings; use orthogonal connectors.
- For critical invariants, add a callout box titled `INVARIANT`.

## EXCLUSIONS (DO NOT INCLUDE)

- Do not include Terraform implementation minutiae (every variable/output).
- Do not include full CI YAML step listings; only represent pipeline stages.
- Do not include AWS resource ARNs, secret names/values, or ExternalId values.
- Do not represent multiple ALBs unless the repo explicitly provisions more than
one.

## VALIDATION CHECKLIST (MUST PASS BEFORE FINAL OUTPUT)

- Each diagram generation produces 3 files:

  1. **PNG** - Static image for documentation/presentations
  2. **DOT** - GraphViz source (text format, can be version controlled)
  3. **DRAWIO** - Editable diagram for manual refinement

- LDAP service is never drawn as internet-exposed (application_infra and
  high-level diagrams).
- Single ALB is shown and all public endpoints (phpldapadmin, passwd, app) route
  through it.
- `app.<domain>` is shown with `/` and `/api/*` path routing (application layer).
- Cross-account trust is explicit (A -> B assume-role with ExternalId) where
  relevant.
- SMS path shows backend -> SNS -> phone; sandbox/spend limits as callouts if
  included.
- All diagrams are readable at 100% zoom (no dense node packing).

## TROUBLESHOOTING

- GRAPHVIZ NOT FOUND OR DOT RENDER FAILS
  - Ensure Graphviz is installed and `dot` is on PATH.
  - Verify the script can write to `docs/architecture-diagrams/diagrams/`.

- IMPORT ERRORS (MISSING NODE CLASSES)
  - Validate the exact node class name and module path against the diagrams node
  reference.
  - Prefer alias classes when available (for example, `EKS` alias for `ElasticKubernetesService`).

- DRAW.IO CONVERSION FAILS
  - Ensure the converter tool is installed and supports the generated DOT syntax.
  - Keep DOT output deterministic (no random IDs, stable node keys) to reduce diff
  noise.

- DIAGRAM TOO DENSE / UNREADABLE
  - Split into multiple views.
  - Collapse low-level resources into service-level nodes.
  - Prefer one VPC-level diagram and one workload-level diagram over a single monolith.

## OUTPUT FILES

During the run, write all diagram artifacts under the **working copy** at
`/tmp/ldap-2fa-on-k8s/docs/architecture-diagrams/diagrams/` (one `.dot`, `.png`,
and `.drawio` per diagram name). The only generated source file is
`/tmp/ldap-2fa-on-k8s/docs/architecture-diagrams/generated-python.py`. In the
final step, copy `generated-python.py` and the contents of `diagrams/` from the
working copy into the repository at `docs/architecture-diagrams/` and
`docs/architecture-diagrams/diagrams/`, then delete `/tmp/ldap-2fa-on-k8s/`.

## KEY PRINCIPLES

- **Source of truth:** Terraform plan/state JSON for infrastructure topology;
  repo docs (e.g. `docs/architecture/ARCHITECTURE.md`) for intent and non-IaC
  runtime components.
- **Reproducibility:** Deterministic output (stable ordering, naming, paths);
  regeneration produces minimal diffs when topology is unchanged.
- **Readability over completeness:** Prefer clear service-level diagrams;
  include low-level resources only when they affect threat model or traffic path.
