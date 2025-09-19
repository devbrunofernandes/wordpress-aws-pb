#!/bin/bash

# Deletar instalacao antigas possiveis do docker
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Instalacao Docker
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install ca-certificates curl unzip
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ir para o diretorio Home
cd /home/ubuntu

# instalando o aws cli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install -y unzip
unzip awscliv2.zip
sudo ./aws/install
rm awscliv2.zip
rm -rf aws

# configurando o aws cli
export AWS_REGION="us-east-1"

# criando variaveis de ambiente para o docker-compose.yml
export DB_HOST=$(aws ssm get-parameter --name "/wordpress/db_host" --with-decryption --query Parameter.Value --output text)
export DB_USER=$(aws ssm get-parameter --name "/wordpress/db_user" --with-decryption --query Parameter.Value --output text)
export DB_PASSWORD=$(aws ssm get-parameter --name "/wordpress/db_password" --with-decryption --query Parameter.Value --output text)
export DB_NAME=$(aws ssm get-parameter --name "/wordpress/db_name" --with-decryption --query Parameter.Value --output text)

# instalando o docker-compose.yml
git clone https://github.com/devbrunofernandes/wordpress-aws-pb.git
cd wordpress-aws-pb

# subindo a aplicacao
sudo -E docker compose up -d