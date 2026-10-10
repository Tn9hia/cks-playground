# multipass-cks

Dựng nhanh một cụm Kubernetes gồm 1 master và N worker (mặc định 2) bằng [Multipass](https://multipass.run) và `kubeadm` để luyện thi **CKS**. Có 2 lựa chọn CNI: **Cilium** hoặc **Calico**. Cả hai đều hỗ trợ NetworkPolicy.

## Thành phần

| Thành phần | Giá trị mặc định | Sửa ở đâu |
|---|---|---|
| OS | Ubuntu 24.04 LTS | `config.env` (`VM_IMAGE`) |
| Node | `k8s-master`, `k8s-worker-1` … `k8s-worker-N` | `config.env` (`MASTER_NAME`, `WORKER_PREFIX`) |
| Số worker | 2 | `config.env` (`WORKER_COUNT`) |
| Tài nguyên mỗi VM | 2 CPU, 2G RAM, 10G disk | `config.env` |
| Kubernetes | v1.36 (kubeadm / kubelet / kubectl) | `config.env` (`K8S_VERSION`) |
| Container runtime | containerd (systemd cgroup) | `cloud-init.yaml` |
| Pod CIDR | `10.244.0.0/16` | `config.env` (`POD_CIDR`) |
| CNI | Cilium 1.20.2 hoặc Calico v3.28.0 | `config.env` |

## Cấu trúc thư mục

```
.
├── config.env                       # cấu hình chung, các script đều source file này
├── cloud-init.yaml                  # template cài containerd + kubeadm/kubelet/kubectl, 01 điền K8S_VERSION vào
├── scripts/
│   ├── 01-create-cluster.sh         # tạo VM master + WORKER_COUNT worker
│   ├── 02-init-master-cilium.sh     # kubeadm init + cài Cilium
│   ├── 02-init-master.sh            # kubeadm init + cài Calico
│   ├── 03-join-worker.sh            # cho các worker join vào cụm
│   ├── 04-destroy.sh                # xoá cụm
│   └── fetch-kubeconfig.sh          # (tuỳ chọn) lấy kubeconfig về máy host
├── join-command.sh                  # sinh ra ở bước 02, KHÔNG commit/share
└── kubeconfig.yaml                  # sinh ra bởi fetch-kubeconfig.sh, KHÔNG commit/share
```

## Yêu cầu

- macOS hoặc Linux đã cài **Multipass**: `brew install --cask multipass`
- **jq**: `brew install jq` (macOS có sẵn từ bản 15 trở lên)
- Máy host còn trống tối thiểu khoảng 2 CPU, 2G RAM và 10G disk **cho mỗi VM**. Với cấu hình mặc định (1 master + 2 worker) là 6 CPU, 6G RAM, 30G disk
- Có Internet, vì VM cần tải package, image và manifest CNI

Kiểm tra:

```bash
multipass version
jq --version
```

## Dựng cụm

```bash
# 1. Tạo VM master + các worker. cloud-init sẽ cài package ngầm, mất vài phút.
#    Muốn đổi số worker thì sửa WORKER_COUNT trong config.env TRƯỚC bước này.
./scripts/01-create-cluster.sh

# 2. Khởi tạo master và cài CNI. Chọn MỘT trong hai:
./scripts/02-init-master-cilium.sh   # Cilium (khuyên dùng, gần với đề CKS hơn)
./scripts/02-init-master.sh          # Calico

# 3. Join tất cả worker
./scripts/03-join-worker.sh
```

Bạn không cần tự đợi cloud-init chạy xong, vì script 02 và 03 đã có bước `cloud-init status --wait`.

> **Lưu ý:** mỗi cụm chỉ chạy **một** script 02. Muốn đổi CNI thì chạy `04-destroy.sh` rồi tạo lại từ đầu.

## Đổi số lượng worker

Số worker chỉ được đọc lúc dựng cụm. Muốn đổi, ví dụ từ 1 lên 3 worker, thì **xoá cụm rồi dựng lại**. Việc này chỉ mất vài phút:

```bash
./scripts/04-destroy.sh              # xoá master và mọi VM k8s-worker / k8s-worker-N
# sửa WORKER_COUNT="3" trong config.env
./scripts/01-create-cluster.sh
./scripts/02-init-master-cilium.sh
./scripts/03-join-worker.sh
```

`04-destroy.sh` tìm VM theo tên chứ không theo `WORKER_COUNT`. Vì vậy dù bạn sửa `WORKER_COUNT` trước hay sau khi xoá, script vẫn dọn hết worker của cụm cũ.

Tài nguyên: mỗi VM dùng `CPUS`/`MEM`/`DISK` trong `config.env`. Hãy chừa khoảng 4–6G RAM cho máy host. Ví dụ máy 16G RAM chạy thoải mái 1 master + 3–4 worker với 2G mỗi VM. Muốn nhiều node hơn thì giảm `MEM` (ví dụ `1536M`).

## Kiểm tra cụm

```bash
multipass shell k8s-master

kubectl get nodes -o wide        # mọi node đều phải Ready
kubectl get pods -A              # mọi pod ở trạng thái Running
```

Nếu dùng Cilium:

```bash
cilium status
# Test kết nối đầy đủ (mất vài phút, tạo namespace cilium-test-*):
cilium connectivity test
```

## Dùng kubectl từ máy host (tuỳ chọn)

```bash
./scripts/fetch-kubeconfig.sh
export KUBECONFIG="$PWD/kubeconfig.yaml"
kubectl get nodes
```

Khi thi CKS thật, bạn chỉ được SSH vào node. Vì vậy để luyện cho sát đề, nên quen làm trực tiếp trong `multipass shell k8s-master`.

## Các lệnh Multipass hay dùng

```bash
multipass list                         # danh sách VM + IP
multipass shell k8s-worker-1           # SSH vào worker 1
multipass exec k8s-master -- <lệnh>    # chạy 1 lệnh trong VM
multipass stop --all                   # tắt VM để tiết kiệm tài nguyên
multipass start --all                  # bật lại, cụm tự chạy tiếp
multipass snapshot k8s-master          # chụp snapshot (VM phải đang stop)
```

Mẹo khi luyện đề: dựng cụm xong thì `multipass stop --all`, rồi `multipass snapshot` cho từng node. Làm hỏng cụm thì `multipass restore` về trạng thái sạch, nhanh hơn nhiều so với dựng lại.

## Xoá cụm

```bash
./scripts/04-destroy.sh
```

Script xoá hẳn master và mọi VM worker (`--purge`), đồng thời xoá `join-command.sh` và `kubeconfig.yaml`.

## Xử lý sự cố

### Node mất kết nối với Multipass sau khi cài CNI

Triệu chứng: sau bước 02/03, khi các pod CNI vừa chạy xong thì `multipass shell` / `multipass exec` bị timeout và không ping được IP của VM. Trạng thái trong `multipass list` vẫn là `Running`.

Nguyên nhân: **dải pod CIDR bị trùng với mạng của VM**. Trên macOS, Multipass dùng dải `192.168.x.0/24` (ví dụ `192.168.252.0/24`, xem bằng `multipass list`). Nếu `POD_CIDR` là `192.168.0.0/16` (mặc định của Calico), CNI có thể cấp cho node một khối IP nằm đúng trong dải đó. Khi ấy CNI cài route `blackhole`/`tunl0` đè lên route mạng của VM, và các node bị cắt khỏi host.

Cách xử lý:

1. Chọn `POD_CIDR` trong `config.env` sao cho **không trùng** với dải IP của VM, dải LAN nhà bạn và service CIDR mặc định (`10.96.0.0/12`). Mặc định của repo là `10.244.0.0/16`.
2. Restart VM không giúp được gì, vì CNI sẽ tạo lại route y như cũ. Phải chạy `./scripts/04-destroy.sh` rồi dựng lại.

Để xem log của Multipass trên macOS:

```bash
tail -f /Library/Logs/Multipass/multipassd.log
```

### `multipass launch` báo timeout ở bước 01

VM thường vẫn đang chạy cloud-init. Cứ chạy tiếp bước 02, script sẽ tự đợi. Muốn xem tiến độ cài đặt:

```bash
multipass exec k8s-master -- tail -f /var/log/cloud-init-output.log
```

### Worker không join được: token hết hạn

Token join chỉ có hiệu lực 24 giờ. Tạo lại bằng lệnh sau, rồi chạy lại `03-join-worker.sh`:

```bash
multipass exec k8s-master -- sudo kubeadm token create --print-join-command > join-command.sh
```

### `join-command.sh` có sẵn trong repo nhưng join lỗi

File này chứa IP và token của **cụm đã tạo nó**, nên không dùng được trên máy khác. Bước 02 sẽ ghi đè file, vì vậy luôn chạy 02 trước 03.

## Đổi phiên bản

- **Kubernetes**: sửa `K8S_VERSION` trong `config.env` theo dạng minor version `vX.Y` (ví dụ `v1.33`), sau đó destroy và tạo lại cụm. Biến này chỉ được đọc lúc tạo VM ở bước 01. Không truyền thẳng `cloud-init.yaml` cho `multipass launch`, vì file này là template, còn chứa placeholder `${K8S_VERSION}` chưa được thay.
- **Cilium**: sửa `CILIUM_VERSION` / `CILIUM_CLI_VERSION` trong `config.env`. Bản stable mới nhất xem tại [cilium/stable.txt](https://raw.githubusercontent.com/cilium/cilium/main/stable.txt) và [cilium-cli/stable.txt](https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt).
- **Calico**: sửa `CALICO_MANIFEST` trong `config.env`. Lưu ý v3.28.0 đã cũ so với Kubernetes 1.34, nên cân nhắc nâng lên bản mới hơn.
