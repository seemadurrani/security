#!/bin/bash

# Variables
VAULT_ADDR="http://127.0.0.1:8200"  # Change to your Vault server
VAULT_TOKEN="root"  # Change to your Vault token or authenticate via VAULT CLI
GCP_PROJECT_ID="<GCP_PROJECT_ID>"  # Replace with your GCP project ID
GCP_SERVICE_ACCOUNT_EMAIL="<GCP_SERVICE_ACCOUNT_EMAIL>"  # Replace with a GCP service account email
VAULT_ROLE_NAME="gcp-admin-role"
VAULT_POLICY_NAME="gcp-admin-access"

# Export Vault Address and Token
export VAULT_ADDR VAULT_TOKEN

# Enable GCP secrets engine
vault secrets enable gcp || echo "GCP secrets engine already enabled."

# Configure GCP credentials
vault write gcp/config \
    credentials=@gcp-service-account.json

# Create a Vault role that generates short-lived GCP IAM tokens
vault write gcp/roleset/$VAULT_ROLE_NAME \
    project="$GCP_PROJECT_ID" \
    secret_type="access_token" \
    bindings=-<<EOF
{
  "roles/cloudsql.admin": ["serviceAccount:$GCP_SERVICE_ACCOUNT_EMAIL"],
  "roles/editor": ["serviceAccount:$GCP_SERVICE_ACCOUNT_EMAIL"],
  "roles/iam.securityAdmin": ["serviceAccount:$GCP_SERVICE_ACCOUNT_EMAIL"]
}
EOF \
    token_scopes="https://www.googleapis.com/auth/cloud-platform" \
    ttl="24h"

# Create Vault policy for GCP admin access
cat <<EOF > $VAULT_POLICY_NAME.hcl
path "gcp/token/$VAULT_ROLE_NAME" {
  capabilities = ["read"]
}
EOF

vault policy write $VAULT_POLICY_NAME $VAULT_POLICY_NAME.hcl

# Assign the policy to a Vault user (adjust for your authentication method)
vault write auth/userpass/users/admin \
    password="securepassword" \
    policies="$VAULT_POLICY_NAME"

echo "Vault setup completed. Use the following command to generate a temporary GCP admin access token:"
echo "vault read gcp/token/$VAULT_ROLE_NAME"
