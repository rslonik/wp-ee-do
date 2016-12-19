#!/bin/bash

if [ -z $1 ] || [ -z $2 ] 
then
    echo "USO: ./deploy.sh nome_droplet url_site";
    echo "** Lembre-se de configurar as variáreis Nome e Email dentro do script";
    exit 1;
fi

NAME=$1;
URL=$2;
YOUR_NAME="Seu Nome";
YOUR_EMAIL="email@email.com";
SSH_KEYS=;

if [[ -z $SSH_KEYS ]];then
    echo "Adicione o fingerprint de uma de suas chaves na variável SSH_KEYS";
    echo "Vou rodar 'doctl compute ssh-key list' e ver se existe alguma chave na sua conta";
    echo $(doctl compute ssh-key list | cut -f3);
    exit 1;
fi

echo "NOME DROPLET É: $NAME";
echo "URL DO SITE É: $URL";

read -r -p "Está certo disso? [y/N] " response
if [[ ! $response =~ ^([yY][eE][sS]|[yY])$ ]]
then
    echo 'Cancelei';
    exit 1;
fi
# DROPLET
DROP_EXISTS=$(doctl compute droplet list | grep $NAME)
if [[ $DROP_EXISTS ]]; then
    echo "ERRO: já existe um droplet chamado $NAME";
    exit 1;
fi
# TODO: ANTES DE CRIAR VERIFICAR SE JÁ NÃO EXISTE UM DROP COM O MESMO $NAME
echo "Vou criar um drop agora com o nome $NAME";
doctl compute droplet create $NAME --image ubuntu-16-04-x64 --size 1gb --region nyc3 --ssh-keys $SSH_KEYS --wait

# GET DROPLET IP
IP=$(doctl compute droplet list --format Name,PublicIPv4 | grep $NAME | cut -f2);
echo "Droplet $NAME criado e tem o IP $IP";

echo "Entrando com SSH em $IP";
# SSH DROPLET
sleep 10;
ssh -p 22 -oStrictHostKeyChecking=no -t root@$IP << HERE
    echo "Pronto! Agora vou configurar o SSH para apenas porta 2998";
    sleep 2;

    # SSH CONFIG
    sed -i -e 's/Port 22/Port 2998/g' /etc/ssh/sshd_config;
    sed -i -e 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config;
    service ssh restart;
    echo "Pronto! Agora vou configurar o Firewall com UFW";
    sleep 2;

    # FIREWALL
    # 11371 is for GPG server
    ufw allow 2998,80,443,11371/tcp;
    ufw --force enable;
    echo "Firewall configurado para portas 2998 80 e 443 e ativado";
    sleep 2;

    echo "Agora instalar o EASYENGINE";
    sleep 2;

    # GIT
    # Install git before EE, so we can config name and email beforehand
    apt-get -y install git;
    git config --global user.name "$YOUR_NAME";
    git config --global user.email "$YOUR_EMAIL";

    # EASYENGINE
    wget -qO ee rt.cx/ee && sudo bash ee;

    echo "Pronto! Agora vou instalar o Duplicity/Boto para os Backups";
    sleep 2;
    # DUPLICITY
    apt-add-repository -y ppa:duplicity-team/ppa;
    apt-get update;
    apt-get -y install duplicity;
    apt-get -y install python-pip;
    pip install boto;
    echo "Pronto! Agora vou criar as chaves GPG dos Backups";
    sleep 2;

    # GPG
    apt-get -y install haveged;
    #apt-get -y install mailutils;
    echo -e "Key-Type: RSA \nName-Real: $YOUR_NAME \nName-Comment: do-backup \nName-Email: $YOUR_EMAIL" > key;
    sleep 2;
    gpg --gen-key --batch key;
    gpg --export -a "$YOUR_NAME" > ~/do-backup-public.key;
    gpg --export-secret-key -a "$YOUR_NAME" > ~/do-backup-private.key;
    rm ~/key;
    echo "Pronto! Finalmente vou criar o seu site";
    sleep 2;

    # SITE CREATE
    ee site create $URL --php7 --wpredis --experimental

    echo "TUDO FEITO! Agora basta configurar sua entrada A apontando para $IP e acessar seu site em $URL";
    sleep 2;
HERE

scp root@$IP:do-backup-public.key .;
scp root@$IP:do-backup-private.key .;

if [[ -z $HOST ]]; then
    exit 1;
fi
echo "HOST $NAME\nHostName $IP\nPort 2998\nUser root\nServerAliveInterval 60\n" >> ~/.ssh/config;
echo "Adicionei o HOST $NAME no seu ~/.ssh/config\nPara acessar use: ssh $NAME";
