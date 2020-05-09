#!/bin/bash
#contSetup_lb.sh
source dats48-params.sh
source global_functions.sh

echo "   - Haproxy" # Loadbalancer
# Checks if it exists, deletes container and image
functionKillAndDeleteContainer "$lb_name"
sudo docker run --name $lb_name --hostname $lb_hostn \
-v $volPath/${lb_dir}/conf.d/:/usr/local/etc/haproxy:ro \
-v /etc/hosts:/etc/hosts -p 80:80 --net $lb_net -d $img_loadbalancer  1> $output
echo "Container made: $lb_name"
functionEditHosts "$lb_name"
