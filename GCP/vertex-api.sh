#!/bin/bash

set -eu
_PROJECT="proj_code"
_MODEL="gemini-1.5-pro-preview-0514"
_MODEL2="gemini-1.5-flash-preview-0514"
_API="$(gcloud auth print-access-token)"

PROJECT="${1:-$_PROJECT}"
API="${2:-$_API}"
MODEL="${3:-$_MODEL}"


curl -X POST \
-H "Authorization: Bearer ${API}" \
-H "Content-Type: application/json" \
"https://us-central1-aiplatform.googleapis.com/v1/projects/${PROJECT}/locations/us-central1/publishers/google/models/${MODEL}:generateContent" -d \
$'{
    "contents": {
        "role": "user",
        "parts": [
            {
                "text": "What\'s a good name for a flower shop that specializes in selling bouquets of dried flowers?"
            }
        ]
    }
}'

echo "$PROJECT" "$API"
