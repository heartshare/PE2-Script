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
  local maxWaits=$(($maxWaits * $waitMultiplier))

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
      local sqlresult=$(sudo docker exec -it $contName mysql -sN -uroot -e 'select variable_name, variable_value from information_schema.global_status where variable_name in ("wsrep_cluster_size", "wsrep_local_state_comment", "wsrep_cluster_status", "wsrep_incoming_addresses")')
      local wsrepLSC=$(echo "$sqlresult" | grep "WSREP_LOCAL_STATE_COMMENT")
      local wsrepCS=$(echo "$sqlresult" | grep "WSREP_CLUSTER_SIZE")
      if [[ ! $( echo "$wsrepLSC" | grep "Synced") == "" && ! $( echo "$wsrepCS" | grep "$numberOfDbServers") == "" ]]
      then
        echo " / synced and galera is ready!"
        return 0
      fi
      ;;
    esac
    contRunning=$(sudo docker inspect -f "{{.State.Running}}" $contName)
    echo -en "\r$waitString"
    local waitString+="."
    if [[ $waitCycles -lt $maxWaits && $contRunning == "true" ]]
    then
      #Doing another cycle
      ((waitCycles+=1))
      sleep $sleepSeconds
    else
      #Done too many cycles
      if [[ $contRunning == "true" ]]
      then
        local waitString+=" crashed"
      fi
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
        echo " - failed"
        return 1
      fi
    fi
  done
}

functionDb () {
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
  --wsrep_cluster_address=gcomm:// 1> $output
  echo "Container made: db0"
  functionEditHosts "db0"
  functionDbWait "db0" 1 0
  #sudo docker stop db0

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
    $img_database --wsrep_cluster_address=gcomm://$gcommString 1> $output
    echo "Container made: db$i"
    bootstrapNames+="db$i "
    #sudo docker container wait db$i
    #sudo docker stop db$i
    #functionDbWait "db$i" 2 4 5
  done
  echo -en "\rWaiting for database-containers to halt..."
  sudo docker stop db0 1> $output
  sudo docker container wait db0 $bootstrapNames 1> $output
  sudo sed -i 's/^safe_to_bootstrap.*/safe_to_bootstrap: 1/' $volPath/db1/data.d/grastate.dat
  sudo truncate -s 0 $(sudo docker inspect --format='{{.LogPath}}' db0)
  echo -e " done!\nStarting db0 again and getting ready to bootstrap"
  sudo docker start db0 1> $output
  functionDbWait "db0" 2 0 20

  for((i=2; i<=$numberOfDbServers; i++))
  do
    sudo docker start db$i 1> $output
    functionDbWait "db$i" 2 0 30
    functionEditHosts "db$i"
  done

  echo "Checking galera cluster status: "
  functionDbWait "db0" 3 0 20

  echo "Removing bootstrap container db0"
  sudo docker kill -s 15 db0 &> /dev/null || true
  sudo docker container wait db0
  sudo docker rm db0 1> $output
  echo "   -- [db1]"
  sudo docker run -d --name db1 --net bridge --hostname dbgc1 \
  -v $volPath/db1/data.d/:/var/lib/mysql \
  -v $volPath/db1/conf.d/:/etc/mysql/mariadb.conf.d \
  -v /etc/hosts:/etc/hosts \
  --env MYSQL_ROOT_PASSWORD="rootpass" \
  $img_database --wsrep_cluster_address=gcomm://$gcommString 1> $output
  bootstrapNames=$(echo "$bootstrapNames" | sed 's/db0/db1/g')
  echo "Container made: db1"
  functionEditHosts "db1"

  functionDbWait "db1" 1 0 30

  functionDbWait "db1" 3 0 20
  return $?
}

waitMultiplier=1
while :
do
  if functionDb
  then
    # functionDb returned 0 and was successfull
    echo "   - Databases setup complete!"
    break
  else
    # functionDb failed setting up the databases
    if [[ $waitMultiplier -lt 2 ]]
    then
      # doing another attempt at setting them up
      ((waitMultiplier+=1))
      echo -e " trying to setup databases again, giving it x$waitMultiplier more time\n\n "
    else
      # too many attempts, aborting
      echo " failed setting up databases... aborting script"
      break
    fi
  fi
done
