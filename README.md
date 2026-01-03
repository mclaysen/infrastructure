# Infrastructure Ansible

Starter Ansible project for managing Portainer stacks.

## Setup
- Install Ansible (pipx: `pipx install ansible` or pip in a venv).
- Install required collection:
  ```bash
  ansible-galaxy collection install -r requirements.yml
  ```
- Update inventory in [inventories/hosts.ini](inventories/hosts.ini) with your Portainer manager host(s).
- Add your stack compose file at `stacks/example-stack.yml` (or adjust `compose_file` in [portainer-stacks.yml](portainer-stacks.yml)).
- Export a Portainer API token:
  ```bash
  export PORTAINER_API_TOKEN="<token>"
  ```

## Run
Execute the playbook against the Portainer managers:
```bash
ansible-playbook portainer-stacks.yml
```

## Notes
- Defaults live in [ansible.cfg](ansible.cfg) (YAML callback output, retry files disabled, host key checking off).
- `endpoint_id` defaults to `1`; change if your Portainer endpoint differs.
- Set `state: absent` in the `portainer_stack` task if you want to remove a stack.
