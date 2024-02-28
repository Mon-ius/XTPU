#!/bin/dash
set -eu

_PROJECT=proj_code
_ZONE=us-central2-b

PROJECT="${1:-$_PROJECT}"
ZONE="${2:-$_ZONE}"

for _INSTANCE in $(gcloud alpha compute tpus queued-resources list --project "$PROJECT" --zone "$ZONE" --format="value(name)")
do 
echo y | gcloud alpha compute tpus queued-resources delete "$_INSTANCE" --project "$PROJECT" --zone "$ZONE" --force --async
done