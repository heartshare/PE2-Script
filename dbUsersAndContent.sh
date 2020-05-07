#!/bin/bash
#dbUsersAndContent.sh
source dats48-params.sh

echo -en "\n\r   # Filling database with data"
sudo cp ./database/studentinfo-db.sql $volPath/db1/data.d/studentinfo-db.sql
sudo docker exec -it db1 mysql -uroot -e "source /var/lib/mysql/studentinfo-db.sql"
echo -e " / done!"

echo -en "\n\r   # Updating some config and other files"
for((i=1;i<=$numberOfWebServers;i++))
do
  sudo sed -i "s/USERNAME/$datsUn/g" $volPath/web$i/html/include/dbconnection.php
  sudo sed -i "s/USERPASSWORD/$datsUp/g" $volPath/web$i/html/include/dbconnection.php
  sudo docker restart web$i 1> $output
done

echo -e " / done!"

echo -e "\nAdding maxscaleuser and dats user"
subnet=$(sudo docker network inspect --format='{{ range .IPAM.Config}}{{.Subnet}}{{end}}' bridge)
subnetIp=$(echo "$subnet" | sed 's#.\/.*$#%#')
echo -e "User[$maxUn] and user[$datsUn] will be restriced to IP $subnet"
sudo docker exec -it db1 mysql -s -uroot -e "CREATE USER '$maxUn'@'$subnetIp' IDENTIFIED BY '$maxUp'"
sudo docker exec -it db1 mysql -s -uroot -e "grant select on mysql.* to '$maxUn'@'$subnetIp'"
sudo docker exec -it db1 mysql -s -uroot -e "grant replication slave on *.* to '$maxUn'@'$subnetIp'"
sudo docker exec -it db1 mysql -s -uroot -e "grant replication client on *.* to '$maxUn'@'$subnetIp'"
sudo docker exec -it db1 mysql -s -uroot -e "grant show databases on *.* to '$maxUn'@'$subnetIp'"
sudo docker exec -it db1 mysql -uroot -e "CREATE USER '$datsUn'@'$subnetIp' IDENTIFIED BY '$datsUp'"
sudo docker exec -it db1 mysql -uroot -e "grant select, insert, delete, update on studentinfo.* to '$datsUn'@'$subnetIp'"
sudo docker exec -it db1 mysql -uroot -e "flush privileges"

echo "   # Databases setup complete"
