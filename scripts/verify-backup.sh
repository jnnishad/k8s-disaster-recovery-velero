#!/usr/bin/env bash
# Fails (non-zero exit) if the most recent scheduled backup did not
# complete successfully. Intended to run as a scheduled CI job / cron so
# a silently broken backup schedule gets caught before it's needed.
set -euo pipefail

SCHEDULE_NAME="${1:-daily-full-backup}"

LATEST=$(velero backup get -l "velero.io/schedule-name=${SCHEDULE_NAME}" \
  --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
items = sorted(data['items'], key=lambda b: b['metadata']['creationTimestamp'], reverse=True)
print(items[0]['metadata']['name'] if items else '')
")

if [[ -z "$LATEST" ]]; then
  echo "No backups found for schedule ${SCHEDULE_NAME}" >&2
  exit 1
fi

STATUS=$(velero backup describe "$LATEST" --output json | python3 -c "import json,sys; print(json.load(sys.stdin)['status']['phase'])")

echo "Latest backup for ${SCHEDULE_NAME}: ${LATEST} (status: ${STATUS})"

if [[ "$STATUS" != "Completed" ]]; then
  echo "Backup ${LATEST} did not complete successfully (status: ${STATUS})" >&2
  exit 1
fi

echo "OK"
