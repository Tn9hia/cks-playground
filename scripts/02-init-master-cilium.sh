#!/usr/bin/env bash
# Same as 02-init-master.sh, but installs Cilium instead of Calico as the CNI
# (NetworkPolicy + CiliumNetworkPolicy, closer to what recent CKS tasks use).
# Runs kubeadm init on the master, wires up kubectl for the ubuntu user,
# installs Cilium via the cilium CLI, and saves the worker join command to
# ../join-command.sh. Use this OR 02-init-master.sh on a fresh cluster, not both.
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

echo ">> Installing cilium CLI $CILIUM_CLI_VERSION..."
multipass exec "$MASTER_NAME" -- bash -c "
  set -euo pipefail
  ARCH=\$(dpkg --print-architecture)
  cd /tmp
  curl -fsSL --remote-name-all https://github.com/cilium/cilium-cli/releases/download/$CILIUM_CLI_VERSION/cilium-linux-\$ARCH.tar.gz{,.sha256sum}
  sha256sum --check cilium-linux-\$ARCH.tar.gz.sha256sum
  sudo tar xzf cilium-linux-\$ARCH.tar.gz -C /usr/local/bin
  rm cilium-linux-\$ARCH.tar.gz{,.sha256sum}
"

# ipam.mode=kubernetes makes Cilium use the per-node podCIDRs that kubeadm carves
# out of $POD_CIDR, instead of its own 10.0.0.0/8 cluster-pool default.
# operator.replicas=1 because the default of 2 can't schedule on a 2-node lab.
echo ">> Installing Cilium $CILIUM_VERSION..."
multipass exec "$MASTER_NAME" -- cilium install \
  --version "$CILIUM_VERSION" \
  --set ipam.mode=kubernetes \
  --set operator.replicas=1

echo ">> Waiting for Cilium to become ready..."
multipass exec "$MASTER_NAME" -- cilium status --wait

echo ">> Saving join command to join-command.sh..."
multipass exec "$MASTER_NAME" -- sudo kubeadm token create --print-join-command > join-command.sh
chmod +x join-command.sh

echo
echo "Master ready. Next: ./scripts/03-join-worker.sh"
