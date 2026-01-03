# Infrastructure Ansible

Starter Ansible project for managing Portainer stacks.

## Setup
- Run the setup script to configure git hooks:
  ```bash
  ./setup.sh
  ```
- Install Ansible (pipx: `pipx install ansible` or pip in a venv).
- Install required collection:
  ```bash
  ansible-galaxy collection install -r requirements.yml
  ```
- Update inventory in [inventories/hosts.ini](inventories/hosts.ini) with your Portainer manager host(s).
- Add your stack compose file at `stacks/example-stack.yml` or use a Jinja2 template (see [stacks/jellystat.yml.j2](stacks/jellystat.yml.j2)) and list it in `stacks` in [portainer-stacks.yml](portainer-stacks.yml).
- Export a Portainer API token:
  ```bash
  export PORTAINER_API_TOKEN="<token>"
  ```

## Run
Execute the playbook against the Portainer managers:
```bash
ansible-playbook portainer-stacks.yml --ask-vault-pass
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
    convert_secrets: true  # convert compose secrets into Portainer secrets
```

  ### Secrets and templated stacks
  - Keep secrets in an encrypted Vault file, e.g. copy [group_vars/portainer_managers/vault.example.yml](group_vars/portainer_managers/vault.example.yml) to `group_vars/portainer_managers/vault.yml` and encrypt it with `ansible-vault encrypt`.
  - Use Jinja templates for stacks that need secrets. Example template: [stacks/jellystat.yml.j2](stacks/jellystat.yml.j2) (expects `jellystat_jwt_secret` and `jellystat_db_password` from Vault).
  - The play renders templates to `/tmp/portainer-stacks/<name>.yml` on the control node, deploys them with `convert_secrets: true`, then deletes the rendered files.
  - Avoid `--diff` when deploying secret-bearing templates and consider `no_log` on any added secret tasks.

### Updating secrets
Store your vault password in `.vault_pass` (git-ignored) for convenience:
```bash
echo "your_vault_password" > .vault_pass
chmod 600 .vault_pass
```

Edit the encrypted vault file directly:
```bash
ansible-vault edit ./group_vars/portainer_managers/vault.yml --vault-password-file ./.vault_pass
```

This opens your editor with the decrypted contents and automatically re-encrypts on save.

## Notes
- Defaults live in [ansible.cfg](ansible.cfg) (YAML callback output, retry files disabled, host key checking off).
- `endpoint_id` defaults to `1`; change if your Portainer endpoint differs.
- Set `state: absent` in the `portainer_stack` task if you want to remove a stack.
