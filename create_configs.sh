#!/bin/bash
#create_config.sh
source dats48-params.sh

# COPYING AND MAKING CONFIG FILES FOR CONTAINERS--------------------------------
echo -e "\n ### Preparing config files for containers--------------------------------"

functionCreateConfigs () {
  echo "   - Haproxy config" # haproxy config
  sudo cp -vf $configSource/haproxy.cfg $volPath/${lb_dir}/conf.d/

  echo "   - Maxscale config" # maxscale config
  sudo rm -f $volPath/${dbproxy_dir}/conf.d/maxscale.cnf
  sudo touch $volPath/${dbproxy_dir}/conf.d/maxscale.cnf
  echo "->'$volPath/${dbproxy_dir}/conf.d/maxscale.cnf'"

  echo "   - DB config" # db config
  dbServerList=""
  for(( i=1; i<=$numberOfDbServers; i++))
  do
    sudo cp -v $configSource/db.cnf $volPath/${db_dir}${i}/conf.d/db${i}.cnf
    # Rest of this loop is config for maxscale, making a [dbX] config block
    serv_weight=1
    if [ $i -eq 1 ]
    then
      serv_weight=2
    fi
    dbDef="[db$i]\n"
    dbDef+="type = server\n"
    dbDef+="address = ${db_hostn}${i}\n"
    dbDef+="port = 3306\n"
    dbDef+="protocol = MariaDBBackend\n"
    dbDef+="serv-weight = $serv_weight\n\n"
    echo -e "$dbDef" \
    | sudo dd of=$volPath/${dbproxy_dir}/conf.d/maxscale.cnf status=none conv=notrunc oflag=append
    dbServerList+="db$i,"
  done

  echo "   - Webserver config" #Webserver configs
  for(( i=1; i<=$numberOfWebServers; i++))
  do
    sudo cp -r $phpContentPath/* $volPath/${web_dir}${i}/html
    # Rest of this loop is config for loadbalancer, making backend servers in config
    echo -e "\tserver ${web_name}${i} ${web_hostn}${i}:80 check weight $(($i * 10))" \
    | sudo dd of=$volPath/${lb_dir}/conf.d/haproxy.cfg status=none conv=notrunc oflag=append
  done

  echo "   - finalizing..." # finishing maxscale config
  # Putting together the maxscale config with the already made [dbX] blocks with
  # the rest of the config
  check=$(cat $volPath/${dbproxy_dir}/conf.d/maxscale.cnf)
  cat $volPath/${dbproxy_dir}/conf.d/maxscale.cnf $configSource/maxscale.cnf \
  | sudo dd of=$volPath/${dbproxy_dir}/conf.d/maxscale.cnf status=none
  if [[ $(cat $volPath/${dbproxy_dir}/conf.d/maxscale.cnf | grep "$db_hostn") == "" ]]
  then
    exit
  fi
  # removing last , on the dbServerList before adding it to the "server =" config
  # line in the maxscale config
  dbServerList=$(echo "$dbServerList" | sed 's/\(.*\),/\1 /')
  sudo sed -in "s/servers =.*/servers = $dbServerList/g" $volPath/${dbproxy_dir}/conf.d/maxscale.cnf
}

configTries=0
while [[ $(cat $volPath/${dbproxy_dir}/conf.d/maxscale.cnf | grep "$db_hostn") == "" && configTries -lt 2 ]]
do
  functionCreateConfigs
  ((configTries+=1))
done
if [[ $(cat $volPath/${dbproxy_dir}/conf.d/maxscale.cnf | grep "$db_hostn") == "" && configTries -gt 1 ]]
then
  exit
fi
echo "   # Configuration files complete!"
