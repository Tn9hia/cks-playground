#!/usr/bin/env bash
# Runs kubeadm init on the master, wires up kubectl for the ubuntu user,
# installs Calico (needed for NetworkPolicy support, which CKS tests heavily),
# and saves the worker join command to ../join-command.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
source config.env

echo ">> Waiting for cloud-init to finish on $MASTER_NAME..."
multipass exec "$MASTER_NAME" -- cloud-init status --wait || true

MASTER_IP=$(get_ip "$MASTER_NAME")
echo ">> Master IP: $MASTER_IP"

echo ">> Running kubeadm init..."
multipass exec "$MASTER_NAME" -- sudo kubeadm init \
  --pod-network-cidr="$POD_CIDR" \
  --apiserver-advertise-address="$MASTER_IP"

echo ">> Configuring kubectl for the ubuntu user..."
multipass exec "$MASTER_NAME" -- sudo mkdir -p /home/ubuntu/.kube
multipass exec "$MASTER_NAME" -- sudo cp -f /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
multipass exec "$MASTER_NAME" -- sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

echo ">> Installing Calico CNI ($CALICO_MANIFEST) with pool $POD_CIDR..."
# Uncomment CALICO_IPV4POOL_CIDR so the pool is pinned to $POD_CIDR instead of
# Calico's 192.168.0.0/16 default, which overlaps the multipass VM network.
multipass exec "$MASTER_NAME" -- bash -c "
  set -euo pipefail
  curl -fsSL '$CALICO_MANIFEST' \
    | sed -e 's|# - name: CALICO_IPV4POOL_CIDR|- name: CALICO_IPV4POOL_CIDR|' \
          -e 's|#   value: \"192.168.0.0/16\"|  value: \"$POD_CIDR\"|' > /tmp/calico.yaml
  grep -A1 -- '- name: CALICO_IPV4POOL_CIDR' /tmp/calico.yaml | grep -q '$POD_CIDR' \
    || { echo 'Failed to set CALICO_IPV4POOL_CIDR in the manifest' >&2; exit 1; }
  kubectl apply -f /tmp/calico.yaml
"

echo ">> Saving join command to join-command.sh..."
multipass exec "$MASTER_NAME" -- sudo kubeadm token create --print-join-command > join-command.sh
chmod +x join-command.sh

echo
echo "Master ready. Next: ./scripts/03-join-worker.sh"
