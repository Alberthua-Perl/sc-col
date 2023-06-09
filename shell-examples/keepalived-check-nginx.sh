#!/bin/bash
#
# Edited : 2017.11.12 16:16 by hualf.
# Usage  : checking status of nginx. If nginx has been down,
#   master node will restart nginx again. When nginx has started
#   failedly, keepalived will be killed, and backup node will 
#   replace the master node.
#

status=$(ps -C nginx --no-headers | wc -l)
if [ $status -eq 0 ]; then
    /usr/local/nginx/sbin/nginx
    sleep 2
    counter=$(ps -C nginx --no-headers | wc -l)
    if [ "${counter}" -eq 0 ]; then
        systemctl stop keepalived
    fi
fi
