#!/bin/bash

#Do initial updates
apt-get update -y && apt-get upgrade -y

#Install debconf
apt-get install -y debconf-utils

#Pull ldap configuration from github and preseed the debconf questions
curl https://raw.githubusercontent.com/WarpRat/NTI-310/master/ldapselections >> /tmp/ldapselections

while read -r line; do echo "$line" | debconf-set-selections; done < /tmp/ldapselections

#Install ldap utilities
DEBIAN_FRONTEND=noninteractive apt-get install -y libpam-ldap nscd

#Set login methods to include ldap
sed -i 's/compat/compat ldap/g' /etc/nsswitch.conf

#Restart the nameserver cache daemon.
systemctl restart nscd
