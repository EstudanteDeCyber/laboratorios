# Clone the project
git clone https://github.com/DefectDojo/django-DefectDojo
cd django-DefectDojo

# Run the application (for other profiles besides postgres-redis see  
# https://github.com/DefectDojo/django-DefectDojo/blob/dev/readme-docs/DOCKER.md)
docker compose up -d

# Obtain admin credentials. The initializer can take up to 3 minutes to run.
# Use docker compose logs -f initializer to track its progress.
# docker compose logs initializer | grep "Admin password:"

# Adicionar restart automatico
sed -i '/image:/a \    restart: unless-stopped' docker-compose.yml
