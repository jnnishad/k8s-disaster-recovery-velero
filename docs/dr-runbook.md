# Disaster recovery runbook

## Backup posture

| Schedule                        | Scope                          | RPO   | Retention |
|----------------------------------|---------------------------------|-------|-----------|
| `daily-full-backup`              | Whole cluster (minus GitOps-managed namespaces) | 24h | 30 days |
| `hourly-critical-namespaces`     | Stateful namespaces (DB, messaging) | 1h  | 3 days |

Storage backend is Minio (S3-compatible), matching the retention-policy
pattern used for metrics/logs/traces at NEC India.

## Verifying backups are healthy

```bash
./scripts/verify-backup.sh daily-full-backup
```

Run this on a schedule (cron / CI) — a Velero schedule that's silently
failing every night is worse than no schedule, because nobody notices
until the restore is needed.

## Restore procedure

1. **Never restore directly into the live namespace first.**
   `scripts/restore-runbook.sh <backup-name> <namespace>` restores into
   `<namespace>-restore-test` via Velero's `--namespace-mappings`.
2. Smoke-test the restored workloads in the `-restore-test` namespace.
3. **Promotion** (only after verification):
   - Scale down the broken namespace's workloads to 0.
   - Re-run the restore without `--namespace-mappings` (restores in place), **or**
   - `kubectl` copy manifests from the `-restore-test` namespace into the real one if only partial recovery is needed.
4. Delete the `-restore-test` namespace once promotion is confirmed good.

## Full cluster loss scenario

1. Rebuild the cluster (`terraform-multicloud-infra` + `gitops-cicd-pipelines` bootstrap).
2. Install Velero pointed at the same Minio backend (`install/velero-values.yaml`).
3. `velero backup get` — confirm the backup catalog is visible (it lives in object storage, independent of the cluster).
4. `velero restore create --from-backup <latest-daily-full-backup>` — full restore, no namespace mapping needed since the cluster is empty.
5. Re-apply anything GitOps-managed (monitoring stack, ingress controllers) via the normal pipeline — these were deliberately excluded from Velero backups since they're reproducible from Git.

## Why namespaces are split into "backed up" vs "GitOps-managed"

Anything whose desired state lives in a Git repo (observability stack,
ingress, cert-manager) is faster and more reliably restored by
re-running the pipeline than by restoring a Velero snapshot — and it
keeps backup size/time focused on the state that's actually irreplaceable:
application data.
