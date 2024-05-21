#!/bin/bash

set -eu
_PROJECT=proj_code

PROJECT="${1:-$_PROJECT}"
MODEL="gemini-1.5-pro-preview-0514"
API="$(gcloud auth print-access-token)"

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
