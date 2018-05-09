#!/bin/bash

yum install -y epel-release
yum install -y python-pip python-devel gcc postgresql-server postgresql-devel postgresql-contrib

postgresql-setup initdb

systemctl restart postgresql

sed -i '/^host/ s/ident/md5/g' /var/lib/pgsql/data/pg_hba.conf

systemctl enable postgresql
systemctl restart postgresql

curl https://raw.githubusercontent.com/WarpRat/NTI-310/master/nti310.sql > /tmp/nti310.sql

sudo -i -u postgres psql -U postgres -f /tmp/nti310.sql
