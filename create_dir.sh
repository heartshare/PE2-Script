#!/bin/bash
#create_dir.sh
source dats48-params.sh

# MAKING DIRCTORIES-------------------------------------------------------------
echo " ### Making directories --------------------------------------------------"

echo "   - Webserver directories" # Webserver directories
for(( i=1; i<=$numberOfWebServers; i++))
do
  sudo mkdir -pv $volPath/${web_dir}${i}/html
done

echo "   - Loadbalancer directory" # Haproxy directory
sudo mkdir -pv $volPath/${lb_dir}/conf.d

echo "   - Database directories" # Database directories
for((i=1; i<=$numberOfDbServers; i++))
do
  sudo mkdir -pv $volPath/${db_dir}${i}/conf.d
  sudo mkdir -pv $volPath/${db_dir}${i}/data.d
done

echo "   - Maxscale directory" # Maxscale directory
sudo mkdir -pv $volPath/${dbproxy_dir}/conf.d

echo "   # Directories made!" # Directories finished
