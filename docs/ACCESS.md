# ProjectX — Accessing every service from your local machine

All commands are PowerShell (Windows). Run them from the repo root
(`c:\Users\HIRESH-053\vs-code\ProjectX`).

> If a new terminal can't find `aws`/`terraform`/`kubectl`/`helm`, close and
> reopen it (PATH refresh), or restart your shell after installing tools.

---

## 0. One-time: point kubectl at the cluster

```powershell
aws eks update-kubeconfig --name projectx-dev-eks --region ap-south-1
kubectl config current-context
```

Grab the values other steps use:

```powershell
$ALB     = kubectl -n projectx get ingress projectx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
$DB_HOST = terraform -chdir="terraform/envs/dev" output -raw db_host
$DB_PASS = terraform -chdir="terraform/envs/dev" output -raw db_password
"App URL : http://$ALB"
"DB host : $DB_HOST"
```

---

## 1. Quick health of everything

```powershell
./scripts/status.ps1
```

---

## 2. The App (public, via ALB)

```powershell
# Open the form in a browser
Start-Process "http://$ALB"

# Health + readiness
curl.exe "http://$ALB/healthz"
curl.exe "http://$ALB/readyz"

# Submit the form via API (also writes to PostgreSQL).
# Use Invoke-RestMethod in PowerShell (curl.exe mangles JSON quoting on Windows).
$body = @{ name = "Ada"; email = "ada@example.com"; message = "hi" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://$ALB/submit" -Method Post -ContentType "application/json" -Body $body

# Read submissions back (proves DB connectivity end-to-end)
Invoke-RestMethod -Uri "http://$ALB/api/submissions"

# CPU burn endpoint (used for load testing / autoscaling)
curl.exe "http://$ALB/load?ms=300"
```

---

## 3. The App pods (kubectl)

```powershell
# List app pods
kubectl -n projectx get pods -o wide

# Live logs (all pods)
kubectl -n projectx logs -l app.kubernetes.io/name=projectx -f --all-containers

# Shell INTO a running app pod
$POD = kubectl -n projectx get pod -l app.kubernetes.io/name=projectx -o jsonpath='{.items[0].metadata.name}'
kubectl -n projectx exec -it $POD -- sh

# Port-forward the app to your laptop (no ALB needed) -> http://localhost:8080
kubectl -n projectx port-forward deploy/projectx 8080:8080
```

---

## 4. Watch autoscaling (HPA + Cluster Autoscaler)

```powershell
# Pod scaling 1 -> 3
kubectl -n projectx get hpa,pods -w

# Per-pod / per-node resource usage (needs metrics-server, already installed)
kubectl top pods -n projectx
kubectl top nodes

# Cluster Autoscaler logs (node scaling)
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-cluster-autoscaler -f
```

Generate load in another terminal:

```powershell
./scripts/load-test.ps1 -Url "http://$ALB" -Concurrency 50 -Seconds 180
```

---

## 5. PostgreSQL (RDS) — it lives in a PRIVATE subnet

RDS is **not** reachable directly from your laptop (private subnet, by design).
Use one of these.

### 5a. Quick psql session from inside the cluster

```powershell
$DB_HOST = terraform -chdir="terraform/envs/dev" output -raw db_host
$DB_PASS = terraform -chdir="terraform/envs/dev" output -raw db_password

kubectl run pgcli --rm -it --restart=Never -n projectx `
  --image=postgres:16 `
  --env="PGPASSWORD=$DB_PASS" `
  -- psql -h $DB_HOST -U projectx -d projectx
```

Then run SQL, e.g.:

```sql
\dt
SELECT * FROM submissions ORDER BY id DESC LIMIT 10;
\q
```

### 5b. Use psql / DBeaver on your laptop (localhost:5432)

Run a tiny relay pod, then port-forward it so RDS appears on `localhost:5432`:

```powershell
$DB_HOST = terraform -chdir="terraform/envs/dev" output -raw db_host

# Start a socat relay pod -> RDS:5432
kubectl -n projectx run rds-relay --image=alpine/socat --restart=Never `
  -- tcp-listen:5432,fork,reuseaddr "tcp-connect:$($DB_HOST):5432"
kubectl -n projectx wait --for=condition=ready pod/rds-relay --timeout=60s

# Forward it to your machine (keep this window open)
kubectl -n projectx port-forward pod/rds-relay 5432:5432
```

Now connect locally (new terminal). Get the password with
`terraform -chdir="terraform/envs/dev" output -raw db_password`:

```
Host: localhost   Port: 5432   DB: projectx   User: projectx
```

Clean up the relay when done:

```powershell
kubectl -n projectx delete pod rds-relay
```

### 5c. DBeaver via SSH bastion (works even when EKS/compute is DOWN)

Method 5b needs a running cluster. If you've done a cost-saving `down.ps1`
(EKS gone, RDS still up), use the free-tier SSH bastion instead:

```powershell
# Creates a t3.micro bastion, locks SSH to your current IP, generates a key,
# and prints the exact DBeaver settings (Main + SSH tabs).
.\scripts\db-bastion.ps1
```

In DBeaver → **New Connection → PostgreSQL**:

- **Main tab:** Host = the RDS endpoint, Port `5432`, Database `projectx`,
  User `projectx`, Password = `terraform -chdir="terraform/envs/dev" output -raw db_password`.
- **SSH tab:** tick *Use SSH Tunnel*, Host = bastion public IP, Port `22`,
  User `ec2-user`, Auth = *Public Key*, Private Key = `terraform/envs/dev/bastion-key.pem`.

DBeaver tunnels through the bastion into the VPC and reaches the private RDS.
Remove the bastion when finished (RDS + free layer stay intact):

```powershell
.\scripts\db-bastion.ps1 -Down
```

---

## 6. Argo CD (GitOps UI)

```powershell
# Admin password
$enc = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($enc))

# Open the UI (keep window open) -> https://localhost:8081  (user: admin)
kubectl -n argocd port-forward svc/argocd-server 8081:443
```

---

## 7. ECR (container images)

```powershell
aws ecr describe-images --repository-name projectx/app --region ap-south-1 `
  --query "sort_by(imageDetails,&imagePushedAt)[].{tag:imageTags[0],pushed:imagePushedAt}" --output table
```

---

## 8. Raw EKS / cluster info

```powershell
kubectl get nodes -o wide
kubectl get pods -A
kubectl -n kube-system get deploy        # add-ons
aws eks describe-cluster --name projectx-dev-eks --region ap-south-1 --query "cluster.status"
```
