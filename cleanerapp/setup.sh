echo "Setting up kubectl..."
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.24.9/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/bin/kubectl
echo "Setting up kubectl completed."

echo "Setting up jq..."
apk --no-cache add jq
echo "Setting up jq completed."

echo "az login..."
az login --service-principal -u AzureSPNAppId -p AzureSPNAppPwd --tenant AzureTenantId
az account set --subscription "AzureSubscriptionId"

echo "Setup AKS credentials..."
az aks get-credentials -n aks-chdemo-dev04 -g rg-chdemo-dev04 --admin
echo "Setup completed."