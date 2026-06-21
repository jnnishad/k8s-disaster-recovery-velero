# k8s-disaster-recovery-velero

Velero-based backup and disaster recovery for Kubernetes clusters:
scheduled backups with tiered RPO/retention, a restore runbook, and
scripts that wrap the Velero CLI so a 2am recovery doesn't depend on
remembering exact flags.

## Why

"We have backups" and "we have tested, documented restores" are
different claims. This repo is the second one — built from running
Velero-based backup/DR for multi-cluster Kubernetes at NEC India,
including scheduled volume backups via Minio-backed object storage.

## Structure

```
install/
  velero-values.yaml              Helm values — Minio (S3-compatible) backend
schedules/
  daily-backup-schedule.yaml       Full cluster, 30-day retention, GitOps namespaces excluded
  hourly-etcd-critical-namespaces.yaml  Tighter RPO for stateful namespaces
scripts/
  verify-backup.sh                 Fails loudly if the latest scheduled backup didn't complete
  restore-runbook.sh                Wraps `velero restore create` with a safe restore-into-test-namespace default
docs/
  dr-runbook.md                      Full restore procedure, including total-cluster-loss recovery
```

## Usage

```bash
# install
helm install velero vmware-tanzu/velero -f install/velero-values.yaml -n velero --create-namespace
kubectl apply -f schedules/

# verify backups are actually succeeding (run this on a schedule, not just once)
./scripts/verify-backup.sh daily-full-backup

# restore (into a *-restore-test namespace by default — see docs/dr-runbook.md)
./scripts/restore-runbook.sh daily-full-backup-20260706020000 production-db
```

## Design notes

- **GitOps-managed namespaces are excluded from backups.** Anything
  whose state lives in Git (ingress, cert-manager, the observability
  stack) is restored faster and more reliably by re-running
  [`gitops-cicd-pipelines`](https://github.com/jnnishad/gitops-cicd-pipelines)
  than by restoring a snapshot.
- **Tiered RPO.** Stateful namespaces get hourly backups with short
  retention as a safety net between the daily full backups — not the
  primary recovery point, just insurance against a bad day.
- **Restores default to a `-restore-test` namespace.** Promotion to the
  real namespace is a deliberate, separate step — see
  `docs/dr-runbook.md`.

## Related repos

- [`k8s-observability-stack`](https://github.com/jnnishad/k8s-observability-stack) — Velero metrics are scraped into the same Prometheus/Mimir stack
- [`terraform-multicloud-infra`](https://github.com/jnnishad/terraform-multicloud-infra) — rebuilding the cluster itself in a total-loss scenario

## License

MIT — see [LICENSE](LICENSE).

<!-- JN -->
