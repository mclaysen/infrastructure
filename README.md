# Infrastructure Ansible

Ansible project for managing infrastructure across a container-manager host and standalone Docker VPS hosts.

# General Process Used

1. Install the base OS on the machine
1. Setup SSH to use a key
   - ssh-keygen -t ed25519 -f {file location} -C "me@mclaysen.com"
   - Add to the ssh config
   ```txt
   Host {name}
    HostName {IP}
    User {Username}
    IdentityFile {key location}
    ```
   - Move public key to server
    ``` ssh-copy-id -i ~/.ssh/my_custom_key.pub your_username@remote_host  ```


## Setup
- Run the setup script to configure git hooks:
  ```bash
  ./setup.sh
  ```
- Install Ansible (pipx: `pipx install ansible` or pip in a venv).
- Install required collections:
  ```bash
  ansible-galaxy collection install -r requirements.yml
  ```
- Update inventory in [inventories/hosts.ini](inventories/hosts.ini):
  - `[container_manager]` - Host running native Compose stacks
  - `[tunnel_hosts]` - VPS hosts with direct Docker access
  
---

## Container-manager Infrastructure

Native Docker Compose stacks are deployed through Ansible on the container-manager host.

### Setup
- Configure `[container_manager]` in [inventories/hosts.ini](inventories/hosts.ini)
- Create and encrypt secrets:
  ```bash
  cp group_vars/portainer_managers/vault.example.yml group_vars/portainer_managers/vault.yml
  ansible-vault edit group_vars/portainer_managers/vault.yml --vault-password-file ./.vault_pass
  ```
- Configure stack settings in [group_vars/portainer_managers/vars.yml](group_vars/portainer_managers/vars.yml)
  and stack secrets in the encrypted vault. The directory name is retained for compatibility.

### Run
Deploy or update native Compose stacks:
```bash
ansible-playbook container-manager/playbooks/process-containers.yml \
  --limit container-VM --vault-password-file ./.vault_pass \
  -e immich_stack_enabled=true
```

The playbook reconciles multiple stacks. Immich remains gated by default, so
omit the extra variable only when its deployment should be skipped. Review
pending configuration changes before running the playbook.

### NVIDIA maintenance

Routine container-manager runs exclude kernel, DKMS, CUDA, and NVIDIA packages.
This prevents an ordinary OS update from triggering an unplanned driver rebuild.
For a planned driver update, run only the NVIDIA-tagged tasks with
`container_manager_nvidia_update=true`. This updates the kernel, driver
prerequisites, NVIDIA driver, and container toolkit as one operation; expect a
Docker restart and, when packages change, a reboot.

### Secrets and templated stacks
- Keep secrets in an encrypted Vault file
- Compose and environment templates live in [container-manager/stacks](container-manager/stacks)
- Environment files are rendered as `root:root` with mode `0600`. Most stack
  secrets use raw service-specific environment files; Cloudflare uses `.env`.
- Monitoring's Dozzle agent uses a separate environment file with the standard
  Compose parser for multiline PEM values. In the encrypted vault,
  `dozzle_cert_pem` must contain the complete certificate, and
  `dozzle_private_key` must contain a PKCS#8 private key in PEM form or its
  base64 body.
- Avoid `--diff` when deploying secret-bearing templates

---

## Docker VPS Infrastructure

For VPS hosts with direct Docker access (no Portainer).

### Initial VPS Setup
Bootstrap a fresh VPS with Docker:
```bash
ansible-playbook vps-bootstrap.yml --vault-password-file ./.vault_pass
```

This installs:
- Docker and Docker Compose plugin
- Firewall configuration
- Directory structure at `/opt/docker-stacks`

### Deploy Stacks
Configure stacks in [vps-stacks.yml](vps-stacks.yml) and deploy:
```bash
ansible-playbook vps-stacks.yml --vault-password-file ./.vault_pass
```

Stacks are deployed via `docker compose` directly on the VPS.

### VPS Secrets
Create and encrypt VPS-specific secrets:
```bash
cp group_vars/tunnel_hosts/vault.example.yml group_vars/tunnel_hosts/vault.yml
ansible-vault edit group_vars/tunnel_hosts/vault.yml --vault-password-file ./.vault_pass
```

