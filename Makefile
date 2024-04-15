VAULT_PASSWORD_FILE=./tmp/ansible-vault-password

ansible-install:
	ansible-galaxy install -r requirements.yml

ansible-vault-edit:
	ansible-vault edit --vault-password-file $(VAULT_PASSWORD_FILE) ./ansible/production/group_vars/all/vault.yml

ansible-terraform-vars-generate:
	ansible-playbook --vault-password-file $(VAULT_PASSWORD_FILE) ./ansible/terraform.yml

tf-generate-local-files:
	terraform -chdir=terraform apply --target local_file.ansible_inventory --target local_file.ssh_config --target local_file.tf_ansible_vars_file --target local_sensitive_file.db_prepared_ssl_cert

tf-plan:
	terraform -chdir=terraform plan

tf-apply:
	terraform -chdir=terraform apply

setup: 
	ansible-playbook --vault-password-file $(VAULT_PASSWORD_FILE) ./ansible/playbook.yml -t setup -i ./ansible/production/inventory.ini -vv

deploy:
	ansible-playbook --vault-password-file $(VAULT_PASSWORD_FILE) ./ansible/playbook.yml -t deploy -i ./ansible/production/inventory.ini -vv

