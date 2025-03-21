#!/bin/bash

# Variables
VAULT_ADDR="http://127.0.0.1:8200" # Change to your Vault server
VAULT_TOKEN="root" # Change to your Vault token or authenticate via VAULT CLI
AWS_ACCESS_KEY="<AWS_ACCESS_KEY>"  # Replace with actual AWS Access Key
AWS_SECRET_KEY="<AWS_SECRET_KEY>"  # Replace with actual AWS Secret Key
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="<AWS_ACCOUNT_ID>"  # Replace with your AWS Account ID
VAULT_ROLE_NAME="admin-role"
VAULT_POLICY_NAME="admin-access"

# Export Vault Address and Token
export VAULT_ADDR VAULT_TOKEN

# Enable AWS secrets engine
vault secrets enable aws || echo "AWS secrets engine already enabled."

# Configure AWS root credentials
vault write aws/config/root \
    access_key="$AWS_ACCESS_KEY" \
    secret_key="$AWS_SECRET_KEY" \
    region="$AWS_REGION"

# Create AWS role for generating temporary admin credentials
vault write aws/roles/$VAULT_ROLE_NAME \
    credential_type=iam_user \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::$AWS_ACCOUNT_ID:role/Admin"
    }
  ]
}
EOF \
    ttl=24h

# Create Vault policy for admin access
cat <<EOF > $VAULT_POLICY_NAME.hcl
path "aws/creds/$VAULT_ROLE_NAME" {
  capabilities = ["read"]
}
EOF

vault policy write $VAULT_POLICY_NAME $VAULT_POLICY_NAME.hcl

# Assign the policy to a Vault user (adjust for your authentication method)
vault write auth/userpass/users/admin \
    password="securepassword" \
    policies="$VAULT_POLICY_NAME"

echo "Vault setup completed. Use the following command to generate admin credentials:"
echo "vault read aws/creds/$VAULT_ROLE_NAME"
