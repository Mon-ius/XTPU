#!/bin/dash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token>"
    echo ""
    echo "This script will deploy Cloudflare Workers for all AI providers and container registries"
    echo ""
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg=="
    exit 1
fi

_CF_TOKEN_BASE64='base64encodedtoken'
CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"

echo "=========================================="
echo "Deploying All Cloudflare Worker Proxies"
echo "=========================================="
echo ""

AI_PROVIDERS="openai gemini claude grok cohere groq mistral huggingface"
# AI_PROVIDERS="ai21 claude cohere deepseek fireworks gemini groq huggingface mistral nvidia openai perplexity replicate together voyage"
REGISTRIES="docker ghcr k8s"
# REGISTRIES="docker quay gcr k8s-gcr k8s ghcr cloudsmith nvcr"

echo "📤 Deploying AI Provider Mirrors..."
echo "----------------------------------"

for provider in $AI_PROVIDERS; do
    script="https://raw.githubusercontent.com/Mon-ius/XTPU/refs/heads/main/cloudflare/workers/create-cloudflare-${provider}.sh"
    echo "  ⏳ Deploying $provider..."
    curl -fsSL "$script" | sh -s -- "$CF_TOKEN_BASE64"
    echo "  ✅ $provider deployed"
done

echo ""
echo "📦 Deploying Container Registry Mirrors..."
echo "------------------------------------------"
for registry in $REGISTRIES; do
    script="https://raw.githubusercontent.com/Mon-ius/XTPU/refs/heads/main/cloudflare/workers/create-cloudflare-${registry}.sh"
    echo "  ⏳ Deploying $registry..."
    curl -fsSL "$script" | sh -s -- "$CF_TOKEN_BASE64"
    echo "  ✅ $registry deployed"
done