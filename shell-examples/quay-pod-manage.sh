#!/bin/bash

# Configure Red Hat Quay v3.3.0 internal registry.
# Deploy method through Podman v3.3.1 engine.
# 
# All containers of Quay will be deployed in one pod,
# including mysql, redis and quay.
#    
# Created by hualf on 2021-12-09.

QUAY_NAME=quay-aio
DESIRE_PAUSE_IMAGE="k8s.gcr.io/pause:3.5"
DESIRE_MYSQL_IMAGE="registry.access.redhat.com/rhscl/mysql-57-rhel7:latest"
DESIRE_REDIS_IMAGE="registry.access.redhat.com/rhscl/redis-32-rhel7:latest"
DESIRE_QUAY_IMAGE="quay.io/redhat/quay:v3.3.0"

config_quay() {
	### verify current user ### 
	echo "[*] Check current user is root..."
	if $(id | grep root > /dev/null); then
		echo "    ---> Current user is root, continue..."
	else
		echo "    ---> Current user is NOT root, exit..."
		exit 1
	fi

  ### check podman package ###
  echo "[*] Check podman package..."
	if [[ -f /etc/redhat-release ]]; then
		# RedHat, CentOS or Fedora OS
  	if $(rpm -q podman > /dev/null); then
    	echo "    ---> Podman has been installled..."
  	else
    	echo "    ---> Exit and please install podman by yourself..."
			exit 1
		fi
	else
		# Debian, Ubuntu OS
		if $(dpkg -l | grep podman > /dev/null); then
			echo "    ---> Podman has been installled..."
		else
			echo "    ---> Exit and please install podman by yourself..."
			exit 1
		fi
  fi

	echo "[*] Please verify following images downloaded:"
	echo "    - ${DESIRE_PAUSE_IMAGE}"
	echo "    - ${DESIRE_MYSQL_IMAGE}"
	echo "    - ${DESIRE_REDIS_IMAGE}"
	echo "    - ${DESIRE_QUAY_IMAGE}"
	echo "[*] INFO: No images will cause deploy failed..."
	echo ""

	### create quay all-in-one pod ###
	echo "[*] Create quay all-in-one pod..."
	IMAGE_PAUSE=$(podman images | grep "k8s.gcr.io/pause" | awk '{print $1":"$2}')
  [[ ${IMAGE_PAUSE} != ${DESIRE_PAUSE_IMAGE} ]] && \
		echo "    ---> Please download ${DESIRE_PAUSE_IMAGE} image..." && exit 1

	echo "    ---> Create all-in-one quay pod..."
	podman pod create \
		--name ${QUAY_NAME} \
		-p 3306:3306 -p 6379:6379 -p 8443:8443 \
		-p 443:8443 -p 80:8080
	# quay-aio pod apply network namespace for all containers
	# mysql, redis and quay share pod network namespace
	# 3306 port: mysql
	# 6379 port: redis
	# 8443 port: quay config
	# 443 or 80 port: access quay through https (default) or http
	[[ $? -eq 0 ]] && echo "    ---> Create ${QUAY_NAME} pod successfully..." || exit 1
	podman pod ps

  ### create MySQL database container ###
  echo "[*] Create MySQL database container..."
  mkdir -p /var/lib/mysql
  chmod 777 /var/lib/mysql

  export MYSQL_CONTAINER_NAME=quay-mysql
  export MYSQL_DATABASE=enterpriseregistrydb
  export MYSQL_PASSWORD=redhat
  export MYSQL_USER=quayuser
  export MYSQL_ROOT_PASSWORD=redhat
  
	IMAGE_MYSQL=$(podman images | grep "registry.access.redhat.com/rhscl/mysql-57-rhel7" | awk '{print $1":"$2}')
	[[ ${IMAGE_MYSQL} != ${DESIRE_MYSQL_IMAGE} ]] && \
		echo "    ---> Please download ${DESIRE_MYSQL_IMAGE} image..." && exit 2

  podman run \
    --detach \
    --env MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} \
    --env MYSQL_USER=${MYSQL_USER} \
    --env MYSQL_PASSWORD=${MYSQL_PASSWORD} \
    --env MYSQL_DATABASE=${MYSQL_DATABASE} \
    --name ${MYSQL_CONTAINER_NAME} \
    --pod ${QUAY_NAME} \
    -v /var/lib/mysql:/var/lib/mysql/data:Z \
    ${DESIRE_MYSQL_IMAGE}
	[[ $? -eq 0 ]] && echo "    ---> Create ${MYSQL_CONTAINER_NAME} container successfully..."
  
  ### create Redis database container ###
  echo "[*] Create Redis database container..."
  mkdir -p /var/lib/redis
  chmod 777 /var/lib/redis

  IMAGE_REDIS=$(podman images | grep "registry.access.redhat.com/rhscl/redis-32-rhel7" | awk '{print $1":"$2}')
  [[ ${IMAGE_REDIS} != ${DESIRE_REDIS_IMAGE} ]] && \
    echo "    ---> Please download ${DESIRE_REDIS_IMAGE} image..." && exit 1
  
  podman run \
    --detach \
    --name quay-redis \
    --pod ${QUAY_NAME} \
    -v /var/lib/redis:/var/lib/redis/data:Z \
    ${DESIRE_REDIS_IMAGE}
  [[ $? -eq 0 ]] && echo "    ---> Create quay-redis container successfully..."

  ### login Red Hat Quay v3 registry ###
  # If you want to use Red Hat Quay v3 image, please use following commad to pull:
  # podman login -u="redhat+quay" -p="O81WSHRSJR14UAZBK54GQHJS0P1V4CLWAJV1X2C4SD7KO59CQ9N3RE12612XU1HR" quay.io
  
  ### configure Quay container ###
	echo "[*] Config Quay registry container..."
	IMAGE_QUAY=$(podman images | grep "quay.io/redhat/quay" | awk '{print $1":"$2}')
	[[ ${IMAGE_QUAY} != ${DESIRE_QUAY_IMAGE} ]] && \
		echo "    ---> Please download ${DESIRE_QUAY_IMAGE} image..." && exit 1

  podman run \
    --detach \
    --name quay-config \
    --pod quay-aio \
    ${DESIRE_QUAY_IMAGE} \
    config redhat
	[[ $? -eq 0 ]] && echo "    ---> Create quay-config container successfully..."

	### check all pod and containers ###
	echo "[*] All infra and containers as followings:"
	sleep 10s
	podman ps | egrep "${MYSQL_CONTAINER_NAME}|quay-redis|quay-config"
	[[ $? -eq 0 ]] && \
		echo "    ---> Deploy Quay config frontend successfully, please access URL..."

	NETNS_IP=$(podman inspect ${MYSQL_CONTAINER_NAME} | jq .[0].NetworkSettings.IPAddress | sed s/\"//g)
	echo -e "[*] Current pod network namespace ip: \033[01;32m${NETNS_IP}\033[00m"
	echo -e "[*] Please use \033[01;32m${NETNS_IP}\033[00m as mysql server address during config quay..."
	echo "[*] Then access Web UI to complete Quay config, and run 'quay-pod-manage deploy' to complete deploy..."
}

