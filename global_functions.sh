#!/bin/bash
#global_functions.sh
source dats48-params.sh

# //////////////////////////////////////////////////////////////////////////////
# By providing the container-name as a parameter this function
# -finds ip and hostname of the container
# -adds the container with hostname and IP to local /etc/hosts file
functionEditHosts () {
  # Param #1: Name of container
  local contName=$1
  local hostName=$(sudo docker inspect --format='{{.Config.Hostname}}' $contName)
  local contIp=$(sudo docker inspect --format='{{ range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $contName)
  if [[ $contIp == "" ]]
  # If the container has not started yet, the IP will be "" and the
  # function waits before it restarts the container and asks for the IP again
  then
    sleep 2
    sudo docker restart $contName
    sleep 1
    local contIp=$(sudo docker inspect --format='{{ range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $contName)
  fi
  # Creates the new line for /etc/hosts, then checks if the hostname already exists,
  # if so replacing, if not append at the end of the file
  local newLine="$contIp $hostName"
  echo "/etc/hosts updated: $newLine"
  grep -q "$hostName" /etc/hosts \
  && sudo sed -i "/$hostName$/c\\$newLine" /etc/hosts \
  || sudo sed -i "$ a $newLine" /etc/hosts
}

# //////////////////////////////////////////////////////////////////////////////
# By providing the container-name as parameter this function
# -stops the container by killing it,
# -then removes that container
# (if the container is not found no error is outputted, just contioues)
functionKillAndDeleteContainer () {
  # Param #1 is container-name to kill and delete
  local contName=$1
  local killResult="$(sudo docker kill $contName 2>&1)" || true
  if [[ ! $( echo "$killResult" | grep -o "No such") == "No such" ]]
  then
    echo "Container '$contName' found, deleting it"
    sudo docker rm $contName &> /dev/null
  fi
}
