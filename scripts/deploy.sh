#!/bin/bash
set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check required variables
: ${AZURE_WEBAPP_NAME:?Please set AZURE_WEBAPP_NAME}
: ${AZURE_RESOURCE_GROUP:?Please set AZURE_RESOURCE_GROUP}

echo "Building and deploying to Azure App Service: $AZURE_WEBAPP_NAME"

# Build image
docker build -t $AZURE_WEBAPP_NAME:latest .

# Tag for Azure Container Registry (if using ACR)
# docker tag $AZURE_WEBAPP_NAME:latest your-registry.azurecr.io/$AZURE_WEBAPP_NAME:latest

# Push to registry (GitHub Container Registry or ACR)
echo "Note: This script expects you're using GitHub Actions for deployment"
echo "For manual deployment, push to your container registry and update the App Service"

# Configure App Service
az webapp config appsettings set \
    --resource-group $AZURE_RESOURCE_GROUP \
    --name $AZURE_WEBAPP_NAME \
    --settings \
        WEBSITES_PORT=4318 \
        AZURE_MONITOR_ENDPOINT="$AZURE_MONITOR_ENDPOINT" \
        APPLICATIONINSIGHTS_CONNECTION_STRING="$APPLICATIONINSIGHTS_CONNECTION_STRING"

echo "✓ Deployment configuration updated"
echo "Push to main branch to trigger GitHub Actions deployment"
