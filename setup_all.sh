#!/bin/bash
#setup_all.sh
cd $(dirname $0)

echo ""
echo " ########################"
echo " ###   PE2 VM SETUP   ###"
echo " ########################"

source dats48-params.sh
source global_functions.sh

echo "  -Setting up VM with Docker and Docker-containers:"
echo "  -$numberOfWebServers web-servers of richarvey/nginx-php-fpm"
echo "  -Load-balancer for the webservers of haproxy"
echo "  -$numberOfDbServers database-servers of mariadb"
echo "  -Database-proxy for the db-servers of mariadb/maxscale"

echo ""
echo ""


# Step 1 - creating directories
source create_dir.sh
# Step 2 - creating config-files
source create_configs.sh
# Step 3 - installing docker if not already
source docker_install.sh
# Step 4 - downloading docker images
source pull_dockerImages.sh

# Step 5 - setting up containers
echo -e "\n ### Setting up containers -----------------------------------------------"
# Step 5 . 1 - setting up web-containers
source contSetup_web.sh
# Step 5 . 2 - setting up loadbalancer(haproxy)
source contSetup_lb.sh
# Step 5 . 3 - setting up database-servers
source contSetup_db.sh
# Step 5 . 4 - setting up dbproxy
source contSetup_dbproxy.sh

# Step 5 - finalizing
source dbUsersAndContent.sh

echo -e "\n ### SETUP COMPLETE ### "
