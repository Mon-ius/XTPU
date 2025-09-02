#!/bin/dash

set +e

TW_API_BASE="https://api.transferwise.com"
_TW_TOKEN_BASE64='base64encodedtoken'
_TW_SOURCE_CURRENCY='USD'
_TW_TARGET_CURRENCY='HKD' # HKD/CNY
_TW_AMOUNT=100

_TW_TARGET_ACCOUNT='123456789012'
_TW_TARGET_NAME='John Smith'

if [ -z "$1" ]; then
    echo "Usage: $0 <wise_token> [source_currency] [target_currency] [amount] [target_account] [target_name]"
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg== USD HKD 100 123456789012 'John Smith'"
    exit 1
fi

TW_TOKEN_BASE64="${1:-$_TW_TOKEN_BASE64}"
TW_SOURCE_CURRENCY="${2:-$_TW_SOURCE_CURRENCY}"
TW_TARGET_CURRENCY="${3:-$_TW_TARGET_CURRENCY}"
TW_AMOUNT="${4:-$_TW_AMOUNT}"
TW_TARGET_ACCOUNT="${5:-$_TW_TARGET_ACCOUNT}"
TW_TARGET_NAME="${6:-$_TW_TARGET_NAME}"

TW_TOKEN=$(echo "$TW_TOKEN_BASE64" | base64 -d)
TW_QUOTE_PAYLOAD='{
    "sourceCurrency": "'$TW_SOURCE_CURRENCY'",
    "targetCurrency": "'$TW_TARGET_CURRENCY'",
    "sourceAmount": '$TW_AMOUNT'
}'

TW_RECIPIENT_PAYLOAD_HK='{
    "currency": "'$TW_TARGET_CURRENCY'",
    "type": "hongkong",
    "profile": '$TW_PROFILE_ID',
    "accountHolderName": "'$TW_TARGET_NAME'",
    "details": {
        "legalType": "PRIVATE",
        "accountNumber": "'$TW_TARGET_ACCOUNT'"
    }
}'


TW_PROFILE_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $TW_TOKEN" "$TW_API_BASE/v2/profiles" | grep -o '"id":[0-9]*' | cut -d':' -f2 | head -n 1)

if [ -z "$TW_PROFILE_ID" ]; then
    echo "[ERROR] Unable to profile id. Please check your API token."
    exit 1
fi

TW_QUOTE_ID=$(curl -fsSL -X POST "$TW_API_BASE/v3/profiles/$TW_PROFILE_ID/quotes" \
    -H "Authorization: Bearer $TW_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$TW_QUOTE_PAYLOAD" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

if [ -z "$TW_QUOTE_ID" ]; then
    echo "[ERROR] Unable to get quote id. Quote creation may have failed."
    exit 1
fi

echo "[INFO] Profile ID: TW_PROFILE_ID=$TW_PROFILE_ID"
echo "[INFO] Quote ID: TW_QUOTE_ID=$TW_QUOTE_ID"

# TW_ACCOUNT_REQUIREMENTS=$(curl -fsSL -X GET "$TW_API_BASE/v1/quotes/$TW_QUOTE_ID/account-requirements" \
#     -H "Authorization: Bearer $TW_TOKEN")

curl -X POST "$TW_API_BASE/v1/accounts" \
    -H "Authorization: Bearer $TW_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$TW_RECIPIENT_PAYLOAD_HK"