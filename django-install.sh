#!/bin/bash
#
#Simple script to install a django server and connect it to a pgsql backend
#This script is designed for use on GCP.
#

yum install -y epel-release
yum update -y
yum install -y python-pip
pip install --upgrade pip
pip install --upgrade virtualenv

cd /opt
virtualenv django
cd django
source bin/activate && pip install django psycopg2 && django-admin startproject testserver

useradd -r -s /sbin/nologin django-admin

chown -R django-admin. /opt/django

ip=$(curl http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")

sed -i "s/ALLOWED_HOSTS \= \[/&'$ip'/" /opt/django/testserver/testserver/settings.py

sed -i '/^DATABASES/,+5d' /opt/django/testserver/testserver/settings.py

echo "DATABASES = {
    'default':{
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'nti310',
        'USER': 'db_srv',
        'PASSWORD': 'Q3KyD4BWjR:En9*A((Syhgny8',
        'HOST': '10.138.0.9',
        'PORT': '5432',
    }
}" >> /opt/django/testserver/testserver/settings.py

#Get instance name and zone
name=$(curl -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
zone=$(curl -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/zone)

#Remove startup script from metadata
gcloud compute instances add-metadata $name --metadata=finished=1 --zone $zone
gcloud compute instances remove-metadata $name --keys startup-script --zone $zone


/sbin/runuser django-admin -s /bin/bash -c "\
	source /opt/django/bin/activate &&
	/opt/django/testserver/manage.py migrate &&
	/opt/django/testserver/manage.py runserver 0:8000 &"
