#!/bin/bash
# 
# used to create CA signed certification
# created by hualongfeiyyy@163.com on 2023-01-02
#

openssl genrsa -out CA-center.key 2048
#openssl req -new -key CA-center.key -out CA-center.csr
# create CA-center.csr used to signed CA-center.crt
# also use following command directly to signed CA-center.crt
openssl req -key CA-center.key \
  -subj "/C=CN/ST=Shanghai/L=Shanghai/O=RedHat/OU=GLS/CN=CA-center.lab.example.com" \
	-new -x509 -days 3650 -out CA-center.crt
# create CA key and CA root certification

openssl genrsa -out server.key 2048
openssl req -key server.key \
  -subj "/C=CN/ST=Shanghai/L=Shanghai/O=RedHat/OU=GLS/CN=cloud-ctl.lab.example.com" \
	-new -out server.csr
openssl x509 -req -in server.csr \
  -CAkey CA-center.key -CA CA-center.crt -CAcreateserial -days 3650 -out server.crt
# use CA key singed server certification

