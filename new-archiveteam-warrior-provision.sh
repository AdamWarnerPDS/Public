#!/bin/bash
# Script to setup archiveteam-warrior instance quickly
# Copywrite 2023 Adam Warner
# Permission is hereby granted, free of charge, to any person obtaining a copy 
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights 
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
# copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in 
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.



# Install Docker https://docs.docker.com/engine/install/debian/
## PreReqs
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg

## GPG
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

## Setup repo
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  
## Install docker
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y



# Install other items
apt install vim htop curl -y


# Create initialization script
initScript=$(cat << EOF
#!/bin/bash

export DOWNLOADER='desiredDownloaderName'
export HTTP_USERNAME='desiredHttpUsername'
export HTTP_PASSWORD='desiredHttpPassword'
export SELECTED_PROJECT=auto
export CONCURRENT_ITEMS=2

docker run --detach --name watchtower --restart=on-failure --volume /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --label-enable --cleanup --interval 3600 && docker run --env DOWNLOADER --env HTTP_USERNAME --env HTTP_PASSWORD --env SELECTED_PROJECT --env CONCURRENT_ITEMS --detach --name archiveteam-warrior --label=com.centurylinklabs.watchtower.enable=true --restart=on-failure --publish 8001:8001 atdr.meo.ws/archiveteam/warrior-dockerfile
EOF
)

echo "$initScript" > /root/init-warrior.sh

# Create stop script
stopScript=$(cat << EOF
#!/bin/bash
docker stop watchtower archiveteam-warrior
EOF
)

echo "$stopScript" > /root/stop-warrior-docker.sh
chmod +x /root/stop-warrior-docker.sh

# Create remove script
removeScript=$(cat << EOF
#!/bin/bash
docker remove watchtower archiveteam-warrior
EOF
)

echo "$removeScript" > /root/remove-warrior-docker.sh
chmod +x /root/remove-warrior-docker.sh

# Create start script
startScript=$(cat << EOF
#!/bin/bash
docker start watchtower archiveteam-warrior
EOF
)

echo "$startScript" > /root/start-warrior-docker.sh
chmod +x /root/start-warrior-docker.sh

# Open 8001 on firewall
ufw allow 8001

# Set options, there's probably a better way to do this
read -p "Enter your downloader/nickname: " desiredDownloaderName
read -p "Enter your desired http username: " desiredHttpUsername
read -p "Enter your desired http password: " desiredHttpPassword

sed -i "s/desiredDownloaderName/$desiredDownloaderName/g" /root/init-warrior.sh
sed -i "s/desiredHttpUsername/$desiredHttpUsername/g" /root/init-warrior.sh
sed -i "s/desiredHttpPassword/$desiredHttpPassword/g" /root/init-warrior.sh

chmod +x /root/init-warrior.sh

printf "\nPlease verify the contents of /root/init-warrior.sh, it should be ready to run \n\n\n"