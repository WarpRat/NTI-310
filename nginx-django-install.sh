#!/bin/bash
#
#Simple script to install a django server and connect it to a pgsql backend
#This script is designed for use on GCP.
#

yum install -y epel-release
yum update -y
yum install -y gcc python-devel python-pip git
pip install --upgrade pip
pip install --upgrade django
pip install --upgrade uwsgi

useradd -r -s /sbin/nologin uwsgi

git clone https://github.com/WarpRat/NTI-310-320-lbdemo.git /tmp/django_tmp/

mv /tmp/django_tmp/django /var/

chown -R uwsgi. /var/django

ip=$(curl http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip -H "Metadata-Flavor: Google")

sed -i "/ALLOWED_HOSTS/ s/\[.*\]/\['$ip'\]/g" /var/django/nti320/nti320/settings.py


# sed -i '/^DATABASES/,+5d' /var/django/nti320/nti320/settings.py
# 
# echo "DATABASES = {
    # 'default':{
        # 'ENGINE': 'django.db.backends.postgresql_psycopg2',
        # 'NAME': 'nti310',
        # 'USER': 'db_srv',
        # 'PASSWORD': 'Q3KyD4BWjR:En9*A((Syhgny8',
        # 'HOST': '10.138.0.9',
        # 'PORT': '5432',
    # }
# }" >> /var/django/nti320/nti320/settings.py

python /var/django/nti320/manage.py migrate
mkdir -p /var/log/uwsgi
mkdir -p /etc/uwsgi/vassals
touch /var/log/uwsgi/access.log
chown -R uwsgi. /var/log/uwsgi

cat << EOF >> /etc/uwsgi/emperor.ini
[uwsgi]
emperor = /etc/uwsgi/vassals
emperor-on-demand-extension = .socket
uid = uwsgi
gid = uwsgi
EOF

cat << EOF >> /etc/uwsgi/vassals/lbdemo.ini
[uwsgi]
chdir			= /var/django/nti320
module			= nti320.wsgi:application
master			= true
logdate			= true
logto			= /var/log/uwsgi/access.log
processes		= 5
vacuum 			= true
idle            = 10
die-on-idle     = true
#protocol        = http #turn on for testing
EOF

echo "$ip:3990" >> /etc/uwsgi/vassals/lbdemo.ini.socket

cat << EOF >> /etc/systemd/system/emperor.uwsgi.service
[Unit]
Description=uWSGI Emperor
After=syslog.target

[Service]
ExecStart=/bin/uwsgi --ini /etc/uwsgi/emperor.ini
Restart=always
KillSignal=SIGQUIT
Type=notify
StandardError=syslog
NotifyAccess=main

[Install]
WantedBy=multi-user.target
EOF

chown uwsgi. -R /etc/uwsgi
systemctl enable emperor.uwsgi
systemctl restart emperor.uwsgi

#Get instance name and zone
name=$(curl -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
zone=$(curl -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/zone)

#Remove startup script from metadata
gcloud compute instances add-metadata $name --metadata=finished=1 --zone $zone
gcloud compute instances remove-metadata $name --keys startup-script --zone $zone