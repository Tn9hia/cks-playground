#!/usr/bin/env bash
# Launches the master and worker VMs from cloud-init.yaml.
set -euo pipefail
cd "$(dirname "$0")/.."
source config.env

if [[ ! "$K8S_VERSION" =~ ^v[0-9]+\.[0-9]+$ ]]; then
  echo "K8S_VERSION must be a minor version like v1.34 (got: $K8S_VERSION)" >&2
  exit 1
fi

# Render the cloud-init template with the version from config.env.
CLOUD_INIT=$(mktemp)
trap 'rm -f "$CLOUD_INIT"' EXIT
sed "s|\${K8S_VERSION}|$K8S_VERSION|g" cloud-init.yaml > "$CLOUD_INIT"

for NAME in "$MASTER_NAME" "$WORKER_NAME"; do
  if multipass info "$NAME" &>/dev/null; then
    echo ">> $NAME already exists, skipping launch"
    continue
  fi
  echo ">> Launching $NAME ($VM_IMAGE, $CPUS CPU, $MEM RAM, $DISK disk, Kubernetes $K8S_VERSION)..."
  multipass launch "$VM_IMAGE" \
    --name "$NAME" \
    --cpus "$CPUS" \
    --memory "$MEM" \
    --disk "$DISK" \
    --cloud-init "$CLOUD_INIT"
done

echo
multipass list
echo
echo "Cloud-init is still finishing package installs in the background."
echo "Check with: multipass exec $MASTER_NAME -- cloud-init status --wait"
echo "Next: ./scripts/02-init-master.sh (Calico) or ./scripts/02-init-master-cilium.sh (Cilium)"
