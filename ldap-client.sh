#!/bin/bash

#Do initial updates
apt-get update -y && apt-get upgrade -y

#Install debconf
apt-get install -y debconf-utils

#Pull ldap configuration from github and preseed the debconf questions
curl https://raw.githubusercontent.com/WarpRat/NTI-310/master/ldapselections >> /tmp/ldapselections

ldap_ip=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/ldap_ip" -H "Metadata-Flavor: Google")

sed -i "s/\(ldap-server\).*$/\1\\tstring ldap:\/\/$ldap_ip/g" /tmp/ldapselections

cat /tmp/ldapselections

while read -r line; do echo "$line" | debconf-set-selections; done < /tmp/ldapselections

#Install ldap utilities
DEBIAN_FRONTEND=noninteractive apt-get install -y libpam-ldap nscd

#Set login methods to include ldap
sed -i 's/compat/compat ldap/g' /etc/nsswitch.conf

#Restart the nameserver cache daemon.
systemctl restart nscd

#Get instance name and zone
name=$(curl -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
zone=$(curl -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/zone)

#Remove startup script from metadata
gcloud compute instances add-metadata $name --metadata=finished=1 --zone $zone
gcloud compute instances remove-metadata $name --keys startup-script --zone $zone