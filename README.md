# svc-courses

A minimal **Courses** microservice (Express + Postgres) to:
- build & push images to **Azure Container Registry (ACR)**
- create/start/stop/test an **Azure Kubernetes Service (AKS)** cluster

---

## Table of contents
1. [Tech stack](#tech-stack)  
2. [Repo structure](#repo-structure)  
3. [Prerequisites](#prerequisites)  
4. [Local development (Docker Compose)](#local-development-docker-compose)  
5. [ACR: build & push image](#acr-build--push-image)  
6. [AKS: create / start / stop / test](#aks-create--start--stop--test)  
7. [Saving credits](#saving-credits) 

---

## Tech stack
- **Node.js / Express** (ESM)
- **PostgreSQL 16** (Docker)
- **Docker & Docker Compose**
- **Azure CLI** (ACR/AKS)
- **pgAdmin** (UI to inspect the DB)

---

## Repo structure
```
svc-courses/
├─ app.js                     # Express API (courses + lectures)
├─ Dockerfile                 # App image
├─ docker-compose.yml         # Local dev: db + app (+ pgadmin)
├─ package.json / package-lock.json
├─ .env.example               # local compose env template
├─ scripts/
│  ├─ acr/
│  │  ├─ example-azure.env    # template for ACR settings
│  │  ├─ azure.env            # (ignored) real ACR env
│  │  ├─ push-local-docker.sh # build & push image to ACR
│  │  └─ test-registry.sh     # verify ACR repo/tags and pulling
│  └─ aks/
│     ├─ example-aks.env      # template for AKS settings
│     ├─ aks.env              # (ignored) real AKS env
│     ├─ aks-create.sh        # idempotent create & kubeconfig
│     ├─ aks-start.sh         # start cluster (resumes nodes)
│     ├─ aks-stop.sh          # stop cluster (saves credits)
│     ├─ aks-scale.sh         # scale workers up/down (1-2 nodes)
│     └─ test-aks.sh          # show state/details; nodes if running
└─ README.md
```

---

## Prerequisites
- **Docker Desktop** (or Docker Engine)  
- **Git Bash / WSL / Linux / macOS** (bash to run scripts)  
- **Azure CLI** (for ACR/AKS):  
  - Install: <https://learn.microsoft.com/cli/azure/install-azure-cli>  
  - Login: `az login --use-device-code`

---

## Local development (Docker Compose)

Copy env template and start:
```bash
cp .env.example .env
docker compose up --build -d
```
---

## ACR: build & push image

1) Prepare env:
```bash
cp scripts/acr/example-azure.env scripts/acr/azure.env
```

2) Log in to Azure:
```bash
az login --use-device-code
```

3) Build and push:
```bash
./scripts/acr/push-local-docker.sh
```

4) Verify registry:
```bash
./scripts/acr/test-registry.sh
```

This will:
- ensure the **Resource Group** & **ACR** exist
- build `rsobingusi.azurecr.io/svc-courses:dev`
- push it to your ACR
- list repos/tags and try a pull

---

## AKS: create / start / stop / test

1) Prepare env:
```bash
cp scripts/aks/example-aks.env scripts/aks/aks.env
```

2) Create cluster and fetch kubeconfig:
```bash
./scripts/aks/aks-create.sh
```

3) Check status:
```bash
./scripts/aks/test-aks.sh
```

4) Start/Stop to control spend:
```bash
./scripts/aks/aks-start.sh
./scripts/aks/aks-stop.sh
```

5) Scale workers quickly:
```bash
# develop cheaply on 1 node
./scripts/aks/aks-scale.sh ./scripts/aks/aks.env 1

# before demo scale to 2 nodes
./scripts/aks/aks-scale.sh ./scripts/aks/aks.env 2
```

---

## Saving credits
- **AKS nodes** (the VM(s)) are the main cost. Use:
  - `./scripts/aks/aks-stop.sh` when you’re done
  - `./scripts/aks/aks-start.sh` when you need it again
  - `./scripts/aks/aks-scale.sh ./scripts/aks/aks.env 1` during development, then 2 before demos.

---