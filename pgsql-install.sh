#!/bin/bash
#
#A script to install a basic PosgreSQL server
#

#Perform initial updates, activate epel-release repo, and install required packages
yum install -y epel-release
yum update -y
yum install -y python-pip python-devel gcc postgresql-server postgresql-devel postgresql-contrib

#Run the Postgres internal tool to initialize the datebase
postgresql-setup initdb

#Start the server
systemctl restart postgresql

#Allow users not matching system users to log in
sed -i '/^host/ s/ident/md5/g' /var/lib/pgsql/data/pg_hba.conf

#Restart the server and ensure it starts on boot
systemctl enable postgresql
systemctl restart postgresql

#Pull down the sql configuration file
curl https://raw.githubusercontent.com/WarpRat/NTI-310/master/nti310.sql > /tmp/nti310.sql

#Run the sql configuration file
sudo -i -u postgres psql -U postgres -f /tmp/nti310.sql
