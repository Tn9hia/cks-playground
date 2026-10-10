#!/usr/bin/env bash
# Optional: copy the admin kubeconfig to the host so you can run kubectl from
# your Mac instead of `multipass shell`/`multipass exec` into the master.
# Note: the real CKS exam only gives you a shell on the cluster nodes, so for
# the most realistic practice prefer `multipass shell k8s-master` instead.
set -euo pipefail
cd "$(dirname "$0")/.."
source config.env

multipass exec "$MASTER_NAME" -- sudo cat /etc/kubernetes/admin.conf > kubeconfig.yaml
echo "Saved to kubeconfig.yaml"
echo "Use it with: export KUBECONFIG=\"\$PWD/kubeconfig.yaml\""
