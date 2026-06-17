# ProjectX — per-service stacks

Each AWS service lives in its own independent Terraform stack with its own local
state, so you can create/destroy them one at a time for fine-grained cost
control. Every stack has the same four scripts:

```
up.ps1   down.ps1   up.sh   down.sh
```

`up` runs `terraform apply`; `down` runs `terraform destroy` (the `app` and
`addons` stacks are script-only and use docker/helm/kubectl instead).

## Stacks & dependencies

Dependencies are read across stacks via `terraform_remote_state` (each stack
reads the local `terraform.tfstate` of the stacks it depends on).

| Stack | What it creates | Depends on | Cost |
|---|---|---|---|
| `vpc` | VPC, subnets, IGW, route tables (no NAT) | — | free |
| `ecr` | Container image registry | — | free (<500 MB) |
| `rds-sg` | Security group for the DB | `vpc` | free |
| `rds` | RDS PostgreSQL 16 (`db.t3.micro`) | `vpc`, `rds-sg` | free-tier |
| `iam` | Dev/QA/Prod roles, groups, users | — | free |
| `nat` | NAT Gateway + EIP + private routes | `vpc` | **~$33/mo** |
| `eks` | EKS control plane + node group | `vpc` (+`nat` to pull images) | **~$73/mo + nodes** |
| `irsa` | IRSA roles (LB controller, autoscaler) | `eks` | free |
| `bastion` | t3.micro SSH bastion for DBeaver | `vpc` | free-tier |
| `github-oidc` | GitHub Actions OIDC + CI role | `ecr` | free |
| `addons` | metrics-server, ALB controller, autoscaler, Argo CD | `eks`, `irsa` | free (drives ALB) |
| `app` | build+push image, deploy app (Helm) | `ecr`, `eks`, `rds` | ALB ~$18/mo |

## Bring up everything (dependency order)

```powershell
# Windows
.\up-all.ps1
```
```bash
# Linux/macOS
./up-all.sh
```

Order: `vpc -> ecr -> rds-sg -> rds -> nat -> eks -> irsa -> addons -> app`.
(`iam`, `bastion`, `github-oidc` are optional — run their own `up` script.)

## Tear down

```powershell
.\down-all.ps1          # COST-SAVING: removes app/addons/irsa/eks/nat/bastion, keeps free layer
.\down-all.ps1 -All     # destroy everything
```
```bash
./down-all.sh           # cost-saving
ALL=true ./down-all.sh  # destroy everything
```

## Single service

```powershell
cd stacks\eks ;  .\up.ps1     # create just EKS (vpc must already be up)
cd stacks\eks ;  .\down.ps1   # destroy just EKS
```

## Notes
- The `iam` stack was migrated here from `terraform/iam` **with its existing
  state**, so your already-created IAM users/roles are preserved.
- `bastion` writes its private key to `stacks/bastion/bastion-key.pem`
  (gitignored) for use as the DBeaver SSH identity.
