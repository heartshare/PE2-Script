#!/bin/bash
#contSetup_dbproxy
source dats48-params.sh
source global_functions.sh

echo "   # Starting to setup dbproxy"
sudo sed -i "s/USERNAME/$maxUn/g" $volPath/dbproxy/conf.d/maxscale.cnf
sudo sed -i "s/USERPASSWORD/$maxUp/g" $volPath/dbproxy/conf.d/maxscale.cnf
functionKillAndDeleteContainer "dbproxy"
sudo docker run -d --name dbproxy --net bridge --hostname maxscale \
-v $volPath/dbproxy/conf.d/maxscale.cnf:/etc/maxscale.cnf \
-v /etc/hosts:/etc/hosts \
$img_dbproxy 1> $output
echo "Container made: dbproxy"
functionEditHosts "dbproxy"
echo "   # dbproxy setup complete!"