---

## Home Server Infrastructure

The home server playbook configures libvirt, the bridge network, and these VMs:
- Home Assistant
- Reverse proxy
- Container manager

Run it with:

```bash
ansible-playbook home-server-playbook.yml --vault-password-file ./.vault_pass
```

Notes:
- `group_vars/home_server/vars.yml` must match the current physical NIC name used for the bridge, via `ethernet_ifname`.
- On Alma/RHEL 10, libvirt uses modular daemons. `home-server/tasks/initialize_libvirt.yml` enables and starts the required sockets and services.

### Libvirt SELinux "already in use" recovery

Symptom:
- Cockpit or Ansible fails to start a VM with `Requested operation is not valid: Setting different SELinux label on ... which is already in use`.

What this meant here:
- The VM file was not actively in use by another domain.
- Libvirt had stale `trusted.libvirt.security.*` xattrs on a VM-owned file.
- For BIOS guests this was the qcow2 disk.
- For the UEFI Home Assistant guest this was the NVRAM file at `/var/lib/libvirt/qemu/nvram/home-assistant-prod_VARS.fd`.

Quick checks:

```bash
sudo getfattr -d -m 'trusted.libvirt.security.*' /path/to/vm-file 2>/dev/null || true
sudo ps -efZ | grep '[q]emu' || true
sudo fuser -v /path/to/vm-file || true
sudo ls -lZ /path/to/vm-file
```

Recovery for a stopped VM file:

```bash
sudo virsh destroy <domain> 2>/dev/null || true

for attr in \
  trusted.libvirt.security.selinux \
  trusted.libvirt.security.dac \
  trusted.libvirt.security.ref_selinux \
  trusted.libvirt.security.ref_dac \
  trusted.libvirt.security.timestamp_selinux \
  trusted.libvirt.security.timestamp_dac
do
  sudo setfattr -x "$attr" /path/to/vm-file 2>/dev/null || true
done

sudo restorecon -Fv /path/to/vm-file
sudo systemctl restart virtqemud virtstoraged virtsecretd
sudo virsh start <domain>
```

Examples from this host:
- `proxy-prod` was fixed by clearing stale libvirt security xattrs on `/var/lib/libvirt/images-bulk/reverse-proxy.qcow2`.
- `home-assistant-prod` was fixed by clearing the same stale xattrs on `/var/lib/libvirt/qemu/nvram/home-assistant-prod_VARS.fd`.

If libvirt daemon sockets are missing after reboot, restart or enable them:

```bash
sudo systemctl enable --now \
  virtqemud.socket virtstoraged.socket virtnetworkd.socket \
  virtnodedevd.socket virtsecretd.socket
```

---

## General

### Updating secrets
Store your vault password in `.vault_pass` (git-ignored) for convenience:
```bash
echo "your_vault_password" > .vault_pass
chmod 600 .vault_pass
```

Edit encrypted vault files:
```bash
# Portainer secrets
ansible-vault edit ./group_vars/portainer_managers/vault.yml --vault-password-file ./.vault_pass

# VPS secrets
ansible-vault edit ./group_vars/tunnel_hosts/vault.yml --vault-password-file ./.vault_pass
```

## Notes
- Configuration defaults in [ansible.cfg](ansible.cfg)
- Pre-commit hook validates encrypted vault files aren't accidentally committed as plaintext
- Use Jinja2 templates in `stacks/` for compose files needing secret injection

## TODO
- Add monitoring for intermittent LAN health issues, including blackbox probes for key local services like the router, Cockpit, and Home Assistant.
- Add host-level alerts for bridge and NIC degradation, especially drops/errors on `enp4s0`, `br0`, and VM tap interfaces.
- Add lightweight Layer 2 visibility for broadcast and ARP spikes so misbehaving devices can be identified faster.
- Ensure Docker waits for the home videos NFS mount before restoring Jellyfin after host reboot, so the container does not start against an empty bind mount.
- Set up Firewalld on the container manager host, including the Python bindings needed for Ansible-managed firewall rules.
