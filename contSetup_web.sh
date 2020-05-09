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
  functionKillAndDeleteContainer "$web_name$i"
  sudo docker run --name ${web_name}${i} --hostname ${web_hostn}${i} -d \
  -v $volPath/${web_dir}${i}/html:/var/www/html:ro \
  -v /etc/hosts:/etc/hosts \
  --net $web_net \
  $img_webserver 1> $output
  echo "Container made: ${web_name}${i}"
  functionEditHosts "${web_name}${i}"
done
