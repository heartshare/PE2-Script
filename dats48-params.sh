#!/bin/bash
# dats48-params.sh

#Images to use
img_webserver=richarvey/nginx-php-fpm:latest
img_loadbalancer=haproxy:latest
img_database=mariadb:10.4
img_dbproxy=mariadb/maxscale:latest

#Output in console. Choose if you only want echos
# or all command outputs. Uncomment you choice
output=/dev/null #for only echos
#output=/dev/stdout #command outputs aswell

#Directories
configSource=./configs_m
volPath=/volumes
dbContentPath=./database
phpContentPath=./phpcode

#Settings
numberOfWebServers=3
numberOfDbServers=3
maxUn="maxscaleuser"
maxUp="maxscalepass"
datsUn="dats48"
datsUp="none Ireland please"
