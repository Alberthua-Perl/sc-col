#!/bin/bash
#
#  The script is used to start minikube v1.17.3 through kvm.
#  All kubernetes components run in minikube vm.
#  Run `minikube dashboard' to view kubernetes dashboard.
#
#    - Author: hualongfeiyyy@163.com
#    - Date: 2020-02-21 
#

echo "--- Starting minikube... ---"
minikube start \
  --container-runtime=crio \
  --image-repository=registry.aliyuncs.com/google_containers

if [ $? -eq 0 ]; then
  echo "--- Enable minikube addons ---"
  for ADDON in dashboard helm-tiller ingress ingress-dns istio istio-provisioner \
    metrics-server registry registry-creds; do
    minikube addons enable ${ADDON}
  done
else
  echo "--- minikube start failed. ---"
fi
