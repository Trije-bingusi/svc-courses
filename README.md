# svc-courses

> **Note:** We don’t accept external contributions; this is a class project. PRs from non-members will be closed.

Minimal **Courses** microservice (Node/Express + Postgres) for:
- building & pushing images to **Azure Container Registry (ACR)**
- creating/running **Azure Kubernetes Service (AKS)**
- deploying with DB and verifying using cluster‑local tests

## Tech stack
Node.js (Express), PostgreSQL 16, Docker/Compose, Azure CLI, NGINX Ingress, Prisma, Helm.


## Repo layout
```sh
helm/               # helm chart for deploying to AKS
  templates/        # k8s manifests (Deployment, Service, Ingress, etc.)
  values.yaml       # default chart values
prisma/             # schema + migrations
scripts/
  deploy/           # building and deploying the app
  utils/            # utility scripts for fetching config and auth to AKS
src/                # App source
  app.js            # Express API (endpoints)
Dockerfile          # app image
docker-compose.yml  # local dev: app + db (+ pgadmin)
```


## Prerequisites
- Docker Desktop/Engine
- Bash (Git Bash/WSL/macOS/Linux)
- Azure CLI (`az login --use-device-code`). Ensure the correct subscription is selected using `az account set --subscription "your-subscription-id"`.


## Local Development
The service can be run locally using Docker Compose.
```bash
cp .env.example .env  # Edit the .env if needed
docker compose up --build -d
```


## Buld and Deploy to AKS

First, make sure the correct `KEYVAULT_NAME` and `K8S_NAMESPACE` from the [shared-infractructure](https://github.com/Trije-bingusi/shared-infrastructure) repo is set in the [`./scripts/.env`](./scripts/.env) file. Set other variables as needed.

To package the app as a Docker image and push it to ACR, use the [`./scripts/deploy/build.sh`](./scripts/deploy/build.sh) script.
```sh
./scripts/deploy/build.sh
```
Upon success, the image will be pushed to ACR and the immutable image tag printed. Use this tag to deplot to the AKS cluster using the [`./scripts/deploy/deploy.sh`](./scripts/deploy/deploy.sh) script:
```sh
./scripts/deploy/deploy.sh <image-tag>
```



## Testing

> **TODO:** Set up a testing framework and add implement tests.