### Next ###
#  1. After running config_quay, you should login https://<register_url>:8443
#     as quayconfig/redhat authorized. 
#  2. During configuration quay will insert and test connection with mysql database.
#  3. Complete all configuration and download quay-config.tar.gz to /root.

deploy_quay() {
	# After config_quay, you should run deploy_quay immediately!
	### deploy quay newly ###
	read -p "[*] Please verify deploy Quay, and this will DESTROY old config [Y/n]: " ANSWER
	if [[ ${ANSWER} == "Y" ]]; then
		echo "[*] Start deploy quay..."
		echo "    ---> Remove old quay config file..."
		[[ -d /mnt/quay ]] && rm -rf /mnt/quay
		
  	echo "    ---> Please verify NEW quay-config.tar.gz in /root..."
  	if [[ -f /root/quay-config.tar.gz ]]; then
			tar -zxvf /root/quay-config.tar.gz
		else
			echo "   --> No quay-config tar ball file..."
			exit 1
		fi

		echo "    ---> Copy new quay config file..."
		mkdir -p /mnt/quay/{config,storage}
    cp /root/config.yaml /mnt/quay/config/
    
    ### create self-signed certification ###
    echo "    ---> Create Quay self-signed certification..."
    openssl req \
      -newkey rsa:2048 -nodes -keyout /root/ssl.key \
      -x509 -days 3650 -out /root/ssl.cert \
      -subj "/C=CN/ST=Shanghai/L=Shanghai/O=RedHat/OU=RedHat/CN=*.openshift4.example.com"
    
    sed -i 's/PREFERRED_URL_SCHEME: http/PREFERRED_URL_SCHEME: https/' /mnt/quay/config/config.yaml
    
    echo "    ---> Copy Quay self-signed certification..."
    cp /root/{ssl.key,ssl.cert} /mnt/quay/config/
  	chmod 0644 /mnt/quay/config/ssl.key
    # must change ssl.key permission, or quay nginx can't run as to permission denied
    chown 1001 /mnt/quay/storage
    # change owner 1001 for nginx gateway to write for rootfull container
    # reference url: https://access.redhat.com/solutions/5503811

    ### stop quay-config container ###
    echo "    ---> Stop quay-config container..."
    podman stop quay-config && podman rm quay-config
    
    ### deploy Red Hat Quay v3.3.0 registry ###
  	echo "    ---> Deploy Red Hat Quay v3.3.0 registry..."
  
    podman run \
      --detach \
      --name quay-master \
      --pod ${QUAY_NAME} \
      -v /mnt/quay/config:/conf/stack:Z \
      -v /mnt/quay/storage:/datastorage:Z \
      ${DESIRE_QUAY_IMAGE}
  	[[ $? -eq 0 ]] && echo "    ---> Create quay-master container successfully..."
    
    ### verfify quay-associated container ###
    echo "[*] Verify quay-associated container..."
    echo "    ---> Waiting several seconds to run all containers..."
  	sleep 10s
  	[[ $(podman ps | grep -e "${MYSQL_CONTAINER_NAME}" -e quay-redis -e quay-master) ]] && \
  		echo "    ---> All containers in quay-aio running..."
  	podman ps
		echo "[*] Deploy completely, please wait for several minutes to initial Quay..."
	else
		echo "[*] Exit deploy quay..."
	fi
}

