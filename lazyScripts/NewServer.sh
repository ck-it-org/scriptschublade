#!/bin/bash

apt-get update && apt-get dist-upgrade -y && apt autoremove -y --purge && apt-get clean -y
timedatectl set-timezone Europe/Berlin
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo 'vm.swappiness = 10' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
apt-get install -y curl mc htop ca-certificates cron sudo
curl -fsSL https://gist.githubusercontent.com/vsefer/f2696e997e1ab4316a50/raw/78544b83cb85428ba057fb02f8bbdd2bae7681db/htz-bashrc -o /root/.bashrc
(crontab -l 2>/dev/null; echo "45 4 * * * apt-get update && apt-get dist-upgrade -y && apt autoremove -y --purge && apt-get clean -y") | crontab -

useradd ck
usermod -aG sudo ck
echo 'ck     ALL=(ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers
mkdir /home/ck
mkdir /home/ck/.ssh
cp /root/.ssh/authorized_keys /home/ck/.ssh/authorized_keys
chown -R ck:ck /home/ck
chmod 700 /home/ck/.ssh
chmod 600 /home/ck/.ssh/authorized_keys

# Docker
printf "Install Docker? [y,n]"
read -n 1 -s doit;

case $doit in  
  y|Y) 
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose
    docker run -d --network host --name watchtower-once -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower:latest --cleanup --include-stopped --run-once
    (crontab -l 2>/dev/null; echo "55 4 * * * docker start watchtower-once -a") | crontab - ;; 
n|N) echo no ;; 
  *) echo dont know ;; 
esac

# Nginx
printf "Install Webserver? [p(nginx),a(pache), n]" >&2
read -n 1 -s doit2

case $doit2 in  
  p|P) 
    apt install -y nginx certbot python3-certbot-dns-cloudflare
    mkdir -p /root/.secrets && touch /root/.secrets/cloudflare.ini

    read -p "Cloudflare API-Key?" key
    echo "dns_cloudflare_api_token = " $key | sudo tee /root/.secrets/cloudflare.ini > /dev/null

    chmod 400 /root/.secrets/cloudflare.ini

    certbot certonly --non-interactive --agree-tos -m support@ck-it.org --dns-cloudflare \
    --dns-cloudflare-credentials /root/.secrets/cloudflare.ini \
    -d *.ck-it.org  
;; 
  n|N) 
    apt install -y apache2 certbot python3-certbot-dns-cloudflare
    mkdir -p /root/.secrets && touch /root/.secrets/cloudflare.ini

    read -p "Cloudflare API-Key?" key
    echo "dns_cloudflare_api_token = " $key | sudo tee /root/.secrets/cloudflare.ini > /dev/null

    chmod 400 /root/.secrets/cloudflare.ini

    certbot certonly --non-interactive --agree-tos -m support@ck-it.org --dns-cloudflare \
    --dns-cloudflare-credentials /root/.secrets/cloudflare.ini \
    -d *.ck-it.org  
;;
n|N) echo no ;; 
  *) echo dont know ;; 
esac

printf "Install Portainer? [y(https),h(ttp), n]" >&2
read -n 1 -s doit3

case $doit3 in  
  h|H) 
  docker run -d -p 9000:9000 -p 8000:8000 \
    --name portainer --restart always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
;; 
  y|Y) 
  docker run -d -p 9443:9443 -p 8000:8000 \
    --name portainer --restart always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    -v /etc/letsencrypt/live/ck-it.org:/certs/live/ck-it.org:ro \
    -v /etc/letsencrypt/archive/ck-it.org:/certs/archive/ck-it.org:ro \
    portainer/portainer-ce:latest \
    --sslcert /certs/live/ck-it.org/fullchain.pem \
    --sslkey /certs/live/ck-it.org/privkey.pem
;; 
n|N) echo no ;; 
  *) echo dont know ;; 
esac
