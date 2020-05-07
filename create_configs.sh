#!/bin/bash
#create_config.sh
source dats48-params.sh

# COPYING AND MAKING CONFIG FILES FOR CONTAINERS--------------------------------
echo " ### Preparing config files for containers--------------------------------"

echo "   - Haproxy config" # haproxy config
sudo cp -vf $configSource/haproxy.cfg $volPath/lb/conf.d/

echo "   - Maxscale config" # maxscale config
sudo rm -f $volPath/dbproxy/conf.d/maxscale.cnf
sudo touch $volPath/dbproxy/conf.d/maxscale.cnf
echo "->'$volPath/dbproxy/conf.d/maxscale.cnf'"

echo "   - DB config" # db config
dbServerList=""
for(( i=1; i<=$numberOfDbServers; i++))
do
  sudo cp -v $configSource/db.cnf $volPath/db$i/conf.d/db$i.cnf
  # Rest of this loop is config for maxscale, making a [dbX] config block
  serv_weight=1
  if [ $i -eq 1 ]
  then
    serv_weight=2
  fi
  dbDef="[db$i]\n"
  dbDef+="type = server\n"
  dbDef+="address = dbgc$i\n"
  dbDef+="port = 3306\n"
  dbDef+="protocol = MariaDBBackend\n"
  dbDef+="serv-weight = $serv_weight\n\n"
  echo -e "$dbDef" \
  | sudo dd of=$volPath/dbproxy/conf.d/maxscale.cnf status=none conv=notrunc oflag=append
  dbServerList+="db$i,"
done

echo "   - Webserver config" #Webserver configs
for(( i=1; i<=$numberOfWebServers; i++))
do
  sudo cp -r $phpContentPath/* $volPath/web$i/html
  # Rest of this loop is config for loadbalancer, making backend servers in config
  echo -e "\tserver web$i web$i:80 check weight $(($i * 10))" \
  | sudo dd of=$volPath/lb/conf.d/haproxy.cfg status=none conv=notrunc oflag=append
done

echo "   - finalizing..." # finishing maxscale config
# Putting together the maxscale config with the already made [dbX] blocks with
# the rest of the config
cat $volPath/dbproxy/conf.d/maxscale.cnf $configSource/maxscale.cnf \
| sudo dd of=$volPath/dbproxy/conf.d/maxscale.cnf status=none
# removing last , on the dbServerList before adding it to the "server =" config
# line in the maxscale config
dbServerList=$(echo "$dbServerList" | sed 's/\(.*\),/\1 /')
sudo sed -in "s/servers =.*/servers = $dbServerList/g" $volPath/dbproxy/conf.d/maxscale.cnf

echo "   # Configuration files complete!"
