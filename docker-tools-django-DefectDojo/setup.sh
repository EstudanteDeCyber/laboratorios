# Clone the project
git clone https://github.com/DefectDojo/django-DefectDojo
cd django-DefectDojo

# Building Docker images
docker compose build

# Run the application (for other profiles besides postgres-redis see  
# https://github.com/DefectDojo/django-DefectDojo/blob/dev/readme-docs/DOCKER.md)
docker compose up -d

cat << 'EOF' | sudo tee /etc/systemd/system/dojo.service > /dev/null
[Unit]
Description=Serviço para subir o projeto Django DefectDojo via Docker Compose
After=network-online.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/home/vagrant/lab-sec/docker-tools-django-DefectDojo/django-DefectDojo/
ExecStart=/usr/bin/docker compose -f docker-compose.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Recarrega os serviços systemd para reconhecer o novo
sudo systemctl daemon-reload

# Habilita para iniciar com o sistema
sudo systemctl enable dojo.service

# Obtain admin credentials. The initializer can take up to 3 minutes to run.
# Use docker compose logs -f initializer to track its progress.
# docker compose logs initializer | grep "Admin password:"
