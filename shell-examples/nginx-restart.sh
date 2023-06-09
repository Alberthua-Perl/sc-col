#!/bin/bash
# 
# Edited: 2017.11.13 21:25 by hualf.
# Usage : Used to restart nginx progress after testing HA.

alias echo='echo -e'
count=$(ps -C nginx --no-headers | wc -l)

if [ $count -gt 0 ]; then
  pids=$(ps -ef | grep nginx | awk '{ print $2 }')
  array=($pids)
  master_pid=${array[0]}
  echo "Master pid: $master_pid\n"
  echo "---------------------\n"
fi

kill -15 $master_pid
echo "[INFO] Nginx has been down.\n"
echo "---------------------\n"

nginx
if [ $? -eq 0 ]; then
  ps -ef | grep nginx
  echo "\n---------------------\n"
  netstat -tunlp | grep 80
  echo "\n[INFO] Nginx has been up again successfully.\n"
else
  echo "\n[ERROR] Nginx hasn't been restarted."
fi
