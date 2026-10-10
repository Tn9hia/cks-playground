#!/usr/bin/env bash
# Tears down the master, all worker VMs and local state so you can start a fresh cluster.
# Workers are matched by name (k8s-worker, k8s-worker-N) rather than WORKER_COUNT,
# so VMs from a cluster created with a different count are removed too.
set -euo pipefail
cd "$(dirname "$0")/.."
source config.env

VMS=$(multipass list --format json \
  | jq -r --arg m "$MASTER_NAME" --arg w "$WORKER_PREFIX" \
      '.list[].name | select(. == $m or test("^" + $w + "(-[0-9]+)?$"))')

if [ -n "$VMS" ]; then
  echo ">> Deleting:" $VMS
  multipass delete $VMS --purge
fi
rm -f join-command.sh kubeconfig.yaml

echo "Cluster destroyed."
