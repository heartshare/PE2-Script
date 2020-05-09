#!/bin/bash
#contSetup_dbproxy
source dats48-params.sh
source global_functions.sh

echo -e "\n   # Starting to setup ${dbproxy_name}"
sudo sed -i "s/USERNAME/$maxUn/g" $volPath/${dbproxy_dir}/conf.d/maxscale.cnf
sudo sed -i "s/USERPASSWORD/$maxUp/g" $volPath/${dbproxy_dir}/conf.d/maxscale.cnf
functionKillAndDeleteContainer "$dbproxy_name"
sudo docker run -d --name $dbproxy_name --net $dbproxy_net --hostname $dbproxy_hostn \
-v $volPath/${dbproxy_dir}/conf.d/maxscale.cnf:/etc/maxscale.cnf \
-v /etc/hosts:/etc/hosts \
$img_dbproxy 1> $output
echo "Container made: $dbproxy_name"
functionEditHosts "$dbproxy_name"
echo "   # dbproxy setup complete!"
