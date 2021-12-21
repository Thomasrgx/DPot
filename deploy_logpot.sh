#!/bin/bash
set -e
set -x

if [ $# -ne 2 ]
    then
        echo "Wrong number of arguments supplied."
        echo "Usage: $0 <server_url> <deploy_key>."
        exit 1
fi

server_url=$1
deploy_key=$2

sudo apt update
sudo apt upgrade -y

# Register the sensor with the MHN server.
wget https://raw.githubusercontent.com/Thomasrgx/mhn/master/server/mhn/static/registration.txt -O registration.sh
chmod 755 registration.sh
. ./registration.sh $server_url $deploy_key "log4pot"

sudo apt install python3-pip
sudo pip3 install poetry
sudo pip3 install azure
sudo apt-get -y install git supervisor
pip3 install virtualenv

# Get the Log4pot source
cd /opt
git clone https://github.com/Thomasrgx/Log4Pot
cd Log4Pot

virtualenv env
. env/bin/activate

wget https://github.com/Thomasrgx/wordpot/blob/master/wordpot.conf
sed -i '/HPFEEDS_.*/d' wordpot.conf
sed -i "s/^HOST\s.*/HOST = '0.0.0.0'/" wordpot.conf
cp wordpot.conf log4pot.conf

sudo poetry install

cat >> log4pot.conf <<EOF
HPFEEDS_ENABLED = True
HPFEEDS_HOST = '$HPF_HOST'
HPFEEDS_PORT = $HPF_PORT
HPFEEDS_IDENT = '$HPF_IDENT'
HPFEEDS_SECRET = '$HPF_SECRET'
HPFEEDS_TOPIC = 'log4pot.events'
EOF

# Config for supervisor.
cat > /etc/supervisor/conf.d/log4pot.conf <<EOF
[program:log4pot]
command=poetry run python3 /opt/Log4Pot/log4pot.py 
directory=/opt/Log4Pot
stdout_logfile=/opt/Log4Pot/log4pot.out
stderr_logfile=/opt/Log4Pot/log4potpot.err
autostart=true
autorestart=true
redirect_stderr=true
stopsignal=QUIT
EOF

supervisorctl update
