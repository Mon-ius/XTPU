#!/bin/dash
set +e

GH_API_BASE="https://api.github.com"
GH_UPLOAD_BASE="https://uploads.github.com"

_GH_TOKEN=""
_GH_TAG=""
_GH_FILE=""
_GH_REPO="${GITHUB_REPOSITORY:-}"

if [ -z "$1" ]; then
    echo "Usage: $0 <token> <tag> <file> [repo]"
    echo "Example:"
    echo "  $0 ghp_xxxx v1.0.0 app-linux"
    echo "  $0 ghp_xxxx v1.0.0 compose.yml owner/repo"
    echo ""
    echo "Note:"
    echo "  - repo defaults to GITHUB_REPOSITORY env var"
    echo "  - sha is fetched from GitHub API if tag needs to be created"
    exit 1
fi

GH_TOKEN="${1:-$_GH_TOKEN}"
GH_TAG="${2:-$_GH_TAG}"
GH_FILE="${3:-$_GH_FILE}"
GH_REPO="${4:-$_GH_REPO}"

if [ -z "$GH_TOKEN" ]; then
    echo "[ERROR] Token required"
    exit 1
fi

if [ -z "$GH_TAG" ]; then
    echo "[ERROR] Tag required"
    exit 1
fi

if [ -z "$GH_FILE" ]; then
    echo "[ERROR] File required"
    exit 1
fi

if [ ! -f "$GH_FILE" ]; then
    echo "[ERROR] File not found: $GH_FILE"
    exit 1
fi

if [ -z "$GH_REPO" ]; then
    echo "[ERROR] Repository required (set GITHUB_REPOSITORY or pass as argument)"
    exit 1
fi


GH_API="$GH_API_BASE/repos/$GH_REPO"
GH_FILENAME=$(basename "$GH_FILE")

# Detect content type
GH_CONTENT_TYPE="application/octet-stream"
case "$GH_FILENAME" in
    *.yml|*.yaml) GH_CONTENT_TYPE="application/x-yaml" ;;
    *.json) GH_CONTENT_TYPE="application/json" ;;
esac

# Check if tag exists
GH_TAG_EXISTS=$(curl -fsSL -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "$GH_API/git/refs/tags/$GH_TAG")

