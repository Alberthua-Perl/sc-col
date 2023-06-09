#!/bin/bash
#
#  Created on 2020-02-28 19:30 by hualf.
#  Usage: 
#    The shell script is used to capture images from https://www.meitulu.com/item/<index>.html.
#  e.g, https://www.meitulu.com/item/20389.html
#

read -t 30 -p "Please type the website of mettulu: " URL
DIR=$(curl -s ${URL} | grep '<title>'| awk -F 'title' '{print $2}' | \
  awk -F '_' '{print $1}' | sed 's/^>//')
mkdir -p ~/meitulu/"${DIR}"
cd ~/meitulu/"${DIR}" 

INDEX=$(echo ${URL} | awk  -F '/' '{print $NF}' | awk -F '.' '{print $1}')
TOTAL=$(curl -s ${URL} | grep 图片数量 | awk '{print $3}')
PREFIX="https://mtl.gzhuibei.com/images/img/"

for NUM in $(seq 1 ${TOTAL}); do
  MERGE=${PREFIX}${INDEX}/${NUM}.jpg
  echo "--- Capturing image from ${MERGE} ---"
  curl -s ${MERGE} -o ${NUM}.jpg
done
