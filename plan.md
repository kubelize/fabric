# Plan: GitOps-managed Nix machines on Proxmox with Crossplane (cleanest option)

## Goal
Use Git as the single source of truth to:
- Provision VMs on Proxmox via Crossplane
- Have each VM converge to its desired configuration via Nix (self-managed)
- Keep Kubernetes as the “infra control plane” without making VMs depend on the cluster for day-2 operations

This plan intentionally avoids “push config from the cluster” as the primary mechanism. VMs should be able to rebuild/converge even if Kubernetes is down.

---

## Architecture (cleanest boundary)
- **Crossplane**: provisioning and infra primitives (VM, disks, network, DNS if any).
- **NixOS on the VM**: desired OS + services config, pulled from Git and applied locally.
- **Git**: source of truth for BOTH:
  - Crossplane “Machine” claims (what machines exist)
  - Nix flake configs (what those machines should be)

Optional later:
- **Argo Workflows**: orchestrated rollouts/rebuilds (not required for MVP).

---

## Repos and source of truth
### Option A (single repo, simplest)
`homelab-infra/`
- `crossplane/`
  - `claims/` (Machine CRs)
  - `compositions/` (XRD + Composition + provider configs)
- `nix/`
  - `flake.nix`
  - `hosts/`
  - `modules/`

### Option B (two repos, cleaner separation)
- `homelab-crossplane/`
- `homelab-nix/`

Pick one; both are GitOps-friendly. Option A is easiest to start.

---

## Desired state model (Kubernetes API)
Define a composite resource as your public interface:

- XRD: `XMachine` (cluster-scoped)
- Claim: `Machine` (namespace-scoped)

A `Machine` should declare only intent, not implementation details.

### Suggested `Machine` spec fields
- `class`: VM sizing class (cpu/mem/disk)
- `hostname`
- `network`:
  - `ip` (static) OR `dhcp: true`
  - `gateway`, `dns`, `cidr` (if static)
- `proxmox`:
  - `node` (optional: pin)
  - `storage` (pool)
  - `vlan` / bridge
- `image`: template identifier (NixOS base template)
- `nix`:
  - `flakeRef`: e.g. `git+https://...#dns01`
  - `channel`/`lock`: controlled via flake.lock in repo
- `bootstrap`:
  - `sshAuthorizedKeys` (or a reference to a secret)
  - `adminUser`
- `tags` / `role` (for grouping)

---

## Cleanest converge strategy (VM self-converges)
### Principle
Crossplane provisions VM and injects *minimal bootstrap* to:
1) ensure SSH works
2) set hostname/network
3) point the VM at the Nix flake it should apply
4) run `nixos-rebuild switch` locally
5) (optional) set up a timer to periodically re-apply

The VM becomes self-healing and Git-driven.

### Why this is clean
- Git is the truth; VM pulls from Git
- K8s can be down and machines still converge on boot/timer
- No need for K8s to hold SSH keys to all VMs for day-2

---

## Proxmox prerequisites
1) **A NixOS VM template** in Proxmox
   - Installed once
   - Has QEMU guest agent enabled
   - Has SSH enabled
   - Has cloud-init support (recommended) OR a predictable first-boot mechanism
2) Proxmox API credentials for Crossplane provider
3) A network approach:
   - Prefer static IPs for “core” infra VMs OR DHCP reservations

---

## Crossplane prerequisites
1) Install Crossplane
2) Install a **Proxmox Crossplane provider**
   - Evaluate provider maturity; pick one you trust
   - Configure ProviderConfig with Proxmox API endpoint + creds
3) Add XRD + Composition for `XMachine`
4) Add a namespace for claims, e.g. `infra-machines`

---

## Bootstrap mechanism (recommended approach)
### Prefer: cloud-init user-data (or Proxmox equivalent)
Inject user-data that:
- creates admin user + authorized keys
- sets hostname
- configures networking (if static)
- writes a small file like `/etc/nix-flake-target` containing `flakeRef`
- runs a one-shot systemd unit that applies the flake

