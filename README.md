## Quick start
```cp .env.example .env```

```docker compose up --build -d```

## Push image to ACR

- [Install Azure CLI.](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&pivots=msi-powershell)
- Make sure you are logged in. In PowerShell:
```az login --use-device-code```

Then you can run:

```cp scripts/example-azure.env scripts/azure.env```

```./scripts/push-local-docker.sh```

```./scripts/test.sh```