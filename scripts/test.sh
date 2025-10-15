# Try to pull it locally
docker pull rsobingusi.azurecr.io/svc-courses:dev

# List repos & tags from ACR
az acr repository list -n rsobingusi -o table
az acr repository show-tags -n rsobingusi --repository svc-courses -o table