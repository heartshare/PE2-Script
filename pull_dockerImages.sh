#!/bin/bash
#pull_dockerImages.sh
source dats48-params.sh


echo -e "\n ### Pulling docker images -----------------------------------------------"
echo -en "\rDownloading webserver image..."
sudo docker pull $img_webserver 1> $output
echo " done!"

echo -en "\rDownloading loadbalancer image..."
sudo docker pull $img_loadbalancer 1> $output
echo " done!"

echo -en "\rDownloading database image..."
sudo docker pull $img_database 1> $output
echo " done!"

echo -en "\rDownloading database-proxy image..."
sudo docker pull $img_dbproxy 1> $output
echo " done!"

echo "   # All images ready"
