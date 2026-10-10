#!/usr/bin/env bash
# Joins the worker node to the cluster using the command saved by 02-init-master.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
source config.env

if [ ! -f join-command.sh ]; then
  echo "join-command.sh not found. Run ./scripts/02-init-master.sh first." >&2
  exit 1
fi

echo ">> Waiting for cloud-init to finish on $WORKER_NAME..."
multipass exec "$WORKER_NAME" -- cloud-init status --wait || true

JOIN_CMD=$(cat join-command.sh)
echo ">> Joining $WORKER_NAME to the cluster..."
multipass exec "$WORKER_NAME" -- sudo bash -c "$JOIN_CMD"

echo
echo ">> Cluster nodes:"
multipass exec "$MASTER_NAME" -- kubectl get nodes -o wide
