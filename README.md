# ProjectX — Production-style EKS platform (POC)

A one-click, fully reproducible AWS environment that deploys a Python form-filling
app on **Amazon EKS**, behind an **ALB**, with **HPA (1→3 pods)** and **Cluster
Autoscaler (1→3 nodes)** so you can run load tests and watch it autoscale — then
tear **everything** down with a single command.

Built per the AWS Well-Architected Framework, adapted for a credits-friendly POC.

---

## Architecture

```
                Internet
                   │
            ┌──────▼───────┐
            │  ALB (HTTP)  │  ← AWS Load Balancer Controller (Ingress)
            └──────┬───────┘
        ┌──────────▼───────────┐   VPC 10.20.0.0/16 (2 AZs, 1 NAT)
        │  EKS managed nodes    │   private subnets
        │  ProjectX pods (HPA)  │──► RDS PostgreSQL (private, encrypted)
        │  + metrics-server     │
        │  + cluster-autoscaler │
        │  + Argo CD            │
        └──────────┬───────────┘
                   │ pulls image
            ┌──────▼───────┐
            │     ECR      │
            └──────────────┘
```

| Layer | Choice | Why |
|---|---|---|
| Region | `ap-south-1` | Per request |
| State | **Local** (POC) | Clean, complete teardown; `terraform/bootstrap` provides S3+DynamoDB for teams |
| Compute | EKS managed node group `t3.medium` ×2 (max 3) | Simple to manage |
| Pod scaling | HPA, CPU 50%, **min 1 / max 3** | Per request |
| Node scaling | Cluster Autoscaler **1 → 3** | Easier than Karpenter |
| DB | RDS PostgreSQL `db.t3.micro` | Free-tier eligible |
| GitOps | Argo CD | Per request |
| CI/CD | GitHub Actions + OIDC | Per request |

---

## Prerequisites

