#!/usr/bin/env bash
# Tears down both VMs and local state so you can start a fresh cluster.
set -euo pipefail
cd "$(dirname "$0")/.."
source config.env

multipass delete "$MASTER_NAME" "$WORKER_NAME" --purge 2>/dev/null || true
rm -f join-command.sh kubeconfig.yaml

echo "Cluster destroyed."
