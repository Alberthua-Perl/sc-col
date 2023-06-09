#!/bin/bash
#
# Configure Red Hat Quay v3.3.0 internal registry.
# Deploy method through docker-ce engine.
# 
# Usage:
#   - run 'config_quay' function
#   - config quay through Web UI
#   - run 'deploy_quay' function
#    
# Modified by hualf on 2021-12-19.
# 

config_quay() {
  ### install docker-ce ###
  echo "[*] Check docker-ce package..."
  if $(rpm -q docker-ce > /dev/null); then
    echo "    ---> docker-ce has been installled..."
  else
    echo "    ---> Install docker-ce package..."
    yum install -y docker-ce
    systemctl enable docker.service
    systemctl start docker.service
  fi
  
  ### create mysql database container ###
  echo "[*] Create MySQL database container..."
  mkdir -p /var/lib/mysql
  chmod 777 /var/lib/mysql
  export MYSQL_CONTAINER_NAME=quay-mysql
  export MYSQL_DATABASE=enterpriseregistrydb
  export MYSQL_PASSWORD=redhat
  export MYSQL_USER=quayuser
  export MYSQL_ROOT_PASSWORD=redhat
  
  if $(docker images | grep mysql > /dev/null); then
    echo "    ---> mysql-57-rhel container image downloaded..."
  else
    echo "    ---> Loading mysql-57-rhel container image..."
    docker load --input /root/mysql-57-rhel7.tar
  fi
  
  docker run \
    --detach \
    --restart=always \
    --env MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} \
    --env MYSQL_USER=${MYSQL_USER} \
    --env MYSQL_PASSWORD=${MYSQL_PASSWORD} \
    --env MYSQL_DATABASE=${MYSQL_DATABASE} \
    --name ${MYSQL_CONTAINER_NAME} \
    --privileged=true \
    --publish 3306:3306 \
    -v /var/lib/mysql:/var/lib/mysql/data \
    registry.access.redhat.com/rhscl/mysql-57-rhel7
  
  ### create redis database container ###
  echo "[*] Create Redis database container..."
  mkdir -p /var/lib/redis
  chmod 777 /var/lib/redis
  
  if $(docker images | grep redis > /dev/null); then
    echo "    ---> redis-32-rhel7 container image downloaded..."
  else
    echo "    ---> Loading redis-32-rhel7 container image..."
    docker load --input /root/redis-32-rhel7.tar
  fi
  
  docker run \
    --detach \
    --restart=always \
    --publish 6379:6379 \
    --privileged=true \
    --name quay-redis \
    -v /var/lib/redis:/var/lib/redis/data \
    registry.access.redhat.com/rhscl/redis-32-rhel7
  
  ### login Red Hat Quay v3 registry ###
  # echo "[*] Login Red Hat Quay v3 registry..."
  # podman login -u="redhat+quay" -p="O81WSHRSJR14UAZBK54GQHJS0P1V4CLWAJV1X2C4SD7KO59CQ9N3RE12612XU1HR" quay.io
  
  ### load Red Hat Quay v3 container image ###
  echo "[*] Load Red Hat Quay v3 container image..."
  if $(docker images | grep quay > /dev/null); then
    echo "    ---> quay container image downloaded..."
  else
    echo "    ---> Loading quay container image..."
    docker load --input /root/quay330.tar
  fi
  
  ### Configure Quay container ###
  docker run \
    --detach \
    --privileged=true \
    --name quay-config \
    --publish 8443:8443 \
    quay.io/redhat/quay:v3.3.0 \
    config redhat
}

### Note ###
# After running docker config quay, you must login https://<register_url>:8443
# as quayconfig/redhat. During quay configuration, config will insert mysql 
# and test connection with mysql database.
# So you can't use quay configuration file directly in script which will result
# quay container can't be deployed successfully!

deploy_quay() {
  ### copy Quay config file ###
  echo "[*] Copy Quay config file..."
  mkdir -p /mnt/quay/{config,storage}
  tar -zxf /root/quay-config.tar.gz 
  cp /root/config.yaml /mnt/quay/config/
  
  ### create self-signed certification ###
  echo "[*] Create Quay self-signed certification..."
  openssl req \
    -newkey rsa:2048 -nodes -keyout /root/ssl.key \
    -x509 -days 3650 -out /root/ssl.cert \
    -subj "/C=CN/ST=Shanghai/L=Shanghai/O=RedHat/OU=RedHat/CN=QuayManager"
  
  sed -i 's/PREFERRED_URL_SCHEME: http/PREFERRED_URL_SCHEME: https/' /mnt/quay/config/config.yaml
  
  echo "    ---> Copy Quay self-signed certification..."
  cp /root/{ssl.key,ssl.cert} /mnt/quay/config/
  chmod 0644 /mnt/quay/config/ssl.key
  chown 1001 /mnt/quay/storage/
  # If don't change owner of the directory, you can't push any container images into registry as to
  # permission dinied.
  #cp /root/ssl.cert /etc/pki/ca-trust/source/anchors/ssl.cert
  #update-ca-trust extract
  
  ### Stop quay-config container ###
  echo "[*] Stop quay-config container..."
  docker stop quay-config && docker rm quay-config
  
  ### Deploy Red Hat Quay v3 registry ###
  echo "[*] Deploy Red Hat Quay v3 registry..."
  docker run \
    --detach \
    --restart=always \
    --sysctl net.core.somaxconn=4096 \
    --privileged=true \
    --name quay-master \
    -v /mnt/quay/config:/conf/stack \
    -v /mnt/quay/storage:/datastorage \
    -p 443:8443 \
    -p 80:8080 \
    quay.io/redhat/quay:v3.3.0
  
  ### Verfify quay-associated container ###
  echo "[*] Verify quay-associated container..."
  docker ps
}

config_quay
#deploy_quay

