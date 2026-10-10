#!/usr/bin/env bash
# Joins every worker to the cluster using the command saved by 02-init-master*.sh.
# Workers that already joined are skipped, so it is safe to re-run.
set -euo pipefail
cd "$(dirname "$0")/.."
source config.env

if [ ! -f join-command.sh ]; then
  echo "join-command.sh not found. Run ./scripts/02-init-master.sh first." >&2
  exit 1
fi

JOIN_CMD=$(cat join-command.sh)

for NAME in $(worker_names); do
  echo ">> Waiting for cloud-init to finish on $NAME..."
  multipass exec "$NAME" -- cloud-init status --wait || true

  # kubelet.conf only exists once kubeadm join (or init) has succeeded on the node.
  if multipass exec "$NAME" -- test -f /etc/kubernetes/kubelet.conf; then
    echo ">> $NAME already joined, skipping"
    continue
  fi

  echo ">> Joining $NAME to the cluster..."
  multipass exec "$NAME" -- sudo bash -c "$JOIN_CMD"
done

echo
echo ">> Cluster nodes:"
multipass exec "$MASTER_NAME" -- kubectl get nodes -o wide
