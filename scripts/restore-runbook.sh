#!/usr/bin/env bash
# Interactive-ish restore helper — wraps the Velero restore commands used
# in an actual DR event so the exact incantations don't have to be
# remembered under pressure. Always restores into a namespace suffixed
# with -restore-test first; promoting to the real namespace is a
# deliberate second step (see docs/dr-runbook.md).
set -euo pipefail

BACKUP_NAME="${1:?Usage: restore-runbook.sh <backup-name> [namespace]}"
NAMESPACE="${2:-}"

echo "==> Backups matching '${BACKUP_NAME}':"
velero backup get | grep "$BACKUP_NAME" || { echo "No matching backup found"; exit 1; }

RESTORE_NAME="restore-$(date +%Y%m%d-%H%M%S)"

if [[ -n "$NAMESPACE" ]]; then
  echo "==> Restoring namespace '${NAMESPACE}' from backup '${BACKUP_NAME}' into '${NAMESPACE}-restore-test'"
  velero restore create "$RESTORE_NAME" \
    --from-backup "$BACKUP_NAME" \
    --namespace-mappings "${NAMESPACE}:${NAMESPACE}-restore-test"
else
  echo "==> Restoring full backup '${BACKUP_NAME}' as '${RESTORE_NAME}'"
  velero restore create "$RESTORE_NAME" --from-backup "$BACKUP_NAME"
fi

echo "==> Watching restore status (Ctrl+C to stop watching, restore continues in background)"
velero restore describe "$RESTORE_NAME" --details || true
echo ""
echo "Next steps:"
echo "  1. Verify the restored workloads: kubectl get all -n <restored-namespace>"
echo "  2. Run application-level smoke tests against the restored namespace"
echo "  3. Only after verification, promote (see docs/dr-runbook.md 'Promotion' section)"
