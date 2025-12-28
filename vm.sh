# Function to check dependencies
check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "ERROR" "Missing dependencies: ${missing_deps[*]}"
        print_status "INFO" "On Ubuntu/Debian, try: sudo apt install qemu-system cloud-image-utils wget"
        exit 1
    fi
}
#!/bin/bash
set -e

# =============================
# VendorNodes VM Manager
# =============================

clear
cat << "EOF"
========================================================================
 _    __              _           _   _           _
| |  / /__ _ __   ___| |__   ___ | |_(_) ___  ___| |
| | / / _ \ '_ \ / __| '_ \ / _ \| __| |/ _ \/ __| |
| |/ /  __/ | | | (__| | | | (_) | |_| |  __/\__ \_|
|___/ \___|_| |_|\___|_| |_|\___/ \__|_|\___||___(_)

                     POWERED BY VENDORNODES
========================================================================
EOF

# Defaults (HARD SET)
MEMORY=98000
CPUS=8
DISK_SIZE="5000G"
VM_DIR="$HOME/vms"

mkdir -p "$VM_DIR"

read -p "Enter VM name: " VM_NAME
read -p "Choose OS (ubuntu22 / ubuntu24 / debian12): " OS

case "$OS" in
  ubuntu22)
    IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    ;;
  ubuntu24)
    IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    ;;
  debian12)
    IMG_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    ;;
  *)
    echo "Invalid OS"
    exit 1
    ;;
esac

IMG_PATH="$VM_DIR/$VM_NAME.qcow2"
SEED_IMG="$VM_DIR/$VM_NAME-seed.img"

echo "[+] Downloading OS image..."
wget -q --show-progress "$IMG_URL" -O "$IMG_PATH"

echo "[+] Resizing disk to $DISK_SIZE"
qemu-img resize "$IMG_PATH" "$DISK_SIZE"

# Cloud-init
cat > user-data <<EOF
#cloud-config
hostname: VendorNodes
preserve_hostname: false
users:
  - name: root
    lock_passwd: false
    shell: /bin/bash
runcmd:
  - echo "VendorNodes" > /etc/hostname
  - hostname VendorNodes
  - sed -i 's/^#Port 22/Port 22/' /etc/ssh/sshd_config
  - systemctl restart ssh
EOF

cat > meta-data <<EOF
instance-id: $VM_NAME
local-hostname: VendorNodes
EOF

cloud-localds "$SEED_IMG" user-data meta-data

rm -f user-data meta-data

echo "[+] Starting VM"
echo "[+] RAM: $MEMORY MB | CPU: $CPUS | DISK: $DISK_SIZE"
echo "[+] Login will show: root@VendorNodes"

qemu-system-x86_64 \
  -enable-kvm \
  -m "$MEMORY" \
  -smp "$CPUS" \
  -drive file="$IMG_PATH",format=qcow2 \
  -drive file="$SEED_IMG",format=raw \
  -net nic \
  -net user,hostfwd=tcp::2222-:22 \
  -nographic

