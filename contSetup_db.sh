#!/bin/bash
#contSetup_db
set -euo pipefail
source dats48-params.sh
source global_functions.sh

dbTotalRetries=0
galeraRetries=0

functionDbWait () {
  #1 Param: Name of container to wait for
  local contName=$1
  #2 Param: Method of checking if ready:
  # method 1: Replying to db-queries
  # method 2: WSREP logging synced
  # method 3: Galera setup complete
  local method=$2
  #3 Param: Number of restarts to attempt
  local maxRestarts=$3
  #4 Param[opt]: Number of cycles to wait
  local maxWaits=${4:-5}

  local sleepSeconds=2
  local restarts=0
  local waitCycles=0

  local waitString="Waiting for $contName to be ready."
  while :
  do
    # The check if db is ok, return 0 if ok
    case $method in
      [1])
      # db query test
      local sqlresult=$(sudo docker exec -it $contName mysqladmin ping -h localhost) 2> /dev/null || true
      if [[ ! $(echo "$sqlresult" | grep "alive") = "" ]]
      then
        echo " / $contName is ready for db queries!"
        return 0
      fi
      ;;
      2)
      # sync test
      local log=$( sudo docker logs $contName 2>&1 | grep "Synchronized with group, ready for connections" ) || true
      if [[ ! $log == "" ]]
      then
        echo " / $contName is ready and synced with group!"
        return 0
      fi
      ;;
      3)
      # galera test
      local sqlresult=$(sudo docker exec -it db1 mysql -sN -uroot -e 'select variable_name, variable_value from information_schema.global_status where variable_name in ("wsrep_cluster_size", "wsrep_local_state_comment", "wsrep_cluster_status", "wsrep_incoming_addresses")')
      local wsrepLSC=$(echo "$sqlresult" | grep "WSREP_LOCAL_STATE_COMMENT")
      local wsrepCS=$(echo "$sqlresult" | grep "WSREP_CLUSTER_SIZE")
      if [[ ! $( echo "$wsrepLSC" | grep "Synced") == "" && ! $( echo "$wsrepCS" | grep "$numberOfDbServers") == "" ]]
      then
        echo " / synced and galera is ready!"
        return 0
      fi
      ;;
    esac
    echo -en "\r$waitString"
    local waitString+="."
    if [[ $waitCycles -lt $maxWaits ]]
    then
      #Doing another cycle
      ((waitCycles+=1))
      sleep $sleepSeconds
    else
      #Done too many cycles
      if [[ $restarts -lt $maxRestarts ]]
      then
        #Doing a restart
        ((restarts+=1))
        local waitCycles=0
        local waitString+=" restarted"
        echo -en "\r$waitString"
        sudo docker restart $contName 1> $output
        sleep $sleepSeconds
      else
        #Done too many restarts
        return 1
      fi
    fi
  done
}

echo "   - Databases" # Database-servers
gcommString="" # String thats later used for dbproxy setup
bootstrapNames="" # String of containers to stop/start/restart
for((i=0; i<=$numberOfDbServers; i++))
do
  # Deletes existing containers and db-data folders content
  sudo sed -i "/dbgc$i/d" /etc/hosts
  functionKillAndDeleteContainer "db$i"
  sudo rm -rf $volPath/db$i/data.d/*
  gcommString+="dbgc$i," # Builds the string
done

echo "   -- [db0]" # Setting up db0
# Removing trailing comma from gcommString
sudo docker run -d --name db0 --net bridge --hostname dbgc0 \
-v $volPath/db1/data.d/:/var/lib/mysql \
-v $volPath/db1/conf.d/:/etc/mysql/mariadb.conf.d \
--env MYSQL_ROOT_PASSWORD="rootpass" $img_database \
--wsrep_cluster_address=gcomm:// \
--wsrep_node_address=dbgc0 1> $output
echo "Container made: db0"
functionEditHosts "db0"
functionDbWait "db0" 2 0

# Setting up db2-dbx
# Removing trailing comma from gcommString
gcommString=$(echo "$gcommString" | sed 's/\(.*\),/\1 /')
for((i=2; i<=$numberOfDbServers; i++))
do
  echo "   -- [db$i]"
  sudo docker run -d --name db$i --net bridge --hostname dbgc$i \
  -v $volPath/db$i/data.d/:/var/lib/mysql \
  -v $volPath/db$i/conf.d/:/etc/mysql/mariadb.conf.d \
  -v /etc/hosts:/etc/hosts \
  --env MYSQL_ROOT_PASSWORD="rootpass" \
  $img_database --wsrep_cluster_address=gcomm://$gcommString \
  --wsrep_node_address=dbgc$i 1> $output
  echo "Container made: db$i"
  functionEditHosts "db$i"
  bootstrapNames+="db$i "
done
# Containers db2 ++ is prob gonna stop here
echo -en "\rWaiting for the containers to fail..."
sudo docker container wait $bootstrapNames 1> $output
sudo docker stop db0 1> /dev/null
sudo docker container wait db0 1> $output
echo " / stopped"
sudo grep -q "safe_to_bootstrap" $volPath/db1/data.d/grastate.dat \
&& sudo sed -i '/safe_to_bootstrap^/c\safe_to_bootstrap: 1' $volPath/db1/data.d/grastate.dat \
|| sudo sed -i '$ a safe_to_bootstrap: 1' $volPath/db1/data.d/grastate.dat
sudo docker start db0 1> $output
functionDbWait "db0" 2 0 10
sudo docker start $bootstrapNames 1> $output

echo "Removing bootstrap container db0"
sudo docker kill db0 &> /dev/null || true
sudo docker rm db0 1> $output
echo "   -- [db1]"
sudo docker run -d --name db1 --net bridge --hostname dbgc1 \
-v $volPath/db1/data.d/:/var/lib/mysql \
-v $volPath/db1/conf.d/:/etc/mysql/mariadb.conf.d \
-v /etc/hosts:/etc/hosts \
--env MYSQL_ROOT_PASSWORD="rootpass" \
$img_database --wsrep_cluster_address=gcomm://$gcommString \
--wsrep_node_address=dbgc1 1> $output
bootstrapNames=$(echo "$bootstrapNames" | sed 's/db0/db1/g')
echo "Container made: db1"
functionEditHosts "db1"

functionDbWait "db1" 1 0 15
sudo docker start $bootstrapNames 1> $output || true
functionDbWait "db1" 3 0 15


echo "   - Databases setup complete!"