Install and configure these locally:

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) — run `aws configure` (or SSO) for an account with admin-ish rights
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) ≥ 3
- [Docker](https://docs.docker.com/get-docker/) (running)

Verify: `aws sts get-caller-identity`

---

## One-click UP

**Windows (PowerShell):**

```powershell
./scripts/up.ps1
```

**Linux / macOS:**

```bash
chmod +x scripts/*.sh
./scripts/up.sh
```

This provisions all infra, installs add-ons, builds & pushes the image, deploys
the app, and prints the public URL (~15–20 min on first run, mostly EKS).

Open the printed `http://<alb-dns>` to use the form.

---

## Load test → watch autoscaling

In one terminal:

```bash
kubectl -n projectx get hpa,pods -w
```

In another:

```powershell
./scripts/load-test.ps1 -Url http://<alb-dns> -Concurrency 50 -Seconds 180
```
```bash
./scripts/load-test.sh http://<alb-dns> 50 180
```

The `/load` endpoint burns CPU, HPA scales pods 1→3, and if pods can't be
placed, Cluster Autoscaler adds nodes (up to 3).

---

## One-click DOWN (deletes everything)

```powershell
./scripts/down.ps1            # add -Force to skip the prompt
```
```bash
./scripts/down.sh             # FORCE=true ./scripts/down.sh to skip prompt
```

Teardown order is deliberate: the app/Ingress is removed first so the ALB +
ENIs are released **before** `terraform destroy`, avoiding the classic stuck-VPC
problem. After it finishes, glance at the console to confirm no ALB/EIP/ENI is
left.

> 💡 Cost tip: EKS control plane (~$0.10/hr) + NAT + ALB + nodes accrue while UP.
> Run `down` whenever you're not actively testing.

---

## App endpoints

| Path | Purpose |
|---|---|
| `GET /` | HTML form |
| `POST /submit` | Save submission to PostgreSQL |
| `GET /api/submissions` | List recent submissions |
| `GET /load?ms=200` | CPU burner for load testing |
| `GET /healthz` / `GET /readyz` | Liveness / readiness probes |

---

## CI/CD (optional)

1. Set `enable_github_oidc = true` and `github_repo = "owner/ProjectX"` in
   `terraform/envs/dev/terraform.tfvars`, then re-run `up` (or `terraform apply`).
2. Copy the `github_ci_role_arn` output into a GitHub repo secret `AWS_ROLE_ARN`.
3. Grant that role cluster access so `app.yml` can deploy:
   ```bash
   aws eks create-access-entry --cluster-name projectx-dev-eks \
     --principal-arn <github_ci_role_arn> --region ap-south-1
   aws eks associate-access-policy --cluster-name projectx-dev-eks \
     --principal-arn <github_ci_role_arn> --region ap-south-1 \
     --access-scope type=cluster \
     --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy
   ```
4. Push to `main` → `infra.yml` runs Terraform, `app.yml` builds & deploys.

## Argo CD (optional GitOps)

`up` installs Argo CD. To manage the app via Git instead of Helm:
edit `argocd/application.yaml` (repoURL + ECR image), then
`kubectl apply -f argocd/application.yaml`. Get the admin password with the
command printed at the end of `up`.

---

## IAM identities (dev / qa / prod)

Account-global IAM lives in `terraform/iam/` and is **applied separately** from the
env infra so `down.ps1` never deletes your users, groups, or roles.

Pattern: **groups define who you are, roles define what you can do, MFA gates the
elevation.** Members sit in a group, the group grants permission to assume only its
matching tier role, and the role carries the actual permissions.

| Tier | Group | Role | Permissions |
|---|---|---|---|
| dev | `projectx-dev` | `projectx-dev` | ECR push/pull, EKS access, read logs/metrics |
| qa | `projectx-qa` | `projectx-qa` | ECR pull, EKS describe, read-only |
| prod | `projectx-prod` | `projectx-prod` | PowerUser (all except IAM/Orgs) + IAM read |

All groups also get an **MFA self-service baseline** that lets users manage their own
credentials/MFA and (with `require_mfa=true`) denies everything else until MFA is used.

Apply it (run as your `Admin` user):

```powershell
terraform -chdir=terraform/iam init
terraform -chdir=terraform/iam apply
```

To also create the users, edit `terraform/iam/terraform.tfvars`:

```hcl
create_users = true
dev_users    = ["dev.alice"]
qa_users     = ["qa.carol"]
prod_users   = ["ops.dave"]
```

Created users have **no console password** by design — set one in the IAM console (or
hand out the `switch_role_urls` output so they can switch into their tier role).

> EKS uses its own RBAC. For dev/qa to run `kubectl`, grant their role cluster access:
> ```bash
> aws eks create-access-entry --cluster-name projectx-dev-eks --region ap-south-1 \
>   --principal-arn <role_arn from terraform output>
> aws eks associate-access-policy --cluster-name projectx-dev-eks --region ap-south-1 \
>   --principal-arn <role_arn> --access-scope type=cluster \
>   --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy
> ```

---

## Layout

```
app/                 Flask app + Dockerfile
helm/projectx/       App Helm chart (Deployment, Service, Ingress, HPA, PDB)
terraform/
  envs/dev/          Root module: VPC, EKS, ECR, RDS, IRSA (local state)
  iam/               Account IAM: dev/qa/prod groups, roles, policies, users
  modules/github-oidc/  GitHub Actions OIDC role
  bootstrap/         Optional S3+DynamoDB remote state
argocd/              Argo CD Application (GitOps)
scripts/             up / down / load-test (PowerShell + bash)
.github/workflows/   CI/CD pipelines
```

## Security notes

- Nodes & RDS live in **private subnets**; RDS only reachable from inside the VPC.
- IRSA gives least-privilege IAM to the LB controller & autoscaler (no node creds).
- Encryption at rest on ECR, RDS, EBS; TLS-capable ALB (add an ACM cert for HTTPS).
- For production: restrict `cluster_public_access_cidrs` to your IP, enable RDS
  Multi-AZ, add WAF/GuardDuty/Config, and switch to the S3 state backend.
