#!/bin/bash
# Author: Chris Har
# Thanks to all who published information on the Internet!
#
# Disclaimer: Your use of this script is at your sole risk.
# This script and its related information are provided "as-is", without any warranty,
# whether express or implied, of its accuracy, completeness, fitness for a particular
# purpose, title or non-infringement, and none of the third-party products or information
# mentioned in the work are authored, recommended, supported or guaranteed by The Author.
# Further, The Author shall not be liable for any damages you may sustain by using this
# script, whether direct, indirect, special, incidental or consequential, even if it
# has been advised of the possibility of such damages.
#

#
# NOTE:
# This script is based on:
# - Git Commit: 18dc987 => https://github.com/gohelpfund/p2pool-help
# - Git Commit: 20bacfa => https://github.com/gohelpfund/aden
#
# You may have to perform your own validation / modification of the script to cope with newer
# releases of the above software.
#
# Tested with Ubuntu 17.10
#

#
# Variables
# UPDATE THEM TO MATCH YOUR SETUP !!
#
PUBLIC_IP=<your public IP address>
EMAIL=<your email address>
PAYOUT_ADDRESS=<your HELP wallet address to receive fees>
USER_NAME=<linux user name>
RPCUSER=<your random rpc user name>
RPCPASSWORD=<your random rpc password>

FEE=0.5
DONATION=0.5
HELP_WALLET_URL=https://github.com/gohelpfund/aden/releases/download/v0.13.1.0/helpcore-0.13.1-x86_64-linux-gnu.tar.gz
HELP_WALLET_ZIP=helpcore-0.13.1-x86_64-linux-gnu.tar.gz
HELP_WALLET_LOCAL=helpcore-0.13.1
P2POOL_FRONTEND=https://github.com/gohelpfund/p2pool-ui-punchy
P2POOL_FRONTEND2=https://github.com/gohelpfund/p2pool-node-status
P2POOL_FRONTEND3=https://github.com/gohelpfund/P2PoolExtendedFrontEnd

#
# Install Prerequisites
#
cd ~
sudo apt-get --yes install python-zope.interface python-twisted python-twisted-web python-dev
sudo apt-get --yes install gcc g++
sudo apt-get --yes install git

#
# Get latest p2pool-HELP
#
mkdir git
cd git
git clone https://github.com/gohelpfund/p2pool-help
cd p2pool-help
git submodule init
git submodule update
cd help_hash
python setup.py install --user

#
# Install Web Frontends
#
cd ..
mv web-static web-static.old
git clone $P2POOL_FRONTEND web-static
mv web-static.old web-static/legacy
cd web-static
git clone $P2POOL_FRONTEND2 status
git clone $P2POOL_FRONTEND3 ext

#
# Get specific version of HELP wallet for Linux
#
cd ~
mkdir help
cd help
wget $HELP_WALLET_URL
tar -xvzf $HELP_WALLET_ZIP
rm $HELP_WALLET_ZIP

#
# Copy HELP daemon
#
sudo cp ~/help/$HELP_WALLET_LOCAL/bin/helpd /usr/bin/helpd
sudo cp ~/help/$HELP_WALLET_LOCAL/bin/help-cli /usr/bin/help-cli
sudo chown -R $USER_NAME:$USER_NAME /usr/bin/helpd
sudo chown -R $USER_NAME:$USER_NAME /usr/bin/help-cli

#
# Prepare HELP configuration
#
mkdir ~/.helpcore
cat <<EOT >> ~/.helpcore/help.conf
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
alertnotify=echo %s | mail -s "HELP Alert" $EMAIL
server=1
daemon=1
EOT

#
# Get latest HELP core
#
cd ~/git
git clone https://github.com/gohelpfund/aden

#
# Install HELP daemon service and set to Auto Start
#
cd /etc/systemd/system
sudo ln -s /home/$USER_NAME/git/aden/contrib/init/helpd.service helpd.service
sudo sed -i 's/User=helpcore/User='"$USER_NAME"'/g' helpd.service
sudo sed -i 's/Group=helpcore/Group='"$USER_NAME"'/g' helpd.service
sudo sed -i 's/\/var\/lib\/helpd/\/home\/'"$USER_NAME"'\/.helpcore/g' helpd.service
sudo sed -i 's/\/etc\/helpcore\/help.conf/\/home\/'"$USER_NAME"'\/.helpcore\/help.conf/g' helpd.service
sudo systemctl daemon-reload
sudo systemctl enable helpd
sudo service helpd start

#
# Prepare p2pool startup script
#
cat <<EOT >> ~/p2pool.start.sh
python ~/git/p2pool-help/run_p2pool.py --external-ip $PUBLIC_IP -f $FEE --give-author $DONATION -a $PAYOUT_ADDRESS
EOT

if [ $? -eq 0 ]
then
echo
echo Installation Completed.
echo You can start p2pool instance by command:
echo
echo bash ~/p2pool.start.sh
echo
echo NOTE: you will need to wait until HELP daemon has finished
echo blockchain synchronization before the p2pool instance is usable.
echo
fi
