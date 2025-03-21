#!/bin/bash

# Variables
VAULT_ADDR="http://127.0.0.1:8200"  # Change to your Vault server
VAULT_TOKEN="root"  # Change to your Vault token or authenticate via VAULT CLI
AZURE_SUBSCRIPTION_ID="<AZURE_SUBSCRIPTION_ID>"  # Replace with your Azure Subscription ID
AZURE_TENANT_ID="<AZURE_TENANT_ID>"  # Replace with your Azure Tenant ID
AZURE_CLIENT_ID="<AZURE_CLIENT_ID>"  # Replace with your Azure Service Principal App ID
AZURE_CLIENT_SECRET="<AZURE_CLIENT_SECRET>"  # Replace with your Azure Service Principal Secret
VAULT_ROLE_NAME="azure-admin-role"
VAULT_POLICY_NAME="azure-admin-access"

# Export Vault Address and Token
export VAULT_ADDR VAULT_TOKEN

# Enable Azure secrets engine
vault secrets enable azure || echo "Azure secrets engine already enabled."

# Configure Azure credentials in Vault
vault write azure/config \
    subscription_id="$AZURE_SUBSCRIPTION_ID" \
    tenant_id="$AZURE_TENANT_ID" \
    client_id="$AZURE_CLIENT_ID" \
    client_secret="$AZURE_CLIENT_SECRET"

# Create a Vault role that generates temporary Azure admin credentials
vault write azure/roles/$VAULT_ROLE_NAME \
    ttl="24h" \
    azure_roles=-<<EOF
[
  {
    "role_name": "Owner",
    "scope": "/subscriptions/$AZURE_SUBSCRIPTION_ID"
  },
  {
    "role_name": "Contributor",
    "scope": "/subscriptions/$AZURE_SUBSCRIPTION_ID"
  }
]
EOF

# Create Vault policy for Azure admin access
cat <<EOF > $VAULT_POLICY_NAME.hcl
path "azure/creds/$VAULT_ROLE_NAME" {
  capabilities = ["read"]
}
EOF

vault policy write $VAULT_POLICY_NAME $VAULT_POLICY_NAME.hcl

# Assign the policy to a Vault user (adjust for your authentication method)
vault write auth/userpass/users/admin \
    password="securepassword" \
    policies="$VAULT_POLICY_NAME"

echo "Vault setup completed. Use the following command to generate temporary Azure admin credentials:"
echo "vault read azure/creds/$VAULT_ROLE_NAME"