### One-shot systemd unit outline (conceptual)
- `nix-gitops-apply.service`
  - After network-online
  - Pull flake from Git
  - `nixos-rebuild switch --flake <ref>`
  - On success: disable itself

Optional:
- `nix-gitops-apply.timer` (daily) for drift control
  - Use with caution; start with “manual runs only” until confident.

---

## Nix repo structure (host-per-file)
`nix/`
- `flake.nix`
- `hosts/`
  - `dns01/`
    - `configuration.nix`
  - `docker01/`
    - `configuration.nix`
- `modules/`
  - `base.nix` (users, ssh, journald, baseline hardening)
  - `networking-static.nix`
  - `docker-host.nix`
  - `dns-unbound.nix` (or bind)
  - `monitoring-agent.nix`

Host configs should be tiny; most logic goes into modules.

---

## Secrets strategy (keep it clean)
### MVP: avoid secrets in Nix
Start with machines that don’t need sensitive secrets.

### Endgame: VM pulls secrets from Vault
- VM authenticates to Vault (AppRole, TLS identity, or another strong method)
- Nix config references a local path populated by a Vault-agent or one-shot fetcher
- No long-lived secrets stored in Git, no secrets pushed from K8s

Avoid “K8s stores SSH keys and pushes secrets to VMs” unless you accept the blast radius.

---

## GitOps workflow (end-to-end)
1) Commit `Machine` claim YAML to `crossplane/claims/`
2) GitOps controller (Argo CD / Flux) applies it
3) Crossplane provisions VM in Proxmox
4) VM boots from NixOS template and runs bootstrap
5) VM pulls its flake and converges
6) Validation is done via:
   - VM-level systemd health
   - Prometheus/monitoring checks
   - optional post-provision checks later via a Workflow

---

## Operational model
### Creating a new machine
- Add `Machine` claim + corresponding `nix/hosts/<name>/configuration.nix`
- Commit → GitOps applies → VM appears → converges

### Updating a machine
- Change Nix config in Git
- Trigger converge via one of:
  - SSH in and run `nixos-rebuild switch --flake ...` (manual)
  - reboot (if bootstrap applies at boot)
  - enable a timer (automated drift control)
  - later: Argo Workflow “rollout all machines in group X”

### Destroying a machine
- Delete `Machine` claim → Crossplane deletes VM
- Optionally keep host config in Git for rebuild

---

## Safety and guardrails
- Use VM sizing classes so you don’t repeat CPU/mem logic everywhere
- Use “groups” via labels/tags (`role=dns`, `tier=core`)
- Don’t enable automatic daily re-apply at first
- Ensure rollback is available:
  - NixOS generations + boot menu
  - keep a known-good template snapshot in Proxmox

---

## MVP milestone checklist
### Milestone 0: Foundations
- [ ] NixOS template VM exists in Proxmox
- [ ] Crossplane installed
- [ ] Proxmox provider installed and can create a test VM

### Milestone 1: First Git-managed machine
- [ ] Add XRD + Composition for `XMachine`
- [ ] Apply one `Machine` claim (test VM)
- [ ] VM boots and applies flake
- [ ] VM exposes SSH and expected service state

### Milestone 2: Expand to 2–3 roles
- [ ] `docker01` config module
- [ ] `dns01` config module
- [ ] baseline module reused across hosts

### Milestone 3: Secrets (optional)
- [ ] Vault agent or fetcher on VM
- [ ] DNS secrets/certs sourced from Vault

### Milestone 4: Orchestrated rollouts (optional)
- [ ] Argo Workflow to roll changes with concurrency limits
- [ ] Manual approval gates for risky changes (reboots, DNS)

---

## Notes on “cleanest option”
- Crossplane provisions; Nix converges locally; Git drives both.
- Avoid pushing Nix config from the cluster as your primary mechanism.
- Add Argo Workflows only once the self-converge loop is solid.

---
