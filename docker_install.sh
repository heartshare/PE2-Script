#!/bin/bash
#docker_install.sh

# INSTALLING DOCKER-------------------------------------------------------------
echo -e "\n ### Docker software installation starting--------------------------------"

# Checking if docker-ce package is installed, if not, running required script to install docker
dockerStatus=$(dpkg-query -W --showformat='${Status}\n' docker-ce|grep "install ok installed")  2> /dev/null || true
if [ "$dockerStatus" == "" ]
then
  sudo apt install -y apt-transport-https software-properties-common ca-certificates
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt update
  sudo apt -y install docker-ce
  echo "   - Setting up docker with sudo-permissions"
  sudo groupadd -f docker
  sudo usermod -aG docker $(whoami)
  sudo rm -fR ~/.docker
  echo "   # Docker software installation complete!"
else
  echo "   # Docker software already installed!"
fi
