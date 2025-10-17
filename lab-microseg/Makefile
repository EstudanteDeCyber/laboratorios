.PHONY: up provision deploy deploy-clean deploy-challenges deploy-challenges-attacker deploy-challenges-pci cleanup-challenges reset validate

up:
	vagrant up

provision:
	ansible-playbook -i inventory.ini lab-provision.yml

deploy:
	ansible-playbook -i inventory.ini lab-deploy-apps.yml

deploy-clean:
	ansible-playbook -i inventory.ini lab-deploy-clean.yml

# ---------- Novos alvos para os desafios ----------
deploy-challenges:
	ansible-playbook -i inventory.ini lab-deploy-challenges.yml

deploy-challenges-attacker:
	ansible-playbook -i inventory.ini lab-deploy-challenges.yml --tags attacker

deploy-challenges-pci:
	ansible-playbook -i inventory.ini lab-deploy-challenges.yml --tags pci

cleanup-challenges:
	ansible-playbook -i inventory.ini lab-deploy-challenges.yml --tags cleanup
# -------------------------------------------------

reset:
	ansible all -m shell -a "/opt/lab/scripts/lab-reset.sh" -i inventory.ini || true
	vagrant destroy -f || true

validate:
	./validate.sh