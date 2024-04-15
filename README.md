### Hexlet tests and linter status:
[![Actions Status](https://github.com/ayshvab/devops-for-programmers-project-77/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/ayshvab/devops-for-programmers-project-77/actions)

#### Result
[https://devops.ant0n.xyz](https://devops.ant0n.xyz)

#### Prerequisites
0. `make ansible-install`
1. Create ./tmp/ansible-vault-password file in the project root directory with Ansible Vault password
2. `make ansible-terraform-vars-generate` 
3. Add `ssh_public_key_file` and `ssh_private_key_file` to generated `secret.auto.tfvars`

#### Setup Web Servers: `make setup`

#### Deploy Web Servers: `make deploy`


