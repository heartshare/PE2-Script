#!/bin/bash
# dats48-params.sh

#Images to use
img_webserver=richarvey/nginx-php-fpm:latest
img_loadbalancer=haproxy:latest
img_database=mariadb:10.4
img_dbproxy=mariadb/maxscale:latest

#Container names
# WEB
web_name=web # webX
web_hostn=web #webX
web_dir=web
web_net=bridge
# LOAD-BALANCER
lb_name=lb
lb_hostn=haproxy
lb_dir=lb
lb_net=bridge
# !! changing lb_name !! carefull of changing lb-name after the script has
# already run once. There can not be two containers having port 80 exposed
# at the same time, and the script will not find, stop and delete the old
# loadbalancer-container
# DATABASE
db_name=db # dbX
db_hostn=dbgc # dgbcX
db_dir=db # dbX
db_net=bridge
# DATABASE PROXY
dbproxy_name=dbproxy
dbproxy_hostn=maxscale # do not touch
dbproxy_dir=dbproxy
dbproxy_net=bridge
# dbproxy_hostn cant not be changed as the php files have
# hostname reference to the dbproxy and the php files are
# not supposed to be changed on this spesific line

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
rootPass="rootpass"
maxUn="maxscaleuser"
maxUp="maxscalepass"
datsUn="dats48"
datsUp="none Ireland please"
