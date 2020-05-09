#!/bin/bash
#dbUsersAndContent.sh
source dats48-params.sh

echo -en "\n\r   - Filling database with data"
sudo cp ./${dbContentPath}/studentinfo-db.sql $volPath/${db_dir}1/data.d/studentinfo-db.sql
sudo docker exec -it ${db_name}1 mysql -uroot -e "source /var/lib/mysql/studentinfo-db.sql"
echo -e " / done!"

echo -en "\r   - Updating some config and other files"
for((i=1;i<=$numberOfWebServers;i++))
do
  sudo sed -i "s/USERNAME/$datsUn/g" $volPath/${web_dir}${i}/html/include/dbconnection.php
  sudo sed -i "s/USERPASSWORD/$datsUp/g" $volPath/${web_dir}${i}/html/include/dbconnection.php
  sudo docker restart ${web_name}$i 1> $output
done

echo -e " / done!"


subnet=$(sudo docker network inspect --format='{{ range .IPAM.Config}}{{.Subnet}}{{end}}' $db_net)
subnetIp=$(echo "$subnet" | sed 's#.\/.*$#%#')
echo -en "\r   - Adding maxscaleuser and dats user, restricted to IP $subnet"
sudo docker exec -it ${db_name}1 mysql -s -uroot -e "CREATE USER '$maxUn'@'$subnetIp' IDENTIFIED BY '$maxUp'"
sudo docker exec -it ${db_name}1 mysql -s -uroot -e "grant select on mysql.* to '$maxUn'@'$subnetIp'"
sudo docker exec -it ${db_name}1 mysql -s -uroot -e "grant replication slave on *.* to '$maxUn'@'$subnetIp'"
sudo docker exec -it ${db_name}1 mysql -s -uroot -e "grant replication client on *.* to '$maxUn'@'$subnetIp'"
sudo docker exec -it ${db_name}1 mysql -s -uroot -e "grant show databases on *.* to '$maxUn'@'$subnetIp'"
sudo docker exec -it ${db_name}1 mysql -uroot -e "CREATE USER '$datsUn'@'$subnetIp' IDENTIFIED BY '$datsUp'"
sudo docker exec -it ${db_name}1 mysql -uroot -e "grant select, insert, delete, update on studentinfo.* to '$datsUn'@'$subnetIp'"
sudo docker exec -it ${db_name}1 mysql -uroot -e "flush privileges"
echo " / done!"

echo "   # Database filled and users added"
