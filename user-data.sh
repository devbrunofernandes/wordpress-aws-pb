#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "INFO: Configurando variáveis de ambiente da AWS via SSM..."
export AWS_REGION="us-east-1"
export DB_HOST=$(aws ssm get-parameter --name "/wordpress/db_host" --with-decryption --query Parameter.Value --output text)
export DB_USER=$(aws ssm get-parameter --name "/wordpress/db_user" --with-decryption --query Parameter.Value --output text)
export DB_PASSWORD=$(aws ssm get-parameter --name "/wordpress/db_password" --with-decryption --query Parameter.Value --output text)
export DB_NAME=$(aws ssm get-parameter --name "/wordpress/db_name" --with-decryption --query Parameter.Value --output text)

export ALB_DNS_NAME=$(aws ssm get-parameter --name "/wordpress/alb_dns" --with-decryption --query Parameter.Value --output text)

export EFS_FILE_SYSTEM_ID=$(aws ssm get-parameter --name "/wordpress/efs" --with-decryption --query Parameter.Value --output text)
EFS_MOUNT_POINT="/mnt/efs"
WORDPRESS_DATA_DIR="${EFS_MOUNT_POINT}/wordpress"

echo "--- INICIANDO SCRIPT USER-DATA COMPLETO (EFS + DOCKER) ---"

echo "INFO: Atualizando o sistema..."
dnf update -y

echo "INFO: Instalando dependências (git, nfs, docker)..."
dnf install -y git unzip nfs-utils docker

echo "INFO: Instalando o repositório do AWS EFS..."
curl -fsSL https://repos.efs.aws/install | bash

echo "INFO: Instalando o amazon-efs-utils..."
dnf install -y amazon-efs-utils

echo "INFO: Criando o ponto de montagem ${EFS_MOUNT_POINT}..."
mkdir -p "${EFS_MOUNT_POINT}"

echo "INFO: Adicionando o EFS ao /etc/fstab para montagem automática..."
grep -qs "${EFS_FILE_SYSTEM_ID}" /etc/fstab || printf "${EFS_FILE_SYSTEM_ID}:/ ${EFS_MOUNT_POINT} efs tls,_netdev\n" >> /etc/fstab

echo "INFO: Montando todos os sistemas de arquivos listados no fstab (tentativas)..."
retryCnt=15; waitTime=30; while true; do mount -a -t efs,nfs4 defaults; if [ $? = 0 ] || [ $retryCnt -lt 1 ]; then echo "INFO: Sistemas de arquivos montados."; break; fi; echo "WARN: Falha ao montar, tentando novamente em ${waitTime}s..."; ((retryCnt--)); sleep $waitTime; done;

echo "INFO: Verificando se o EFS foi montado com sucesso..."
df -h | grep "${EFS_MOUNT_POINT}"

echo "INFO: Criando o diretório de dados do WordPress dentro do EFS..."
mkdir -p "${WORDPRESS_DATA_DIR}"
chmod 777 "${WORDPRESS_DATA_DIR}"

echo "INFO: Iniciando e habilitando o serviço do Docker..."
systemctl start docker
systemctl enable docker

DOCKER_COMPOSE_VERSION="v2.27.0"
echo "INFO: Baixando o Docker Compose ${DOCKER_COMPOSE_VERSION}..."
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

echo "INFO: Aplicando permissões de execução ao Docker Compose..."
chmod +x /usr/local/bin/docker-compose

echo "INFO: Navegando para o diretório /root para instalar o AWS CLI..."
cd /root

echo "INFO: Clonando o repositório da aplicação..."
cd /root
git clone https://github.com/devbrunofernandes/wordpress-aws-pb.git
cd wordpress-aws-pb

echo "INFO: Subindo a aplicação com Docker Compose..."
docker-compose up -d

echo "--- SCRIPT USER-DATA FINALIZADO COM SUCESSO ---"