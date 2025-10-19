# svc-courses

**NOTE: We don’t accept external contributions; this is a class project. PRs from non-members will be closed.**

Minimal **Courses** microservice (Node/Express + Postgres) for:
- building & pushing images to **Azure Container Registry (ACR)**
- creating/running **Azure Kubernetes Service (AKS)**
- deploying with DB and verifying using cluster‑local tests

---

## Tech stack
Node.js (Express), PostgreSQL 16, Docker/Compose, Azure CLI (ACR/AKS), NGINX Ingress, Prisma.

---

## Repo layout
```
k8s/                # namespace, service, deployment, ingress, placeholder secret
prisma/             # schema + migrations
scripts/
  acr/              # ACR env + build & push
  aks/              # AKS create/start/stop/scale + deploy-with-db-test.sh
  db/               # Azure Postgres settings + secret helper
Dockerfile          # app image
docker-compose.yml  # local dev: app + db (+ pgadmin)
app.js              # Express API (endpoints)
```

---

## Prereqs
- Docker Desktop/Engine
- Bash (Git Bash/WSL/macOS/Linux)
- Azure CLI (`az login --use-device-code`)

---

## Local dev (Compose)
```bash
cp .env.example .env
docker compose up --build -d
```

---

## ACR: build & push
1) Configure ACR env:
```bash
cp scripts/acr/example-azure.env scripts/acr/azure.env
```
2) Build & push (uses Buildx; defaults to **linux/arm64** to match AKS nodepool):
```bash
./scripts/acr/push-local-docker.sh
```
3) Tagging strategy (built into the script):
- Pushes the chosen tag (e.g. `dev`) **and** a timestamp tag (e.g. `dev-YYYYMMDDHHMMSS`).
- Prints an immutable **digest**. You can pin the Deployment to that digest:
  ```yaml
  image: <loginServer>/svc-courses@sha256:<digest>
  ```
---

## AKS workflow
1) Configure AKS env:
```bash
cp scripts/aks/example-aks.env scripts/aks/aks.env
```
2) Create / fetch kubeconfig:
```bash
./scripts/aks/aks-create.sh
```
3) Install/ensure NGINX ingress:
```bash
./scripts/aks/ingress-install.sh
```


### Database secret (Azure Postgres + Prisma)

1) Configure DB env:
```bash
cp scripts/db/example-db.env scripts/db/db.env
```

2) Create/refresh the Kubernetes Secret (`DATABASE_URL` is built for you):
```bash
./scripts/db/db-secret.sh
```

3) **Apply Prisma migrations** to the DB (optional but recommended on first deploy / when schema changes):
```bash
./scripts/db/db-migrate-deploy.sh     # uses DATABASE_URL to run `prisma migrate deploy`
```

### Deploy + cluster-local tests
Apply manifests, wait for rollout, then test **inside the cluster** (no reliance on home network):
```bash
./scripts/aks/deploy-with-db-test.sh
```
It verifies:
- `GET /healthz` and `GET /api/courses` via the Service DNS
- the same two calls via the Ingress controller **service**

---

## Cost tips
```bash
# Most savings come from scaling AKS to 1 node or stopping AKS and stopping the DB.

./scripts/aks/aks-scale.sh ./scripts/aks/aks.env 1   # cheap dev (scale back to 2 for demos)
./scripts/aks/aks-stop.sh                            # stop cluster VMs (pause compute)
./scripts/aks/aks-start.sh                           # start cluster VMs again

./scripts/db/db-stop.sh      # stop DB server (compute paused; storage still billed)
./scripts/db/db-start.sh     # start DB server
# Note: a stopped Flexible Server auto-starts after 7 days (Azure policy).
```

---
