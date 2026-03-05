#!/usr/bin/env python3
"""
Generate unified architecture diagram for ldap-2fa-on-k8s.
Outputs: diagrams/ldap_2fa_unified.png, .dot, .drawio.
Run from docs/architecture-diagrams/ with venv activated.
"""

import os
import subprocess
import sys

# Ensure we run from script directory so paths resolve
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
os.chdir(SCRIPT_DIR)

OUTPUT_DIR = "diagrams"
DIAGRAM_NAME = "ldap_2fa_unified"

# Tier colors per AGENT.md (AWS-style)
TIER_EDGE_DNS = "#E3F2FD"
TIER_INGRESS = "#E8EAF6"
TIER_NETWORK = "#E0F7FA"
TIER_COMPUTE = "#E8F5E9"
TIER_PLATFORM = "#F3E5F5"
TIER_DATA = "#FFF3E0"
TIER_STORAGE = "#FFF8E1"
TIER_SECURITY = "#FFEBEE"
TIER_OBSERVABILITY = "#ECEFF1"


def main() -> None:
    from diagrams import Cluster, Diagram, Edge
    from diagrams.aws.compute import EKS, EC2ContainerRegistry, EC2Instance
    from diagrams.aws.database import RDSPostgresqlInstance, ElasticacheForRedis
    from diagrams.aws.engagement import SimpleEmailServiceSes
    from diagrams.aws.general import Client, User
    from diagrams.aws.integration import SimpleNotificationServiceSns
    from diagrams.aws.network import (
        ElbApplicationLoadBalancer,
        InternetGateway,
        NATGateway,
        Route53,
        Route53HostedZone,
    )
    from diagrams.aws.security import (
        CertificateManager,
        IdentityAndAccessManagementIamRole,
        SecretsManager,
    )
    from diagrams.aws.storage import S3

    graph_attr = {
        "splines": "ortho",
        "nodesep": "0.8",
        "ranksep": "1.2",
        "fontsize": "14",
        "bgcolor": "white",
        "pad": "0.5",
    }

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    diagram_path = os.path.join(OUTPUT_DIR, DIAGRAM_NAME)

    with Diagram(
        "LDAP 2FA on EKS - Unified Architecture",
        filename=diagram_path,
        direction="TB",
        outformat=["png", "dot"],
        show=False,
        graph_attr=graph_attr,
    ):
        users = User("Users")
        github = Client("GitHub Actions\n(OIDC)")

        # --- Account A (State) ---
        with Cluster(
            "Account A (State)",
            graph_attr={"style": "filled", "bgcolor": TIER_SECURITY, "penwidth": "2"},
        ):
            with Cluster(
                "DNS / TLS",
                graph_attr={"style": "filled", "bgcolor": TIER_EDGE_DNS},
            ):
                r53_zone = Route53HostedZone("Hosted Zone")
                r53 = Route53("Route53\nA/ALIAS records")
            with Cluster(
                "State & Secrets",
                graph_attr={"style": "filled", "bgcolor": TIER_STORAGE},
            ):
                s3_state = S3("Terraform State\n(S3)")
                secrets = SecretsManager("Secrets Manager")
            iam_github = IdentityAndAccessManagementIamRole("IAM Role\n(GitHub OIDC)")

        # --- Account B (Deployment) ---
        with Cluster(
            "Account B (Deployment)",
            graph_attr={"style": "filled", "bgcolor": TIER_COMPUTE, "penwidth": "2"},
        ):
            acm = CertificateManager("ACM Certificate\n(HTTPS)")
            ecr = EC2ContainerRegistry("ECR")

            with Cluster(
                "VPC",
                graph_attr={"style": "filled", "bgcolor": TIER_NETWORK},
            ):
                with Cluster(
                    "Public Subnets",
                    graph_attr={"style": "filled", "bgcolor": TIER_INGRESS},
                ):
                    igw = InternetGateway("IGW")
                    nat = NATGateway("NAT")
                    alb = ElbApplicationLoadBalancer("ALB\n(HTTPS 443)\nhost/path routing")
                with Cluster(
                    "Private Subnets",
                    graph_attr={"style": "filled", "bgcolor": TIER_COMPUTE},
                ):
                    with Cluster(
                        "EKS Auto Mode",
                        graph_attr={"style": "filled", "bgcolor": TIER_PLATFORM},
                    ):
                        eks = EKS("EKS Cluster")
                        with Cluster("OpenLDAP Stack\n(internal only)"):
                            openldap = EC2Instance("OpenLDAP\n(ClusterIP)")
                            phpldap = EC2Instance("phpLDAPadmin")
                            ltb = EC2Instance("LTB-passwd")
                        with Cluster("2FA App"):
                            frontend = EC2Instance("Frontend\n(path /)")
                            backend = EC2Instance("Backend\n(path /api)")
                        argocd = EC2Instance("ArgoCD\n(GitOps)")

            with Cluster(
                "Data & Messaging",
                graph_attr={"style": "filled", "bgcolor": TIER_DATA},
            ):
                postgres = RDSPostgresqlInstance("PostgreSQL")
                redis = ElasticacheForRedis("Redis")
                sns = SimpleNotificationServiceSns("SNS\n(SMS)")
                ses = SimpleEmailServiceSes("SES\n(Email)")

        # --- Data plane: Users -> Route53 -> ALB -> EKS ---
        users >> Edge(label="HTTPS") >> r53
        r53 >> Edge(label="A/ALIAS") >> alb
        alb >> Edge(label="phpldapadmin.<domain>") >> phpldap
        alb >> Edge(label="passwd.<domain>") >> ltb
        alb >> Edge(label="app.<domain>/") >> frontend
        alb >> Edge(label="app.<domain>/api/*") >> backend

        # Internal: backend -> LDAP (never internet)
        backend >> Edge(label="LDAP\n(internal)") >> openldap
        backend >> postgres
        backend >> redis
        backend >> sns
        backend >> ses

        # TLS at ALB; network path
        acm >> alb
        r53_zone >> r53
        igw >> alb
        nat >> eks

        # --- Control plane: GitHub -> Account A -> Account B ---
        github >> Edge(label="OIDC") >> iam_github
        iam_github >> Edge(label="assume-role\n+ ExternalId") >> eks
        iam_github >> s3_state
        iam_github >> r53_zone
        secrets >> iam_github

        # Terraform layer flow (logical)
        s3_state >> Edge(label="state") >> eks
        ecr >> eks
        argocd >> frontend
        argocd >> backend

    print("Diagram generation OK: %s.png, %s.dot" % (diagram_path, diagram_path))

    # Convert DOT to Draw.io
    dot_path = diagram_path + ".dot"
    drawio_path = diagram_path + ".drawio"
    if os.path.isfile(dot_path):
        try:
            subprocess.run(
                [
                    "graphviz2drawio",
                    dot_path,
                    "-o",
                    drawio_path,
                ],
                check=True,
                cwd=SCRIPT_DIR,
            )
            print("Draw.io conversion OK: %s" % drawio_path)
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            print("Warning: graphviz2drawio failed (%s). Install with: pip install graphviz2drawio" % e, file=sys.stderr)
    else:
        print("Warning: %s not found, skipping drawio conversion." % dot_path, file=sys.stderr)


if __name__ == "__main__":
    main()
