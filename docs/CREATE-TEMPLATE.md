# Creating a NixOS Template for Proxmox

This guide shows how to create a NixOS template VM that can be cloned by the Crossplane Machine API.

## Prerequisites

- Proxmox VE cluster access
- SSH access to Proxmox host
- NixOS ISO (download from https://nixos.org/download)

## Option 1: Install from ISO (Standard Method)

### 1. Download NixOS ISO

```bash
# SSH to Proxmox host
ssh root@proxmox

# Download NixOS minimal ISO
cd /var/lib/vz/template/iso

# Get latest stable (24.05 as of 2026)
wget https://releases.nixos.org/nixos/24.05/latest-nixos-minimal-x86_64-linux.iso

# Or unstable
wget https://releases.nixos.org/nixos/unstable/latest-nixos-minimal-x86_64-linux.iso
```

### 2. Create VM from ISO

```bash
# Create VM with ID 9000 (or choose another ID)
qm create 9000 \
  --name nixos-1426-template \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-pci

# Add SCSI disk
qm set 9000 --scsi0 block:32

# Add CD-ROM with NixOS ISO (adjust filename to match downloaded ISO)
qm set 9000 --ide2 local:iso/nixos-minimal-25.11.5776.6c5e707c6b53-x86_64-linux.iso,media=cdrom

# Enable QEMU Guest Agent
qm set 9000 --agent enabled=1

# Set boot order
qm set 9000 --boot order=scsi0
```

### 3. Install NixOS

```bash
# Start the VM
qm start 9000

# Access console via Proxmox UI or VNC
# Follow NixOS installation:
```

**Minimal NixOS Configuration for Template:**

```nix
# /etc/nixos/configuration.nix
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Boot loader
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # Enable QEMU guest agent
  services.qemu-guest-agent.enable = true;

  # Cloud-init support (optional but recommended)
  services.cloud-init = {
    enable = true;
    network.enable = true;
  };

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Allow root SSH with key (for initial setup)
  users.users.root.openssh.authorizedKeys.keys = [
    # Add your SSH public key here temporarily
    # "ssh-ed25519 AAAA... your-key"
  ];

  # Networking (will be overridden by cloud-init if enabled)
  networking = {
    useDHCP = true;
    hostName = "nixos-template";
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    qemu-utils
  ];

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  # Clean up on shutdown to reduce template size
  boot.tmp.cleanOnBoot = true;

  system.stateVersion = "24.05";
}
```

**Installation Steps:**

```bash
# In the VM console (after booting from ISO)
# Optional: Set keyboard layout first
# loadkeys de_CH-latin1  # For Swiss German

sudo -i

# Partition disk (warnings about fstab are expected and can be ignored)
parted -s /dev/sda -- mklabel msdos
parted -s /dev/sda -- mkpart primary 1MiB 100%
parted -s /dev/sda -- set 1 boot on

# Format
mkfs.ext4 -L nixos /dev/sda1

# Mount
mount /dev/disk/by-label/nixos /mnt

# Generate config
nixos-generate-config --root /mnt

# Edit /mnt/etc/nixos/configuration.nix with the config above
nano /mnt/etc/nixos/configuration.nix

# Install
nixos-install

# Set root password when prompted
# Password: [enter a temporary password]

# Reboot
reboot
```

### 4. Prepare for Template Conversion

After NixOS is installed and booted:

```bash
# SSH into the VM
ssh root@<vm-ip>

# Clean up
sudo nix-collect-garbage -d
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
sudo rm -f /etc/ssh/ssh_host_*
sudo rm -f ~/.ssh/authorized_keys

# Clear machine ID (will be regenerated on clone)
sudo truncate -s 0 /etc/machine-id

# Clear network config
sudo rm -f /etc/nixos/hardware-configuration.nix

# Shutdown
sudo poweroff
```

### 5. Convert to Template

```bashQuick Start via Proxmox UI

1. **Create New VM** in Proxmox UI
   - VM ID: `9000`
   - Name: `nixos-24-05-template`
   - OS: Linux (kernel 6.x)
   - Memory: 2048 MB
   - Disk: 32 GB (SCSI, virtio-scsi-pci, write-back cache)
   - Network: virtio, vmbr0
   - CPU: 2 cores (host CPU type)

2. **Attach NixOS ISO**
   - Hardware → CD/DVD Drive → Select the uploaded ISO

3. **Install NixOS**
   - Start VM → Open Console
   - Follow installation steps from Option 1 above

4. **After Installation**
   - Remove ISO from CD/DVD drive
   - Clean up as shown in "Prepare for Template Conversion"
# Or create a custom installation script
# This requires more setup but allows fully automated installation
```

**Note:** NixOS doesn't provide official pre-built cloud qcow2 images. You must install from ISO or use automated installation tools.set 9000 --ciuser admin
qm set 9000 --ipconfig0 ip=dhcp

# Convert to template
qm template 9000
```

## Option 3: Manual Installation via Proxmox UI

1. **Create New VM** in Proxmox UI
   - VM ID: `9000`
   - Name: `nixos-23-11-template`
   - OS: Linux (kernel 5.x - 6.x)
   - Memory: 2048 MB
   - Disk: 32 GB (SCSI, virtio-scsi-pci)
   - Network: virtio, vmbr0
   - CPU: 2 cores

2. **Attach NixOS ISO**
   - Hardware → CD/DVD Drive → Select ISO

3. **Install NixOS**
   - Start VM
   - Open Console
   - Follow installation steps with the configuration above

4. **After Installation**
   - Clean up as shown above
   - Shutdown VM
   - Right-click VM → Convert to Template

## Verify Template

```bash
# List templates
qm list | grep template

# Check template configuration
qm config 9000

# Template should show:
# - template: 1
# - cloudinit drive
# - qemu-guest-agent: 1
```

## Update Composition

If you used a different VM ID than 9000:

```yaml
# In crossplane/package/composition.yaml
transforms:
  - type: map
    map:
      nixos-23-11-template: "9001"  # Your template VM ID
      nixos-24-05-template: "9002"
```

## Testing the Template

```bash
# Apply the secret
kubectl apply -f crossplane/config/proxmox-terraform-secret.yaml

# Apply composition
kubectl apply -f crossplane/package/composition.yaml

# Create a test VM
kubectl apply -f crossplane/claims/examples/basic.yaml

# Watch for VM creation
kubectl get machines -n infra-machines -w
```

## Cloud-Init Configuration

When cloning, cloud-init will:
- Set hostname from claim spec
- Configure network (DHCP or static)
- Add SSH authorized keys
- Set admin user

The Fabric flake will then configure the VM via NixOS.

## Multi-Node Considerations

**Important:** Template availability depends on your storage type.

### Local Storage (local-zfs, local-lvm, local)
- Template only exists on the node where it was created
- **You need to create the template on each Proxmox node** where you want to deploy VMs
- OR copy the template to other nodes:
  ```bash
  # From source node, get VM disk
  qm disk export 9000 scsi0 template-disk.qcow2
  
  # Copy to target node
  scp template-disk.qcow2 root@other-node:/tmp/
  
  # On target node, import
  qm create 9000 --name nixos-24-05-template --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
  qm importdisk 9000 /tmp/template-disk.qcow2 local-zfs
  qm set 9000 --scsi0 local-zfs:vm-9000-disk-0
  qm set 9000 --ide2 local-zfs:cloudinit
  qm set 9000 --boot order=scsi0
  qm set 9000 --agent enabled=1
  qm template 9000
  ```

### Shared Storage (NFS, Ceph, GlusterFS)
- Template accessible from all nodes in the cluster
- **Create template once**, use everywhere
- Recommended for production clusters

### Recommendation
For multi-node clusters, use shared storage or create the template with the **same VM ID (9000)** on each node so the composition works consistently across all nodes.

## Storage Recommendations

- **Shared Storage (NFS/Ceph)**: Best for clusters - create template once, use on any node
- **local-zfs**: Fast, copy-on-write - requires template on each node
- **local-lvm**: Good performance, thin provisioning - requires template on each node
- **local**: Simple, but no snapshots - requires template on each node

## Next Steps

1. **Decide on storage strategy:**
   - Shared storage: Create template once on any node
   - Local storage: Create template on each node (same VM ID: 9000)

2. **Create template VM (ID 9000)**
   - Follow Option 1, 2, or 3 above

3. **Test cloning manually:**
   ```bash
   qm clone 9000 999 --name test-clone
   qm start 999
   ```

4. **If successful, convert to template:**
   ```bash
   qm destroy 999  # Delete test clone
   qm template 9000
   ```

5. **Verify on all nodes (if using local storage):**
   ```bash
   # On each node
   qm list | grep 9000
   qm config 9000 | grep template
   ```

6. **Test with Crossplane:**
   ```bash
   kubectl apply -f crossplane/claims/examples/basic.yaml
   kubectl get machines -n infra-machines -w
   ```

## Troubleshooting

**VM doesn't start after clone:**
- Check if qemu-guest-agent is enabled
- Verify cloud-init drive exists
- Check boot order

**Network doesn't work:**
- Ensure cloud-init network is enabled
- Check bridge configuration (vmbr0)
- Verify DHCP or static IP config

**SSH doesn't work:**
- Check if SSH keys are in cloud-init config
- Verify openssh service is enabled
- Check firewall rules

**Template too large:**
- Run `nix-collect-garbage -d`
- Remove unnecessary packages
- Clear logs and cache

## Reference

- VM ID used in composition: `9000`
- Template name: `nixos-24-05-template`
- Storage: Configure in claim `spec.proxmox.storage`
- Network: Configure in claim `spec.proxmox.bridge`
- NixOS version: 24.05 (stable) or unstable

## Alternative: nixos-generators

For more automated template creation:

```bash
# Install nixos-generators
nix-shell -p nixos-generators

# Generate a Proxmox-compatible qcow2
nixos-generate -f proxmox-lxc -c ./template-config.nix

# Then import to Proxmox (requires manual qcow2 to VM conversion)
```

**Note:** This approach requires additional setup and is more complex than ISO installation.
