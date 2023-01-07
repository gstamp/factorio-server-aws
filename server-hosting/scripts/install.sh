#!/bin/sh

# Note: Arguments to this script 
#  1: string - S3 bucket for your backup save files (required)
#  2: string - Duck DNS token
#  3: string - Duck DNS subdomain
S3_SAVE_BUCKET=$1
DUCK_DNS_TOKEN=$2
DUCK_DNS_SUBDOMAIN=$3

add-apt-repository multiverse
dpkg --add-architecture i386
apt update

apt install -y unzip lib32gcc1

# install factorio
curl -L https://www.factorio.com/get-download/1.1.74/headless/linux64 -o /tmp/factorio.tar.xz
useradd factorio
mkdir /opt
cd /opt
tar -xJf /tmp/factorio.tar.xz
chown -R factorio:factorio /opt/factorio
cd /opt/factorio
su - factorio -c "./bin/x64/factorio --create ./saves/my-save.zip"

# Add service for factorio
cat << 'EOF' > /etc/systemd/system/factorio.service
[Unit]
Description=Factorio dedicated server
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Environment="LD_LIBRARY_PATH=./linux64"
ExecStart=/opt/factorio/bin/x64/factorio --start-server ./saves/my-save.zip
User=factorio
Group=factorio
StandardOutput=journal
Restart=on-failure
KillSignal=SIGINT
WorkingDirectory=/opt/factorio

[Install]
WantedBy=multi-user.target
EOF
systemctl enable factorio
systemctl start factorio
systemctl status factorio

# Setup DuckDNS
cat << EOF > /opt/factorio/duck.sh
#!/bin/bash
current=""
while true; do
	latest=`ec2metadata --public-ipv4`
	echo "public-ipv4=\$latest"
	if [ "\$current" == "\$latest" ]
	then
		echo "ip not changed"
	else
		echo "ip has changed - updating"
		current=\$latest
		echo url="https://www.duckdns.org/update?domains=$DUCK_DNS_SUBDOMAIN&token=$DUCK_DNS_TOKEN&ip=" | curl -k -o /tmp/duck.log -K -
	fi
	sleep 5m
done
EOF
chown -R factorio:factorio /opt/factorio/duck.sh
chmod +x /opt/factorio/duck.sh

cat << 'EOF' > /etc/systemd/system/duck.service
[Unit]
Description=DuckDNS service
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Environment="LD_LIBRARY_PATH=./linux64"
ExecStart=/opt/factorio/duck.sh
User=ubuntu
Group=ubuntu
StandardOutput=journal
Restart=on-failure
KillSignal=SIGINT
WorkingDirectory=/opt/factorio

[Install]
WantedBy=multi-user.target
EOF
systemctl enable duck
systemctl start duck
systemctl status duck


# enable auto shutdown
cat << 'EOF' > /home/ubuntu/auto-shutdown.sh
#!/bin/sh

shutdownIdleMinutes=30
idleCheckFrequencySeconds=1

isIdle=0
while [ $isIdle -le 0 ]; do
    isIdle=1
    iterations=$((60 / $idleCheckFrequencySeconds * $shutdownIdleMinutes))
    while [ $iterations -gt 0 ]; do
        sleep $idleCheckFrequencySeconds
        connectionBytes=$(ss -lu | grep 34197 | awk -F ' ' '{s+=$2} END {print s}')
        if [ ! -z $connectionBytes ] && [ $connectionBytes -gt 0 ]; then
            isIdle=0
        fi
        if [ $isIdle -le 0 ] && [ $(($iterations % 21)) -eq 0 ]; then
           echo "Activity detected, resetting shutdown timer to $shutdownIdleMinutes minutes."
           break
        fi
        iterations=$(($iterations-1))
    done
done

echo "No activity detected for $shutdownIdleMinutes minutes, shutting down."
sudo shutdown -h now
EOF
chmod +x /home/ubuntu/auto-shutdown.sh
chown ubuntu:ubuntu /home/ubuntu/auto-shutdown.sh

cat << 'EOF' > /etc/systemd/system/auto-shutdown.service
[Unit]
Description=Auto shutdown if no one is playing server
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Environment="LD_LIBRARY_PATH=./linux64"
ExecStart=/home/ubuntu/auto-shutdown.sh
User=ubuntu
Group=ubuntu
StandardOutput=journal
Restart=on-failure
KillSignal=SIGINT
WorkingDirectory=/home/ubuntu

[Install]
WantedBy=multi-user.target
EOF
systemctl enable auto-shutdown
systemctl start auto-shutdown
systemctl status auto-shutdown

# automated backups to s3 every 5 minutes
su - ubuntu -c "crontab -l -e ubuntu | { cat; echo \"*/5 * * * * /usr/local/bin/aws s3 sync /opt/factorio/saves s3://$S3_SAVE_BUCKET\"; } | crontab -"
