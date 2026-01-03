# Infrastructure Ansible

Ansible project for managing infrastructure across Portainer-managed hosts and standalone Docker VPS hosts.

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
  - `[portainer_managers]` - Hosts managed via Portainer API
  - `[tunnel_hosts]` - VPS hosts with direct Docker access
  
---

## Portainer-Managed Infrastructure

For hosts running Portainer where stacks are deployed via the Portainer API.

### Setup
- Add hosts to `[portainer_managers]` in [inventories/hosts.ini](inventories/hosts.ini)
- Create and encrypt secrets:
  ```bash
  cp group_vars/portainer_managers/vault.example.yml group_vars/portainer_managers/vault.yml
  ansible-vault edit group_vars/portainer_managers/vault.yml --vault-password-file ./.vault_pass
  ```
- Add Portainer API token and stack secrets to vault
- Configure stacks in [portainer-stacks.yml](portainer-stacks.yml)

### Run
Deploy or update Portainer stacks:
```bash
ansible-playbook portainer-stacks.yml --vault-password-file ./.vault_pass
```

### Stacks configuration
`stacks` is a list of compose deployments. Example entry:
```yaml
stacks:
  - name: myapp
    file: stacks/myapp.yml            # or template: stacks/myapp.yml.j2
    stack_type: standalone  # or swarm
    endpoint_id: 1
    env:
      - name: LOG_LEVEL
        value: info
    prune: true            # remove orphaned services
    pull_images: false     # set true to always pull
```

### Secrets and templated stacks
- Keep secrets in an encrypted Vault file
- Use Jinja templates for stacks that need secrets. Example: [stacks/jellystat.yml.j2](stacks/jellystat.yml.j2)
- The play renders templates to `/tmp/portainer-stacks/<name>.yml` on the control node, deploys them, then deletes the rendered files
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
