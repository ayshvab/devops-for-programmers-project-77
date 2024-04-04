VAULT_PASSWORD_FILE=./tmp/ansible-vault-password 

ansible-terraform-vars-generate:
	ansible-playbook --vault-password-file $(VAULT_PASSWORD_FILE) ./ansible/terraform.yml -i ./ansible/production/inventory.yml

ansible-vault-edit:
	ansible-vault edit --vault-password-file $(VAULT_PASSWORD_FILE) ./ansible/production/group_vars/all/vault.yml