if [ "$GH_TAG_EXISTS" != "200" ]; then
    # Get latest commit SHA from default branch
    GH_SHA=$(curl -fsSL \
        -H "Authorization: Bearer $GH_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "$GH_API/commits/HEAD" | grep -o '"sha":"[^"]*"' | head -n 1 | cut -d'"' -f4)

    if [ -z "$GH_SHA" ]; then
        echo "[ERROR] Failed to get latest commit SHA"
        echo "[DEBUG] Retrying for detailed error..."
        GH_SHA_RESPONSE=$(curl -sS \
            -H "Authorization: Bearer $GH_TOKEN" \
            -H "Accept: application/vnd.github+json" \
            "$GH_API/commits/HEAD" 2>&1)
        echo "[DEBUG] Response: $GH_SHA_RESPONSE"
        exit 1
    fi

    GH_TAG_PAYLOAD='{"ref":"refs/tags/'"$GH_TAG"'","sha":"'"$GH_SHA"'"}'
    GH_TAG_RESPONSE=$(curl -fsSL -X POST \
        -H "Authorization: Bearer $GH_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "$GH_API/git/refs" \
        -d "$GH_TAG_PAYLOAD")

    if [ -z "$GH_TAG_RESPONSE" ]; then
        echo "[ERROR] Failed to create tag"
        echo "[DEBUG] Payload: $GH_TAG_PAYLOAD"
        echo "[DEBUG] Retrying for detailed error..."
        GH_TAG_RESPONSE=$(curl -sS -X POST \
            -H "Authorization: Bearer $GH_TOKEN" \
            -H "Accept: application/vnd.github+json" \
            "$GH_API/git/refs" \
            -d "$GH_TAG_PAYLOAD" 2>&1)
        echo "[DEBUG] Response: $GH_TAG_RESPONSE"
        exit 1
    fi
    echo "[INFO] Tag created: $GH_TAG ($GH_SHA)"
else
    echo "[INFO] Tag exists: $GH_TAG"
fi

# Get or create release
GH_RELEASE_RESPONSE=$(curl -fsSL \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "$GH_API/releases/tags/$GH_TAG" 2>/dev/null || echo "")
GH_RELEASE_ID=$(echo "$GH_RELEASE_RESPONSE" | grep -o '"id":[0-9]*' | head -n 1 | cut -d':' -f2)

if [ -z "$GH_RELEASE_ID" ]; then
    GH_RELEASE_PAYLOAD='{"tag_name":"'"$GH_TAG"'","name":"'"$GH_TAG"'","draft":false,"prerelease":false}'
    GH_RELEASE_RESPONSE=$(curl -fsSL -X POST \
        -H "Authorization: Bearer $GH_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "$GH_API/releases" \
        -d "$GH_RELEASE_PAYLOAD")
    GH_RELEASE_ID=$(echo "$GH_RELEASE_RESPONSE" | grep -o '"id":[0-9]*' | head -n 1 | cut -d':' -f2)

    if [ -z "$GH_RELEASE_ID" ]; then
        echo "[ERROR] Failed to create release"
        echo "[DEBUG] Payload: $GH_RELEASE_PAYLOAD"
        echo "[DEBUG] Retrying for detailed error..."
        GH_RELEASE_RESPONSE=$(curl -sS -X POST \
            -H "Authorization: Bearer $GH_TOKEN" \
            -H "Accept: application/vnd.github+json" \
            "$GH_API/releases" \
            -d "$GH_RELEASE_PAYLOAD" 2>&1)
        echo "[DEBUG] Response: $GH_RELEASE_RESPONSE"
        exit 1
    fi
    echo "[INFO] Release created: $GH_RELEASE_ID"
else
    echo "[INFO] Release exists: $GH_RELEASE_ID"
fi

# Delete existing asset if exists
GH_ASSET_RESPONSE=$(curl -fsSL \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "$GH_API/releases/$GH_RELEASE_ID/assets")
GH_ASSET_ID=$(echo "$GH_ASSET_RESPONSE" | grep -o '"id":[0-9]*,"[^}]*"name":"'"$GH_FILENAME"'"' | grep -o '"id":[0-9]*' | cut -d':' -f2)

if [ -n "$GH_ASSET_ID" ]; then
    curl -fsSL -X DELETE \
        -H "Authorization: Bearer $GH_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "$GH_API/releases/assets/$GH_ASSET_ID"
    echo "[INFO] Deleted existing asset: $GH_ASSET_ID"
fi

# Upload asset
GH_UPLOAD_RESPONSE=$(curl -fsSL -X POST \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: $GH_CONTENT_TYPE" \
    --data-binary @"$GH_FILE" \
    "$GH_UPLOAD_BASE/repos/$GH_REPO/releases/$GH_RELEASE_ID/assets?name=$GH_FILENAME")
GH_UPLOAD_ID=$(echo "$GH_UPLOAD_RESPONSE" | grep -o '"id":[0-9]*' | head -n 1 | cut -d':' -f2)

if [ -z "$GH_UPLOAD_ID" ]; then
    echo "[ERROR] Failed to upload asset"
    echo "[DEBUG] Retrying for detailed error..."
    GH_UPLOAD_RESPONSE=$(curl -sS -X POST \
        -H "Authorization: Bearer $GH_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -H "Content-Type: $GH_CONTENT_TYPE" \
        --data-binary @"$GH_FILE" \
        "$GH_UPLOAD_BASE/repos/$GH_REPO/releases/$GH_RELEASE_ID/assets?name=$GH_FILENAME" 2>&1)
    echo "[DEBUG] Response: $GH_UPLOAD_RESPONSE"
    exit 1
fi

echo "[INFO] Tag: $GH_TAG"
echo "[INFO] Release ID: $GH_RELEASE_ID"
echo "[INFO] Asset ID: $GH_UPLOAD_ID"