destroy_quay() {
	### destroy Quay pod ###
	echo "[*] Destroy Quay pod..."
	echo "    ---> Remove quay-aio pod..."
	podman pod stop ${QUAY_NAME}
	podman pod rm ${QUAY_NAME}
	podman pod ps
	echo "    ---> Remove all config file and directory..."
	rm -rf /var/lib/{mysql,redis} /mnt/quay
	rm -f /root/{config.yaml,quay-config.tar.gz}
	rm -f /root/ssl.*
}

recover_quay() {
	# If you run `podman pod stop quay-aio', then run `podman pod start quay-aio',
	# quay-master container will start failure. Because container ip will change
	# when starting. quay-master can't connect mysql and redis container in same
	# network namespace through old ip of quay config file.
	#
	# So just change namespace ip in quay config file, after replacing old ip,
	# use podman run again to start quay-master.
	
	echo "[*] Remove quay-master container..."
	if $(podman ps | grep quay-master > /dev/null); then
		podman pod stop ${QUAY_NAME}
		podman pod start ${QUAY_NAME}
		sleep 10s
		podman stop quay-master && podman rm quay-master
	else
		podman rm quay-master
	fi

	echo "[*] Start quay-master container again..."
	NETNS_IP=$(podman inspect quay-mysql | jq .[0].NetworkSettings.IPAddress | sed s/\"//g)
	sed -i s/10.88.[0-9]*.[0-9]*/${NETNS_IP}/g /mnt/quay/config/config.yaml
	
	podman run \
    --detach \
    --name quay-master \
    --pod ${QUAY_NAME} \
    -v /mnt/quay/config:/conf/stack:Z \
    -v /mnt/quay/storage:/datastorage:Z \
    ${DESIRE_QUAY_IMAGE}
	[[ $? -eq 0 ]] && echo "    ---> Create quay-config container successfully..."
	echo "[*] Please wait for several minutes to initial Quay registry..."
}

case $1 in 
	config)
		config_quay
		;;
	deploy)
		deploy_quay
		;;
	recover)
		recover_quay
		;;
	destroy)
		destroy_quay
		;;
	*)
		echo "Usage: "
		echo "  quay-pod-manage [command]"
		echo ""
		echo "Available Commands:"
		echo "  config   Config Quay to get config file archive"
		echo "  deploy   Deploy new all-in-one Quay pod"
		echo "  recover  Recover failure container in pod as to podman pod stop"
		echo "  destroy  Destroy all-in-one Quay pod and remove all config"
		echo ""
		;;
esac
