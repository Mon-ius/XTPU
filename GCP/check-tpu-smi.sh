#!/bin/dash
set -eu

_PROJECT=proj_code
_ZONE=us-central2-b

PROJECT="${1:-$_PROJECT}"
ZONE="${2:-$_ZONE}"

ctpu status --details