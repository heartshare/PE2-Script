#!/bin/bash
#contSetup_lb.sh
source dats48-params.sh
source global_functions.sh

echo "   - Haproxy" # Loadbalancer
# Checks if it exists, deletes container and image
functionKillAndDeleteContainer "lb"
sudo docker run --name lb --hostname haproxy \
-v $volPath/lb/conf.d/:/usr/local/etc/haproxy:ro \
-v /etc/hosts:/etc/hosts -p 80:80 --net bridge -d $img_loadbalancer  1> $output
echo "Container made: lb"
functionEditHosts "lb"
