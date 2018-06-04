#!/bin/bash
#
#A script to install a basic PosgreSQL server
#

#Perform initial updates, activate epel-release repo, and install required packages
yum install -y epel-release
yum update -y
yum install -y python-pip python-devel gcc postgresql-server postgresql-devel postgresql-contrib phpPgAdmin httpd

#Set SELinux to Permissive (come back here and check with audit2allow)
setenforce 0

#Run the Postgres internal tool to initialize the datebase
postgresql-setup initdb

#Start the server
systemctl restart postgresql

#Allow users not matching system users to log in
sed -i '/^host/ s/ident/md5/g' /var/lib/pgsql/data/pg_hba.conf

#Listen on any address
sed -i '/^\#listen_addresses/ s/localhost/\*/g' /var/lib/pgsql/data/postgresql.conf
sed -i '/^\#listen_addresses/ s/^#//g' /var/lib/pgsql/data/postgresql.conf

#Allow database service account to log in
echo '
host	nti310	db_srv	10.138.0.0/20	md5' >> /var/lib/pgsql/data/pg_hba.conf
#Restart the server and ensure it starts on boot
systemctl enable postgresql
systemctl restart postgresql

#Pull down the sql configuration file
curl https://raw.githubusercontent.com/WarpRat/NTI-310/master/nti310.sql > /tmp/nti310.sql

#Run the sql configuration file
sudo -i -u postgres psql -U postgres -f /tmp/nti310.sql

#Allow outside connections to phpPgAdmin
sed -i 's/Require local/Require all granted/g' /etc/httpd/conf.d/phpPgAdmin.conf

#Allow user postgres to connect
sed -i '/extra_login_security/ s/true/false/g' /etc/phpPgAdmin/config.inc.php

#Set lab password **NEVER USE ON THE OPEN INTERNET**
nti_cmd="ALTER USER db_srv WITH PASSWORD 'P@ssw0rd1';"
pg_cmd="ALTER USER postgres WITH PASSWORD 'P@ssw0rd1';"
sudo -i -u postgres psql -U postgres -d nti310 --command $nti_cmd
sudo -i -u postgres psql -U postgres -d template1 --command $pg_cmd

echo $nti_cmd > /tmp/nti_cmd
echo $pg_cmd > /tmp/pg_cmd
#Change authentication method for local unix socket
sed -i '/^local/ s/peer/md5/g' /var/lib/pgsql/data/pg_hba.conf

#Restart services
systemctl restart httpd
systemctl restart postgresql

#Get instance name and zone
name=$(curl -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
zone=$(curl -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/zone)

#Remove startup script from metadata
gcloud compute instances add-metadata $name --metadata=finished=1 --zone $zone
gcloud compute instances remove-metadata $name --keys startup-script --zone $zone

#Install Nagios Monitoring
yum install -y nrpe nagios-plugins-all
yum update -y
systemctl enable nrpe
systemctl restart nrpe

sed -i 's/allowed_hosts=127.0.0.1/allowed_hosts=127.0.0.1, 10.138.0.3/g' /etc/nagios/nrpe.cfg

sed -i 's/check_hda1/check_disk/g' /etc/nagios/nrpe.cfg
sed -i 's/dev\/hda1/dev\/sda1/g' /etc/nagios/nrpe.cfg
echo "command[check_mem]=/usr/lib/nagios/plugins/check_mem.sh -w 80 -c 90" >> /etc/nagios/nrpe.cfg
#Get the ip address of the first instance with repo in the name - adjust with for loop to add multiple repos at once
repo_ip=$(gcloud compute instances list | grep repo | sed '/s/\s\{1,\}/ /g' | cut -d ' ' -f 4 | head -n 1)

echo "[nti-320]
name=Extra Packages for Centos from NTI-320 7 - $basearch
#baseurl=http://download.fedoraproject.org/pub/epel/7/$basearch <- example epel repo
# Note, this is putting repodata at packages instead of 7 and our path is a hack around that.
baseurl=http://$repo_ip/centos/7/extras/x86_64/Packages/
enabled=1
gpgcheck=0
" >> /etc/yum.repos.d/NTI-320.repo

#Syslog
echo "*.info;mail.none;authpriv.none;cron.none   @10.138.0.4" >> /etc/rsyslog.conf && systemctl restart rsyslog.service
