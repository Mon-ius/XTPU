#!/bin/dash

set +e

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token> <bucket_name> [is_admin] [is_public]"
    echo "Notice that, it is the account-owned solution"
    echo "is_admin: Set to 'true' for admin permissions (optional, default: false)"
    echo "is_public: Set to 'true' for public bucket (optional, default: true)"
    exit 1
fi

_CF_TOKEN_BASE64='base64encodedtoken'
_BUCKET_NAME='mybucket'
_IS_ADMIN='false'
_IS_PUBLIC='true'

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
BUCKET_NAME="${2:-$_BUCKET_NAME}"
IS_ADMIN="${3:-$_IS_ADMIN}"
IS_PUBLIC="${4:-$_IS_PUBLIC}"

CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)
CF_ACCOUNT_ID=$(curl -fsSL "https://api.cloudflare.com/client/v4/accounts" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

if [ -z "$CF_ACCOUNT_ID" ]; then
    echo "Error: Unable to retrieve Cloudflare account."
    exit 1
fi

echo "[INFO] Account ID: $CF_ACCOUNT_ID"
echo "[INFO] Admin mode: $IS_ADMIN"
echo "[INFO] Public mode: $IS_PUBLIC"

R2_ENDPOINT="https://$CF_ACCOUNT_ID.r2.cloudflarestorage.com"
R2_RESOURCE="com.cloudflare.edge.r2.bucket.${CF_ACCOUNT_ID}_default_${BUCKET_NAME}"
R2_RESOURCE_EU="com.cloudflare.edge.r2.bucket.${CF_ACCOUNT_ID}_eu_my-eu-${BUCKET_NAME}"

BUCKET_EXISTS=$(curl -fsSL "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/r2/buckets" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"name":"'"$BUCKET_NAME"'"')

echo "[INFO] Setting up R2 bucket: $BUCKET_NAME"

if [ -z "$BUCKET_EXISTS" ]; then
    curl -fsSL -X POST "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/r2/buckets" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "'"$BUCKET_NAME"'",
            "locationHint": "apac"
        }'
fi

echo "[INFO] Configuring public access for bucket"

if [ "$IS_PUBLIC" = "true" ]; then
    DOMAIN_RESPONSE=$(curl -fsSL -X PUT "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/r2/buckets/$BUCKET_NAME/domains/managed" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "enabled": true
        }')
    
    PUBLIC_DOMAIN=$(echo "$DOMAIN_RESPONSE" | grep -o '"domain":"[^"]*' | cut -d'"' -f4)
    
    if [ -n "$PUBLIC_DOMAIN" ]; then
        echo "[INFO] Public URL: https://$PUBLIC_DOMAIN"
    else
        echo "[ERROR] Failed to enable public domain"
    fi
fi

if [ "$IS_ADMIN" = "true" ]; then
    TOKEN_RESPONSE=$(curl -fsSL -X POST "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/tokens" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "R2-'"${BUCKET_NAME}"'-admin",
            "policies": [{
                "effect": "allow",
                "resources": {
                    "com.cloudflare.api.account.'"${CF_ACCOUNT_ID}"'": "*"
                },
                "permission_groups": [
                    {
                        "id": "6a018a9f2fc74eb6b293b0c548f38b39",
                        "name": "Workers R2 Storage Bucket Item Read"
                    },
                    {
                        "id": "2efd5506f9c8494dacb1fa10a3e7d5b6",
                        "name": "Workers R2 Storage Bucket Item Write"
                    },
                    {
                        "id": "b4992e1108244f5d8bfbd5744320c2e1",
                        "name": "Workers R2 Storage Read"
                    },
                    {
                        "id": "bf7481a1826f439697cb59a20b22293e",
                        "name": "Workers R2 Storage Write"
                    },
                    {
                        "id": "45db74139a62490b9b60eb7c4f34994b",
                        "name": "Workers R2 Data Catalog Read"
                    },
                    {
                        "id": "d229766a2f7f4d299f20eaa8c9b1fde9",
                        "name": "Workers R2 Data Catalog Write"
                    }
                ]
            }]
        }')
else
    TOKEN_RESPONSE=$(curl -fsSL -X POST "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/tokens" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "R2-'"${BUCKET_NAME}"'",
            "policies": [{
                "effect": "allow",
                "resources": {
                    "'"${R2_RESOURCE}"'": "*",
                    "'"${R2_RESOURCE_EU}"'": "*"
                },
                "permission_groups": [
                    {
                        "id": "6a018a9f2fc74eb6b293b0c548f38b39",
                        "name": "Workers R2 Storage Bucket Item Read"
                    },
                    {
                        "id": "2efd5506f9c8494dacb1fa10a3e7d5b6",
                        "name": "Workers R2 Storage Bucket Item Write"
                    }
                ]
            }]
        }')
fi

R2_ACCESS_KEY=$(echo "$TOKEN_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
R2_TOKEN_VALUE=$(echo "$TOKEN_RESPONSE" | grep -o '"value":"[^"]*' | cut -d'"' -f4)
R2_SECRET_KEY=$(echo -n "$R2_TOKEN_VALUE" | sha256sum | cut -d' ' -f1)

echo "[SUCCESS] R2 configured"
echo "Endpoint: $R2_ENDPOINT"
echo "ACCESS KEY: $R2_ACCESS_KEY"
echo "SECRET KEY: $R2_SECRET_KEY"
