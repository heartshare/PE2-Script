#!/bin/bash
#contSetup_web.sh
source dats48-params.sh
source global_functions.sh

echo "   - Webservers"  #Webservers
for ((i=1; i<=$numberOfWebServers; i++))
do
  # For each web server:
  # checks if it already exists and deletes
  # then creates it and adds it to hosts file
  functionKillAndDeleteContainer "web$i"
  sudo docker run --name web$i --hostname web$i -d \
  -v $volPath/web$i/html:/var/www/html:ro \
  -v /etc/hosts:/etc/hosts \
  --net bridge \
  $img_webserver 1> $output
  echo "Container made: web$i"
  functionEditHosts "web$i"
done
